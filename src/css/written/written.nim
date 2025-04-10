import macros
import strutils


import types
export types

import selector
import ../util
import ../types
import ../core


import pkg/lifter
import pkg/jsony_plus/serialized_node



proc parseWrittenPropertyBody(syntax: string, body: NimNode): WrittenPropertyBody =
  var valueStr = body.repr.strip().replaceUnits().replace(" - ", "-").replace("var (", "var(").replace("val (", "var(").replace("val(", "var(").replace("cvar (", "var(").replace("cvar(", "var(").replace("{", "").replace("}", "")

  if valueStr.contains("`"):
    
    var nodes: seq[NimNode] = @[]
    
    var str = ""
    var inside = false
    for ch in valueStr:
      if ch == '\n':
        continue
      if ch == '`':
        inside = not inside
        if inside:
          if str.len > 0:
            nodes.add newStrLitNode(str)
            str = ""
        else:
          if str.len > 0:
            nodes.add ident(str)
            str = ""
        continue
      
      str.add ch
    if str.len > 0:
      nodes.add newStrLitNode(str)


    if nodes.len == 0:
      raise newException(ValueError, "Invalid CSS value! Not enough nodes.")
    
    var node = nodes[0]
    if nodes.len >= 2:
      node = nnkInfix.newTree(
        ident("&"),
        node,
        nodes[1],
      )

    if nodes.len > 2:
      for i in 2 ..< nodes.len:
        node = nnkInfix.newTree(
          ident("&"),
          node,
          nodes[i],
        )

    
    return WrittenPropertyBody(kind: pkMIXED, node: node.toSerializedNode())
  else:
    # valueStr = valueStr.strip()
    # echo valueStr
    # echo body.treeRepr

    if valueStr.len >= 3 and valueStr[0] == '"' and valueStr[^1] == '"':
      valueStr = valueStr[1 .. ^2]

    if valueStr.startsWith("--") and not valueStr.contains(" "):
      valueStr = "var(" & valueStr & ")"
    
    # echo "VALUE STR"
    # echo valueStr

    # echo "Attempting \"" & valueStr & "\""
    # echo valueStr
    # echo valueStr
    var validateResponse = ValidatorResult(valid: true, errors: @[])
    if syntax != "<declaration-value>":
      validateResponse = validateSyntaxValue(syntax, valueStr)
    let valid  = validateResponse.valid
    let errors = validateResponse.errors
    if not valid:
      let errorStr = errors.join("\n")
      error "Invalid CSS value!\n" & errorStr, body
    
    if valueStr.startsWith("\n"):
      valueStr = valueStr[1..^1]

    return WrittenPropertyBody(kind: pkPURE, value: valueStr)
proc parseWrittenProperty(node: NimNode): WrittenProperty =
  # echo node.treeRepr
  # echo node.treeRepr
  expectKind(node, {nnkCall, nnkInfix, nnkPrefix})
  
  var cssPropertyName: string
  var isVariable = false
  var propertyNodeBody: NimNode
  if node.kind == nnkCall:
    expectLen(node, 2)
    expectKind(node[0], {nnkStrLit, nnkIdent})
    expectKind(node[1], nnkStmtList)
    if node[0].kind == nnkStrLit:
      cssPropertyName = node[0].strVal
    elif node[0].kind == nnkIdent:
      let nimPropertyName = node[0].strVal
      cssPropertyName = toKebabCase(nimPropertyName)
    else:
      error "Expected a string literal or an identifier"
    propertyNodeBody = node[1]
  elif node.kind == nnkInfix:
    expectMinLen(node, 3)
    expectKind(node[^1], nnkStmtList)
    propertyNodeBody = node[^1]
    cssPropertyName = node[1].repr.replace(" - ", "-") & "-" & node[2].repr.replace(" - ", "-")
    isVariable = true
    # echo "PROP NAME: " & cssPropertyName
  elif node.kind == nnkPrefix:
    expectLen(node, 3)
    expectKind(node[^1], nnkStmtList)
    expectKind(node[0], nnkIdent)
    if node[0].strVal != "--":
      error "Expected a variable declaration starting with --"
    propertyNodeBody = node[^1]
    cssPropertyName = "--" & node[1].repr.replace(" - ", "-")
    isVariable = true
  else:
    error "Expected a call or infix node"


  if cssPropertyName.startsWith("WebKit"):
    cssPropertyName = "-webkit-" & cssPropertyName[6..^1]
  elif cssPropertyName.startsWith("Moz"):
    cssPropertyName = "-moz-" & cssPropertyName[3..^1]
  elif cssPropertyName.startsWith("Ms"):
    cssPropertyName = "-ms-" & cssPropertyName[2..^1]
  elif cssPropertyName.startsWith("webkit"):
    cssPropertyName = "-webkit-" & cssPropertyName[7..^1]
  elif cssPropertyName.startsWith("moz"):
    cssPropertyName = "-moz-" & cssPropertyName[3..^1]
  elif cssPropertyName.startsWith("ms"):
    cssPropertyName = "-ms-" & cssPropertyName[2..^1]
  elif cssPropertyName.startsWith("o-"):
    cssPropertyName = "-o-" & cssPropertyName[2..^1]

  var syntax: string = "<declaration-value>"
  if not isVariable:
    if not validatePropertyName(cssPropertyName).valid:
      error "Unknown CSS property name: " & cssPropertyName, node[0]
    syntax = getProperty(cssPropertyName).syntax




  # let bodyStr = parsePropertyBody(cssProp.get, propertyBody)
  let propertyBody = parseWrittenPropertyBody(syntax, propertyNodeBody)
  result = WrittenProperty(name: cssPropertyName, body: propertyBody)


