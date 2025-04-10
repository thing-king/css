import strutils, os, times

import ../src/css
import ../src/css/analyzer/value_parser

import pkg/colors

const SHOW_ERRORS = false
const MAX_ERRORS = 10

proc testFile(path: string) =
  if not fileExists(path):
    raise newException(Exception, "File not found: " & path)
  let content = readFile(path)

  echo "\nTesting: " & path
  let startTime = getTime()
  let tokens = tokenizeValueFast(content)
  echo "Tokenized in: " & $(getTime() - startTime)

  var count = 00
  var errorCount = 0
  
  let startValidateTime = getTime()
  let validation = validateCSS(tokens, allowProperties = false, allowRules = true)
  echo "Validated in: " & $(getTime() - startValidateTime)
  for error in validation.errors:
    if SHOW_ERRORS:
      if errorCount >= MAX_ERRORS:
        echo "\nMax errors reached.".red
        break
    count.inc
    errorCount.inc()
    if SHOW_ERRORS:
      echo "  Errors: ".red
      for error in validation.errors:
        if error.message.contains("Invalid property name"):
          echo "    - " & error.message.bgRed
        else:
          echo "    - " & error.message

  echo "Total error count: " & $count
  if SHOW_ERRORS:
    echo "Error count: " & $errorCount & " / " & $MAX_ERRORS & " max"
  
  echo "Finished in: " & $(getTime() - startTime)



when isMainModule:
  if paramCount() != 1:
    echo "Usage: css <file.css>"
    quit(1)
  let filePath = paramStr(1)
  if not fileExists(filePath):
    echo "File not found: " & filePath
    quit(1)
  echo "Testing..."
  testFile(filePath)

  # testFile("./tests/data/bootstrap.css")
  # testSingle("background-color", "rgba(1,2,3 / 0.5)")
  # testFile("./tests/data/bootstrap-utilities.css")
  # testFile("./tests/data/bootstrap-reboot.css")
  # testFile("./tests/data/bootstrap-grid.css")

  # testFile("./tests/data/foundation.css")