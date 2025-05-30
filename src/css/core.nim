import strutils, tables

import types
import util
import imports/imports

import analyzer/validator
import analyzer/value_parser


# TODO: fix "declaration-value", its not efficient to check every possible syntax against the variable value
const VALIDATE_VARIABLES = false

proc validateUnitValue*(value: string): ValidatorResult {.gcsafe.} =
  let unit = value.strip(chars = {'0'..'9', '.', '+', '-'})
  return ValidatorResult(
    unit in imports.units,
    @["Invalid unit: " & value]
  )
proc validateVariableName*(name: string): ValidatorResult {.gcsafe.} =
  var valid = false
  if name.startsWith("--") and not name.endsWith("-"):
    # and if name does not have spaces- and is only a-Z and 0-9
    valid = true
    for c in name:
      if not c.isAlphaNumeric and c != '-':
        valid = false
        break

  return ValidatorResult(
    valid,
    @["Invalid variable name: " & name]
  )
proc isVariableName*(name: string): bool {.gcsafe.} =
  return validateVariableName(name).valid
proc validatePropertyName*(name: string): ValidatorResult {.gcsafe.} =
  return ValidatorResult(
    name in imports.properties,
    @["Invalid property name: " & name]
  )
proc validateAtRuleName*(rawName: string): ValidatorResult {.gcsafe.} =
  var name = rawName
  if not name.startsWith("@"):
    name = "@" & name
  return ValidatorResult(
    name in imports.atRules,
    @["Invalid at-rule name: " & name]
  )

proc getProperty*(name: string): PropertiesValue {.gcsafe.} =
  return imports.properties[name]
proc getAtRule*(rawName: string): AtRuleValue {.gcsafe.} =
  var name = rawName
  if not name.startsWith("@"):
    name = "@" & name
  return imports.atRules[name]

proc validateSyntaxValue*(syntax: string, value: string): ValidatorResult {.gcsafe.} =
  # Temporary hack: Manually parse out ';', '!important!', and auto-pass on 'initial', 'unset', 'revert', and 'inherit'
  if value in ["initial", "unset", "revert", "inherit"]:
    return ValidatorResult(valid: true)
  return validate(syntax, value)
proc validateSyntaxValue*(syntax: string, tokens: seq[ValueToken]): ValidatorResult {.gcsafe.} =
  # Temporary hack: Manually parse out ';', '!important!', and auto-pass on 'initial', 'unset', 'revert', and 'inherit'
  if tokens.len == 1 and tokens[0].kind == vtkIdent and tokens[0].value in ["initial", "unset", "revert", "inherit"]:
    return ValidatorResult(valid: true)
  return validate(syntax, tokens)

proc validateVariableValue*(value: string): ValidatorResult {.gcsafe.} =
  return validateSyntaxValue("<declaration-value>", value)
proc validateVariableValue*(tokens: seq[ValueToken]): ValidatorResult {.gcsafe.} =
  return validateSyntaxValue("<declaration-value>", tokens)

proc validatePropertyValue*(property: PropertiesValue, value: string): ValidatorResult {.gcsafe.} =
  let syntax = property.syntax
  return validateSyntaxValue(syntax, value)
proc validatePropertyValue*(property: PropertiesValue, tokens: seq[ValueToken]): ValidatorResult {.gcsafe.} =
  let syntax = property.syntax
  return validateSyntaxValue(syntax, tokens)

proc validatePropertyValue*(name: string, value: string): ValidatorResult {.gcsafe.} =
  let validName = validatePropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return validatePropertyValue(property, value)

proc validatePropertyValue*(name: string, tokens: seq[ValueToken]): ValidatorResult {.gcsafe.} =
  let validName = validatePropertyName(name)
  if not validName.valid:
    return validName

  let property = imports.properties[name]
  return validatePropertyValue(property, tokens)

proc validateCSS*(rawTokens: seq[ValueToken], allowProperties: bool = false, allowRules: bool = true): ValidatorResult {.gcsafe.} =
  var tokens = rawTokens
  if tokens.len == 1 and tokens[0].kind == vtkSequence:
    tokens = tokens[0].children

  # echo tokens.treeRepr

  var issues: seq[Error] = @[]

  proc validateProperty(token: ValueToken) =
    let isVariable = isVariableName(token.value)
    if not isVariable:
      let name = token.value
      let validName = validatePropertyName(name)
      if not validName.valid:
        issues.add(
          Error(
            message: "Invalid property name: " & name,
            line: token.line,
            column: token.column,
            preview: $token
          )
        )
        return
      let valid = validatePropertyValue(token.value, token.children)
      if not valid.valid:
        issues.add(
          Error(
            message: valid.errors.join(", "),
            line: token.line,
            column: token.column,
            preview: $token
          )
        )
        return
    else:
      if VALIDATE_VARIABLES:
        let valid = validateVariableValue(token.children)
        if not valid.valid:
          issues.add(
            Error(
              message: valid.errors.join(", "),
              line: token.line,
              column: token.column,
              preview: $token
            )
          )
          return

  proc validateAtRule(token: ValueToken) =
    let name = token.value
    let validName = validateAtRuleName(name)
    if not validName.valid:
      issues.add(
        Error(
          message: "Invalid at-rule name: " & name,
          line: token.line,
          column: token.column,
          preview: $token
        )
      )
      return
    let valid = validate(getAtRule(name).syntax, @[token])
    if not valid.valid:
      issues.add(
        Error(
          message: valid.errors.join(", "),
          line: token.line,
          column: token.column,
          preview: $token
        )
      )
      return

  for token in tokens:
    if token.kind == vtkProperty and not allowProperties:
      issues.add(
        Error(
          message: "Property not allowed at root level",
          line: token.line,
          column: token.column
        )
      )
      continue
    if token.kind in {vtkRule, vtkAtRule} and not allowRules:
      issues.add(
        Error(
          message: "Rules not allowed",
          line: token.line,
          column: token.column
        )
      )
      continue
    
    case token.kind
    of vtkProperty:
      validateProperty(token)
    of vtkRule:
      for child in token.body:
        if child.kind != vtkProperty:
          issues.add(
            Error(
              message: "Invalid item in rule body: " & $child.kind,
              line: child.line,
              column: child.column
            )
          )
          continue
        else:
          validateProperty(child)
    of vtkAtRule:
      validateAtRule(token)
    else:
      issues.add(
        Error(
          message: "Invalid token kind: " & $token.kind,
          line: token.line,
          column: token.column
        )
      )
      continue
    
  if issues.len == 0:
    return ValidatorResult(valid: true)
  else:
    return ValidatorResult(valid: false, errors: issues)
proc validateCSS*(css: string, allowProperties: bool = false, allowRules: bool = true): ValidatorResult {.gcsafe.} =
  let tokens = tokenizeValueFast(css)
  return validateCSS(tokens, allowProperties, allowRules)

when isMainModule:
#   let content = """
# :root,
# [data-bs-theme=light] {
#   --bs-blue: #0d6efd;
# }
# """

  let content = readFile("./src/css/analyzer/bootstrap.css")
  let result = validateCSS(content, allowProperties = false, allowRules = true)
  echo $result.errors.len

  let maxErrorPrintCount = 10
  for i in 0 ..< min(result.errors.len, maxErrorPrintCount):
    let error = result.errors[i]
    echo "Error: " & error.message
    echo "Line: " & $error.line
    echo "Column: " & $error.column
    echo "Preview: " & $error.preview
    echo ""
