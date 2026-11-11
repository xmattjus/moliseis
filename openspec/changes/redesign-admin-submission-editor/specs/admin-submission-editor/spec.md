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

### Requirement: Save validation is independent of body visibility
Ordinary Save/Create SHALL validate content, coordinates and event time regardless of scroll position, viewport height, keyboard visibility or layout. Off-screen forms SHALL neither bypass validation nor block valid work solely through absence. Rejection SHALL provide visible actionable feedback and direct access to the invalid field or message. Captured-save recovery SHALL retain its intentional validation bypass and existing admission semantics.

#### Scenario: Valid forms are outside the viewport
- **WHEN** valid content or location sections are off-screen and ordinary Save/Create is selected in either layout, including a short viewport or visible keyboard
- **THEN** validation succeeds independently of body visibility and exactly one admitted Save precedes one existing Save Progress navigation

#### Scenario: Invalid off-screen fields reject Save visibly
- **WHEN** ordinary Save/Create encounters invalid required content or coordinate drafts outside the viewport
- **THEN** no backend Save or Save Progress navigation starts, and a visible validation summary identifies the problem with direct access to its field or message without searching the whole editor
- **AND** coordinate validation remains effective in both Map and Coordinates modes; a hidden invalid coordinate field can be revealed for correction

#### Scenario: Responsive changes retain validation state
- **WHEN** the editor changes layout with typed content, rich-text selection, coordinate drafts or validation errors
- **THEN** the same form state and values remain available without remount-induced loss or validation bypass

#### Scenario: Captured-save continuation is selected
- **WHEN** the existing recovery state offers Resume Captured Save
- **THEN** continuation retains its intentional current-form validation bypass, captured input and admission rules rather than being routed through ordinary Save validation

### Requirement: Primary action reflects current editorial work
The decision area SHALL emphasize one appropriate next action while retaining applicable secondary actions and existing admission rules. Priority SHALL be running/recovery state, new or unsaved work, external comparison/resolution, then publication. Workflow offering, interactive prerequisites and current command admission SHALL remain distinct; a retained target alone SHALL NOT grant eligibility. Backend acceptance remains authoritative.

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
- **WHEN** a clean persisted human Event submission has a non-null eligible Event start and an eligible selected target
- **THEN** Link remains available under its existing guards and takes priority over publication for that selected linking intent
- **AND** linking does not become restricted to imported submissions or overwrite Event content

#### Scenario: Selected target outlives Event eligibility
- **GIVEN** a persisted human Event has a selected target
- **WHEN** its start becomes missing or unresolved, or it is converted to Place and saved while the target remains selected
- **THEN** target presence and command admission alone do not offer or enable Link as an eligible primary action; Place-like content cannot link to an Event
- **AND** stale callbacks cannot bypass the existing request-time start, dirty, activation or other mutation guards, and ineligible linking issues no repository mutation
- **AND** publication still follows Event/Place semantics and Reject does not inherit publication-category readiness

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

#### Scenario: Stale source evidence is outside the viewport
- **WHEN** an external submission is stale and its current-source details are off-screen
- **THEN** both compact and expanded decision areas visibly indicate a newer source revision and offer a labeled accessible action "Esamina fonte aggiornata" to reveal/focus the current-source evidence
- **AND** complete displayed source values and the existing explicit acknowledgement checkbox remain accessible with acknowledgement bound to the displayed source hash
- **AND** navigation performs no mutation or automatic acknowledgement, and copy explains that resolving this proposal does not automatically acknowledge newer source revisions
- **AND** resolution without acknowledgement remains available under existing guards; no visit, reading, confirmation or acknowledgement gate is added

#### Scenario: Source context changes
- **WHEN** source state is reloaded or changes, or the activation is replaced
- **THEN** the stale indicator and navigation target reflect the current authorized source or disappear when no longer stale, without displaying a prior activation's evidence
- **AND** existing SOURCE_CHANGED refresh-and-review and explicit renewed acknowledgement rules remain effective; no checkbox selection is inferred from navigation or reload

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

### Requirement: Restructured surfaces retain selective Replay classification
Every newly composed or moved editor surface SHALL preserve the canonical session-replay-privacy classification through official masking boundaries. Protection SHALL follow the rendered values, including disclosed comparison evidence and private assets, rather than Admin access, final status or related publication alone. Deliberately public content and approved administrator account context SHALL retain their intended visibility.

#### Scenario: Classified private moderation evidence is rendered
- **WHEN** redesigned pending human, imported create/update, stale-source, recovery or finalized presentations render classified private values
- **THEN** original contributor name/email, unpublished identity, private authored content/location, private or unpublished source snapshots, moderated values, classified private base/source/current evidence, pending-submission warnings, recovery/technical details and private asset previews retain official masking ancestors
- **AND** adjacent deliberately public Event content and approved create-mode administrator identity retain their intended visibility
- **AND** publication of a related Event does not by itself reclassify original or unpublished values as public

#### Scenario: Masking regression coverage is assessed
- **WHEN** focused widget tests inspect the restructured private/public boundaries
- **THEN** they verify official application masking ancestors and authorized readability, without claiming native Replay pixel output or changing global privacy configuration
