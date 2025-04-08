import std/[strutils, sequtils, tables, options, unicode]

# Import the token types from the original parser
import syntax_lexer

type
  NodeKind* = enum
    nkFunction,     # Function with parameters
    nkDataType,     # <...> data type
    nkKeyword,      # Literal keywords
    nkChoice,       # A | B | C alternatives (only one)
    nkAndList,      # A && B && C alternatives (all must be present in any order)
    nkOrList,       # A || B || C alternatives (any number in any order)
    nkSequence,     # A B C sequence of nodes
    nkOptional,     # [...]? optional node
    nkZeroOrMore,   # A* zero or more repetitions
    nkOneOrMore,    # A+ one or more repetitions
    nkCommaList,    # A# comma-separated list
    nkSpaceList,    # A+ space-separated list
    nkRequired,     # A! required node
    nkQuantified,   # A{m,n} quantity specified node
    nkValueRange,   # A[min,max] value range
    nkSeparator,    # Special separator like slash (/)
    nkAtRule,       # At-rule (e.g. @media)
    nkRule          # Rule (e.g. something { ... })

  Node* = ref object
    case kind*: NodeKind
    of nkAtRule, nkRule:
      body*: seq[Node]  # Body block for at-rules
    else:
      discard
    value*: string  # For data types, keywords, etc.
    children*: seq[Node]
    case isQuantified*: bool
    of true:
      min*: int
      max*: Option[int]  # None means unlimited
    of false: discard
    case hasValueRange*: bool
    of true:
      minValue*: string
      maxValue*: string
    of false: discard

proc newNode(kind: NodeKind, value: string = ""): Node =
  Node(
    kind: kind,
    value: value,
    children: @[],
    isQuantified: false,
    hasValueRange: false
  )

proc newQuantifiedNode(kind: NodeKind, value: string, min: int, max: Option[int]): Node =
  Node(
    kind: kind,
    value: value,
    children: @[],
    isQuantified: true,
    min: min,
    max: max,
    hasValueRange: false
  )

proc newValueRangedNode(kind: NodeKind, value: string, minValue, maxValue: string): Node =
  Node(
    kind: kind,
    value: value,
    children: @[],
    isQuantified: false,
    hasValueRange: true,
    minValue: minValue,
    maxValue: maxValue
  )

proc newQuantifiedValueRangedNode(kind: NodeKind, value: string, min: int, max: Option[int], minValue, maxValue: string): Node =
  Node(
    kind: kind,
    value: value,
    children: @[],
    isQuantified: true,
    min: min,
    max: max,
    hasValueRange: true,
    minValue: minValue,
    maxValue: maxValue
  )

# Forward declarations
proc processTokensToNodes(tokens: seq[Token], isTopLevel: bool = true, inFunction: bool = false): seq[Node] {.gcsafe.}
proc processToken(token: Token): Node {.gcsafe.}

# Process function parameters based on whether they're comma-separated or space-separated
proc processFunctionParams(tokens: seq[Token]): seq[Node] {.gcsafe.} =
  # Check if this is a comma-separated function or space-separated function
  var hasCommas = false
  for token in tokens:
    if token.kind == tkComma:
      hasCommas = true
      break
  
  if hasCommas:
    # Process as comma-separated parameters
    var params: seq[Node] = @[]
    var currentParam: seq[Node] = @[]
    
    for i in 0..<tokens.len:
      if tokens[i].kind == tkComma:
        # End of current parameter, add it to params list
        if currentParam.len > 0:
          if currentParam.len == 1:
            params.add(currentParam[0])
          else:
            var seqNode = newNode(nkSequence)
            seqNode.children = currentParam
            params.add(seqNode)
          currentParam = @[]
      else:
        # Process token as part of current parameter
        let node = processToken(tokens[i])
        currentParam.add(node)
    
    # Add the last parameter if there is one
    if currentParam.len > 0:
      if currentParam.len == 1:
        params.add(currentParam[0])
      else:
        var seqNode = newNode(nkSequence)
        seqNode.children = currentParam
        params.add(seqNode)
    
    return params
  else:
    # For space-separated parameters, wrap everything in a single sequence
    var seqNode = newNode(nkSequence)
    var nodes: seq[Node] = @[]
    for token in tokens:
      let node = processToken(token)
      nodes.add(node)
    seqNode.children = nodes
    return @[seqNode]  # Return as a single parameter

