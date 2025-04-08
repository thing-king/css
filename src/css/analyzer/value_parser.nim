import options, strutils, sequtils, tables
import pkg/colors

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
    vtkImportant,   # New token type for !important
    vtkSequence,
    vtkAtRule,
    vtkProperty,
    vtkRule         # New token type for CSS rule blocks like 'from', 'to', etc.

  ValueToken* = object
    case kind*: ValueTokenKind
    of vtkAtRule, vtkRule:  # Modified to include vtkRule
      body*: seq[ValueToken]
    else:
      discard
    value*: string
    children*: seq[ValueToken]
    case hasNumValue*: bool
    of true:
      numValue*: float
      unit*: string
    of false: discard

# Wrap tokens in a sequence if more than one token (unless forced not to).
proc wrapSequence*(tokens: seq[ValueToken], isRoot: bool = false): ValueToken =
  if tokens.len == 1 and not isRoot:
    return tokens[0]
  else:
    return ValueToken(kind: vtkSequence, value: "", children: tokens)

# Forward declaration to allow mutual recursion
proc parseValueBody*(input: string, wrapRoot: bool = true): seq[ValueToken]

proc tokenizeValue*(input: string, wrapRoot: bool = true): seq[ValueToken] {.gcsafe.} =
  var tokens: seq[ValueToken] = @[]
  var i = 0

  proc skipWhitespace(i: var int, input: string) =
    while i < input.len and input[i] in {' ', '\t', '\n', '\r'}:
      inc i

  proc parseString(i: var int, input: string): ValueToken =
    let quoteChar = input[i]  # either " or '
    inc i  # skip opening quote
    var strVal = ""
    while i < input.len and input[i] != quoteChar:
      strVal.add(input[i])
      inc i
    if i < input.len and input[i] == quoteChar:
      inc i  # skip closing quote
    return ValueToken(kind: vtkString, value: strVal)

  proc parseNumber(i: var int, input: string): ValueToken =
    var numStr = ""
    # Handle negative numbers - check for minus sign
    if i < input.len and input[i] == '-':
      numStr.add(input[i])
      inc i
    
    # Parse digits before decimal point
    while i < input.len and input[i] in {'0'..'9'}:
      numStr.add(input[i])
      inc i
    
    # Parse decimal point and digits after it
    if i < input.len and input[i] == '.':
      numStr.add(input[i])
      inc i
      while i < input.len and input[i] in {'0'..'9'}:
        numStr.add(input[i])
        inc i
    
    # Check for unit
    var unit = ""
    if i < input.len and (input[i] in {'a'..'z', 'A'..'Z', '%'}):
      while i < input.len and (input[i] in {'a'..'z', 'A'..'Z', '-', '%'}):
        unit.add(input[i])
        inc i
    
    # Return appropriate token based on unit
    if unit == "%":
      return ValueToken(kind: vtkPercentage, value: numStr & unit,
                        hasNumValue: true, numValue: parseFloat(numStr))
    elif unit.len > 0:
      return ValueToken(kind: vtkDimension, value: numStr & unit,
                        hasNumValue: true, numValue: parseFloat(numStr), unit: unit)
    else:
      return ValueToken(kind: vtkNumber, value: numStr,
                        hasNumValue: true, numValue: parseFloat(numStr))

  proc parseProperty(i: var int, input: string): ValueToken =
    # Find the property name (everything before the colon)
    var startPos = i
    var colonPos = -1
    
    # Search for the colon
    while i < input.len:
      if input[i] == ':':
        colonPos = i
        break
      inc i
    
    if colonPos == -1:
      # This wasn't a property (no colon found)
      # Reset position and return nothing
      i = startPos
      return ValueToken(kind: vtkIdent, value: "")  # Placeholder that will be ignored
    
    # Extract the property name
    let propertyName = input[startPos..<colonPos].strip()
    
    # Skip the colon
    inc i  # Now i points to the character after the colon
    
    # Find the end of the property value (usually at semicolon or closing brace)
    var valueStart = i
    var braceLevel = 0
    
    while i < input.len:
      if input[i] == '{':
        braceLevel.inc()
      elif input[i] == '}':
        if braceLevel > 0:
          braceLevel.dec()
        else:
          # End of containing block
          break
      elif input[i] == ';' and braceLevel == 0:
        # End of property
        break
      
      inc i
    
    # Extract the property value
    let propertyValue = input[valueStart..<i].strip()
    
    # Skip the semicolon if present
    if i < input.len and input[i] == ';':
      inc i
    
    # Create the property token
    var propertyToken = ValueToken(kind: vtkProperty, value: propertyName)
    
    # Parse the value into tokens and add them as children
    if propertyValue.len > 0:
      propertyToken.children = tokenizeValue(propertyValue, wrapRoot=false)
    
    return propertyToken

  # New procedure to parse CSS rules like 'from', 'to', etc.
  proc parseRule(i: var int, input: string): ValueToken =
    var selectors: seq[ValueToken] = @[]
    var startPos = i
    
    # Parse all selectors before the opening brace
    while true:
      # Skip whitespace
      skipWhitespace(i, input)
      
      # Parse a selector (could be an identifier, or something more complex in a full CSS parser)
      if i < input.len and (input[i].isAlphaAscii or input[i] in {'-', '_', '%', '.', '#', '*', '[', ':'}):
        var selectorStart = i
        
        # Parse the selector
        while i < input.len and input[i] notin {',', '{', '}', ';', '\n', '\r'}:
          inc i
        
        var selectorText = input[selectorStart..<i].strip()
        if selectorText.len > 0:
          # Add this selector to our list
          selectors.add(ValueToken(kind: vtkIdent, value: selectorText))
      
      # Skip whitespace
      skipWhitespace(i, input)
      
      # Check if we have a comma (more selectors) or opening brace (end of selectors)
      if i < input.len and input[i] == ',':
        # Add the comma to our selectors
        # selectors.add(ValueToken(kind: vtkComma, value: ","))
        inc i
        # Continue to parse more selectors
        continue
      elif i < input.len and input[i] == '{':
        # We've reached the opening brace, break out
        break
      else:
        # Not a valid rule, reset position
        i = startPos
        return ValueToken(kind: vtkIdent, value: "")  # Placeholder
    
    # Skip the opening brace
    inc i
    
    # Create the rule token with selectors as children
    var ruleToken = ValueToken(kind: vtkRule, value: "")
    ruleToken.children = selectors
    
    # Parse the rule body
    var bodyContent = ""
    var braceLevel = 1
    
    while i < input.len and braceLevel > 0:
      if input[i] == '{':
        braceLevel.inc()
      elif input[i] == '}':
        braceLevel.dec()
      
      if braceLevel > 0:  # Don't include the final closing brace
        bodyContent.add(input[i])
      
      inc i
    
    # Parse the body content recursively
    if bodyContent.len > 0:
      ruleToken.body = parseValueBody(bodyContent.strip())  # <-- FIXED: Use parseValueBody instead
    
    return ruleToken

  proc parseAtRule(i: var int, input: string): ValueToken =
    # Skip the '@'
    inc i
    
    # Parse the at-rule name (like "property", "media", etc.)
    var ruleName = ""
    while i < input.len and (input[i].isAlphaAscii or input[i].isDigit or input[i] in {'-', '_'}):
      ruleName.add(input[i])
      inc i
    
    # Create the token with just the at-rule name
    var atRuleToken = ValueToken(kind: vtkAtRule, value: ruleName)
    
    # Parse any parameters that follow (before the opening brace if present)
    skipWhitespace(i, input)
    
    var paramStr = ""
    var startParams = i
    
    # Collect everything until we hit a '{' or end of input
    while i < input.len:
      if input[i] == '{':
        # Found the opening of the body
        break
      elif input[i] == ';' and not (i > 0 and input[i-1] == '\\'):
        # End of rule without a body
        break
      else:
        paramStr.add(input[i])
        inc i
    
    # Parse the params into tokens and add them as children
    if paramStr.strip().len > 0:
      atRuleToken.children = tokenizeValue(paramStr.strip(), wrapRoot=false)
    
    # If we have a body block, parse it too
    if i < input.len and input[i] == '{':
      inc i  # Skip '{'
      
      # Find the matching closing brace
      var bodyContent = ""
      var braceLevel = 1
      
      while i < input.len and braceLevel > 0:
        if input[i] == '{':
          braceLevel.inc()
        elif input[i] == '}':
          braceLevel.dec()
        
        if braceLevel > 0:  # Don't include the final closing brace
          bodyContent.add(input[i])
        
        inc i
      
      # Parse the body content recursively
      if bodyContent.len > 0:
        # FIXED: Use parseValueBody instead of tokenizeValue to avoid infinite recursion
        atRuleToken.body = parseValueBody(bodyContent.strip())
    elif i < input.len and input[i] == ';':
      inc i  # Skip ';'
    
    return atRuleToken

  # New function to parse !important
  proc parseImportant(i: var int, input: string): ValueToken =
    # Store the current position
    let startPos = i
    # Skip the '!'
    inc i
    # Check if this is specifically "!important"
    let remainder = "important"
    var matched = true
    
    for j in 0..<remainder.len:
      if i + j >= input.len or input[i + j] != remainder[j]:
        matched = false
        break
    
    if matched:
      # This is exactly "!important", so consume it
      i += remainder.len
      return ValueToken(kind: vtkImportant, value: "!important")
    else:
      # This is not "!important", so reset position
      i = startPos
      # Just return the '!' as an identifier
      inc i
      return ValueToken(kind: vtkIdent, value: "!")

  proc parseFunctionArgs(input: string, start: int): (seq[ValueToken], int) =
    var args: seq[ValueToken] = @[]
    var currentArg = ""
    var parenLevel = 0
    var j = start
    while j < input.len:
      let c = input[j]
      if c == '(':
        parenLevel.inc()
        currentArg.add(c)
      elif c == ')' and parenLevel > 0:
        parenLevel.dec()
        currentArg.add(c)
      elif c == ')' and parenLevel == 0:
        break
      elif c == ',' and parenLevel == 0:
        let argTokens = tokenizeValue(currentArg.strip(), wrapRoot=false)
        if argTokens.len == 1:
          args.add(argTokens[0])
        else:
          args.add(wrapSequence(argTokens))
        currentArg = ""
      else:
        currentArg.add(c)
      inc j
    if currentArg.len > 0:
      let argTokens = tokenizeValue(currentArg.strip(), wrapRoot=false)
      if argTokens.len == 1:
        args.add(argTokens[0])
      else:
        args.add(wrapSequence(argTokens))
    return (args, j)


  proc parseIdent(i: var int, input: string): ValueToken =
    var identStr = ""
    while i < input.len and (input[i].isAlphaAscii or input[i].isDigit or input[i] in {'-', '_'}):
      identStr.add(input[i])
      inc i
    
    # Check if this is a CSS selector rule like 'from', 'to', etc.
    # We need to look ahead to see if there's a '{' after potential whitespace
    var lookAheadPos = i
    skipWhitespace(lookAheadPos, input)
    
    if lookAheadPos < input.len and input[lookAheadPos] == '{':
      # Handle as a CSS rule
      i = lookAheadPos  # Update the index to the position of '{'
      # Parse the rule
      var ruleToken = ValueToken(kind: vtkRule, value: identStr)
      
      # Skip the opening brace
      inc i
      
      # Parse the rule body
      var bodyContent = ""
      var braceLevel = 1
      
      while i < input.len and braceLevel > 0:
        if input[i] == '{':
          braceLevel.inc()
        elif input[i] == '}':
          braceLevel.dec()
        
        if braceLevel > 0:  # Don't include the final closing brace
          bodyContent.add(input[i])
        
        inc i
      
      # Parse the body content recursively
      if bodyContent.len > 0:
        ruleToken.body = parseValueBody(bodyContent.strip())  # <-- FIXED: Use parseValueBody instead
      
      return ruleToken
    
    # If not a rule, continue with normal ident parsing
    if i < input.len and input[i] == '(':
      inc i  # skip '('
      let (funcArgs, newIndex) = parseFunctionArgs(input, i)
      i = newIndex
      if i < input.len and input[i] == ')' :
         inc i
      return ValueToken(kind: vtkFunc, value: identStr, children: funcArgs)
    else:
      return ValueToken(kind: vtkIdent, value: identStr)


  while i < input.len:
    skipWhitespace(i, input)
    if i >= input.len: break
    
    # CRITICAL FIX: Check for at-rules (@keyframes, etc.) FIRST before any other pattern
    if input[i] == '@':
      tokens.add(parseAtRule(i, input))
      continue
    
    # Now check if this could be a rule (selector followed by {)
    var lookAheadPos = i
    var foundOpenBrace = false
    
    while lookAheadPos < input.len and not foundOpenBrace:
      if input[lookAheadPos] == '{':
        foundOpenBrace = true
        break
      elif input[lookAheadPos] in {';', '}', '\n', '\r'}:
        # Stop looking if we hit these characters
        break
      inc lookAheadPos
    
    if foundOpenBrace:
      # This appears to be a rule, try to parse it
      tokens.add(parseRule(i, input))
      continue
    
    lookAheadPos = i
    var foundColon = false
    
    # Look ahead for a colon
    while lookAheadPos < input.len and not foundColon:
      if input[lookAheadPos] == ':':
        foundColon = true
        break
      elif input[lookAheadPos] in {';', '{', '}', '\n', '\r'}:
        # Stop looking if we hit these characters before finding a colon
        break
      inc lookAheadPos
    
    if foundColon:
      # We found a property pattern, parse it
      tokens.add(parseProperty(i, input))
      continue

    # Main change: Check for negative numbers before identifiers
    # A negative number is a minus sign followed by a digit or decimal point
    if input[i] == '-' and i + 1 < input.len and (input[i + 1] in {'0'..'9', '.'}):
      tokens.add(parseNumber(i, input))
    elif input[i] in {'0'..'9', '.'}:
      tokens.add(parseNumber(i, input))
    elif input[i] in {'"', '\''}:
      tokens.add(parseString(i, input))
    elif input[i] == '!':
      tokens.add(parseImportant(i, input))
    elif input[i] in {'a'..'z', 'A'..'Z', '-', '_'}:
      tokens.add(parseIdent(i, input))
    elif input[i] == '#':
      var color = "#"
      inc i
      while i < input.len and input[i] in {'0'..'9', 'a'..'f', 'A'..'F'}:
        color.add(input[i])
        inc i
      tokens.add(ValueToken(kind: vtkColor, value: color))
    elif input[i] == ',':
      tokens.add(ValueToken(kind: vtkComma, value: ","))
      inc i
    elif input[i] == '/':
      tokens.add(ValueToken(kind: vtkSlash, value: "/"))
      inc i
    elif input[i] == '(':
      tokens.add(ValueToken(kind: vtkLParen, value: "("))
      inc i
    elif input[i] == ')':
      tokens.add(ValueToken(kind: vtkRParen, value: ")"))
      inc i
    else:
      inc i

  if wrapRoot:
    var groups: seq[seq[ValueToken]] = @[]
    var currentGroup: seq[ValueToken] = @[]
    for token in tokens:
      if token.kind == vtkComma:
        groups.add(currentGroup)
        currentGroup = @[]
      else:
        currentGroup.add(token)
    if currentGroup.len > 0:
      groups.add(currentGroup)
    var resultTokens: seq[ValueToken] = @[]
    for group in groups:
      if group.len == 1:
        resultTokens.add(group[0])
      elif group.len > 1:
        resultTokens.add(wrapSequence(group, isRoot=false))
    return resultTokens
  else:
    return tokens

