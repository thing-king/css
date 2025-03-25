# std
import macros
import strutils, tables

# this
import ./css/util
import ./css/validator

export ValidatorResult


type InvalidCSSValue* = object of ValueError

proc singleIssue(valid: bool, error: string): ValidatorResult =
  var errors: seq[string] = @[]
  if not valid:
    errors.add(error)
  return ValidatorResult(valid: valid, errors: errors)

proc replaceUnits*(input: string): string =
  var unitsSeq = @["%"]
  for unitName in units:
    unitsSeq.add(unitName)

  result = input
  for unit in unitsSeq:
    result = result.replace("." & unit, unit)


proc isValidUnitValue*(value: string): ValidatorResult {.gcsafe.} =
  let unit = value.strip(chars = {'0'..'9', '.', '+', '-'})
  return singleIssue(
    unit in imports.units,
    "Invalid unit: " & value
  )

proc isValidPropertyName*(name: string): ValidatorResult {.gcsafe.} =
  return singleIssue(
    name in imports.properties,
    "Invalid property name: " & name
  )

proc getProperty*(name: string): PropertiesValue {.gcsafe.} =
  return imports.properties[name]

proc isValidPropertyValue*(property: PropertiesValue, value: string): ValidatorResult {.gcsafe.} =
  let syntax = property.syntax

  var vv = value
  if vv.endsWith(";"):
    vv = vv[0..^2]
  if vv.endsWith(" !important"):
    vv = vv[0..^12]
  
  if vv in ["initial", "unset", "revert", "inherit"]:
    return ValidatorResult(valid: true)

  return validateCSSValue(syntax, vv)

proc isValidPropertyValue*(name: string, value: string): ValidatorResult {.gcsafe.} =
  let validName = isValidPropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return isValidPropertyValue(property, value)



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
        echo value.treeRepr
        echo value.repr
        
        var isPure = true
        if value.repr.contains("`"):
          isPure = false
      
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
              newStrLitNode(`propertyName`)
            ),
            node
          )
        else:
          let valueStr = value.repr.replaceUnits()
          let validationResult = isValidPropertyValue(`propertyName`, valueStr)
          if not validationResult.valid:
            error "Invalid value for " & `propertyName` & ": " & validationResult.errors.join("\n"), value

          result = nnkAsgn.newTree(
            nnkBracketExpr.newTree(
              nnkDotExpr.newTree(
                style,
                ident("properties")
              ),
              newStrLitNode(`propertyName`)
            ),
            newStrLitNode(valueStr)
          )


      macro `nameEqualsIdent`*(style: var `stylesName`, value: untyped): untyped =
        echo value.treeRepr
        if value.kind == nnkStrLit:
          let validationResult = isValidPropertyValue(`propertyName`, value.strVal)
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
            newStrLitNode(value.repr)
          )
    
  result.add quote do:
    proc newStyles*(): Styles =
      return Styles(properties: initTable[string, string]())
  

makeStyle Styles
export Styles


# var styles = newStyles()

# let aut = "auto"
# styles.margin = "1px"
# styles.margin = `aut`


# echo properties

# macro `test=`(styles: typed, value: untyped): untyped =
#   if value.kind == nnkStrLit:
#     let validationResult = isValidPropertyValue("object-fit", value.strVal)
#     if validationResult.valid:
#       result = quote do:
#         `styles`.internalObjectFit = `value`
#     else:
#       error "Invalid value for object-fit: " & validationResult.errors.join("\n"), value
#   else:
#     result = quote do:
#       `styles`.internalObjectFit = `value`

# styles.test = "dsadsa"




# var style = Styles()
# style.test = "5"
# echo style.objectFit


# style.backgroundColor = "orange"
# echo style.backgroundColor

# style.objectFit = "red"
# echo style.objectFit


# echo isValidPropertyValue("color", "inherit !important;")