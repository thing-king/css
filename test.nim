import strutils

var vv = "test;"
if vv.endsWith(";"):
  vv = vv[0..^2]

echo vv