proc parseWrittenRuleBody(body: NimNode): seq[WrittenProperty] =
  for node in body:
    result.add parseWrittenProperty(node)
proc parseWrittenRule(selectorStr: string, selectorNode: NimNode, body: NimNode): WrittenRule =
  # let selectorValidation = isValidCSSSelector(selectorStr)
  # if not selectorValidation.valid:
    # let errorStr = selectorValidation.errors.join("\n")
    # error "Invalid CSS selector!\n" & errorStr, selectorNode
  
  let properties = parseWrittenRuleBody(body)
  result = WrittenRule(selector: selectorStr, properties: properties, body: body.toSerializedNode())


proc parseWrittenDocument*(body: NimNode): WrittenDocument =
  proc extractRuleSelectorAndBody(node: NimNode): tuple[selector: string, body: NimNode] =
    ## Extracts the CSS selector string and statement list from a CSS-like Nim AST
    
    var body = newStmtList()
    
    var newNode = node.kind.newNimNode()
    
    for child in node:
      if child.kind == nnkStmtList:
        body = child
      else:
        newNode.add child
      
    var selector = newNode.repr.replace(" - ", "-")
    # if selector.endsWith("\"()"):
    #   selector = selector[1 .. ^4]
    if selector.startsWith("\"") and selector.endsWith("\""):
      selector = selector[1..^2]
    if selector.endsWith("()"):
      selector = selector[0 .. ^3]
    # echo "SELECTOR: " & selector
    if selector.startsWith("{") and selector.endsWith("}"):
      selector = selector[1..^2]

    let actualSelector = processWrittenSelector(selector)

    return (actualSelector, body)

  # echo body.treeRepr
  for node in body:
    var isProperty = node.kind == nnkCall and node[0].kind in {nnkIdent, nnkStrLit} and node[1].kind == nnkStmtList and node[1].len == 1
    if isProperty and node[1].kind == nnkStmtList and node[1].len == 1 and node[1][0].kind == nnkCall:
      isProperty = false # is something like `body: { backgroundColor: "" }`
    
    # (node[1][0].kind != nnkCall and node[1][0].len != 2)
    var isInline = node.kind == nnkImportStmt


    echo node.treeRepr
    echo isProperty

    # echo "CSS HERE:"
    # echo node.treeRepr
    # echo isProperty

    if isInline:
      var content = node.repr
      if content.startsWith("import"):
        content = content.replace("import\n ", "@import")
      if content.endsWith("\n"):
        content = content[0..^2]
      content = content.strip()
      if content.endsWith(";"):
        content = content[0..^2]

      result.add WrittenDocumentNode(kind: cssikINLINE, content: content)
    else:
      if isProperty:
        result.add WrittenDocumentNode(kind: cssikPROPERTY, property: parseWrittenProperty(node))
      else:

        let (selectorStr, body) = extractRuleSelectorAndBody(node)
        # echo "SELECTOR STR: " & selectorStr
        result.add WrittenDocumentNode(kind: cssikRULE, rule: parseWrittenRule(selectorStr, node, body))


genLift(WrittenDocument)
macro css*(body: untyped): untyped =
  let document = parseWrittenDocument(body)
  # echo document
  result = lift(document)