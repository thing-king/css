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
    vtkSequence     

  ValueToken* = object
    kind*: ValueTokenKind
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


proc tokenizeValue*(input: string, wrapRoot: bool = true): seq[ValueToken] =
  var tokens: seq[ValueToken] = @[]
  var i = 0

  proc skipWhitespace() =
    while i < input.len and input[i] in {' ', '\t', '\n', '\r'}:
      inc i

  proc parseString(): ValueToken =
    let quoteChar = input[i]  # either " or '
    inc i  # skip opening quote
    var strVal = ""
    while i < input.len and input[i] != quoteChar:
      strVal.add(input[i])
      inc i
    if i < input.len and input[i] == quoteChar:
      inc i  # skip closing quote
    return ValueToken(kind: vtkString, value: strVal)

  proc parseNumber(): ValueToken =
    var numStr = ""
    while i < input.len and input[i] in {'0'..'9'}:
      numStr.add(input[i])
      inc i
    if i < input.len and input[i] == '.':
      numStr.add(input[i])
      inc i
      while i < input.len and input[i] in {'0'..'9'}:
        numStr.add(input[i])
        inc i
    var unit = ""
    if i < input.len and (input[i] in {'a'..'z', 'A'..'Z', '%'}):
      while i < input.len and (input[i] in {'a'..'z', 'A'..'Z', '-', '%'}):
        unit.add(input[i])
        inc i
    if unit == "%":
      return ValueToken(kind: vtkPercentage, value: numStr & unit,
                        hasNumValue: true, numValue: parseFloat(numStr))
    elif unit.len > 0:
      return ValueToken(kind: vtkDimension, value: numStr & unit,
                        hasNumValue: true, numValue: parseFloat(numStr), unit: unit)
    else:
      return ValueToken(kind: vtkNumber, value: numStr,
                        hasNumValue: true, numValue: parseFloat(numStr))


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


  proc parseIdent(): ValueToken =
    var identStr = ""
    while i < input.len and (input[i].isAlphaAscii or input[i].isDigit or input[i] in {'-', '_'}):
      identStr.add(input[i])
      inc i
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
    skipWhitespace()
    if i >= input.len: break
    case input[i]
    of '"', '\'':
      tokens.add(parseString())
    of '0'..'9', '.':
      tokens.add(parseNumber())
    of 'a'..'z', 'A'..'Z', '-', '_':
      tokens.add(parseIdent())
    of '#':
      var color = "#"
      inc i
      while i < input.len and input[i] in {'0'..'9', 'a'..'f', 'A'..'F'}:
        color.add(input[i])
        inc i
      tokens.add(ValueToken(kind: vtkColor, value: color))
    of ',':
      tokens.add(ValueToken(kind: vtkComma, value: ","))
      inc i
    of '/':
      tokens.add(ValueToken(kind: vtkSlash, value: "/"))
      inc i
    of '(':
      tokens.add(ValueToken(kind: vtkLParen, value: "("))
      inc i
    of ')':
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



proc parseValue*(input: string): seq[ValueToken] =
  return tokenizeValue(input)

proc `$`*(vt: ValueToken): string =
  case vt.kind
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
proc `$`*(vts: seq[ValueToken]): string =
  return vts.map(`$`).join(", ")

proc treeRepr*(vt: ValueToken, indent: string = ""): string =
  let newIndent = indent & "    "
  case vt.kind
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

proc treeRepr*(vts: seq[ValueToken]): string =
  var lines = newSeq[string]()
  for vt in vts:
    lines.add(treeRepr(vt))
  return lines.join(",\n")

when isMainModule:
  let valueStr = "url(\"hello world\") 2"
  let tokens = tokenizeValue(valueStr)
  echo "Value tokens for: ", valueStr
  echo $tokens
  echo "\nTree representation:"
  echo treeRepr(tokens)
  echo tokens[0].children.len
  echo tokens[0].children[1].value
