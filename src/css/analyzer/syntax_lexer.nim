import std/[strutils, sequtils, tables, options, unicode]

type
  TokenKind* = enum
    tkDataType,     # <...>
    tkKeyword,      # literal keywords
    tkOr,           # |
    tkOrList,       # ||
    tkAndList,      # &&
    tkCommaList,    # #
    tkSpaceList,    # +
    tkOptional,     # [...] with ? modifier
    tkGroup,        # [...] - for grouping (required)
    tkParenGroup,   # (...) - for parenthesized grouping
    tkZeroOrMore,   # *
    tkRequired,     # ...!
    tkSingleOptional, # ? - makes previous term optional
    tkSlash,        # / - separator
    tkQuantity,     # {m,n} - quantity specifier
    tkValueRange,   # [min,max] - value range
    tkComma,        # , - parameter separator in functions
    tkAtRule,       # @keyword - CSS at-rule
    tkBodyBlock,    # {...} - block of content
    tkOpenBrace,    # { - opening brace
    tkCloseBrace,   # } - closing brace
    tkColon,        # : - colon separator
    tkChar          # 's' - character in single quotes

  ValueRangeType* = object
    min*: string
    max*: string

  QuantityType* = object
    min*: int
    max*: Option[int]  # None means unlimited

  Token* = object
    kind*: TokenKind
    value*: string
    children*: seq[Token]
    modifiers*: seq[TokenKind]  # To store modifiers like ?, !, #, +, *
    case isSpecial*: bool
    of true:
      quantity*: QuantityType
      valueRange*: ValueRangeType
    of false: discard

proc parseDataType(input: string, pos: var int): string {.gcsafe.} =
  # Parse a data type like <color> or <'padding-top'>
  result = ""
  if pos >= input.len or input[pos] != '<':
    return
  
  pos += 1 # Skip opening <
  
  # Check for quoted property names like <'padding-top'>
  var hasQuote = false
  if pos < input.len and input[pos] == '\'':
    hasQuote = true
    result.add('\'')
    pos += 1
  
  # Store the starting position to detect premature ending
  var contentStartPos = pos
  
  while pos < input.len and input[pos] != '>':
    # If we have a quote, look for closing quote
    if hasQuote and input[pos] == '\'':
      result.add('\'')
      pos += 1
      # Continue to grab characters until we reach >
      while pos < input.len and input[pos] != '>':
        # Skip any value range that might appear after the property
        if input[pos] == '[':
          # We're inside a data type but encountered a value range marker
          # Don't add it to the result
          break
        result.add(input[pos])
        pos += 1
      break
    
    # Check for value range start inside data type - we should stop
    if input[pos] == '[':
      # We're inside a data type but encountered a value range marker
      # We need to roll back position to process it separately outside
      break
    
    result.add(input[pos])
    pos += 1
  
  # If we found a value range marker '[' inside the data type, we need to stop
  # without consuming it, so it can be processed separately
  if pos < input.len and input[pos] == '[':
    # Make sure we captured at least some content
    if pos > contentStartPos:
      # Success, but don't advance position past '['
      # We'll leave the '[' to be processed as a value range later
      return
  
  if pos < input.len and input[pos] == '>':
    pos += 1 # Skip closing >
  else:
    # Invalid data type, no closing >
    return ""

proc parseChar(input: string, pos: var int): string {.gcsafe.} =
  # Parse a character in single quotes like 's'
  result = ""
  if pos >= input.len or input[pos] != '\'':
    return
  
  pos += 1 # Skip opening quote
  
  # Capture everything until the closing quote
  while pos < input.len and input[pos] != '\'':
    result.add(input[pos])
    pos += 1
  
  if pos < input.len and input[pos] == '\'':
    pos += 1 # Skip closing quote
  else:
    # Invalid char, no closing quote
    return ""

proc parseKeyword(input: string, pos: var int): string {.gcsafe.} =
  # Parse a keyword (simple string without spaces or special chars)
  result = ""
  while pos < input.len and input[pos] in {'a'..'z', 'A'..'Z', '0'..'9', '-'}:
    result.add(input[pos])
    pos += 1

