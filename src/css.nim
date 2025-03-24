# std
import macros
import strutils, tables

# this
import ./css/util
import ./css/imports
import ./css/validator

export ValidatorResult


type InvalidCSSValue* = object of ValueError

proc singleIssue(valid: bool, error: string): ValidatorResult =
  var errors: seq[string] = @[]
  if not valid:
    errors.add(error)
  return ValidatorResult(valid: valid, errors: errors)




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
    var nameEqualsIdent = ident(name & "=")
    var nameIdent = ident(name)

    result.add quote do:
      proc `nameEqualsIdent`*(style: var `stylesName`, value: string) {.inline.} =
        let validationResult = isValidPropertyValue(`propertyName`, value)
        if validationResult.valid:
          style.properties[`propertyName`] = value
        else:
          raise newException(InvalidCSSValue, "Invalid value for " & `propertyName` & ": \n" & validationResult.errors.join("\n"))
      proc `nameIdent`*(style: `stylesName`): string {.inline.} =
        return style.properties[`propertyName`]

    
  



makeStyle Styles
export Styles

var style = Styles()

style.backgroundColor = "orange"
echo style.backgroundColor

style.objectFit = "red"
echo style.objectFit


# echo isValidPropertyValue("color", "inherit !important;")