proc processToken(token: Token): Node {.gcsafe.} =
  case token.kind:
    of tkDataType:
      var dataNode: Node
      if token.isSpecial:
        if token.valueRange.min != "" and token.valueRange.max != "":
          if token.quantity.min != 0 or token.quantity.max.isSome:
            dataNode = newQuantifiedValueRangedNode(
              nkDataType, 
              token.value, 
              token.quantity.min, 
              token.quantity.max,
              token.valueRange.min,
              token.valueRange.max
            )
          else:
            dataNode = newValueRangedNode(
              nkDataType, 
              token.value, 
              token.valueRange.min,
              token.valueRange.max
            )
        else:
          if token.quantity.min != 0 or token.quantity.max.isSome:
            dataNode = newQuantifiedNode(
              nkDataType, 
              token.value, 
              token.quantity.min, 
              token.quantity.max
            )
          else:
            dataNode = newNode(nkDataType, token.value)
      else:
        dataNode = newNode(nkDataType, token.value)
        
      # Apply modifiers if any
      result = dataNode
      # Check for explicit optional modifier, but don't make all data types optional
      var hasOptional = false
      for modifier in token.modifiers:
        if modifier == tkSingleOptional:
          hasOptional = true
          break
      
      if hasOptional:
        var optNode = newNode(nkOptional)
        optNode.children.add(result)
        result = optNode
      
      # Apply other modifiers
      for modifier in token.modifiers:
        if modifier == tkSingleOptional:
          # Already handled
          discard
        else:
          case modifier:
            of tkZeroOrMore:
              var zeroOrMoreNode = newNode(nkZeroOrMore)
              zeroOrMoreNode.children.add(result)
              result = zeroOrMoreNode
            of tkCommaList:
              var commaListNode = newNode(nkCommaList)
              commaListNode.children.add(result)
              result = commaListNode
            of tkSpaceList:
              var spaceListNode = newNode(nkOneOrMore)
              spaceListNode.children.add(result)
              result = spaceListNode
            of tkRequired:
              var requiredNode = newNode(nkRequired)
              requiredNode.children.add(result)
              result = requiredNode
            else:
              discard

    of tkKeyword:
      var keywordNode: Node
      if token.isSpecial and (token.quantity.min != 0 or token.quantity.max.isSome):
        keywordNode = newQuantifiedNode(
          nkKeyword, 
          token.value, 
          token.quantity.min, 
          token.quantity.max
        )
      else:
        keywordNode = newNode(nkKeyword, token.value)
      
      # Apply modifiers if any
      result = keywordNode
      # Check for explicit optional modifier, don't make all keywords optional
      var hasOptional = false
      for modifier in token.modifiers:
        if modifier == tkSingleOptional:
          hasOptional = true
          break
      
      if hasOptional:
        var optNode = newNode(nkOptional)
        optNode.children.add(result)
        result = optNode
      
      # Apply other modifiers
      for modifier in token.modifiers:
        if modifier == tkSingleOptional:
          # Already handled
          discard
        else:
          case modifier:
            of tkZeroOrMore:
              var zeroOrMoreNode = newNode(nkZeroOrMore)
              zeroOrMoreNode.children.add(result)
              result = zeroOrMoreNode
            of tkCommaList:
              var commaListNode = newNode(nkCommaList)
              commaListNode.children.add(result)
              result = commaListNode
            of tkSpaceList:
              var spaceListNode = newNode(nkOneOrMore)
              spaceListNode.children.add(result)
              result = spaceListNode
            of tkRequired:
              var requiredNode = newNode(nkRequired)
              requiredNode.children.add(result)
              result = requiredNode
            else:
              discard

    of tkSlash:
      # Only create a separator node for special separators like slash (/)
      # This will be useful for alpha channel separation
      result = newNode(nkSeparator, "/")  # Directly use "/" instead of token.value

    of tkComma:
      # Commas are handled differently in processFunctionParams
      # This should rarely be hit directly
      result = newNode(nkSeparator, ",")

    of tkOptional:
      # Handle optional group [...]?
      var innerNodes = processTokensToNodes(token.children, false)
      
      # Create a sequence node if there are multiple children
      var contentNode: Node
      if innerNodes.len > 1:
        contentNode = newNode(nkSequence)
        contentNode.children = innerNodes
      elif innerNodes.len == 1:
        contentNode = innerNodes[0]
      else:
        contentNode = newNode(nkSequence)  # Empty sequence
      
      # Create the optional wrapper because the token is explicitly optional (tkOptional)
      var optNode = newNode(nkOptional)
      optNode.children.add(contentNode)
      
      # Handle quantification if present
      if token.isSpecial and (token.quantity.min != 0 or token.quantity.max.isSome):
        var quantNode = newQuantifiedNode(
          nkQuantified, 
          "", 
          token.quantity.min, 
          token.quantity.max
        )
        quantNode.children.add(optNode)
        result = quantNode
      else:
        result = optNode
      
      # Apply other modifiers if any
      for modifier in token.modifiers:
        case modifier:
          of tkSingleOptional:
            # This is redundant for an already optional node, but we'll apply it
            var newOptNode = newNode(nkOptional)
            newOptNode.children.add(result)
            result = newOptNode
          of tkZeroOrMore:
            var zeroOrMoreNode = newNode(nkZeroOrMore)
            zeroOrMoreNode.children.add(result)
            result = zeroOrMoreNode
          of tkCommaList:
            var commaListNode = newNode(nkCommaList)
            commaListNode.children.add(result)
            result = commaListNode
          of tkSpaceList:
            var spaceListNode = newNode(nkOneOrMore)
            spaceListNode.children.add(result)
            result = spaceListNode
          of tkRequired:
            var requiredNode = newNode(nkRequired)
            requiredNode.children.add(result)
            result = requiredNode
          else:
            discard

    of tkGroup:
      # Process the grouped tokens
      var innerNodes = processTokensToNodes(token.children, false)
      
      var contentNode: Node
      if innerNodes.len > 1:
        contentNode = newNode(nkSequence)
        contentNode.children = innerNodes
      elif innerNodes.len == 1:
        contentNode = innerNodes[0]
      else:
        contentNode = newNode(nkSequence)  # Empty sequence
      
      # Important change: For tkGroup, don't automatically make it optional
      # Only make it optional if it has the tkSingleOptional modifier
      var baseNode = contentNode
      
      # First check for tkSingleOptional in modifiers
      var isOptional = false
      for modifier in token.modifiers:
        if modifier == tkSingleOptional:
          isOptional = true
          break
          
      # If it's optional, wrap it in an nkOptional node
      if isOptional:
        var optNode = newNode(nkOptional)
        optNode.children.add(baseNode)
        baseNode = optNode
      
      # Handle quantification if present
      if token.isSpecial and (token.quantity.min != 0 or token.quantity.max.isSome):
        var quantNode = newQuantifiedNode(
          nkQuantified, 
          "", 
          token.quantity.min, 
          token.quantity.max
        )
        quantNode.children.add(baseNode)
        result = quantNode
      else:
        result = baseNode
      
      # Apply other modifiers (except optional which was handled above)
      for modifier in token.modifiers:
        case modifier:
          of tkSingleOptional:
            # Already handled above
            discard
          of tkZeroOrMore:
            var zeroOrMoreNode = newNode(nkZeroOrMore)
            zeroOrMoreNode.children.add(result)
            result = zeroOrMoreNode
          of tkCommaList:
            var commaListNode = newNode(nkCommaList)
            commaListNode.children.add(result)
            result = commaListNode
          of tkSpaceList:
            var spaceListNode = newNode(nkOneOrMore)
            spaceListNode.children.add(result)
            result = spaceListNode
          of tkRequired:
            var requiredNode = newNode(nkRequired)
            requiredNode.children.add(result)
            result = requiredNode
          else:
            discard

    of tkParenGroup:
      # For ParenGroup (function parameters), we process similarly to Group
      var innerNodes = processTokensToNodes(token.children, false, true)
      
      var contentNode: Node
      if innerNodes.len > 1:
        contentNode = newNode(nkSequence)
        contentNode.children = innerNodes
      elif innerNodes.len == 1:
        contentNode = innerNodes[0]
      else:
        contentNode = newNode(nkSequence)  # Empty sequence
      
      # ParenGroups are not optional by default
      var baseNode = contentNode
      
      # Check for tkSingleOptional in modifiers
      var isOptional = false
      for modifier in token.modifiers:
        if modifier == tkSingleOptional:
          isOptional = true
          break
          
      # If it's optional, wrap it in an nkOptional node
      if isOptional:
        var optNode = newNode(nkOptional)
        optNode.children.add(baseNode)
        baseNode = optNode
      
      # Handle quantification if present
      if token.isSpecial and (token.quantity.min != 0 or token.quantity.max.isSome):
        var quantNode = newQuantifiedNode(
          nkQuantified, 
          "", 
          token.quantity.min, 
          token.quantity.max
        )
        quantNode.children.add(baseNode)
        result = quantNode
      else:
        result = baseNode
      
      # Apply other modifiers (except optional which was handled above)
      for modifier in token.modifiers:
        case modifier:
          of tkSingleOptional:
            # Already handled above
            discard
          of tkZeroOrMore:
            var zeroOrMoreNode = newNode(nkZeroOrMore)
            zeroOrMoreNode.children.add(result)
            result = zeroOrMoreNode
          of tkCommaList:
            var commaListNode = newNode(nkCommaList)
            commaListNode.children.add(result)
            result = commaListNode
          of tkSpaceList:
            var spaceListNode = newNode(nkOneOrMore)
            spaceListNode.children.add(result)
            result = spaceListNode
          of tkRequired:
            var requiredNode = newNode(nkRequired)
            requiredNode.children.add(result)
            result = requiredNode
          else:
            discard

    of tkOr:
      # This should be handled at a higher level in processTokensToNodes
      result = newNode(nkChoice)
      
    of tkOrList:
      # This should be handled at a higher level in processTokensToNodes
      result = newNode(nkOrList)

    else:
      # Default fallback for other token types
      result = newNode(nkSequence)

