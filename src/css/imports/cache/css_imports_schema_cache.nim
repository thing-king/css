import tables

## AtRule

type
  AtRuleDefinitionsStringOrPropertyListVariant0* = string
type
  AtRuleDefinitionsStringOrPropertyListVariant1* = seq[string]
type
  AtRuleDefinitionsStringOrPropertyListKind* = enum
    Variant0, Variant1
type
  AtRuleDefinitionsStringOrPropertyList* = object
    case kind*: AtRuleDefinitionsStringOrPropertyListKind
    of Variant0:
        value0*: AtRuleDefinitionsStringOrPropertyListVariant0

    of Variant1:
        value1*: AtRuleDefinitionsStringOrPropertyListVariant1

  
type
  AtRuleValueInterfaces* = seq[string]
type
  definitionsGroupList* = enum
    dglBASIC_SELECTORS, dglCOMBINATORS, dglCOMPOSITING_AND_BLENDING,
    dglCSS_ANGLES, dglCSS_ANIMATIONS, dglCSS_BACKGROUNDS_AND_BORDERS,
    dglCSS_BASIC_USER_INTERFACE, dglCSS_BOX_ALIGNMENT, dglCSS_BOX_MODEL,
    dglCSS_BOX_SIZING, dglCSS_CASCADING_AND_INHERITANCE, dglCSS_COLOR,
    dglCSS_CONDITIONAL_RULES, dglCSS_CONTAINMENT, dglCSS_COUNTER_STYLES,
    dglCSS_CUSTOM_PROPERTIES_FOR_CASCADING_VARIABLES, dglCSS_DEVICE_ADAPTATION,
    dglCSS_DISPLAY, dglCSS_FLEXIBLE_BOX_LAYOUT, dglCSS_FONTS,
    dglCSS_FRAGMENTATION, dglCSS_FREQUENCIES, dglCSS_GENERATED_CONTENT,
    dglCSS_GRID_LAYOUT, dglCSS_HOUDINI, dglCSS_IMAGES, dglCSS_INLINE,
    dglCSS_LENGTHS, dglCSS_LISTS_AND_COUNTERS, dglCSS_LOGICAL_PROPERTIES,
    dglCSS_MASKING, dglCSS_MOTION_PATH, dglCSS_MULTI_COLUMN_LAYOUT,
    dglCSS_NAMESPACES, dglCSS_OVERFLOW, dglCSS_OVERSCROLL_BEHAVIOR,
    dglCSS_PAGED_MEDIA, dglCSS_POSITIONING, dglCSS_RESOLUTIONS, dglCSS_RUBY,
    dglCSS_SCROLL_ANCHORING, dglCSS_SCROLLBARS, dglCSS_SCROLL_SNAP,
    dglCSS_SHADOW_PARTS, dglCSS_SHAPES, dglCSS_SPEECH, dglCSS_SYNTAX,
    dglCSS_TABLE, dglCSS_TEXT, dglCSS_TEXT_DECORATION, dglCSS_TIMES,
    dglCSS_TRANSFORMS, dglCSS_TRANSITIONS, dglCSS_TYPES, dglCSS_UNITS,
    dglCSS_VIEW_TRANSITIONS, dglCSS_WILL_CHANGE, dglCSS_WRITING_MODES,
    dglCSSOM_VIEW, dglFILTER_EFFECTS, dglGROUPING_SELECTORS, dglMATH_ML,
    dglMEDIA_QUERIES, dglMICROSOFT_EXTENSIONS, dglMOZILLA_EXTENSIONS,
    dglPOINTER_EVENTS, dglPSEUDO, dglPSEUDO_CLASSES, dglPSEUDO_ELEMENTS,
    dglSELECTORS, dglSCALABLE_VECTOR_GRAPHICS, dglWEB_KIT_EXTENSIONS
type
  AtRuleValueGroups* = seq[definitionsGroupList]
type
  AtRuleValueDescriptorsValueMediaVariant0* = enum
    arvdvmvALL, arvdvmvCONTINUOUS, arvdvmvPAGED, arvdvmvVISUAL
type
  AtRuleValueDescriptorsValueMediaVariant1Item* = enum
    arvdvmviCONTINUOUS, arvdvmviPAGED, arvdvmviVISUAL
type
  AtRuleValueDescriptorsValueMediaVariant1* = seq[
      AtRuleValueDescriptorsValueMediaVariant1Item]
type
  AtRuleValueDescriptorsValueMediaKind* = enum
    Variant0, Variant1
type
  AtRuleValueDescriptorsValueMedia* = object
    case kind*: AtRuleValueDescriptorsValueMediaKind
    of Variant0:
        value0*: AtRuleValueDescriptorsValueMediaVariant0

    of Variant1:
        value1*: AtRuleValueDescriptorsValueMediaVariant1

  
type
  AtRuleValueDescriptorsValueOrder* = enum
    arvdvoORDER_OF_APPEARANCE, arvdvoUNIQUE_ORDER
type
  AtRuleValueDescriptorsValueStatus* = enum
    arvdvsSTANDARD, arvdvsNONSTANDARD, arvdvsEXPERIMENTAL, arvdvsOBSOLETE
type
  AtRuleValueDescriptorsValue* = object
    syntax*: string
    media*: AtRuleValueDescriptorsValueMedia
    initial*: AtRuleDefinitionsStringOrPropertyList
    percentages*: AtRuleDefinitionsStringOrPropertyList
    computed*: AtRuleDefinitionsStringOrPropertyList
    order*: AtRuleValueDescriptorsValueOrder
    status*: AtRuleValueDescriptorsValueStatus
    mdn_url*: string

type
  AtRuleValueDescriptors* = Table[string, AtRuleValueDescriptorsValue]
type
  AtRuleValueStatus* = enum
    arvsSTANDARD, arvsNONSTANDARD, arvsEXPERIMENTAL, arvsOBSOLETE
type
  AtRuleValue* = object
    syntax*: string
    interfaces*: AtRuleValueInterfaces
    groups*: AtRuleValueGroups
    descriptors*: AtRuleValueDescriptors
    status*: AtRuleValueStatus
    mdn_url*: string

type
  AtRule* = Table[string, AtRuleValue]
# proc enumHook*(s: string; v: var definitionsGroupList) =
#   var definitionsGroupListTable: Table[string, definitionsGroupList] = initTable[
#       string, definitionsGroupList]()
#   definitionsGroupListTable["Basic Selectors"] = definitionsGroupList.dglBASIC_SELECTORS
#   definitionsGroupListTable["Combinators"] = definitionsGroupList.dglCOMBINATORS
#   definitionsGroupListTable["Compositing and Blending"] = definitionsGroupList.dglCOMPOSITING_AND_BLENDING
#   definitionsGroupListTable["CSS Angles"] = definitionsGroupList.dglCSS_ANGLES
#   definitionsGroupListTable["CSS Animations"] = definitionsGroupList.dglCSS_ANIMATIONS
#   definitionsGroupListTable["CSS Backgrounds and Borders"] = definitionsGroupList.dglCSS_BACKGROUNDS_AND_BORDERS
#   definitionsGroupListTable["CSS Basic User Interface"] = definitionsGroupList.dglCSS_BASIC_USER_INTERFACE
#   definitionsGroupListTable["CSS Box Alignment"] = definitionsGroupList.dglCSS_BOX_ALIGNMENT
#   definitionsGroupListTable["CSS Box Model"] = definitionsGroupList.dglCSS_BOX_MODEL
#   definitionsGroupListTable["CSS Box Sizing"] = definitionsGroupList.dglCSS_BOX_SIZING
#   definitionsGroupListTable["CSS Cascading and Inheritance"] = definitionsGroupList.dglCSS_CASCADING_AND_INHERITANCE
#   definitionsGroupListTable["CSS Color"] = definitionsGroupList.dglCSS_COLOR
#   definitionsGroupListTable["CSS Conditional Rules"] = definitionsGroupList.dglCSS_CONDITIONAL_RULES
#   definitionsGroupListTable["CSS Containment"] = definitionsGroupList.dglCSS_CONTAINMENT
#   definitionsGroupListTable["CSS Counter Styles"] = definitionsGroupList.dglCSS_COUNTER_STYLES
#   definitionsGroupListTable["CSS Custom Properties for Cascading Variables"] = definitionsGroupList.dglCSS_CUSTOM_PROPERTIES_FOR_CASCADING_VARIABLES
#   definitionsGroupListTable["CSS Device Adaptation"] = definitionsGroupList.dglCSS_DEVICE_ADAPTATION
#   definitionsGroupListTable["CSS Display"] = definitionsGroupList.dglCSS_DISPLAY
#   definitionsGroupListTable["CSS Flexible Box Layout"] = definitionsGroupList.dglCSS_FLEXIBLE_BOX_LAYOUT
#   definitionsGroupListTable["CSS Fonts"] = definitionsGroupList.dglCSS_FONTS
#   definitionsGroupListTable["CSS Fragmentation"] = definitionsGroupList.dglCSS_FRAGMENTATION
#   definitionsGroupListTable["CSS Frequencies"] = definitionsGroupList.dglCSS_FREQUENCIES
#   definitionsGroupListTable["CSS Generated Content"] = definitionsGroupList.dglCSS_GENERATED_CONTENT
#   definitionsGroupListTable["CSS Grid Layout"] = definitionsGroupList.dglCSS_GRID_LAYOUT
#   definitionsGroupListTable["CSS Houdini"] = definitionsGroupList.dglCSS_HOUDINI
#   definitionsGroupListTable["CSS Images"] = definitionsGroupList.dglCSS_IMAGES
#   definitionsGroupListTable["CSS Inline"] = definitionsGroupList.dglCSS_INLINE
#   definitionsGroupListTable["CSS Lengths"] = definitionsGroupList.dglCSS_LENGTHS
#   definitionsGroupListTable["CSS Lists and Counters"] = definitionsGroupList.dglCSS_LISTS_AND_COUNTERS
#   definitionsGroupListTable["CSS Logical Properties"] = definitionsGroupList.dglCSS_LOGICAL_PROPERTIES
#   definitionsGroupListTable["CSS Masking"] = definitionsGroupList.dglCSS_MASKING
#   definitionsGroupListTable["CSS Motion Path"] = definitionsGroupList.dglCSS_MOTION_PATH
#   definitionsGroupListTable["CSS Multi-column Layout"] = definitionsGroupList.dglCSS_MULTI_COLUMN_LAYOUT
#   definitionsGroupListTable["CSS Namespaces"] = definitionsGroupList.dglCSS_NAMESPACES
#   definitionsGroupListTable["CSS Overflow"] = definitionsGroupList.dglCSS_OVERFLOW
#   definitionsGroupListTable["CSS Overscroll Behavior"] = definitionsGroupList.dglCSS_OVERSCROLL_BEHAVIOR
#   definitionsGroupListTable["CSS Paged Media"] = definitionsGroupList.dglCSS_PAGED_MEDIA
#   definitionsGroupListTable["CSS Positioning"] = definitionsGroupList.dglCSS_POSITIONING
#   definitionsGroupListTable["CSS Resolutions"] = definitionsGroupList.dglCSS_RESOLUTIONS
#   definitionsGroupListTable["CSS Ruby"] = definitionsGroupList.dglCSS_RUBY
#   definitionsGroupListTable["CSS Scroll Anchoring"] = definitionsGroupList.dglCSS_SCROLL_ANCHORING
#   definitionsGroupListTable["CSS Scrollbars"] = definitionsGroupList.dglCSS_SCROLLBARS
#   definitionsGroupListTable["CSS Scroll Snap"] = definitionsGroupList.dglCSS_SCROLL_SNAP
#   definitionsGroupListTable["CSS Shadow Parts"] = definitionsGroupList.dglCSS_SHADOW_PARTS
#   definitionsGroupListTable["CSS Shapes"] = definitionsGroupList.dglCSS_SHAPES
#   definitionsGroupListTable["CSS Speech"] = definitionsGroupList.dglCSS_SPEECH
#   definitionsGroupListTable["CSS Syntax"] = definitionsGroupList.dglCSS_SYNTAX
#   definitionsGroupListTable["CSS Table"] = definitionsGroupList.dglCSS_TABLE
#   definitionsGroupListTable["CSS Text"] = definitionsGroupList.dglCSS_TEXT
#   definitionsGroupListTable["CSS Text Decoration"] = definitionsGroupList.dglCSS_TEXT_DECORATION
#   definitionsGroupListTable["CSS Times"] = definitionsGroupList.dglCSS_TIMES
#   definitionsGroupListTable["CSS Transforms"] = definitionsGroupList.dglCSS_TRANSFORMS
#   definitionsGroupListTable["CSS Transitions"] = definitionsGroupList.dglCSS_TRANSITIONS
#   definitionsGroupListTable["CSS Types"] = definitionsGroupList.dglCSS_TYPES
#   definitionsGroupListTable["CSS Units"] = definitionsGroupList.dglCSS_UNITS
#   definitionsGroupListTable["CSS View Transitions"] = definitionsGroupList.dglCSS_VIEW_TRANSITIONS
#   definitionsGroupListTable["CSS Will Change"] = definitionsGroupList.dglCSS_WILL_CHANGE
#   definitionsGroupListTable["CSS Writing Modes"] = definitionsGroupList.dglCSS_WRITING_MODES
#   definitionsGroupListTable["CSSOM View"] = definitionsGroupList.dglCSSOM_VIEW
#   definitionsGroupListTable["Filter Effects"] = definitionsGroupList.dglFILTER_EFFECTS
#   definitionsGroupListTable["Grouping Selectors"] = definitionsGroupList.dglGROUPING_SELECTORS
#   definitionsGroupListTable["MathML"] = definitionsGroupList.dglMATH_ML
#   definitionsGroupListTable["Media Queries"] = definitionsGroupList.dglMEDIA_QUERIES
#   definitionsGroupListTable["Microsoft Extensions"] = definitionsGroupList.dglMICROSOFT_EXTENSIONS
#   definitionsGroupListTable["Mozilla Extensions"] = definitionsGroupList.dglMOZILLA_EXTENSIONS
#   definitionsGroupListTable["Pointer Events"] = definitionsGroupList.dglPOINTER_EVENTS
#   definitionsGroupListTable["Pseudo"] = definitionsGroupList.dglPSEUDO
#   definitionsGroupListTable["Pseudo-classes"] = definitionsGroupList.dglPSEUDO_CLASSES
#   definitionsGroupListTable["Pseudo-elements"] = definitionsGroupList.dglPSEUDO_ELEMENTS
#   definitionsGroupListTable["Selectors"] = definitionsGroupList.dglSELECTORS
#   definitionsGroupListTable["Scalable Vector Graphics"] = definitionsGroupList.dglSCALABLE_VECTOR_GRAPHICS
#   definitionsGroupListTable["WebKit Extensions"] = definitionsGroupList.dglWEB_KIT_EXTENSIONS
#   v = definitionsGroupListTable[s]

