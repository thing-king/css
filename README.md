# css
MDN-typed CSS validator with minimally hacked non-string DSL.


## Features
- parses for syntax and values
- syntax validator
- typed styles object with assignment validation

### Supported
- [X] Properties
- [X] AtRules
- [X] Rules
- [ ] Rule selectors

### TODO
- [ ] Userfriendly errors
- [ ] Entire rewrite
- [ ] Context awareness  (track variables)

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

## Validation
All property values are validated at compile-time, unless their value is "not-pure" (dynamic), then they are validated at run-time.
```nim
import pkg/css

# Validate property names
echo isValidPropertyName("not valid!").valid                      # false

# Validate property values against a name
echo isValidPropertyValue("background-color", "magenta").valid    # true
echo isValidPropertyValue("backgsdound-color", "magenta").valid   # false
echo isValidPropertyValue("backgsdound-color", "magenta").errors  # @[ "backgsdound-color is not a valid property name" ]
echo isValidPropertyValue("margin", "20").errors                  # @[ "Expected length, got integer" ]

# Directly access MDN CSS data
echo functions["abs()"].status                                    # "standard"
echo properties["flex-direction"].inherited                       # false
echo syntaxes["frequency-percentage"].syntax                      # "<frequency> | <percentage>"
```


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

```
Testing: ./tests/data/bootstrap.css
Testing: `clip`: `rect(0, 0, 0, 0);`
  Errors: 
    - None of the alternatives matched
Testing: `transform-origin`: `0 0;`
  Errors: 
    - Extra tokens at index 1
Testing: `background-position`: `right 0.75rem center, center right 2.25rem;`
  Errors: 
    - Single item in comma list is invalid: 
Testing: `background-position`: `right 0.75rem center, center right 2.25rem;`
  Errors: 
    - Single item in comma list is invalid: 
Testing: `background`: `none;`
  Errors: 
    - Expected nkDataType but reached end
Testing: `background-image`: `linear-gradient(45deg, rgba(255, 255, 255, 0.15) 25%, transparent 25%, transparent 50%, rgba(255, 255, 255, 0.15) 50%, rgba(255, 255, 255, 0.15) 75%, transparent 75%, transparent);`
  Errors: 
    - Single item in comma list is invalid: None of the alternatives matched
Testing: `background`: `none;`
  Errors: 
    - Expected nkDataType but reached end
Testing: `-webkit-mask-image`: `linear-gradient(130deg, #000 55%, rgba(0, 0, 0, 0.8) 75%, #000 95%);`
  Errors: 
    - Single item in comma list is invalid: None of the alternatives matched
Testing: `mask-image`: `linear-gradient(130deg, #000 55%, rgba(0, 0, 0, 0.8) 75%, #000 95%);`
  Errors: 
    - Single item in comma list is invalid: None of the alternatives matched
Testing: `box-shadow`: `var(--bs-focus-ring-x, 0) var(--bs-focus-ring-y, 0) var(--bs-focus-ring-blur, 0) var(--bs-focus-ring-width) var(--bs-focus-ring-color);`
  Errors: 
    - Extra tokens at index 1
Testing: `clip`: `rect(0, 0, 0, 0) !important;`
  Errors: 
    - None of the alternatives matched
Error Count: 11 / 30 max
Finished in: 39 milliseconds, 736 microseconds, and 483 nanoseconds
```