proc skipWhitespace(input: string, pos: var int) {.gcsafe.} =
  while pos < input.len and input[pos] in {' ', '\t', '\n', '\r'}:
    pos += 1

proc parseQuantity(input: string, pos: var int): Option[QuantityType] {.gcsafe.} =
  # Parse a quantity specifier like {1,2} or {1,} or {1}
  if pos >= input.len or input[pos] != '{':
    return none(QuantityType)
  
  var startPos = pos
  pos += 1 # Skip {
  var minStr = ""
  var maxStr = ""
  var reachedComma = false
  
  while pos < input.len and input[pos] != '}':
    if input[pos] == ',':
      reachedComma = true
      pos += 1
    elif input[pos] in {'0'..'9'}:
      if reachedComma:
        maxStr.add(input[pos])
      else:
        minStr.add(input[pos])
      pos += 1
    else:
      # Invalid character, not a number or comma
      pos = startPos # Reset position
      return none(QuantityType)
  
  if pos < input.len and input[pos] == '}':
    pos += 1 # Skip }
    
    var minVal = if minStr.len > 0: parseInt(minStr) else: 0
    var maxVal: Option[int]
    
    # If no comma was encountered, it's a single value specifier {n}
    if not reachedComma:
      maxVal = some(minVal)  # For {n}, max is the same as min
    else:
      # For {n,m} or {n,}, handle as before
      maxVal = if maxStr.len > 0: some(parseInt(maxStr)) else: none(int)
    
    return some(QuantityType(min: minVal, max: maxVal))
  else:
    # Unclosed quantity specifier
    pos = startPos # Reset position
    return none(QuantityType)

proc parseValueRange(input: string, pos: var int): Option[ValueRangeType] {.gcsafe.} =
  # Parse a value range like [0,∞]
  if pos >= input.len or input[pos] != '[':
    return none(ValueRangeType)
  
  var startPos = pos
  pos += 1 # Skip [
  
  # Skip whitespace before min value
  skipWhitespace(input, pos)
  
  # Parse min value
  var minValue = ""
  while pos < input.len and input[pos] notin {',', ']', ' ', '\t', '\n', '\r'}:
    minValue.add(input[pos])
    pos += 1
  
  # Skip whitespace after min value
  skipWhitespace(input, pos)
  
  # Check for comma
  if pos < input.len and input[pos] == ',':
    pos += 1 # Skip ,
  else:
    # Invalid format, no comma
    pos = startPos # Reset position
    return none(ValueRangeType)
  
  # Skip whitespace before max value
  skipWhitespace(input, pos)
  
  # Parse max value (could be infinity symbol ∞ or other value)
  var maxValue = ""
  while pos < input.len and input[pos] notin {']', ' ', '\t', '\n', '\r'}:
    # Safely handle UTF-8 characters
    if pos < input.len:  # Ensure we're still within bounds
      var runeLen = 1
      # Only use unicode functions for potential multi-byte characters
      if ord(input[pos]) >= 128:
        try:
          runeLen = runeLenAt(input, pos)
        except IndexDefect:
          # If we get an index error, just treat as a single byte
          runeLen = 1
      
      # Safely extract the character(s)
      if pos + runeLen <= input.len:
        maxValue.add(input[pos..<pos+runeLen])
        pos += runeLen
      else:
        # If adding runeLen would exceed string length, just add the current char
        maxValue.add(input[pos])
        pos += 1
    else:
      break  # Safety check - shouldn't reach here due to the while condition
  
  # Skip whitespace after max value
  skipWhitespace(input, pos)
  
  # Check for closing bracket
  if pos < input.len and input[pos] == ']':
    pos += 1 # Skip ]
    return some(ValueRangeType(min: minValue, max: maxValue))
  else:
    # Invalid format, no closing bracket
    pos = startPos # Reset position
    return none(ValueRangeType)

