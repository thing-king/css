# css
CSS parser with value validation.


## Features
- [X] MDN CSS data imported via JSON schema, created with `jsony_plus`
- [X] Property Name/Value Validation
- [X] `calc()` support
- [ ] Rewrite lexer/parser/validator as single loop, currenttly three components
- [ ] Userfriendly errors
- [ ] Selectors
- [ ] Dynamic Compilation/Contexts

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