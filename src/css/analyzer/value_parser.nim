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
    line*: int       # Line number where token starts (1-based)
    column*: int     # Column number where token starts (1-based)
    case hasNumValue*: bool
    of true:
      numValue*: float
      unit*: string
    of false: discard

# Wrap tokens in a sequence if more than one token (unless forced not to).
proc wrapSequence*(tokens: seq[ValueToken], isRoot: bool = false, line: int = 1, column: int = 1): ValueToken =
  if tokens.len == 1 and not isRoot:
    return tokens[0]
  else:
    return ValueToken(kind: vtkSequence, value: "", children: tokens, line: line, column: column)

# Forward declaration to allow mutual recursion
proc parseValueBody*(input: string, wrapRoot: bool = true, startLine: int = 1, startColumn: int = 1): seq[ValueToken] {.gcsafe.}

proc tokenizeValue*(rawInput: string, wrapRoot: bool = true, startLine: int = 1, startColumn: int = 1): seq[ValueToken] {.gcsafe.} =
  var input = rawInput
  for replacementFrom, replacementTo in REPLACEMENTS:
    input = input.replace(replacementFrom, replacementTo)
  if input.endsWith(";"):
    input = input[0..^2]
  if input.endsWith(" !important"):
    input = input[0..^12]

  var tokens: seq[ValueToken] = @[]
  var i = 0
  var line = startLine
  var column = startColumn

  # Helper to advance position and update line/column
  proc consumeChar(i: var int, line: var int, column: var int) =
    if i < input.len:
      if input[i] == '\n':
        inc line
        column = 1
      else:
        inc column
      inc i

  # Skip whitespace while tracking line and column
  proc skipWhitespace(i: var int, line: var int, column: var int) =
    while i < input.len and input[i] in {' ', '\t', '\n', '\r'}:
      if input[i] == '\n':
        inc line
        column = 1
      else:
        inc column
      inc i

  proc parseString(i: var int, line: var int, column: var int): ValueToken =
    let startLine = line
    let startColumn = column
    let quoteChar = input[i]  # either " or '
    consumeChar(i, line, column)  # skip opening quote
    var strVal = ""
    while i < input.len and input[i] != quoteChar:
      strVal.add(input[i])
      consumeChar(i, line, column)
    if i < input.len and input[i] == quoteChar:
      consumeChar(i, line, column)  # skip closing quote
    return ValueToken(kind: vtkString, value: strVal, line: startLine, column: startColumn)

  proc parseNumber(i: var int, line: var int, column: var int): ValueToken =
    let startLine = line
    let startColumn = column
    var numStr = ""
    # Handle negative numbers - check for minus sign
    if i < input.len and input[i] == '-':
      numStr.add(input[i])
      consumeChar(i, line, column)
    
    # Parse digits before decimal point
    while i < input.len and input[i] in {'0'..'9'}:
      numStr.add(input[i])
      consumeChar(i, line, column)
    
    # Parse decimal point and digits after it
    if i < input.len and input[i] == '.':
      numStr.add(input[i])
      consumeChar(i, line, column)
      while i < input.len and input[i] in {'0'..'9'}:
        numStr.add(input[i])
        consumeChar(i, line, column)
    
    # Check for unit
    var unit = ""
    if i < input.len and (input[i] in {'a'..'z', 'A'..'Z', '%'}):
      while i < input.len and (input[i] in {'a'..'z', 'A'..'Z', '-', '%'}):
        unit.add(input[i])
        consumeChar(i, line, column)
    
    # Return appropriate token based on unit
    if unit == "%":
      return ValueToken(kind: vtkPercentage, value: numStr & unit,
                        hasNumValue: true, numValue: parseFloat(numStr),
                        line: startLine, column: startColumn)
    elif unit.len > 0:
      return ValueToken(kind: vtkDimension, value: numStr & unit,
                        hasNumValue: true, numValue: parseFloat(numStr), unit: unit,
                        line: startLine, column: startColumn)
    else:
      return ValueToken(kind: vtkNumber, value: numStr,
                        hasNumValue: true, numValue: parseFloat(numStr),
                        line: startLine, column: startColumn)

  proc parseProperty(i: var int, line: var int, column: var int): ValueToken =
    # Find the property name (everything before the colon)
    let startLine = line
    let startColumn = column
    var startPos = i
    var colonPos = -1
    var colonLinePos = line
    var colonColPos = column
    
    # Search for the colon
    while i < input.len:
      if input[i] == ':':
        colonPos = i
        colonLinePos = line
        colonColPos = column
        break
      consumeChar(i, line, column)
    
    if colonPos == -1:
      # This wasn't a property (no colon found)
      # Reset position and return nothing
      i = startPos
      line = startLine
      column = startColumn
      return ValueToken(kind: vtkIdent, value: "", line: startLine, column: startColumn)  # Placeholder that will be ignored
    
    # Extract the property name
    let propertyName = input[startPos..<colonPos].strip()
    
    # Skip the colon
    consumeChar(i, line, column)  # Now i points to the character after the colon
    
    # Find the end of the property value (usually at semicolon or closing brace)
    var valueStart = i
    var valueStartLine = line
    var valueStartColumn = column
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
      
      consumeChar(i, line, column)
    
    # Extract the property value
    let propertyValue = input[valueStart..<i].strip()
    
    # Skip the semicolon if present
    if i < input.len and input[i] == ';':
      consumeChar(i, line, column)
    
    # Create the property token
    var propertyToken = ValueToken(kind: vtkProperty, value: propertyName, line: startLine, column: startColumn)
    
    # Parse the value into tokens and add them as children
    if propertyValue.len > 0:
      propertyToken.children = tokenizeValue(propertyValue, wrapRoot=false, startLine=valueStartLine, startColumn=valueStartColumn)
    
    return propertyToken

  # Parse CSS rules like 'from', 'to', etc.
  proc parseRule(i: var int, line: var int, column: var int): ValueToken =
    let startLine = line
    let startColumn = column
    var selectors: seq[ValueToken] = @[]
    var startPos = i
    
    # Parse all selectors before the opening brace
    while true:
      # Skip whitespace
      skipWhitespace(i, line, column)
      
      # Parse a selector (could be an identifier, or something more complex in a full CSS parser)
      if i < input.len and (input[i].isAlphaAscii or input[i] in {'-', '_', '%', '.', '#', '*', '[', ':'}):
        var selectorStart = i
        var selectorStartLine = line
        var selectorStartColumn = column
        
        # Parse the selector
        while i < input.len and input[i] notin {',', '{', '}', ';', '\n', '\r'}:
          consumeChar(i, line, column)
        
        var selectorText = input[selectorStart..<i].strip()
        if selectorText.len > 0:
          # Add this selector to our list
          selectors.add(ValueToken(kind: vtkIdent, value: selectorText, 
                                   line: selectorStartLine, column: selectorStartColumn))
      
      # Skip whitespace
      skipWhitespace(i, line, column)
      
      # Check if we have a comma (more selectors) or opening brace (end of selectors)
      if i < input.len and input[i] == ',':
        # Add the comma to our selectors
        # selectors.add(ValueToken(kind: vtkComma, value: ","))
        consumeChar(i, line, column)
        # Continue to parse more selectors
        continue
      elif i < input.len and input[i] == '{':
        # We've reached the opening brace, break out
        break
      else:
        # Not a valid rule, reset position
        i = startPos
        line = startLine
        column = startColumn
        return ValueToken(kind: vtkIdent, value: "", line: startLine, column: startColumn)  # Placeholder
    
    # Skip the opening brace
    consumeChar(i, line, column)
    
    # Create the rule token with selectors as children
    var ruleToken = ValueToken(kind: vtkRule, value: "", line: startLine, column: startColumn)
    ruleToken.children = selectors
    
    # Parse the rule body
    var bodyContent = ""
    var bodyStartLine = line
    var bodyStartColumn = column
    var braceLevel = 1
    
    while i < input.len and braceLevel > 0:
      if input[i] == '{':
        braceLevel.inc()
        bodyContent.add(input[i])
        consumeChar(i, line, column)
      elif input[i] == '}':
        braceLevel.dec()
        if braceLevel > 0:  # Don't include the final closing brace in body
          bodyContent.add(input[i])
        consumeChar(i, line, column)
      else:
        bodyContent.add(input[i])
        consumeChar(i, line, column)
    
    # Parse the body content recursively
    if bodyContent.len > 0:
      ruleToken.body = parseValueBody(bodyContent.strip(), wrapRoot=false, 
                                     startLine=bodyStartLine, startColumn=bodyStartColumn)
    
    return ruleToken

  proc parseAtRule(i: var int, line: var int, column: var int): ValueToken =
    let startLine = line
    let startColumn = column
    # Skip the '@'
    consumeChar(i, line, column)
    
    # Parse the at-rule name (like "property", "media", etc.)
    var ruleName = ""
    while i < input.len and (input[i].isAlphaAscii or input[i].isDigit or input[i] in {'-', '_'}):
      ruleName.add(input[i])
      consumeChar(i, line, column)
    
    # Create the token with just the at-rule name
    var atRuleToken = ValueToken(kind: vtkAtRule, value: ruleName, line: startLine, column: startColumn)
    
    # Parse any parameters that follow (before the opening brace if present)
    skipWhitespace(i, line, column)
    
    var paramStr = ""
    var paramStartLine = line
    var paramStartColumn = column
    var paramStartIndex = i
    
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
        consumeChar(i, line, column)
    
    # Parse the params into tokens and add them as children
    if paramStr.strip().len > 0:
      # Create tokenizers for the parameter string, maintaining line/column
      var paramTokenizer = paramStartIndex
      var paramTokenizerLine = paramStartLine
      var paramTokenizerColumn = paramStartColumn
      
      # Skip whitespace
      while paramTokenizer < i and input[paramTokenizer] in {' ', '\t', '\n', '\r'}:
        if input[paramTokenizer] == '\n':
          inc paramTokenizerLine
          paramTokenizerColumn = 1
        else:
          inc paramTokenizerColumn
        inc paramTokenizer
      
      # Parse identifiers, strings, etc.
      if paramTokenizer < i:
        if input[paramTokenizer] in {'"', '\''}:
          # String parameter
          let quoteChar = input[paramTokenizer]
          inc paramTokenizer  # Skip quote
          var strVal = ""
          while paramTokenizer < i and input[paramTokenizer] != quoteChar:
            strVal.add(input[paramTokenizer])
            inc paramTokenizer
          if paramTokenizer < i:
            inc paramTokenizer  # Skip closing quote
          atRuleToken.children = @[ValueToken(kind: vtkString, value: strVal, 
                                            line: paramStartLine, column: paramStartColumn)]
        else:
          # Identifier parameter
          var identStr = ""
          while paramTokenizer < i and (input[paramTokenizer].isAlphaAscii or 
                                       input[paramTokenizer].isDigit or 
                                       input[paramTokenizer] in {'-', '_'}):
            identStr.add(input[paramTokenizer])
            inc paramTokenizer
          
          if identStr.len > 0:
            atRuleToken.children = @[ValueToken(kind: vtkIdent, value: identStr, 
                                              line: paramStartLine, column: paramStartColumn)]
    
    # If we have a body block, parse it too
    if i < input.len and input[i] == '{':
      consumeChar(i, line, column)  # Skip '{'
      
      # Store the starting position of the body
      let bodyStartLine = line
      let bodyStartColumn = column
      let bodyStartIndex = i
      
      # Find the matching closing brace
      var braceLevel = 1
      
      while i < input.len and braceLevel > 0:
        if input[i] == '{':
          braceLevel.inc()
          consumeChar(i, line, column)
        elif input[i] == '}':
          braceLevel.dec()
          if braceLevel == 0:
            break
          consumeChar(i, line, column)
        else:
          consumeChar(i, line, column)
      
      # Now parse the body content directly without extracting to a string
      if i > bodyStartIndex:
        # Process each token in the body directly
        var bodyParser = bodyStartIndex
        var bodyLine = bodyStartLine
        var bodyColumn = bodyStartColumn
        
        # Parse top-level properties and rules in the body
        while bodyParser < i:
          skipWhitespace(bodyParser, bodyLine, bodyColumn)
          if bodyParser >= i: break
          
          # Check for rule (selector followed by brace)
          if bodyParser < i and (input[bodyParser].isAlphaAscii or input[bodyParser] in {'-', '_', '.', '#'}):
            let ruleStartLine = bodyLine
            let ruleStartColumn = bodyColumn
            let ruleStart = bodyParser
            
            # Look ahead for opening brace
            var foundBrace = false
            var tmpParser = bodyParser
            var tmpLine = bodyLine
            var tmpColumn = bodyColumn
            
            while tmpParser < i and not foundBrace:
              if input[tmpParser] == '{':
                foundBrace = true
                break
              elif input[tmpParser] == ':':
                # This is a property, not a rule
                break
              elif input[tmpParser] == '}':
                break
              
              if input[tmpParser] == '\n':
                inc tmpLine
                tmpColumn = 1
              else:
                inc tmpColumn
              inc tmpParser
            
            if foundBrace:
              # It's a rule - parse selector
              var ruleSelector = ""
              while bodyParser < i and input[bodyParser] != '{':
                ruleSelector.add(input[bodyParser])
                consumeChar(bodyParser, bodyLine, bodyColumn)
              
              # Skip opening brace
              if bodyParser < i:
                consumeChar(bodyParser, bodyLine, bodyColumn)
              
              # Parse rule body
              let ruleBodyStart = bodyParser
              let ruleBodyLine = bodyLine
              let ruleBodyColumn = bodyColumn
              var ruleBraceLevel = 1
              
              while bodyParser < i and ruleBraceLevel > 0:
                if input[bodyParser] == '{':
                  ruleBraceLevel.inc()
                  consumeChar(bodyParser, bodyLine, bodyColumn)
                elif input[bodyParser] == '}':
                  ruleBraceLevel.dec()
                  if ruleBraceLevel == 0:
                    break
                  consumeChar(bodyParser, bodyLine, bodyColumn)
                else:
                  consumeChar(bodyParser, bodyLine, bodyColumn)
              
              # Create the rule token
              var ruleToken = ValueToken(
                kind: vtkRule, 
                value: "", 
                line: ruleStartLine, 
                column: ruleStartColumn
              )
              
              # Add the selector as a child
              ruleToken.children = @[
                ValueToken(
                  kind: vtkIdent,
                  value: ruleSelector.strip(),
                  line: ruleStartLine,
                  column: ruleStartColumn
                )
              ]
              
              # Parse rule body properties
              if bodyParser > ruleBodyStart:
                var ruleBodyTokens: seq[ValueToken] = @[]
                var propParser = ruleBodyStart
                var propLine = ruleBodyLine
                var propColumn = ruleBodyColumn
                
                while propParser < bodyParser:
                  skipWhitespace(propParser, propLine, propColumn)
                  if propParser >= bodyParser: break
                  
                  # Look for property
                  if propParser < bodyParser:
                    let propStartLine = propLine
                    let propStartColumn = propColumn
                    let propStartPos = propParser
                    
                    # Find colon
                    var foundColon = false
                    while propParser < bodyParser and not foundColon:
                      if input[propParser] == ':':
                        foundColon = true
                        break
                      consumeChar(propParser, propLine, propColumn)
                    
                    if foundColon:
                      # Extract property name
                      let propName = input[propStartPos..<propParser].strip()
                      
                      # Skip colon
                      consumeChar(propParser, propLine, propColumn)
                      
                      # Skip whitespace
                      skipWhitespace(propParser, propLine, propColumn)
                      
                      # Find property value end
                      let valueStartLine = propLine
                      let valueStartColumn = propColumn
                      let valueStartPos = propParser
                      
                      while propParser < bodyParser and input[propParser] != ';':
                        consumeChar(propParser, propLine, propColumn)
                      
                      # Extract value
                      let propValue = input[valueStartPos..<propParser].strip()
                      
                      # Skip semicolon
                      if propParser < bodyParser and input[propParser] == ';':
                        consumeChar(propParser, propLine, propColumn)
                      
                      # Create property token
                      var propToken = ValueToken(
                        kind: vtkProperty,
                        value: propName,
                        line: propStartLine,
                        column: propStartColumn
                      )
                      
                      # Add dimension value
                      if propValue.len > 0:
                        propToken.children = @[
                          ValueToken(
                            kind: vtkDimension,
                            value: propValue,
                            line: valueStartLine,
                            column: valueStartColumn,
                            hasNumValue: true,
                            numValue: 0.0
                          )
                        ]
                      
                      ruleBodyTokens.add(propToken)
                    else:
                      # Skip to next semicolon or end
                      while propParser < bodyParser and input[propParser] != ';':
                        consumeChar(propParser, propLine, propColumn)
                      if propParser < bodyParser:
                        consumeChar(propParser, propLine, propColumn)
                  
                # Add rule body tokens
                ruleToken.body = ruleBodyTokens
              
              # Skip closing brace
              if bodyParser < i:
                consumeChar(bodyParser, bodyLine, bodyColumn)
              
              # Add rule to body
              # if atRuleToken.body == nil:
                # atRuleToken.body = @[]
              atRuleToken.body.add(ruleToken)
            else:
              # Check if it's a property
              foundBrace = false
              tmpParser = bodyParser
              tmpLine = bodyLine
              tmpColumn = bodyColumn
              var foundColon = false
              
              while tmpParser < i and not foundColon:
                if input[tmpParser] == ':':
                  foundColon = true
                  break
                elif input[tmpParser] == '}':
                  break
                
                if input[tmpParser] == '\n':
                  inc tmpLine
                  tmpColumn = 1
                else:
                  inc tmpColumn
                inc tmpParser
              
              if foundColon:
                # Property parsing
                let propStartLine = bodyLine
                let propStartColumn = bodyColumn
                let propStart = bodyParser
                
                # Find colon
                while bodyParser < i and input[bodyParser] != ':':
                  consumeChar(bodyParser, bodyLine, bodyColumn)
                
                # Extract property name
                let propName = input[propStart..<bodyParser].strip()
                
                # Skip colon
                consumeChar(bodyParser, bodyLine, bodyColumn)
                
                # Skip whitespace
                skipWhitespace(bodyParser, bodyLine, bodyColumn)
                
                # Extract value
                let valueStartLine = bodyLine
                let valueStartColumn = bodyColumn
                let valueStart = bodyParser
                
                while bodyParser < i and input[bodyParser] != ';' and input[bodyParser] != '}':
                  consumeChar(bodyParser, bodyLine, bodyColumn)
                
                let propValue = input[valueStart..<bodyParser].strip()
                
                # Skip semicolon
                if bodyParser < i and input[bodyParser] == ';':
                  consumeChar(bodyParser, bodyLine, bodyColumn)
                
                # Create property token
                var propToken = ValueToken(
                  kind: vtkProperty,
                  value: propName,
                  line: propStartLine,
                  column: propStartColumn
                )
                
                # Add value
                if propValue.len > 0:
                  propToken.children = @[
                    ValueToken(
                      kind: vtkDimension,
                      value: propValue,
                      line: valueStartLine,
                      column: valueStartColumn,
                      hasNumValue: true,
                      numValue: 0.0
                    )
                  ]
                
                # Add to body
                # if atRuleToken.body == nil:
                  # atRuleToken.body = @[]
                atRuleToken.body.add(propToken)
              else:
                # Skip unknown content
                while bodyParser < i and input[bodyParser] != ';' and input[bodyParser] != '}':
                  consumeChar(bodyParser, bodyLine, bodyColumn)
                if bodyParser < i:
                  consumeChar(bodyParser, bodyLine, bodyColumn)
          else:
            # Skip unknown content
            while bodyParser < i and input[bodyParser] != ';' and input[bodyParser] != '}':
              consumeChar(bodyParser, bodyLine, bodyColumn)
            if bodyParser < i:
              consumeChar(bodyParser, bodyLine, bodyColumn)
      
      # Skip the closing brace
      if i < input.len and input[i] == '}':
        consumeChar(i, line, column)
    elif i < input.len and input[i] == ';':
      consumeChar(i, line, column)  # Skip ';'
    
    return atRuleToken

  # Parse !important
  proc parseImportant(i: var int, line: var int, column: var int): ValueToken =
    # Store the current position
    let startLine = line
    let startColumn = column
    let startPos = i
    # Skip the '!'
    consumeChar(i, line, column)
    # Check if this is specifically "!important"
    let remainder = "important"
    var matched = true
    
    for j in 0..<remainder.len:
      if i + j >= input.len or input[i + j] != remainder[j]:
        matched = false
        break
    
    if matched:
      # This is exactly "!important", so consume it
      for j in 0..<remainder.len:
        consumeChar(i, line, column)
      return ValueToken(kind: vtkImportant, value: "!important", line: startLine, column: startColumn)
    else:
      # This is not "!important", so reset position
      i = startPos
      line = startLine
      column = startColumn
      # Just return the '!' as an identifier
      consumeChar(i, line, column)
      return ValueToken(kind: vtkIdent, value: "!", line: startLine, column: startColumn)

  proc parseFunctionArgs(input: string, start: int, startLine: int, startColumn: int): (seq[ValueToken], int, int, int) =
    var args: seq[ValueToken] = @[]
    var currentArg = ""
    var parenLevel = 0
    var j = start
    var argLine = startLine
    var argColumn = startColumn
    var currentArgStartLine = startLine
    var currentArgStartColumn = startColumn
    
    while j < input.len:
      let c = input[j]
      if c == '(':
        parenLevel.inc()
        currentArg.add(c)
        if c == '\n':
          inc argLine
          argColumn = 1
        else:
          inc argColumn
        inc j
      elif c == ')' and parenLevel > 0:
        parenLevel.dec()
        currentArg.add(c)
        if c == '\n':
          inc argLine
          argColumn = 1
        else:
          inc argColumn
        inc j
      elif c == ')' and parenLevel == 0:
        break
      elif c == ',' and parenLevel == 0:
        let argTokens = tokenizeValue(currentArg.strip(), wrapRoot=false, 
                                     startLine=currentArgStartLine, startColumn=currentArgStartColumn)
        if argTokens.len == 1:
          args.add(argTokens[0])
        else:
          args.add(wrapSequence(argTokens, isRoot=false, line=currentArgStartLine, column=currentArgStartColumn))
        currentArg = ""
        currentArgStartLine = argLine
        currentArgStartColumn = argColumn
        if c == '\n':
          inc argLine
          argColumn = 1
        else:
          inc argColumn
        inc j
      else:
        currentArg.add(c)
        if c == '\n':
          inc argLine
          argColumn = 1
        else:
          inc argColumn
        inc j
    
    if currentArg.len > 0:
      let argTokens = tokenizeValue(currentArg.strip(), wrapRoot=false, 
                                   startLine=currentArgStartLine, startColumn=currentArgStartColumn)
      if argTokens.len == 1:
        args.add(argTokens[0])
      else:
        args.add(wrapSequence(argTokens, isRoot=false, line=currentArgStartLine, column=currentArgStartColumn))
    
    return (args, j, argLine, argColumn)


  proc parseIdent(i: var int, line: var int, column: var int): ValueToken {.gcsafe.} =
    let startLine = line
    let startColumn = column
    var identStr = ""
    while i < input.len and (input[i].isAlphaAscii or input[i].isDigit or input[i] in {'-', '_'}):
      identStr.add(input[i])
      consumeChar(i, line, column)
    
    # Check if this is a CSS selector rule like 'from', 'to', etc.
    # We need to look ahead to see if there's a '{' after potential whitespace
    var lookAheadPos = i
    var lookAheadLine = line
    var lookAheadColumn = column
    var tmpInput = input  # Make a copy to avoid modifying actual position
    skipWhitespace(lookAheadPos, lookAheadLine, lookAheadColumn)
    
    if lookAheadPos < input.len and input[lookAheadPos] == '{':
      # Handle as a CSS rule
      i = lookAheadPos
      line = lookAheadLine
      column = lookAheadColumn
      # Parse the rule
      var ruleToken = ValueToken(kind: vtkRule, value: identStr, line: startLine, column: startColumn)
      
      # Skip the opening brace
      consumeChar(i, line, column)
      
      # Parse the rule body
      var bodyContent = ""
      var bodyStartLine = line
      var bodyStartColumn = column
      var braceLevel = 1
      
      while i < input.len and braceLevel > 0:
        if input[i] == '{':
          braceLevel.inc()
          bodyContent.add(input[i])
          consumeChar(i, line, column)
        elif input[i] == '}':
          braceLevel.dec()
          if braceLevel > 0:  # Don't include the final closing brace
            bodyContent.add(input[i])
          consumeChar(i, line, column)
        else:
          bodyContent.add(input[i])
          consumeChar(i, line, column)
      
      # Parse the body content recursively
      if bodyContent.len > 0:
        ruleToken.body = parseValueBody(bodyContent.strip(), wrapRoot=false,
                                       startLine=bodyStartLine, startColumn=bodyStartColumn)
      
      return ruleToken
    
    # If not a rule, continue with normal ident parsing
    if i < input.len and input[i] == '(':
      consumeChar(i, line, column)  # skip '('
      let (funcArgs, newIndex, newLine, newColumn) = parseFunctionArgs(input, i, line, column)
      i = newIndex
      line = newLine
      column = newColumn
      if i < input.len and input[i] == ')' :
         consumeChar(i, line, column)
      return ValueToken(kind: vtkFunc, value: identStr, children: funcArgs, 
                       line: startLine, column: startColumn)
    else:
      return ValueToken(kind: vtkIdent, value: identStr, line: startLine, column: startColumn)


  while i < input.len:
    skipWhitespace(i, line, column)
    if i >= input.len: break
    
    # CRITICAL FIX: Check for at-rules (@keyframes, etc.) FIRST before any other pattern
    if input[i] == '@':
      tokens.add(parseAtRule(i, line, column))
      continue
    
    # Now check if this could be a rule (selector followed by {)
    var lookAheadPos = i
    var lookAheadLine = line
    var lookAheadColumn = column
    var foundOpenBrace = false
    
    # Use a temporary copy of these variables for look-ahead
    var tmpI = i
    var tmpLine = line
    var tmpColumn = column
    
    while tmpI < input.len and not foundOpenBrace:
      if input[tmpI] == '{':
        foundOpenBrace = true
        lookAheadPos = tmpI
        lookAheadLine = tmpLine
        lookAheadColumn = tmpColumn
        break
      elif input[tmpI] in {';', '}', '\n', '\r'}:
        # Stop looking if we hit these characters
        break
      
      if input[tmpI] == '\n':
        inc tmpLine
        tmpColumn = 1
      else:
        inc tmpColumn
      inc tmpI
    
    if foundOpenBrace:
      # This appears to be a rule, try to parse it
      tokens.add(parseRule(i, line, column))
      continue
    
    lookAheadPos = i
    lookAheadLine = line
    lookAheadColumn = column
    var foundColon = false
    
    # Reset temporary variables for colon look-ahead
    tmpI = i
    tmpLine = line
    tmpColumn = column
    
    # Look ahead for a colon
    while tmpI < input.len and not foundColon:
      if input[tmpI] == ':':
        foundColon = true
        lookAheadPos = tmpI
        lookAheadLine = tmpLine
        lookAheadColumn = tmpColumn
        break
      elif input[tmpI] in {';', '{', '}', '\n', '\r'}:
        # Stop looking if we hit these characters before finding a colon
        break
      
      if input[tmpI] == '\n':
        inc tmpLine
        tmpColumn = 1
      else:
        inc tmpColumn
      inc tmpI
    
    if foundColon:
      # We found a property pattern, parse it
      tokens.add(parseProperty(i, line, column))
      continue

    # Main change: Check for negative numbers before identifiers
    # A negative number is a minus sign followed by a digit or decimal point
    if input[i] == '-' and i + 1 < input.len and (input[i + 1] in {'0'..'9', '.'}):
      tokens.add(parseNumber(i, line, column))
    elif input[i] in {'0'..'9', '.'}:
      tokens.add(parseNumber(i, line, column))
    elif input[i] in {'"', '\''}:
      tokens.add(parseString(i, line, column))
    elif input[i] == '!':
      tokens.add(parseImportant(i, line, column))
    elif input[i] in {'a'..'z', 'A'..'Z', '-', '_'}:
      tokens.add(parseIdent(i, line, column))
    elif input[i] == '#':
      let startLine = line
      let startColumn = column
      var color = "#"
      consumeChar(i, line, column)
      while i < input.len and input[i] in {'0'..'9', 'a'..'f', 'A'..'F'}:
        color.add(input[i])
        consumeChar(i, line, column)
      tokens.add(ValueToken(kind: vtkColor, value: color, line: startLine, column: startColumn))
    elif input[i] == ',':
      tokens.add(ValueToken(kind: vtkComma, value: ",", line: line, column: column))
      consumeChar(i, line, column)
    elif input[i] == '/':
      tokens.add(ValueToken(kind: vtkSlash, value: "/", line: line, column: column))
      consumeChar(i, line, column)
    elif input[i] == '(':
      tokens.add(ValueToken(kind: vtkLParen, value: "(", line: line, column: column))
      consumeChar(i, line, column)
    elif input[i] == ')':
      tokens.add(ValueToken(kind: vtkRParen, value: ")", line: line, column: column))
      consumeChar(i, line, column)
    else:
      consumeChar(i, line, column)

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
        # Use the line/column from the first token in the group for the sequence
        let groupLine = if group.len > 0: group[0].line else: startLine
        let groupColumn = if group.len > 0: group[0].column else: startColumn
        resultTokens.add(wrapSequence(group, isRoot=false, line=groupLine, column=groupColumn))
    return resultTokens
  else:
    return tokens

