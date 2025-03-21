# import pkg/jsony_plus/schema
# import pkg/jsony_plus/schema_cacher
# cacheSchema "thing/web/css/cache/css_imports_schema_cache.nim", "src/thing/web/css/cache/css_imports_schema_cache.nim":
#   fromSchema "thing/web/css/schemas/definitions.json",       "Definitions"
#   fromSchema "thing/web/css/schemas/at-rules.schema.json",   "AtRule"
#   fromSchema "thing/web/css/schemas/types.schema.json",      "Types"
#   fromSchema "thing/web/css/schemas/units.schema.json",      "Units"
#   fromSchema "thing/web/css/schemas/syntaxes.schema.json",   "Syntaxes"
#   fromSchema "thing/web/css/schemas/properties.schema.json", "Properties"
#   fromSchema "thing/web/css/schemas/selectors.schema.json",  "Selectors"
#   fromSchema "thing/web/css/schemas/functions.schema.json",  "Functions"
# cacheTypes "cache/css_imports_cache.nim", "css_imports_schema_cache.nim":
#   const atRulesData = staticRead("data/at-rules.json")
#   const typesData = staticRead("data/types.json")
#   const unitsData = staticRead("data/units.json")
#   const syntaxesData = staticRead("data/syntaxes.json")
#   const propertiesData = staticRead("data/properties.json")
#   const selectorsData = staticRead("data/selectors.json")
#   const functionsData = staticRead("data/functions.json")
#   const types* = typesData.fromJson(Types)
#   const units* = unitsData.fromJson(Units)
#   const syntaxes* = syntaxesData.fromJson(Syntaxes)
#   const selectors* = selectorsData.fromJson(Selectors)
#   const functions* = functionsData.fromJson(Functions)
#   const atRules* = atRulesData.fromJson(AtRule)
#   const properties* = propertiesData.fromJson(Properties)

import macros
import tables

import cache/css_imports_schema_cache
import cache/css_imports_cache
export css_imports_schema_cache
# export css_imports_cache

const AVAILABLE = [
  "atRules",
  "types",
  "units",
  "syntaxes",
  "selectors",
  "functions",
  "properties"
]

macro importCSSAndModify*(kind: untyped, blck: untyped): untyped =
  expectKind(kind, nnkIdent)
  expectKind(blck, nnkStmtList)
  if kind.strVal notin AVAILABLE:
    error "Kind not found: " & kind.strVal
  
  result = quote do:
    block:
      var `kind` = css_imports_cache.`kind`
      `blck`
      `kind`

macro importCSS*(kind: untyped): untyped =
  expectKind(kind, nnkIdent)
  if kind.strVal notin AVAILABLE:
    error "Kind not found: " & kind.strVal
  
  result = quote do:
    css_imports_cache.`kind`

const properties* = importCSSAndModify properties:
  properties["-webkit-text-size-adjust"] = PropertiesValue(syntax: "<percentage> | auto | none")
  properties["-webkit-text-decoration"] = PropertiesValue(syntax: "<'text-decoration-line'> || <'text-decoration-style'> || <'text-decoration-color'> || <'text-decoration-thickness'>")
  properties["-webkit-text-decoration-skip-ink"] = PropertiesValue(syntax: "auto | all | none")
  properties["-webkit-margin-end"] = PropertiesValue(syntax: "<length-percentage> | auto")
  properties["-webkit-margin-before"] = PropertiesValue(syntax: "<length-percentage> | auto")
  properties["-webkit-transition"] = PropertiesValue(syntax: "<single-transition>#")
  properties["-webkit-print-color-adjust"] = PropertiesValue(syntax: "economy | exact")
  properties["color-adjust"] = PropertiesValue(syntax: "economy | exact")

const syntaxes* = importCSSAndModify syntaxes:
  syntaxes["url"] = SyntaxesValue(syntax: "url( <string> )")
  syntaxes["length-percentage"] = SyntaxesValue(syntax: "<length> | <percentage>")
const functions* = importCSSAndModify functions:
  functions["url()"] = FunctionsValue(syntax: "url( <string> )")
const atRules* = importCSS atRules
const types* = importCSS types
const units* = importCSS units
const selectors* = importCSS selectors