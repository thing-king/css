import types


proc `$`*(docNode: WrittenDocumentNode): string =
  case docNode.kind:
  of cssikPROPERTY:
    result = docNode.property.name & ": " & docNode.property.body.value & ";\n"
  of cssikRULE:
    result = "\n" & docNode.rule.selector & " {\n"
    for prop in docNode.rule.properties:
      result.add "  " & $prop
    result.add "}\n"
  of cssikINLINE:
    result = docNode.content & ";\n"

proc `$`*(doc: WrittenDocument): string =
  var result = ""
  for node in doc:
    result.add $node
  return result