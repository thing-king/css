# std
import strutils, sequtils, tables, algorithm, options, sets

# pkgs
import pkg/colors

# this
import ../types
import ../util
import ../imports/imports   # gives access to `syntaxes` and `functions`
export imports
import syntax_parser # provides: let ast: Node = parseSyntax("…")
import value_parser  # provides: let tokens: seq[ValueToken] = tokenizeValue("…")

# # Extend built-in dictionaries with missing entries
# let extendedProperties = block:
#   var temp = properties
#   temp["-webkit-text-size-adjust"] = PropertiesValue(syntax: "<percentage> | auto | none")

#   temp

# let extendedSyntaxes = block:
#   var temp = syntaxes
#   temp["url"] = SyntaxesValue(syntax: "url( <string> )")
#   temp["length-percentage"] = SyntaxesValue(syntax: "<length> | <percentage>")
#   temp

# let extendedFunctions = block:
#   var temp = functions
#   temp["url()"] = FunctionsValue(syntax: "url( <string> )")
#   temp

# Debug settings
var DEBUG {.compileTime} = true
proc enableDebug*() = DEBUG = true
proc disableDebug*() = DEBUG = false


proc log(msg: string) =
  when defined(js):
    discard
  else:
    if DEBUG:
      echo "[LOG] " & msg


# Cache for visited properties to avoid infinite recursion
# var visitedProperties {.compileTime, threadvar.}: HashSet[string]

#---------------------------------------------------------
# VALIDATORS
#---------------------------------------------------------

proc validateNode(node: Node, tokens: seq[ValueToken], index: int, visitedProperties: var HashSet[string]): MatchResult {.gcsafe.}

proc isNodeOptional(node: Node): bool =
  ## Helper function to determine if a node is optional
  return node.kind == nkOptional or node.kind == nkZeroOrMore or 
         (node.kind == nkQuantified and node.min == 0)

# Helper function to check if remaining tokens only contain a valid !important
proc hasOnlyImportant(tokens: seq[ValueToken], index: int): bool =
  # If there's only one token left and it's vtkImportant
  if index < tokens.len and index == tokens.len - 1 and tokens[index].kind == vtkImportant:
    return true
  return false

proc validateDeclarationValue(tokens: seq[ValueToken], visitedProperties: var HashSet[string]): bool =
  ## Validates if tokens form a valid declaration value
  ## (matches any valid CSS property syntax)
  log("Validating declaration-value")
  
  # First try to match against all property syntaxes
  for propName, propValue in properties.pairs:
    let syntaxAst = parseSyntax(propValue.syntax)
    let result = validateNode(syntaxAst, tokens, 0, visitedProperties)
    
    # Consider it valid if all tokens were consumed
    if result.success and result.index == tokens.len:
      log("Valid declaration-value: matched property " & propName)
      return true
    
    # Also valid if only a trailing !important remains
    if result.success and result.index < tokens.len and 
       hasOnlyImportant(tokens, result.index):
      log("Valid declaration-value with !important: matched property " & propName)
      return true
  
  # Then try to match against all custom syntaxes
  for syntaxName, syntaxValue in syntaxes.pairs:
    let syntaxAst = parseSyntax(syntaxValue.syntax)
    let result = validateNode(syntaxAst, tokens, 0, visitedProperties)
    
    # Consider it valid if all tokens were consumed
    if result.success and result.index == tokens.len:
      log("Valid declaration-value: matched syntax " & syntaxName)
      return true
    
    # Also valid if only a trailing !important remains
    if result.success and result.index < tokens.len and 
       hasOnlyImportant(tokens, result.index):
      log("Valid declaration-value with !important: matched syntax " & syntaxName)
      return true
  
  # If it didn't match any property or syntax, it's not a valid declaration value
  log("Invalid declaration-value: did not match any property or syntax")
  return false


proc validateBuiltinDataType(typeName: string, token: ValueToken, visitedProperties: var HashSet[string]): bool =
  ## Validates if a token matches a built-in data type  
  if (typeName.len == 0 or token.value.len == 0) and typeName != "declaration-value" and token.kind != vtkString:
    log("Empty type name or token value")
    return false
  
  # SPECIAL CASE: var() function should match any type since it can substitute for any CSS value
  if token.kind == vtkFunc and token.value == "var":
    log("Special handling: var() function matches any type")
    return true
    
  # SPECIAL CASE: calc() function can match specific numeric types
  if token.kind == vtkFunc and token.value == "calc":
    # calc() is valid for these data types
    let calcAllowedTypes = ["length", "time", "frequency", "angle", "number", "percentage", 
                           "length-percentage", "flex", "integer", "declaration-value"]
    
    if typeName in calcAllowedTypes:
      log("Special handling: calc() function accepted for type: " & typeName)
      return true
    else:
      log("calc() function not allowed for type: " & typeName)
      return false

  log("Validating built-in type '" & typeName & "' with token '" & token.value & "' (" & $token.kind & ")")
  
  # Special handling for declaration-value
  if typeName == "declaration-value":
    # If the token is a sequence, we need to validate all of its children
    if token.kind == vtkSequence:
      return validateDeclarationValue(token.children, visitedProperties)
    # Otherwise, treat single token as a sequence of one
    else:
      return validateDeclarationValue(@[token], visitedProperties)

  # Special handling for declaration-list
  if typeName == "declaration-list":
    log("Validating declaration-list")
    
    # Case 1: For a sequence token (multiple properties)
    if token.kind == vtkSequence:
      log("Checking sequence of " & $token.children.len & " tokens for declaration-list")
      
      # All children must be properties
      for child in token.children:
        if child.kind != vtkProperty:
          log("Invalid token in declaration-list: " & $child.kind & " (expected vtkProperty)")
          return false
      
      # If we got here, all children are properties
      return true
    
    # Case 2: For a single property token
    elif token.kind == vtkProperty:
      log("Found single property in declaration-list: " & token.value)
      return true
    
    # Case 3: Neither a property nor a sequence of properties
    else:
      log("Token is not a property or sequence of properties: " & $token.kind)
      return false

  case typeName
  of "number":       
    return token.kind == vtkNumber
  of "percentage":   
    return token.kind == vtkPercentage
  of "color":        
    return token.kind == vtkColor or token.kind == vtkIdent
  of "angle":        
    return token.kind == vtkDimension and token.unit in ["deg", "rad", "grad", "turn"]
  of "custom-ident": 
    return token.kind == vtkIdent
  of "dashed-ident": 
    return token.kind == vtkIdent and token.value.startsWith("--") and not token.value.endsWith("-")
  of "custom-property-name":
    return token.kind == vtkIdent and token.value.startsWith("--") and not token.value.endsWith("-")
  of "integer":      
    return token.kind == vtkNumber and not token.value.contains(".")
  of "string":       
    return token.kind == vtkString
  of "dimension":    
    return token.kind == vtkDimension
  of "frequency":    
    return token.kind == vtkDimension and token.unit in ["Hz", "kHz", "KhZ"]
  of "length":       
    let lengthUnits = ["cap", "ch", "em", "ex", "ic", "lh", "rcap", "rch", "rem", "rex", "ric", 
                       "rlh", "sv", "lv", "dv", "vh", "vw", "vmax", "vmin", "vb", "vi", "cqw", 
                       "cqh", "cqi", "cqb", "cqmin", "cqmax", "px", "cm", "mm", "Q", "in", "pc", "pt"]
    if token.kind == vtkNumber and token.value == "0":
      return true
    return token.kind == vtkDimension and token.unit in lengthUnits
  of "overflow":     
    return token.kind == vtkIdent and token.value in ["visible", "hidden", "scroll", "auto", "clip"]
  of "resolution":   
    return token.kind == vtkDimension and token.unit in ["dpi", "dpcm", "dppx", "x"]
  of "time":         
    return token.kind == vtkDimension and token.unit in ["s", "ms"]
  of "hex-color":
    return token.kind == vtkColor and token.value.startsWith("#") and token.value.len in {4, 7, 5, 9}
  # of "alpha-value":  
    # return token.kind == vtkNumber or token.kind == vtkPercentage
  else:
    log("No built-in validator for data type: " & typeName)
    return false

