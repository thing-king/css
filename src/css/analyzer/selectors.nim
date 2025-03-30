import std/[tables, strutils, sequtils, strformat]
import validator, imports

const DEBUG = true

proc logMsg(msg: string) =
  if DEBUG:
    echo "[DEBUG] ", msg

const pseudos = block:
  var temp = imports.selectors

  const builtins = @["Type selectors", "Class selectors", "ID selectors", "Universal selectors", "Attribute selectors", "Selector list", "Next-sibling combinator", "Subsequent-sibling combinator", "Child combinator", "Descendant combinator", "Column combinator", "Pseudo-classes", "Pseudo-elements"]
  for builtin in builtins:
    if not temp.hasKey(builtin):
      raise newException(ValueError, "Missing builtin selector: " & builtin)
    temp.del(builtin)

  temp

type
  SelectorType* = enum
    stElement,     # e.g. "div"
    stClass,       # e.g. ".class-name"
    stId,          # e.g. "#id-name"
    stUniversal,   # e.g. "*"
    stCombinator,  # e.g. ">", "+", "~", " ", "||"
    stPseudo,      # e.g. ":hover", "::before"
    stAttribute,   # e.g. "[attr=value]"
    stGroup,       # e.g. "," (for selector lists)
    stUnexpected   # For unexpected/invalid characters

  SelectorNode* = ref object
    case kind*: SelectorType
    of stElement:
      element*: string
    of stClass:
      className*: string
    of stId:
      idName*: string
    of stUniversal:
      discard
    of stCombinator:
      combinator*: string
    of stPseudo:
      pseudoName*: string
      pseudoValue*: string
    of stAttribute:
      attributeName*: string
      attributeOp*: string
      attributeValue*: string
    of stGroup:
      discard
    of stUnexpected:
      unexpectedChar*: string  # Changed to string to handle multiple characters
      position*: int
    
  Selector* = seq[SelectorNode]

  ParserContext = object
    input: string
    pos: int
    len: int

proc treeRepr*(node: SelectorNode, indent: int = 0): string =
  let indentStr = repeat("  ", indent)
  result = indentStr
  
  case node.kind:
    of stElement:
      result &= fmt"Element({node.element})"
    of stClass:
      result &= fmt"Class({node.className})"
    of stId:
      result &= fmt"ID({node.idName})"
    of stUniversal:
      result &= "Universal*"
    of stCombinator:
      result &= fmt"Combinator('{node.combinator}')"
    of stPseudo:
      if node.pseudoValue.len > 0:
        result &= fmt"Pseudo({node.pseudoName}({node.pseudoValue}))"
      else:
        result &= fmt"Pseudo({node.pseudoName})"
    of stAttribute:
      if node.attributeOp.len > 0:
        result &= fmt"Attribute([{node.attributeName}{node.attributeOp}{node.attributeValue}])"
      else:
        result &= fmt"Attribute([{node.attributeName}])"
    of stGroup:
      result &= "Group: ,"
    of stUnexpected:
      result &= fmt"Unexpected('{node.unexpectedChar}' at position {node.position})"

proc treeRepr*(selector: Selector, indent: int = 0): string =
  result = ""
  for i, node in selector:
    result &= treeRepr(node, indent)
    if i < selector.len - 1:
      result &= "\n"

proc `or`(a: SelectorNode, b: SelectorNode): SelectorNode =
  if a != nil:
    return a
  return b

proc peek(ctx: ParserContext): char =
  if ctx.pos < ctx.len:
    return ctx.input[ctx.pos]
  return '\0'

proc peekAhead(ctx: ParserContext, n: int): char =
  if ctx.pos + n < ctx.len:
    return ctx.input[ctx.pos + n]
  return '\0'

proc next(ctx: var ParserContext): char =
  if ctx.pos < ctx.len:
    result = ctx.input[ctx.pos]
    ctx.pos += 1
  else:
    result = '\0'

proc skipWhitespace(ctx: var ParserContext) =
  while ctx.pos < ctx.len and ctx.input[ctx.pos] in {' ', '\t', '\n', '\r'}:
    ctx.pos += 1

