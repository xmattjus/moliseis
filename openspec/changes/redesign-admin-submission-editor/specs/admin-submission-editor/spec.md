# Spec Delta

## ADDED Requirements

### Requirement: Editor workspace leads with content identity
The editor SHALL present content identity and moderation status before editable content, photos/location, contextual verification, moderation decisions and secondary metadata. Urgent recovery and safety warnings SHALL remain prominent even when this interrupts the normal reading order.

#### Scenario: New or pending editor opens
- **WHEN** a new or pending submission is displayed
- **THEN** its title, municipality, place/event type and new/pending status are immediately understandable, with explicit placeholders for missing values
- **AND** every existing editable value and its validation remains available

#### Scenario: Identity changes during editing or hydration
- **WHEN** current authorized fields or status change
- **THEN** the identity summary reflects that state without resetting typing or creating edits
- **AND** preserved local content is distinguished from a conflicting remote final status

### Requirement: Editor decisions remain available across layouts
The editor SHALL provide one persistent decision area independent of content scroll position: a bottom area on compact layouts and a side panel only when available space supports both readable content and actions. It SHALL expose applicable actions without duplicate decision controls in the scrollable body and explain blocked primary actions.

#### Scenario: Compact editor with keyboard and enlarged text
- **WHEN** the editor is used at a narrow width with the keyboard visible or enlarged text
- **THEN** decision controls remain reachable, respect safe insets and navigation, and neither obscure the focused field nor clip labels
- **AND** secondary actions remain reachable without scrolling through the form

#### Scenario: Expanded layout fits or stops fitting
- **WHEN** available width permits a readable content column and moderation side panel
- **THEN** content width is constrained and the panel remains available independently of body scrolling
- **AND** resizing or increased text size that makes this arrangement unusable returns to the compact arrangement without losing fields, focus intent or operation state

### Requirement: Primary action reflects current editorial work
The decision area SHALL emphasize one appropriate next action while retaining applicable secondary actions and existing admission rules. Priority SHALL be running/recovery state, new or unsaved work, external comparison/resolution, then publication. An unavailable action SHALL never gain authority through its visual prominence.

#### Scenario: New submission
- **WHEN** a new submission is editable
- **THEN** Create is the primary action and publication/rejection are unavailable
- **AND** invalid input remains subject to existing Save validation

#### Scenario: Pending work is unsaved
- **WHEN** a pending submission has unconfirmed fields or staged work
- **THEN** Save is primary when admitted, with an explanation that moderation requires saved work
- **AND** publication, rejection, linking and update application cannot bypass existing dirty guards

#### Scenario: Clean submission is ready to publish
- **WHEN** a clean pending submission is eligible for publication, is not an external update and has no selected eligible Event linking intent
- **THEN** the appropriate event/place publication action is primary and Reject and Save remain secondary where applicable
- **AND** publication invokes the existing confirmation and readiness checks separately from Save

#### Scenario: Publication category is missing
- **WHEN** a clean pending submission that offers publication lacks a concrete publication category
- **THEN** publication stays disabled with guidance to select and save a category
- **AND** category editing is easy to locate and rejection retains its independent eligibility

#### Scenario: External proposal needs a target or preview
- **WHEN** an external submission requires linking or comparison
- **THEN** target selection and its current identity are discoverable in contextual verification
- **AND** Link or Preview is emphasized only for its applicable state, while missing prerequisites are explained
- **AND** unlinked create proposals retain the separate publication alternative where eligible

#### Scenario: Human Event submission can still link
- **WHEN** a clean human Event submission has an eligible selected target
- **THEN** Link remains available under its existing guards and takes priority over publication for that selected linking intent
- **AND** linking does not become restricted to imported submissions or overwrite Event content

#### Scenario: External update has a current preview
- **WHEN** an external update has a valid merge preview
- **THEN** Apply is primary subject to its existing guards, while Preview, Link and Reject remain available where applicable
- **AND** each group's Keep Current remains next to its comparison rather than being duplicated as a global action

#### Scenario: Save is invoked from either layout
- **WHEN** the user selects Save or Create and existing validation and admission succeed
- **THEN** the existing Save Progress presentation opens for that attempt and terminal return retains the editor
- **AND** no automatic publication, remote auto-save or combined Save-and-Publish behavior is introduced

### Requirement: Verification emphasizes consequential source information
External submissions SHALL show recognizable provenance and stale-source state before resolution. Existing comparison groups SHALL emphasize meaningful differences and overwrite conflicts, with their complete underlying values accessible. Disclosure SHALL NOT conceal safety-critical warnings, required acknowledgement controls or their consequences.

