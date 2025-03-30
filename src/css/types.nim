type
  InvalidCSSValue* = object of ValueError
  
  ValidatorResult* = object
    valid*: bool
    errors*: seq[string]

  MatchResult* = object
    success*: bool
    index*: int
    errors*: seq[string]