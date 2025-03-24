import strutils

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

# echo kebabToCamelCase("object-fit")