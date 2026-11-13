# empty-view-presentation Specification

## ADDED Requirements

### Requirement: EmptyView adapts to effective layout constraints without a specialized API

The existing `EmptyView`, `EmptyView.error` and `EmptyView.loading` constructors SHALL remain unchanged. `EmptyView` SHALL adapt its presentation to the constraints actually allocated by its parent, without an image-specific constructor, compact flag, new public variant or dependency on the viewport's global size. Where space permits, it SHALL preserve the current centered composition, padding, typography, icon size and action layout.

#### Scenario: Existing spacious screen renders EmptyView

- **GIVEN** a current loading, error or empty state with enough available height and width for the normal composition
- **WHEN** the screen renders `EmptyView`
- **THEN** icon, text, action, hierarchy and normal spacing remain visibly equivalent to the existing presentation
- **AND** current text scaling, focus and semantics behavior is preserved

#### Scenario: Compact noninteractive image slot

- **GIVEN** an `EmptyView` with a meaningful icon and text but no interactive action, constrained to 32×32, 48×48, 72×72 or 86×86 logical pixels
- **WHEN** it is laid out
- **THEN** the component fits inside its allocated bounds without `RenderFlex` overflow
- **AND** it reduces discretionary padding, spacing and icon size as needed
- **AND** if the visible text cannot remain readable, it may omit visible text while retaining an accessible description of the state
- **AND** no new constructor or image-specific public switch is necessary

#### Scenario: Constrained non-square container or scaled text

- **GIVEN** an `EmptyView` with text and optional icon inside a narrow or short bounded container, possibly with enlarged text scaling
- **WHEN** available constraints are smaller than the normal presentation requires
- **THEN** it respects parent bounds and avoids uncontrolled layout overflow, preserving readable text when sufficient room exists
- **AND** it does not globally suppress text scaling or shrink all content with an indiscriminate `FittedBox`

### Requirement: EmptyView preserves reachable accessible actions

A constrained `EmptyView` SHALL NOT silently discard, disable or reduce an existing action to an unusable hit target merely to prevent overflow. If content with an action cannot fit, the component SHALL use an appropriate bounded reachability strategy, such as scrolling within finite constraints, while keeping the action focusable and semantically discoverable. The layout SHALL remain valid under relevant unbounded-axis constraints used by scrollable or sliver-based parents.

#### Scenario: Error or empty state contains recovery action

- **GIVEN** a current `EmptyView` with icon, message and a retry/return action
- **WHEN** its parent supplies insufficient bounded space for the normal column
- **THEN** the action remains accessible, focusable and usable, with an appropriate hit target
- **AND** the widget does not hide it as a compact image-only fallback
- **AND** any scrolling or content reduction does not cause a viewport overflow

#### Scenario: EmptyView is placed in a vertically unbounded scroll host

- **WHEN** an existing screen renders `EmptyView` inside a scrollable/sliver composition that provides unbounded height
- **THEN** responsive layout does not assume finite height or introduce an invalid viewport/flex constraint
- **AND** the content remains laid out and reachable in the same host

### Requirement: Compact error semantics remain meaningful

Where `EmptyView` omits visual text for insufficient space, the textual meaning of the state SHALL remain available through assistive technologies without exposing private file paths or image URLs. Decorative icon semantics SHALL NOT produce redundant or contradictory announcements.

#### Scenario: Text is hidden but broken-image icon remains

- **WHEN** a bounded image slot shows an icon-only error
- **THEN** the semantics tree exposes an understandable image-unavailable label
- **AND** no duplicate or misleading error label is announced
- **AND** a screen reader does not require the hidden text to remain visually laid out