# Add a separate function for parsing body content to avoid infinite recursion
proc parseValueBody*(input: string, wrapRoot: bool = true): seq[ValueToken] =
  var tokens: seq[ValueToken] = @[]
  var i = 0
  
  proc skipWhitespace(i: var int, input: string) =
    while i < input.len and input[i] in {' ', '\t', '\n', '\r'}:
      inc i

  # Helper function to parse rule selectors (like "from, to" in @keyframes)
  proc parseRuleSelectors(i: var int, input: string): seq[ValueToken] =
    var selectors: seq[ValueToken] = @[]
    var selectorStart = i
    
    while i < input.len:
      skipWhitespace(i, input)
      
      # Parse a selector
      if i < input.len and input[i] notin {',', '{', '}', ';'}:
        selectorStart = i
        
        # Parse the selector text
        while i < input.len and input[i] notin {',', '{', '}', ';'}:
          inc i
        
        let selectorText = input[selectorStart..<i].strip()
        if selectorText.len > 0:
          selectors.add(ValueToken(kind: vtkIdent, value: selectorText))
      
      skipWhitespace(i, input)
      
      # Check if we have more selectors or reached the end
      if i < input.len and input[i] == ',':
        inc i  # Skip comma
        continue
      else:
        break
    
    return selectors

  # Helper function to parse a rule block
  proc parseNestedRule(i: var int, input: string): ValueToken =
    # Parse selectors
    var selectors = parseRuleSelectors(i, input)
    
    # Create rule token
    var ruleToken = ValueToken(kind: vtkRule, value: "")
    ruleToken.children = selectors
    
    # Check for opening brace
    skipWhitespace(i, input)
    if i < input.len and input[i] == '{':
      inc i  # Skip opening brace
      
      # Parse rule body
      var bodyContent = ""
      var braceLevel = 1
      
      while i < input.len and braceLevel > 0:
        if input[i] == '{':
          braceLevel.inc()
        elif input[i] == '}':
          braceLevel.dec()
        
        if braceLevel > 0:  # Don't include the final closing brace
          bodyContent.add(input[i])
        
        inc i
      
      # Parse the body content
      if bodyContent.len > 0:
        ruleToken.body = parseValueBody(bodyContent.strip())
    
    return ruleToken

  # Main parsing loop
  while i < input.len:
    skipWhitespace(i, input)
    if i >= input.len: break
    
    # Look ahead to see if this is a property or a nested rule
    var lookAheadPos = i
    var foundOpenBrace = false
    var foundColon = false
    
    # Look for opening brace or colon
    while lookAheadPos < input.len and not (foundOpenBrace or foundColon):
      if input[lookAheadPos] == '{':
        foundOpenBrace = true
        break
      elif input[lookAheadPos] == ':':
        foundColon = true
        break
      elif input[lookAheadPos] in {';', '}'}:
        break
      inc lookAheadPos
    
    if foundOpenBrace:
      # This looks like a nested rule (like "from {" in @keyframes)
      tokens.add(parseNestedRule(i, input))
    elif foundColon:
      # This looks like a property
      var propStart = i
      var colonPos = lookAheadPos
      
      # Skip to colon
      i = colonPos + 1
      
      # Extract property name
      let propName = input[propStart..<colonPos].strip()
      
      # Find property value end
      skipWhitespace(i, input)
      var valueStart = i
      
      while i < input.len and input[i] != ';' and input[i] != '}':
        inc i
      
      let propValue = input[valueStart..<i].strip()
      
      # Skip semicolon if present
      if i < input.len and input[i] == ';':
        inc i
      
      # Create property token
      var propToken = ValueToken(kind: vtkProperty, value: propName)
      
      # Parse the value with full capability
      if propValue.len > 0:
        propToken.children = tokenizeValue(propValue, wrapRoot=false)
      
      tokens.add(propToken)
    else:
      # Unknown content, skip to next semicolon or brace
      while i < input.len and input[i] notin {';', '}'}:
        inc i
      if i < input.len:
        inc i  # Skip the delimiter
  
  return tokens

