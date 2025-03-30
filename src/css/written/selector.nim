import strutils, tables
import ../imports/imports

proc processWrittenSelector*(selector: string): string 

proc isAttributeSelector(tag: string): bool =
  # Check if this is an attribute selector (contains = but not as part of an operator)
  return "=" in tag and not (tag.contains(">=") or tag.contains("<=") or tag.contains("!="))

proc formatAttributeSelector(tag: string): string =
  var formatted = tag.strip()
  
  # Standardize quotes - replace single quotes with double quotes if needed
  if "='" in formatted and "=\"" notin formatted:
    var parts = formatted.split("='", 1)
    if parts.len == 2 and parts[1].endsWith("'"):
      let attrName = parts[0].strip()
      let attrValue = parts[1][0..^2].strip() # Remove trailing single quote
      formatted = attrName & "=\"" & attrValue & "\""
  
  # Add brackets
  return "[" & formatted & "]"

proc finishTag(currentTag: string): string =
  var tag = currentTag.strip()
  if tag.len == 0:
    return ""
  
  # Check if this is an attribute selector
  if isAttributeSelector(tag):
    return formatAttributeSelector(tag)
  
  # Check if this tag has nested content that needs recursive processing
  if "[" in tag or "!" in tag:
    # Handle function-style pseudo classes like not()
    if "(" in tag:
      let openPos = tag.find('(')
      var closePos = tag.rfind(')')
      if closePos == -1:
        closePos = tag.len
        tag.add ')'
        
      let funcName = tag[0..<openPos]
      let args = tag[openPos+1..<closePos]
      
      # Process arguments recursively
      let processedArgs = processWrittenSelector(args)
      
      # Check if it's a valid pseudo-element/class
      var shortTag = funcName & "()"
      let isSingle = (":" & shortTag) in selectors
      let isDouble = ("::" & shortTag) in selectors
      
      if not isSingle and not isDouble:
        raise newException(ValueError, "Invalid CSS selector! Unknown pseudo-syntax: :" & shortTag & " or ::" & shortTag)
      
      # Create result with processed arguments
      if isSingle:
        return ":" & funcName & "(" & processedArgs & ")"
      elif isDouble:
        return "::" & funcName & "(" & processedArgs & ")"
      else:
        # Default to single colon if not found (shouldn't reach here)
        return ":" & funcName & "(" & processedArgs & ")"
    else:
      # Regular tag with nested content
      return processWrittenSelector(tag)
  
  # Regular pseudo processing (no nesting)
  if tag.endsWith('(') and not tag.endsWith("()"):
    tag.add ')'
  
  var shortTag = tag.split('(')[0]
  if "(" in tag:
    shortTag.add "()"
  
  let isSingle = (":" & shortTag) in selectors
  let isDouble = ("::" & shortTag) in selectors
  
  # If it's a known pseudo-class or pseudo-element, use appropriate colon format
  if isSingle:
    return ":" & tag
  elif isDouble:
    return "::" & tag
  elif tag == "_" or tag == "*":
    return "*"
  else:
    # For unknown tags, treat as attribute selector
    return "[" & tag & "]"

proc processWrittenSelector*(selector: string): string =
  var newSelector = ""
  var inBracket = false
  var currentTag = ""
  
  proc tagCountMatches(): bool =
    # Check if parentheses, single quotes, and double quotes are balanced
    let openParens = currentTag.count('(')
    let closeParens = currentTag.count(')')
    let singleQuotes = currentTag.count('\'')
    let doubleQuotes = currentTag.count('"')
    
    return openParens == closeParens and 
           singleQuotes mod 2 == 0 and 
           doubleQuotes mod 2 == 0
  
  const REPLACEMENTS = [
    ('!', '.')
  ].toTable()
  
  for cc in selector:
    var c = cc
    if c in REPLACEMENTS:
      c = REPLACEMENTS[c]
    
    if inBracket:
      if c == ']' and tagCountMatches():
        inBracket = false
        if currentTag.len > 0:
          newSelector.add finishTag(currentTag)
          currentTag = ""
      elif c == ',' and tagCountMatches():
        if currentTag.len > 0:
          newSelector.add finishTag(currentTag)
          currentTag = ""
      else:
        currentTag.add c
    else:
      if c == '[':
        if inBracket:
          raise newException(ValueError, "Invalid CSS selector! Nested brackets are not allowed.")
        inBracket = true
      else:
        newSelector.add c
  
  if currentTag.len > 0:
    raise newException(ValueError, "Invalid CSS selector! Unclosed tag: " & currentTag)
  
  return newSelector.strip()