# proc enumHook*(s: string;
#                v: var AtRuleValueDescriptorsValueMediaVariant0) =
#   var AtRuleValueDescriptorsValueMediaVariant0Table: Table[string,
#       AtRuleValueDescriptorsValueMediaVariant0] = initTable[string,
#       AtRuleValueDescriptorsValueMediaVariant0]()
#   AtRuleValueDescriptorsValueMediaVariant0Table["all"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvALL
#   AtRuleValueDescriptorsValueMediaVariant0Table["continuous"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvCONTINUOUS
#   AtRuleValueDescriptorsValueMediaVariant0Table["paged"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvPAGED
#   AtRuleValueDescriptorsValueMediaVariant0Table["visual"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvVISUAL
#   v = AtRuleValueDescriptorsValueMediaVariant0Table[s]

# proc enumHook*(s: string;
#                v: var AtRuleValueDescriptorsValueMediaVariant1Item) =
#   var AtRuleValueDescriptorsValueMediaVariant1ItemTable: Table[string,
#       AtRuleValueDescriptorsValueMediaVariant1Item] = initTable[string,
#       AtRuleValueDescriptorsValueMediaVariant1Item]()
#   AtRuleValueDescriptorsValueMediaVariant1ItemTable["continuous"] = AtRuleValueDescriptorsValueMediaVariant1Item.arvdvmviCONTINUOUS
#   AtRuleValueDescriptorsValueMediaVariant1ItemTable["paged"] = AtRuleValueDescriptorsValueMediaVariant1Item.arvdvmviPAGED
#   AtRuleValueDescriptorsValueMediaVariant1ItemTable["visual"] = AtRuleValueDescriptorsValueMediaVariant1Item.arvdvmviVISUAL
#   v = AtRuleValueDescriptorsValueMediaVariant1ItemTable[s]

# proc enumHook*(s: string;
#                v: var AtRuleValueDescriptorsValueOrder) =
#   var AtRuleValueDescriptorsValueOrderTable: Table[string,
#       AtRuleValueDescriptorsValueOrder] = initTable[string,
#       AtRuleValueDescriptorsValueOrder]()
#   AtRuleValueDescriptorsValueOrderTable["orderOfAppearance"] = AtRuleValueDescriptorsValueOrder.arvdvoORDER_OF_APPEARANCE
#   AtRuleValueDescriptorsValueOrderTable["uniqueOrder"] = AtRuleValueDescriptorsValueOrder.arvdvoUNIQUE_ORDER
#   v = AtRuleValueDescriptorsValueOrderTable[s]

# proc enumHook*(s: string;
#                v: var AtRuleValueDescriptorsValueStatus) =
#   var AtRuleValueDescriptorsValueStatusTable: Table[string,
#       AtRuleValueDescriptorsValueStatus] = initTable[string,
#       AtRuleValueDescriptorsValueStatus]()
#   AtRuleValueDescriptorsValueStatusTable["standard"] = AtRuleValueDescriptorsValueStatus.arvdvsSTANDARD
#   AtRuleValueDescriptorsValueStatusTable["nonstandard"] = AtRuleValueDescriptorsValueStatus.arvdvsNONSTANDARD
#   AtRuleValueDescriptorsValueStatusTable["experimental"] = AtRuleValueDescriptorsValueStatus.arvdvsEXPERIMENTAL
#   AtRuleValueDescriptorsValueStatusTable["obsolete"] = AtRuleValueDescriptorsValueStatus.arvdvsOBSOLETE
#   v = AtRuleValueDescriptorsValueStatusTable[s]

# proc enumHook*(s: string; v: var AtRuleValueStatus) =
#   var AtRuleValueStatusTable: Table[string, AtRuleValueStatus] = initTable[
#       string, AtRuleValueStatus]()
#   AtRuleValueStatusTable["standard"] = AtRuleValueStatus.arvsSTANDARD
#   AtRuleValueStatusTable["nonstandard"] = AtRuleValueStatus.arvsNONSTANDARD
#   AtRuleValueStatusTable["experimental"] = AtRuleValueStatus.arvsEXPERIMENTAL
#   AtRuleValueStatusTable["obsolete"] = AtRuleValueStatus.arvsOBSOLETE
#   v = AtRuleValueStatusTable[s]

# proc parseHook*(s: string; i: var int;
#                 v: var AtRuleValueDescriptorsValueMedia) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: AtRuleValueDescriptorsValueMediaVariant0
#     tempValue = fromJson(jsonStr,
#                                  AtRuleValueDescriptorsValueMediaVariant0)
#     v = AtRuleValueDescriptorsValueMedia(
#         kind: AtRuleValueDescriptorsValueMediaKind.Variant0,
#         value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: AtRuleValueDescriptorsValueMediaVariant1
#     tempValue = fromJson(jsonStr,
#                                  AtRuleValueDescriptorsValueMediaVariant1)
#     v = AtRuleValueDescriptorsValueMedia(
#         kind: AtRuleValueDescriptorsValueMediaKind.Variant1,
#         value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "AtRuleValueDescriptorsValueMedia")

# proc dumpHook*(s: var string; v: AtRuleValueDescriptorsValueMedia) =
#   case v.kind
#   of AtRuleValueDescriptorsValueMediaKind.Variant0:
#     s = toJson(v.value0)
#   of AtRuleValueDescriptorsValueMediaKind.Variant1:
#     s = toJson(v.value1)
  
# proc parseHook*(s: string; i: var int;
#                 v: var AtRuleDefinitionsStringOrPropertyList) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: AtRuleDefinitionsStringOrPropertyListVariant0
#     tempValue = fromJson(jsonStr,
#                                   AtRuleDefinitionsStringOrPropertyListVariant0)
#     v = AtRuleDefinitionsStringOrPropertyList(
#         kind: AtRuleDefinitionsStringOrPropertyListKind.Variant0,
#         value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: AtRuleDefinitionsStringOrPropertyListVariant1
#     tempValue = fromJson(jsonStr,
#                                   AtRuleDefinitionsStringOrPropertyListVariant1)
#     v = AtRuleDefinitionsStringOrPropertyList(
#         kind: AtRuleDefinitionsStringOrPropertyListKind.Variant1,
#         value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "AtRuleDefinitionsStringOrPropertyList")

# proc dumpHook*(s: var string; v: AtRuleDefinitionsStringOrPropertyList) =
#   case v.kind
#   of AtRuleDefinitionsStringOrPropertyListKind.Variant0:
#     s = toJson(v.value0)
#   of AtRuleDefinitionsStringOrPropertyListKind.Variant1:
#     s = toJson(v.value1)
  

## Types

# type
#   TypesValueGroups* = seq[definitionsGroupList]
# type
#   TypesValueStatus* = enum
#     tvsSTANDARD, tvsNONSTANDARD, tvsEXPERIMENTAL, tvsOBSOLETE
# type
#   TypesValue* = object
#     groups*: TypesValueGroups
#     status*: TypesValueStatus
#     mdn_url*: string

# type
#   Types* = Table[string, TypesValue]
# proc enumHook*(s: string; v: var TypesValueStatus) =
#   var TypesValueStatusTable: Table[string, TypesValueStatus] = initTable[string,
#       TypesValueStatus]()
#   TypesValueStatusTable["standard"] = TypesValueStatus.tvsSTANDARD
#   TypesValueStatusTable["nonstandard"] = TypesValueStatus.tvsNONSTANDARD
#   TypesValueStatusTable["experimental"] = TypesValueStatus.tvsEXPERIMENTAL
#   TypesValueStatusTable["obsolete"] = TypesValueStatus.tvsOBSOLETE
#   v = TypesValueStatusTable[s]


# ## Units

# type
#   UnitsValueGroups* = seq[definitionsGroupList]
# type
#   UnitsValueStatus* = enum
#     uvsSTANDARD, uvsNONSTANDARD, uvsEXPERIMENTAL, uvsOBSOLETE
# type
#   UnitsValue* = object
#     groups*: UnitsValueGroups
#     status*: UnitsValueStatus

# type
#   Units* = Table[string, UnitsValue]
# proc enumHook*(s: string; v: var UnitsValueStatus) =
#   var UnitsValueStatusTable: Table[string, UnitsValueStatus] = initTable[string,
#       UnitsValueStatus]()
#   UnitsValueStatusTable["standard"] = UnitsValueStatus.uvsSTANDARD
#   UnitsValueStatusTable["nonstandard"] = UnitsValueStatus.uvsNONSTANDARD
#   UnitsValueStatusTable["experimental"] = UnitsValueStatus.uvsEXPERIMENTAL
#   UnitsValueStatusTable["obsolete"] = UnitsValueStatus.uvsOBSOLETE
#   v = UnitsValueStatusTable[s]


## Syntaxes

type
  SyntaxesValue* = object
    syntax*: string

type
  Syntaxes* = Table[string, SyntaxesValue]

## Properties

type
  PropertiesDefinitionsPropertyList* = seq[string]
type
  PropertiesDefinitionsOrder* = enum
    pdoCANONICAL_ORDER, pdoLENGTH_OR_PERCENTAGE_BEFORE_KEYWORD_IF_BOTH_PRESENT,
    pdoLENGTH_OR_PERCENTAGE_BEFORE_KEYWORDS,
    pdoONE_OR_TWO_VALUES_LENGTH_ABSOLUTE_KEYWORDS_PERCENTAGES,
    pdoORDER_OF_APPEARANCE, pdoPERCENTAGES_OR_LENGTHS_FOLLOWED_BY_FILL,
    pdoPER_GRAMMAR, pdoUNIQUE_ORDER
type
  PropertiesDefinitionsPercentages* = enum
    pdpBLOCK_SIZE_OF_CONTAINING_BLOCK, pdpDEPENDS_ON_LAYOUT_MODEL,
    pdpINLINE_SIZE_OF_CONTAINING_BLOCK, pdpLENGTHS_AS_PERCENTAGES,
    pdpLOGICAL_HEIGHT_OF_CONTAINING_BLOCK, pdpLOGICAL_WIDTH_OF_CONTAINING_BLOCK,
    pdpLOGICAL_HEIGHT_OR_WIDTH_OF_CONTAINING_BLOCK, pdpMAP_TO_RANGE0_TO1,
    pdpMAX_ZOOM_FACTOR, pdpMIN_ZOOM_FACTOR, pdpNO, pdpREFER_TO_BORDER_BOX,
    pdpREFER_TO_CONTAINING_BLOCK_HEIGHT, pdpREFER_TO_DIMENSION_OF_BORDER_BOX,
    pdpREFER_TO_DIMENSION_OF_CONTENT_AREA, pdpREFER_TO_ELEMENT_FONT_SIZE,
    pdpREFER_TO_FLEX_CONTAINERS_INNER_MAIN_SIZE, pdpREFER_TO_HEIGHT_OF_BACKGROUND_POSITIONING_AREA_MINUS_BACKGROUND_IMAGE_HEIGHT,
    pdpREFER_TO_LINE_BOX_WIDTH, pdpREFER_TO_LINE_HEIGHT,
    pdpREFER_TO_PARENT_ELEMENTS_FONT_SIZE, pdpREFER_TO_SIZE_OF_BACKGROUND_POSITIONING_AREA_MINUS_BACKGROUND_IMAGE_SIZE,
    pdpREFER_TO_SIZE_OF_BORDER_IMAGE, pdpREFER_TO_SIZE_OF_BOUNDING_BOX,
    pdpREFER_TO_SIZE_OF_CONTAINING_BLOCK, pdpREFER_TO_SIZE_OF_ELEMENT,
    pdpREFER_TO_SIZE_OF_FONT, pdpREFER_TO_SIZE_OF_MASK_BORDER_IMAGE,
    pdpREFER_TO_SIZE_OF_MASK_PAINTING_AREA, pdpREFER_TO_SVGVIEWPORT_HEIGHT,
    pdpREFER_TO_SVGVIEWPORT_SIZE, pdpREFER_TO_SVGVIEWPORT_WIDTH,
    pdpREFER_TO_SVGVIEWPORT_DIAGONAL, pdpREFER_TO_TOTAL_PATH_LENGTH,
    pdpREFER_TO_WIDTH_AND_HEIGHT_OF_ELEMENT,
    pdpREFER_TO_WIDTH_OF_AFFECTED_GLYPH, pdpREFER_TO_WIDTH_OF_BACKGROUND_POSITIONING_AREA_MINUS_BACKGROUND_IMAGE_WIDTH,
    pdpREFER_TO_WIDTH_OF_CONTAINING_BLOCK,
    pdpREFER_TO_WIDTH_OR_HEIGHT_OF_BORDER_IMAGE_AREA,
    pdpREFER_TO_REFERENCE_BOX_WHEN_SPECIFIED_OTHERWISE_BORDER_BOX,
    pdpREGARDING_HEIGHT_OF_GENERATED_BOX_CONTAINING_BLOCK_PERCENTAGES0,
    pdpREGARDING_HEIGHT_OF_GENERATED_BOX_CONTAINING_BLOCK_PERCENTAGES_NONE, pdpREGARDING_HEIGHT_OF_GENERATED_BOX_CONTAINING_BLOCK_PERCENTAGES_RELATIVE_TO_CONTAINING_BLOCK,
    pdpRELATIVE_TO_BACKGROUND_POSITIONING_AREA,
    pdpRELATIVE_TO_CORRESPONDING_DIMENSION_OF_RELEVANT_SCROLLPORT,
    pdpRELATIVE_TO_MASK_BORDER_IMAGE_AREA,
    pdpRELATIVE_TO_SCROLL_CONTAINER_PADDING_BOX_AXIS,
    pdpRELATIVE_TO_THE_SCROLL_CONTAINERS_SCROLLPORT,
    pdpRELATIVE_TO_TIMELINE_RANGE_IF_SPECIFIED_OTHERWISE_ENTIRE_TIMELINE,
    pdpRELATIVE_TO_WIDTH_AND_HEIGHT
