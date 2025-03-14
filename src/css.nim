# std
import tables
import strutils

# this
import ./css/imports
import ./css/validator

type
  ValidResult* = object
    isValid*: bool
    issues*: seq[string]

proc singleIssue(valid: bool, error: string): ValidatorResult =
  var errors: seq[string] = @[]
  if not valid:
    errors.add(error)
  return ValidatorResult(valid: valid, errors: errors)




proc isValidUnitValue*(value: string): ValidatorResult =
  let unit = value.strip(chars = {'0'..'9', '.', '+', '-'})
  return singleIssue(
    unit in imports.units,
    "Invalid unit: " & value
  )

proc isValidPropertyName*(name: string): ValidatorResult =
  return singleIssue(
    name in imports.properties,
    "Invalid property name: " & name
  )

proc isValidPropertyValue*(property: PropertiesValue, value: string): ValidatorResult =
  let syntax = property.syntax
  return validateCSSValue(syntax, value)

proc isValidPropertyValue*(name: string, value: string): ValidatorResult =
  let validName = isValidPropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return isValidPropertyValue(property, value)


echo isValidPropertyValue("color", "oranges")