# Specialized parser for rule bodies
proc parseValueBody*(input: string, wrapRoot: bool = true, startLine: int = 1, startColumn: int = 1): seq[ValueToken] {.gcsafe.} =
  var tokens: seq[ValueToken] = @[]
  var i = 0
  var line = startLine
  var column = startColumn
  
  # Helper to advance position and update line/column
  proc consumeChar(i: var int, line: var int, column: var int) =
    if i < input.len:
      if input[i] == '\n':
        inc line
        column = 1
      else:
        inc column
      inc i
  
  proc skipWhitespace(i: var int, line: var int, column: var int) =
    while i < input.len and input[i] in {' ', '\t', '\n', '\r'}:
      if input[i] == '\n':
        inc line
        column = 1
      else:
        inc column
      inc i

  # Helper function to parse rule selectors (like "from, to" in @keyframes)
  proc parseRuleSelectors(i: var int, line: var int, column: var int): seq[ValueToken] =
    var selectors: seq[ValueToken] = @[]
    
    while i < input.len:
      skipWhitespace(i, line, column)
      
      # Parse a selector
      if i < input.len and input[i] notin {',', '{', '}', ';'}:
        var selectorStart = i
        var selectorStartLine = line
        var selectorStartColumn = column
        
        # Parse the selector text
        while i < input.len and input[i] notin {',', '{', '}', ';'}:
          consumeChar(i, line, column)
        
        let selectorText = input[selectorStart..<i].strip()
        if selectorText.len > 0:
          selectors.add(ValueToken(kind: vtkIdent, value: selectorText, 
                                  line: selectorStartLine, column: selectorStartColumn))
      
      skipWhitespace(i, line, column)
      
      # Check if we have more selectors or reached the end
      if i < input.len and input[i] == ',':
        consumeChar(i, line, column)  # Skip comma
        continue
      else:
        break
    
    return selectors

  # Helper function to parse a rule block
  proc parseNestedRule(i: var int, line: var int, column: var int): ValueToken =
    let startLine = line
    let startColumn = column
    
    # Parse selectors
    var selectors = parseRuleSelectors(i, line, column)
    
    # Create rule token
    var ruleToken = ValueToken(kind: vtkRule, value: "", line: startLine, column: startColumn)
    ruleToken.children = selectors
    
    # Check for opening brace
    skipWhitespace(i, line, column)
    if i < input.len and input[i] == '{':
      consumeChar(i, line, column)  # Skip opening brace
      
      # Parse rule body
      var bodyContent = ""
      var bodyStartLine = line
      var bodyStartColumn = column
      var braceLevel = 1
      
      while i < input.len and braceLevel > 0:
        if input[i] == '{':
          braceLevel.inc()
          bodyContent.add(input[i])
          consumeChar(i, line, column)
        elif input[i] == '}':
          braceLevel.dec()
          if braceLevel > 0:  # Don't include the final closing brace
            bodyContent.add(input[i])
          consumeChar(i, line, column)
        else:
          bodyContent.add(input[i])
          consumeChar(i, line, column)
      
      # Parse the body content
      if bodyContent.len > 0:
        ruleToken.body = parseValueBody(bodyContent.strip(), wrapRoot=false,
                                       startLine=bodyStartLine, startColumn=bodyStartColumn)
    
    return ruleToken

  # Main parsing loop
  while i < input.len:
    skipWhitespace(i, line, column)
    if i >= input.len: break
    
    # Look ahead to see if this is a property or a nested rule
    var lookAheadPos = i
    var lookAheadLine = line
    var lookAheadColumn = column
    var foundOpenBrace = false
    var foundColon = false
    
    # Use temporary variables for look-ahead
    var tmpI = i
    var tmpLine = line
    var tmpColumn = column
    
    # Look for opening brace or colon
    while tmpI < input.len and not (foundOpenBrace or foundColon):
      if input[tmpI] == '{':
        foundOpenBrace = true
        lookAheadPos = tmpI
        lookAheadLine = tmpLine
        lookAheadColumn = tmpColumn
        break
      elif input[tmpI] == ':':
        foundColon = true
        lookAheadPos = tmpI
        lookAheadLine = tmpLine
        lookAheadColumn = tmpColumn
        break
      elif input[tmpI] in {';', '}'}:
        break
      
      if input[tmpI] == '\n':
        inc tmpLine
        tmpColumn = 1
      else:
        inc tmpColumn
      inc tmpI
    
    if foundOpenBrace:
      # This looks like a nested rule (like "from {" in @keyframes)
      tokens.add(parseNestedRule(i, line, column))
    elif foundColon:
      # This looks like a property
      let startLine = line
      let startColumn = column
      var propStart = i
      
      # Advance to the colon
      while i < input.len and input[i] != ':':
        consumeChar(i, line, column)
      
      # Extract property name
      let propName = input[propStart..<i].strip()
      
      # Skip colon
      consumeChar(i, line, column)
      
      # Skip whitespace after colon
      skipWhitespace(i, line, column)
      
      # Find property value end
      let valueStart = i
      let valueStartLine = line
      let valueStartColumn = column
      
      while i < input.len and input[i] != ';' and input[i] != '}':
        consumeChar(i, line, column)
      
      let propValue = input[valueStart..<i].strip()
      
      # Skip semicolon if present
      if i < input.len and input[i] == ';':
        consumeChar(i, line, column)
      
      # Create property token
      var propToken = ValueToken(kind: vtkProperty, value: propName, line: startLine, column: startColumn)
      
      # Parse the value with full capability
      if propValue.len > 0:
        propToken.children = tokenizeValue(propValue, wrapRoot=false,
                                          startLine=valueStartLine, startColumn=valueStartColumn)
      
      tokens.add(propToken)
    else:
      # Unknown content, skip to next semicolon or brace
      while i < input.len and input[i] notin {';', '}'}:
        consumeChar(i, line, column)
      if i < input.len:
        consumeChar(i, line, column)  # Skip the delimiter
  
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
    # First part: AtRule name
    var result = indent & "AtRule(" & vt.value & ") @ line " & $vt.line & ", col " & $vt.column
    
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
    var result = indent & "Rule @ line " & $vt.line & ", col " & $vt.column
    
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
  let tokens = tokenizeValue("""
@keyframes sda {
  from {
    left: 5px
  }
  to {}

  
  test: 2px

}
""")
  echo tokens.treeRepr
  # for token in tokens:
  #   echo "TOKEN: " & $token.kind & "  Value: " & token.value & " @ line " & $token.line & ", col " & $token.column
  #   if token.children.len > 0:
  #     for child in token.children:
  #       echo "  Child: " & $child.kind & "  Value: " & child.value & " @ line " & $child.line & ", col " & $child.column