type
  PropertiesDefinitionsMdn_url* = string
type
  PropertiesDefinitionsComputed* = enum
    pdcABSOLUTE_LENGTH, pdcABSOLUTE_LENGTH0_FOR_NONE,
    pdcABSOLUTE_LENGTH0_IF_COLUMN_RULE_STYLE_NONE_OR_HIDDEN,
    pdcABSOLUTE_LENGTH_OR0_IF_BORDER_BOTTOM_STYLE_NONE_OR_HIDDEN,
    pdcABSOLUTE_LENGTH_OR0_IF_BORDER_LEFT_STYLE_NONE_OR_HIDDEN,
    pdcABSOLUTE_LENGTH_OR0_IF_BORDER_RIGHT_STYLE_NONE_OR_HIDDEN,
    pdcABSOLUTE_LENGTH_OR0_IF_BORDER_TOP_STYLE_NONE_OR_HIDDEN,
    pdcABSOLUTE_LENGTH_OR_AS_SPECIFIED, pdcABSOLUTE_LENGTH_OR_KEYWORD,
    pdcABSOLUTE_LENGTH_OR_NONE, pdcABSOLUTE_LENGTH_OR_NORMAL,
    pdcABSOLUTE_LENGTH_OR_PERCENTAGE,
    pdcABSOLUTE_LENGTH_OR_PERCENTAGE_NUMBERS_CONVERTED,
    pdcABSOLUTE_LENGTHS_SPECIFIED_COLOR_AS_SPECIFIED,
    pdcABSOLUTE_LENGTH_ZERO_IF_BORDER_STYLE_NONE_OR_HIDDEN,
    pdcABSOLUTE_LENGTH_ZERO_OR_LARGER, pdcABSOLUTE_URIOR_NONE,
    pdcANGLE_ROUNDED_TO_NEXT_QUARTER, pdcAS_AUTO_OR_COLOR,
    pdcAS_COLOR_OR_ABSOLUTE_URL,
    pdcAS_DEFINED_FOR_BASIC_SHAPE_WITH_ABSOLUTE_URIOTHERWISE_AS_SPECIFIED,
    pdcAS_LENGTH, pdcAS_LONGHANDS, pdcAS_SPECIFIED,
    pdcAS_SPECIFIED_APPLIES_TO_EACH_PROPERTY, pdcAS_SPECIFIED_BUT_VISIBLE_OR_CLIP_REPLACED_TO_AUTO_OR_HIDDEN_IF_OTHER_VALUE_DIFFERENT,
    pdcAS_SPECIFIED_EXCEPT_MATCH_PARENT, pdcAS_SPECIFIED_EXCEPT_POSITIONED_FLOATING_AND_ROOT_ELEMENTS_KEYWORD_MAYBE_DIFFERENT,
    pdcAS_SPECIFIED_RELATIVE_TO_ABSOLUTE_LENGTHS, pdcAS_SPECIFIED_URLS_ABSOLUTE,
    pdcAS_SPECIFIED_WITH_EXCEPTION_OF_RESOLUTION, pdcAS_SPECIFIED_WITH_LENGTHS_ABSOLUTE_AND_NORMAL_COMPUTING_TO_ZERO_EXCEPT_MULTI_COLUMN,
    pdcAS_SPECIFIED_WITH_LENGTH_VALUES_COMPUTED,
    pdcAS_SPECIFIED_WITH_VARS_SUBSTITUTED,
    pdcAUTO_ON_ABSOLUTELY_POSITIONED_ELEMENTS_VALUE_OF_ALIGN_ITEMS_ON_PARENT,
    pdcAUTO_OR_RECTANGLE, pdcCOLOR_PLUS_THREE_ABSOLUTE_LENGTHS,
    pdcCOMPUTED_COLOR, pdcCONSISTS_OF_TWO_DIMENSION_KEYWORDS,
    pdcCONSISTS_OF_TWO_KEYWORDS_FOR_ORIGIN_AND_OFFSETS,
    pdcFOR_LENGTH_ABSOLUTE_VALUE_OTHERWISE_PERCENTAGE,
    pdcAUTO_FOR_TRANSLUCENT_COLOR_RGBAOTHERWISE_RGB,
    pdcKEYWORD_OR_NUMERICAL_VALUE_BOLDER_LIGHTER_TRANSFORMED_TO_REAL_VALUE,
    pdcKEYWORD_PLUS_INTEGER_IF_DIGITS,
    pdcLENGTH_ABSOLUTE_PERCENTAGE_AS_SPECIFIED_OTHERWISE_AUTO,
    pdcLIST_EACH_ITEM_CONSISTING_OF_ABSOLUTE_LENGTH_PERCENTAGE_AND_ORIGIN,
    pdcLIST_EACH_ITEM_CONSISTING_OF_ABSOLUTE_LENGTH_PERCENTAGE_OR_KEYWORD, pdcLIST_EACH_ITEM_CONSISTING_OF_NORMAL_LENGTH_PERCENTAGE_OR_NAME_LENGTH_PERCENTAGE,
    pdcLIST_EACH_ITEM_CONSISTING_OF_PAIRS_OF_AUTO_OR_LENGTH_PERCENTAGE,
    pdcLIST_EACH_ITEM_HAS_TWO_KEYWORDS_ONE_PER_DIMENSION,
    pdcLIST_EACH_ITEM_IDENTIFIER_OR_NONE_AUTO,
    pdcLIST_EACH_ITEM_TWO_KEYWORDS_ORIGIN_OFFSETS,
    pdcNONE_OR_IMAGE_WITH_ABSOLUTE_URI, pdcNONE_OR_ORDERED_LIST_OF_IDENTIFIERS,
    pdcNORMALIZED_ANGLE,
    pdcNORMAL_ON_ELEMENTS_FOR_PSEUDOS_NONE_ABSOLUTE_URISTRING_OR_AS_SPECIFIED,
    pdcONE_TO_FOUR_PERCENTAGES_OR_ABSOLUTE_LENGTHS_PLUS_FILL,
    pdcOPTIMUM_VALUE_OF_ABSOLUTE_LENGTH_OR_NORMAL,
    pdcPERCENTAGE_AS_SPECIFIED_ABSOLUTE_LENGTH_OR_NONE,
    pdcPERCENTAGE_AS_SPECIFIED_OR_ABSOLUTE_LENGTH,
    pdcPERCENTAGE_AUTO_OR_ABSOLUTE_LENGTH,
    pdcPERCENTAGE_OR_ABSOLUTE_LENGTH_PLUS_KEYWORDS, pdcSAME_AS_BOX_OFFSETS,
    pdcSAME_AS_MAX_WIDTH_AND_MAX_HEIGHT, pdcSAME_AS_MIN_WIDTH_AND_MIN_HEIGHT,
    pdcSAME_AS_WIDTH_AND_HEIGHT, pdcSPECIFIED_INTEGER_OR_ABSOLUTE_LENGTH,
    pdcSPECIFIED_VALUE, pdcSPECIFIED_VALUE_CLIPPED0_TO1,
    pdcSPECIFIED_VALUE_NUMBER_CLIPPED0_TO1,
    pdcTHE_COMPUTED_LENGTH_AND_VISUAL_BOX,
    pdcTHE_KEYWORD_LIST_STYLE_IMAGE_NONE_OR_COMPUTED_VALUE,
    pdcTHE_SPECIFIED_KEYWORD, pdcTRANSLUCENT_VALUES_RGBAOTHERWISE_RGB,
    pdcTWO_ABSOLUTE_LENGTH_OR_PERCENTAGES, pdcTWO_ABSOLUTE_LENGTHS
type
  PropertiesDefinitionsAppliesto* = enum
    pdaABSOLUTELY_POSITIONED_ELEMENTS, pdaALL_ELEMENTS,
    pdaALL_ELEMENTS_ACCEPTING_WIDTH_OR_HEIGHT, pdaALL_ELEMENTS_AND_PSEUDOS,
    pdaALL_ELEMENTS_AND_TEXT,
    pdaALL_ELEMENTS_BUT_NON_REPLACED_AND_TABLE_COLUMNS,
    pdaALL_ELEMENTS_BUT_NON_REPLACED_AND_TABLE_ROWS,
    pdaALL_ELEMENTS_CREATING_NATIVE_WINDOWS,
    pdaALL_ELEMENTS_EXCEPT_GENERATED_CONTENT_OR_PSEUDO_ELEMENTS,
    pdaALL_ELEMENTS_EXCEPT_INLINE_BOXES_AND_INTERNAL_RUBY_OR_TABLE_BOXES,
    pdaALL_ELEMENTS_EXCEPT_INTERNAL_TABLE_DISPLAY_TYPES, pdaALL_ELEMENTS_EXCEPT_NON_REPLACED_INLINE_ELEMENTS_TABLE_ROWS_COLUMNS_ROW_COLUMN_GROUPS,
    pdaALL_ELEMENTS_EXCEPT_TABLE_DISPLAY_TYPES,
    pdaALL_ELEMENTS_EXCEPT_TABLE_ELEMENTS_WHEN_COLLAPSE,
    pdaALL_ELEMENTS_EXCEPT_TABLE_ROW_COLUMN_GROUPS_TABLE_ROWS_COLUMNS,
    pdaALL_ELEMENTS_EXCEPT_TABLE_ROW_GROUPS_ROWS_COLUMN_GROUPS_AND_COLUMNS,
    pdaALL_ELEMENTS_NO_EFFECT_IF_DISPLAY_NONE,
    pdaALL_ELEMENTS_SOME_VALUES_NO_EFFECT_ON_NON_INLINE_ELEMENTS,
    pdaALL_ELEMENTS_SVGCONTAINER_ELEMENTS,
    pdaALL_ELEMENTS_SVGCONTAINER_GRAPHICS_AND_GRAPHICS_REFERENCING_ELEMENTS,
    pdaALL_ELEMENTS_THAT_CAN_REFERENCE_IMAGES,
    pdaALL_ELEMENTS_THAT_GENERATE_APRINCIPAL_BOX,
    pdaALL_ELEMENTS_TREE_ABIDING_PSEUDO_ELEMENTS_PAGE_MARGIN_BOXES,
    pdaALL_ELEMENTS_UAS_NOT_REQUIRED_WHEN_COLLAPSE,
    pdaANY_ELEMENT_EFFECT_ON_PROGRESS_AND_METER, pdaAS_LONGHANDS,
    pdaBEFORE_AND_AFTER_PSEUDOS, pdaBLOCK_CONTAINER_ELEMENTS,
    pdaBLOCK_CONTAINERS, pdaBLOCK_CONTAINERS_AND_INLINE_BOXES,
    pdaBLOCK_CONTAINERS_AND_MULTI_COLUMN_CONTAINERS,
    pdaBLOCK_CONTAINERS_EXCEPT_MULTI_COLUMN_CONTAINERS,
    pdaBLOCK_CONTAINERS_EXCEPT_TABLE_WRAPPERS,
    pdaBLOCK_CONTAINERS_FLEX_CONTAINERS_GRID_CONTAINERS, pdaBLOCK_CONTAINERS_FLEX_CONTAINERS_GRID_CONTAINERS_INLINE_BOXES_TABLE_ROWS_SVGTEXT_CONTENT_ELEMENTS, pdaBLOCK_CONTAINERS_MULTI_COLUMN_CONTAINERS_FLEX_CONTAINERS_GRID_CONTAINERS,
    pdaBLOCK_ELEMENTS_IN_NORMAL_FLOW, pdaBLOCK_LEVEL_ELEMENTS,
    pdaBLOCK_LEVEL_BOXES_AND_ABSOLUTELY_POSITIONED_BOXES_AND_GRID_ITEMS,
    pdaBOX_ELEMENTS, pdaCHILDREN_OF_BOX_ELEMENTS,
    pdaDIRECT_CHILDREN_OF_ELEMENTS_WITH_DISPLAY_MOZ_BOX_MOZ_INLINE_BOX,
    pdaELEMENTS_FOR_WHICH_LAYOUT_CONTAINMENT_CAN_APPLY,
    pdaELEMENTS_FOR_WHICH_SIZE_CONTAINMENT_CAN_APPLY,
    pdaELEMENTS_THAT_ACCEPT_INPUT, pdaELEMENTS_WITH_DEFAULT_PREFERRED_SIZE,
    pdaELEMENTS_WITH_DISPLAY_BOX_OR_INLINE_BOX, pdaELEMENTS_WITH_DISPLAY_MARKER,
    pdaELEMENTS_WITH_DISPLAY_MOZ_BOX_MOZ_INLINE_BOX,
    pdaELEMENTS_WITH_OVERFLOW_NOT_VISIBLE_AND_REPLACED_ELEMENTS,
    pdaEXCLUSION_ELEMENTS,
    pdaFIRST_LETTER_PSEUDO_ELEMENTS_AND_INLINE_LEVEL_FIRST_CHILDREN,
    pdaFLEX_CONTAINERS,
    pdaFLEX_ITEMS_AND_ABSOLUTELY_POSITIONED_FLEX_CONTAINER_CHILDREN,
    pdaFLEX_ITEMS_AND_IN_FLOW_PSEUDOS,
    pdaFLEX_ITEMS_GRID_ITEMS_ABSOLUTELY_POSITIONED_CONTAINER_CHILDREN,
    pdaFLEX_ITEMS_GRID_ITEMS_AND_ABSOLUTELY_POSITIONED_BOXES, pdaFLOATS,
    pdaGRID_CONTAINERS, pdaGRID_CONTAINERS_WITH_MASONRY_LAYOUT,
    pdaGRID_CONTAINERS_WITH_MASONRY_LAYOUT_IN_THEIR_BLOCK_AXIS,
    pdaGRID_CONTAINERS_WITH_MASONRY_LAYOUT_IN_THEIR_INLINE_AXIS,
    pdaGRID_ITEMS_AND_BOXES_WITHIN_GRID_CONTAINER, pdaIFRAME_ELEMENTS,
    pdaIMAGES, pdaIN_FLOW_BLOCK_LEVEL_ELEMENTS,
    pdaIN_FLOW_CHILDREN_OF_BOX_ELEMENTS, pdaINLINE_BOXES_AND_BLOCK_CONTAINERS,
    pdaINLINE_LEVEL_AND_TABLE_CELL_ELEMENTS, pdaLIMITED_SVGELEMENTS,
    pdaLIMITED_SVGELEMENTS_CIRCLE, pdaLIMITED_SVGELEMENTS_ELLIPSE,
    pdaLIMITED_SVGELEMENTS_ELLIPSE_RECT,
    pdaLIMITED_SVGELEMENTS_FILTER_PRIMITIVES,
    pdaLIMITED_SVGELEMENTS_FLOOD_AND_DROP_SHADOW,
    pdaLIMITED_SVGELEMENTS_GEOMETRY, pdaLIMITED_SVGELEMENTS_GRAPHICS,
    pdaLIMITED_SVGELEMENTS_GRAPHICS_AND_USE,
    pdaLIMITED_SVGELEMENTS_LIGHT_SOURCE, pdaLIMITED_SVGELEMENTS_PATH,
    pdaLIMITED_SVGELEMENTS_SHAPES,
    pdaLIMITED_SVGELEMENTS_SHAPES_AND_TEXT_CONTENT,
    pdaLIMITED_SVGELEMENTS_SHAPE_TEXT, pdaLIMITED_SVGELEMENTS_STOP,
    pdaLIMITED_SVGELEMENTS_TEXT_CONTENT, pdaLIST_ITEMS, pdaMASK_ELEMENTS,
    pdaMULTICOL_ELEMENTS,
    pdaMULTI_COLUMN_ELEMENTS_FLEX_CONTAINERS_GRID_CONTAINERS,
    pdaMULTILINE_FLEX_CONTAINERS,
    pdaNON_REPLACED_BLOCK_AND_INLINE_BLOCK_ELEMENTS,
    pdaNON_REPLACED_BLOCK_ELEMENTS, pdaNON_REPLACED_ELEMENTS,
    pdaNON_REPLACED_INLINE_ELEMENTS, pdaPOSITIONED_ELEMENTS,
    pdaPOSITIONED_ELEMENTS_WITH_ADEFAULT_ANCHOR_ELEMENT, pdaREPLACED_ELEMENTS,
    pdaRUBY_ANNOTATIONS_CONTAINERS,
    pdaRUBY_BASES_ANNOTATIONS_BASE_ANNOTATION_CONTAINERS, pdaSAME_AS_MARGIN,
    pdaSAME_AS_WIDTH_AND_HEIGHT, pdaSCROLL_CONTAINERS, pdaSCROLLING_BOXES,
    pdaTABLE_CAPTION_ELEMENTS, pdaTABLE_CELL_ELEMENTS, pdaTABLE_ELEMENTS,
    pdaTEXT_AND_BLOCK_CONTAINERS, pdaTEXT_ELEMENTS, pdaTEXT_FIELDS,
    pdaTRANSFORMABLE_ELEMENTS, pdaXUL_IMAGE_ELEMENTS
