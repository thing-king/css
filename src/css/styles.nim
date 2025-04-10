import macros
import strutils, tables

import util
import core
import types
import imports/imports

import ./written/written


macro makeStyle(stylesName: untyped): untyped =
  expectKind(stylesName, nnkIdent)
  
  result = nnkStmtList.newTree(
    quote do:
      type `stylesName` = object
        properties*: Table[string, string]
  )

  for propertyName, propertyValue in properties:
    if propertyName == "--*":
      continue
    
    var name = propertyName.kebabToCamelCase
    var nameEqualsIdent = nnkAccQuoted.newTree(ident(name & "="))
    var nameIdent = ident(name)

    # echo nameEqualsIdent
    result.add quote do:
      # proc `nameEqualsIdent`*(style: var `stylesName`, value: string) {.inline.} =
      #   let validationResult = isValidPropertyValue(`propertyName`, value)
      #   if validationResult.valid:
      #     style.properties[`propertyName`] = value
      #   else:
      #     raise newException(InvalidCSSValue, "Invalid value for " & `propertyName` & ": \n" & validationResult.errors.join("\n"))
      proc `nameIdent`*(style: `stylesName`): string {.inline.} =
        return style.properties[`propertyName`]
      
      macro `nameIdent`*(style: var `stylesName`, value: untyped): untyped =
        result = nnkCommand.newTree(
          nnkDotExpr.newTree(
            style,
            ident("setProperty")
          ),
          newStrLitNode(`propertyName`),
          value
        )

      macro `nameEqualsIdent`*(style: var `stylesName`, value: untyped): untyped =
        # echo value.treeRepr
        if value.kind == nnkStrLit:
          let validationResult = validatePropertyValue(`propertyName`, value.strVal)
          if validationResult.valid:
            result = nnkAsgn.newTree(
              nnkBracketExpr.newTree(
                nnkDotExpr.newTree(
                  style,
                  ident("properties")
                ),
                newStrLitNode(`propertyName`)
              ),
              value
            )
          else:
            error "Invalid value for " & `propertyName` & ": " & validationResult.errors.join("\n"), value
        else:
          result = nnkAsgn.newTree(
            nnkBracketExpr.newTree(
              nnkDotExpr.newTree(
                style,
                ident("properties")
              ),
              newStrLitNode(`propertyName`)
            ),
            value
          )
    

  let toStr = nnkAccQuoted.newTree(ident("$"))
  
  let equalsIdent = nnkAccQuoted.newTree(ident("[]="))
  result.add quote do:
    proc newStyles*(): `stylesName` =
      return Styles(properties: initTable[string, string]())
  
    proc `toStr`*(styles: `stylesName`): string =
      for key, value in styles.properties:
        result.add key & ": " & value & "; "
      return result[0..^3]
    
    # proc setProperty*(styles: var `stylesName`, key: string, value: string) =
    #   let validationResult = isValidPropertyValue(key, value)
    #   if validationResult.valid:
    #     styles.properties[key] = value
    #   else:
    #     raise newException(InvalidCSSValue, "Invalid value for " & key & ": \n" & validationResult.errors.join("\n"))

    macro setProperty*(style: var `stylesName`, key: string, value: untyped): untyped =
      var valueStr = value.repr
      if value.kind == nnkStrLit:
        valueStr = value.strVal
      
      var isPure = true
      if valueStr.contains("`"):
        isPure = false
      
      # expectKind(key, nnkStrLit)

      if not isPure:
        var node: NimNode = newEmptyNode()
        var str = ""
        var isInside = false
        for i, c in value.repr:
          if c == '`':
            if isInside:
              isInside = false

              if node.kind == nnkEmpty:
                node = ident(str)
              else:
                node = nnkInfix.newTree(
                  ident("&"),
                  node,
                  ident(str)
                )
              str = ""
            else:
              isInside = true
                
              if node.kind == nnkEmpty:
                node = newStrLitNode(str)
              else:
                node = nnkInfix.newTree(
                  ident("&"),
                  node,
                  newStrLitNode(str.replaceUnits())
                )
              str = ""
          else:
            str.add c
          
        result = nnkAsgn.newTree(
          nnkBracketExpr.newTree(
            nnkDotExpr.newTree(
              style,
              ident("properties")
            ),
            key
          ),
          node
        )
      else:
        valueStr = valueStr.replaceUnits()
        let validationResult = validatePropertyValue(key.strVal, valueStr)
        if not validationResult.valid:
          error "Invalid value for " & key.strVal & ": " & validationResult.errors.join("\n"), value

        result = nnkAsgn.newTree(
          nnkBracketExpr.newTree(
            nnkDotExpr.newTree(
              style,
              ident("properties")
            ),
            key
          ),
          newStrLitNode(valueStr)
        )

    # proc `equalsIdent`[T, U](styles: var `stylesName`, key: T, value: U) =


makeStyle Styles
export Styles

# macro fromDocument*(doc: WrittenDocument): Styles =
#   var styles = newStyles()
#   for docNode in doc:
#     if docNode.kind != cssikPROPERTY:
#       raise newException(ValueError, "Invalid CSS document! Can only construct a Styles object from pure properties.")
#     # let property = docNode.property

# proc append*(styles: var Styles, doc: WrittenDocument) =
#   for docNode in doc:
#     let kind: WrittenDocumentNodeKind = docNode.kind
#     if docNode.kind == cssikPROPERTY:
#       let property = docNode.property
#       let body = property.body
#       if body.kind == pkMIXED:
#         styles.setProperty property.name, property.body.node
#       elif body.kind == pkPURE:
#         styles.setProperty property.name, property.body.value
#     else:
#       raise newException(ValueError, "Invalid CSS document! Only expecting pure properties, cannot append rules or inlines to a Styles object.")

macro add*(styles: var Styles, body: untyped): untyped =
  if(body.kind != nnkStmtList):
    error "Expecting a statement list", body
  
  result = nnkStmtList.newNimNode()

  let doc = parseWrittenDocument(body)
  for docNode in doc:
    if docNode.kind != cssikPROPERTY:
      raise newException(ValueError, "Invalid CSS document! Can only construct a Styles object from pure properties.")
    let property = docNode.property
    let body = docNode.property.body

    let name = property.name
    if body.kind == pkPURE:
      let content = body.value
      result.add quote do:
        `styles`.setProperty(`name`, `content`) 
    else:
      let content = body.node
      result.add quote do:
        `styles`.setProperty(`name`, `content`)