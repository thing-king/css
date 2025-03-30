import strutils, tables

import types
import util
import imports/imports

import analyzer/validator

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

proc isValidSyntaxValue*(syntax: string, value: string): ValidatorResult {.gcsafe.} =
  return validateCSSValue(syntax, value)

proc isValidVariableValue*(value: string): ValidatorResult {.gcsafe.} =
  return isValidSyntaxValue("<declaration-value>", value)

proc isValidPropertyValue*(property: PropertiesValue, value: string): ValidatorResult {.gcsafe.} =
  let syntax = property.syntax

  var vv = value
  if vv.endsWith(";"):
    vv = vv[0..^2]
  if vv.endsWith(" !important"):
    vv = vv[0..^12]
  
  if vv in ["initial", "unset", "revert", "inherit"]:
    return ValidatorResult(valid: true)

  return isValidSyntaxValue(syntax, vv)
proc isValidPropertyValue*(name: string, value: string): ValidatorResult {.gcsafe.} =
  let validName = isValidPropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return isValidPropertyValue(property, value)
