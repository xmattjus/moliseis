## ADDED Requirements

### Requirement: Admin editor admission binds one execution synchronously

The editor SHALL reserve each accepted request and its immutable inputs before notifications or deferred execution. Same-operation duplicates and busy conflicting requests SHALL be refused without queueing, joining, replacing an accepted request or publishing a terminal result for the refused attempt. Refusal SHALL change neither desired input nor execution snapshots. Admission success SHALL NOT mean persistence success.

#### Scenario: Duplicate before deferred entry

- **WHEN** two Save requests arrive before the first action enters
- **THEN** only the first is accepted and persists its own captured fields once
- **AND** the second changes no request slot or result snapshot

#### Scenario: Conflicting mutations

- **WHEN** Save, Reject, Promote, Link, Apply, KeepCurrent, AddAsset or DeleteAsset owns the editor mutation reservation
- **THEN** all other mutation requests are refused until safe settlement
- **AND** disabled UI controls are supplementary to the editor admission check

#### Scenario: Refusal and validation failure remain distinct

- **WHEN** a busy request is refused and a later idle request fails normal validation
- **THEN** refusal leaves execution snapshots unchanged while the admitted invalid attempt produces its expected application error
- **AND** a corrected explicit retry can execute after safe settlement

### Requirement: Admin editor hydration cannot erase accepted work

Public detail loading SHALL be exclusive with other operations and SHALL refuse to replace a loaded dirty draft. A detail response SHALL hydrate only the still-current owner and draft revision. Internal resolution refresh SHALL retain the outer operation's authority without requiring public Load admission.

#### Scenario: Public load conflicts with work

- **WHEN** Load is reserved or another editor operation is reserved
- **THEN** overlapping public Load and editor work are refused in both admission orders

#### Scenario: Draft changes during load

- **WHEN** local fields change after a detail request was admitted but before its response
- **THEN** the response cannot replace the newer draft or publish a current hydration success

### Requirement: Admin editor Save success identifies the persisted draft

Save SHALL persist its admission-time field snapshot using the route's existing create/update identity. A successful response SHALL clear dirty and authorize closure only for its terminal execution ID and matching clean draft revision. A new Save admission SHALL revoke the previous closure association. Later edits SHALL be retained. Create success SHALL NOT adopt a new identity or introduce an automatic follow-up save.

#### Scenario: Newer draft while Save is pending

- **WHEN** Save persists revision A while newer revision B exists locally
- **THEN** B remains dirty and visible and the editor does not close as though B were saved
- **AND** only an explicit later Save can persist B

#### Scenario: Snapshot and original identity

- **WHEN** accepted Save inputs or nested description data are changed before deferred entry
- **THEN** the accepted immutable snapshot and original route ID determine the request
- **AND** create remains create without adopting the returned ID

### Requirement: Admin editor explicit reads publish only current context

Candidate input editing SHALL invalidate prior result authority without starting or queueing I/O. Explicit single-flight search SHALL capture current desired input only after admission. Refusal SHALL change no input, receipt or snapshot. Input, draft, target or source changes SHALL revoke obsolete read data and feedback; physical completion SHALL NOT restore candidates, incompatible preview or Apply readiness.

#### Scenario: Search input changes and returns

- **WHEN** candidate search A is pending and input changes A to B to A
- **THEN** the old A response remains obsolete despite equal final text
- **AND** a request while that lane is busy is refused; a fresh explicit request is possible after settlement

#### Scenario: Separate input edit and refused search

- **WHEN** search A is pending, input is explicitly set to B, then another search is requested
- **THEN** the setter alone invalidates A without I/O or changing its captured input
- **AND** the refused search changes nothing further, creates no receipt and adds no feedback
- **AND** after A settles, an explicit admitted search sends exactly B

#### Scenario: Obsolete candidate failures

- **WHEN** A is invalidated by desired-input editing and later returns expected error or throws a raw runtime failure
- **THEN** no stale candidates or failure feedback appear
- **AND** the original handled raw Object and stack still report once globally

#### Scenario: Input changes during mutation

- **WHEN** desired search input changes while another mutation is admitted
- **THEN** only candidate input and stale candidate presentation change, without implicit search, mutation reinterpretation or reservation release
- **AND** an explicitly admitted blank query retains the repository's null search-name semantics

#### Scenario: Target returns to A

- **WHEN** preview for A is pending and target changes A to B to A
- **THEN** its old generation cannot publish a preview or current success or enable Apply

#### Scenario: Mutation overtakes advisory read

- **WHEN** an allowed mutation is admitted while preview or candidates are pending
- **THEN** it revokes their old publication before deferred mutation entry
- **AND** their later completion cannot undo the mutation's state or source acknowledgement

#### Scenario: Current source display changes in preview

- **WHEN** an authoritative preview returns a newer source hash
- **THEN** the preview and source display update together, prior acknowledgement is revoked and unrelated older candidate context is invalidated

### Requirement: Admin editor results preserve failure kind and original reporting

Each accepted attempt SHALL have a distinct execution identity even for equal Result values. New admission SHALL publish its own running state and revoke previous terminal authority. Outcomes SHALL distinguish neutral, success, expected Result error and runtime failure. Original handled runtime Object and stack SHALL report once, including after revocation. Assertions SHALL remain fail-loud.

#### Scenario: Real void success

- **WHEN** an operation returns successful void Result
- **THEN** it is completed success distinct from never-run neutral state

#### Scenario: Late raw failure

