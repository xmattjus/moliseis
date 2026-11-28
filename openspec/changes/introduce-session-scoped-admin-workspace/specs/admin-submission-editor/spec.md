# Admin Submission Editor Delta

## ADDED Requirements

### Requirement: Recovery obligations outlive ordinary Workspace departure
A pending explicit recovery checkpoint obligation SHALL survive ordinary Editor and Workspace departure while the app owner and Admin authority remain current. It SHALL continue refusing different target/session activation until matching checkpoint proof succeeds. Field discard SHALL NOT satisfy that obligation. Actual auth revocation SHALL retain its existing immediate security lifecycle.

#### Scenario: Locally clean accepted recovery leaves page
- **GIVEN** C=E=B, P=A and a pending recovery checkpoint obligation
- **WHEN** the user returns to the dashboard then reopens the same session
- **THEN** B and its obligation remain without a field-discard prompt or implicit write
- **AND** another target/session is still refused with access back to the active editor and explicit checkpoint recovery

#### Scenario: Same authority reenters from Settings
- **GIVEN** accepted B is locally clean over persisted A with an outstanding recovery checkpoint obligation
- **WHEN** the user leaves Editor and Workspace normally, then enters again without losing authority
- **THEN** the new Workspace starts at its Dashboard, and reopening the same session retains B and its obligation
- **AND** stale callbacks cannot act in the new visit and another target cannot replace that session until its matching checkpoint succeeds

#### Scenario: Different local target
- **WHEN** a different target or session is selected while the outstanding obligation still owns the active session
- **THEN** the outgoing activation is protected before another activates
- **AND** pending recovery refusal remains actionable without an automatic decision dialog or checkpoint

#### Scenario: Dirty accepted recovery distinguishes removal from replacement
- **GIVEN** local fields differ from E while an explicit recovery checkpoint obligation remains
- **WHEN** another target/session is requested
- **THEN** replacement is refused without a dialog or automatic checkpoint/discard
- **AND** a separate page-only return to the dashboard offers the field choices while retaining the obligation after successful discard

#### Scenario: Stale recovered selection cannot bypass protection
- **WHEN** an explicit local recovery resolves a different owner, mismatched target or stale activation
- **THEN** source authority and account/target agreement are checked before binding
- **AND** no dirty fields or recovery obligation are abandoned

### Requirement: Local Save Progress observes admitted work
Save SHALL be admitted synchronously before local fullscreen Progress is shown for the live execution of the same authorized Editor visit. Progress SHALL only observe admitted work and SHALL NOT start or replay Save on open, rebuild or restart. Running work SHALL block ordinary Back while mandatory retirement remains effective.

#### Scenario: Presentation rebuild or retirement
- **WHEN** the active Progress rebuilds, is retired, or the process restarts
- **THEN** only a still-live authorized execution can remain observable and no Save starts or repeats
- **AND** recovery of an adopted session uses account-checked durable lookup from a fresh visit

#### Scenario: Repeated Save tap
- **WHEN** a Save is already admitted or physically settling
- **THEN** another tap cannot admit or present a second execution

### Requirement: Retirement removes private presentation as a unit
The private Navigator and its Editor, Progress, dialogs, overlays, focus and feedback SHALL retire when the authority interval ends. Retirement SHALL NOT depend on a successful pop, a dialog result or a router redirect. Private effects SHALL remain within the present authorized Workspace and SHALL NOT clear public feedback.

#### Scenario: Authority changes with private UI in use
- **WHEN** authority is lost while a dialog, focused Editor, Progress or feedback belongs to the retiring interval
- **THEN** none remains visible, interactive or accessible in the new interval
- **AND** releasing old callbacks or results cannot re-create them

#### Scenario: Mandatory removal with volatile edits
- **WHEN** a mandatory transition retires a Workspace that holds fields which were never persisted
- **THEN** recovery after auth loss or restart restores only durable work, including previously accepted persistence that validly commits
- **AND** if the app owner and authority remain current, mandatory presentation removal preserves applicable app-owned obligations without restoring private navigation