proc processTokensToNodes(tokens: seq[Token], isTopLevel: bool = true, inFunction: bool = false): seq[Node] {.gcsafe.} =
  result = @[]
  if tokens.len == 0:
    return

  # For top-level processing, specifically check for function definitions separated by OR
  if isTopLevel:
    # First look for OR tokens
    var orPositions: seq[int] = @[]
    for i in 0..<tokens.len:
      if tokens[i].kind == tkOr:
        orPositions.add(i)
    
    # If we have OR tokens at the top level, split and process each alternative
    if orPositions.len > 0:
      var choiceNode = newNode(nkChoice)
      var start = 0
      
      # Process each segment between OR tokens
      for pos in orPositions:
        let segment = tokens[start..<pos]
        if segment.len > 0:
          # Check if this segment is a function definition
          if segment.len >= 2 and segment[0].kind == tkKeyword and segment[1].kind == tkParenGroup:
            var funcNode = newNode(nkFunction, segment[0].value)
            var paramNodes = processFunctionParams(segment[1].children)
            funcNode.children = paramNodes
            choiceNode.children.add(funcNode)
          else:
            # Not a function, process normally
            let subNodes = processTokensToNodes(segment, false, inFunction)
            if subNodes.len == 1:
              choiceNode.children.add(subNodes[0])
            else:
              var seqNode = newNode(nkSequence)
              seqNode.children = subNodes
              choiceNode.children.add(seqNode)
        start = pos + 1
      
      # Process the final segment after the last OR
      let finalSegment = tokens[start..<tokens.len]
      if finalSegment.len > 0:
        if finalSegment.len >= 2 and finalSegment[0].kind == tkKeyword and finalSegment[1].kind == tkParenGroup:
          var funcNode = newNode(nkFunction, finalSegment[0].value)
          var paramNodes = processFunctionParams(finalSegment[1].children)
          funcNode.children = paramNodes
          choiceNode.children.add(funcNode)
        else:
          let subNodes = processTokensToNodes(finalSegment, false, inFunction)
          if subNodes.len == 1:
            choiceNode.children.add(subNodes[0])
          else:
            var seqNode = newNode(nkSequence)
            seqNode.children = subNodes
            choiceNode.children.add(seqNode)
      
      result.add(choiceNode)
      return
  
  # The rest of the original function continues as before...
  # 1) Special check for function syntax patterns (e.g. foo(...))
  if tokens.len >= 2 and tokens[0].kind == tkKeyword and tokens[1].kind == tkParenGroup:
    var funcNode = newNode(nkFunction, tokens[0].value)
    var paramNodes = processFunctionParams(tokens[1].children)
    funcNode.children = paramNodes
    result.add(funcNode)
    return

  # check for rules
  if tokens.len > 1 and tokens[tokens.len - 1].kind == tkBodyBlock:
    # Check if it's not an at-rule (which was already handled)
    if tokens[0].kind != tkAtRule:
      var ruleNode = newNode(nkRule, "")
      var selectors = tokens[0..tokens.len - 2]
      var selectorNodes = processTokensToNodes(selectors, false, inFunction)
      if selectorNodes.len == 1:
        ruleNode.children.add(selectorNodes[0])
      else:
        var seqNode = newNode(nkSequence)
        seqNode.children = selectorNodes
        ruleNode.children.add(seqNode)

      # parse bodyblock's children
      var bodyBlockTokens = tokens[tokens.len - 1].children
      var bodyBlockNode = newNode(nkSequence)
      var bodyBlockChildren = processTokensToNodes(bodyBlockTokens, false, inFunction)
      if bodyBlockChildren.len == 1:
        bodyBlockNode.children.add(bodyBlockChildren[0])
      else:
        var seqNode = newNode(nkSequence)
        seqNode.children = bodyBlockChildren
        bodyBlockNode.children.add(seqNode)
      ruleNode.body.add(bodyBlockNode)
      result.add(ruleNode)
      return

  # 1.5) Check for atrule
  if tokens.len > 1 and tokens[0].kind == tkAtRule:
    var atRuleNode = newNode(nkAtRule, tokens[0].value)
    var hasBody = tokens[tokens.len - 1].kind == tkBodyBlock
    var selectors: seq[Token] = @[]
    if hasBody:
      selectors = tokens[1..tokens.len - 2]
    else:
      selectors = tokens[1..tokens.len - 1]
    var selectorNodes = processTokensToNodes(selectors, false, inFunction)
    if selectorNodes.len == 1:
      atRuleNode.children.add(selectorNodes[0])
    else:
      var seqNode = newNode(nkSequence)
      seqNode.children = selectorNodes
      atRuleNode.children.add(seqNode)
    if hasBody:
      # parse bodyblock's children
      var bodyBlockTokens = tokens[tokens.len - 1].children
      var bodyBlockNode = newNode(nkSequence)
      var bodyBlockChildren = processTokensToNodes(bodyBlockTokens, false, inFunction)
      if bodyBlockChildren.len == 1:
        bodyBlockNode.children.add(bodyBlockChildren[0])
      else:
        var seqNode = newNode(nkSequence)
        seqNode.children = bodyBlockChildren
        bodyBlockNode.children.add(seqNode)
      atRuleNode.body.add(bodyBlockNode)
    result.add(atRuleNode)
    return

  # 2) Check for tkOrList (the double-pipe "||")
  var hasOrList = false
  for token in tokens:
    if token.kind == tkOrList:
      hasOrList = true
      break

  if hasOrList:
    # Split on tkOrList
    var orListNode = newNode(nkOrList)
    var currentItem: seq[Token] = @[]
    for t in tokens:
      if t.kind == tkOrList:
        if currentItem.len > 0:
          let subNodes = processTokensToNodes(currentItem, false, inFunction)
          if subNodes.len == 1:
            orListNode.children.add(subNodes[0])
          else:
            var seqN = newNode(nkSequence)
            seqN.children = subNodes
            orListNode.children.add(seqN)
          currentItem = @[]
      else:
        currentItem.add(t)
    # Add the last segment
    if currentItem.len > 0:
      let subNodes = processTokensToNodes(currentItem, false, inFunction)
      if subNodes.len == 1:
        orListNode.children.add(subNodes[0])
      else:
        var seqN = newNode(nkSequence)
        seqN.children = subNodes
        orListNode.children.add(seqN)

    result.add(orListNode)
    return

  # 3) Check for any plain tkOr (the single-pipe "|") at this level
  var hasChoice = false
  for token in tokens:
    if token.kind == tkOr:
      hasChoice = true
      break

  if hasChoice:
    # We create an nkChoice node by splitting on tkOr
    var choiceNode = newNode(nkChoice)
    var currentItem: seq[Token] = @[]
    for t in tokens:
      if t.kind == tkOr:
        if currentItem.len > 0:
          let subNodes = processTokensToNodes(currentItem, false, inFunction)
          if subNodes.len == 1:
            choiceNode.children.add(subNodes[0])
          else:
            var seqN = newNode(nkSequence)
            seqN.children = subNodes
            choiceNode.children.add(seqN)
          currentItem = @[]
      else:
        currentItem.add(t)
    # Add the final segment
    if currentItem.len > 0:
      let subNodes = processTokensToNodes(currentItem, false, inFunction)
      if subNodes.len == 1:
        choiceNode.children.add(subNodes[0])
      else:
        var seqN = newNode(nkSequence)
        seqN.children = subNodes
        choiceNode.children.add(seqN)

    result.add(choiceNode)
    return

  # 4) If there's no OR, check for AND (tkAndList, i.e. "&&")
  var hasAndList = false
  for token in tokens:
    if token.kind == tkAndList:
      hasAndList = true
      break

  if hasAndList:
    # We create an nkAndList node
    var andListNode = newNode(nkAndList)
    var currentItem: seq[Token] = @[]
    for t in tokens:
      if t.kind == tkAndList:
        if currentItem.len > 0:
          let subNodes = processTokensToNodes(currentItem, false, inFunction)
          if subNodes.len == 1:
            andListNode.children.add(subNodes[0])
          else:
            var seqN = newNode(nkSequence)
            seqN.children = subNodes
            andListNode.children.add(seqN)
          currentItem = @[]
      else:
        currentItem.add(t)
    # Add the last segment
    if currentItem.len > 0:
      let subNodes = processTokensToNodes(currentItem, false, inFunction)
      if subNodes.len == 1:
        andListNode.children.add(subNodes[0])
      else:
        var seqN = newNode(nkSequence)
        seqN.children = subNodes
        andListNode.children.add(seqN)

    result.add(andListNode)
    return

  # 5) If no OR or AND, parse tokens in a normal left-to-right sequence.
  var current: seq[Node] = @[]
  var i = 0
  while i < tokens.len:
    # Commas in function calls are handled in processFunctionParams, so skip here
    if inFunction and tokens[i].kind == tkComma:
      i += 1
      continue
    let node = processToken(tokens[i])
    current.add(node)
    i += 1

  if current.len == 0:
    return
  elif current.len == 1:
    result.add(current[0])
  else:
    var seqNode = newNode(nkSequence)
    seqNode.children = current
    result.add(seqNode)


