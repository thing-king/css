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
  properties["-moz-transition"] = PropertiesValue(syntax: "<single-transition>#")
  properties["-webkit-text-decoration-color"] = PropertiesValue(syntax: "<color>")
  properties["-webkit-backface-visibility"] = PropertiesValue(syntax: "visible | hidden")
  properties["-o-object-fit"] = PropertiesValue(syntax: "fill | contain | cover | none | scale-down")
  properties["-moz-column-gap"] = PropertiesValue(syntax: "normal | <length-percentage>")
  properties["-moz-user-select"] = PropertiesValue(syntax: "auto | text | none | all")

const syntaxes* = importCSSAndModify syntaxes:
  syntaxes["url"] = SyntaxesValue(syntax: "url( <string> )")
  syntaxes["length-percentage"] = SyntaxesValue(syntax: "<length> | <percentage>")
const functions* = importCSSAndModify functions:
  functions["url()"] = FunctionsValue(syntax: "url( <string> )")



# const atRules* = importCSS atRules
# const types* = importCSS types
# const units* = importCSS units
# const selectors* = importCSS selectors

const units* = @[
  "cap",
  "ch",
  "cm",
  "deg",
  "dpcm",
  "dpi",
  "dppx",
  "em",
  "ex",
  "fr",
  "grad",
  "Hz",
  "ic",
  "in",
  "kHz",
  "mm",
  "ms",
  "pc",
  "pt",
  "px",
  "Q",
  "rad",
  "rem",
  "s",
  "turn",
  "vh",
  "vmax",
  "vmin",
  "vw",
  "x"
]

# proc repr*[K, V](tbl: Table[K, V]): string =
#   # Create a valid Nim constructor syntax
#   result = "["
#   var first = true
#   var empty = true
#   for key, val in tbl.pairs:
#     empty = false
#     if not first:
#       result.add(", ")
#     result.add("(\"" & key & "\", " & val.repr & ")")
#     first = false
#   result.add("].toTable")
#   if empty:
#     result = "initTable[" & $K & ", " & $V & "]()"

# import tables, strutils, typetraits, macros

# proc genRepr[T](val: T, varName: string): string

# # Extract the actual type name for any value using Nim's type system
# proc getTypeName[T](val: T): string =
#   # Get full type name
#   var fullTypeName = name(type(val))
  
#   # Strip any generic parameters if present
#   if '[' in fullTypeName:
#     fullTypeName = fullTypeName.split('[')[0]
  
#   # Remove module prefix if present
#   if '.' in fullTypeName:
#     result = fullTypeName.split('.')[^1]
#   else:
#     result = fullTypeName
  
#   # Handle special case of tuple which might actually be a variant object
#   if result == "tuple" and compiles(val.kind):
#     # This is likely a variant object, not just a tuple
#     # Try to derive the type name from the context
#     # Since Nim doesn't provide direct access to the original type name
#     # we need to rely on the kind field to construct the appropriate name
#     when compiles($val.kind):
#       let kindValue = $val.kind
#       return kindValue.split('.')[0]  # Get type prefix from enum kind
  
#   return result

# # Helper to get field value with proper constructor name
# proc getFieldValueRepr[T](fieldVal: T, fieldName: string = ""): string =
#   # For variant objects (tuples with a 'kind' field)
#   when compiles(fieldVal.kind):
#     let typeName = getTypeName(fieldVal)
#     let kindValue = $fieldVal.kind
    
#     # Handle different variant kinds based on available fields
#     when compiles(fieldVal.value0) and compiles($fieldVal.kind == "Variant0"):
#       if $fieldVal.kind == "Variant0":
#         result = "$1(kind: $2, value0: $3)".format(
#           typeName, $fieldVal.kind, getFieldValueRepr(fieldVal.value0, ""))
#       elif $fieldVal.kind == "Variant1" and compiles(fieldVal.value1):
#         when compiles(fieldVal.value1[0]):  # Check if value1 is a sequence
#           var values: seq[string] = @[]
#           for item in fieldVal.value1:
#             values.add(getFieldValueRepr(item, ""))
#           result = "$1(kind: $2, value1: @[$3])".format(
#             typeName, $fieldVal.kind, values.join(", "))
#         else:
#           result = "$1(kind: $2, value1: $3)".format(
#             typeName, $fieldVal.kind, getFieldValueRepr(fieldVal.value1, ""))
#       else:
#         # Fallback for other kinds
#         result = "$1($2)".format(typeName, $fieldVal)
#     elif T is string:
#       result = "\"\"\"$1\"\"\"".format(fieldVal)
#     elif T is seq:
#       var items: seq[string] = @[]
#       for item in fieldVal:
#         items.add(getFieldValueRepr(item, ""))
#       result = "@[$1]".format(items.join(", "))
#     elif T is enum:
#       result = $fieldVal
#     else:
#       result = $fieldVal
#   else:
#     # Non-variant types
#     when T is string:
#       result = "\"\"\"$1\"\"\"".format(fieldVal)
#     elif T is seq:
#       var items: seq[string] = @[]
#       for item in fieldVal:
#         items.add(getFieldValueRepr(item, ""))
#       result = "@[$1]".format(items.join(", "))
#     elif T is enum:
#       result = $fieldVal
#     else:
#       result = $fieldVal

# # Table specific representation
# proc genTableRepr[K, V](t: Table[K, V], varName: string): string =
#   result = "var $1 = initTable[$2, $3]()\n".format(
#     varName, name(K), name(V))
  
#   var idx = 0
#   for k, v in t:
#     # Generate key representation using triple quotes for strings
#     let keyStr = when K is string: "\"\"\"" & $k & "\"\"\"" else: $k
    
#     # Handle value based on its type
#     when V is Table:
#       let valueVarName = varName & "_" & $idx
#       result &= genTableRepr(v, valueVarName)
#       result &= "$1[$2] = $3\n".format(varName, keyStr, valueVarName)
#     elif V is object:
#       # Create the object inline with its fields
#       let objType = name(V)
#       var objFields: seq[string] = @[]
      
#       # Extract field values for inline definition
#       for fieldName, fieldVal in v.fieldPairs:
#         objFields.add("$1: $2".format(fieldName, getFieldValueRepr(fieldVal, fieldName)))
      
#       let objStr = "$1($2)".format(objType, objFields.join(", "))
#       result &= "$1[$2] = $3\n".format(varName, keyStr, objStr)
#     elif V is string:
#       result &= "$1[$2] = \"\"\"$3\"\"\"\n".format(varName, keyStr, v)
#     else:
#       result &= "$1[$2] = $3\n".format(varName, keyStr, getFieldValueRepr(v, ""))
#     idx.inc

# # Generic value representation
# proc genRepr[T](val: T, varName: string): string =
#   when T is Table:
#     result = genTableRepr(val, varName)
#   elif T is object:
#     # For objects that are variables on their own, not inline
#     result = "var $1 = $2()\n".format(varName, name(T))
#     for fieldName, fieldVal in val.fieldPairs:
#       result &= "$1.$2 = $3\n".format(varName, fieldName, getFieldValueRepr(fieldVal, fieldName))
#   elif T is string:
#     result = "var $1 = \"\"\"$2\"\"\"\n".format(varName, val)
#   else:
#     result = "var $1 = $2\n".format(varName, getFieldValueRepr(val, ""))

# # The main entry point that accepts a custom root variable name
# proc repr*[T](val: T, rootVarName: string = "functions"): string =
#   result = genRepr(val, rootVarName)

# # echo syntaxes.repr
# echo functions.repr