proc checkModifiersWithQuantity(input: string, pos: var int): tuple[modifiers: seq[TokenKind], quantity: Option[QuantityType]] {.gcsafe.} =
  # Check for modifiers after a token or group, and also check for quantity specifiers that follow modifiers
  result.modifiers = @[]
  result.quantity = none(QuantityType)
  var currentPos = pos
  
  while currentPos < input.len:
    case input[currentPos]:
      of '?':
        result.modifiers.add(tkSingleOptional)
        currentPos += 1
      of '!':
        result.modifiers.add(tkRequired)
        currentPos += 1
      of '#':
        result.modifiers.add(tkCommaList)
        currentPos += 1
        # After encountering a comma list modifier #, check for a quantity specifier
        skipWhitespace(input, currentPos)
        if currentPos < input.len and input[currentPos] == '{':
          result.quantity = parseQuantity(input, currentPos)
      of '+':
        result.modifiers.add(tkSpaceList)
        currentPos += 1
        # Similar handling for space list modifier
        skipWhitespace(input, currentPos)
        if currentPos < input.len and input[currentPos] == '{':
          result.quantity = parseQuantity(input, currentPos)
      of '*':
        result.modifiers.add(tkZeroOrMore)
        currentPos += 1
      else:
        break
  
  # Update position only if we found modifiers or quantity
  if result.modifiers.len > 0 or result.quantity.isSome:
    pos = currentPos

# Then we need to change the original checkModifiers function to use this new one internally
proc checkModifiers(input: string, pos: var int): seq[TokenKind] {.gcsafe.} =
  let result = checkModifiersWithQuantity(input, pos)
  return result.modifiers


proc parseTokens(input: string, pos: var int, inFunctionGroup = false): seq[Token] {.gcsafe.}

# Parse the body block content (everything between { and })
proc parseBodyBlock(input: string, pos: var int): Token {.gcsafe.} =
  var startPos = pos
  if pos >= input.len or input[pos] != '{':
    return Token(kind: tkBodyBlock, value: "", isSpecial: false)
  
  pos += 1 # Skip {
  var braceCount = 1
  var bodyContent = ""
  
  # Parse all content until we find the matching closing brace
  while pos < input.len and braceCount > 0:
    if input[pos] == '{':
      braceCount += 1
    elif input[pos] == '}':
      braceCount -= 1
      if braceCount == 0:
        pos += 1  # Skip the closing brace
        break
    
    if braceCount > 0:  # Only add to content if we haven't hit the matching closing brace
      bodyContent.add(input[pos])
      pos += 1
  
  # Parse the body content recursively to tokenize its contents
  var contentPos = 0
  let innerTokens = parseTokens(bodyContent, contentPos)
  
  return Token(
    kind: tkBodyBlock,
    value: bodyContent,
    children: innerTokens,
    isSpecial: false
  )