proc tokensToAST*(tokens: seq[Token]): Node {.gcsafe.} =
  # We call processTokensToNodes at top level (isTopLevel = true).
  # It will handle OR first, then AND, whether at top level or nested.
  let nodes = processTokensToNodes(tokens, true)

  # If there's exactly one node, return it; else wrap in nkSequence.
  if nodes.len == 1:
    return nodes[0]
  else:
    var root = newNode(nkSequence)
    root.children = nodes
    return root


# Helper function to simplify the AST by removing unnecessary nodes and restructuring for better traversal
proc simplifyAST*(node: Node): Node =
  # First simplify all children
  for i in 0..<node.children.len:
    node.children[i] = simplifyAST(node.children[i])
  
  case node.kind:
    of nkFunction:
      # For functions, we want to keep the structure clean
      result = node
    
    of nkSequence:
      # If there's only one child, replace sequence with that child
      if node.children.len == 1:
        result = node.children[0]
      # If there are no children, keep an empty sequence
      elif node.children.len == 0:
        result = node
      else:
        # Check for nested sequences and flatten them
        var newChildren: seq[Node] = @[]
        var i = 0
        while i < node.children.len:
          if node.children[i].kind == nkSequence and 
             not node.children[i].isQuantified and 
             not node.children[i].hasValueRange:
            # Flatten nested sequences
            newChildren.add(node.children[i].children)
          elif node.children[i].kind == nkSeparator and 
               node.children[i].value == "/" and
               i + 1 < node.children.len:
            # Handle slash separator specially - combine with next node if possible
            if node.children[i + 1].kind == nkOptional:
              var slashNode = newNode(nkSeparator, "/")
              var combinedNode = newNode(nkSequence)
              combinedNode.children.add(slashNode)
              combinedNode.children.add(node.children[i + 1].children)
              
              var optNode = newNode(nkOptional)
              optNode.children.add(combinedNode)
              newChildren.add(optNode)
              i += 1  # Skip the next node as we've combined it
            else:
              newChildren.add(node.children[i])
          else:
            newChildren.add(node.children[i])
          i += 1
        
        node.children = newChildren
        result = node
    
    of nkChoice:
      # Simplify choice nodes
      if node.children.len == 1:
        # If there's only one alternative, just return it
        result = node.children[0]
      elif node.children.len == 0:
        # Empty choice (shouldn't happen)
        result = node
      else:
        # Keep multiple choices
        result = node
    
    of nkOrList:
      # Simplify OrList nodes
      if node.children.len == 1:
        # If there's only one alternative, just return it
        result = node.children[0]
      elif node.children.len == 0:
        # Empty OrList (shouldn't happen)
        result = node
      else:
        # Keep multiple OrList items
        result = node
    
    of nkOptional:
      # If the optional contains another optional, simplify
      if node.children.len == 1 and node.children[0].kind == nkOptional:
        result = node.children[0]
      # If there are no children, keep an empty optional
      elif node.children.len == 0:
        result = node
      else:
        result = node
    
    of nkSeparator:
      # We want to keep slash separators but remove comma separators
      if node.value == ",":
        # This should not happen with our improved processing, but just in case
        result = node  # Keep it for now, might remove later
      else:
        result = node
    
    else:
      result = node
  
  return result

