# std
import strutils, sequtils, tables, algorithm, options, sets

# pkgs
import pkg/colors

# this
import imports   # gives access to `syntaxes` and `functions`
import syntax_parser # provides: let ast: Node = parseSyntax("…")
import value_parser  # provides: let tokens: seq[ValueToken] = tokenizeValue("…")


const modifiedFunctions = block:
  var temp = functions
  temp["url()"] = FunctionsValue(syntax: "url( <string> )")
  temp

const modifiedSyntaxes = block:
  var temp = syntaxes
  temp["url"] = SyntaxesValue(syntax: "url( <string> )")
  temp["length-percentage"] = SyntaxesValue(syntax: "<length> | <percentage>")
  temp


const DEBUG = true

proc logMsg(msg: string) =
  if DEBUG:
    echo "[LOG] " & msg

# Dump tree representations for tokens and nodes.
proc dumpTokens(label: string, tokens: seq[ValueToken]) =
  logMsg(label & " tokens tree:")
  logMsg(tokens.treeRepr)

proc dumpNode(label: string, node: Node) =
  logMsg(label & " tree:")
  logMsg("\n" & node.treeRepr)

type
  ValidatorResult* = object
    valid*: bool
    errors*: seq[string]

  MatchResult = object
    success: bool
    index: int
    errors: seq[string]

# Built-in data type validator (extended)
proc validateBuiltinDataType(dtName: string, token: ValueToken): bool =
  # Safety check for empty strings
  if dtName.len == 0 or token.value.len == 0:
    logMsg("WARNING: Empty data type name or token value")
    return false
    
  logMsg("Validating built-in data type '" & dtName & "' with token '" & token.value & "' of kind " & $token.kind)
  case dtName
  of "number":       token.kind == vtkNumber
  of "percentage":   token.kind == vtkPercentage
  of "color":        token.kind == vtkColor or token.kind == vtkIdent
  of "angle":        token.kind == vtkDimension and token.unit in @["deg", "rad", "grad", "turn"]
  of "custom-ident": token.kind == vtkIdent
  of "dashed-ident": token.kind == vtkIdent and token.value.startsWith("--") and not token.value.endsWith("-")
  of "integer":      token.kind == vtkNumber and not token.value.contains(".")
  of "string":       token.kind == vtkString
  of "dimension":    token.kind == vtkDimension
  of "frequency":    token.kind == vtkDimension and token.unit in @["Hz", "kHz", "KhZ"]
  of "length":       token.kind == vtkDimension and token.unit in @["cap", "ch", "em", "ex", "ic", "lh", "rcap", "rch", "rem", "rex", "ric", "rlh", "sv", "lv", "dv", "vh", "vw", "vmax", "vmin", "vb", "vi", "cqw", "cqh", "cqi", "cqb", "cqmin", "cqmax", "px", "cm", "mm", "Q", "in", "pc", "pt"]
  of "overflow":     token.kind == vtkIdent and token.value in @["visible", "hidden", "scroll", "auto", "clip"]
  of "resolution":   token.kind == vtkDimension and token.unit in @["dpi", "dpcm", "dppx", "x"]
  of "time":         token.kind == vtkDimension and token.unit in @["s", "ms"]
  else:
    logMsg("No built-in validator for data type '" & dtName & "'")
    false

proc validateNode(node: Node, tokens: seq[ValueToken], index: int): MatchResult {.gcsafe.}



# Add this global set to track property validation to prevent infinite loops
var visitedProperties {.threadvar.}: HashSet[string]

# Overhaul the validator functions to prevent infinite loops
proc validatePropertyDataType(propertyName: string, tokens: seq[ValueToken], index: int): MatchResult {.gcsafe.} =
  # Detect circular references
  if propertyName in visitedProperties:
    logMsg("WARNING: Circular reference detected for property '" & propertyName & "'")
    # Return success to break the recursion - this is a simplification
    # Ideally we'd have a more sophisticated approach to handle circular references
    return MatchResult(success: true, index: index+1, errors: @[])
  
  # Add this property to visited set
  visitedProperties.incl(propertyName)
  
  logMsg("Validating property data type '" & propertyName & "' at index " & $index)
  
  # Get validation result
  var result: MatchResult
  
  if properties.hasKey(propertyName):
    logMsg("Found property data type definition for '" & propertyName & "'")
    let propertyDataType = properties[propertyName]
    let dtAST = parseSyntax(propertyDataType.syntax)
    dumpNode("Property data type AST for " & propertyName, dtAST)

    if index < tokens.len:
      result = validateNode(dtAST, tokens, index)
      logMsg("Property data type validation result: " & $result.success)
    else:
      result = MatchResult(success: false, index: index,
        errors: @["Expected property '" & propertyName & "', reached end"])
  else:
    logMsg("No property data type found for '" & propertyName & "'")
    result = MatchResult(success: false, index: index,
      errors: @["Unknown property data type '" & propertyName & "'"])
  
  # Remove this property from visited set
  visitedProperties.excl(propertyName)
  
  return result