type
  PropertiesDefinitionsAlsoApplyToItem* = enum
    pdaatiFIRST_LETTER, pdaatiFIRST_LINE, pdaatiPLACEHOLDER
type
  PropertiesDefinitionsAlsoApplyTo* = seq[PropertiesDefinitionsAlsoApplyToItem]
type
  PropertiesDefinitionsStatus* = enum
    pdsSTANDARD, pdsNONSTANDARD, pdsEXPERIMENTAL, pdsOBSOLETE
type
  PropertiesDefinitionsAnimationType* = enum
    pdatANGLE_BASIC_SHAPE_OR_PATH, pdatANGLE_OR_BASIC_SHAPE_OR_PATH,
    pdatBASIC_SHAPE_OTHERWISE_NO, pdatBY_COMPUTED_VALUE,
    pdatBY_COMPUTED_VALUE_TYPE,
    pdatBY_COMPUTED_VALUE_TYPE_NORMAL_ANIMATES_AS_OBLIQUE_ZERO_DEG, pdatCOLOR,
    pdatDISCRETE, pdatDISCRETE_BUT_VISIBLE_FOR_DURATION_WHEN_ANIMATED_HIDDEN,
    pdatDISCRETE_BUT_VISIBLE_FOR_DURATION_WHEN_ANIMATED_NONE,
    pdatEACH_OF_SHORTHAND_PROPERTIES_EXCEPT_UNICODE_BI_DI_AND_DIRECTION,
    pdatFILTER_LIST, pdatFONT_STRETCH, pdatFONT_WEIGHT, pdatINTEGER, pdatLENGTH,
    pdatLPC, pdatNOT_ANIMATABLE, pdatNUMBER_OR_LENGTH, pdatNUMBER, pdatPOSITION,
    pdatRECTANGLE, pdatREPEATABLE_LIST, pdatSHADOW_LIST, pdatSIMPLE_LIST_OF_LPC,
    pdatSIMPLE_LIST_OF_LPC_DIFFERENCE_LPC, pdatTRANSFORM, pdatVISIBILITY
type
  PropertiesValueMediaVariant0* = enum
    pvmvALL, pvmvAURAL, pvmvCONTINUOUS, pvmvINTERACTIVE, pvmvNONE,
    pvmvNO_PRACTICAL_MEDIA, pvmvPAGED, pvmvVISUAL,
    pvmvVISUAL_IN_CONTINUOUS_MEDIA_NO_EFFECT_IN_OVERFLOW_COLUMNS
type
  PropertiesValueMediaVariant1Item* = enum
    pvmviINTERACTIVE, pvmviPAGED, pvmviVISUAL
type
  PropertiesValueMediaVariant1* = seq[PropertiesValueMediaVariant1Item]
type
  PropertiesValueMediaKind* = enum
    Variant0, Variant1
type
  PropertiesValueMedia* = object
    case kind*: PropertiesValueMediaKind
    of Variant0:
        value0*: PropertiesValueMediaVariant0

    of Variant1:
        value1*: PropertiesValueMediaVariant1

  
type
  PropertiesValueAnimationTypeVariant0* = PropertiesDefinitionsAnimationType
type
  PropertiesValueAnimationTypeVariant1* = PropertiesDefinitionsPropertyList
type
  PropertiesValueAnimationTypeKind* = enum
    Variant0, Variant1
type
  PropertiesValueAnimationType* = object
    case kind*: PropertiesValueAnimationTypeKind
    of Variant0:
        value0*: PropertiesValueAnimationTypeVariant0

    of Variant1:
        value1*: PropertiesValueAnimationTypeVariant1

  
type
  PropertiesValuePercentagesVariant0* = PropertiesDefinitionsPercentages
type
  PropertiesValuePercentagesVariant1* = PropertiesDefinitionsPropertyList
type
  PropertiesValuePercentagesKind* = enum
    Variant0, Variant1
type
  PropertiesValuePercentages* = object
    case kind*: PropertiesValuePercentagesKind
    of Variant0:
        value0*: PropertiesValuePercentagesVariant0

    of Variant1:
        value1*: PropertiesValuePercentagesVariant1

  
type
  PropertiesValueGroups* = seq[definitionsGroupList]
type
  PropertiesValueInitialVariant0* = string
type
  PropertiesValueInitialVariant1* = PropertiesDefinitionsPropertyList
type
  PropertiesValueInitialKind* = enum
    Variant0, Variant1
type
  PropertiesValueInitial* = object
    case kind*: PropertiesValueInitialKind
    of Variant0:
        value0*: PropertiesValueInitialVariant0

    of Variant1:
        value1*: PropertiesValueInitialVariant1

  
type
  PropertiesValueComputedVariant0* = PropertiesDefinitionsComputed
type
  PropertiesValueComputedVariant1* = PropertiesDefinitionsPropertyList
type
  PropertiesValueComputedKind* = enum
    Variant0, Variant1
type
  PropertiesValueComputed* = object
    case kind*: PropertiesValueComputedKind
    of Variant0:
        value0*: PropertiesValueComputedVariant0

    of Variant1:
        value1*: PropertiesValueComputedVariant1

  
type
  PropertiesValue* = object
    syntax*: string
    media*: PropertiesValueMedia
    inherited*: bool
    animationType*: PropertiesValueAnimationType
    percentages*: PropertiesValuePercentages
    groups*: PropertiesValueGroups
    initial*: PropertiesValueInitial
    appliesto*: PropertiesDefinitionsAppliesto
    alsoAppliesTo*: PropertiesDefinitionsAlsoApplyTo
    computed*: PropertiesValueComputed
    order*: PropertiesDefinitionsOrder
    stacking*: bool
    status*: PropertiesDefinitionsStatus
    mdn_url*: PropertiesDefinitionsMdn_url

type
  Properties* = Table[string, PropertiesValue]
# proc enumHook*(s: string;
#                v: var PropertiesValueMediaVariant0) =
#   var PropertiesValueMediaVariant0Table: Table[string,
#       PropertiesValueMediaVariant0] = initTable[string,
#       PropertiesValueMediaVariant0]()
#   PropertiesValueMediaVariant0Table["all"] = PropertiesValueMediaVariant0.pvmvALL
#   PropertiesValueMediaVariant0Table["aural"] = PropertiesValueMediaVariant0.pvmvAURAL
#   PropertiesValueMediaVariant0Table["continuous"] = PropertiesValueMediaVariant0.pvmvCONTINUOUS
#   PropertiesValueMediaVariant0Table["interactive"] = PropertiesValueMediaVariant0.pvmvINTERACTIVE
#   PropertiesValueMediaVariant0Table["none"] = PropertiesValueMediaVariant0.pvmvNONE
#   PropertiesValueMediaVariant0Table["noPracticalMedia"] = PropertiesValueMediaVariant0.pvmvNO_PRACTICAL_MEDIA
#   PropertiesValueMediaVariant0Table["paged"] = PropertiesValueMediaVariant0.pvmvPAGED
#   PropertiesValueMediaVariant0Table["visual"] = PropertiesValueMediaVariant0.pvmvVISUAL
#   PropertiesValueMediaVariant0Table["visualInContinuousMediaNoEffectInOverflowColumns"] = PropertiesValueMediaVariant0.pvmvVISUAL_IN_CONTINUOUS_MEDIA_NO_EFFECT_IN_OVERFLOW_COLUMNS
#   v = PropertiesValueMediaVariant0Table[s]

# proc enumHook*(s: string;
#                v: var PropertiesValueMediaVariant1Item) =
#   var PropertiesValueMediaVariant1ItemTable: Table[string,
#       PropertiesValueMediaVariant1Item] = initTable[string,
#       PropertiesValueMediaVariant1Item]()
#   PropertiesValueMediaVariant1ItemTable["interactive"] = PropertiesValueMediaVariant1Item.pvmviINTERACTIVE
#   PropertiesValueMediaVariant1ItemTable["paged"] = PropertiesValueMediaVariant1Item.pvmviPAGED
#   PropertiesValueMediaVariant1ItemTable["visual"] = PropertiesValueMediaVariant1Item.pvmviVISUAL
#   v = PropertiesValueMediaVariant1ItemTable[s]

# proc enumHook*(s: string; v: var PropertiesDefinitionsOrder) =
#   var PropertiesDefinitionsOrderTable: Table[string, PropertiesDefinitionsOrder] = initTable[
#       string, PropertiesDefinitionsOrder]()
#   PropertiesDefinitionsOrderTable["canonicalOrder"] = PropertiesDefinitionsOrder.pdoCANONICAL_ORDER
#   PropertiesDefinitionsOrderTable["lengthOrPercentageBeforeKeywordIfBothPresent"] = PropertiesDefinitionsOrder.pdoLENGTH_OR_PERCENTAGE_BEFORE_KEYWORD_IF_BOTH_PRESENT
#   PropertiesDefinitionsOrderTable["lengthOrPercentageBeforeKeywords"] = PropertiesDefinitionsOrder.pdoLENGTH_OR_PERCENTAGE_BEFORE_KEYWORDS
#   PropertiesDefinitionsOrderTable["oneOrTwoValuesLengthAbsoluteKeywordsPercentages"] = PropertiesDefinitionsOrder.pdoONE_OR_TWO_VALUES_LENGTH_ABSOLUTE_KEYWORDS_PERCENTAGES
#   PropertiesDefinitionsOrderTable["orderOfAppearance"] = PropertiesDefinitionsOrder.pdoORDER_OF_APPEARANCE
#   PropertiesDefinitionsOrderTable["percentagesOrLengthsFollowedByFill"] = PropertiesDefinitionsOrder.pdoPERCENTAGES_OR_LENGTHS_FOLLOWED_BY_FILL
#   PropertiesDefinitionsOrderTable["perGrammar"] = PropertiesDefinitionsOrder.pdoPER_GRAMMAR
#   PropertiesDefinitionsOrderTable["uniqueOrder"] = PropertiesDefinitionsOrder.pdoUNIQUE_ORDER
#   v = PropertiesDefinitionsOrderTable[s]

