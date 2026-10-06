## Purpose

Provide consistent application typography that preserves the localized Material
baseline, expresses the app's Brand/Plain families and Material emphasis, and
uses native title styles and ambient text scaling at the identified UI seams.

## ADDED Requirements

### Requirement: Localized baseline typography has explicit application families

Application baseline typography SHALL retain Material size, weight, tracking
and line-height geometry resolved for the active context. Lexend SHALL be the
Plain/default family; Fraunces with SOFT 50 SHALL be the Brand family for all
display and headline roles and titleLarge. The same family policy SHALL apply
to the independent photo-viewer theme. Standard weight changes SHALL remain
effective without a conflicting explicit wght axis.

#### Scenario: Brand and plain roles resolve

- **WHEN** a widget consumes the application baseline
- **THEN** display/headline/titleLarge use Fraunces, the other roles use Lexend,
  and their Material geometry and current theme colors are retained

#### Scenario: Script category differs

- **WHEN** a context resolves typography for a different script category
- **THEN** application styles retain that context's localized geometry and
  text baseline rather than using an independently precomputed scale

#### Scenario: Photo viewer is shown

- **WHEN** the independent photo-viewer theme supplies text styles
- **THEN** it follows the same Brand/Plain family policy in its dark context

#### Scenario: Local weight is selected

- **WHEN** a component or rich-text attribute selects a standard weight
- **THEN** that weight is not overridden by an application-pinned wght axis

### Requirement: Every Material role has a context-derived emphasized counterpart

Application typography SHALL offer emphasized counterparts for all fifteen
Material roles, derived from the current resolved baseline. The emphasized
scale SHALL follow Material 3 Expressive emphasis while retaining application
families, non-weight axes and other properties not changed by its tokens.
Widgets SHALL request emphasized roles through a stable application boundary
rather than depending on its temporary token-construction algorithm.

#### Scenario: Brand headline is emphasized

- **WHEN** emphasized headlineLarge is requested for a post name
- **THEN** it retains localized headline geometry, Fraunces and SOFT while
  expressing the emphasized medium weight

#### Scenario: Display and body tracking differ

- **WHEN** emphasized displayLarge or bodyLarge is requested
- **THEN** each uses its Material emphasized tracking as well as emphasized
  weight while preserving unrelated baseline properties

#### Scenario: Plain label is emphasized

- **WHEN** emphasized labelMedium is requested
- **THEN** it retains the resolved plain label geometry and uses emphasized
  bold weight

#### Scenario: Theme changes

- **WHEN** a consuming context receives a new theme or script category
- **THEN** subsequently requested emphasis derives from the new resolved styles

#### Scenario: Token provider is replaced

- **WHEN** equivalent native emphasized support replaces the compatibility source
- **THEN** widgets continue requesting the same application emphasized roles

### Requirement: Shared semantic styles retain current meaning

Section and link styles SHALL derive from the current resolved baseline and
color scheme. Section SHALL use titleMedium with primary color. Link SHALL use
bodySmall, secondary color at alpha 0.7, underline and matching decoration color.
Calendar weekday and month-header styles SHALL retain their presentation-owned
sources and brightness-dependent colors.

#### Scenario: Semantic colors follow the theme

- **WHEN** section or link styles are requested after a theme change
- **THEN** they use the new context's baseline roles and semantic colors

#### Scenario: Calendar styles resolve

- **WHEN** calendar presentation resolves weekday and month styles
- **THEN** weekday uses the date-picker weekday role with black45/white54,
  and month uses titleMedium with black87/white70 for light/dark respectively

### Requirement: Named emphasis migrations preserve component hierarchy

The post name SHALL use emphasized headlineLarge and its city SHALL use plain
baseline titleMedium. The rail SHALL retain labelMedium sizing, emphasized
bold selection and an explicitly normal-weight unselected label. Primary
weather temperature SHALL retain its local displayMedium bold weight; hourly
weather's light label SHALL retain light weight. Unrelated content/component
bold choices SHALL not be converted automatically to emphasized roles.

#### Scenario: Rail selection changes

- **WHEN** a rail destination becomes selected or unselected
- **THEN** its label uses the corresponding emphasized-bold or normal-weight
  style without changing role size or navigation behavior

#### Scenario: Weather is displayed

- **WHEN** current temperature and hourly labels render
- **THEN** the primary temperature retains its bold hierarchy and the hourly
  light label retains its intended light weight

### Requirement: Identified text measurements consume ambient typography inputs

SnackBar line measurement and slideshow-label width measurement SHALL use the
rendered text's ambient scaler, direction and locale and matching effective
style/line limit, including accessible bold and text-spacing overrides. This
contract SHALL NOT imply exact SnackBar width/action-placement correctness or
unbounded responsive layout at extreme scaling.

#### Scenario: Scaling or locale changes

- **WHEN** the named components measure text with elevated scaling or a changed
  direction/locale
- **THEN** measurements use those same inputs rather than unscaled LTR defaults

#### Scenario: Accessible style overrides change

- **WHEN** accessible bold or height, letter or word spacing overrides change
- **THEN** the named measurements follow the effective rendered style,
  including a SnackBar that is already visible

#### Scenario: Slideshow label theme changes

- **WHEN** the slideshow's text dependencies change
- **THEN** its expanded label width is recomputed with the same role style
  used for the rendered button label

### Requirement: Suggestion viewport height is independent of text line-height ratios

The suggestion carousel SHALL retain its viewport fraction and section-spacing
deduction without adding TextStyle.height or a substitute header estimate as
an absolute pixel measurement. Its section heading SHALL remain outside the
carousel viewport.

#### Scenario: Typography height changes

- **WHEN** only text style line-height ratios or text scaling change
- **THEN** the carousel viewport height continues to follow viewport size and
  existing spacing instead of a typography multiplier treated as pixels

### Requirement: Picker header uses its active native title style

The compact iOS date/time picker header SHALL derive from the active local
Cupertino navigation-title style, without a synthetic font-family alias or
Material title weight overlay. Picker selection and wheel/button behavior
SHALL remain unchanged.

#### Scenario: Native popup title is built

- **WHEN** the date or time popup builds its title under the local Cupertino theme
- **THEN** it uses that theme's native title typography

### Requirement: Renderer and local presentation contracts are preserved

Markdown heading/link sizes and line heights, Quill inline bold/italic/
underline/link semantics, paragraph/list spacing and deliberate local branding
SHALL remain intact. Removing a weight-axis workaround SHALL preserve legitimate
non-weight variations when present. This change SHALL not broaden into a
renderer redesign or a general accessibility/layout migration.

#### Scenario: Rich description combines attributes

- **WHEN** a description combines bold, italic, underline and link formatting
- **THEN** those rendered attributes remain active without clearing unrelated
  non-weight axes from the inherited style

#### Scenario: Legacy Markdown renders

- **WHEN** a Markdown description contains headings or links
- **THEN** it retains its renderer-specific sizes and line heights