proc parseTokens(input: string, pos: var int, inFunctionGroup = false): seq[Token] {.gcsafe.} =
  var tokens: seq[Token] = @[]
  
  while pos < input.len:
    skipWhitespace(input, pos)
    if pos >= input.len:
      break
    
    # Handle commas as separators in function parameter lists
    if inFunctionGroup and input[pos] == ',':
      pos += 1 # Skip the comma
      tokens.add(Token(kind: tkComma, value: ",", isSpecial: false))
      continue
    
    # Handle colon as a token
    if input[pos] == ':':
      pos += 1 # Skip the colon
      tokens.add(Token(kind: tkColon, value: ":", isSpecial: false))
      continue
    
    # Handle @ for at-rules
    if input[pos] == '@':
      pos += 1 # Skip @
      skipWhitespace(input, pos)
      
      # Parse the at-rule keyword that follows the @ symbol
      let atRuleKeyword = parseKeyword(input, pos)
      if atRuleKeyword != "":
        tokens.add(Token(kind: tkAtRule, value: atRuleKeyword, isSpecial: false))
      else:
        # Invalid at-rule (@ without keyword)
        # Just add a generic at-rule token and continue
        tokens.add(Token(kind: tkAtRule, value: "", isSpecial: false))
      
      continue
    
    # Handle opening brace - for body blocks
    if input[pos] == '{':
      # Generate a body block token
      let bodyBlock = parseBodyBlock(input, pos)
      tokens.add(bodyBlock)
      continue
    
    # Handle closing brace - should be handled by parseBodyBlock
    if input[pos] == '}':
      pos += 1 # Skip }
      continue
    
    # Handle character in single quotes
    if input[pos] == '\'':
      let charValue = parseChar(input, pos)
      if charValue != "":
        # Check for modifiers and quantity
        skipWhitespace(input, pos)
        let modResult = checkModifiersWithQuantity(input, pos)
        
        # Then check for quantity if not already found after a modifier
        let quantityOpt = if modResult.quantity.isNone and pos < input.len and input[pos] == '{':
          parseQuantity(input, pos)
        else:
          modResult.quantity
        
        # Create appropriate token based on quantity
        if quantityOpt.isSome:
          var token = Token(
            kind: tkChar, 
            value: charValue, 
            isSpecial: true,
            quantity: quantityOpt.get(),
            valueRange: ValueRangeType(), # Empty, as chars don't have value ranges
            modifiers: modResult.modifiers
          )
          tokens.add(token)
        else:
          var token = Token(
            kind: tkChar, 
            value: charValue, 
            isSpecial: false,
            modifiers: modResult.modifiers
          )
          tokens.add(token)
      continue
    
    # Data Type
    if input[pos] == '<':
      let dataType = strutils.strip(parseDataType(input, pos))
      if dataType != "":
        # Check for value range
        skipWhitespace(input, pos)
        let valueRangeOpt = parseValueRange(input, pos)
        # Check for modifiers and quantity
        skipWhitespace(input, pos)
        let modResult = checkModifiersWithQuantity(input, pos)
        # Then check for quantity if not already found after a modifier
        let quantityOpt = if modResult.quantity.isNone and pos < input.len and input[pos] == '{':
          parseQuantity(input, pos)
        else:
          modResult.quantity
        # Create appropriate token based on specials
        if valueRangeOpt.isSome or quantityOpt.isSome:
          var token = Token(
            kind: tkDataType, 
            value: dataType, 
            isSpecial: true,
            valueRange: if valueRangeOpt.isSome: valueRangeOpt.get() else: ValueRangeType(),
            quantity: if quantityOpt.isSome: quantityOpt.get() else: QuantityType(),
            modifiers: modResult.modifiers  # Add modifiers even for special tokens
          )
          tokens.add(token)
        else:
          var token = Token(
            kind: tkDataType, 
            value: dataType, 
            isSpecial: false,
            modifiers: modResult.modifiers
          )
          tokens.add(token)
    
    # Group with square brackets - either a required group or optional group with ? modifier
    elif input[pos] == '[':
      pos += 1 # Skip [
      let innerTokens = parseTokens(input, pos, inFunctionGroup)
      if pos < input.len and input[pos] == ']':
        pos += 1 # Skip ]
        
        # Check for modifiers and quantity
        let modResult = checkModifiersWithQuantity(input, pos)
        let isOptional = tkSingleOptional in modResult.modifiers
        
        # Then check for quantity if not already found after a modifier
        let quantityOpt = if modResult.quantity.isNone and pos < input.len and input[pos] == '{':
          parseQuantity(input, pos)
        else:
          modResult.quantity
        
        # Create appropriate token based on whether it's optional and has quantity
        if quantityOpt.isSome:
          var token = Token(
            kind: if isOptional: tkOptional else: tkGroup, 
            children: innerTokens, 
            isSpecial: true,
            quantity: quantityOpt.get(),
            valueRange: ValueRangeType(), # Empty as groups don't have value ranges
            modifiers: modResult.modifiers  # Add modifiers even for special tokens
          )
          tokens.add(token)
        else:
          var token = Token(
            kind: if isOptional: tkOptional else: tkGroup, 
            children: innerTokens, 
            isSpecial: false,
            modifiers: modResult.modifiers
          )
          tokens.add(token)
    
    # Parenthesized Group
    elif input[pos] == '(':
      pos += 1 # Skip (
      
      # Determine if this is likely a function
      var isFunctionGroup = false
      if tokens.len > 0 and tokens[^1].kind == tkKeyword:
        isFunctionGroup = true
      
      let innerTokens = parseTokens(input, pos, isFunctionGroup)
      
      if pos < input.len and input[pos] == ')':
        pos += 1 # Skip )
        
        # Check for modifiers and quantity
        let modResult = checkModifiersWithQuantity(input, pos)
        
        # Then check for quantity if not already found after a modifier
        let quantityOpt = if modResult.quantity.isNone and pos < input.len and input[pos] == '{':
          parseQuantity(input, pos)
        else:
          modResult.quantity
        
        # Create appropriate token based on quantity
        if quantityOpt.isSome:
          var token = Token(
            kind: tkParenGroup, 
            children: innerTokens, 
            isSpecial: true,
            quantity: quantityOpt.get(),
            valueRange: ValueRangeType(), # Empty, as groups don't have value ranges
            modifiers: modResult.modifiers  # Add modifiers even for special tokens
          )
          tokens.add(token)
        else:
          var token = Token(
            kind: tkParenGroup, 
            children: innerTokens, 
            isSpecial: false,
            modifiers: modResult.modifiers
          )
          tokens.add(token)
    
    # End of group or optional, handled by caller
    elif input[pos] in {')', ']'}:
      break
    
    # Or operator
    elif input[pos] == '|':
      if pos + 1 < input.len and input[pos + 1] == '|':
        # Or list ||
        pos += 2
        tokens.add(Token(kind: tkOrList, isSpecial: false))
      else:
        # Simple or |
        pos += 1
        tokens.add(Token(kind: tkOr, isSpecial: false))
    
    # And list
    elif input[pos] == '&' and pos + 1 < input.len and input[pos + 1] == '&':
      pos += 2
      tokens.add(Token(kind: tkAndList, isSpecial: false))
    
    # Slash separator
    elif input[pos] == '/':
      pos += 1
      tokens.add(Token(kind: tkSlash, isSpecial: false))
    
    # Keyword
    else:
      let keyword = parseKeyword(input, pos)
      if keyword != "":
        # Check for modifiers and quantity
        skipWhitespace(input, pos)
        let modResult = checkModifiersWithQuantity(input, pos)
        
        # Then check for quantity if not already found after a modifier
        let quantityOpt = if modResult.quantity.isNone and pos < input.len and input[pos] == '{':
          parseQuantity(input, pos)
        else:
          modResult.quantity
        
        # Create appropriate token based on quantity
        if quantityOpt.isSome:
          var token = Token(
            kind: tkKeyword, 
            value: keyword, 
            isSpecial: true,
            quantity: quantityOpt.get(),
            valueRange: ValueRangeType(), # Empty, as keywords don't have value ranges
            modifiers: modResult.modifiers  # Add modifiers even for special tokens
          )
          tokens.add(token)
        else:
          var token = Token(
            kind: tkKeyword, 
            value: keyword, 
            isSpecial: false,
            modifiers: modResult.modifiers
          )
          tokens.add(token)
      else:
        # Skip unrecognized character
        pos += 1
  
  return tokens
  