# proc enumHook*(s: string;
#                v: var PropertiesDefinitionsPercentages) =
#   var PropertiesDefinitionsPercentagesTable: Table[string,
#       PropertiesDefinitionsPercentages] = initTable[string,
#       PropertiesDefinitionsPercentages]()
#   PropertiesDefinitionsPercentagesTable["blockSizeOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpBLOCK_SIZE_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["dependsOnLayoutModel"] = PropertiesDefinitionsPercentages.pdpDEPENDS_ON_LAYOUT_MODEL
#   PropertiesDefinitionsPercentagesTable["inlineSizeOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpINLINE_SIZE_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["lengthsAsPercentages"] = PropertiesDefinitionsPercentages.pdpLENGTHS_AS_PERCENTAGES
#   PropertiesDefinitionsPercentagesTable["logicalHeightOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpLOGICAL_HEIGHT_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["logicalWidthOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpLOGICAL_WIDTH_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["logicalHeightOrWidthOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpLOGICAL_HEIGHT_OR_WIDTH_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["mapToRange0To1"] = PropertiesDefinitionsPercentages.pdpMAP_TO_RANGE0_TO1
#   PropertiesDefinitionsPercentagesTable["maxZoomFactor"] = PropertiesDefinitionsPercentages.pdpMAX_ZOOM_FACTOR
#   PropertiesDefinitionsPercentagesTable["minZoomFactor"] = PropertiesDefinitionsPercentages.pdpMIN_ZOOM_FACTOR
#   PropertiesDefinitionsPercentagesTable["no"] = PropertiesDefinitionsPercentages.pdpNO
#   PropertiesDefinitionsPercentagesTable["referToBorderBox"] = PropertiesDefinitionsPercentages.pdpREFER_TO_BORDER_BOX
#   PropertiesDefinitionsPercentagesTable["referToContainingBlockHeight"] = PropertiesDefinitionsPercentages.pdpREFER_TO_CONTAINING_BLOCK_HEIGHT
#   PropertiesDefinitionsPercentagesTable["referToDimensionOfBorderBox"] = PropertiesDefinitionsPercentages.pdpREFER_TO_DIMENSION_OF_BORDER_BOX
#   PropertiesDefinitionsPercentagesTable["referToDimensionOfContentArea"] = PropertiesDefinitionsPercentages.pdpREFER_TO_DIMENSION_OF_CONTENT_AREA
#   PropertiesDefinitionsPercentagesTable["referToElementFontSize"] = PropertiesDefinitionsPercentages.pdpREFER_TO_ELEMENT_FONT_SIZE
#   PropertiesDefinitionsPercentagesTable["referToFlexContainersInnerMainSize"] = PropertiesDefinitionsPercentages.pdpREFER_TO_FLEX_CONTAINERS_INNER_MAIN_SIZE
#   PropertiesDefinitionsPercentagesTable["referToHeightOfBackgroundPositioningAreaMinusBackgroundImageHeight"] = PropertiesDefinitionsPercentages.pdpREFER_TO_HEIGHT_OF_BACKGROUND_POSITIONING_AREA_MINUS_BACKGROUND_IMAGE_HEIGHT
#   PropertiesDefinitionsPercentagesTable["referToLineBoxWidth"] = PropertiesDefinitionsPercentages.pdpREFER_TO_LINE_BOX_WIDTH
#   PropertiesDefinitionsPercentagesTable["referToLineHeight"] = PropertiesDefinitionsPercentages.pdpREFER_TO_LINE_HEIGHT
#   PropertiesDefinitionsPercentagesTable["referToParentElementsFontSize"] = PropertiesDefinitionsPercentages.pdpREFER_TO_PARENT_ELEMENTS_FONT_SIZE
#   PropertiesDefinitionsPercentagesTable["referToSizeOfBackgroundPositioningAreaMinusBackgroundImageSize"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_BACKGROUND_POSITIONING_AREA_MINUS_BACKGROUND_IMAGE_SIZE
#   PropertiesDefinitionsPercentagesTable["referToSizeOfBorderImage"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_BORDER_IMAGE
#   PropertiesDefinitionsPercentagesTable["referToSizeOfBoundingBox"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_BOUNDING_BOX
#   PropertiesDefinitionsPercentagesTable["referToSizeOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["referToSizeOfElement"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_ELEMENT
#   PropertiesDefinitionsPercentagesTable["referToSizeOfFont"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_FONT
#   PropertiesDefinitionsPercentagesTable["referToSizeOfMaskBorderImage"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_MASK_BORDER_IMAGE
#   PropertiesDefinitionsPercentagesTable["referToSizeOfMaskPaintingArea"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SIZE_OF_MASK_PAINTING_AREA
#   PropertiesDefinitionsPercentagesTable["referToSVGViewportHeight"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SVGVIEWPORT_HEIGHT
#   PropertiesDefinitionsPercentagesTable["referToSVGViewportSize"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SVGVIEWPORT_SIZE
#   PropertiesDefinitionsPercentagesTable["referToSVGViewportWidth"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SVGVIEWPORT_WIDTH
#   PropertiesDefinitionsPercentagesTable["referToSVGViewportDiagonal"] = PropertiesDefinitionsPercentages.pdpREFER_TO_SVGVIEWPORT_DIAGONAL
#   PropertiesDefinitionsPercentagesTable["referToTotalPathLength"] = PropertiesDefinitionsPercentages.pdpREFER_TO_TOTAL_PATH_LENGTH
#   PropertiesDefinitionsPercentagesTable["referToWidthAndHeightOfElement"] = PropertiesDefinitionsPercentages.pdpREFER_TO_WIDTH_AND_HEIGHT_OF_ELEMENT
#   PropertiesDefinitionsPercentagesTable["referToWidthOfAffectedGlyph"] = PropertiesDefinitionsPercentages.pdpREFER_TO_WIDTH_OF_AFFECTED_GLYPH
#   PropertiesDefinitionsPercentagesTable["referToWidthOfBackgroundPositioningAreaMinusBackgroundImageWidth"] = PropertiesDefinitionsPercentages.pdpREFER_TO_WIDTH_OF_BACKGROUND_POSITIONING_AREA_MINUS_BACKGROUND_IMAGE_WIDTH
#   PropertiesDefinitionsPercentagesTable["referToWidthOfContainingBlock"] = PropertiesDefinitionsPercentages.pdpREFER_TO_WIDTH_OF_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["referToWidthOrHeightOfBorderImageArea"] = PropertiesDefinitionsPercentages.pdpREFER_TO_WIDTH_OR_HEIGHT_OF_BORDER_IMAGE_AREA
#   PropertiesDefinitionsPercentagesTable["referToReferenceBoxWhenSpecifiedOtherwiseBorderBox"] = PropertiesDefinitionsPercentages.pdpREFER_TO_REFERENCE_BOX_WHEN_SPECIFIED_OTHERWISE_BORDER_BOX
#   PropertiesDefinitionsPercentagesTable["regardingHeightOfGeneratedBoxContainingBlockPercentages0"] = PropertiesDefinitionsPercentages.pdpREGARDING_HEIGHT_OF_GENERATED_BOX_CONTAINING_BLOCK_PERCENTAGES0
#   PropertiesDefinitionsPercentagesTable["regardingHeightOfGeneratedBoxContainingBlockPercentagesNone"] = PropertiesDefinitionsPercentages.pdpREGARDING_HEIGHT_OF_GENERATED_BOX_CONTAINING_BLOCK_PERCENTAGES_NONE
#   PropertiesDefinitionsPercentagesTable["regardingHeightOfGeneratedBoxContainingBlockPercentagesRelativeToContainingBlock"] = PropertiesDefinitionsPercentages.pdpREGARDING_HEIGHT_OF_GENERATED_BOX_CONTAINING_BLOCK_PERCENTAGES_RELATIVE_TO_CONTAINING_BLOCK
#   PropertiesDefinitionsPercentagesTable["relativeToBackgroundPositioningArea"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_BACKGROUND_POSITIONING_AREA
#   PropertiesDefinitionsPercentagesTable["relativeToCorrespondingDimensionOfRelevantScrollport"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_CORRESPONDING_DIMENSION_OF_RELEVANT_SCROLLPORT
#   PropertiesDefinitionsPercentagesTable["relativeToMaskBorderImageArea"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_MASK_BORDER_IMAGE_AREA
#   PropertiesDefinitionsPercentagesTable["relativeToScrollContainerPaddingBoxAxis"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_SCROLL_CONTAINER_PADDING_BOX_AXIS
#   PropertiesDefinitionsPercentagesTable["relativeToTheScrollContainersScrollport"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_THE_SCROLL_CONTAINERS_SCROLLPORT
#   PropertiesDefinitionsPercentagesTable["relativeToTimelineRangeIfSpecifiedOtherwiseEntireTimeline"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_TIMELINE_RANGE_IF_SPECIFIED_OTHERWISE_ENTIRE_TIMELINE
#   PropertiesDefinitionsPercentagesTable["relativeToWidthAndHeight"] = PropertiesDefinitionsPercentages.pdpRELATIVE_TO_WIDTH_AND_HEIGHT
#   v = PropertiesDefinitionsPercentagesTable[s]

