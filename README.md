# css
Blazing fast MDN-typed CSS validator (**linter**) with minimally hacked non-string DSL.


## Features
- parses MDN syntax, parses css
- validates parsed syntax against css
- minimally hacked non-string dsl
- typed styles object with assignment validation


### Supported
- [X] Properties
- [X] AtRules
- [X] Rules
- [ ] Rule selectors (.class, tag, etc)

### Coming soon
- [ ] Userfriendly errors
- [ ] Performance rewrite
- [ ] Plugins
- [ ] Dynamic context awareness  (i.e. track variables)

## Written DSL
See [web](https://github.com/thing-king/web)
```nim
let doc = css:
  !thisIsAClass:
    color: red

  !thisIsAClass[hover, active]:
    opacity: 0.6
  
  [root]:
    --some-thing: 50.px
    --another-thing: {cvar(--some-thing), 20.px}

echo $doc # ".thisIsAClass { color: red } .thisIsAClass:hover:active { opacity: 0.6 } :root { --some-thing: 50px; --another-thing: var(--some-thing), 20px }"
```
```nim
var styles = newStyles()
styles.add:
  color: red
  backgroundColor: blue

  !aClass:  # this throws an error
    margin: 0
```

## Individual Validation
```nim
import pkg/css

# Validate property names
echo validatePropertyName("not valid!").valid                      # false

# Validate property values against a name
echo validatePropertyValue("background-color", "magenta").valid    # true
echo validatePropertyValue("backgsdound-color", "magenta").valid   # false
echo validatePropertyValue("backgsdound-color", "magenta").errors  # @[ "backgsdound-color is not a valid property name" ]
echo validatePropertyValue("margin", "20").errors                  # @[ "Expected length, got integer" ]

# Directly access MDN CSS data
echo functions["abs()"].status                                    # "standard"
echo properties["flex-direction"].inherited                       # false
echo syntaxes["frequency-percentage"].syntax                      # "<frequency> | <percentage>"
```

## Generic Validation
Validate generic css-strings
```nim
echo validateCSS("""
@keyframes 'test' {
  from {
    color: red;
  }
}

asdasd

test: 5px
""", allowProperties = false,  # allow properties are root level
     allowRules      = true    # allow rules
)

# (valid: false, errors: @[
#   (message: "Invalid token kind: vtkIdent", line: 7, column: 1),
#   (message: "Property not allowed at root level", line: 9, column: 1)
# ])
```

## Styles Object
`Styles` is a typed object, assignment is validated at compile-time if static, or run-time if dynamic.
```nim
import pkg/css

var style = Styles()

style.backgroundColor = "orange"
echo style.backgroundColor # works

# compile-time values validated at compile-time
style.objectFit = "red" # throws an error
echo style.objectFit

var val = "test"
style.objectFit = val # no error until runtime

# inject values with ``
var red = "red"
style.color `red`
style.border 1.px solid `red`
style.border "1px solid " & red
```
```
orange
/home/savant/css/src/css.nim(101) css
/home/savant/css/src/css.nim(87) objectFit=
Error: unhandled exception: Invalid value for object-fit: 
None of the alternatives matched [InvalidCSSValue]
Error: execution of an external program failed: '/home/savant/css/bin/css'
```

## Performance

### thing-king/css
```
savant@savantpc:~/css$ time ./bin/test ./src/css/analyzer/bootstrap.css
Testing...

Testing: ./src/css/analyzer/bootstrap.css
Tokenized in: 29 milliseconds, 881 microseconds, and 80 nanoseconds
Validated in: 45 milliseconds, 965 microseconds, and 70 nanoseconds
Total error count: 24
Finished in: 75 milliseconds, 897 microseconds, and 720 nanoseconds

real    0m0.078s
user    0m0.076s
sys     0m0.011s
```

### csstree-validator
```
savant@savantpc:~/css/tests/data$ time csstree-validator bootstrap.css
# bootstrap.css
    * Invalid value for `text-align` property
      syntax: start | end | left | right | center | justify | match-parent
       value: -webkit-match-parent
      --------^
    * Unknown property `-webkit-margin-end`
    * Unknown property `-webkit-margin-end`
    * Unknown property `-webkit-margin-end`
    * Unknown property `-webkit-margin-end`
    * Unknown property `-webkit-margin-end`
    * Unknown property `-webkit-margin-end`
    * Unknown property `color-adjust`
    * Invalid value for `-moz-user-select` property
      syntax: none | text | all | -moz-none
       value: auto
      --------^


real    0m0.365s
user    0m0.593s
sys     0m0.136s
```