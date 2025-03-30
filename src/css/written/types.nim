type
  WrittenPropertyKind* = enum
    pkPURE
    pkMIXED
  
  WrittenPropertyBody* = object
    case kind*: WrittenPropertyKind
    of pkPURE:
      value*: string
    of pkMIXED:
      node*: NimNode

  WrittenProperty* = object
    name*: string
    body*: WrittenPropertyBody

  WrittenRule* = object
    selector*: string
    properties*: seq[WrittenProperty]
    body*: NimNode


type
  WrittenDocumentNodeKind* = enum
    cssikPROPERTY,  # a property at root level
    cssikRULE,      # a rule
    cssikINLINE     # single line- non-property

  WrittenDocumentNode* = object
    case kind*: WrittenDocumentNodeKind
    of cssikPROPERTY:
      property*: WrittenProperty
    of cssikRULE:
      rule*: WrittenRule
    of cssikINLINE:
      content*: string
  
  WrittenDocument* = seq[WrittenDocumentNode]