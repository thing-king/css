# css
CSS parser and validator.


## Features
- [X] MDN CSS data imported via JSON schema, created with `jsony_plus`
- [X] Property Name/Value Validation
- [ ] Userfriendly validation errors
- [ ] Selectors
- [ ] Stylesheet

```nim
import pkg/css

# Validate property names
echo isValidPropertyName("not valid!").valid                      # true

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