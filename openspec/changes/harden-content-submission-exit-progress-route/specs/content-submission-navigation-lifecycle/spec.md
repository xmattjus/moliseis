## Purpose

Define recoverable, single-flight navigation and lifecycle boundaries for the application-scoped Content Submission draft, its external exits, submission progress, and successful local retirement.

## ADDED Requirements

### Requirement: Removing a dirty form route requires one explicit exit decision
The system SHALL guard an attempt to remove the Content Submission form route whenever the current form snapshot differs from its last durable checkpoint. A clean form route SHALL exit without confirmation. A dirty exit SHALL present exactly the choices `Salva ed esci`, `Esci senza salvare`, and `Annulla`. Exactly one route-removal invocation SHALL own an active dirty-exit decision; any overlapping invocation SHALL be denied or deferred without receiving a second affirmative completion from the owner's decision. The same policy SHALL govern AppBar back, operating-system back, supported interactive back gestures, and programmatic navigation that removes the form route. Removing only the child progress route while retaining the form route SHALL NOT itself be treated as a form-route exit.

#### Scenario: Clean form exits directly
- **WHEN** navigation attempts to remove the form route while its current snapshot equals its checkpoint
- **THEN** navigation proceeds without displaying an exit confirmation or invoking draft persistence

#### Scenario: Dirty form offers exactly three choices
- **WHEN** navigation attempts to remove the form route while its current snapshot differs from its checkpoint
- **THEN** navigation pauses and one confirmation presents `Salva ed esci`, `Esci senza salvare`, and `Annulla`

#### Scenario: Save and exit checkpoints before navigation
- **WHEN** the user selects `Salva ed esci` and the current snapshot checkpoints successfully
- **THEN** the system awaits that checkpoint and removes the form route only after success

#### Scenario: Save and exit failure preserves editing
- **WHEN** the user selects `Salva ed esci` and checkpointing fails
- **THEN** the form route remains active, current in-memory work and session ownership remain unchanged, and the existing generic error feedback is shown

#### Scenario: Exit without saving restores the checkpoint
- **WHEN** the user selects `Esci senza salvare` and the checkpoint restore succeeds
- **THEN** only uncheckpointed form-field edits are discarded, the in-memory form snapshot returns to its last checkpoint, and navigation then removes the form route

#### Scenario: Exit without saving preserves durable session state
- **GIVEN** the current session has an existing persisted draft and may own already-durable staged assets
- **WHEN** `Esci senza salvare` succeeds
- **THEN** the persisted draft is not deleted, its client submission identity is not rotated, and its durable staged assets are neither deleted nor represented as reversible form-field edits

#### Scenario: Exit without saving failure stays on the form
- **WHEN** no trustworthy checkpoint can be restored or checkpoint restoration otherwise returns an error
- **THEN** navigation is denied, current state remains unchanged, and the existing generic error feedback is shown

#### Scenario: Reopening does not resurrect discarded edits
- **WHEN** the form is reopened after a successful `Esci senza salvare`
- **THEN** it exposes the restored checkpoint rather than the discarded in-memory field values

#### Scenario: Cancel leaves state and navigation unchanged
- **WHEN** the user selects `Annulla` or dismisses the dirty-exit confirmation
- **THEN** navigation remains on the form and no checkpoint, restore, clear, session rotation, or staged-asset mutation occurs

#### Scenario: Concurrent dirty exits remain single-flight
- **WHEN** another route-removal attempt occurs while a dirty-exit decision or its selected operation is pending
- **THEN** the owning invocation alone may receive affirmative permission, the overlap cannot consume that permission, exactly one confirmation and at most one selected checkpoint/restore flow occur, and an affirmative owner removes exactly the intended form route once

#### Scenario: Overlapping Back cannot remove an underlying route
- **GIVEN** another route remains beneath the dirty Content Submission form route
- **WHEN** concurrent Back or pop attempts overlap and the owning decision permits exit
- **THEN** the form route is removed once, the underlying route remains current, and no stale match completion, double completion, framework exception, or router exception occurs

#### Scenario: Concurrent programmatic removal has one owner
- **WHEN** more than one programmatic route replacement attempts to remove the dirty form while one decision is pending
- **THEN** only the owning replacement may proceed from that decision and an overlapping replacement cannot apply a second destination from the same affirmative result