# proc enumHook*(s: string;
#                v: var PropertiesDefinitionsComputed) =
#   var PropertiesDefinitionsComputedTable: Table[string,
#       PropertiesDefinitionsComputed] = initTable[string,
#       PropertiesDefinitionsComputed]()
#   PropertiesDefinitionsComputedTable["absoluteLength"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH
#   PropertiesDefinitionsComputedTable["absoluteLength0ForNone"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH0_FOR_NONE
#   PropertiesDefinitionsComputedTable["absoluteLength0IfColumnRuleStyleNoneOrHidden"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH0_IF_COLUMN_RULE_STYLE_NONE_OR_HIDDEN
#   PropertiesDefinitionsComputedTable["absoluteLengthOr0IfBorderBottomStyleNoneOrHidden"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR0_IF_BORDER_BOTTOM_STYLE_NONE_OR_HIDDEN
#   PropertiesDefinitionsComputedTable["absoluteLengthOr0IfBorderLeftStyleNoneOrHidden"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR0_IF_BORDER_LEFT_STYLE_NONE_OR_HIDDEN
#   PropertiesDefinitionsComputedTable["absoluteLengthOr0IfBorderRightStyleNoneOrHidden"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR0_IF_BORDER_RIGHT_STYLE_NONE_OR_HIDDEN
#   PropertiesDefinitionsComputedTable["absoluteLengthOr0IfBorderTopStyleNoneOrHidden"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR0_IF_BORDER_TOP_STYLE_NONE_OR_HIDDEN
#   PropertiesDefinitionsComputedTable["absoluteLengthOrAsSpecified"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR_AS_SPECIFIED
#   PropertiesDefinitionsComputedTable["absoluteLengthOrKeyword"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR_KEYWORD
#   PropertiesDefinitionsComputedTable["absoluteLengthOrNone"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR_NONE
#   PropertiesDefinitionsComputedTable["absoluteLengthOrNormal"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR_NORMAL
#   PropertiesDefinitionsComputedTable["absoluteLengthOrPercentage"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR_PERCENTAGE
#   PropertiesDefinitionsComputedTable["absoluteLengthOrPercentageNumbersConverted"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_OR_PERCENTAGE_NUMBERS_CONVERTED
#   PropertiesDefinitionsComputedTable["absoluteLengthsSpecifiedColorAsSpecified"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTHS_SPECIFIED_COLOR_AS_SPECIFIED
#   PropertiesDefinitionsComputedTable["absoluteLengthZeroIfBorderStyleNoneOrHidden"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_ZERO_IF_BORDER_STYLE_NONE_OR_HIDDEN
#   PropertiesDefinitionsComputedTable["absoluteLengthZeroOrLarger"] = PropertiesDefinitionsComputed.pdcABSOLUTE_LENGTH_ZERO_OR_LARGER
#   PropertiesDefinitionsComputedTable["absoluteURIOrNone"] = PropertiesDefinitionsComputed.pdcABSOLUTE_URIOR_NONE
#   PropertiesDefinitionsComputedTable["angleRoundedToNextQuarter"] = PropertiesDefinitionsComputed.pdcANGLE_ROUNDED_TO_NEXT_QUARTER
#   PropertiesDefinitionsComputedTable["asAutoOrColor"] = PropertiesDefinitionsComputed.pdcAS_AUTO_OR_COLOR
#   PropertiesDefinitionsComputedTable["asColorOrAbsoluteURL"] = PropertiesDefinitionsComputed.pdcAS_COLOR_OR_ABSOLUTE_URL
#   PropertiesDefinitionsComputedTable["asDefinedForBasicShapeWithAbsoluteURIOtherwiseAsSpecified"] = PropertiesDefinitionsComputed.pdcAS_DEFINED_FOR_BASIC_SHAPE_WITH_ABSOLUTE_URIOTHERWISE_AS_SPECIFIED
#   PropertiesDefinitionsComputedTable["asLength"] = PropertiesDefinitionsComputed.pdcAS_LENGTH
#   PropertiesDefinitionsComputedTable["asLonghands"] = PropertiesDefinitionsComputed.pdcAS_LONGHANDS
#   PropertiesDefinitionsComputedTable["asSpecified"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED
#   PropertiesDefinitionsComputedTable["asSpecifiedAppliesToEachProperty"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_APPLIES_TO_EACH_PROPERTY
#   PropertiesDefinitionsComputedTable["asSpecifiedButVisibleOrClipReplacedToAutoOrHiddenIfOtherValueDifferent"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_BUT_VISIBLE_OR_CLIP_REPLACED_TO_AUTO_OR_HIDDEN_IF_OTHER_VALUE_DIFFERENT
#   PropertiesDefinitionsComputedTable["asSpecifiedExceptMatchParent"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_EXCEPT_MATCH_PARENT
#   PropertiesDefinitionsComputedTable["asSpecifiedExceptPositionedFloatingAndRootElementsKeywordMaybeDifferent"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_EXCEPT_POSITIONED_FLOATING_AND_ROOT_ELEMENTS_KEYWORD_MAYBE_DIFFERENT
#   PropertiesDefinitionsComputedTable["asSpecifiedRelativeToAbsoluteLengths"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_RELATIVE_TO_ABSOLUTE_LENGTHS
#   PropertiesDefinitionsComputedTable["asSpecifiedURLsAbsolute"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_URLS_ABSOLUTE
#   PropertiesDefinitionsComputedTable["asSpecifiedWithExceptionOfResolution"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_WITH_EXCEPTION_OF_RESOLUTION
#   PropertiesDefinitionsComputedTable["asSpecifiedWithLengthsAbsoluteAndNormalComputingToZeroExceptMultiColumn"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_WITH_LENGTHS_ABSOLUTE_AND_NORMAL_COMPUTING_TO_ZERO_EXCEPT_MULTI_COLUMN
#   PropertiesDefinitionsComputedTable["asSpecifiedWithLengthValuesComputed"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_WITH_LENGTH_VALUES_COMPUTED
#   PropertiesDefinitionsComputedTable["asSpecifiedWithVarsSubstituted"] = PropertiesDefinitionsComputed.pdcAS_SPECIFIED_WITH_VARS_SUBSTITUTED
#   PropertiesDefinitionsComputedTable["autoOnAbsolutelyPositionedElementsValueOfAlignItemsOnParent"] = PropertiesDefinitionsComputed.pdcAUTO_ON_ABSOLUTELY_POSITIONED_ELEMENTS_VALUE_OF_ALIGN_ITEMS_ON_PARENT
#   PropertiesDefinitionsComputedTable["autoOrRectangle"] = PropertiesDefinitionsComputed.pdcAUTO_OR_RECTANGLE
#   PropertiesDefinitionsComputedTable["colorPlusThreeAbsoluteLengths"] = PropertiesDefinitionsComputed.pdcCOLOR_PLUS_THREE_ABSOLUTE_LENGTHS
#   PropertiesDefinitionsComputedTable["computedColor"] = PropertiesDefinitionsComputed.pdcCOMPUTED_COLOR
#   PropertiesDefinitionsComputedTable["consistsOfTwoDimensionKeywords"] = PropertiesDefinitionsComputed.pdcCONSISTS_OF_TWO_DIMENSION_KEYWORDS
#   PropertiesDefinitionsComputedTable["consistsOfTwoKeywordsForOriginAndOffsets"] = PropertiesDefinitionsComputed.pdcCONSISTS_OF_TWO_KEYWORDS_FOR_ORIGIN_AND_OFFSETS
#   PropertiesDefinitionsComputedTable["forLengthAbsoluteValueOtherwisePercentage"] = PropertiesDefinitionsComputed.pdcFOR_LENGTH_ABSOLUTE_VALUE_OTHERWISE_PERCENTAGE
#   PropertiesDefinitionsComputedTable["autoForTranslucentColorRGBAOtherwiseRGB"] = PropertiesDefinitionsComputed.pdcAUTO_FOR_TRANSLUCENT_COLOR_RGBAOTHERWISE_RGB
#   PropertiesDefinitionsComputedTable["keywordOrNumericalValueBolderLighterTransformedToRealValue"] = PropertiesDefinitionsComputed.pdcKEYWORD_OR_NUMERICAL_VALUE_BOLDER_LIGHTER_TRANSFORMED_TO_REAL_VALUE
#   PropertiesDefinitionsComputedTable["keywordPlusIntegerIfDigits"] = PropertiesDefinitionsComputed.pdcKEYWORD_PLUS_INTEGER_IF_DIGITS
#   PropertiesDefinitionsComputedTable["lengthAbsolutePercentageAsSpecifiedOtherwiseAuto"] = PropertiesDefinitionsComputed.pdcLENGTH_ABSOLUTE_PERCENTAGE_AS_SPECIFIED_OTHERWISE_AUTO
#   PropertiesDefinitionsComputedTable["listEachItemConsistingOfAbsoluteLengthPercentageAndOrigin"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_CONSISTING_OF_ABSOLUTE_LENGTH_PERCENTAGE_AND_ORIGIN
#   PropertiesDefinitionsComputedTable["listEachItemConsistingOfAbsoluteLengthPercentageOrKeyword"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_CONSISTING_OF_ABSOLUTE_LENGTH_PERCENTAGE_OR_KEYWORD
#   PropertiesDefinitionsComputedTable["listEachItemConsistingOfNormalLengthPercentageOrNameLengthPercentage"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_CONSISTING_OF_NORMAL_LENGTH_PERCENTAGE_OR_NAME_LENGTH_PERCENTAGE
#   PropertiesDefinitionsComputedTable["listEachItemConsistingOfPairsOfAutoOrLengthPercentage"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_CONSISTING_OF_PAIRS_OF_AUTO_OR_LENGTH_PERCENTAGE
#   PropertiesDefinitionsComputedTable["listEachItemHasTwoKeywordsOnePerDimension"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_HAS_TWO_KEYWORDS_ONE_PER_DIMENSION
#   PropertiesDefinitionsComputedTable["listEachItemIdentifierOrNoneAuto"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_IDENTIFIER_OR_NONE_AUTO
#   PropertiesDefinitionsComputedTable["listEachItemTwoKeywordsOriginOffsets"] = PropertiesDefinitionsComputed.pdcLIST_EACH_ITEM_TWO_KEYWORDS_ORIGIN_OFFSETS
#   PropertiesDefinitionsComputedTable["noneOrImageWithAbsoluteURI"] = PropertiesDefinitionsComputed.pdcNONE_OR_IMAGE_WITH_ABSOLUTE_URI
#   PropertiesDefinitionsComputedTable["noneOrOrderedListOfIdentifiers"] = PropertiesDefinitionsComputed.pdcNONE_OR_ORDERED_LIST_OF_IDENTIFIERS
#   PropertiesDefinitionsComputedTable["normalizedAngle"] = PropertiesDefinitionsComputed.pdcNORMALIZED_ANGLE
#   PropertiesDefinitionsComputedTable["normalOnElementsForPseudosNoneAbsoluteURIStringOrAsSpecified"] = PropertiesDefinitionsComputed.pdcNORMAL_ON_ELEMENTS_FOR_PSEUDOS_NONE_ABSOLUTE_URISTRING_OR_AS_SPECIFIED
#   PropertiesDefinitionsComputedTable["oneToFourPercentagesOrAbsoluteLengthsPlusFill"] = PropertiesDefinitionsComputed.pdcONE_TO_FOUR_PERCENTAGES_OR_ABSOLUTE_LENGTHS_PLUS_FILL
#   PropertiesDefinitionsComputedTable["optimumValueOfAbsoluteLengthOrNormal"] = PropertiesDefinitionsComputed.pdcOPTIMUM_VALUE_OF_ABSOLUTE_LENGTH_OR_NORMAL
#   PropertiesDefinitionsComputedTable["percentageAsSpecifiedAbsoluteLengthOrNone"] = PropertiesDefinitionsComputed.pdcPERCENTAGE_AS_SPECIFIED_ABSOLUTE_LENGTH_OR_NONE
#   PropertiesDefinitionsComputedTable["percentageAsSpecifiedOrAbsoluteLength"] = PropertiesDefinitionsComputed.pdcPERCENTAGE_AS_SPECIFIED_OR_ABSOLUTE_LENGTH
#   PropertiesDefinitionsComputedTable["percentageAutoOrAbsoluteLength"] = PropertiesDefinitionsComputed.pdcPERCENTAGE_AUTO_OR_ABSOLUTE_LENGTH
#   PropertiesDefinitionsComputedTable["percentageOrAbsoluteLengthPlusKeywords"] = PropertiesDefinitionsComputed.pdcPERCENTAGE_OR_ABSOLUTE_LENGTH_PLUS_KEYWORDS
#   PropertiesDefinitionsComputedTable["sameAsBoxOffsets"] = PropertiesDefinitionsComputed.pdcSAME_AS_BOX_OFFSETS
#   PropertiesDefinitionsComputedTable["sameAsMaxWidthAndMaxHeight"] = PropertiesDefinitionsComputed.pdcSAME_AS_MAX_WIDTH_AND_MAX_HEIGHT
#   PropertiesDefinitionsComputedTable["sameAsMinWidthAndMinHeight"] = PropertiesDefinitionsComputed.pdcSAME_AS_MIN_WIDTH_AND_MIN_HEIGHT
#   PropertiesDefinitionsComputedTable["sameAsWidthAndHeight"] = PropertiesDefinitionsComputed.pdcSAME_AS_WIDTH_AND_HEIGHT
#   PropertiesDefinitionsComputedTable["specifiedIntegerOrAbsoluteLength"] = PropertiesDefinitionsComputed.pdcSPECIFIED_INTEGER_OR_ABSOLUTE_LENGTH
#   PropertiesDefinitionsComputedTable["specifiedValue"] = PropertiesDefinitionsComputed.pdcSPECIFIED_VALUE
#   PropertiesDefinitionsComputedTable["specifiedValueClipped0To1"] = PropertiesDefinitionsComputed.pdcSPECIFIED_VALUE_CLIPPED0_TO1
#   PropertiesDefinitionsComputedTable["specifiedValueNumberClipped0To1"] = PropertiesDefinitionsComputed.pdcSPECIFIED_VALUE_NUMBER_CLIPPED0_TO1
#   PropertiesDefinitionsComputedTable["theComputedLengthAndVisualBox"] = PropertiesDefinitionsComputed.pdcTHE_COMPUTED_LENGTH_AND_VISUAL_BOX
#   PropertiesDefinitionsComputedTable["theKeywordListStyleImageNoneOrComputedValue"] = PropertiesDefinitionsComputed.pdcTHE_KEYWORD_LIST_STYLE_IMAGE_NONE_OR_COMPUTED_VALUE
#   PropertiesDefinitionsComputedTable["theSpecifiedKeyword"] = PropertiesDefinitionsComputed.pdcTHE_SPECIFIED_KEYWORD
#   PropertiesDefinitionsComputedTable["translucentValuesRGBAOtherwiseRGB"] = PropertiesDefinitionsComputed.pdcTRANSLUCENT_VALUES_RGBAOTHERWISE_RGB
#   PropertiesDefinitionsComputedTable["twoAbsoluteLengthOrPercentages"] = PropertiesDefinitionsComputed.pdcTWO_ABSOLUTE_LENGTH_OR_PERCENTAGES
#   PropertiesDefinitionsComputedTable["twoAbsoluteLengths"] = PropertiesDefinitionsComputed.pdcTWO_ABSOLUTE_LENGTHS
#   v = PropertiesDefinitionsComputedTable[s]