## MODIFIED Requirements

### Requirement: One active editor survives page changes
The application SHALL own one active Admin editing session shared by editor and progress presentations. Normal target changes SHALL refuse unsettled work and unresolved recovery checkpoint obligations. Uncheckpointed field changes SHALL require an explicit exit decision before replacement. Reopening the same local session within continuous authority SHALL preserve its applicable app-owned initialization and retained work, including outstanding recovery obligations. A fresh Workspace visit SHALL use fresh presentation bindings. On authority loss or restart, recovery follows the durable owner contracts. Local checkpointing SHALL accept incomplete fields without remote Save.

#### Scenario: Replacement would abandon work
- **GIVEN** A contains uncheckpointed fields or an admitted mutation
- **WHEN** navigation requests target B
- **THEN** A remains active until any mutation settles and, for local field edits, a current explicit exit decision succeeds
- **AND** no implicit checkpoint, remote request or second editor is created

#### Scenario: Checkpoint then switch
- **GIVEN** A has incomplete editable values
- **WHEN** the user explicitly checkpoints A and later switches after settlement
- **THEN** A restores losslessly when reopened and B receives independent authority

### Requirement: Account and activation authority guard every effect
Revocation SHALL immediately hide private editor state and prevent new remote phases or stale publication. Callbacks and effects SHALL retain their original Workspace visit, continuous Admin authority, account, session, target and activation. Already-started physical work SHALL settle according to its original ownership and SHALL NOT publish into a replacement session or start further unauthorized phases. A physical operation reservation SHALL release only on its own settlement.

#### Scenario: Account A to B
- **WHEN** A's operation completes after revocation and activation of B
- **THEN** B receives none of A's fields, assets, errors, navigation effects or successful status
- **AND** captured durable commits remain recoverable only for A

#### Scenario: Session A1 to B to A2
- **WHEN** a setter, dialog, load, picker or command from A1 completes after A2 activates
- **THEN** equal target or session identifiers do not restore A1 publication authority

### Requirement: Dashboard refresh does not depend on Save pop result
A normal local Editor return SHALL refresh its still-current Dashboard regardless of an Editor result. Dismissing Progress to the same Editor and retirement of the Workspace SHALL NOT count as an Editor return.

#### Scenario: Save remains open then user returns
- **WHEN** an administrator Saves and later leaves the editor normally
- **THEN** the current dashboard reloads even without a true route result

#### Scenario: Untouched editor exits
- **WHEN** an editor returns without changing remote content
- **THEN** the same harmless dashboard refresh occurs subject to current Dashboard visit and continuous authority

### Requirement: One exit decision owns one exact transition
All supported voluntary Editor exit entry points SHALL share one single-flight decision owner. Permission SHALL bind its current local Editor visit, continuous authority, account/session/target/activation and exact departure; it SHALL NOT be a reusable boolean or shared affirmative future. Competing attempts SHALL be refused. Authority SHALL be rechecked across every await and before removal; cancellation or failure SHALL release only its own ownership.

#### Scenario: Concurrent Back and programmatic removal
- **WHEN** Back and a programmatic removal overlap during a dialog or checkpoint
- **THEN** only the owning attempt can proceed, with one dialog and at most one route removal
- **AND** no second attempt inherits its affirmative result or pops the dashboard underneath

#### Scenario: Different target while a dialog is pending
- **WHEN** a second request targets another submission or session while the first decision is pending
- **THEN** the second request is refused and cannot repurpose the dialog's captured departure
- **AND** covered, replaced or obsolete private presentation cannot authorize any later target

#### Scenario: A1 returns as A2
- **WHEN** an exit result arrives after activation replacement or A1 to B to A2
- **THEN** matching durable identifiers do not revive its authority or produce errors, checkpoint, discard or navigation in A2