#### Scenario: Exit ownership is reusable after termination
- **WHEN** an owning exit decision is cancelled, fails, or completes and a later independent form route subsequently requests removal
- **THEN** the stale decision no longer blocks or authorizes the later attempt, which evaluates normally against its current route and form state

#### Scenario: Dirty iOS edge swipe is prevented before it starts
- **WHEN** the form is dirty on iOS and the user attempts the native left-edge interactive back gesture
- **THEN** the gesture does not start, the form remains fully visible and interactive, Explore is not partially exposed, and no exit dialog is shown from that gesture

#### Scenario: Clean iOS edge swipe remains native
- **WHEN** the form is clean on iOS and the user completes the native left-edge interactive back gesture
- **THEN** the form exits without confirmation through the normal native transition

#### Scenario: Dirty AppBar Back retains the route exit policy
- **WHEN** the form is dirty and the user activates the unchanged AppBar Back control
- **THEN** the existing three-choice route-exit policy owns the attempt, and `Annulla` leaves the form dirty, interactive, and fully visible

### Requirement: Dirty state is visible without changing AppBar geometry
The Content Submission AppBar SHALL derive its state directly from `ContentSubmissionViewModel.hasUnsavedChanges`. While dirty, it SHALL show the visible status text `Modifiche non salvate` directly below `Suggerimento` with a decorative circular dot that does not create a separate semantic announcement. The status SHALL be absent while clean. Both states SHALL retain the existing standard Material 3 AppBar dimensions, unchanged Back control visuals and semantics, and stable surrounding content geometry.

#### Scenario: Dirty indicator follows checkpoint state
- **WHEN** a dirty form checkpoints successfully without leaving the form
- **THEN** `hasUnsavedChanges` becomes false through the existing lifecycle behavior and the dirty indicator disappears without resizing the AppBar

### Requirement: External form boundaries checkpoint current dirty data
Before intentionally launching the Terms of Service or Privacy Policy outside the application-controlled form lifecycle, the system SHALL await a successful checkpoint of the current dirty form data. A checkpoint error SHALL prevent the external launch, preserve current in-memory work, and use the existing generic error feedback. The existing image-picker flow SHALL retain its single ViewModel-owned pre-picker checkpoint and SHALL NOT receive an additional UI-owned checkpoint.

#### Scenario: Terms launch follows a successful dirty checkpoint
- **WHEN** the user activates Terms of Service while the form is dirty and checkpointing succeeds
- **THEN** the current form snapshot is durable before the Terms destination is launched

#### Scenario: Privacy launch follows a successful dirty checkpoint
- **WHEN** the user activates Privacy Policy while the form is dirty and checkpointing succeeds
- **THEN** the current form snapshot is durable before the Privacy destination is launched

#### Scenario: External checkpoint failure blocks launch
- **WHEN** the checkpoint required for either external destination returns an error
- **THEN** that destination is not launched, current work remains editable, and the existing generic error feedback is shown

#### Scenario: External launcher failure retains existing feedback
- **WHEN** checkpointing permits an external launch but the existing URL launch operation reports failure
- **THEN** the system remains on the form and shows the existing generic error feedback

#### Scenario: Image picker retains one checkpoint owner
- **WHEN** asset selection opens the image picker
- **THEN** exactly the existing ViewModel-owned pre-picker checkpoint governs that boundary and the form UI performs no second checkpoint

### Requirement: A validated submission crosses one durable single-flight transition
The system SHALL validate the editable form before performing lifecycle work. After validation succeeds, it SHALL prevent concurrent duplicate transition handling, await a successful checkpoint of the current snapshot, start one submission Command execution, and push one progress route in that order. A checkpoint failure or loss of the form widget before the transition completes SHALL start neither remote submission nor progress navigation. The form SHALL preserve current in-memory work and show the existing generic error feedback on checkpoint failure.

#### Scenario: Validation failure performs no transition work
- **WHEN** either form validation or event-time validation fails
- **THEN** no transition checkpoint, submission execution, or progress-route push occurs

