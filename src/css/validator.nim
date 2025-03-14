import strutils, sequtils, tables, algorithm, options

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
  logMsg(node.treeRepr)

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
  logMsg("Validating built-in data type '" & dtName & "' with token '" & token.value & "'")
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

proc validateNode(node: Node, tokens: seq[ValueToken], index: int): MatchResult

proc validateDataType(node: Node, tokens: seq[ValueToken], index: int): MatchResult =
  logMsg("Validating data type node '" & node.value & "' at index " & $index)
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
              errors: @["Data type '" & node.value & "' failed: " & res.errors.join(", ")])
    else:
      let res = validateNode(dtAST, tokens, index)
      if res.success:
        return res
      else:
        return MatchResult(success: false, index: index,
              errors: @["Data type '" & node.value & "' failed: " & res.errors.join(", ")])
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

proc validateNode(node: Node, tokens: seq[ValueToken], index: int): MatchResult =
  logMsg("Validating node: " & $node.kind & " '" & node.value & "' at index " & $index)
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
    var argTokens = tok.children
    dumpTokens("Function argument tokens for " & node.value, argTokens)
    var effectiveArgTokens = argTokens
    if effectiveArgTokens.len == 1 and effectiveArgTokens[0].kind == vtkSequence:
      logMsg("Flattening single sequence token for function arguments")
      effectiveArgTokens = effectiveArgTokens[0].children
      dumpTokens("Effective function argument tokens", effectiveArgTokens)
    if modifiedFunctions.hasKey(node.value & "()"):
      logMsg("Using custom syntax for function '" & node.value & "()'")
      let funcAST = parseSyntax(modifiedFunctions[node.value & "()"].syntax)
      dumpNode("Custom function syntax AST", funcAST)
      var argsAST: Node
      if funcAST.kind == nkFunction:
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
    return MatchResult(success: true, index: index+1, errors: @[])
  of nkSequence:
    var cur = index
    for child in node.children:
      let res = validateNode(child, tokens, cur)
      if not res.success:
        return MatchResult(success: false, index: cur,
          errors: @["Sequence error: " & res.errors.join(", ")])
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
    while true:
      let res = validateNode(node.children[0], tokens, cur)
      if res.success and res.index > cur:
        cur = res.index
      else:
        break
    return MatchResult(success: true, index: cur, errors: @[])
  of nkOneOrMore:
    let first = validateNode(node.children[0], tokens, index)
    if not first.success:
      return MatchResult(success: false, index: index,
        errors: @["Expected at least one repetition: " & first.errors.join(", ")])
    var cur = first.index
    while true:
      let res = validateNode(node.children[0], tokens, cur)
      if res.success and res.index > cur:
        cur = res.index
      else:
        break
    return MatchResult(success: true, index: cur, errors: @[])
  of nkCommaList:
    var cur = index
    var first = true
    while true:
      let res = validateNode(node.children[0], tokens, cur)
      if not res.success:
        if first:
          return MatchResult(success: false, index: cur,
            errors: @["Expected list item at token index " & $cur])
        else:
          break
      cur = res.index
      first = false
      if cur < tokens.len and tokens[cur].kind == vtkComma:
        inc(cur)
      else:
        break
    return MatchResult(success: true, index: cur, errors: @[])
  of nkSpaceList:
    if index >= tokens.len or tokens[index].kind != vtkSequence:
      return MatchResult(success: false, index: index,
        errors: @["Expected space-separated list as a sequence token"])
    let seqTok = tokens[index]
    for childTok in seqTok.children:
      let res = validateNode(node.children[0], @[childTok], 0)
      if not res.success:
        return MatchResult(success: false, index: index,
          errors: @["Space list item invalid: " & res.errors.join(", ")])
    return MatchResult(success: true, index: index+1, errors: @[])
  of nkRequired:
    let res = validateNode(node.children[0], tokens, index)
    if not res.success:
      return MatchResult(success: false, index: index,
        errors: @["Required node missing: " & res.errors.join(", ")])
    return res
  of nkQuantified:
    var cur = index; var count = 0
    while true:
      let res = validateNode(node.children[0], tokens, cur)
      if res.success and res.index > cur:
        cur = res.index
        inc(count)
        if node.max.isSome and count >= node.max.get: break
      else:
        break
    if count < node.min:
      return MatchResult(success: false, index: index,
        errors: @["Expected at least " & $node.min & " occurrences, got " & $count])
    return MatchResult(success: true, index: cur, errors: @[])
  of nkValueRange:
    if index >= tokens.len:
      return MatchResult(success: false, index: index,
        errors: @["Expected a value in range, reached end"])
    let tok = tokens[index]
    if not tok.hasNumValue:
      return MatchResult(success: false, index: index,
        errors: @["Expected numeric token for range, got '" & tok.value & "'"])
    let valNum = tok.numValue
    let minVal = parseFloat(node.minValue)
    let maxVal = parseFloat(node.maxValue)
    if valNum < minVal or valNum > maxVal:
      return MatchResult(success: false, index: index,
        errors: @["Value " & $valNum & " not in range [" & node.minValue & ", " & node.maxValue & "]"])
    return MatchResult(success: true, index: index+1, errors: @[])
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

proc validateCSSValue*(syntaxStr, valueStr: string): ValidatorResult =
  logMsg("Starting CSS validation")
  logMsg("Parsing syntax: " & syntaxStr)
  let ast = parseSyntax(syntaxStr)
  dumpNode("Parsed syntax AST", ast)
  logMsg("Parsing value: " & valueStr)

  echo "!!!!!!!!!!!!!!!!!!!!!!!"
  var tokens = tokenizeValue(valueStr)
  echo tokens.treeRepr
  dumpTokens("Value tokens", tokens)
  if tokens.len == 1 and tokens[0].kind == vtkSequence:
    logMsg("Unwrapping top-level sequence token")
    tokens = tokens[0].children
    dumpTokens("Effective value tokens", tokens)
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

when isMainModule:
  # Test case for [ <counter-name> <integer>? ]+ | none
  let syntaxStr = "none | <filter-function-list>"
  let valueStr = "url(\"hello world\")"
  let result = validateCSSValue(syntaxStr, valueStr)
  echo "Valid: ", result.valid
  for err in result.errors:
    echo err