proc tokenizeSyntax*(input: string): seq[Token] {.gcsafe.} =
  var pos = 0
  result = @[]
  
  result = parseTokens(input, pos)

proc formatQuantity(q: QuantityType): string {.gcsafe.} =
  if q.max.isNone:
    if q.min == 0:
      result = "{0,∞}"
    else:
      result = "{" & $q.min & ",∞}"
  else:
    # If min and max are the same, format as {n} instead of {n,n}
    if q.min == q.max.get():
      result = "{" & $q.min & "}"
    else:
      result = "{" & $q.min & "," & $q.max.get() & "}"

proc formatValueRange(vr: ValueRangeType): string {.gcsafe.} =
  result = "[" & vr.min & "," & vr.max & "]"

proc `$`(token: Token): string =
  var base = ""
  case token.kind:
    of tkDataType:
      base = "DataType<" & token.value & ">"
    of tkKeyword:
      base = "Keyword(" & token.value & ")"
    of tkOr:
      base = "Or(|)"
    of tkOrList:
      base = "OrList(||)"
    of tkAndList:
      base = "AndList(&&)"
    of tkCommaList:
      base = "CommaList(#)"
    of tkSpaceList:
      base = "SpaceList(+)"
    of tkOptional:
      base = "Optional[" & token.children.mapIt($it).join(" ") & "]"
    of tkZeroOrMore:
      base = "ZeroOrMore(*)"
    of tkRequired:
      base = "Required(!)"
    of tkGroup:
      base = "Group[" & token.children.mapIt($it).join(" ") & "]"
    of tkParenGroup:
      base = "ParenGroup(" & token.children.mapIt($it).join(" ") & ")"
    of tkSingleOptional:
      base = "Optional(?)"
    of tkSlash:
      base = "Separator(/)"
    of tkQuantity:
      base = "Quantity"
    of tkValueRange:
      base = "ValueRange"
    of tkComma:
      base = "Comma(,)"
    of tkAtRule:
      base = "AtRule(@" & token.value & ")"
    of tkBodyBlock:
      base = "BodyBlock{" & token.children.mapIt($it).join(" ") & "}"
    of tkOpenBrace:
      base = "OpenBrace({)"
    of tkCloseBrace:
      base = "CloseBrace(})"
    of tkColon:
      base = "Colon(:)"
    of tkChar:
      base = "Char('" & token.value & "')"
  
  # Add special information if any
  if token.isSpecial:
    if token.kind == tkDataType or token.kind == tkKeyword or 
       token.kind == tkParenGroup or token.kind == tkGroup or token.kind == tkOptional or
       token.kind == tkChar:  # Add tkChar to the list of tokens that can have specials
      # Show quantity if available
      if token.quantity.min != 0 or token.quantity.max.isSome:
        base = base & " " & formatQuantity(token.quantity)
      
      # Show value range if available (for data types)
      if token.kind == tkDataType and token.valueRange.min != "" and token.valueRange.max != "":
        base = base & " " & formatValueRange(token.valueRange)
  
  # Add modifiers if any - but don't add the ? modifier for tkOptional as it's already included in the kind
  if token.modifiers.len > 0:
    var modStr = ""
    for modd in token.modifiers:
      # Skip ? for tkOptional as it's redundant
      if token.kind == tkOptional and modd == tkSingleOptional:
        continue
        
      case modd:
        of tkSingleOptional: modStr.add("?")
        of tkRequired: modStr.add("!")
        of tkCommaList: modStr.add("#")
        of tkSpaceList: modStr.add("+")
        of tkZeroOrMore: modStr.add("*")
        else: discard
    
    if modStr.len > 0:
      result = base & " with modifiers: " & modStr
    else:
      result = base
  else:
    result = base

import times
when isMainModule:
  # Test the enhanced CSS syntax parser
  
  let startTime = getTime()
  block:
    let syntax1 = "@font-feature-values <family-name># {\n  <feature-value-block-list>\n}"
    let tokens1 = tokenizeSyntax(syntax1)
    echo "Parsed syntax: ", syntax1
    echo tokens1
    
    # Test with more complex at-rule syntax that includes a colon
    let syntax2 = "( <ident> : <ident> )"
    let tokens2 = tokenizeSyntax(syntax2)
    echo "\nParsed syntax: ", syntax2
    echo tokens2

    # Test with character literals
    let syntax3 = "( [ <mf-plain> | <mf-boolean> | <mf-range> ] )"
    let tokens3 = tokenizeSyntax(syntax3)
    echo "\nParsed syntax: ", syntax3
    echo tokens3
  
  echo "\nTotal time taken: ", getTime() - startTime