#### Scenario: Successful checkpoint starts one submission transition
- **WHEN** a valid current form snapshot checkpoints successfully
- **THEN** one submission Command execution starts and one progress route is pushed after the checkpoint

#### Scenario: Submission checkpoint failure blocks the boundary
- **WHEN** a validated current form snapshot cannot be checkpointed
- **THEN** submission does not start, the progress route is not pushed, the editable work is preserved, and the existing generic error feedback is shown

#### Scenario: Rapid repeated submission remains single-flight
- **WHEN** the user rapidly activates submission more than once while checkpointing or progress navigation is pending
- **THEN** exactly one validated transition, one checkpoint boundary, one active submission execution, and one progress-route push occur

#### Scenario: Process loss during submission retains the attempted snapshot
- **WHEN** a submission attempt is interrupted or its runtime Command state is lost after the progress transition
- **THEN** local recovery can restore the snapshot checkpointed for that attempt rather than only an arbitrary older snapshot

### Requirement: Form-owned boundaries and form removal are mutually exclusive
A form-owned checkpoint-to-external-launch or checkpoint-to-submit/progress transition and a competing removal of the parent form route SHALL NOT overtake one another. Whichever operation synchronously acquires ownership first SHALL exclude the other until its route-sensitive boundary is complete. While a form boundary owns the transition, user interaction SHALL remain blocked and AppBar, operating-system, predictive, and programmatic removal attempts SHALL NOT start a dirty-exit dialog, checkpoint, or restore flow. While a form-removal invocation owns the transition, a form boundary SHALL NOT start checkpointing, external launch, submission, or progress navigation. Ownership SHALL release after cancellation, failure, or the relevant handoff so later independent actions work normally.

#### Scenario: Back is denied during a pre-submit checkpoint
- **WHEN** a validated submit transition owns the form boundary and its checkpoint remains pending while system or predictive Back commits
- **THEN** Back does not start an exit dialog or second persistence flow, does not remove the form, and the submit transition proceeds at most once after its checkpoint succeeds

#### Scenario: Back is denied during an external checkpoint
- **WHEN** a Terms or Privacy transition owns the form boundary and its checkpoint remains pending while system or predictive Back commits
- **THEN** Back does not start an exit dialog or second persistence flow, does not remove the form, and the selected external destination launches at most once after its checkpoint succeeds

#### Scenario: An owning exit prevents late submission
- **WHEN** a form-removal attempt acquires ownership before a competing submit transition and ultimately removes the form
- **THEN** the competing transition performs no checkpoint, starts no submission Command, pushes no progress route, and cannot resume after route removal

#### Scenario: An owning exit prevents a late external launch
- **WHEN** a form-removal attempt acquires ownership before a competing Terms or Privacy transition and ultimately removes the form
- **THEN** the competing transition performs no checkpoint, launches no external destination, and cannot resume after route removal

#### Scenario: Boundary ownership releases for later Back
- **WHEN** a form-owned boundary completes or fails without removing the parent form route
- **THEN** a later independent AppBar, system, predictive, or programmatic removal attempt evaluates through the normal clean-or-dirty route policy

### Requirement: Progress navigation reflects operation state without owning draft policy
The dedicated progress route SHALL render the shared submission operation state and SHALL NOT independently checkpoint, restore, clear, rotate, or delete the draft/session in response to its navigation buttons. Navigation actions SHALL delegate any removal of the parent form route to the central form-exit policy.

#### Scenario: Running progress blocks every back path
- **WHEN** submission or required successful-session finalization is running
- **THEN** progress UI is shown, AppBar back is unavailable, system and predictive back cannot remove the route, no exit action is available, and another submission cannot start

#### Scenario: Restored idle progress returns to editing
- **WHEN** the progress route is restored while the runtime submission Command is idle
- **THEN** Back or `Torna al modulo` removes only the progress route, preserves editable and durable work, and does not submit or clear automatically

#### Scenario: Remote failure back preserves the session
- **WHEN** remote submission fails and the user activates Back
- **THEN** only the progress route is removed and the same draft identity, form data, and staged assets remain available for editing

#### Scenario: Remote failure retry reuses the session
- **WHEN** remote submission fails and the user activates `Riprova`
- **THEN** the existing submission Command executes again for the same draft/session without creating or pushing another progress route, and retry-safe uploaded/staged assets retain their existing reuse behavior

