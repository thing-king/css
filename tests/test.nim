import strutils, os

import ../src/css

import pkg/colors

const ONLY_SHOW_ERRORS = true
const MAX_ERRORS = 30

proc testFile(path: string) =
  if not fileExists(path):
    raise newException(Exception, "File not found: " & path)
  let content = readFile(path)

  var errorCount = 0
  for line in content.splitLines():
    let stripped = line.strip()
    if not stripped.startsWith("--") and stripped.contains(":"):
      let splits = stripped.split(":")
      if splits.len == 2:
        let propName = splits[0]
        let propValue = splits[1].strip()
        if propName.len > 2 and not propName.contains(" ") and not propValue.endsWith("{"):
          let validation = isValidPropertyValue(propName, propValue)
          
          if ONLY_SHOW_ERRORS and validation.valid:
            continue
          echo "Testing: `" & propName & "`: `" & propValue & "`"
          if validation.valid:
            echo "  OK".green
          else:
            errorCount.inc()
            echo "  Errors: ".red
            for error in validation.errors:
              echo "    - " & error

          if errorCount >= MAX_ERRORS:
            echo "\nMax errors reached.".red
            break


when isMainModule:
  testFile("./tests/data/bootstrap.css")