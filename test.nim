import macros

type
  Kind = enum
    kA, kB
  ACaseType = object
    case kind*: Kind
    of kA:
      a*: int
    of kB:
      b*: int

macro test(): untyped =
  let a = ACaseType(kind: kA, a: 1)
  
  # Convert to string literal and parse
  result = parseExpr(a.repr)

# let val = test()
# echo val
let val = test()
echo val