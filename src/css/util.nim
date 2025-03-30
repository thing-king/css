import strutils

import types
import imports/imports

proc kebabToCamelCase*(s: string): string =
  ## Converts a kebab-case string to camelCase
  ## Example: "-webkit-line-clamp" -> "webkitLineClamp"
  
  result = ""
  var capitalizeNext = false
  
  for i, c in s:
    if c == '-':
      capitalizeNext = true
    elif capitalizeNext:
      result.add(toUpperAscii(c))
      capitalizeNext = false
    else:
      result.add(c)
  
  # Handle case when string begins with a hyphen (like "-webkit-line-clamp")
  if result.len > 0 and s.len > 0 and s[0] == '-':
    result = result[1..^1]
proc toKebabCase*(s: string): string =
  if s.len == 0:
    return ""
  
  result = newStringOfCap(s.len + 5) # Extra capacity for potential hyphens
  result.add(s[0].toLowerAscii)
  
  for i in 1 ..< s.len:
    if s[i].isUpperAscii:
      result.add('-')
      result.add(s[i].toLowerAscii)
    else:
      result.add(s[i])


proc singleIssue*(valid: bool, error: string): ValidatorResult =
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