proc validateDataType(node: Node, tokens: seq[ValueToken], index: int): MatchResult {.gcsafe.} =
  logMsg("Validating data type node '" & node.value & "' at index " & $index)
  
  # First check if this is a property data type (enclosed in single quotes)
  let isPropertyDataType = node.value.startsWith("'") and node.value.endsWith("'")
  if isPropertyDataType:
    var propertyDataTypeValue = node.value[1..^2]
    logMsg("Detected property data type '" & propertyDataTypeValue & "'")
    # Call the specialized property data type validator with circular reference detection
    return validatePropertyDataType(propertyDataTypeValue, tokens, index)
  
  # Handle quantified data types (e.g. <length-percentage>{1,2})
  if node.isQuantified:
    logMsg("Processing quantified data type: " & node.value & " {" & $node.min & 
           "," & (if node.max.isSome: $node.max.get else: "unlimited") & "}")
    
    var cur = index
    var count = 0
    
    # Try to match the pattern as many times as possible (up to max if specified)
    while cur < tokens.len:
      # Check if we've reached the maximum allowed occurrences
      if node.max.isSome and count >= node.max.get:
        logMsg("Reached maximum allowed occurrences: " & $node.max.get)
        break
      
      var dataTypeMatched = false
      
      # Handle property data types in quantified context
      let childIsPropertyDataType = node.value.startsWith("'") and node.value.endsWith("'")
      if childIsPropertyDataType:
        var propertyDataTypeValue = node.value[1..^2]
        # Use the specialized property data type validator with circular reference detection
        let res = validatePropertyDataType(propertyDataTypeValue, tokens, cur)
        if res.success and res.index > cur:
          cur = res.index
          dataTypeMatched = true
          inc(count)
          logMsg("Matched occurrence " & $count & " of property data type '" & propertyDataTypeValue & "' at index " & $(cur-1))
      else:
        # Perform standard data type validation without quantification
        if modifiedSyntaxes.hasKey(node.value):
          logMsg("Found custom syntax for data type '" & node.value & "'")
          let dtAST = parseSyntax(modifiedSyntaxes[node.value].syntax)
          dumpNode("Custom syntax AST for " & node.value, dtAST)
          
          # Try each token against the data type definition
          if cur < tokens.len:
            let res = validateNode(dtAST, tokens, cur)
            if res.success and res.index > cur:
              cur = res.index
              dataTypeMatched = true
              inc(count)
              logMsg("Matched occurrence " & $count & " of data type '" & node.value & "' at index " & $(cur-1))
        else:
          logMsg("No custom syntax for '" & node.value & "', using built-in validation")
          if cur < tokens.len:
            let token = tokens[cur]
            
            # Handle the case where we have a sequence token
            if token.kind == vtkSequence and token.children.len > 0:
              logMsg("Found sequence token at index " & $cur & ", checking first child for data type match")
              if token.children.len > 0 and token.children[0].kind != vtkComma and 
                 validateBuiltinDataType(node.value, token.children[0]):
                # Use the first child of the sequence
                inc(cur)
                dataTypeMatched = true
                inc(count)
                logMsg("First child of sequence matched occurrence " & $count & " of data type '" & node.value & "'")
              else:
                logMsg("First child of sequence did not match data type '" & node.value & "'")
            # Skip commas as they are separators, not values
            elif token.kind != vtkComma and validateBuiltinDataType(node.value, token):
              inc(cur)
              dataTypeMatched = true
              inc(count)
              logMsg("Matched occurrence " & $count & " of built-in data type '" & node.value & "' at index " & $(cur-1))
      
      # If we couldn't match the data type, stop trying
      if not dataTypeMatched:
        logMsg("Could not match data type '" & node.value & "' at index " & $cur)
        break
    
    # Check if we found enough occurrences
    if count < node.min:
      return MatchResult(success: false, index: index,
        errors: @["Expected at least " & $node.min & " occurrences of data type '" & 
                 node.value & "', got " & $count])
    
    # All constraints satisfied
    return MatchResult(success: true, index: cur, errors: @[])
  
  # Normal (non-quantified) data type handling
  if modifiedSyntaxes.hasKey(node.value):
    logMsg("Found custom syntax for data type '" & node.value & "'")
    let dtAST = parseSyntax(modifiedSyntaxes[node.value].syntax)
    dumpNode("Custom syntax AST for " & node.value, dtAST)
    if index < tokens.len and tokens[index].kind == vtkSequence:
      logMsg("Token at index " & $index & " is a sequence; using its children for custom validation")
      let innerTokens = tokens[index].children
      let res = validateNode(dtAST, innerTokens, 0)
      if res.success and res.index == innerTokens.len:
        return MatchResult(success: true, index: index+1, errors: @[])
      else:
        return MatchResult(success: false, index: index,
              errors: res.errors)
    else:
      let res = validateNode(dtAST, tokens, index)
      if res.success:
        return res
      else:
        return MatchResult(success: false, index: index,
              errors: res.errors)
  else:
    logMsg("No custom syntax for '" & node.value & "', using built-in validation")
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
              errors: @["Expected built-in data type '" & node.value & "' but no token found"])
    let token = tokens[index]
    if validateBuiltinDataType(node.value, token):
      return MatchResult(success: true, index: index+1, errors: @[])
    else:
      return MatchResult(success: false, index: index,
              errors: @["Built-in data type '" & node.value & "' rejected token '" & token.value & "'"])