proc `$`*(node: Node): string =
  case node.kind:
    of nkAtRule:
      result = "@" & node.value
      if node.body.len > 0:
        result &= " {\n" & node.body.mapIt($it).join("\n") & "\n}"
    of nkRule:
      # Similar to AtRule but without the @ symbol
      if node.children.len > 0:
        result = $node.children[0]
      else:
        result = ""
      if node.body.len > 0:
        result &= " {\n" & node.body.mapIt($it).join("\n") & "\n}"
    of nkFunction:
      var params = node.children.mapIt($it).join(", ")
      result = node.value & "(" & params & ")"
    
    of nkDataType:
      result = "<" & node.value & ">"
      if node.hasValueRange:
        result &= "[" & node.minValue & "," & node.maxValue & "]"
      if node.isQuantified:
        result &= "{" & $node.min
        if node.max.isSome:
          if node.max.get != node.min:
            result &= "," & $node.max.get
        else:
          result &= ",∞"
        result &= "}"
    
    of nkKeyword:
      result = node.value
      if node.isQuantified:
        result &= "{" & $node.min
        if node.max.isSome:
          if node.max.get != node.min:
            result &= "," & $node.max.get
        else:
          result &= ",∞"
        result &= "}"
    
    of nkChoice:
      result = node.children.mapIt($it).join(" | ")
      
    of nkOrList:
      result = node.children.mapIt($it).join(" || ")
    
    of nkSequence:
      result = node.children.mapIt($it).join(" ")
    
    of nkOptional:
      if node.children.len == 1:
        result = "[" & $node.children[0] & "]?"
      elif node.children.len > 1:
        result = "[" & node.children.mapIt($it).join(" ") & "]?"
      else:
        result = "[]?" # Empty optional
    
    of nkZeroOrMore:
      if node.children.len == 1:
        result = $node.children[0] & "*"
      else:
        result = "(" & node.children.mapIt($it).join(" ") & ")*"
    
    of nkOneOrMore:
      if node.children.len == 1:
        result = $node.children[0] & "+"
      else:
        result = "(" & node.children.mapIt($it).join(" ") & ")+"
    
    of nkCommaList:
      if node.children.len == 1:
        result = $node.children[0] & "#"
      else:
        result = "(" & node.children.mapIt($it).join(" ") & ")#"
    
    of nkSpaceList:
      if node.children.len == 1:
        result = $node.children[0] & "+"
      else:
        result = "(" & node.children.mapIt($it).join(" ") & ")+"
    
    of nkRequired:
      if node.children.len == 1:
        result = $node.children[0] & "!"
      else:
        result = "(" & node.children.mapIt($it).join(" ") & ")!"
    
    of nkQuantified:
      var innerStr: string
      if node.children.len == 1:
        innerStr = $node.children[0]
      else:
        innerStr = "(" & node.children.mapIt($it).join(" ") & ")"
      
      result = innerStr & "{" & $node.min
      if node.max.isSome:
        if node.max.get != node.min:
          result &= "," & $node.max.get
      else:
        result &= ",∞"
      result &= "}"
    
    of nkValueRange:
      var innerStr: string
      if node.children.len == 1:
        innerStr = $node.children[0]
      else:
        innerStr = "(" & node.children.mapIt($it).join(" ") & ")"
      
      result = innerStr & "[" & node.minValue & "," & node.maxValue & "]"
        
    of nkSeparator:
      result = node.value
    
    of nkAndList:
      result = node.children.mapIt($it).join(" && ")