# proc enumHook*(s: string;
#                v: var PropertiesDefinitionsAppliesto) =
#   var PropertiesDefinitionsAppliestoTable: Table[string,
#       PropertiesDefinitionsAppliesto] = initTable[string,
#       PropertiesDefinitionsAppliesto]()
#   PropertiesDefinitionsAppliestoTable["absolutelyPositionedElements"] = PropertiesDefinitionsAppliesto.pdaABSOLUTELY_POSITIONED_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["allElements"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["allElementsAcceptingWidthOrHeight"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_ACCEPTING_WIDTH_OR_HEIGHT
#   PropertiesDefinitionsAppliestoTable["allElementsAndPseudos"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_AND_PSEUDOS
#   PropertiesDefinitionsAppliestoTable["allElementsAndText"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_AND_TEXT
#   PropertiesDefinitionsAppliestoTable["allElementsButNonReplacedAndTableColumns"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_BUT_NON_REPLACED_AND_TABLE_COLUMNS
#   PropertiesDefinitionsAppliestoTable["allElementsButNonReplacedAndTableRows"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_BUT_NON_REPLACED_AND_TABLE_ROWS
#   PropertiesDefinitionsAppliestoTable["allElementsCreatingNativeWindows"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_CREATING_NATIVE_WINDOWS
#   PropertiesDefinitionsAppliestoTable["allElementsExceptGeneratedContentOrPseudoElements"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_GENERATED_CONTENT_OR_PSEUDO_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["allElementsExceptInlineBoxesAndInternalRubyOrTableBoxes"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_INLINE_BOXES_AND_INTERNAL_RUBY_OR_TABLE_BOXES
#   PropertiesDefinitionsAppliestoTable["allElementsExceptInternalTableDisplayTypes"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_INTERNAL_TABLE_DISPLAY_TYPES
#   PropertiesDefinitionsAppliestoTable["allElementsExceptNonReplacedInlineElementsTableRowsColumnsRowColumnGroups"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_NON_REPLACED_INLINE_ELEMENTS_TABLE_ROWS_COLUMNS_ROW_COLUMN_GROUPS
#   PropertiesDefinitionsAppliestoTable["allElementsExceptTableDisplayTypes"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_TABLE_DISPLAY_TYPES
#   PropertiesDefinitionsAppliestoTable["allElementsExceptTableElementsWhenCollapse"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_TABLE_ELEMENTS_WHEN_COLLAPSE
#   PropertiesDefinitionsAppliestoTable["allElementsExceptTableRowColumnGroupsTableRowsColumns"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_TABLE_ROW_COLUMN_GROUPS_TABLE_ROWS_COLUMNS
#   PropertiesDefinitionsAppliestoTable["allElementsExceptTableRowGroupsRowsColumnGroupsAndColumns"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_EXCEPT_TABLE_ROW_GROUPS_ROWS_COLUMN_GROUPS_AND_COLUMNS
#   PropertiesDefinitionsAppliestoTable["allElementsNoEffectIfDisplayNone"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_NO_EFFECT_IF_DISPLAY_NONE
#   PropertiesDefinitionsAppliestoTable["allElementsSomeValuesNoEffectOnNonInlineElements"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_SOME_VALUES_NO_EFFECT_ON_NON_INLINE_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["allElementsSVGContainerElements"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_SVGCONTAINER_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["allElementsSVGContainerGraphicsAndGraphicsReferencingElements"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_SVGCONTAINER_GRAPHICS_AND_GRAPHICS_REFERENCING_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["allElementsThatCanReferenceImages"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_THAT_CAN_REFERENCE_IMAGES
#   PropertiesDefinitionsAppliestoTable["allElementsThatGenerateAPrincipalBox"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_THAT_GENERATE_APRINCIPAL_BOX
#   PropertiesDefinitionsAppliestoTable["allElementsTreeAbidingPseudoElementsPageMarginBoxes"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_TREE_ABIDING_PSEUDO_ELEMENTS_PAGE_MARGIN_BOXES
#   PropertiesDefinitionsAppliestoTable["allElementsUAsNotRequiredWhenCollapse"] = PropertiesDefinitionsAppliesto.pdaALL_ELEMENTS_UAS_NOT_REQUIRED_WHEN_COLLAPSE
#   PropertiesDefinitionsAppliestoTable["anyElementEffectOnProgressAndMeter"] = PropertiesDefinitionsAppliesto.pdaANY_ELEMENT_EFFECT_ON_PROGRESS_AND_METER
#   PropertiesDefinitionsAppliestoTable["asLonghands"] = PropertiesDefinitionsAppliesto.pdaAS_LONGHANDS
#   PropertiesDefinitionsAppliestoTable["beforeAndAfterPseudos"] = PropertiesDefinitionsAppliesto.pdaBEFORE_AND_AFTER_PSEUDOS
#   PropertiesDefinitionsAppliestoTable["blockContainerElements"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINER_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["blockContainers"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["blockContainersAndInlineBoxes"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_AND_INLINE_BOXES
#   PropertiesDefinitionsAppliestoTable["blockContainersAndMultiColumnContainers"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_AND_MULTI_COLUMN_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["blockContainersExceptMultiColumnContainers"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_EXCEPT_MULTI_COLUMN_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["blockContainersExceptTableWrappers"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_EXCEPT_TABLE_WRAPPERS
#   PropertiesDefinitionsAppliestoTable["blockContainersFlexContainersGridContainers"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_FLEX_CONTAINERS_GRID_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["blockContainersFlexContainersGridContainersInlineBoxesTableRowsSVGTextContentElements"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_FLEX_CONTAINERS_GRID_CONTAINERS_INLINE_BOXES_TABLE_ROWS_SVGTEXT_CONTENT_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["blockContainersMultiColumnContainersFlexContainersGridContainers"] = PropertiesDefinitionsAppliesto.pdaBLOCK_CONTAINERS_MULTI_COLUMN_CONTAINERS_FLEX_CONTAINERS_GRID_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["blockElementsInNormalFlow"] = PropertiesDefinitionsAppliesto.pdaBLOCK_ELEMENTS_IN_NORMAL_FLOW
#   PropertiesDefinitionsAppliestoTable["blockLevelElements"] = PropertiesDefinitionsAppliesto.pdaBLOCK_LEVEL_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["blockLevelBoxesAndAbsolutelyPositionedBoxesAndGridItems"] = PropertiesDefinitionsAppliesto.pdaBLOCK_LEVEL_BOXES_AND_ABSOLUTELY_POSITIONED_BOXES_AND_GRID_ITEMS
#   PropertiesDefinitionsAppliestoTable["boxElements"] = PropertiesDefinitionsAppliesto.pdaBOX_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["childrenOfBoxElements"] = PropertiesDefinitionsAppliesto.pdaCHILDREN_OF_BOX_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["directChildrenOfElementsWithDisplayMozBoxMozInlineBox"] = PropertiesDefinitionsAppliesto.pdaDIRECT_CHILDREN_OF_ELEMENTS_WITH_DISPLAY_MOZ_BOX_MOZ_INLINE_BOX
#   PropertiesDefinitionsAppliestoTable["elementsForWhichLayoutContainmentCanApply"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_FOR_WHICH_LAYOUT_CONTAINMENT_CAN_APPLY
#   PropertiesDefinitionsAppliestoTable["elementsForWhichSizeContainmentCanApply"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_FOR_WHICH_SIZE_CONTAINMENT_CAN_APPLY
#   PropertiesDefinitionsAppliestoTable["elementsThatAcceptInput"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_THAT_ACCEPT_INPUT
#   PropertiesDefinitionsAppliestoTable["elementsWithDefaultPreferredSize"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_WITH_DEFAULT_PREFERRED_SIZE
#   PropertiesDefinitionsAppliestoTable["elementsWithDisplayBoxOrInlineBox"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_WITH_DISPLAY_BOX_OR_INLINE_BOX
#   PropertiesDefinitionsAppliestoTable["elementsWithDisplayMarker"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_WITH_DISPLAY_MARKER
#   PropertiesDefinitionsAppliestoTable["elementsWithDisplayMozBoxMozInlineBox"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_WITH_DISPLAY_MOZ_BOX_MOZ_INLINE_BOX
#   PropertiesDefinitionsAppliestoTable["elementsWithOverflowNotVisibleAndReplacedElements"] = PropertiesDefinitionsAppliesto.pdaELEMENTS_WITH_OVERFLOW_NOT_VISIBLE_AND_REPLACED_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["exclusionElements"] = PropertiesDefinitionsAppliesto.pdaEXCLUSION_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["firstLetterPseudoElementsAndInlineLevelFirstChildren"] = PropertiesDefinitionsAppliesto.pdaFIRST_LETTER_PSEUDO_ELEMENTS_AND_INLINE_LEVEL_FIRST_CHILDREN
#   PropertiesDefinitionsAppliestoTable["flexContainers"] = PropertiesDefinitionsAppliesto.pdaFLEX_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["flexItemsAndAbsolutelyPositionedFlexContainerChildren"] = PropertiesDefinitionsAppliesto.pdaFLEX_ITEMS_AND_ABSOLUTELY_POSITIONED_FLEX_CONTAINER_CHILDREN
#   PropertiesDefinitionsAppliestoTable["flexItemsAndInFlowPseudos"] = PropertiesDefinitionsAppliesto.pdaFLEX_ITEMS_AND_IN_FLOW_PSEUDOS
#   PropertiesDefinitionsAppliestoTable["flexItemsGridItemsAbsolutelyPositionedContainerChildren"] = PropertiesDefinitionsAppliesto.pdaFLEX_ITEMS_GRID_ITEMS_ABSOLUTELY_POSITIONED_CONTAINER_CHILDREN
#   PropertiesDefinitionsAppliestoTable["flexItemsGridItemsAndAbsolutelyPositionedBoxes"] = PropertiesDefinitionsAppliesto.pdaFLEX_ITEMS_GRID_ITEMS_AND_ABSOLUTELY_POSITIONED_BOXES
#   PropertiesDefinitionsAppliestoTable["floats"] = PropertiesDefinitionsAppliesto.pdaFLOATS
#   PropertiesDefinitionsAppliestoTable["gridContainers"] = PropertiesDefinitionsAppliesto.pdaGRID_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["gridContainersWithMasonryLayout"] = PropertiesDefinitionsAppliesto.pdaGRID_CONTAINERS_WITH_MASONRY_LAYOUT
#   PropertiesDefinitionsAppliestoTable["gridContainersWithMasonryLayoutInTheirBlockAxis"] = PropertiesDefinitionsAppliesto.pdaGRID_CONTAINERS_WITH_MASONRY_LAYOUT_IN_THEIR_BLOCK_AXIS
#   PropertiesDefinitionsAppliestoTable["gridContainersWithMasonryLayoutInTheirInlineAxis"] = PropertiesDefinitionsAppliesto.pdaGRID_CONTAINERS_WITH_MASONRY_LAYOUT_IN_THEIR_INLINE_AXIS
#   PropertiesDefinitionsAppliestoTable["gridItemsAndBoxesWithinGridContainer"] = PropertiesDefinitionsAppliesto.pdaGRID_ITEMS_AND_BOXES_WITHIN_GRID_CONTAINER
#   PropertiesDefinitionsAppliestoTable["iframeElements"] = PropertiesDefinitionsAppliesto.pdaIFRAME_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["images"] = PropertiesDefinitionsAppliesto.pdaIMAGES
#   PropertiesDefinitionsAppliestoTable["inFlowBlockLevelElements"] = PropertiesDefinitionsAppliesto.pdaIN_FLOW_BLOCK_LEVEL_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["inFlowChildrenOfBoxElements"] = PropertiesDefinitionsAppliesto.pdaIN_FLOW_CHILDREN_OF_BOX_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["inlineBoxesAndBlockContainers"] = PropertiesDefinitionsAppliesto.pdaINLINE_BOXES_AND_BLOCK_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["inlineLevelAndTableCellElements"] = PropertiesDefinitionsAppliesto.pdaINLINE_LEVEL_AND_TABLE_CELL_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["limitedSVGElements"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsCircle"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_CIRCLE
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsEllipse"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_ELLIPSE
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsEllipseRect"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_ELLIPSE_RECT
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsFilterPrimitives"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_FILTER_PRIMITIVES
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsFloodAndDropShadow"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_FLOOD_AND_DROP_SHADOW
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsGeometry"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_GEOMETRY
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsGraphics"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_GRAPHICS
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsGraphicsAndUse"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_GRAPHICS_AND_USE
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsLightSource"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_LIGHT_SOURCE
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsPath"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_PATH
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsShapes"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_SHAPES
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsShapesAndTextContent"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_SHAPES_AND_TEXT_CONTENT
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsShapeText"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_SHAPE_TEXT
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsStop"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_STOP
#   PropertiesDefinitionsAppliestoTable["limitedSVGElementsTextContent"] = PropertiesDefinitionsAppliesto.pdaLIMITED_SVGELEMENTS_TEXT_CONTENT
#   PropertiesDefinitionsAppliestoTable["listItems"] = PropertiesDefinitionsAppliesto.pdaLIST_ITEMS
#   PropertiesDefinitionsAppliestoTable["maskElements"] = PropertiesDefinitionsAppliesto.pdaMASK_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["multicolElements"] = PropertiesDefinitionsAppliesto.pdaMULTICOL_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["multiColumnElementsFlexContainersGridContainers"] = PropertiesDefinitionsAppliesto.pdaMULTI_COLUMN_ELEMENTS_FLEX_CONTAINERS_GRID_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["multilineFlexContainers"] = PropertiesDefinitionsAppliesto.pdaMULTILINE_FLEX_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["nonReplacedBlockAndInlineBlockElements"] = PropertiesDefinitionsAppliesto.pdaNON_REPLACED_BLOCK_AND_INLINE_BLOCK_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["nonReplacedBlockElements"] = PropertiesDefinitionsAppliesto.pdaNON_REPLACED_BLOCK_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["nonReplacedElements"] = PropertiesDefinitionsAppliesto.pdaNON_REPLACED_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["nonReplacedInlineElements"] = PropertiesDefinitionsAppliesto.pdaNON_REPLACED_INLINE_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["positionedElements"] = PropertiesDefinitionsAppliesto.pdaPOSITIONED_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["positionedElementsWithADefaultAnchorElement"] = PropertiesDefinitionsAppliesto.pdaPOSITIONED_ELEMENTS_WITH_ADEFAULT_ANCHOR_ELEMENT
#   PropertiesDefinitionsAppliestoTable["replacedElements"] = PropertiesDefinitionsAppliesto.pdaREPLACED_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["rubyAnnotationsContainers"] = PropertiesDefinitionsAppliesto.pdaRUBY_ANNOTATIONS_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["rubyBasesAnnotationsBaseAnnotationContainers"] = PropertiesDefinitionsAppliesto.pdaRUBY_BASES_ANNOTATIONS_BASE_ANNOTATION_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["sameAsMargin"] = PropertiesDefinitionsAppliesto.pdaSAME_AS_MARGIN
#   PropertiesDefinitionsAppliestoTable["sameAsWidthAndHeight"] = PropertiesDefinitionsAppliesto.pdaSAME_AS_WIDTH_AND_HEIGHT
#   PropertiesDefinitionsAppliestoTable["scrollContainers"] = PropertiesDefinitionsAppliesto.pdaSCROLL_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["scrollingBoxes"] = PropertiesDefinitionsAppliesto.pdaSCROLLING_BOXES
#   PropertiesDefinitionsAppliestoTable["tableCaptionElements"] = PropertiesDefinitionsAppliesto.pdaTABLE_CAPTION_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["tableCellElements"] = PropertiesDefinitionsAppliesto.pdaTABLE_CELL_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["tableElements"] = PropertiesDefinitionsAppliesto.pdaTABLE_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["textAndBlockContainers"] = PropertiesDefinitionsAppliesto.pdaTEXT_AND_BLOCK_CONTAINERS
#   PropertiesDefinitionsAppliestoTable["textElements"] = PropertiesDefinitionsAppliesto.pdaTEXT_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["textFields"] = PropertiesDefinitionsAppliesto.pdaTEXT_FIELDS
#   PropertiesDefinitionsAppliestoTable["transformableElements"] = PropertiesDefinitionsAppliesto.pdaTRANSFORMABLE_ELEMENTS
#   PropertiesDefinitionsAppliestoTable["xulImageElements"] = PropertiesDefinitionsAppliesto.pdaXUL_IMAGE_ELEMENTS
#   v = PropertiesDefinitionsAppliestoTable[s]