proc parseValue*(input: string): seq[ValueToken] =
  return tokenizeValue(input)

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
  of vtkRule:  # Add handling for vtkRule
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
    return indent & "Property(" & vt.value & ")" & childrenStr
  of vtkNumber:
    return indent & "Number(" & vt.value & ")"
  of vtkDimension:
    return indent & "Dimension(" & vt.value & ")"
  of vtkPercentage:
    return indent & "Percentage(" & vt.value & ")"
  of vtkColor:
    return indent & "Color(" & vt.value & ")"
  of vtkString:
    return indent & "String(" & vt.value & ")"
  of vtkIdent:
    return indent & "Ident(" & vt.value & ")"
  of vtkFunc:
    var childrenStr = ""
    for child in vt.children:
      childrenStr.add("\n" & treeRepr(child, newIndent) & ",")
    return indent & "Func(" & vt.value & childrenStr & "\n" & indent & ")"
  of vtkSequence:
    var childrenStr = ""
    for child in vt.children:
      childrenStr.add("\n" & treeRepr(child, newIndent))
    return indent & "Sequence(" & childrenStr & "\n" & indent & ")"
  of vtkComma:
    return indent & "Comma"
  of vtkSlash:
    return indent & "Slash"
  of vtkLParen:
    return indent & "LParen"
  of vtkRParen:
    return indent & "RParen"
  of vtkImportant:
    return indent & "Important"
  of vtkAtRule:
    # First part: AtRule name
    var result = indent & "AtRule(" & vt.value & ")"
    
    # Second part: Children (parameters)
    if vt.children.len > 0:
      result.add("\n")
      for child in vt.children:
        result.add(treeRepr(child, newIndent) & "\n")
    
    # Third part: Body (if applicable)
    if vt.body.len > 0:
      result.add("\n" & indent & "body {\n")
      for item in vt.body:
        result.add(treeRepr(item, newIndent) & "\n")
      result.add(indent & "}")
    
    return result
  of vtkRule:  # Modified to display children as selectors
    var result = indent & "Rule"
    
    # Display the selectors (children)
    if vt.children.len > 0:
      result.add("(")
      for i, child in vt.children:
        if i > 0:
          result.add(" ")
        result.add(child.value)
      result.add(")")
    else:
      result.add("()")
    
    # Body content
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

when isMainModule:
  let tokens = tokenizeValue("@keyframes sda { from { left: 5px} to {} test: 2px }")
  echo tokens.treeRepr
  # for token in tokens:
  #   echo "TOKEN: " & $token.kind & "  Value: " & token.value
  #   if token.children.len > 0:
  #     for child in token.children:
  #       echo "  Child: " & $child.kind & "  Value: " & child.value