# Enhanced function to support nested calc() expressions
proc validateCalcExpression(token: ValueToken, expectedType: string): bool =
  ## Validates a calc() expression including nested calc() functions
  if token.kind != vtkFunc:
    return false
    
  # Direct calc() function
  if token.value == "calc":
    log("Validating calc() expression")
    # For simplicity, we accept any calc() expression without detailed validation
    # A more complete implementation would validate the arithmetic operations
    return true
    
  # Handle other functions that might contain calc() as parameters
  for child in token.children:
    if child.kind == vtkFunc and child.value == "calc":
      if validateCalcExpression(child, expectedType):
        return true
        
  return false

proc validateDataType(node: Node, tokens: seq[ValueToken], index: int, visitedProperties: var HashSet[string]): MatchResult {.gcsafe.} =
  ## Validates if tokens match a data type
  log("Validating data type: " & node.value & " at index " & $index)
  
  # Check for property reference (enclosed in single quotes)
  if node.value.startsWith("'") and node.value.endsWith("'"):
    let propName = node.value[1..^2]
    log("Detected property reference: " & propName)
    
    # Check for circular references
    if propName in visitedProperties:
      log("Circular reference detected for property: " & propName)
      return MatchResult(success: true, index: index, errors: @[])
    
    # Validate the property
    visitedProperties.incl(propName)
    defer: visitedProperties.excl(propName)
    
    if properties.hasKey(propName):
      let propSyntax = properties[propName].syntax
      let propAst = parseSyntax(propSyntax)
      
      # Handle quantified property references
      if node.isQuantified:
        log("Processing quantified property reference: " & propName & " {" & $node.min & "," & 
            (if node.max.isSome: $node.max.get else: "unlimited") & "}")
        
        var curIndex = index
        var matchCount = 0
        
        # Match the property pattern multiple times
        while curIndex < tokens.len:
          if node.max.isSome and matchCount >= node.max.get:
            break
          
          let res = validateNode(propAst, tokens, curIndex, visitedProperties)
          
          if res.success and res.index > curIndex:
            curIndex = res.index
            inc(matchCount)
            log("Matched occurrence " & $matchCount & " of property " & propName)
          else:
            break
        
        # Check if minimum occurrences constraint is satisfied
        if matchCount < node.min:
          return MatchResult(success: false, index: index,
                          errors: @["Expected at least " & $node.min & " occurrences of property '" & 
                                  propName & "', got " & $matchCount])
        
        return MatchResult(success: true, index: curIndex, errors: @[])
      else:
        # Original code for non-quantified property references
        if index < tokens.len:
          return validateNode(propAst, tokens, index, visitedProperties)
        else:
          return MatchResult(success: false, index: index, 
                           errors: @["Expected property '" & propName & "', reached end"])
    else:
      return MatchResult(success: false, index: index,
                        errors: @["Unknown property: " & propName])
  
  # Handle quantified data types (like <number>#{3})
  if node.isQuantified:
    # Rest of the original quantified data type code...
    log("Processing quantified data type: " & node.value & " {" & $node.min & "," & 
        (if node.max.isSome: $node.max.get else: "unlimited") & "}")
    
    var curIndex = index
    var matchCount = 0
    
    # Special handling for cases like <number>#{3} which should match exactly 3 consecutive numbers
    if node.min == node.max.get and node.min > 1:
      log("Exact quantity required: " & $node.min)
      
      # For each required occurrence
      for i in 1..node.min:
        # Skip over commas between values, but not before the first one
        if i > 1 and curIndex < tokens.len and tokens[curIndex].kind == vtkComma:
          log("Skipping comma separator")
          inc(curIndex)
        
        # Check if we ran out of tokens
        if curIndex >= tokens.len:
          return MatchResult(success: false, index: index,
                            errors: @["Expected " & $node.min & " occurrences of '" & 
                                    node.value & "', got " & $matchCount])
        
        # Validate the current token against the data type
        let token = tokens[curIndex]
        
        if validateBuiltinDataType(node.value, token, visitedProperties):
          inc(curIndex)
          inc(matchCount)
          log("Matched occurrence " & $matchCount & " of " & node.value)
        else:
          return MatchResult(success: false, index: index,
                            errors: @["Expected data type '" & node.value & "' at position " & $i])
      
      return MatchResult(success: true, index: curIndex, errors: @[])
    
    # Standard quantified type handling
    while curIndex < tokens.len:
      if node.max.isSome and matchCount >= node.max.get:
        break
      
      var matched = false
      
      # Check if data type is defined in extended syntaxes
      if syntaxes.hasKey(node.value):
        let syntaxDef = syntaxes[node.value].syntax
        let subAst = parseSyntax(syntaxDef)
        let res = validateNode(subAst, tokens, curIndex, visitedProperties)
        
        if res.success and res.index > curIndex:
          curIndex = res.index
          inc(matchCount)
          matched = true
      else:
        # Try built-in data type validation
        if curIndex < tokens.len:
          let token = tokens[curIndex]
          
          # Handle sequence token specially
          if token.kind == vtkSequence and token.children.len > 0:
            if validateBuiltinDataType(node.value, token.children[0], visitedProperties):
              inc(curIndex)
              inc(matchCount)
              matched = true
          elif token.kind != vtkComma and validateBuiltinDataType(node.value, token, visitedProperties):
            inc(curIndex)
            inc(matchCount)
            matched = true
      
      if not matched:
        break
    
    # Check if minimum occurrences constraint is satisfied
    if matchCount < node.min:
      return MatchResult(success: false, index: index,
                        errors: @["Expected at least " & $node.min & " occurrences of '" & 
                                node.value & "', got " & $matchCount])
    
    return MatchResult(success: true, index: curIndex, errors: @[])
  
  # Special handling for specific data types
  if node.value == "alpha-value":
    log("Special handling for alpha-value")
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected alpha-value but reached end"])
    
    let token = tokens[index]
    if token.kind == vtkNumber or token.kind == vtkPercentage:
      return MatchResult(success: true, index: index + 1, errors: @[])
    else:
      return MatchResult(success: false, index: index,
                        errors: @["Expected alpha-value, got " & token.value])
  
  # Special handling for declaration-list
  elif node.value == "declaration-list":
    log("Special handling for declaration-list")
    
    # First check if this is a sequence of properties
    if index < tokens.len:
      # If the first token is a sequence, use the existing sequence handling
      if tokens[index].kind == vtkSequence:
        log("Found sequence token for declaration-list")
        let innerTokens = tokens[index].children
        
        # Check if all children are properties
        var allProperties = true
        for child in innerTokens:
          if child.kind != vtkProperty:
            allProperties = false
            log("Invalid token in declaration-list sequence: " & $child.kind)
            break
        
        if allProperties:
          log("All tokens in sequence are properties, valid declaration-list")
          return MatchResult(success: true, index: index + 1, errors: @[])
        else:
          return MatchResult(success: false, index: index, 
                          errors: @["Not all tokens in sequence are properties"])
      else:
        # Handle consecutive property tokens
        var currentIndex = index
        var foundProperty = false
        
        while currentIndex < tokens.len and tokens[currentIndex].kind == vtkProperty:
          foundProperty = true
          currentIndex += 1
        
        # Check if we've processed all tokens
        if foundProperty and currentIndex == tokens.len:
          log("Found " & $(currentIndex - index) & " consecutive property tokens")
          return MatchResult(success: true, index: currentIndex, errors: @[])
        # Check if we have remaining non-property tokens
        elif foundProperty and currentIndex < tokens.len:
          log("Found non-property token after properties at index " & $currentIndex)
          return MatchResult(success: false, index: index,
                          errors: @["Invalid token in declaration-list: " & $tokens[currentIndex].kind])
        else:
          return MatchResult(success: false, index: index,
                          errors: @["Expected property token for declaration-list"])
    else:
      return MatchResult(success: false, index: index,
                        errors: @["Expected declaration-list, reached end"])
  # Non-quantified data type
  elif syntaxes.hasKey(node.value):
    log("Using syntax definition for: " & node.value)
    let syntaxDef = syntaxes[node.value].syntax
    let subAst = parseSyntax(syntaxDef)
    
    # Special handling for sequence tokens
    if index < tokens.len and tokens[index].kind == vtkSequence:
      let innerTokens = tokens[index].children
      let res = validateNode(subAst, innerTokens, 0, visitedProperties)
      
      if res.success and res.index == innerTokens.len:
        return MatchResult(success: true, index: index + 1, errors: @[])
      else:
        return MatchResult(success: false, index: index, errors: res.errors)
    else:
      return validateNode(subAst, tokens, index, visitedProperties)
  else:
    log("Using built-in validation for: " & node.value)
    
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected '" & node.value & "' but reached end"])
    
    let token = tokens[index]
    if validateBuiltinDataType(node.value, token, visitedProperties):
      return MatchResult(success: true, index: index + 1, errors: @[])
    else:
      return MatchResult(success: false, index: index,
                        errors: @["Type '" & node.value & "' rejected token: " & token.value])

