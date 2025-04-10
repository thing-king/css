import options, strutils, sequtils, tables

const REPLACEMENTS = @[
  ("-webkit-match-parent", "match-parent"),
  ("currentcolor", "currentColor"),
  ("-webkit-max-content", "max-content"),
  ("-webkit-min-content", "min-content"),
  ("-moz-max-content", "max-content"),
  ("-moz-min-content", "min-content"),
  ("RGBA(", "rgba("),
  ("RGB(", "rgb("),
  ("-webkit-sticky", "sticky"),
].toTable

type
  ValueTokenKind* = enum
    vtkNumber,      
    vtkDimension,   
    vtkPercentage,  
    vtkColor,       
    vtkString,      
    vtkIdent,       
    vtkFunc,        
    vtkComma,       
    vtkSlash,       
    vtkLParen,      
    vtkRParen,      
    vtkImportant,   
    vtkSequence,
    vtkAtRule,
    vtkProperty,
    vtkRule         

  ValueToken* = object
    case kind*: ValueTokenKind
    of vtkAtRule, vtkRule:
      body*: seq[ValueToken]
    else:
      discard
    value*: string
    children*: seq[ValueToken]
    line*: int      
    column*: int    
    case hasNumValue*: bool
    of true:
      numValue*: float
      unit*: string
    of false: discard

# Efficient token position tracker
type TokenPosition = object
  i*: int
  line*: int
  column*: int
  input*: string

# Pre-allocate token sequences for better performance
const INITIAL_TOKEN_CAPACITY = 32

# Character classification for better performance (avoid multiple char checks)
template isIdentChar(c: char): bool = c.isAlphaAscii or c.isDigit or c in {'-', '_'}
template isHexChar(c: char): bool = c in {'0'..'9', 'a'..'f', 'A'..'F'}

# Fast position manipulation
template consumeChar(pos: var TokenPosition) =
  if pos.i < pos.input.len:
    if pos.input[pos.i] == '\n':
      inc pos.line
      pos.column = 1
    else:
      inc pos.column
    inc pos.i

template skipWhitespace(pos: var TokenPosition) =
  while pos.i < pos.input.len and pos.input[pos.i] in {' ', '\t', '\n', '\r'}:
    if pos.input[pos.i] == '\n':
      inc pos.line
      pos.column = 1
    else:
      inc pos.column
    inc pos.i

# Optimized string extraction without slicing (avoids allocation)
template extractString(pos: TokenPosition, startIdx: int): string =
  pos.input[startIdx..<pos.i]

template skipComment(pos: var TokenPosition) =
  if pos.i + 1 < pos.input.len and pos.input[pos.i..pos.i+1] == "/*":
    # Move past the opening of the comment
    pos.i += 2
    
    # Find the closing of the comment
    while pos.i < pos.input.len:
      if pos.i + 1 < pos.input.len and pos.input[pos.i..pos.i+1] == "*/":
        pos.i += 2  # Move past the closing of the comment
        break
      
      # Track line and column for multiline comments
      if pos.input[pos.i] == '\n':
        inc pos.line
        pos.column = 1
      else:
        inc pos.column
      
      inc pos.i

# Forward declarations
proc tokenizeValueFast*(input: string, wrapRoot: bool = true, startLine: int = 1, startColumn: int = 1, isPropertyValue: bool = false): seq[ValueToken]
proc parseValueBodyFast*(pos: var TokenPosition, wrapRoot: bool = true): seq[ValueToken]
proc parseRule(pos: var TokenPosition): ValueToken
proc parseAtRule(pos: var TokenPosition): ValueToken
proc parseProperty(pos: var TokenPosition): ValueToken

# Function to check if input likely contains a property
proc hasPropertySyntax(input: string): bool =
  var i = 0
  
  # Skip initial whitespace
  while i < input.len and input[i] in {' ', '\t', '\n', '\r'}:
    inc i
  
  # Find identifier
  let startIdent = i
  while i < input.len and isIdentChar(input[i]):
    inc i
  
  if i == startIdent:
    return false  # No identifier found
  
  # Skip whitespace after identifier
  while i < input.len and input[i] in {' ', '\t'}:
    inc i
  
  # Check for colon
  if i < input.len and input[i] == ':':
    return true
  
  return false

# Helper to check if current position might be a property
proc isPotentialProperty(pos: TokenPosition): bool =
  var lookAhead = pos.i
  
  # Skip identifier
  while lookAhead < pos.input.len and isIdentChar(pos.input[lookAhead]):
    inc lookAhead
  
  # Skip whitespace
  while lookAhead < pos.input.len and pos.input[lookAhead] in {' ', '\t'}:
    inc lookAhead
  
  # Check for colon
  return lookAhead < pos.input.len and pos.input[lookAhead] == ':'

# Wrap tokens in a sequence if more than one token
proc wrapSequence*(tokens: seq[ValueToken], isRoot: bool = false, line: int = 1, column: int = 1): ValueToken =
  if tokens.len == 1 and not isRoot:
    result = tokens[0]
  else:
    result = ValueToken(kind: vtkSequence, value: "", children: tokens, line: line, column: column)

# Fast token creation helpers
proc createToken(kind: ValueTokenKind, value: string, line, column: int): ValueToken =
  ValueToken(kind: kind, value: value, line: line, column: column)

proc createNumericToken(kind: ValueTokenKind, value: string, numValue: float, unit: string, line, column: int): ValueToken =
  ValueToken(kind: kind, value: value, hasNumValue: true, numValue: numValue, unit: unit, line: line, column: column)