proc isNodeOptional(node: Node): bool =
  ## Helper function to determine if a node is optional
  return node.kind == nkOptional or node.kind == nkZeroOrMore or 
         (node.kind == nkQuantified and node.min == 0)

proc validateNode(node: Node, tokens: seq[ValueToken], index: int): MatchResult {.gcsafe.} =
  logMsg("Validating node: " & $node.kind & " '" & node.value & "' at index " & $index)
  if index >= tokens.len and not isNodeOptional(node):
    return MatchResult(success: false, index: index, 
      errors: @["Expected " & $node.kind & " but reached end of tokens"])
      
  case node.kind
  of nkKeyword:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
        errors: @["Expected keyword '" & node.value & "', reached end"])
    if tokens[index].kind != vtkIdent or tokens[index].value != node.value:
      return MatchResult(success: false, index: index,
        errors: @["Expected keyword '" & node.value & "', got '" & tokens[index].value & "'"])
    return MatchResult(success: true, index: index+1, errors: @[])
    
  of nkDataType:
    return validateDataType(node, tokens, index)
    
  of nkFunction:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
        errors: @["Expected function '" & node.value & "', reached end"])
    
    let tok = tokens[index]
    if tok.kind != vtkFunc or tok.value != node.value:
      return MatchResult(success: false, index: index,
        errors: @["Expected function '" & node.value & "', got '" & tok.value & "'"])
    logMsg("Function '" & node.value & "' matched at index " & $index)
    dumpTokens("Function token for " & node.value, @[tok])
    
    # Safely handle function arguments
    if tok.children.len == 0:
      logMsg("Function has no arguments")
      return MatchResult(success: true, index: index+1, errors: @[])
      
    var argTokens = tok.children
    dumpTokens("Function argument tokens for " & node.value, argTokens)
    
    var rawEffectiveArgTokens = argTokens
    var effectiveArgTokens: seq[ValueToken] = @[]
    if rawEffectiveArgTokens.len == 1 and rawEffectiveArgTokens[0].kind == vtkSequence:
      logMsg("Flattening single sequence token for function arguments")
      effectiveArgTokens = rawEffectiveArgTokens[0].children
      dumpTokens("Effective function argument tokens", effectiveArgTokens)
    else:
      effectiveArgTokens = rawEffectiveArgTokens

    if modifiedFunctions.hasKey(node.value & "()"):
      logMsg("Using custom syntax for function '" & node.value & "()'")
      let funcAST = parseSyntax(modifiedFunctions[node.value & "()"].syntax)
      dumpNode("Custom function syntax AST", funcAST)
      
      var argsAST: Node
      if funcAST.kind == nkFunction and funcAST.children.len > 0:
        if funcAST.children.len == 1:
          argsAST = funcAST.children[0]
        else:
          argsAST = Node(kind: nkSequence, value: "", children: funcAST.children)
        
        logMsg("Using custom function arguments AST:")
        dumpNode("Custom function arguments AST", argsAST)
        
        let res = validateNode(argsAST, effectiveArgTokens, 0)
        logMsg("Custom function validation result: consumed " & $res.index & " of " & $effectiveArgTokens.len)
        
        if not res.success or res.index != effectiveArgTokens.len:
          var errMsg = "Expected " & $effectiveArgTokens.len & " tokens, but consumed " & $res.index
          if res.errors.len > 0:
            errMsg &= ": " & res.errors.join(", ")
          return MatchResult(success: false, index: index,
            errors: @["Function '" & node.value & "()' arguments invalid: " & errMsg])
      elif node.children.len > 0:
        logMsg("Validating function '" & node.value & "' using provided AST children")
        dumpNode("Provided function argument AST", node.children[0])
        
        let res = validateNode(node.children[0], effectiveArgTokens, 0)
        logMsg("Provided AST function validation result: consumed " & $res.index & " of " & $effectiveArgTokens.len)
        
        if not res.success or res.index != effectiveArgTokens.len:
          var errMsg = "Expected " & $effectiveArgTokens.len & " tokens, but consumed " & $res.index
          if res.errors.len > 0:
            errMsg &= ": " & res.errors.join(", ")
          return MatchResult(success: false, index: index,
            errors: @["Function '" & node.value & "' arguments invalid: " & errMsg])
    elif node.children.len > 0:
      logMsg("Validating function '" & node.value & "' using provided AST children")
      dumpNode("Provided function argument AST", node.children[0])
      
      let res = validateNode(node.children[0], effectiveArgTokens, 0)
      logMsg("Provided AST function validation result: consumed " & $res.index & " of " & $effectiveArgTokens.len)
      
      if not res.success or res.index != effectiveArgTokens.len:
        var errMsg = "Expected " & $effectiveArgTokens.len & " tokens, but consumed " & $res.index
        if res.errors.len > 0:
          errMsg &= ": " & res.errors.join(", ")
        return MatchResult(success: false, index: index,
          errors: @["Function '" & node.value & "' arguments invalid: " & errMsg])
    else:
      logMsg("Warning: No custom syntax or provided AST for function '" & node.value & "'")
      return MatchResult(success: false, index: index,
        errors: @["No custom syntax or provided AST for function '" & node.value & "'"])

    return MatchResult(success: true, index: index+1, errors: @[])
    
  of nkSequence:
    var cur = index
    for child in node.children:
      let res = validateNode(child, tokens, cur)
      if not res.success:
        return MatchResult(success: false, index: cur,
          # errors: @["Sequence error: " & res.errors.join(", ")])
          errors: res.errors)

      cur = res.index
    return MatchResult(success: true, index: cur, errors: @[])
    
  of nkChoice:
    var errs: seq[string] = @[]
    for child in node.children:
      let res = validateNode(child, tokens, index)
      if res.success:
        return res
      errs.add("[" & res.errors.join(", ") & "]")
    return MatchResult(success: false, index: index, errors: errs)
    
  of nkOrList:
    var cur = index
    while cur < tokens.len:
      var matched = false
      for child in node.children:
        let res = validateNode(child, tokens, cur)
        if res.success:
          cur = res.index
          matched = true
          break
      if not matched: break
    return MatchResult(success: true, index: cur, errors: @[])
    
  of nkAndList:
    logMsg("Validating AndList node with " & $node.children.len & " children at index " & $index)
    
    # Track which children have been matched
    var matched = newSeq[bool](node.children.len)
    var cur = index
    var progress = true
    var matchedCount = 0
    
    # Continue trying to match children until no more progress can be made
    while progress and cur < tokens.len:
      progress = false
      
      # Try each unmatched child at the current position
      for i in 0..<node.children.len:
        if matched[i]: continue
        
        let child = node.children[i]
        let res = validateNode(child, tokens, cur)
        
        # If this child matches at the current position
        if res.success and res.index > cur:
          logMsg("AndList: matched child " & $i & " at index " & $cur)
          matched[i] = true
          inc(matchedCount)
          cur = res.index
          progress = true
          break
      
      # If we've matched all children, we're done
      if matchedCount == node.children.len:
        break
    
    # Check if all required children have been matched
    var errors: seq[string] = @[]
    var missingRequired = false
    
    for i in 0..<node.children.len:
      if not matched[i] and not isNodeOptional(node.children[i]):
        missingRequired = true
        errors.add("Required component at index " & $i & " not matched")
    
    if missingRequired:
      return MatchResult(success: false, index: index, errors: errors)
    
    return MatchResult(success: true, index: cur, errors: @[])
    
  of nkOptional:
    if node.children.len == 0:
      return MatchResult(success: true, index: index, errors: @[])
    let res = validateNode(node.children[0], tokens, index)
    if res.success:
      return res
    else:
      return MatchResult(success: true, index: index, errors: @[])
      
  of nkZeroOrMore:
    var cur = index
    while cur < tokens.len:
      let res = validateNode(node.children[0], tokens, cur)
      if res.success and res.index > cur:
        cur = res.index
      else:
        break
    return MatchResult(success: true, index: cur, errors: @[])
    
  of nkOneOrMore:
    # Must have at least one child node
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
        errors: @["OneOrMore node has no child to match"])
    
    let first = validateNode(node.children[0], tokens, index)
    if not first.success:
      return MatchResult(success: false, index: index,
        errors: @["Expected at least one repetition: " & first.errors.join(", ")])
        
    var cur = first.index
    while cur < tokens.len:
      let res = validateNode(node.children[0], tokens, cur)
      if res.success and res.index > cur:
        cur = res.index
      else:
        break
    return MatchResult(success: true, index: cur, errors: @[])
    
  of nkCommaList:
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
        errors: @["CommaList node has no child to match"])
        
    # Handle two different token structures:
    # 1. Each comma-separated item is already a sequence token
    # 2. Commas are separate tokens in a flat list
    
    # Case 1: Items are already sequences with comma tokens in between
    if index < tokens.len and tokens[index].kind == vtkSequence:
      logMsg("Processing comma list where items are sequences")
      var cur = index
      var allValid = true
      var errors: seq[string] = @[]
      
      while cur < tokens.len:
        # Validate the current sequence token against the child pattern
        let seqToken = tokens[cur]
        let childRes = validateNode(node.children[0], @[seqToken], 0)
        
        if not childRes.success:
          allValid = false
          errors.add("Item " & $(cur - index) & " in comma list is invalid: " & childRes.errors.join(", "))
          break
        
        inc(cur)
        
        # Check if there are more items
        if cur < tokens.len:
          logMsg("Checking for more items in comma list at index " & $cur)
      
      if allValid:
        return MatchResult(success: true, index: cur, errors: @[])
      else:
        return MatchResult(success: false, index: index, errors: errors)
    
    # Case 2: Comma tokens are mixed with normal tokens
    else:
      logMsg("Processing comma list with separate comma tokens")
      var cur = index
      var first = true
      
      while cur < tokens.len:
        let res = validateNode(node.children[0], tokens, cur)
        if not res.success:
          if first:
            return MatchResult(success: false, index: cur,
              errors: @["Expected list item at token index " & $cur])
          else:
            break
        cur = res.index
        first = false
        
        # Look for comma separator if we're not at the end
        if cur < tokens.len and tokens[cur].kind == vtkComma:
          inc(cur)
        else:
          break
      return MatchResult(success: true, index: cur, errors: @[])
    
  of nkSpaceList:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
        errors: @["Expected space-separated list but reached end of tokens"])
        
    if tokens[index].kind != vtkSequence:
      return MatchResult(success: false, index: index,
        errors: @["Expected space-separated list as a sequence token, got " & $tokens[index].kind])
      
    let seqTok = tokens[index]
    for childTok in seqTok.children:
      let res = validateNode(node.children[0], @[childTok], 0)
      if not res.success:
        return MatchResult(success: false, index: index,
          errors: @["Space list item invalid: " & res.errors.join(", ")])
    return MatchResult(success: true, index: index+1, errors: @[])
    
  of nkRequired:
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
        errors: @["Required node has no child to match"])
        
    let res = validateNode(node.children[0], tokens, index)
    if not res.success:
      return MatchResult(success: false, index: index,
        errors: @["Required node missing: " & res.errors.join(", ")])
    return res
    
  of nkQuantified:
    logMsg("Validating quantified node: min=" & $node.min & 
           ", max=" & (if node.max.isSome: $node.max.get else: "unlimited"))
    
    # Check if we have a single child node that needs to be quantified
    if node.children.len == 0:
      return MatchResult(success: false, index: index,
        errors: @["Quantified node has no child to match"])
    
    # Track how many occurrences we've found
    var cur = index
    var count = 0
    
    # Try to match the pattern as many times as possible (up to max if specified)
    while cur < tokens.len:
      # Try to match the child node at current position
      let childRes = validateNode(node.children[0], tokens, cur)
      
      # If match was successful and consumed tokens
      if childRes.success and childRes.index > cur:
        # Move cursor forward
        cur = childRes.index
        # Increment the occurrence count
        inc(count)
        logMsg("Matched occurrence " & $count & " of quantified node at index " & $(cur-1))
        
        # Stop if we've reached maximum allowed occurrences
        if node.max.isSome and count >= node.max.get:
          logMsg("Reached maximum quantified occurrences: " & $node.max.get)
          break
      else:
        # No more matches possible
        logMsg("Failed to match next occurrence of quantified node at index " & $cur)
        break
    
    # Check if we found enough occurrences
    if count < node.min:
      return MatchResult(success: false, index: index,
        errors: @["Expected at least " & $node.min & " occurrences, got " & $count])
        
    # All constraints satisfied
    return MatchResult(success: true, index: cur, errors: @[])

  of nkValueRange:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
        errors: @["Expected a value in range, reached end"])
        
    let tok = tokens[index]
    if not tok.hasNumValue:
      return MatchResult(success: false, index: index,
        errors: @["Expected numeric token for range, got '" & tok.value & "'"])
        
    # Convert values to numeric for comparison
    try:
      let valNum = tok.numValue
      let minVal = parseFloat(node.minValue)
      let maxVal = parseFloat(node.maxValue)
      
      # Check if value is within the specified range
      if valNum < minVal or valNum > maxVal:
        return MatchResult(success: false, index: index,
          errors: @["Value " & $valNum & " not in range [" & node.minValue & ", " & node.maxValue & "]"])
          
      # Range check passed
      return MatchResult(success: true, index: index+1, errors: @[])
    except ValueError:
      return MatchResult(success: false, index: index,
        errors: @["Failed to parse numeric values for range comparison"])
        
  of nkSeparator:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
        errors: @["Expected separator '" & node.value & "', reached end"])
    if tokens[index].value != node.value:
      return MatchResult(success: false, index: index,
        errors: @["Expected separator '" & node.value & "', got '" & tokens[index].value & "'"])
    return MatchResult(success: true, index: index+1, errors: @[])
  else:
    return MatchResult(success: false, index: index,
      errors: @["Validation for node kind " & $node.kind & " not implemented"])