proc validateFunction(node: Node, tokens: seq[ValueToken], index: int, visitedProperties: var HashSet[string]): MatchResult =
  ## Validates a function node
  log("Validating function: " & node.value)
  
  if index >= tokens.len:
    return MatchResult(success: false, index: index, 
                      errors: @["Expected function " & node.value & ", reached end"])
  
  let token = tokens[index]
  if token.kind != vtkFunc or token.value != node.value:
    return MatchResult(success: false, index: index,
                      errors: @["Expected function " & node.value & ", got " & token.value])
  
  # No arguments to validate
  if token.children.len == 0:
    return MatchResult(success: true, index: index + 1, errors: @[])
  
  # Extract argument tokens
  log("Function has " & $token.children.len & " argument tokens")
  
  # Flatten argument tokens for easier processing
  var argTokens: seq[ValueToken] = @[]
  
  # Process the argument tokens
  for child in token.children:
    if child.kind == vtkSequence:
      # Add each child of the sequence
      for seqChild in child.children:
        argTokens.add(seqChild)
    else:
      # Add the token as-is
      argTokens.add(child)
  
  log("Flattened to " & $argTokens.len & " argument tokens")
  for i, arg in argTokens:
    log("  Arg " & $i & ": " & arg.value & " (" & $arg.kind & ")")
  
  # Special handling: Check if any parameter is a var() function
  var hasVarFunction = false
  for arg in argTokens:
    if arg.kind == vtkFunc and arg.value == "var":
      hasVarFunction = true
      log("Detected var() function as parameter - enabling flexible parameter validation")
      break
  
  # If any parameter is a var() function, we need to be more lenient
  if hasVarFunction:
    # Basic validation: just make sure the function has at least one parameter
    if argTokens.len > 0:
      log("var() function could provide multiple values - skipping strict parameter validation")
      return MatchResult(success: true, index: index + 1, errors: @[])
  
  # Check if the node has children (function arguments in the AST)
  if node.children.len > 0:
    log("Function node has " & $node.children.len & " children in AST")
    
    # Log the AST structure for debugging
    proc logAstStructure(n: Node, indent: int = 0) =
      let indentStr = repeat("  ", indent)
      log(indentStr & "Node: " & $n.kind & " '" & n.value & "'")
      for child in n.children:
        logAstStructure(child, indent + 1)
    
    log("Function arguments AST structure:")
    for i, child in node.children:
      log("Child " & $i & ":")
      logAstStructure(child)
    
    # Special handling: Check if there's a declaration-value as an argument
    var hasDeclarationValue = false
    var declarationValueIndex = -1
    
    for i, child in node.children:
      let nodeToCheck = if child.kind == nkOptional and child.children.len > 0: child.children[0] else: child
      if nodeToCheck.kind == nkDataType and nodeToCheck.value == "declaration-value":
        hasDeclarationValue = true
        declarationValueIndex = i
        log("Found declaration-value at argument index " & $i)
        break
    
    # If we have a declaration-value argument, handle it specially
    if hasDeclarationValue:
      log("Special handling for declaration-value argument")
      
      var currentArgTokenIndex = 0
      var allArgsValid = true
      var errors: seq[string] = @[]
      
      # Process arguments before the declaration-value
      for i in 0..<declarationValueIndex:
        let argAst = node.children[i]
        
        # Handle required vs optional arguments
        let isOptional = argAst.kind == nkOptional
        
        # If it's optional, validate the inner node
        let nodeToValidate = if isOptional and argAst.children.len > 0: argAst.children[0] else: argAst
        
        # Special handling for comma separators in the AST
        if nodeToValidate.kind == nkSeparator and nodeToValidate.value == ",":
          log("Checking for comma separator")
          # If we have a comma token, consume it
          if currentArgTokenIndex < argTokens.len and argTokens[currentArgTokenIndex].kind == vtkComma:
            log("Found comma token, consuming it")
            currentArgTokenIndex += 1
          # Otherwise assume the tokenizer didn't separate the commas
          continue
        
        # Skip validation if we've run out of tokens and this is optional
        if currentArgTokenIndex >= argTokens.len:
          if isOptional:
            log("No more tokens but argument " & $i & " is optional - continuing")
            continue
          else:
            log("Missing required argument " & $i)
            allArgsValid = false
            errors.add("Missing required argument " & $i)
            break
        
        # Validate the current argument
        let res = validateNode(nodeToValidate, argTokens, currentArgTokenIndex, visitedProperties)
        
        if res.success:
          log("Argument " & $i & " validated successfully, consumed " & 
              $(res.index - currentArgTokenIndex) & " tokens")
          currentArgTokenIndex = res.index
        else:
          # If it's an optional argument, failure is ok
          if isOptional:
            log("Optional argument " & $i & " failed validation, but that's ok")
          else:
            log("Required argument " & $i & " failed validation")
            allArgsValid = false
            errors.add("Invalid argument " & $i & ": " & res.errors.join(", "))
            break
      
      # If we successfully validated all arguments before declaration-value
      if allArgsValid:
        # Now handle the declaration-value argument, which should consume all remaining tokens
        if currentArgTokenIndex < argTokens.len:
          log("Validating declaration-value with all remaining tokens starting at index " & $currentArgTokenIndex)
          
          # Get the declaration-value node
          let declValueNode = 
            if node.children[declarationValueIndex].kind == nkOptional:
              node.children[declarationValueIndex].children[0]
            else:
              node.children[declarationValueIndex]
          
          # Create a sequence token from all remaining tokens
          var remainingTokensSequence = ValueToken(kind: vtkSequence, value: "")
          for i in currentArgTokenIndex..<argTokens.len:
            remainingTokensSequence.children.add(argTokens[i])
          
          # Validate against declaration-value
          let isValid = validateBuiltinDataType("declaration-value", remainingTokensSequence, visitedProperties)
          
          if isValid:
            log("All remaining tokens validated successfully as declaration-value")
            return MatchResult(success: true, index: index + 1, errors: @[])
          else:
            log("Failed to validate remaining tokens as declaration-value")
            return MatchResult(success: false, index: index,
                              errors: @["Invalid declaration-value argument"])
        else:
          # No tokens remaining for declaration-value
          let isOptional = node.children[declarationValueIndex].kind == nkOptional
          
          if isOptional:
            log("No tokens for optional declaration-value - that's fine")
            return MatchResult(success: true, index: index + 1, errors: @[])
          else:
            log("Missing required declaration-value argument")
            return MatchResult(success: false, index: index,
                              errors: @["Missing required declaration-value argument"])
      else:
        # Failed to validate arguments before declaration-value
        return MatchResult(success: false, index: index, errors: errors)
    else:
      # Normal validation for functions without declaration-value
      var argTokenIndex = 0
      var astNodeIndex = 0
      var errors: seq[string] = @[]
      
      # Process each argument in the function's syntax definition
      while astNodeIndex < node.children.len:
        let astNode = node.children[astNodeIndex]
        log("Validating argument " & $astNodeIndex & ":")
        
        # Handle comma separators in the AST
        if astNode.kind == nkSeparator and astNode.value == ",":
          log("Found comma separator in AST at index " & $astNodeIndex)
          
          # Skip an actual comma token if present
          if argTokenIndex < argTokens.len and argTokens[argTokenIndex].kind == vtkComma:
            log("Skipping matching comma token at index " & $argTokenIndex)
            argTokenIndex += 1
          
          # Move to next AST node
          astNodeIndex += 1
          continue
        
        # Check if we've run out of tokens
        if argTokenIndex >= argTokens.len:
          let isOptional = astNode.kind == nkOptional
          if isOptional:
            log("No more tokens but node at index " & $astNodeIndex & " is optional - continuing")
            astNodeIndex += 1
            continue
          else:
            return MatchResult(success: false, index: index,
                              errors: @["Missing required argument at position " & $astNodeIndex])
        
        # Special handling for comma lists with hash notation
        if astNode.kind == nkCommaList and astNode.children.len == 1 and 
           astNode.children[0].kind == nkDataType and astNode.children[0].isQuantified:
          
          let dataTypeNode = astNode.children[0]
          # Check for exact count specification (min == max)
          if dataTypeNode.max.isSome and dataTypeNode.min == dataTypeNode.max.get:
            let requiredCount = dataTypeNode.min
            let dataType = dataTypeNode.value
            
            log("Processing hash notation: " & dataType & "#{" & $requiredCount & "}")
            
            var matchedCount = 0
            var tempIndex = argTokenIndex
            
            # Collect exactly the required number of matching tokens
            while tempIndex < argTokens.len and matchedCount < requiredCount:
              # Skip commas between items (but not before the first one)
              if matchedCount > 0 and tempIndex < argTokens.len and
                 argTokens[tempIndex].kind == vtkComma:
                tempIndex += 1
                continue
              
              # Validate token against the data type
              let token = argTokens[tempIndex]
              if validateBuiltinDataType(dataType, token, visitedProperties):
                matchedCount += 1
                tempIndex += 1
                log("Matched " & dataType & " #" & $matchedCount & ": " & token.value)
              else:
                # Token doesn't match expected type
                return MatchResult(success: false, index: index,
                                 errors: @["Item at position " & $matchedCount & 
                                          " is not a valid " & dataType & ": " & token.value])
            
            # Verify we matched exactly the required count
            if matchedCount == requiredCount:
              log("Successfully matched " & $requiredCount & " occurrences of " & dataType)
              argTokenIndex = tempIndex
              astNodeIndex += 1
              continue
            else:
              return MatchResult(success: false, index: index,
                               errors: @["Expected " & $requiredCount & " occurrences of '" & 
                                        dataType & "', got " & $matchedCount])
          
        # Check if this is an optional argument
        let isOptional = astNode.kind == nkOptional
        log("Argument is " & (if isOptional: "optional" else: "required"))
        
        # If it's optional, validate the inner node
        let nodeToValidate = if isOptional and astNode.children.len > 0: astNode.children[0] else: astNode
        
        # Validate the current argument
        let res = validateNode(nodeToValidate, argTokens, argTokenIndex, visitedProperties)
        
        if res.success:
          log("Argument " & $astNodeIndex & " validated successfully, consumed " & 
              $(res.index - argTokenIndex) & " tokens")
          argTokenIndex = res.index
          astNodeIndex += 1
        else:
          # If it's an optional argument, failure is ok
          if isOptional:
            log("Optional argument " & $astNodeIndex & " failed validation, but that's ok")
            astNodeIndex += 1
          else:
            log("Required argument " & $astNodeIndex & " failed validation")
            return MatchResult(success: false, index: index,
                              errors: @["Invalid argument at position " & $astNodeIndex & ": " & 
                                        res.errors.join(", ")])
      
      # Check if we consumed all tokens
      if argTokenIndex == argTokens.len:
        log("All arguments validated and all tokens consumed")
        return MatchResult(success: true, index: index + 1, errors: @[])
      else:
        # If we have var() functions as parameters, extra tokens are allowed
        if hasVarFunction:
          log("var() function present - allowing extra tokens")
          return MatchResult(success: true, index: index + 1, errors: @[])
        else:
          log("Not all tokens consumed - this is an error")
          return MatchResult(success: false, index: index,
                           errors: @["Extra unexpected tokens: " & $argTokenIndex & "/" & $argTokens.len])
  
  # If no AST children, check for extended function syntax
  var funcSyntax = ""
  if functions.hasKey(node.value & "()"):
    funcSyntax = functions[node.value & "()"].syntax
    log("Using extended function syntax: " & funcSyntax)
  
  if funcSyntax.len > 0:
    let funcAst = parseSyntax(funcSyntax)
    
    # Use the same validation logic as above
    if funcAst.kind == nkFunction:
      # Create a new MatchResult with the extended AST
      return validateFunction(funcAst, tokens, index, visitedProperties)
  
  # If we get here, we couldn't validate the function
  return MatchResult(success: false, index: index,
                    errors: @["No definition for function " & node.value])