- **WHEN** retained editor work throws a handled raw error after owner disposal
- **THEN** its original error and stack are reported once without a fabricated Result.error, duplicate report or disposed-notifier secondary failure

#### Scenario: Nested phase failure

- **WHEN** a private phase of KeepCurrent or moderation throws
- **THEN** only the owning outer operation reports that original runtime failure
- **AND** no internal Save completion navigates the editor

#### Scenario: Equal outcomes belong to different executions

- **WHEN** two consecutive accepted executions produce equal Results using the same reusable lane
- **THEN** they retain distinct execution identities and separately observable running and terminal outcomes
- **AND** old callbacks cannot publish a duplicate into the second attempt or reset its busy state

### Requirement: Admin editor navigation consumes current completion once

Editor effects SHALL consume owner/lane/execution IDs once without bind-time replay. Navigation SHALL require the current editor route and pop(true). Covered terminals SHALL have no feedback or replay. Only a current owned status dialog MAY retain a clean Save latch; coverage SHALL revoke its session permanently. Deferred closure SHALL require current route/owner/session and Save ID/revision authority; later Save admission SHALL revoke old authority. Obsolete callbacks SHALL have no effect.

#### Scenario: Save during open status dialog

- **WHEN** a matching clean Save succeeds while Publish or Reject confirmation is open
- **THEN** completion is retained without popping underneath the dialog
- **AND** dialog completion closes the editor once with true and starts no stale moderation

#### Scenario: Newer draft invalidates Save latch

- **WHEN** fields become dirty after the success captured by an open dialog
- **THEN** the old Save latch cannot close the editor or authorize confirmation of the changed draft

#### Scenario: Owner changes during dialog

- **WHEN** the screen is unmounted or receives another owner before confirmation resolves
- **THEN** its old callback neither navigates, reports feedback, admits work nor clears a newer dialog session

#### Scenario: Repeated notifications after terminal

- **WHEN** the same terminal outcome is observed again during data notifications or admission reopening
- **THEN** it causes no second snackbar or route pop

#### Scenario: Save success then error then successful retry

- **WHEN** Save A succeeds and settles under an open status dialog, B is admitted and fails, then C is admitted and succeeds
- **THEN** B admission revokes A's closure authority and B failure inherits no success
- **AND** C has its own terminal revision association; dialog completion may close once only for C, without replaying A or B feedback

#### Scenario: Superseded Save latch cannot confirm moderation

- **WHEN** an open dialog observed Save A success, then Save B was admitted and failed without changing the clean draft
- **THEN** closing that dialog neither uses A to navigate nor falls through to stale confirmed moderation
- **AND** a later same-session matching Save success may provide only its own deferred closure authority

#### Scenario: Binding to existing terminal and replacing owner

- **WHEN** a screen binds to an owner already holding a terminal outcome or replaces that owner before its pending work completes
- **THEN** the old outcome is not replayed and late old-owner work cannot cause effects on the replacement
- **AND** genuinely new terminal execution IDs on the current owner can be consumed once

#### Scenario: Covered editor consumes without visible effects

- **WHEN** a pushed page retains a live editor underneath it and Save or moderation reaches a terminal
- **THEN** the editor consumes that execution without popping the covering page or producing a snackbar
- **AND** returning to the editor does not replay the consumed terminal, while raw failures retain global reporting

#### Scenario: Covered owned dialog loses deferred authority

- **WHEN** a distinct page covers the editor's active confirmation dialog before or after a Save latch was acquired
- **THEN** that dialog session cannot navigate or confirm moderation after the covering page returns
- **AND** a Save under an uninterrupted current owned dialog still closes the editor once after confirm or cancel when its execution and revision remain authorized

### Requirement: Admin editor revocation preserves private physical settlement

Each lane SHALL reuse one private Command and stable private observation while its owner is live. Safe execution settlement SHALL release only its receipt and reservation. Owner revocation SHALL stop public forwarding and new phases immediately. Pending Commands SHALL remain alive for original late-error reporting; after revocation each SHALL be disposed once, outside dispatch after safe settlement. Nonterminating work SHALL NOT be declared cancelled.

#### Scenario: Failed execution then successful retry reuses its lane

- **WHEN** an execution returns Result.error, safely settles and an explicit retry succeeds
- **THEN** the same live lane remains usable with a new receipt, without Command disposal or duplicated observation
- **AND** execution settlement does not remove observers required by future attempts

#### Scenario: Revoke during second execution

- **WHEN** the owner is revoked during its second execution after the first settled
- **THEN** the idle lanes release deferred, while the active lane retains private observation until physical settlement
- **AND** a late handled runtime failure reports its original error once, publishes no UI state and releases that Command once

#### Scenario: Dispose before deferred action

- **WHEN** owner revocation occurs before an admitted action enters
- **THEN** no picker or repository phase starts and the skipped receipt settles privately; after revocation its Command releases once without public completion

#### Scenario: Reentrant terminal admission

- **WHEN** a terminal listener requests new work before upstream finally and deferred dispatch finish
- **THEN** it is refused without overwriting the original receipt
- **AND** an explicit request after safe reopening stays reserved independently of the previous execution

#### Scenario: Revocation between private phases

- **WHEN** an owner is revoked after one private phase settles or reentrantly during a state notification
- **THEN** no subsequent repository phase, public commit or navigation starts

#### Scenario: Nonterminating work and assertion

- **WHEN** physical work remains pending or an assertion bypasses ordinary terminal routing
- **THEN** pending work is retained without invented cancellation, while assertion receipts settle privately and remain fail-loud; a live lane stays reusable and only revoked safe lanes dispose their Commands