# proc enumHook*(s: string;
#                v: var PropertiesDefinitionsAlsoApplyToItem) =
#   var PropertiesDefinitionsAlsoApplyToItemTable: Table[string,
#       PropertiesDefinitionsAlsoApplyToItem] = initTable[string,
#       PropertiesDefinitionsAlsoApplyToItem]()
#   PropertiesDefinitionsAlsoApplyToItemTable["::first-letter"] = PropertiesDefinitionsAlsoApplyToItem.pdaatiFIRST_LETTER
#   PropertiesDefinitionsAlsoApplyToItemTable["::first-line"] = PropertiesDefinitionsAlsoApplyToItem.pdaatiFIRST_LINE
#   PropertiesDefinitionsAlsoApplyToItemTable["::placeholder"] = PropertiesDefinitionsAlsoApplyToItem.pdaatiPLACEHOLDER
#   v = PropertiesDefinitionsAlsoApplyToItemTable[s]

# proc enumHook*(s: string; v: var PropertiesDefinitionsStatus) =
#   var PropertiesDefinitionsStatusTable: Table[string,
#       PropertiesDefinitionsStatus] = initTable[string,
#       PropertiesDefinitionsStatus]()
#   PropertiesDefinitionsStatusTable["standard"] = PropertiesDefinitionsStatus.pdsSTANDARD
#   PropertiesDefinitionsStatusTable["nonstandard"] = PropertiesDefinitionsStatus.pdsNONSTANDARD
#   PropertiesDefinitionsStatusTable["experimental"] = PropertiesDefinitionsStatus.pdsEXPERIMENTAL
#   PropertiesDefinitionsStatusTable["obsolete"] = PropertiesDefinitionsStatus.pdsOBSOLETE
#   v = PropertiesDefinitionsStatusTable[s]

# proc enumHook*(s: string;
#                v: var PropertiesDefinitionsAnimationType) =
#   var PropertiesDefinitionsAnimationTypeTable: Table[string,
#       PropertiesDefinitionsAnimationType] = initTable[string,
#       PropertiesDefinitionsAnimationType]()
#   PropertiesDefinitionsAnimationTypeTable["angleBasicShapeOrPath"] = PropertiesDefinitionsAnimationType.pdatANGLE_BASIC_SHAPE_OR_PATH
#   PropertiesDefinitionsAnimationTypeTable["angleOrBasicShapeOrPath"] = PropertiesDefinitionsAnimationType.pdatANGLE_OR_BASIC_SHAPE_OR_PATH
#   PropertiesDefinitionsAnimationTypeTable["basicShapeOtherwiseNo"] = PropertiesDefinitionsAnimationType.pdatBASIC_SHAPE_OTHERWISE_NO
#   PropertiesDefinitionsAnimationTypeTable["byComputedValue"] = PropertiesDefinitionsAnimationType.pdatBY_COMPUTED_VALUE
#   PropertiesDefinitionsAnimationTypeTable["byComputedValueType"] = PropertiesDefinitionsAnimationType.pdatBY_COMPUTED_VALUE_TYPE
#   PropertiesDefinitionsAnimationTypeTable[
#       "byComputedValueTypeNormalAnimatesAsObliqueZeroDeg"] = PropertiesDefinitionsAnimationType.pdatBY_COMPUTED_VALUE_TYPE_NORMAL_ANIMATES_AS_OBLIQUE_ZERO_DEG
#   PropertiesDefinitionsAnimationTypeTable["color"] = PropertiesDefinitionsAnimationType.pdatCOLOR
#   PropertiesDefinitionsAnimationTypeTable["discrete"] = PropertiesDefinitionsAnimationType.pdatDISCRETE
#   PropertiesDefinitionsAnimationTypeTable[
#       "discreteButVisibleForDurationWhenAnimatedHidden"] = PropertiesDefinitionsAnimationType.pdatDISCRETE_BUT_VISIBLE_FOR_DURATION_WHEN_ANIMATED_HIDDEN
#   PropertiesDefinitionsAnimationTypeTable[
#       "discreteButVisibleForDurationWhenAnimatedNone"] = PropertiesDefinitionsAnimationType.pdatDISCRETE_BUT_VISIBLE_FOR_DURATION_WHEN_ANIMATED_NONE
#   PropertiesDefinitionsAnimationTypeTable[
#       "eachOfShorthandPropertiesExceptUnicodeBiDiAndDirection"] = PropertiesDefinitionsAnimationType.pdatEACH_OF_SHORTHAND_PROPERTIES_EXCEPT_UNICODE_BI_DI_AND_DIRECTION
#   PropertiesDefinitionsAnimationTypeTable["filterList"] = PropertiesDefinitionsAnimationType.pdatFILTER_LIST
#   PropertiesDefinitionsAnimationTypeTable["fontStretch"] = PropertiesDefinitionsAnimationType.pdatFONT_STRETCH
#   PropertiesDefinitionsAnimationTypeTable["fontWeight"] = PropertiesDefinitionsAnimationType.pdatFONT_WEIGHT
#   PropertiesDefinitionsAnimationTypeTable["integer"] = PropertiesDefinitionsAnimationType.pdatINTEGER
#   PropertiesDefinitionsAnimationTypeTable["length"] = PropertiesDefinitionsAnimationType.pdatLENGTH
#   PropertiesDefinitionsAnimationTypeTable["lpc"] = PropertiesDefinitionsAnimationType.pdatLPC
#   PropertiesDefinitionsAnimationTypeTable["notAnimatable"] = PropertiesDefinitionsAnimationType.pdatNOT_ANIMATABLE
#   PropertiesDefinitionsAnimationTypeTable["numberOrLength"] = PropertiesDefinitionsAnimationType.pdatNUMBER_OR_LENGTH
#   PropertiesDefinitionsAnimationTypeTable["number"] = PropertiesDefinitionsAnimationType.pdatNUMBER
#   PropertiesDefinitionsAnimationTypeTable["position"] = PropertiesDefinitionsAnimationType.pdatPOSITION
#   PropertiesDefinitionsAnimationTypeTable["rectangle"] = PropertiesDefinitionsAnimationType.pdatRECTANGLE
#   PropertiesDefinitionsAnimationTypeTable["repeatableList"] = PropertiesDefinitionsAnimationType.pdatREPEATABLE_LIST
#   PropertiesDefinitionsAnimationTypeTable["shadowList"] = PropertiesDefinitionsAnimationType.pdatSHADOW_LIST
#   PropertiesDefinitionsAnimationTypeTable["simpleListOfLpc"] = PropertiesDefinitionsAnimationType.pdatSIMPLE_LIST_OF_LPC
#   PropertiesDefinitionsAnimationTypeTable["simpleListOfLpcDifferenceLpc"] = PropertiesDefinitionsAnimationType.pdatSIMPLE_LIST_OF_LPC_DIFFERENCE_LPC
#   PropertiesDefinitionsAnimationTypeTable["transform"] = PropertiesDefinitionsAnimationType.pdatTRANSFORM
#   PropertiesDefinitionsAnimationTypeTable["visibility"] = PropertiesDefinitionsAnimationType.pdatVISIBILITY
#   v = PropertiesDefinitionsAnimationTypeTable[s]

# proc parseHook*(s: string; i: var int; v: var PropertiesValueMedia) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: PropertiesValueMediaVariant0
#     tempValue = fromJson(jsonStr, PropertiesValueMediaVariant0)
#     v = PropertiesValueMedia(kind: PropertiesValueMediaKind.Variant0,
#                              value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: PropertiesValueMediaVariant1
#     tempValue = fromJson(jsonStr, PropertiesValueMediaVariant1)
#     v = PropertiesValueMedia(kind: PropertiesValueMediaKind.Variant1,
#                              value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "PropertiesValueMedia")

# proc dumpHook*(s: var string; v: PropertiesValueMedia) =
#   case v.kind
#   of PropertiesValueMediaKind.Variant0:
#     s = toJson(v.value0)
#   of PropertiesValueMediaKind.Variant1:
#     s = toJson(v.value1)
  
# proc parseHook*(s: string; i: var int;
#                 v: var PropertiesValueAnimationType) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: PropertiesValueAnimationTypeVariant0
#     tempValue = fromJson(jsonStr, PropertiesValueAnimationTypeVariant0)
#     v = PropertiesValueAnimationType(kind: PropertiesValueAnimationTypeKind.Variant0,
#                                      value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: PropertiesValueAnimationTypeVariant1
#     tempValue = fromJson(jsonStr, PropertiesValueAnimationTypeVariant1)
#     v = PropertiesValueAnimationType(kind: PropertiesValueAnimationTypeKind.Variant1,
#                                      value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "PropertiesValueAnimationType")

# proc dumpHook*(s: var string; v: PropertiesValueAnimationType) =
#   case v.kind
#   of PropertiesValueAnimationTypeKind.Variant0:
#     s = toJson(v.value0)
#   of PropertiesValueAnimationTypeKind.Variant1:
#     s = toJson(v.value1)
  
# proc parseHook*(s: string; i: var int;
#                 v: var PropertiesValuePercentages) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: PropertiesValuePercentagesVariant0
#     tempValue = fromJson(jsonStr, PropertiesValuePercentagesVariant0)
#     v = PropertiesValuePercentages(kind: PropertiesValuePercentagesKind.Variant0,
#                                    value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: PropertiesValuePercentagesVariant1
#     tempValue = fromJson(jsonStr, PropertiesValuePercentagesVariant1)
#     v = PropertiesValuePercentages(kind: PropertiesValuePercentagesKind.Variant1,
#                                    value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "PropertiesValuePercentages")

# proc dumpHook*(s: var string; v: PropertiesValuePercentages) =
#   case v.kind
#   of PropertiesValuePercentagesKind.Variant0:
#     s = toJson(v.value0)
#   of PropertiesValuePercentagesKind.Variant1:
#     s = toJson(v.value1)
  
# proc parseHook*(s: string; i: var int; v: var PropertiesValueInitial) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: PropertiesValueInitialVariant0
#     tempValue = fromJson(jsonStr, PropertiesValueInitialVariant0)
#     v = PropertiesValueInitial(kind: PropertiesValueInitialKind.Variant0,
#                                value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: PropertiesValueInitialVariant1
#     tempValue = fromJson(jsonStr, PropertiesValueInitialVariant1)
#     v = PropertiesValueInitial(kind: PropertiesValueInitialKind.Variant1,
#                                value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "PropertiesValueInitial")

# proc dumpHook*(s: var string; v: PropertiesValueInitial) =
#   case v.kind
#   of PropertiesValueInitialKind.Variant0:
#     s = toJson(v.value0)
#   of PropertiesValueInitialKind.Variant1:
#     s = toJson(v.value1)
  
# proc parseHook*(s: string; i: var int; v: var PropertiesValueComputed) =
#   var jsonStr: string
#   var jsn: RawJson
#   parseHook(s, i, jsn)
#   jsonStr = jsn.toJson()
#   try:
#     var tempValue: PropertiesValueComputedVariant0
#     tempValue = fromJson(jsonStr, PropertiesValueComputedVariant0)
#     v = PropertiesValueComputed(kind: PropertiesValueComputedKind.Variant0,
#                                 value0: tempValue)
#     return
#   except:
#     discard
#   try:
#     var tempValue: PropertiesValueComputedVariant1
#     tempValue = fromJson(jsonStr, PropertiesValueComputedVariant1)
#     v = PropertiesValueComputed(kind: PropertiesValueComputedKind.Variant1,
#                                 value1: tempValue)
#     return
#   except:
#     discard
#   raise newException(ValueError, "Could not parse any variant for " &
#       "PropertiesValueComputed")

# proc dumpHook*(s: var string; v: PropertiesValueComputed) =
#   case v.kind
#   of PropertiesValueComputedKind.Variant0:
#     s = toJson(v.value0)
#   of PropertiesValueComputedKind.Variant1:
#     s = toJson(v.value1)
  

## Selectors

type
  SelectorsValueGroups* = seq[definitionsGroupList]
type
  SelectorsValueStatus* = enum
    svsSTANDARD, svsNONSTANDARD, svsEXPERIMENTAL, svsOBSOLETE
type
  SelectorsValue* = object
    syntax*: string
    groups*: SelectorsValueGroups
    status*: SelectorsValueStatus
    mdn_url*: string

type
  Selectors* = Table[string, SelectorsValue]
# proc enumHook*(s: string; v: var SelectorsValueStatus) =
#   var SelectorsValueStatusTable: Table[string, SelectorsValueStatus] = initTable[
#       string, SelectorsValueStatus]()
#   SelectorsValueStatusTable["standard"] = SelectorsValueStatus.svsSTANDARD
#   SelectorsValueStatusTable["nonstandard"] = SelectorsValueStatus.svsNONSTANDARD
#   SelectorsValueStatusTable["experimental"] = SelectorsValueStatus.svsEXPERIMENTAL
#   SelectorsValueStatusTable["obsolete"] = SelectorsValueStatus.svsOBSOLETE
#   v = SelectorsValueStatusTable[s]


## Functions

type
  FunctionsDefinitionsMdn_url* = string
type
  FunctionsDefinitionsStatus* = enum
    fdsSTANDARD, fdsNONSTANDARD, fdsEXPERIMENTAL, fdsOBSOLETE
type
  FunctionsValueGroups* = seq[definitionsGroupList]
type
  FunctionsValue* = object
    syntax*: string
    groups*: FunctionsValueGroups
    status*: FunctionsDefinitionsStatus
    mdn_url*: FunctionsDefinitionsMdn_url

type
  Functions* = Table[string, FunctionsValue]
# proc enumHook*(s: string; v: var FunctionsDefinitionsStatus) =
#   var FunctionsDefinitionsStatusTable: Table[string, FunctionsDefinitionsStatus] = initTable[
#       string, FunctionsDefinitionsStatus]()
#   FunctionsDefinitionsStatusTable["standard"] = FunctionsDefinitionsStatus.fdsSTANDARD
#   FunctionsDefinitionsStatusTable["nonstandard"] = FunctionsDefinitionsStatus.fdsNONSTANDARD
#   FunctionsDefinitionsStatusTable["experimental"] = FunctionsDefinitionsStatus.fdsEXPERIMENTAL
#   FunctionsDefinitionsStatusTable["obsolete"] = FunctionsDefinitionsStatus.fdsOBSOLETE
#   v = FunctionsDefinitionsStatusTable[s]