proc isVarFunction(token: ValueToken): bool =
  ## Helper function to check if a token is a var() function
  return token.kind == vtkFunc and token.value == "var"

proc validateNode(node: Node, tokens: seq[ValueToken], index: int, visitedProperties: var HashSet[string]): MatchResult {.gcsafe.} =
  ## Main validator function that handles all node kinds
  log("Validating node: " & $node.kind & " '" & node.value & "' at index " & $index)
  

  # Special case: For recursive calc() functions
  if index < tokens.len and tokens[index].kind == vtkFunc and tokens[index].value == "calc":
    if node.kind == nkDataType:
      let calcAllowedTypes = ["length", "time", "frequency", "angle", "number", "percentage", 
                             "length-percentage", "flex", "integer"]
                             
      if node.value in calcAllowedTypes:
        log("Accepting calc() function for data type: " & node.value)
        return MatchResult(success: true, index: index + 1, errors: @[])

  # Skip validation if we've reached the end of tokens and node is optional
  if index >= tokens.len and not isNodeOptional(node):
    return MatchResult(success: false, index: index,
                      errors: @["Expected " & $node.kind & " but reached end"])
  
  case node.kind
  of nkRule:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                      errors: @["Expected rule, reached end"])
    
    let token = tokens[index]
    
    # Check if the token is a rule
    if token.kind != vtkRule:
      return MatchResult(success: false, index: index,
                      errors: @["Expected rule, got " & $token.kind & " '" & token.value & "'"])
    
    # Validation flags and errors
    var hasValidChildren = true
    var childErrors: seq[string] = @[]
    
    # For a rule, get the selector tokens
    var selectorTokens: seq[ValueToken] = @[]
    if token.value.len > 0:
      # Tokenize the rule selector using the existing tokenizer
      selectorTokens = tokenizeValue(token.value, wrapRoot=false)
      log("Tokenized rule selector into " & $selectorTokens.len & " tokens")
    elif token.children.len > 0:
      # Use the child tokens directly
      selectorTokens = token.children
      log("Using " & $selectorTokens.len & " existing child tokens for selector")
    
    echo "Got selector tokens:"
    echo $selectorTokens

    # Check if the node requires parameters (selector)
    if node.children.len > 0:
      log("Validating rule selector tokens")
      
      # Validate the selector against the first child (which should be a comma list or other selector pattern)
      let selectorResult = validateNode(node.children[0], selectorTokens, 0, visitedProperties)
      
      if not selectorResult.success:
        hasValidChildren = false
        childErrors.add("Invalid selector: " & selectorResult.errors.join(", "))
      # If all selector tokens are not consumed, that's an error
      elif selectorResult.index < selectorTokens.len:
        hasValidChildren = false
        childErrors.add("Extra unexpected tokens in selector at position " & $selectorResult.index)
    
    # Check for body validation
    var hasValidBody = true
    
    # Use the dedicated body field for rules
    if node.body.len > 0:
      # The body validator is the first node in the body sequence
      let bodyValidator = node.body[0]
      log("Found body validator: " & $bodyValidator.kind & " '" & bodyValidator.value & "'")
      
      # Check if a body is required but missing
      if token.body.len == 0:
        hasValidBody = false
        childErrors.add("Missing required body for rule")
      # Validate the body content if present
      elif token.body.len > 0:
        log("Validating rule body with " & $token.body.len & " tokens")
        for i, bodyToken in token.body:
          log("  Body token " & $i & ": " & $bodyToken.kind & " '" & bodyToken.value & "'")
        
        let bodyResult = validateNode(bodyValidator, token.body, 0, visitedProperties)
        if not bodyResult.success:
          hasValidBody = false
          childErrors.add("Invalid body content: " & bodyResult.errors.join(", "))
    
    # Return success if selector is valid and body is valid
    if hasValidChildren and hasValidBody:
      return MatchResult(success: true, index: index + 1, errors: @[])
    else:
      return MatchResult(success: false, index: index, errors: childErrors)

  of nkKeyword:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected keyword " & node.value & ", reached end"])
    
    # Special handling for var() functions - they can substitute for any keyword
    if isVarFunction(tokens[index]):
      log("var() function accepted as substitute for keyword: " & node.value)
      return MatchResult(success: true, index: index + 1, errors: @[])
    
    if tokens[index].kind != vtkIdent or tokens[index].value != node.value:
      return MatchResult(success: false, index: index,
                        errors: @["Expected keyword " & node.value & ", got " & tokens[index].value])
    
    return MatchResult(success: true, index: index + 1, errors: @[])
  
  of nkAtRule:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected at-rule " & node.value & ", reached end"])
    
    let token = tokens[index]
    
    # Check if the token is an at-rule of the expected type
    if token.kind != vtkAtRule or token.value != node.value:
      return MatchResult(success: false, index: index,
                        errors: @["Expected at-rule " & node.value & ", got " & $token.kind & " '" & token.value & "'"])
    
    # Validation flags and errors
    var hasValidChildren = true
    var childErrors: seq[string] = @[]
    
    # Check if the node requires parameters
    if node.children.len > 0:
      let paramValidator = node.children[0]
      let isParamOptional = paramValidator.kind == nkOptional
      
      if not isParamOptional and token.children.len == 0:
        hasValidChildren = false
        childErrors.add("Missing required parameters for " & node.value)
      elif token.children.len > 0:
        # Validate the parameters that are present
        log("Validating at-rule parameters")
        let paramResult = validateNode(paramValidator, token.children, 0, visitedProperties)
        
        if not paramResult.success:
          hasValidChildren = false
          childErrors.add("Invalid parameters: " & paramResult.errors.join(", "))
    
    # Check for body validation
    var hasValidBody = true
    
    # Use the dedicated body field for at-rules
    if node.body.len > 0:
      # The body validator is the first node in the body sequence
      let bodyValidator = node.body[0]
      log("Found body validator: " & $bodyValidator.kind & " '" & bodyValidator.value & "'")
      
      # Check if body is required
      let isBodyRequired = bodyValidator.kind == nkRequired
      
      # Get the actual validator node if wrapped in required
      let actualBodyValidator = if isBodyRequired and bodyValidator.children.len > 0:
                                bodyValidator.children[0]
                              else:
                                bodyValidator
      
      # Check if a body is required but missing
      if isBodyRequired and token.body.len == 0:
        hasValidBody = false
        childErrors.add("Missing required body for " & node.value)
      # Validate the body content if present
      elif token.body.len > 0:
        log("Validating at-rule body with " & $token.body.len & " tokens")
        for i, bodyToken in token.body:
          log("  Body token " & $i & ": " & $bodyToken.kind & " '" & bodyToken.value & "'")
        
        let bodyResult = validateNode(actualBodyValidator, token.body, 0, visitedProperties)
        if not bodyResult.success:
          hasValidBody = false
          childErrors.add("Invalid body content: " & bodyResult.errors.join(", "))
    
    # Return success if parameters are valid and body is valid (or not required)
    if hasValidChildren and hasValidBody:
      return MatchResult(success: true, index: index + 1, errors: @[])
    else:
      return MatchResult(success: false, index: index, errors: childErrors)

  of nkDataType:
    return validateDataType(node, tokens, index, visitedProperties)
  
  of nkFunction:
    return validateFunction(node, tokens, index, visitedProperties)
  
  of nkSequence:
    var currentIndex = index
    
    for child in node.children:
      let res = validateNode(child, tokens, currentIndex, visitedProperties)
      if not res.success:
        return MatchResult(success: false, index: currentIndex, errors: res.errors)
      currentIndex = res.index
    
    return MatchResult(success: true, index: currentIndex, errors: @[])
  
  of nkChoice:
    # Special handling for var() functions with choices
    if index < tokens.len and isVarFunction(tokens[index]):
      log("var() function accepted as substitute for choice")
      return MatchResult(success: true, index: index + 1, errors: @[])
    
    # Try each alternative and return first success
    var allErrors: seq[string] = @[]
    
    for child in node.children:
      let res = validateNode(child, tokens, index, visitedProperties)
      if res.success:
        return res
      allErrors.add(res.errors)
    
    return MatchResult(success: false, index: index, 
                      errors: @["None of the alternatives matched"])
  
  of nkAndList:
    var matched = newSeq[bool](node.children.len)
    var currentIndex = index
    var progress = true
    var matchCount = 0
    
    # Keep trying until no more progress can be made
    while progress and currentIndex < tokens.len:
      progress = false
      
      for i in 0..<node.children.len:
        if matched[i]: continue
        
        let child = node.children[i]
        let res = validateNode(child, tokens, currentIndex, visitedProperties)
        
        if res.success and res.index > currentIndex:
          matched[i] = true
          inc(matchCount)
          currentIndex = res.index
          progress = true
          break
      
      if matchCount == node.children.len:
        break
    
    # Check for missing required children
    for i in 0..<node.children.len:
      if not matched[i] and not isNodeOptional(node.children[i]):
        return MatchResult(success: false, index: index,
                          errors: @["Required component not matched"])
    
    return MatchResult(success: true, index: currentIndex, errors: @[])
  
  of nkOrList:
    # Fixed implementation for OrList (||) combinator
    var currentIndex = index
    var matchedComponents = newSeq[bool](node.children.len)
    var anyMatched = false
    
    # Continue processing tokens as long as we can match components
    while currentIndex < tokens.len:
      var madeProgress = false
      
      # Try to match each unmatched component with the current token
      for i in 0..<node.children.len:
        if matchedComponents[i]:
          continue
        
        let childRes = validateNode(node.children[i], tokens, currentIndex, visitedProperties)
        if childRes.success and childRes.index > currentIndex:
          log("Matched component " & $i & " at index " & $currentIndex)
          matchedComponents[i] = true
          currentIndex = childRes.index
          anyMatched = true
          madeProgress = true
          break
      
      # If we didn't match any component with the current token, we're done
      if not madeProgress:
        break
    
    # OrList is valid if at least one component matched
    return MatchResult(success: anyMatched, index: currentIndex, errors: @[])
  
  of nkOptional:
    if node.children.len == 0:
      return MatchResult(success: true, index: index, errors: @[])
    
    let res = validateNode(node.children[0], tokens, index, visitedProperties)
    if res.success:
      return res
    else:
      # It's optional, so success even if child didn't match
      return MatchResult(success: true, index: index, errors: @[])
  
  of nkZeroOrMore:
    var currentIndex = index
    
    while currentIndex < tokens.len:
      let res = validateNode(node.children[0], tokens, currentIndex, visitedProperties)
      if res.success and res.index > currentIndex:
        currentIndex = res.index
      else:
        break
    
    return MatchResult(success: true, index: currentIndex, errors: @[])
  
  of nkOneOrMore:
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
                        errors: @["OneOrMore node has no child to match"])
    
    # Must have at least one match
    let firstMatch = validateNode(node.children[0], tokens, index, visitedProperties)
    if not firstMatch.success:
      return MatchResult(success: false, index: index,
                        errors: @["Expected at least one occurrence"])
    
    var currentIndex = firstMatch.index
    
    # Try to match more if possible
    while currentIndex < tokens.len:
      let res = validateNode(node.children[0], tokens, currentIndex, visitedProperties)
      if res.success and res.index > currentIndex:
        currentIndex = res.index
      else:
        break
    
    return MatchResult(success: true, index: currentIndex, errors: @[])
  
  of nkCommaList:
    # Handle the case where we have individual tokens without explicit commas
    if node.children.len > 0 and tokens.len > 0 and 
      not tokens.any(proc(t: ValueToken): bool = t.kind == vtkComma):
      var allValid = true
      var errors: seq[string] = @[]
      
      # Validate each token individually
      for i, token in tokens:
        let res = validateNode(node.children[0], @[token], 0, visitedProperties)
        if not res.success:
          allValid = false
          errors.add("Item at position " & $i & " is invalid: " & res.errors.join(", "))
      
      if allValid:
        return MatchResult(success: true, index: tokens.len, errors: @[])
      else:
        return MatchResult(success: false, index: index, errors: errors)
    if tokens.len > 0 and not tokens.any(proc(t: ValueToken): bool = t.kind == vtkComma):
      # Validate the entire sequence as a single item
      let res = validateNode(node.children[0], tokens, 0, visitedProperties)
      if res.success:
        return MatchResult(success: true, index: tokens.len, errors: @[])
      else:
        return MatchResult(success: false, index: index, 
                          errors: @["Single item in comma list is invalid: " & res.errors.join(", ")])
  

    # Add special handling for data types with hash-based quantification
    if node.children.len == 1 and 
      node.children[0].kind == nkDataType and 
      node.children[0].isQuantified and 
      node.children[0].min == node.children[0].max.get:
      
      # Get the required count
      let requiredCount = node.children[0].min
      let dataType = node.children[0].value
      
      # Count the actual tokens (excluding commas)
      var itemCount = 0
      var i = index
      
      # First, count all the numbers in the token stream
      while i < tokens.len:
        if tokens[i].kind != vtkComma:
          # Validate this token is the right type
          if not validateBuiltinDataType(dataType, tokens[i], visitedProperties):
            return MatchResult(success: false, index: index,
                            errors: @["Item at position " & $itemCount & " is not a valid " & dataType])
          
          inc(itemCount)
        i += 1
      
      # Verify we got the expected count
      if itemCount == requiredCount:
        return MatchResult(success: true, index: tokens.len, errors: @[])
      else:
        return MatchResult(success: false, index: index,
                          errors: @["Expected " & $requiredCount & " occurrences of '" & 
                                  dataType & "', got " & $itemCount])
      
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
                        errors: @["CommaList node has no child to match"])
    
    # Fix for comma list handling
    # First, flatten the tokens to properly handle sequences and commas
    var flattenedTokens: seq[ValueToken] = @[]
    var i = index
    var firstItem = true
    
    while i < tokens.len:
      let token = tokens[i]
      
      # Check if this is a comma separator
      if token.kind == vtkComma:
        flattenedTokens.add(token)
        i += 1
        continue
      
      # If this is a sequence token
      if token.kind == vtkSequence:
        if not firstItem and (flattenedTokens.len == 0 or flattenedTokens[^1].kind != vtkComma):
          # If not first item and no comma before it, insert a comma
          flattenedTokens.add(ValueToken(kind: vtkComma, value: ","))
        
        for childToken in token.children:
          flattenedTokens.add(childToken)
        
        firstItem = false
        i += 1
      else:
        # Regular token
        if not firstItem and (flattenedTokens.len == 0 or flattenedTokens[^1].kind != vtkComma):
          # If not first item and no comma before it, insert a comma
          flattenedTokens.add(ValueToken(kind: vtkComma, value: ","))
        
        flattenedTokens.add(token)
        firstItem = false
        i += 1
    
    # Now process the flattened tokens
    var currentIndex = 0
    var isFirst = true
    
    while currentIndex < flattenedTokens.len:
      # Skip commas between items
      if not isFirst and currentIndex < flattenedTokens.len and flattenedTokens[currentIndex].kind == vtkComma:
        currentIndex += 1
        # If comma is the last token, it's an error
        if currentIndex >= flattenedTokens.len:
          return MatchResult(success: false, index: index,
                            errors: @["List ends with comma"])
      
      # Find the next comma
      var nextCommaIndex = -1
      for j in currentIndex..<flattenedTokens.len:
        if flattenedTokens[j].kind == vtkComma:
          nextCommaIndex = j
          break
      
      # Determine the end index for current item
      let endIndex = if nextCommaIndex == -1: flattenedTokens.len else: nextCommaIndex
      
      let itemTokens = flattenedTokens[currentIndex..<endIndex]
      if itemTokens.len == 0:
        # Empty item (double comma)
        return MatchResult(success: false, index: index,
                          errors: @["Empty item in comma list"])
      
      let res = validateNode(node.children[0], itemTokens, 0, visitedProperties)
      
      if not res.success:
        if isFirst:
          return MatchResult(success: false, index: index,
                            errors: @["First item in comma list is invalid: " & res.errors.join(", ")])
        else:
          return MatchResult(success: false, index: index,
                            errors: @["Invalid item at position " & $currentIndex & " in comma list: " & res.errors.join(", ")])
      
      # Move to the next item
      currentIndex = endIndex
      isFirst = false
    
    # Successfully validated all items in the comma list
    return MatchResult(success: true, index: tokens.len, errors: @[])
  

  of nkSpaceList:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected space list, reached end"])
    
    if tokens[index].kind != vtkSequence:
      return MatchResult(success: false, index: index,
                        errors: @["Expected space list as sequence"])
    
    let seqToken = tokens[index]
    
    for childToken in seqToken.children:
      let res = validateNode(node.children[0], @[childToken], 0, visitedProperties)
      if not res.success:
        return MatchResult(success: false, index: index, 
                          errors: @["Invalid item in space list"])
    
    return MatchResult(success: true, index: index + 1, errors: @[])
  
  of nkQuantified:
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
                        errors: @["Quantified node has no child to match"])
    
    var currentIndex = index
    var count = 0
    
    # Try to match the pattern multiple times
    while currentIndex < tokens.len:
      let childRes = validateNode(node.children[0], tokens, currentIndex, visitedProperties)
      
      if childRes.success and childRes.index > currentIndex:
        currentIndex = childRes.index
        inc(count)
        
        if node.max.isSome and count >= node.max.get:
          break
      else:
        break
    
    # Check minimum occurrences constraint
    if count < node.min:
      return MatchResult(success: false, index: index,
                        errors: @["Expected at least " & $node.min & " occurrences, got " & $count])
    
    return MatchResult(success: true, index: currentIndex, errors: @[])
  
  of nkValueRange:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected value in range, reached end"])
    
    # Special handling for var() functions - they can substitute for any value range
    if isVarFunction(tokens[index]):
      log("var() function accepted as substitute for value range")
      return MatchResult(success: true, index: index + 1, errors: @[])
    
    let token = tokens[index]
    if not token.hasNumValue:
      return MatchResult(success: false, index: index,
                        errors: @["Expected numeric value for range"])
    
    try:
      let value = token.numValue
      let minValue = parseFloat(node.minValue)
      let maxValue = parseFloat(node.maxValue)
      
      if value < minValue or value > maxValue:
        return MatchResult(success: false, index: index,
                          errors: @["Value " & $value & " not in range [" & 
                                  node.minValue & ", " & node.maxValue & "]"])
      
      return MatchResult(success: true, index: index + 1, errors: @[])
    except ValueError:
      return MatchResult(success: false, index: index,
                        errors: @["Failed to parse numeric values for range comparison"])
  
  of nkSeparator:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
                        errors: @["Expected separator " & node.value & ", reached end"])
    
    if tokens[index].value != node.value:
      return MatchResult(success: false, index: index,
                        errors: @["Expected separator " & node.value & ", got " & tokens[index].value])
    
    return MatchResult(success: true, index: index + 1, errors: @[])
  
  of nkRequired:
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
                        errors: @["Required node has no child to match"])
    
    let res = validateNode(node.children[0], tokens, index, visitedProperties)
    
    if not res.success:
      return MatchResult(success: false, index: index,
                        errors: @["Required component missing"])
    
    return res
  
  else:
    return MatchResult(success: false, index: index,
                      errors: @["Unsupported node kind: " & $node.kind])


