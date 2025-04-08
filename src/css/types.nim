type
  InvalidCSSValue* = object of ValueError

  Error* = object
    message*: string
    line*: int
    column*: int

  ValidatorResult* = object
    valid*: bool
    errors*: seq[Error]

  MatchResult* = object
    success*: bool
    index*: int
    errors*: seq[string]