### Requirement: Platform exit controls preserve route ownership
AppBar Back, Android system/predictive Back, iOS edge gestures, Escape and supported programmatic departures SHALL obey the same voluntary exit policy. A dirty iOS native edge gesture SHALL be disabled before it begins; clean native swipe SHALL remain available. Explicit Back SHALL still reach the decision policy without enabling a reusable pop bypass.

#### Scenario: Dirty and clean iOS gestures
- **WHEN** iOS renders dirty fields or an owned exit decision
- **THEN** a native edge gesture cannot begin or reveal the underlying route
- **AND** clean idle fields permit native swipe and explicit Back still supports all three choices

#### Scenario: Escape outside a modal
- **WHEN** Escape requests an editor exit on desktop with no covering route
- **THEN** it enters the same guarded policy and cannot pop a covered underlying route

### Requirement: Running operations and retained pages are not dirty exits
Ongoing Save admission, in-flight mutations and existing local operation barriers SHALL block ordinary removal without a dirty dialog or a bypass. Local Progress SHALL retain the Editor. Terminal Progress Back SHALL dismiss only Progress. Successful moderation SHALL permit only its currently authorized editor closure; Save success SHALL keep the editor open.

#### Scenario: Mutation already admitted
- **WHEN** an ordinary exit is attempted during Save or another admitted mutation
- **THEN** no dirty dialog, remote retry or removal is admitted, even if field edits coexist

#### Scenario: Progress return
- **WHEN** terminal Progress is dismissed to its exact retained Editor
- **THEN** no editor exit decision occurs, even if newer editor fields are uncheckpointed

#### Scenario: Moderation closure
- **WHEN** a current successful moderation terminal owns its editor-close effect
- **THEN** only that editor closure is authorized without dirty confirmation
- **AND** an old, hidden or revoked terminal cannot grant later removal permission

### Requirement: Auth revocation preempts exit decisions
Loss of continuous authority SHALL immediately invalidate private exit effects. Mandatory retirement SHALL remove the private presentation, including local modals, without awaiting a voluntary decision, checkpoint, Back, animation or remote completion. Mandatory application removal SHALL also retire the visit when authority itself is unchanged. Neither case SHALL create an automatic checkpoint.

#### Scenario: Logout with open dialog or checkpoint
- **WHEN** authorization is revoked while a private exit decision or checkpoint is pending
- **THEN** admission and publication are revoked immediately, the private Navigator and its modal retire on reconciliation, and the dialog can authorize no further work or route effect
- **AND** an already-started local write can settle only for its original private owner and cannot publish into a replacement visit

### Requirement: Save validation is independent of body visibility
Ordinary Save/Create SHALL validate content, coordinates and event time regardless of scroll position, viewport height, keyboard visibility or layout. Off-screen forms SHALL neither bypass validation nor block valid work solely through absence. Rejection SHALL provide visible actionable feedback and direct access to the invalid field or message. Captured-save recovery SHALL retain its intentional validation bypass and existing admission semantics.

#### Scenario: Valid forms are outside the viewport
- **WHEN** valid content or location sections are off-screen and ordinary Save/Create is selected in either layout, including a short viewport or visible keyboard
- **THEN** validation succeeds independently of body visibility and exactly one admitted Save precedes its local Save Progress presentation

#### Scenario: Invalid off-screen fields reject Save visibly
- **WHEN** ordinary Save/Create encounters invalid required content or coordinate drafts outside the viewport
- **THEN** no backend Save or Save Progress presentation starts, and a visible validation summary identifies the problem with direct access to its field or message without searching the whole editor
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
- **THEN** local Save Progress opens for that attempt and terminal return retains the same Editor
- **AND** no automatic publication, remote auto-save or combined Save-and-Publish behavior is introduced

## REMOVED Requirements

### Requirement: Save progress observes admitted work
**Reason**: The global Progress route and cold restoration no longer exist.

**Migration**: Open local Progress from one admitted execution; recover durable pending work through a fresh Editor.

### Requirement: Recovery obligations outlive page removal
**Reason**: Global ID and query transitions are no longer supported.

**Migration**: Keep the ordinary page removal and target replacement rules under local selection.