#---------------------------------------------------------
# PUBLIC API
#---------------------------------------------------------

proc validate*(syntaxStr: string, tokens: seq[ValueToken]): ValidatorResult {.gcsafe.} =
  ## Validates a CSS value against a syntax definition
  
  # Initialize visited properties set to prevent circular references
  # visitedProperties = initHashSet[string]()
  
  # Parse syntax and value
  let ast = parseSyntax(syntaxStr)
  
  log "Syntax AST:"
  log ast.treeRepr

  log "Value Tokens:"
  log tokens.treeRepr


  proc isVarToken(token: ValueToken): bool =
    return token.kind == vtkFunc and token.value == "var"
  # var areAllVars = false
  # proc checkAreAllVars(tokens: seq[ValueToken]): bool =
  #   for token in tokens:
  #     if isVarToken(token):
  #       areAllVars = true
  #     elif token.kind == vtkSequence:
  #       areAllVars = checkAreAllVars(token.children)
  #       if not areAllVars:
  #         break
  #     else:
  #       areAllVars = false
  #       break
  #   return areAllVars
  # if checkAreAllVars(tokens):
  #   log "All tokens are var() functions"
  #   return ValidatorResult(valid: true, errors: @[])


  var isVar = false
  if tokens.len == 1 and tokens[0].kind == vtkSequence:
    for child in tokens[0].children:
      if isVarToken(child):
        isVar = true
        break
  else:
    for child in tokens:
      if isVarToken(child):
        isVar = true
        break
  if isVar:
    log "A token is a var() function"
    return ValidatorResult(true)



  # Handle top-level sequence token if present
  var effectiveTokens = if tokens.len == 1 and tokens[0].kind == vtkSequence:
                         tokens[0].children
                        else:
                         tokens
  
  # Validate tokens against syntax AST
  var visitedProperties = initHashSet[string]()
  let result = validateNode(ast, effectiveTokens, 0, visitedProperties)
  
  # Build final result
  if result.success:
    # If validation succeeded but there are remaining tokens, check if they're just !important
    if result.index < effectiveTokens.len:
      if hasOnlyImportant(effectiveTokens, result.index):
        # Valid: the only remaining token is !important at the end
        return ValidatorResult(true)
      else:
        # Invalid: there are extra tokens that aren't just a trailing !important
        var errors = result.errors
        errors.add("Extra tokens at index " & $result.index)
        return ValidatorResult(false, errors)
    else:
      # All tokens consumed successfully
      return ValidatorResult(true)
  else:
    # Validation failed
    return ValidatorResult(false, result.errors)

