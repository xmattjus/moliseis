# empty-view-presentation Specification

## Purpose

Keep known image-error descriptions accessible in compact slots, and preserve shared empty/loading/error content and reachable actions under their actual supported constraints.

## ADDED Requirements

### Requirement: Compact image errors have explicit semantic ownership

The noninteractive image-error caller/composition SHALL own an explicit known image-unavailable label independently of visible text. It SHALL NOT extract a string from arbitrary EmptyView widget content. A single semantic boundary SHALL retain that description while excluding duplicate decorative/icon/text announcements. Raw URLs and private staging paths SHALL NOT be included. EmptyView constructors and widget-valued fields SHALL remain unchanged.

#### Scenario: Compact noninteractive image slot

- **GIVEN** the known image-error state in a 32×32, 48×48, 72×72 or 86×86 logical slot
- **WHEN** its normal visual icon/text/decorations do not fit
- **THEN** a nonzero visible broken-image icon remains fully within the slot without overflow or clipping
- **AND** the semantics tree exposes exactly one meaningful image-unavailable description even though visible Text is omitted
- **AND** decorative descendants do not produce duplicate announcements
- **AND** this behavior belongs to the image-error composition, not arbitrary shared EmptyView content/actions

#### Scenario: Known label fits normally

- **WHEN** actual parent constraints allow the known label at effective typography/TextScaler and the existing icon/decorations
- **THEN** image-error presentation uses the existing EmptyView visual composition with unchanged normal geometry
- **AND** the same one semantic description remains available without duplicate visible-text announcements
- **AND** compact selection uses measured content requirements, including width/height boundaries and enlarged text, rather than a global viewport or arbitrary image-height breakpoint
- **AND** text scaling is not suppressed and the whole state is not indiscriminately shrunk

### Requirement: Shared EmptyView preserves arbitrary content and spacious layout

EmptyView, EmptyView.error and EmptyView.loading constructors and widget-valued fields SHALL remain unchanged. Shared adaptation SHALL preserve arbitrary content, descendant semantics and roomy layout. It SHALL NOT hide arbitrary text or infer its semantic string. No image-specific constructor/parameter, general responsive framework or semantic extraction system SHALL be introduced.

#### Scenario: Existing spacious state

- **GIVEN** an existing empty/loading/error state whose content fits its supported host
- **WHEN** finite-height reachability support is applied
- **THEN** icon/text/action rectangles and normal visual hierarchy remain equivalent
- **AND** action callbacks, text scaling, keyboard focus and descendant semantics remain intact

#### Scenario: Shared content needs more finite height

- **GIVEN** actual existing caller content in a narrow/short finite host with enlarged text
- **WHEN** its full composition exceeds available height
- **THEN** appropriate bounded vertical scrolling keeps the content reachable without hiding or shrinking it
- **AND** normal centered geometry is preserved where the content fits
- **AND** this vertical reachability contract does not promise that any arbitrary child fits every possible width/height

### Requirement: Shared EmptyView actions remain reachable and accessible

Within actual supported parent constraints, action-bearing EmptyView SHALL preserve usable hit targets, labels, callbacks, keyboard focus/activation and assistive-technology access. The compact image-error semantic exclusion SHALL NOT wrap action-bearing states or remove their descendants. The small noninteractive square matrix SHALL NOT be used as an action contract.

#### Scenario: Finite existing error and retry consumer

- **GIVEN** a Nearby/Suggestion-style error/retry state, including width 320, height 216 and text scale 2
- **WHEN** content exceeds its bounded height
- **THEN** scrolling makes the labelled action reachable and tappable with its existing usable target, at least 48 logical pixels where required by that consumer
- **AND** keyboard focus/Enter and semantics tap activate its actual callback
- **AND** tests inspect visible/reachable hit geometry, not only widget presence or absence of exceptions

#### Scenario: Viewport smaller than an action target

- **WHEN** a supported viewport cannot expose an entire existing 48×48 target simultaneously
- **THEN** the action is not hidden, disabled or shrunk to imply it fits
- **AND** tests verify reachable usable visible geometry after scrolling without claiming that the entire target is simultaneously exposed

#### Scenario: Vertically unbounded scroll or sliver host

- **WHEN** EmptyView is hosted in an existing SliverToBoxAdapter, another unbounded-height composition, or an intrinsic-measuring SliverFillRemaining(hasScrollBody: false)
- **THEN** it supports the host’s intrinsic measurement and layout without exceptions, an unbounded nested viewport or a flex error
- **AND** finite-height overflow still scrolls to reachable content/actions and roomy layouts remain equivalent
- **AND** its text/action semantics and reachable/tappable geometry remain available
