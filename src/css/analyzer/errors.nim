import strutils, sequtils, tables, algorithm, options

import validator

type
  FormattedError* = object
    message*: string
    suggestion*: string

# Extract data type from error string using simple string operations
proc extractDataType(err: string): string =
  if not (err.contains("Data type") and err.contains("failed")):
    return ""
    
  let startIdx = err.find("Data type '")
  if startIdx < 0:
    return ""
    
  let valueStartIdx = startIdx + 11  # Length of "Data type '"
  let valueEndIdx = err.find("'", valueStartIdx)
  if valueEndIdx < 0:
    return ""
    
  return err[valueStartIdx..<valueEndIdx]

# Processes the raw error messages to extract useful information
proc formatErrors*(errors: seq[string]): seq[FormattedError] =
  var formattedErrors: seq[FormattedError] = @[]
  
  # Skip empty errors
  if errors.len == 0:
    return formattedErrors
  
  # Check for common error patterns
  for err in errors:
    # Process data type errors
    let dataType = extractDataType(err)
    if dataType.len > 0:
      # Create a more user-friendly error for data types
      var message = "Invalid value for " & dataType
      var suggestion = ""
      
      # Add specific suggestions for common CSS data types
      case dataType
      of "color":
        message = "Invalid color value"
        suggestion = "Use a valid color name like 'red', or a hex code like '#ff0000'"
      of "length", "length-percentage":
        message = "Invalid length value"
        suggestion = "Use a valid measurement like '10px', '2em', or '50%'"
      of "angle":
        message = "Invalid angle value"
        suggestion = "Use a valid angle like '90deg', '0.5turn', or '1rad'"
      of "number":
        message = "Invalid number value"
        suggestion = "Use a plain number without units"
      of "url":
        message = "Invalid URL value"
        suggestion = "Use url('...') with a valid URL"
      else:
        message = "Invalid " & dataType & " value"
        suggestion = "Please check the syntax for " & dataType
      
      formattedErrors.add(FormattedError(message: message, suggestion: suggestion))
      continue
    
    # Check for "Expected keyword/function" errors
    if err.contains("Expected") and err.contains("got"):
      var expectedType = ""
      var expectedValue = ""
      var gotValue = ""
      
      # Extract "Expected X" part
      if err.contains("Expected keyword"):
        expectedType = "keyword"
        let startIdx = err.find("Expected keyword '") + 17
        let endIdx = err.find("'", startIdx)
        if endIdx > startIdx:
          expectedValue = err[startIdx..<endIdx]
      elif err.contains("Expected function"):
        expectedType = "function"
        let startIdx = err.find("Expected function '") + 18
        let endIdx = err.find("'", startIdx)
        if endIdx > startIdx:
          expectedValue = err[startIdx..<endIdx]
      elif err.contains("Expected built-in data type"):
        expectedType = "built-in data type"
        let startIdx = err.find("Expected built-in data type '") + 28
        let endIdx = err.find("'", startIdx)
        if endIdx > startIdx:
          expectedValue = err[startIdx..<endIdx]
      
      # Extract "got X" part
      if err.contains("got '"):
        let startIdx = err.find("got '") + 5
        let endIdx = err.find("'", startIdx)
        if endIdx > startIdx:
          gotValue = err[startIdx..<endIdx]
      
      # Only proceed if we have both expected and got values
      if expectedType.len > 0 and expectedValue.len > 0 and gotValue.len > 0:
        var message = ""
        var suggestion = ""
        
        # Format message based on error type
        if expectedType == "keyword":
          message = "Invalid keyword: '" & gotValue & "'"
          suggestion = "Did you mean to use '" & expectedValue & "'?"
        elif expectedType == "function":
          message = "Invalid function: '" & gotValue & "'"
          suggestion = "Did you mean to use the '" & expectedValue & "' function?"
        elif expectedType == "built-in data type":
          message = "Invalid value for " & expectedValue & ": '" & gotValue & "'"
          
          # Suggestions for common data types
          if expectedValue == "color":
            suggestion = "Use a valid color name like 'red', or a hex code like '#ff0000'"
          elif expectedValue == "length":
            suggestion = "Use a valid length unit (px, em, rem, etc.)"
          elif expectedValue == "percentage":
            suggestion = "Use a percentage value (e.g., '50%')"
          else:
            suggestion = "Please provide a valid " & expectedValue & " value"
        
        # Add formatted error if we created a valid message
        if message.len > 0:
          formattedErrors.add(FormattedError(message: message, suggestion: suggestion))
          continue
    
    # Extra tokens error - just pass through as is
    if err.startsWith("Extra tokens"):
      formattedErrors.add(FormattedError(
        message: "Unexpected additional value in CSS property",
        suggestion: "Remove extra values after the valid portion"
      ))
      continue
    
    # Validation errors that don't fit specific patterns
    if not err.contains("[") and not err.contains("]") and err.len > 0:
      formattedErrors.add(FormattedError(message: err, suggestion: ""))
  
  # If we couldn't extract any specific errors, provide a generic message
  if formattedErrors.len == 0 and errors.len > 0:
    formattedErrors.add(FormattedError(
      message: "Invalid CSS value",
      suggestion: "Please check your syntax"
    ))
  
  # Remove duplicates
  var uniqueErrors: seq[FormattedError] = @[]
  var seenMessages = newSeq[string]()
  
  for err in formattedErrors:
    if not seenMessages.contains(err.message):
      uniqueErrors.add(err)
      seenMessages.add(err.message)
  
  return uniqueErrors

# Format the error output as a user-friendly string
proc formatErrorOutput*(rst: ValidatorResult): string =
  if rst.valid:
    return "Valid: true"
  
  echo rst.errors

  let formattedErrors = formatErrors(rst.errors)
  var output = "Invalid: false\n"
  
  for i, err in formattedErrors:
    output &= "Error " & $(i + 1) & ": " & err.message & "\n"
    if err.suggestion.len > 0:
      output &= "   Suggestion: " & err.suggestion & "\n"
  
  return output

# Use this to replace the output in the isMainModule section
when isMainModule:
  let syntaxStr = "[ normal | small-caps ]"
  let valueStr = "normals"
  
  let result = validateCSSValue(syntaxStr, valueStr)
  echo formatErrorOutput(result)