proc validate*(syntaxStr, valueStr: string): ValidatorResult {.gcsafe.} =
  ## Validates a CSS value against a syntax definition
  
  # Parse the value string into tokens
  let tokens = tokenizeValue(valueStr)
  
  # Call the main validation function
  return validate(syntaxStr, tokens)



# Example usage when run as main program
when isMainModule:
  enableDebug()

  let syntaxStr = "@keyframes <keyframes-name> {\n  <keyframe-block-list>\n}"
  let valueStr = "@keyframes 'sts' { from { left: 2px } }"
  # let syntaxStr = "@keyframes <keyframes-name> {\n  <keyframe-block-list>\n}"
  # let valueStr = "@keyframes 'test' { from { left: 5px } to { right: 2px } }"
  # let syntaxStr = "@import [ <string> | <url> ]\n        [ layer | layer(<layer-name>) ]?\n        [ supports( [ <supports-condition> | <declaration> ] ) ]?\n        <media-query-list>? ;"
  # let valueStr = "@import "


  
  # let syntaxStr = "<declaration-value>"
  # let valueStr  = "dasdsa dasds"


  let result = validate(syntaxStr, valueStr)
  if result.valid:
    echo "Valid: ", ($result.valid).green
  else:
    echo "Invalid: ", ($result.valid).red
    for err in result.errors:
      echo " - " & $err