proc treeRepr*(node: Node, indent = 0): string =
  # Print the AST in a tree-like format
  var nodeInfo = $node.kind
  case node.kind:
    of nkAtRule:
      nodeInfo &= " @" & node.value
      if node.body.len > 0:
        nodeInfo &= " {\n" & node.body.mapIt($it.treeRepr(indent + 2)).join("\n") & "\n}"
    of nkRule:
      # nodeInfo &= ""
      if node.body.len > 0:
        nodeInfo &= " {\n" & node.body.mapIt($it.treeRepr(indent + 2)).join("\n") & "\n}"
    of nkFunction:
      nodeInfo &= "(" & node.value & ")"
    of nkDataType, nkKeyword, nkSeparator:
      nodeInfo &= "(" & node.value & ")"
      if node.hasValueRange:
        nodeInfo &= " Range: [" & node.minValue & "," & node.maxValue & "]"
      if node.isQuantified:
        nodeInfo &= " Quantity: {" & $node.min
        if node.max.isSome:
          nodeInfo &= "," & $node.max.get
        else:
          nodeInfo &= ",∞"
        nodeInfo &= "}"
    of nkQuantified:
      nodeInfo &= " {" & $node.min
      if node.max.isSome:
        nodeInfo &= "," & $node.max.get
      else:
        nodeInfo &= ",∞"
      nodeInfo &= "}"
    of nkValueRange:
      nodeInfo &= " [" & node.minValue & "," & node.maxValue & "]"
    of nkAndList:
      nodeInfo &= " (All)"
    else:
      discard
  
  result = " ".repeat(indent) & nodeInfo & "\n"
  for child in node.children:
    result &= child.treeRepr(indent + 2)

