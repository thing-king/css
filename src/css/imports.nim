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

import cache/css_imports_schema_cache
import cache/css_imports_cache
export css_imports_schema_cache
export css_imports_cache