proc validate*(syntaxStr, valueStr: string): ValidatorResult {.gcsafe.} =
  visitedProperties = initHashSet[string]()
  
  logMsg("Starting CSS validation")
  logMsg("Parsing syntax: " & syntaxStr)
  let ast = parseSyntax(syntaxStr)
  dumpNode("Parsed syntax AST", ast)
  logMsg("Parsing value: " & valueStr)

  var rawTokens = tokenizeValue(valueStr)
  var tokens: seq[ValueToken] = @[]

  dumpTokens("Value tokens", rawTokens)
  if rawTokens.len == 1 and rawTokens[0].kind == vtkSequence:
    logMsg("Unwrapping top-level sequence token")
    tokens = rawTokens[0].children
    dumpTokens("Effective value tokens", tokens)
  else:
    tokens = rawTokens
  
  logMsg("Token count: " & $tokens.len)
  let res = validateNode(ast, tokens, 0)
  var errs = res.errors
  if res.success and res.index == tokens.len:
    logMsg("Validation successful")
    return ValidatorResult(valid: true, errors: @[])
  else:
    if res.index < tokens.len:
      errs.add("Extra tokens at index " & $res.index)
    return ValidatorResult(valid: false, errors: errs)

proc validateCSSValue*(syntaxStr, valueStr: string): ValidatorResult {.gcsafe.} =
  validate(syntaxStr, valueStr)


when isMainModule:
  # Test case for length-percentage
  let syntaxStr = "<'text-decoration-line'> || <'text-decoration-style'> || <'text-decoration-color'> || <'text-decoration-thickness'>"
  let valueStr = "underlines"
  

  let result = validateCSSValue(syntaxStr, valueStr)
  if result.valid:
    echo "Valid: ", ($result.valid).green
  else:
    echo "Invalid: ", ($result.valid).red
  for err in result.errors:
    echo " - " & err