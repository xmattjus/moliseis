## MODIFIED Requirements

### Requirement: Confirmed remote success retires the local session before normal success
While its ViewModel owner remains live, a confirmed successful remote submission SHALL have one ViewModel-owned local finalization policy that reuses the existing persistence-first draft/session clear and staged-session cleanup. Normal submission success SHALL be exposed only after that local finalization succeeds, at which point the old persisted draft is absent, completed-session staged assets are no longer active, and exactly one fresh clean submission identity is exposed. Progress-screen Back, Home, and `Nuovo suggerimento` SHALL NOT duplicate this finalization.

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

#### Scenario: Disposed operation does not publish normal success
- **WHEN** an already-started remote request or local retirement settles after owner disposal
- **THEN** the disposed owner starts no further repository phase, publishes no progress success and triggers no navigation or form reset


## ADDED Requirements

### Requirement: Progress distinguishes neutral and both failure kinds
Progress SHALL distinguish neutral restoration, running, successful application completion, application failure and handled runtime failure. Admission SHALL block duplicate submission and Back before deferred action entry. Immediate retry SHALL require a stopped terminal failure plus confirmed pending local finalization; ordinary failures SHALL retain Back, Home and form recovery without immediate replay.

#### Scenario: Progress observes immediate admission
- **WHEN** a valid checkpoint is followed by accepted submission and progress navigation before action entry
- **THEN** progress blocks Back and shows running rather than interrupted idle or stale prior success

#### Scenario: Retry clears stale terminal state
- **WHEN** local-finalization retry is accepted
- **THEN** retry immediately becomes unavailable, progress is running and no old failure or success is treated as the new result

#### Scenario: Runtime failure before acknowledgement
- **WHEN** submission stops with a handled runtime failure before acknowledgement
- **THEN** failure is shown, no immediate retry is offered and returning to the form preserves the same session

#### Scenario: Runtime failure after acknowledgement
- **WHEN** local finalization stops with a handled runtime failure while confirmed success remains pending
- **THEN** local-only retry is offered and Back and Home remain blocked

#### Scenario: Process-restored neutral operation
- **WHEN** a new ViewModel restores the progress route without runtime execution state
- **THEN** it displays interrupted idle with return to the form and performs no automatic submit, retry, clear or rotation

### Requirement: Replaced Content Submission consumers revoke old callbacks
Retained form, asset-list and progress consumers SHALL detach the previous owner and observe the replacement. Pending callbacks SHALL require a mounted consumer, the captured owner and the captured current session or transition before feedback, external launch or navigation. Owner replacement SHALL reset owner-bound form presentation even for equal session identifiers without replaying old edits.

#### Scenario: Same State receives a replacement owner
- **WHEN** the form and list receive B while retaining their State objects from A
- **THEN** B notifications update the UI, A notifications do not, forms reflect B and no old listener remains attached at disposal

#### Scenario: Selection warning arrives from old owner
- **WHEN** an asset selection admitted by A finishes after the consumer rebinds to B
- **THEN** no warning, success feedback or asset mutation is attributed to B

#### Scenario: Deferred bootstrap is obsolete
- **WHEN** owner replacement or unmount precedes the form's recovery callback
- **THEN** the obsolete callback starts no recovery and the current owner receives at most one valid bootstrap request

#### Scenario: Checkpoint returns after replacement
- **WHEN** a submit, external-link or exit checkpoint completes after its captured owner or session becomes obsolete
- **THEN** no old-owner submit, external launch, route removal or progress push follows and its transition token is released

### Requirement: Asset feedback belongs to an accepted execution
Asset selection warnings SHALL be emitted at most once for the caller's own accepted successful terminal outcome while owner and session remain current. Ignored requests, retained values, joined waiters and disposal SHALL NOT imply success. Existing generic oversized and capacity wording SHALL remain free of file names.

#### Scenario: Duplicate tap has no duplicate warning
- **WHEN** selection is already pending and another add tap is ignored
- **THEN** at most the original accepted execution can produce one warning and no second picker opens

#### Scenario: Retired session warning is stale
- **WHEN** a picker request completes after its session was retired
- **THEN** it creates neither assets nor warning feedback for the fresh session

### Requirement: Form transition runtime failures stop their boundary
Unexpected failures of a direct checkpoint or restore awaited by a form transition SHALL be reported once with the original error and stack without fabricated application success. They SHALL start no subsequent submission, external launch or route removal, and SHALL release transition ownership. Obsolete consumers SHALL show no feedback. Assertion failures SHALL preserve fail-loud behavior.

#### Scenario: Unexpected pre-submit checkpoint failure
- **WHEN** a direct form checkpoint throws before submission admission
- **THEN** no submission or progress navigation starts, the error is reported once and transition ownership is released

#### Scenario: Unexpected exit or external checkpoint failure
- **WHEN** a direct restore or checkpoint throws while an exit or external-link transition is pending
- **THEN** no route removal or external launch follows, reporting preserves the original error and stack and no obsolete consumer shows feedback