proc parseSyntax*(syntaxStr: string): Node {.gcsafe.} =
  let tokens = tokenizeSyntax(syntaxStr)

  for i, token in tokens:
    if token.kind == tkAtRule and i != 0:
      # If we have an at-rule, it should be the first token
      raise newException(ValueError, "At-rule must be the first token in the syntax string.")
    if token.kind == tkBodyBlock:
      if i != tokens.len - 1:
        # If we have a body block, it should be the last token
        raise newException(ValueError, "Body block must be the last token in the syntax string.")
      # elif tokens[0].kind != tkAtRule:
      #   # If we have a body block, it should be preceded by an at-rule
      #   raise newException(ValueError, "Body block must be preceded by an at-rule.")

  let ast = tokensToAST(tokens)
  return simplifyAST(ast)


# Test function for trying out the AST conversion
proc test*(syntaxStr: string) =
  let ast = parseSyntax(syntaxStr)
  echo "Original syntax: ", syntaxStr
  echo "\nAST structure:"
  echo ast.treeRepr
  # echo "\nReconstructed syntax:"
  # echo $ast


when isMainModule:
  # Test the AST converter with sample syntax

  # [ normal | <baseline-position> | <content-distribution> | <overflow-position>? <content-position> ]#
  # [ <mask-reference> || <position> [ / <bg-size> ]? || <repeat-style> || [ <visual-box> | border | padding | content | text ] || [ <visual-box> | border | padding | content ] ]#
  # <outline-radius>{1,4} [ / <outline-radius>{1,4} ]?
  # snapInterval( <length-percentage>, <length-percentage> ) | snapList( <length-percentage># )

  # let syntax1 = "hwb( [<hue> | none] [<percentage> | none] [<percentage> | none] [ / [<alpha-value> | none] ]?)"
  test("[ [ left | center | right | top | bottom | <length-percentage> ] | [ left | center | right | <length-percentage> ] [ top | center | bottom | <length-percentage> ] | [ center | [ left | right ] <length-percentage>? ] && [ center | [ top | bottom ] <length-percentage>? ] ]")
  test("rgba( <percentage>{3} [ / <alpha-value> ]? ) | rgba( <number>{3} [ / <alpha-value> ]? ) | rgba( <percentage>#{3} , <alpha-value>? ) | rgba( <number>#{3} , <alpha-value>? )")
  
  test("@font-feature-values <family-name># {\n  <feature-value-block-list>\n}")
  test("@media <media-query> {\n  <rule-list>\n}")

  test("<keyframe-selector># {\n  <declaration-list>\n}")
  # echo "\n--------------------------\n"
  
  # let syntax2 = "<color> | <image># | <url>"
  # test(syntax2)
  
  # echo "\n--------------------------\n"
  
  # let syntax3 = "rgb( [<percentage> | <number>]{3} [ / [<alpha-value>] ]? )"
  # test(syntax3)

  # echo "\n--------------------------\n"
  
  # let syntax4 = "env( <custom-ident> something , <declaration-value>? )"
  # test(syntax4)
  
  # echo "\n--------------------------\n"
  
  # let syntax5 = "hsl( <hue> <percentage> <percentage> [ / <alpha-value> ]? , akeyword ) | hsl( <hue> <something-else>, <percentage>, <percentage>, <alpha-value>? )"
  # test(syntax5)
  
  # echo "\n--------------------------\n"
  
  # let syntax6 = "normal | light | dark | <palette-identifier> | <palette-mix()>"
  # test(syntax6)