#### Scenario: Remote failure home preserves recoverability
- **WHEN** remote submission fails and the user activates `Torna alla home`
- **THEN** no destructive progress-screen cleanup occurs, any dirty parent-form exit is decided by the central form-route policy, and the failed draft/session remains recoverable unless that central policy explicitly checkpoints or restores its form edits

#### Scenario: Successful actions only navigate
- **WHEN** local finalization has succeeded and the user activates Back or `Nuovo suggerimento`
- **THEN** only the progress route is removed and the revealed form exposes a clean new submission session

#### Scenario: Successful home leaves no completed draft
- **WHEN** local finalization has succeeded and the user activates `Torna alla home`
- **THEN** navigation removes the Content Submission route without performing button-owned cleanup and no completed draft/session remains active for later restoration

### Requirement: Confirmed remote success retires the local session before normal success
A confirmed successful remote submission SHALL have one ViewModel-owned local finalization policy that reuses the existing persistence-first draft/session clear and staged-session cleanup. Normal submission success SHALL be exposed only after that local finalization succeeds, at which point the old persisted draft is absent, completed-session staged assets are no longer active, and exactly one fresh clean submission identity is exposed. Progress-screen Back, Home, and `Nuovo suggerimento` SHALL NOT duplicate this finalization.

#### Scenario: Remote success finalizes once before success UI
- **WHEN** the backend confirms submission and local finalization succeeds
- **THEN** the completed session is retired once before the submission operation reports normal success, and later progress navigation performs no additional clear

#### Scenario: Successful finalization creates a clean next session
- **WHEN** the old session has been finalized successfully
- **THEN** reopening or returning to the form exposes empty clean state with a new identity and cannot restore the completed persisted draft or its staged assets

#### Scenario: Local finalization failure is distinct from remote failure
- **WHEN** the backend has confirmed submission but local draft/session finalization returns an error
- **THEN** the system records that remote success in current runtime state, does not report the operation as an ordinary resendable remote failure, and presents an explicit local-finalization recovery state

#### Scenario: Finalization retry never resends confirmed content
- **GIVEN** remote success is recorded and local finalization remains incomplete
- **WHEN** the user activates `Riprova`
- **THEN** only local finalization is retried, no asset upload or final remote submission call is repeated, and successful retry exposes normal success with a fresh clean session

#### Scenario: Incomplete finalization cannot navigate into stale completed work
- **WHEN** remote success is recorded but local finalization remains incomplete
- **THEN** Back, system/predictive back, Home, and new-submission navigation remain unavailable until finalization succeeds, while `Riprova` remains available for local finalization only

#### Scenario: Multiple finalization attempts rotate once
- **WHEN** one or more local finalization attempts fail before a later attempt succeeds
- **THEN** the remote submission is sent once, each retry targets the same completed session, and successful state rotation occurs exactly once

### Requirement: Subplan 3 reuses earlier hardening without claiming release readiness
This capability SHALL reuse the explicit draft checkpoint, checkpoint baseline, durable client submission identity, local lifecycle serialization, staged-asset ownership, retry-safe upload behavior, and persistence-first clear established by Content Submission Hardening Subplans 1 and 2. It SHALL NOT duplicate those mechanisms, add backend contracts, or represent completion of this navigation/lifecycle subplan as whole-feature release readiness.

#### Scenario: Existing durable boundaries remain authoritative
- **WHEN** guarded exits, external launches, submission transitions, retries, or finalization need persistence behavior
- **THEN** they invoke or extend the existing checkpoint, serialized lifecycle, staged-session, Command, and clear primitives rather than creating parallel draft or asset infrastructure

#### Scenario: Backend remains unchanged
- **WHEN** this capability is implemented
- **THEN** Supabase schemas, migrations, RLS, RPCs, Edge Functions, remote payloads, and Cloudinary retry semantics remain unchanged

#### Scenario: Completion is reported as Subplan 3 only
- **WHEN** every requirement in this capability is verified
- **THEN** the result is reported as completion of the Form Exit Guard & Progress Route subplan and whole-program release readiness remains deferred to the complete hardening sequence