# Core parsing functions optimized for speed
proc parseString(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let quoteChar = pos.input[pos.i]
  consumeChar(pos)  # skip opening quote
  
  let startIdx = pos.i
  while pos.i < pos.input.len and pos.input[pos.i] != quoteChar:
    consumeChar(pos)
  
  let strVal = if pos.i > startIdx: extractString(pos, startIdx) else: ""
  
  if pos.i < pos.input.len:
    consumeChar(pos)  # skip closing quote
  
  return createToken(vtkString, strVal, startLine, startColumn)

proc parseNumber(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let startIdx = pos.i
  
  # Handle negative sign
  if pos.i < pos.input.len and pos.input[pos.i] == '-':
    consumeChar(pos)
  
  # Parse digits before decimal
  while pos.i < pos.input.len and pos.input[pos.i] in {'0'..'9'}:
    consumeChar(pos)
  
  # Parse decimal point and digits after
  if pos.i < pos.input.len and pos.input[pos.i] == '.':
    consumeChar(pos)
    while pos.i < pos.input.len and pos.input[pos.i] in {'0'..'9'}:
      consumeChar(pos)
  
  # Extract the numeric string
  let numStr = extractString(pos, startIdx)
  
  # Check for unit
  let unitStartIdx = pos.i
  if pos.i < pos.input.len and (pos.input[pos.i] in {'a'..'z', 'A'..'Z', '%'}):
    while pos.i < pos.input.len and (pos.input[pos.i] in {'a'..'z', 'A'..'Z', '-', '%'}):
      consumeChar(pos)
  
  let unit = if pos.i > unitStartIdx: extractString(pos, unitStartIdx) else: ""
  let fullValue = numStr & unit
  
  # Parse the number value
  let numValue = try: parseFloat(numStr) except: 0.0
  
  # Return appropriate token based on unit
  if unit == "%":
    return createNumericToken(vtkPercentage, fullValue, numValue, unit, startLine, startColumn)
  elif unit.len > 0:
    return createNumericToken(vtkDimension, fullValue, numValue, unit, startLine, startColumn)
  else:
    return createNumericToken(vtkNumber, numStr, numValue, "", startLine, startColumn)

proc parseImportant(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let startIdx = pos.i
  
  # Skip '!'
  consumeChar(pos)
  
  # Check for "important"
  if pos.i + 8 <= pos.input.len:
    let slice = pos.input[pos.i..<pos.i+9]
    if slice == "important":
      for _ in 1..9:
        consumeChar(pos)
      return createToken(vtkImportant, "!important", startLine, startColumn)
  
  # If not !important, return as ident
  pos.i = startIdx
  pos.line = startLine
  pos.column = startColumn
  consumeChar(pos)
  return createToken(vtkIdent, "!", startLine, startColumn)

proc parseFunctionArgsFast(pos: var TokenPosition): seq[ValueToken] =
  var args = newSeqOfCap[ValueToken](INITIAL_TOKEN_CAPACITY)
  var currentArg = ""
  var parenLevel = 0
  var argPos = TokenPosition(i: pos.i, line: pos.line, column: pos.column, input: pos.input)
  
  # Track where current arg starts
  var currentArgStartLine = pos.line
  var currentArgStartColumn = pos.column
  
  while pos.i < pos.input.len:
    let c = pos.input[pos.i]
    
    if c == '(':
      parenLevel.inc()
      currentArg.add(c)
      consumeChar(pos)
    elif c == ')' and parenLevel > 0:
      parenLevel.dec()
      currentArg.add(c)
      consumeChar(pos)
    elif c == ')' and parenLevel == 0:
      break
    elif c == ',' and parenLevel == 0:
      if currentArg.len > 0:
        let argTokens = tokenizeValueFast(currentArg.strip(), false, currentArgStartLine, currentArgStartColumn, true)
        if argTokens.len == 1:
          args.add(argTokens[0])
        else:
          args.add(wrapSequence(argTokens, false, currentArgStartLine, currentArgStartColumn))
      
      currentArg = ""
      currentArgStartLine = pos.line
      currentArgStartColumn = pos.column
      consumeChar(pos)
    else:
      currentArg.add(c)
      consumeChar(pos)
  
  # Add the last argument if there is one
  if currentArg.len > 0:
    let argTokens = tokenizeValueFast(currentArg.strip(), false, currentArgStartLine, currentArgStartColumn, true)
    if argTokens.len == 1:
      args.add(argTokens[0])
    else:
      args.add(wrapSequence(argTokens, false, currentArgStartLine, currentArgStartColumn))
  
  return args

proc parseIdent(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let startIdx = pos.i
  
  # Parse identifier
  while pos.i < pos.input.len and isIdentChar(pos.input[pos.i]):
    consumeChar(pos)
  
  let identStr = extractString(pos, startIdx)
  
  # Look ahead for function call
  skipWhitespace(pos)
  if pos.i < pos.input.len and pos.input[pos.i] == '(':
    consumeChar(pos)  # skip '('
    let funcArgs = parseFunctionArgsFast(pos)
    
    if pos.i < pos.input.len and pos.input[pos.i] == ')':
      consumeChar(pos)  # skip ')'
    
    var token = createToken(vtkFunc, identStr, startLine, startColumn)
    token.children = funcArgs
    return token
  
  return createToken(vtkIdent, identStr, startLine, startColumn)

proc parseColor(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let startIdx = pos.i  # Start at '#'
  
  consumeChar(pos)  # Skip '#'
  
  # Parse hex digits
  while pos.i < pos.input.len and isHexChar(pos.input[pos.i]):
    consumeChar(pos)
  
  let color = extractString(pos, startIdx)
  return createToken(vtkColor, color, startLine, startColumn)

proc parseProperty(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let propStartIdx = pos.i
  
  # Find colon
  while pos.i < pos.input.len and pos.input[pos.i] != ':':
    consumeChar(pos)
  
  if pos.i >= pos.input.len or pos.input[pos.i] != ':':
    # Not a property (no colon found)
    pos.i = propStartIdx
    pos.line = startLine
    pos.column = startColumn
    return createToken(vtkIdent, "", startLine, startColumn)  # Placeholder
  
  # Extract property name
  let propName = extractString(pos, propStartIdx).strip()
  
  # Skip colon
  consumeChar(pos)
  
  skipWhitespace(pos)
  
  # Remember value position
  let valueStartLine = pos.line
  let valueStartColumn = pos.column
  let valueStartIdx = pos.i
  
  # Find end of property value
  var braceLevel = 0
  var parenLevel = 0
  while pos.i < pos.input.len:
    if pos.input[pos.i] == '{':
      braceLevel.inc()
      consumeChar(pos)
    elif pos.input[pos.i] == '}':
      if braceLevel > 0:
        braceLevel.dec()
        consumeChar(pos)
      else:
        break
    elif pos.input[pos.i] == '(':
      parenLevel.inc()
      consumeChar(pos)
    elif pos.input[pos.i] == ')':
      if parenLevel > 0:
        parenLevel.dec()
        consumeChar(pos)
      else:
        # This is a closing parenthesis that's not part of the property value
        # We should stop here and NOT consume it
        break
    elif pos.input[pos.i] == ';' and braceLevel == 0:
      break
    else:
      consumeChar(pos)
  
  # Extract value
  let valueEndIdx = pos.i
  let propValue = pos.input[valueStartIdx..<valueEndIdx].strip()
  
  # Skip semicolon if present
  if pos.i < pos.input.len and pos.input[pos.i] == ';':
    consumeChar(pos)
  
  # Create property token
  var propToken = createToken(vtkProperty, propName, startLine, startColumn)
  
  # Parse value
  if propValue.len > 0:
    propToken.children = tokenizeValueFast(propValue, false, valueStartLine, valueStartColumn, true)
  
  return propToken

proc parseRule(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  var selectors = newSeqOfCap[ValueToken](4)  # Most rules have few selectors
  
  # Remember start position for backtracking
  let startPos = pos.i
  let startPosLine = pos.line
  let startPosColumn = pos.column
  
  # Parse selectors
  while true:
    skipWhitespace(pos)
    
    if pos.i >= pos.input.len:
      break
    
    # Parse selector
    if pos.input[pos.i].isAlphaAscii or pos.input[pos.i] in {'-', '_', '%', '.', '#', '*', '[', ':'}:
      let selectorStartLine = pos.line
      let selectorStartColumn = pos.column
      let selectorStartIdx = pos.i
      
      # Parse the selector text - FIXED: removed \n and \r from the stopping chars
      # to allow selectors to span multiple lines
      while pos.i < pos.input.len and pos.input[pos.i] notin {',', '{', '}', ';'}:
        consumeChar(pos)
      
      let selectorText = pos.input[selectorStartIdx..<pos.i].strip()
      if selectorText.len > 0:
        selectors.add(createToken(vtkIdent, selectorText, selectorStartLine, selectorStartColumn))
    
    skipWhitespace(pos)
    
    # Check for comma or brace
    if pos.i < pos.input.len and pos.input[pos.i] == ',':
      consumeChar(pos)
      # Continue parsing selectors after comma
      continue
    elif pos.i < pos.input.len and pos.input[pos.i] == '{':
      break
    else:
      # Not a valid rule, reset and return empty
      pos.i = startPos
      pos.line = startPosLine
      pos.column = startPosColumn
      return createToken(vtkIdent, "", startLine, startColumn)
  
  # Skip opening brace
  consumeChar(pos)
  
  # Create rule token
  var ruleToken = createToken(vtkRule, "", startLine, startColumn)
  ruleToken.children = selectors
  
  # Parse rule body
  let bodyStartLine = pos.line
  let bodyStartColumn = pos.column
  let bodyStartIdx = pos.i
  
  var braceLevel = 1
  while pos.i < pos.input.len and braceLevel > 0:
    if pos.input[pos.i] == '{':
      braceLevel.inc()
      consumeChar(pos)
    elif pos.input[pos.i] == '}':
      braceLevel.dec()
      if braceLevel == 0:
        break
      consumeChar(pos)
    else:
      consumeChar(pos)
  
  # Extract and parse body content
  if pos.i > bodyStartIdx:
    # Don't strip the content as it affects line numbers
    let bodyContent = pos.input[bodyStartIdx..<pos.i]
    if bodyContent.len > 0:
      var bodyPos = TokenPosition(i: 0, line: bodyStartLine, column: bodyStartColumn, input: bodyContent)
      ruleToken.body = parseValueBodyFast(bodyPos, false)
  
  # Skip closing brace
  if pos.i < pos.input.len:
    consumeChar(pos)
  
  return ruleToken

proc parseAtRule(pos: var TokenPosition): ValueToken =
  # Get the starting position
  let startLine = pos.line
  let startColumn = pos.column
  
  # Skip '@'
  inc pos.i
  inc pos.column
  
  # Parse rule name manually
  let nameStartIdx = pos.i
  while pos.i < pos.input.len and (pos.input[pos.i].isAlphaAscii or pos.input[pos.i].isDigit or pos.input[pos.i] in {'-', '_'}):
    inc pos.i
    inc pos.column
  
  # Extract rule name
  let ruleName = if pos.i > nameStartIdx: pos.input[nameStartIdx..<pos.i] else: ""
  
  # Create at-rule token
  var atRuleToken = createToken(vtkAtRule, ruleName, startLine, startColumn)
  atRuleToken.children = @[]
  atRuleToken.body = @[]
  
  # Skip whitespace manually
  while pos.i < pos.input.len and pos.input[pos.i] in {' ', '\t', '\n', '\r'}:
    if pos.input[pos.i] == '\n':
      inc pos.line
      pos.column = 1
    else:
      inc pos.column
    inc pos.i
  
  # If we have parameters before '{' or ';', capture them without tokenizing
  let paramStartIdx = pos.i
  let paramStartLine = pos.line
  let paramStartColumn = pos.column
  
  # Collect everything until '{' or ';'
  while pos.i < pos.input.len and pos.input[pos.i] notin {'{', ';'}:
    if pos.input[pos.i] == '\n':
      inc pos.line
      pos.column = 1
    else:
      inc pos.column
    inc pos.i
  
  # Extract parameters as simple text
  let paramsStr = if pos.i > paramStartIdx: pos.input[paramStartIdx..<pos.i].strip() else: ""
  
  # Tokenize parameters
  if paramsStr.len > 0:
    var paramPos = TokenPosition(i: 0, line: paramStartLine, column: paramStartColumn, input: paramsStr)
    var paramTokens = newSeq[ValueToken]()
    
    # Specialized tokenizer for parameters
    while paramPos.i < paramPos.input.len:
      # Skip whitespace
      while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {' ', '\t', '\n', '\r'}:
        if paramPos.input[paramPos.i] == '\n':
          inc paramPos.line
          paramPos.column = 1
        else:
          inc paramPos.column
        inc paramPos.i
      
      if paramPos.i >= paramPos.input.len:
        break
      
      let c = paramPos.input[paramPos.i]
      case c
      of '(':
        paramTokens.add(createToken(vtkLParen, "(", paramPos.line, paramPos.column))
        inc paramPos.i
        inc paramPos.column
      of ')':
        paramTokens.add(createToken(vtkRParen, ")", paramPos.line, paramPos.column))
        inc paramPos.i
        inc paramPos.column
      of ',':
        paramTokens.add(createToken(vtkComma, ",", paramPos.line, paramPos.column))
        inc paramPos.i
        inc paramPos.column
      of '"', '\'':
        # Parse string
        let stringStartLine = paramPos.line
        let stringStartColumn = paramPos.column
        let quoteChar = paramPos.input[paramPos.i]
        
        inc paramPos.i
        inc paramPos.column
        
        let stringStartIdx = paramPos.i
        while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] != quoteChar:
          if paramPos.input[paramPos.i] == '\n':
            inc paramPos.line
            paramPos.column = 1
          else:
            inc paramPos.column
          inc paramPos.i
        
        let strValue = if paramPos.i > stringStartIdx: paramPos.input[stringStartIdx..<paramPos.i] else: ""
        
        if paramPos.i < paramPos.input.len:
          inc paramPos.i
          inc paramPos.column
        
        paramTokens.add(createToken(vtkString, strValue, stringStartLine, stringStartColumn))
      of '0'..'9', '.', '-':
        # Check if this is a number
        let numStartLine = paramPos.line
        let numStartColumn = paramPos.column
        let numStartIdx = paramPos.i
        
        # Handle negative sign
        if paramPos.input[paramPos.i] == '-':
          inc paramPos.i
          inc paramPos.column
        
        # Parse digits
        var hasDigits = false
        while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {'0'..'9'}:
          hasDigits = true
          inc paramPos.i
          inc paramPos.column
        
        # Handle decimal point
        if paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] == '.':
          inc paramPos.i
          inc paramPos.column
          
          while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {'0'..'9'}:
            hasDigits = true
            inc paramPos.i
            inc paramPos.column
        
        # Handle units
        let unitStartIdx = paramPos.i
        if hasDigits and paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {'a'..'z', 'A'..'Z', '%'}:
          while paramPos.i < paramPos.input.len and (paramPos.input[paramPos.i] in {'a'..'z', 'A'..'Z', '-', '%'}):
            inc paramPos.i
            inc paramPos.column
        
        # Create number token if we have digits
        if hasDigits:
          let numValue = paramPos.input[numStartIdx..<paramPos.i]
          let numValueFloat = try: parseFloat(numValue) except: 0.0
          
          if unitStartIdx < paramPos.i:
            let unit = paramPos.input[unitStartIdx..<paramPos.i]
            if unit == "%":
              paramTokens.add(createNumericToken(vtkPercentage, numValue & unit, numValueFloat, unit, numStartLine, numStartColumn))
            else:
              paramTokens.add(createNumericToken(vtkDimension, numValue & unit, numValueFloat, unit, numStartLine, numStartColumn))
          else:
            paramTokens.add(createNumericToken(vtkNumber, numValue, numValueFloat, "", numStartLine, numStartColumn))
        else:
          # This is likely an identifier that starts with a hyphen (like in CSS properties)
          let identStartLine = paramPos.line
          let identStartColumn = paramPos.column
          let identStartIdx = paramPos.i
          
          while paramPos.i < paramPos.input.len and (
                paramPos.input[paramPos.i].isAlphaAscii or 
                paramPos.input[paramPos.i].isDigit or 
                paramPos.input[paramPos.i] in {'-', '_'}
              ):
            inc paramPos.i
            inc paramPos.column
          
          let identValue = if paramPos.i > identStartIdx: paramPos.input[identStartIdx..<paramPos.i] else: ""
          
          # Check if this is a property (followed by colon)
          var isProperty = false
          var tempPos = paramPos.i
          
          # Skip whitespace to check for colon
          while tempPos < paramPos.input.len and paramPos.input[tempPos] in {' ', '\t', '\n', '\r'}:
            inc tempPos
          
          if tempPos < paramPos.input.len and paramPos.input[tempPos] == ':':
            isProperty = true
          
          if isProperty:
            # Skip whitespace before colon
            while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {' ', '\t', '\n', '\r'}:
              if paramPos.input[paramPos.i] == '\n':
                inc paramPos.line
                paramPos.column = 1
              else:
                inc paramPos.column
              inc paramPos.i
            
            # Skip colon
            inc paramPos.i  # Skip ':'
            inc paramPos.column
            
            # Skip whitespace after colon
            while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {' ', '\t', '\n', '\r'}:
              if paramPos.input[paramPos.i] == '\n':
                inc paramPos.line
                paramPos.column = 1
              else:
                inc paramPos.column
              inc paramPos.i
            
            # Remember value position
            let valueStartLine = paramPos.line
            let valueStartColumn = paramPos.column
            let valueStartIdx = paramPos.i
            
            # Find end of value
            while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] notin {')', ',', ';'}:
              if paramPos.input[paramPos.i] == '\n':
                inc paramPos.line
                paramPos.column = 1
              else:
                inc paramPos.column
              inc paramPos.i
            
            # Extract value
            let propValue = if paramPos.i > valueStartIdx: paramPos.input[valueStartIdx..<paramPos.i].strip() else: ""
            
            # Create property token
            var propToken = createToken(vtkProperty, identValue, identStartLine, identStartColumn)
            
            # Parse value
            if propValue.len > 0:
              # Just use a simple ident token for now to avoid recursion
              propToken.children = @[createToken(vtkIdent, propValue, valueStartLine, valueStartColumn)]
            
            paramTokens.add(propToken)
          else:
            # Just a regular identifier
            if identValue.len > 0:
              paramTokens.add(createToken(vtkIdent, identValue, identStartLine, identStartColumn))
      of 'a'..'z', 'A'..'Z', '_':
        # Parse identifier
        let identStartLine = paramPos.line
        let identStartColumn = paramPos.column
        let identStartIdx = paramPos.i
        
        while paramPos.i < paramPos.input.len and (
              paramPos.input[paramPos.i].isAlphaAscii or 
              paramPos.input[paramPos.i].isDigit or 
              paramPos.input[paramPos.i] in {'-', '_'}
            ):
          inc paramPos.i
          inc paramPos.column
        
        let identValue = if paramPos.i > identStartIdx: paramPos.input[identStartIdx..<paramPos.i] else: ""
        
        # Check if this is a property (followed by colon)
        var isProperty = false
        var tempPos = paramPos.i
        
        # Skip whitespace to check for colon
        while tempPos < paramPos.input.len and paramPos.input[tempPos] in {' ', '\t', '\n', '\r'}:
          inc tempPos
        
        if tempPos < paramPos.input.len and paramPos.input[tempPos] == ':':
          isProperty = true
        
        if isProperty:
          # Skip whitespace before colon
          while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {' ', '\t', '\n', '\r'}:
            if paramPos.input[paramPos.i] == '\n':
              inc paramPos.line
              paramPos.column = 1
            else:
              inc paramPos.column
            inc paramPos.i
          
          # Skip colon
          inc paramPos.i  # Skip ':'
          inc paramPos.column
          
          # Skip whitespace after colon
          while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] in {' ', '\t', '\n', '\r'}:
            if paramPos.input[paramPos.i] == '\n':
              inc paramPos.line
              paramPos.column = 1
            else:
              inc paramPos.column
            inc paramPos.i
          
          # Remember value position
          let valueStartLine = paramPos.line
          let valueStartColumn = paramPos.column
          let valueStartIdx = paramPos.i
          
          # Find end of value
          while paramPos.i < paramPos.input.len and paramPos.input[paramPos.i] notin {')', ',', ';'}:
            if paramPos.input[paramPos.i] == '\n':
              inc paramPos.line
              paramPos.column = 1
            else:
              inc paramPos.column
            inc paramPos.i
          
          # Extract value
          let propValue = if paramPos.i > valueStartIdx: paramPos.input[valueStartIdx..<paramPos.i].strip() else: ""
          
          # Create property token
          var propToken = createToken(vtkProperty, identValue, identStartLine, identStartColumn)
          
          # Parse value
          if propValue.len > 0:
            # Just use a simple ident token for now to avoid recursion
            propToken.children = @[createToken(vtkIdent, propValue, valueStartLine, valueStartColumn)]
          
          paramTokens.add(propToken)
        else:
          # Just a regular identifier
          paramTokens.add(createToken(vtkIdent, identValue, identStartLine, identStartColumn))
      of ':':
        # This is likely a standalone colon (unexpected but possible)
        paramTokens.add(createToken(vtkIdent, ":", paramPos.line, paramPos.column))
        inc paramPos.i
        inc paramPos.column
      else:
        # Skip unknown characters
        inc paramPos.i
        inc paramPos.column
    
    atRuleToken.children = paramTokens
  
  # Parse body if we have a '{'
  if pos.i < pos.input.len and pos.input[pos.i] == '{':
    # Skip '{'
    inc pos.i
    inc pos.column
    
    let bodyStartIdx = pos.i
    let bodyStartLine = pos.line
    let bodyStartColumn = pos.column
    
    # Find matching '}'
    var braceLevel = 1
    while pos.i < pos.input.len and braceLevel > 0:
      if pos.input[pos.i] == '{':
        inc braceLevel
      elif pos.input[pos.i] == '}':
        dec braceLevel
      
      if pos.input[pos.i] == '\n':
        inc pos.line
        pos.column = 1
      else:
        inc pos.column
      
      # Only increment index if we're not at the closing brace
      if not (pos.input[pos.i] == '}' and braceLevel == 0):
        inc pos.i
      else: 
        break
    
    # Extract body content
    let bodyContent = if pos.i > bodyStartIdx: pos.input[bodyStartIdx..<pos.i] else: ""
    
    # Manually parse body content
    if bodyContent.len > 0:
      # Parse body as separate CSS content
      var bodyPos = TokenPosition(i: 0, line: bodyStartLine, column: bodyStartColumn, input: bodyContent)
      
      # Parse rules in the body
      while bodyPos.i < bodyPos.input.len:
        # Skip whitespace
        while bodyPos.i < bodyPos.input.len and bodyPos.input[bodyPos.i] in {' ', '\t', '\n', '\r'}:
          if bodyPos.input[bodyPos.i] == '\n':
            inc bodyPos.line
            bodyPos.column = 1
          else:
            inc bodyPos.column
          inc bodyPos.i
          
        if bodyPos.i >= bodyPos.input.len:
          break
          
        # Parse rule or property
        if bodyPos.input[bodyPos.i] == ':' or bodyPos.input[bodyPos.i].isAlphaAscii or 
           bodyPos.input[bodyPos.i] in {'.', '#', '[', '*', '_', '-'}:
          # Try to parse as rule
          let rule = parseRule(bodyPos)
          if rule.children.len > 0:
            atRuleToken.body.add(rule)
          else:
            # Skip to next structure
            while bodyPos.i < bodyPos.input.len and bodyPos.input[bodyPos.i] notin {'{', ';', '}'}:
              inc bodyPos.i
              if bodyPos.i < bodyPos.input.len:
                if bodyPos.input[bodyPos.i] == '\n':
                  inc bodyPos.line
                  bodyPos.column = 1
                else:
                  inc bodyPos.column
            
            if bodyPos.i < bodyPos.input.len:
              inc bodyPos.i
        elif bodyPos.input[bodyPos.i] == '@':
          # Handle nested at-rule
          let nestedAtRule = parseAtRule(bodyPos)
          atRuleToken.body.add(nestedAtRule)
        else:
          # Skip unknown character
          inc bodyPos.i
          if bodyPos.i < bodyPos.input.len:
            if bodyPos.input[bodyPos.i-1] == '\n':
              inc bodyPos.line
              bodyPos.column = 1
            else:
              inc bodyPos.column
    
    # Skip closing '}'
    if pos.i < pos.input.len and pos.input[pos.i] == '}':
      inc pos.i
      inc pos.column
  elif pos.i < pos.input.len and pos.input[pos.i] == ';':
    # Skip ';'
    inc pos.i
    inc pos.column
  
  return atRuleToken

# Main parsing functions
proc parseValueBodyFast*(pos: var TokenPosition, wrapRoot: bool = true): seq[ValueToken] =
  var tokens = newSeqOfCap[ValueToken](INITIAL_TOKEN_CAPACITY)
  
  while pos.i < pos.input.len:
    skipWhitespace(pos)
    if pos.i >= pos.input.len:
      break
    
    # Look for property or rule
    let currentIdx = pos.i
    let currentLine = pos.line
    let currentColumn = pos.column
    
    # Fast classification of next token type
    if pos.input[pos.i] == '@':
      tokens.add(parseAtRule(pos))
    # FIXED: Added all selector beginning characters
    elif pos.input[pos.i].isAlphaAscii or pos.input[pos.i] in {'-', '_', '.', '#', '[', ':', '*', '%'}:
      # Optimize lookahead for property vs rule
      var isProperty = false
      var lookAhead = pos.i
      
      # Quick scan for colon or brace
      while lookAhead < pos.input.len:
        if pos.input[lookAhead] == ':':
          isProperty = true
          break
        elif pos.input[lookAhead] == '{':
          isProperty = false
          break
        elif pos.input[lookAhead] in {';', '}'}:
          break
        inc lookAhead
      
      if isProperty:
        tokens.add(parseProperty(pos))
      else:
        # Try parse as rule
        let ruleToken = parseRule(pos)
        if ruleToken.value.len > 0 or ruleToken.children.len > 0:
          tokens.add(ruleToken)
        else:
          # Skip unknown content
          while pos.i < pos.input.len and pos.input[pos.i] notin {';', '}'}:
            consumeChar(pos)
          if pos.i < pos.input.len:
            consumeChar(pos)
    else:
      # Skip unknown character
      consumeChar(pos)
  
  return tokens

# Parse entire CSS document
proc parseCSSDocument*(input: string): seq[ValueToken] =
  if input.len == 0:
    return @[]
    
  var pos = TokenPosition(i: 0, line: 1, column: 1, input: input)
  var tokens = newSeqOfCap[ValueToken](32)
  
  while pos.i < pos.input.len:
    skipWhitespace(pos)
    skipComment(pos)
    
    if pos.i >= pos.input.len:
      break
      
    if pos.input[pos.i] == '@':
      # Parse at-rule
      tokens.add(parseAtRule(pos))
    elif pos.input[pos.i].isAlphaAscii or pos.input[pos.i] in {'-', '_', '.', '#', '[', ':', '*', '%'}:
      # Try to parse as rule
      let savedPos = pos
      let rule = parseRule(pos)
      if rule.value.len > 0 or rule.children.len > 0:
        tokens.add(rule)
      else:
        # Reset position
        pos = savedPos
        
        # Check if this might be a property
        if isPotentialProperty(pos):
          let propToken = parseProperty(pos)
          if propToken.kind == vtkProperty and propToken.value.len > 0:
            tokens.add(propToken)
          else:
            # Try as standalone identifier
            pos = savedPos
            let identToken = parseIdent(pos)
            if identToken.value.len > 0:
              tokens.add(identToken)
            else:
              # Skip to next structure if all parsing attempts failed
              while pos.i < pos.input.len and pos.input[pos.i] notin {';', '{', '}'}:
                consumeChar(pos)
              if pos.i < pos.input.len:
                consumeChar(pos)
        else:
          # Try as standalone identifier
          let identToken = parseIdent(pos)
          if identToken.value.len > 0:
            tokens.add(identToken)
          else:
            # Skip to next structure
            while pos.i < pos.input.len and pos.input[pos.i] notin {';', '{', '}'}:
              consumeChar(pos)
            if pos.i < pos.input.len:
              consumeChar(pos)
    else:
      # Skip unknown character
      consumeChar(pos)
  
  return tokens

proc parseChar(pos: var TokenPosition): ValueToken =
  let startLine = pos.line
  let startColumn = pos.column
  let op = $pos.input[pos.i]  # Convert char to string
  
  # Consume the operator character
  consumeChar(pos)
  
  return createToken(vtkIdent, op, startLine, startColumn)

proc tokenizeValueFast*(input: string, wrapRoot: bool = true, startLine: int = 1, startColumn: int = 1, isPropertyValue: bool = false): seq[ValueToken] =
  if input.len == 0:
    return @[]
  
  # Apply replacements first
  var processedInput = input
  for replacementFrom, replacementTo in REPLACEMENTS:
    processedInput = processedInput.replace(replacementFrom, replacementTo)
  
  # Remove trailing semicolon and !important if present
  if processedInput.endsWith(";"):
    processedInput = processedInput[0..^2]
  if processedInput.endsWith(" !important"):
    processedInput = processedInput[0..^12]
  
  # Initialize position tracker
  var pos = TokenPosition(i: 0, line: startLine, column: startColumn, input: processedInput)
  var tokens = newSeqOfCap[ValueToken](INITIAL_TOKEN_CAPACITY)
  
  # Check if input looks like a standalone property declaration
  if not isPropertyValue and hasPropertySyntax(processedInput) and wrapRoot:
    # Try to parse as a top-level property
    var propPos = TokenPosition(i: 0, line: startLine, column: startColumn, input: processedInput)
    let propToken = parseProperty(propPos)
    if propToken.kind == vtkProperty and propToken.value.len > 0:
      return @[propToken]
  
  # Only try to parse as a CSS document if we're NOT in property value mode AND we're at the top level
  # This prevents infinite recursion with at-rule parameters
  if not isPropertyValue and processedInput.contains("{") and wrapRoot:
    # Try to parse as CSS document
    return parseCSSDocument(processedInput)
  
  # Main tokenization loop for regular token parsing
  while pos.i < pos.input.len:
    skipWhitespace(pos)
    skipComment(pos)

    if pos.i >= pos.input.len:
      break
    
    let c = pos.input[pos.i]
    case c
    of '@':
      # When in property value mode, don't recursively parse at-rules
      if isPropertyValue:
        # Just treat it as an identifier
        tokens.add(parseIdent(pos))
      else:
        tokens.add(parseAtRule(pos))
    of '-':
      # Check if it's a negative number
      if pos.i + 1 < pos.input.len and (pos.input[pos.i + 1] in {'0'..'9', '.'}):
        tokens.add(parseNumber(pos))
      # Check if it might be a property
      elif not isPropertyValue and isPotentialProperty(pos):
        tokens.add(parseProperty(pos))
      else:
        tokens.add(parseIdent(pos))
    of '0'..'9', '.':
      tokens.add(parseNumber(pos))
    of '"', '\'':
      tokens.add(parseString(pos))
    of '!':
      tokens.add(parseImportant(pos))
    of 'a'..'z', 'A'..'Z', '_':
      # Check if this might be a property if we're not already parsing a property value
      if not isPropertyValue and isPotentialProperty(pos):
        tokens.add(parseProperty(pos))
      else:
        # Regular identifier or function
        tokens.add(parseIdent(pos))
    of '#':
      # Always parse '#' followed by hex digits as a color
      if pos.i + 1 < pos.input.len and isHexChar(pos.input[pos.i + 1]):
        tokens.add(parseColor(pos))
      else:
        # Handle as ID selector in appropriate context
        if not isPropertyValue:
          # Try parse as a rule in document context
          let savedPos = pos
          let ruleToken = parseRule(pos)
          if ruleToken.value.len > 0 or ruleToken.children.len > 0:
            return @[ruleToken]
          pos = savedPos
        # Default to color parsing
        tokens.add(parseColor(pos))
    of ',':
      tokens.add(createToken(vtkComma, ",", pos.line, pos.column))
      consumeChar(pos)
    of '/':
      tokens.add(createToken(vtkSlash, "/", pos.line, pos.column))
      consumeChar(pos)
    of '(':
      tokens.add(createToken(vtkLParen, "(", pos.line, pos.column))
      consumeChar(pos)
    of ')':
      tokens.add(createToken(vtkRParen, ")", pos.line, pos.column))
      consumeChar(pos)
    of ':':
      # This is a colon, we should consume it and not get stuck
      tokens.add(createToken(vtkIdent, ":", pos.line, pos.column))
      consumeChar(pos)
    of '[':
      # This is likely an attribute selector in a rule context
      if not isPropertyValue:
        let savedPos = pos
        let ruleToken = parseRule(pos)
        if ruleToken.value.len > 0 or ruleToken.children.len > 0:
          return @[ruleToken]
        pos = savedPos
      # Skip if we can't handle it
      consumeChar(pos)
    of '~', '=', '|', '^', '$', '*', '+', '>', '<':
      tokens.add(parseChar(pos))
    else:
      consumeChar(pos)  # Skip unknown characters
  
  # Handle wrapping if requested
  if wrapRoot and tokens.len > 0:
    var groups: seq[seq[ValueToken]] = @[]
    var currentGroup = newSeqOfCap[ValueToken](tokens.len div 2 + 1)
    
    for token in tokens:
      if token.kind == vtkComma:
        if currentGroup.len > 0:
          groups.add(currentGroup)
          currentGroup = newSeqOfCap[ValueToken](4)
      else:
        currentGroup.add(token)
    
    if currentGroup.len > 0:
      groups.add(currentGroup)
    
    var resultTokens = newSeqOfCap[ValueToken](groups.len)
    for group in groups:
      if group.len == 1:
        resultTokens.add(group[0])
      elif group.len > 1:
        let groupLine = if group.len > 0: group[0].line else: startLine
        let groupColumn = if group.len > 0: group[0].column else: startColumn
        resultTokens.add(wrapSequence(group, false, groupLine, groupColumn))
    
    return resultTokens
  else:
    return tokens

# Public API
proc parseValue*(input: string): seq[ValueToken] =
  return tokenizeValueFast(input)

# String representation
proc `$`*(vt: ValueToken): string =
  case vt.kind
  of vtkProperty:
    let childrenStr = if vt.children.len > 0: ": " & vt.children.map(`$`).join(" ") else: ""
    return "[" & vt.value & childrenStr & "]"
  of vtkAtRule:
    result = "@" & vt.value
    if vt.body.len > 0:
      result.add(" {" & vt.body.map(`$`).join(", ") & "}")
    return result
  of vtkRule:
    result = "[" & vt.value & " {"
    if vt.body.len > 0:
      result.add(" " & vt.body.map(`$`).join(", ") & " ")
    result.add("}]")
    return result
  of vtkNumber, vtkDimension, vtkPercentage, vtkColor, vtkString, vtkIdent:
    return "[" & vt.value & "]"
  of vtkFunc:
    return "[" & vt.value & "(" & vt.children.map(`$`).join(", ") & ")]"
  of vtkSequence:
    return "(" & vt.children.map(`$`).join(" ") & ")"
  of vtkComma:
    return "[,]"
  of vtkSlash:
    return "[/]"
  of vtkLParen:
    return "[(]"
  of vtkRParen:
    return "[)]"
  of vtkImportant:
    return "[!important]"
    
proc `$`*(vts: seq[ValueToken]): string =
  return vts.map(`$`).join(", ")

proc treeRepr*(vt: ValueToken, indent: string = ""): string =
  let newIndent = indent & "    "
  case vt.kind
  of vtkProperty:
    var childrenStr = ""
    for child in vt.children:
      childrenStr.add("\n" & treeRepr(child, newIndent))
    return indent & "Property(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column & childrenStr
  of vtkNumber:
    return indent & "Number(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
  of vtkDimension:
    return indent & "Dimension(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
  of vtkPercentage:
    return indent & "Percentage(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
  of vtkColor:
    return indent & "Color(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
  of vtkString:
    return indent & "String(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
  of vtkIdent:
    return indent & "Ident(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
  of vtkFunc:
    var childrenStr = ""
    for child in vt.children:
      childrenStr.add("\n" & treeRepr(child, newIndent) & ",")
    return indent & "Func(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column & childrenStr & "\n" & indent & ")"
  of vtkSequence:
    var childrenStr = ""
    for child in vt.children:
      childrenStr.add("\n" & treeRepr(child, newIndent))
    return indent & "Sequence @ line " & $vt.line & ", col " & $vt.column & childrenStr & "\n" & indent & ")"
  of vtkComma:
    return indent & "Comma @ line " & $vt.line & ", col " & $vt.column
  of vtkSlash:
    return indent & "Slash @ line " & $vt.line & ", col " & $vt.column
  of vtkLParen:
    return indent & "LParen @ line " & $vt.line & ", col " & $vt.column
  of vtkRParen:
    return indent & "RParen @ line " & $vt.line & ", col " & $vt.column
  of vtkImportant:
    return indent & "Important @ line " & $vt.line & ", col " & $vt.column
  of vtkAtRule:
    var result = indent & "AtRule(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
    
    if vt.children.len > 0:
      result.add("\n")
      for child in vt.children:
        result.add(treeRepr(child, newIndent) & "\n")
    
    if vt.body.len > 0:
      result.add("\n" & indent & "body {\n")
      for item in vt.body:
        result.add(treeRepr(item, newIndent) & "\n")
      result.add(indent & "}")
    
    return result
  of vtkRule:
    var result = indent & "Rule @ line " & $vt.line & ", col " & $vt.column
    
    if vt.children.len > 0:
      result.add("(")
      for i, child in vt.children:
        if i > 0:
          result.add(" ")
        result.add(child.value)
      result.add(")")
    else:
      result.add("()")
    
    if vt.body.len > 0:
      result.add(" {\n")
      for item in vt.body:
        result.add(treeRepr(item, newIndent) & "\n")
      result.add(indent & "}")
    else:
      result.add(" {}")
    
    return result

proc treeRepr*(vts: seq[ValueToken]): string =
  var lines = newSeq[string]()
  for vt in vts:
    lines.add(treeRepr(vt))
  return lines.join(",\n")

import times
when isMainModule:
  let time = getTime()
  # let content = readFile("src/css/analyzer/bootstrap.css")
  let content = """
@keyframes 'test' {
  from {
    color: red;
  }
}

asdasd

test: 5px
"""
  let tokens = tokenizeValueFast(content)
  let endTime = getTime() - time

  # echo tokens[1].treeRepr
  for token in tokens:
    echo token.treeRepr
  echo "Tokenized in: " & $endTime