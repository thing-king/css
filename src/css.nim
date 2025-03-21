# std
import tables
import strutils

# this
import ./css/imports
import ./css/validator

export ValidatorResult


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

proc isValidPropertyValue*(property: PropertiesValue, value: string): ValidatorResult =
  let syntax = property.syntax

  var vv = value
  if vv.endsWith(";"):
    vv = vv[0..^2]
  if vv in ["initial", "unset", "revert", "inherit"]:
    return ValidatorResult(valid: true)

  return validateCSSValue(syntax, vv)

proc isValidPropertyValue*(name: string, value: string): ValidatorResult =
  let validName = isValidPropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return isValidPropertyValue(property, value)


# echo isValidPropertyValue("color", "inherit;")