proc isNameChar(c: char): bool =
  return c in {'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '\\'}

proc isNameStart(c: char): bool =
  return c in {'a'..'z', 'A'..'Z', '_', '-', '\\'}

proc parseUnexpected(ctx: var ParserContext): SelectorNode =
  if ctx.pos < ctx.len:
    let position = ctx.pos
    var chars = $ctx.next()
    
    # For identifiers that appear in unexpected positions
    if isNameStart(chars[0]):
      # Consume the rest of this identifier
      while ctx.pos < ctx.len and isNameChar(ctx.peek()):
        chars &= $ctx.next()
      
      logMsg(fmt"Encountered unexpected identifier: '{chars}' at position {position}")
    else:
      logMsg(fmt"Encountered unexpected character: '{chars}' at position {position}")
    
    return SelectorNode(kind: stUnexpected, unexpectedChar: chars, position: position)
  
  return nil

proc parseIdentifier(ctx: var ParserContext): string =
  var start = ctx.pos
  
  # Handle first character of identifier
  if ctx.pos < ctx.len and isNameStart(ctx.peek()):
    discard ctx.next()
  else:
    return ""
  
  # Handle rest of identifier
  while ctx.pos < ctx.len and isNameChar(ctx.peek()):
    discard ctx.next()
  
  return ctx.input[start..<ctx.pos]

proc parseElement(ctx: var ParserContext): SelectorNode =
  let startPos = ctx.pos
  let element = parseIdentifier(ctx)
  if element.len > 0:
    logMsg(fmt"Parsed element: {element}")
    return SelectorNode(kind: stElement, element: element)
  return nil

proc parseClass(ctx: var ParserContext): SelectorNode =
  if ctx.peek() == '.':
    let startPos = ctx.pos
    discard ctx.next() # Skip '.'
    
    # Check for whitespace after the '.'
    let originalPos = ctx.pos
    skipWhitespace(ctx)
    
    # If we skipped any whitespace, this is an invalid class selector
    if ctx.pos != originalPos:
      # Reset to the start
      ctx.pos = startPos
      # Return as unexpected
      return SelectorNode(kind: stUnexpected, unexpectedChar: ". (class with whitespace)", position: startPos)
    
    let className = parseIdentifier(ctx)
    if className.len > 0:
      logMsg(fmt"Parsed class: {className}")
      return SelectorNode(kind: stClass, className: className)
    
    # If we didn't find a valid class name, treat this as unexpected
    ctx.pos = startPos
    return SelectorNode(kind: stUnexpected, unexpectedChar: ".", position: startPos)
  
  return nil

proc parseId(ctx: var ParserContext): SelectorNode =
  if ctx.peek() == '#':
    let startPos = ctx.pos
    discard ctx.next() # Skip '#'
    
    # Check for whitespace after the '#'
    let originalPos = ctx.pos
    skipWhitespace(ctx)
    
    # If we skipped any whitespace, this is an invalid ID selector
    if ctx.pos != originalPos:
      # Reset to the start
      ctx.pos = startPos
      # Return as unexpected
      return SelectorNode(kind: stUnexpected, unexpectedChar: "# (ID with whitespace)", position: startPos)
    
    let idName = parseIdentifier(ctx)
    if idName.len > 0:
      logMsg(fmt"Parsed id: {idName}")
      return SelectorNode(kind: stId, idName: idName)
    
    # If we didn't find a valid ID name, treat this as unexpected
    ctx.pos = startPos
    return SelectorNode(kind: stUnexpected, unexpectedChar: "#", position: startPos)
  
  return nil

proc parseUniversal(ctx: var ParserContext): SelectorNode =
  if ctx.peek() == '*':
    discard ctx.next() # Skip '*'
    logMsg("Parsed universal selector")
    return SelectorNode(kind: stUniversal)
  return nil

# The main issue is with how combinators are detected, especially the descendant combinator (space)
# Here's the fix for the parseCombinator function that will correctly detect whitespace as a combinator

proc parseCombinator(ctx: var ParserContext): SelectorNode =
  let startPos = ctx.pos
  
  # If we're at the end, no combinator
  if ctx.pos >= ctx.len:
    return nil
  
  # Handle explicit combinators first
  case ctx.peek()
  of '>':
    discard ctx.next()
    logMsg("Parsed child combinator '>'")
    return SelectorNode(kind: stCombinator, combinator: ">")
  of '+':
    discard ctx.next()
    logMsg("Parsed next-sibling combinator '+'")
    return SelectorNode(kind: stCombinator, combinator: "+")
  of '~':
    discard ctx.next()
    logMsg("Parsed subsequent-sibling combinator '~'")
    return SelectorNode(kind: stCombinator, combinator: "~")
  of '|':
    if ctx.pos + 1 < ctx.len and ctx.input[ctx.pos + 1] == '|':
      discard ctx.next() # Skip first '|'
      discard ctx.next() # Skip second '|'
      logMsg("Parsed column combinator '||'")
      return SelectorNode(kind: stCombinator, combinator: "||")
  else:
    discard
  
  # Now check for whitespace combinator (the main issue) 
  # Important: Don't reset position here!
  if ctx.peek() in {' ', '\t', '\n', '\r'}:
    # Skip all whitespace
    let beforePos = ctx.pos
    skipWhitespace(ctx)
    
    # If we skipped some whitespace and there's something valid next, it's a descendant combinator
    if ctx.pos > beforePos and ctx.pos < ctx.len and 
       (isNameStart(ctx.peek()) or ctx.peek() in {'.', '#', '*', '[', ':'}):
      logMsg("Parsed descendant combinator (whitespace)")
      return SelectorNode(kind: stCombinator, combinator: " ")
  
  # If we get here, no combinator was found
  ctx.pos = startPos
  return nil

proc parsePseudoValue(ctx: var ParserContext): string =
  if ctx.peek() != '(':
    return ""
  
  discard ctx.next() # Skip '('
  var start = ctx.pos
  var nesting = 1
  
  while ctx.pos < ctx.len and nesting > 0:
    case ctx.input[ctx.pos]
    of '(':
      nesting += 1
    of ')':
      nesting -= 1
    else:
      discard
    
    if nesting > 0:
      ctx.pos += 1
  
  if nesting != 0:
    # Unbalanced parentheses
    ctx.pos = start
    return ""
  
  let value = ctx.input[start..<ctx.pos]
  discard ctx.next() # Skip ')'
  return value

proc parsePseudo(ctx: var ParserContext): SelectorNode =
  let start = ctx.pos
  
  if ctx.peek() == ':':
    discard ctx.next() # Skip first ':'
    
    var isDoubleColon = false
    if ctx.peek() == ':':
      isDoubleColon = true
      discard ctx.next() # Skip second ':'
    
    let name = parseIdentifier(ctx)
    if name.len == 0:
      ctx.pos = start
      return SelectorNode(kind: stUnexpected, unexpectedChar: if isDoubleColon: "::" else: ":", position: start)
    
    let pseudoName = (if isDoubleColon: "::" else: ":") & name
    var pseudoValue = ""
    
    if ctx.peek() == '(':
      pseudoValue = parsePseudoValue(ctx)
      if pseudoValue == "":
        # If we failed to parse the pseudo value, mark as unexpected
        return SelectorNode(kind: stUnexpected, unexpectedChar: pseudoName & "(", position: start)
    
    logMsg(fmt"Parsed pseudo: {pseudoName}" & 
           (if pseudoValue.len > 0: fmt"({pseudoValue})" else: ""))
    
    return SelectorNode(kind: stPseudo, pseudoName: pseudoName, pseudoValue: pseudoValue)
  
  return nil

proc parseAttribute(ctx: var ParserContext): SelectorNode =
  if ctx.peek() != '[':
    return nil
  
  let start = ctx.pos
  discard ctx.next() # Skip '['
  
  skipWhitespace(ctx)
  let attrName = parseIdentifier(ctx)
  if attrName.len == 0:
    # If no attribute name was found, this is unexpected
    ctx.pos = start
    return SelectorNode(kind: stUnexpected, unexpectedChar: "[", position: start)
  
  skipWhitespace(ctx)
  var op = ""
  var value = ""
  
  # Check for operator and value
  if ctx.peek() in {'=', '~', '|', '^', '$', '*'}:
    let opChar = ctx.next()
    if opChar == '=' or (ctx.peek() == '=' and (opChar in {'~', '|', '^', '$', '*'})):
      if opChar != '=':
        op = $opChar & "="
        discard ctx.next() # Skip '='
      else:
        op = "="
      
      skipWhitespace(ctx)
      
      # Parse attribute value (can be quoted or unquoted)
      if ctx.peek() in {'"', '\''}:
        let quote = ctx.next()
        let startValue = ctx.pos
        
        while ctx.pos < ctx.len and ctx.input[ctx.pos] != quote:
          ctx.pos += 1
        
        if ctx.pos >= ctx.len:
          # Unterminated quote
          ctx.pos = start
          return SelectorNode(kind: stUnexpected, unexpectedChar: "[" & attrName & op, position: start)
        
        value = ctx.input[startValue..<ctx.pos]
        discard ctx.next() # Skip closing quote
      else:
        let startValue = ctx.pos
        
        while ctx.pos < ctx.len and ctx.input[ctx.pos] notin {']', ' ', '\t', '\n', '\r'}:
          ctx.pos += 1
        
        value = ctx.input[startValue..<ctx.pos]
    else:
      # Invalid operator
      ctx.pos = start
      return SelectorNode(kind: stUnexpected, unexpectedChar: "[" & attrName & opChar, position: start)
  
  skipWhitespace(ctx)
  
  if ctx.peek() != ']':
    # Missing closing bracket
    ctx.pos = start
    return SelectorNode(kind: stUnexpected, unexpectedChar: "[" & attrName & op & value, position: start)
  
  discard ctx.next() # Skip ']'
  
  logMsg(fmt"Parsed attribute: [{attrName}{op}{value}]")
  return SelectorNode(kind: stAttribute, attributeName: attrName, attributeOp: op, attributeValue: value)

proc parseSimpleSelector(ctx: var ParserContext): seq[SelectorNode] =
  result = @[]
  let startPos = ctx.pos
  
  # First try to parse element or universal selector
  let elementOrUniversal = parseElement(ctx) or parseUniversal(ctx)
  if elementOrUniversal != nil:
    result.add(elementOrUniversal)
  
  # Parse additional simple selectors (classes, IDs, pseudo-classes, attributes)
  var lastPos = -1
  while ctx.pos < ctx.len and lastPos != ctx.pos:
    lastPos = ctx.pos
    
    if ctx.peek() == '.':
      let classNode = parseClass(ctx)
      if classNode != nil:
        result.add(classNode)
    elif ctx.peek() == '#':
      let idNode = parseId(ctx)
      if idNode != nil:
        result.add(idNode)
    elif ctx.peek() == ':':
      let pseudoNode = parsePseudo(ctx)
      if pseudoNode != nil:
        result.add(pseudoNode)
    elif ctx.peek() == '[':
      let attrNode = parseAttribute(ctx)
      if attrNode != nil:
        result.add(attrNode)
    else:
      break
  
  # If we didn't make any progress and we're not at a known delimiter, this is unexpected
  if result.len == 0 and ctx.pos < ctx.len and ctx.peek() notin {' ', '\t', '\n', '\r', ',', '>', '+', '~', '|'}:
    let unexpectedNode = parseUnexpected(ctx)
    if unexpectedNode != nil:
      result.add(unexpectedNode)
  
  return result

proc parseSelector*(input: string): Selector =
  ## Parses a CSS selector string into a sequence of SelectorNode objects
  logMsg(fmt"Parsing selector: '{input}'")
  
  var ctx = ParserContext(input: input, pos: 0, len: input.len)
  
  # return result
  result = @[]
  
  skipWhitespace(ctx)

  # Special case for empty input
  if ctx.pos >= ctx.len:
    return result

  while ctx.pos < ctx.len:
    let beforePos = ctx.pos
    
    # Parse simple selector sequence
    let simpleSelectors = parseSimpleSelector(ctx)
    if simpleSelectors.len > 0:
      for node in simpleSelectors:
        result.add(node)
    
    # Check for a combinator
    let combinator = parseCombinator(ctx)
    if combinator != nil:
      result.add(combinator)
    elif ctx.pos < ctx.len and ctx.peek() == ',':
      # Handle selector group (comma-separated list)
      discard ctx.next() # Skip ','
      skipWhitespace(ctx)
      logMsg("Parsed group separator ','")
      result.add(SelectorNode(kind: stGroup))
    else:
      # If we're at a non-whitespace position and haven't recognized the character,
      # treat it as unexpected
      if ctx.pos < ctx.len and ctx.peek() notin {' ', '\t', '\n', '\r'}:
        let unexpectedNode = parseUnexpected(ctx)
        if unexpectedNode != nil:
          result.add(unexpectedNode)
      else:
        # Just whitespace at the end or between parts
        skipWhitespace(ctx)
    
    # If we've made no progress, that's an infinite loop risk
    if ctx.pos == beforePos:
      ctx.pos += 1  # Force advancement
  
  # Post-process to handle descendant relationships that weren't explicitly identified
  var preprocessed = result
  result = @[]
  
  var i = 0
  while i < preprocessed.len:
    # First add the current node
    result.add(preprocessed[i])
    
    # Check if we need to inject a combinator
    if i < preprocessed.len - 1:
      let current = preprocessed[i]
      let next = preprocessed[i + 1]
      
      # If the current node is a valid selector part and the next one is too, and there's no
      # explicit combinator, then insert a descendant combinator
      if current.kind in {stElement, stClass, stId, stUniversal, stAttribute, stPseudo} and
         next.kind in {stElement, stClass, stId, stUniversal, stAttribute, stPseudo} and
         (i == 0 or preprocessed[i-1].kind != stCombinator):
        # Insert a descendant combinator
        result.add(SelectorNode(kind: stCombinator, combinator: " "))
        logMsg("Inserted implicit descendant combinator")
    
    i += 1

  logMsg("Parsing complete")
  logMsg("Selector tree:\n" & treeRepr(result))
  
  return result

proc validateSelector*(input: string): ValidatorResult =
  ## Validates a CSS selector string and returns a ValidatorResult
  logMsg(fmt"Validating selector: '{input}'")
  
  var errors: seq[string] = @[]
  
  try:
    let parsed = parseSelector(input)
    
    if parsed.len == 0:
      let msg = "Empty selector or parsing failed"
      logMsg(msg)
      errors.add(msg)
      return ValidatorResult(valid: false, errors: errors)
    
    # Check for unexpected nodes first
    for i, node in parsed:
      if node.kind == stUnexpected:
        let msg = fmt"Unexpected syntax: '{node.unexpectedChar}' at position {node.position}"
        logMsg(msg)
        errors.add(msg)
        return ValidatorResult(valid: false, errors: errors)
    
    # Check for unmatched combinators
    var i = 0
    while i < parsed.len:
      if parsed[i].kind == stCombinator:
        if i == 0 or i == parsed.len - 1 or 
           (i + 1 < parsed.len and parsed[i + 1].kind == stCombinator) or
           (i + 1 < parsed.len and parsed[i + 1].kind == stGroup):
          let msg = fmt"Combinator '{parsed[i].combinator}' at position {i} is misplaced"
          logMsg(msg)
          errors.add(msg)
          return ValidatorResult(valid: false, errors: errors)
      
      if parsed[i].kind == stGroup and i + 1 < parsed.len and parsed[i + 1].kind == stCombinator:
        let msg = fmt"Combinator cannot follow a group separator at position {i}"
        logMsg(msg)
        errors.add(msg)
        return ValidatorResult(valid: false, errors: errors)

      # Validate pseudo syntax
      if parsed[i].kind == stPseudo:
        if parsed[i].pseudoValue.len > 0:
          let pseudoName = parsed[i].pseudoName
          let pseudoValue = parsed[i].pseudoValue
          
          # Check if this pseudo-element has a specific syntax to validate
          if pseudoName & "()" in pseudos:
            let syntax = pseudos[pseudoName & "()"].syntax
            let pseudoNameWithoutColon = pseudoName.strip(chars = {':'})
            
            # Validate using the validator
            let cleanValue = pseudoValue.strip()
            let validationResult = validator.validate(
              syntax.replace(pseudoName & "(", pseudoNameWithoutColon & "("), 
              pseudoNameWithoutColon & "(" & cleanValue & ")"
            )

            if not validationResult.valid:
              let msg = fmt"Invalid pseudo syntax for {pseudoName}({pseudoValue})"
              logMsg(msg)
              for err in validationResult.errors:
                let errorMsg = fmt"  - {err}"
                logMsg(errorMsg)
                errors.add(errorMsg)
              return ValidatorResult(valid: false, errors: errors)
          else:
            let msg = fmt"Unknown pseudo function: {parsed[i].pseudoName}"
            logMsg(msg)
            errors.add(msg)
            return ValidatorResult(valid: false, errors: errors)
        else:
          if not pseudos.hasKey(parsed[i].pseudoName):
            let msg = fmt"Unknown pseudo: {parsed[i].pseudoName}"
            logMsg(msg)
            errors.add(msg)
            return ValidatorResult(valid: false, errors: errors)
      
      i += 1
    
    logMsg("Validation successful")
    return ValidatorResult(valid: true, errors: @[])
  except Exception as e:
    let msg = "Error parsing selector: " & e.msg
    logMsg(msg)
    errors.add(msg)
    return ValidatorResult(valid: false, errors: errors)

# Examples of usage:
when isMainModule:
  # Example 1: Parse a simple selector with element after ID
  let selector1 = "div > p"
  echo "Parsing: ", selector1
  let parsed1 = parseSelector(selector1)
  echo "Tree representation:\n", treeRepr(parsed1)
  
  echo "Validation: ", validateSelector(selector1)
  
  # # Example 2: Parse a selector with unexpected character
  # let selector2 = "div.container @ p.text:dir(ltr)"
  # echo "Parsing: ", selector2
  # let parsed2 = parseSelector(selector2)
  # echo "Tree representation:\n", treeRepr(parsed2)
  
  # echo "Validation: ", validateSelector(selector2)
  
  # # Example 3: Parse a selector with functional pseudo-classes
  # let selector3 = "p:dir(ltr)"
  # echo "Parsing: ", selector3
  # let parsed3 = parseSelector(selector3)
  # echo "Tree representation:\n", treeRepr(parsed3)
  
  # echo "Validation: ", validateSelector(selector3)