#### Scenario: Stale external source
- **WHEN** a stale external submission is reviewed
- **THEN** the stale warning and acknowledgement meaning are visible without expanding secondary metadata
- **AND** acknowledgement remains an explicit choice for the displayed source state

#### Scenario: Merge preview contains an overwrite conflict
- **WHEN** a valid preview group would overwrite current editorial content
- **THEN** the persistent decision area shows an explicit accessible warning with the number of overwrite groups and an action labeled "Esamina sovrascritture" in both compact and expanded layouts
- **AND** overwrite groups appear first, prioritizing their warning and complete proposed moderated/current destination values without secondary disclosure
- **AND** complete base/source values and other comparison evidence remain accessible, and Keep Current retains its original merge-group identity and behavior
- **AND** the warning is informational: no new confirmation, per-group acknowledgement or requirement to visit conflicts changes Apply eligibility

#### Scenario: Long preview leaves overwrite evidence off-screen
- **GIVEN** a valid preview has enough comparison groups and content for an overwrite group to be outside the viewport
- **WHEN** Apply remains accessible in the persistent decision area while the conflicting comparison is off-screen
- **THEN** the overwrite-count warning and "Esamina sovrascritture" remain visible without secondary disclosure in both compact and expanded layouts
- **AND** selecting that action reveals the current preview's first overwrite group, its warning and complete proposed moderated/current destination values for reading without secondary disclosure, with long values scrollable in full
- **AND** navigation executes neither Apply nor Keep Current and does not add an Apply admission requirement

#### Scenario: Preview invalidation or replacement changes overwrite navigation
- **WHEN** the current preview is invalidated or replaced, including replacement with no overwrite groups
- **THEN** the warning/count and navigation target update to the current valid preview or disappear when none contains overwrites
- **AND** obsolete navigation callbacks cannot reveal a retired preview or affect a replacement activation
- **AND** preview changes, rebuilds and layout changes do not automatically scroll or execute moderation

#### Scenario: Secondary metadata is disclosed
- **WHEN** the user opens contributor or technical details
- **THEN** existing available email, identifiers and timestamps remain accessible under the same authorization and sensitive-data masking
- **AND** disclosure does not grant editing, acknowledgement or mutation authority

### Requirement: Final submissions are readable and explicitly read-only
Accepted and rejected submissions SHALL present content and location at normal reading contrast with explicit final status and read-only labeling. Applicable publication linkage SHALL be discoverable. Presentation SHALL prevent editing through pointer and keyboard input without dimming the entire content.

#### Scenario: Accepted or rejected content is reviewed
- **WHEN** a finalized submission opens
- **THEN** content, photos and location are readable, final status is evident and any existing publication linkage is visible
- **AND** Save and moderation mutation controls are absent, with editing unavailable through focus or pointer interaction
- **AND** separately preserved local recovery work retains its existing allowed local-only actions

### Requirement: Recovery and operation feedback remains actionable
The workspace SHALL visibly distinguish loading, running operations, recoverable errors, conflicts and uncertain remote-save outcomes. It SHALL prioritize the current allowed recovery step over moderation, retain progress/error information for photos and preserve access to existing recovery choices without implying remote success or durability.

#### Scenario: Recovery or unknown save outcome blocks normal work
- **WHEN** the editor has a conflict, unavailable remote state, unresolved save outcome or pending local recovery checkpoint
- **THEN** a prominent summary explains the blocker and exposes the existing applicable read-back, reload, resume, field-settlement, comparison, checkpoint or return choices
- **AND** no new save/retry is inferred from displaying or expanding recovery information

#### Scenario: Operation runs or fails
- **WHEN** an operation is running or returns a failure
- **THEN** its action shows recognizable progress or actionable error feedback, competing operations retain their existing disabled states and repeated taps do not start duplicate work
- **AND** an error does not clear fields, staged progress or review evidence beyond existing invalidation rules

### Requirement: Workspace controls use accessible application styling
The workspace SHALL use established semantic colors, typography and shapes, meaningful action labels, accessible focus order and at least 48 logical-pixel interactive targets. Status and blockers SHALL be understandable without color alone, and text SHALL respect ambient scaling.

#### Scenario: Keyboard and assistive-technology review
- **WHEN** a user navigates the workspace with keyboard or assistive technology
- **THEN** identity, content, verification, decisions and disclosures have a meaningful reading/focus order and action names
- **AND** locked fields cannot capture editing focus, disabled actions expose an understandable nearby reason and disclosure controls expose expanded state

#### Scenario: Photo removal is available
- **WHEN** an editable photo exposes removal
- **THEN** its labeled target meets the minimum interactive size without obscuring neighboring controls or changing deletion eligibility
