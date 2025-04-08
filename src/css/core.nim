import strutils, tables

import types
import util
import imports/imports

import analyzer/validator

proc validateUnitValue*(value: string): ValidatorResult {.gcsafe.} =
  let unit = value.strip(chars = {'0'..'9', '.', '+', '-'})
  return singleIssue(
    unit in imports.units,
    "Invalid unit: " & value
  )

proc validatePropertyName*(name: string): ValidatorResult {.gcsafe.} =
  return singleIssue(
    name in imports.properties,
    "Invalid property name: " & name
  )

proc getProperty*(name: string): PropertiesValue {.gcsafe.} =
  return imports.properties[name]

proc validateSyntaxValue*(syntax: string, value: string): ValidatorResult {.gcsafe.} =
  # Temporary hack: Manually parse out ';', '!important!', and auto-pass on 'initial', 'unset', 'revert', and 'inherit'
  var realValue = value
  if realValue.endsWith(";"):
    realValue = realValue[0..^2]
  if realValue.endsWith(" !important"):
    realValue = realValue[0..^12]
  
  if realValue in ["initial", "unset", "revert", "inherit"]:
    return ValidatorResult(valid: true)
  return validateCSSValue(syntax, realValue)

proc validateVariableValue*(value: string): ValidatorResult {.gcsafe.} =
  return validateSyntaxValue("<declaration-value>", value)

proc validatePropertyValue*(property: PropertiesValue, value: string): ValidatorResult {.gcsafe.} =
  let syntax = property.syntax
  return validateSyntaxValue(syntax, value)

proc validatePropertyValue*(name: string, value: string): ValidatorResult {.gcsafe.} =
  let validName = validatePropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return validatePropertyValue(property, value)


# TODO
proc validateCSS*(css: string): ValidatorResult {.gcsafe.} =
  discard
