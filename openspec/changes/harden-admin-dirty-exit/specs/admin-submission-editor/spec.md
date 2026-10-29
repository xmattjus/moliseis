# Spec Delta

## MODIFIED Requirements

### Requirement: One active editor survives page changes
The application SHALL own one active Admin editing session shared by editor and progress presentations. Normal target changes SHALL refuse unsettled work and unresolved recovery checkpoint obligations. Uncheckpointed field changes SHALL require an explicit exit decision before replacement. Same-target reconstruction SHALL reuse initialization and session state. Local checkpointing SHALL accept incomplete fields without remote Save.

#### Scenario: Replacement would abandon work
- **GIVEN** A contains uncheckpointed fields or an admitted mutation
- **WHEN** navigation requests target B
- **THEN** A remains active until any mutation settles and, for local field edits, a current explicit exit decision succeeds
- **AND** no implicit checkpoint, remote request or second editor is created

#### Scenario: Checkpoint then switch
- **GIVEN** A has incomplete editable values
- **WHEN** the user explicitly checkpoints A and later switches after settlement
- **THEN** A restores losslessly when reopened and B receives independent authority

## ADDED Requirements

### Requirement: Exit prompts reflect local field changes only
Admin New and Edit SHALL use one exit policy comparing current fields with the effective local baseline. Remote unsaved work, durable staged assets, receipts and unresolved write intent SHALL NOT alone trigger field-discard confirmation. Existing moderation dirtiness SHALL retain its broader remote-work meaning.

#### Scenario: Pristine new editor
- **WHEN** an untouched new editor is left with no running barrier
- **THEN** removal needs no dialog, local write or remote request

#### Scenario: Remote work is locally checkpoint-clean
- **WHEN** current fields equal the effective baseline but remote confirmation, staged assets or an unresolved write outcome remain
- **THEN** ordinary page exit needs no field-discard prompt and retains all durable work
- **AND** this does not grant remote Save or moderation authority

#### Scenario: Uncheckpointed fields
- **WHEN** current fields differ from the effective baseline and an otherwise admissible page removal or target change is requested
- **THEN** exactly one three-choice Save and Exit, Discard and Exit, Cancel dialog is presented

### Requirement: Save and Exit confirms a local checkpoint
Save and Exit SHALL checkpoint only immutable reviewed fields for the exact activation, accepting incomplete input and preserving intents and staged work. Superseded field or baseline/recovery state SHALL refuse before persistence, without substituting newer fields. Removal SHALL require confirmed reviewed fields, checkpoint-clean current fields and current decision authority. Copy SHALL distinguish local checkpoint from separately admitted remote Save/Progress.

#### Scenario: Local checkpoint succeeds
- **WHEN** Save and Exit checkpoints the captured current fields successfully with unchanged exit authority
- **THEN** removal is authorized once and the same session can restore those fields
- **AND** no Create, Update, upload, association or moderation request is issued

#### Scenario: Checkpoint fails or newer typing remains
- **WHEN** checkpointing fails, authority becomes stale, or newer edits remain uncheckpointed after it finishes
- **THEN** removal is refused and all local work remains in the editor
- **AND** an error is shown only by the still-current private presentation, with explicit retry available

#### Scenario: Reviewed fields superseded before checkpoint execution
- **GIVEN** the exit decision reviewed immutable fields A and their effective baseline, field revision and recovery context
- **WHEN** the Exit checkpoint waits behind local work and current fields change to B before its serialized action executes
- **THEN** that action refuses before any Exit checkpoint write or baseline advancement
- **AND** it neither persists unreviewed B nor silently reselects it; exit is refused and B remains available

#### Scenario: Newer fields arrive after reviewed persistence begins
- **GIVEN** the reviewed A passed serialized admission and its persistence has begun
- **WHEN** current fields become B before that write completes successfully
- **THEN** the write may finish for A without rollback, P/E become A under the same activation, and current B remains uncheckpointed
- **AND** B is neither overwritten nor confirmed and the owning exit is refused

#### Scenario: Equal fields do not revive a superseded decision
- **WHEN** current fields still equal reviewed A but its effective baseline, relevant baseline/recovery identity, field revision or activation has been superseded before persistence
- **THEN** the Exit checkpoint refuses without writing even if a clean-state check would pass
- **AND** an obsolete A1 result cannot authorize removal in A2 or another route

#### Scenario: Affirmative exit requires the reviewed checkpoint and current authority
- **WHEN** the reviewed checkpoint completes and the owning router invocation is about to authorize removal
- **THEN** it requires confirmed reviewed A, unchanged reviewed field intent, checkpoint-clean current fields and the original route/account/session/target/activation authority
- **AND** only its own checkpoint baseline advancement and matching recovery-proof settlement are permitted; unrelated supersession refuses exit

### Requirement: Cancel and discard retain private work boundaries
Cancel or dismissal SHALL retain the editor unchanged. Discard and Exit SHALL authorize removal only after successful restoration to the reviewed effective baseline with current authority. It SHALL NOT erase physical checkpoints, accepted remote evidence, staged work, unresolved intents or recovery obligations.

#### Scenario: Discard succeeds with different physical baseline
- **GIVEN** P=A and E=B with current edits C
- **WHEN** current authorized Discard and Exit succeeds
- **THEN** C becomes B and the owning removal proceeds once while P remains A

#### Scenario: Discard fails
- **WHEN** discard fails or its reviewed revision is superseded
- **THEN** no removal occurs and newer fields and all durable work remain available

#### Scenario: Cancel and modal Back
- **WHEN** Cancel, Escape, modal Back or barrier dismissal occurs
- **THEN** no field, persistence or underlying route-pop effect is authorized

### Requirement: One exit decision owns one exact transition
All Admin exit entry points SHALL share one single-flight decision owner. Permission SHALL bind its source route visit, account/session/target/activation and exact transition; it SHALL NOT be a reusable boolean or shared affirmative future. Competing attempts SHALL be refused. Authority SHALL be rechecked across every await and before removal; cancellation or failure SHALL release only its own ownership.

#### Scenario: Concurrent Back and programmatic removal
- **WHEN** Back and a programmatic removal overlap during a dialog or checkpoint
- **THEN** only the owning attempt can proceed, with one dialog and at most one route removal
- **AND** no second attempt inherits its affirmative result or pops the dashboard underneath

#### Scenario: Different target while a dialog is pending
- **WHEN** a second request targets another submission or session while the first decision is pending
- **THEN** the second request is refused and cannot change the dialog's captured destination
- **AND** covered, replaced or obsolete private presentation cannot authorize any later target

#### Scenario: A1 returns as A2
- **WHEN** an exit result arrives after activation replacement or A1 to B to A2
- **THEN** matching durable identifiers do not revive its authority or produce errors, checkpoint, discard or navigation in A2

### Requirement: Platform exit controls preserve route ownership
AppBar Back, Android system/predictive Back, iOS edge gestures, Escape and programmatic navigation SHALL obey the same exit policy. A dirty iOS native edge gesture SHALL be disabled before it begins; clean native swipe SHALL remain available. Explicit Back SHALL still reach the decision policy without enabling a reusable pop bypass.

#### Scenario: Dirty and clean iOS gestures
- **WHEN** iOS renders dirty fields or an owned exit decision
- **THEN** a native edge gesture cannot begin or reveal the underlying route
- **AND** clean idle fields permit native swipe and explicit Back still supports all three choices

#### Scenario: Escape outside a modal
- **WHEN** Escape requests an editor exit on desktop with no covering route
- **THEN** it enters the same guarded policy and cannot pop a covered underlying route

### Requirement: Running operations and retained pages are not dirty exits
Ongoing Save admission, in-flight mutations and existing local operation barriers SHALL block ordinary removal without a dirty dialog or a bypass. A pushed progress page retaining the editor SHALL NOT count as editor removal. Terminal progress Back SHALL pop only progress. Successful moderation SHALL permit only its currently authorized editor closure; Save success SHALL keep the editor open.

#### Scenario: Mutation already admitted
- **WHEN** an ordinary exit is attempted during Save or another admitted mutation
- **THEN** no dirty dialog, remote retry or removal is admitted, even if field edits coexist

#### Scenario: Progress return
- **WHEN** a terminal progress page pops to its exact retained editor
- **THEN** no editor exit decision occurs, even if newer editor fields are uncheckpointed

#### Scenario: Moderation closure
- **WHEN** a current successful moderation terminal owns its editor-close effect
- **THEN** only that editor closure is authorized without dirty confirmation
- **AND** an old, hidden or revoked terminal cannot grant later removal permission

### Requirement: Recovery obligations outlive page removal
A pending explicit recovery checkpoint obligation SHALL survive ordinary page removal and same-session restoration in the application-owned session. It SHALL continue refusing different target/session activation until matching checkpoint proof succeeds. Field discard SHALL NOT satisfy that obligation. Actual auth revocation SHALL retain its existing immediate security lifecycle.

#### Scenario: Locally clean accepted recovery leaves page
- **GIVEN** C=E=B, P=A and a pending recovery checkpoint obligation
- **WHEN** the user returns to the dashboard then reopens the same session
- **THEN** B and its obligation remain without a field-discard prompt or implicit write
- **AND** another target/session is still refused with access back to the active editor and explicit checkpoint recovery

#### Scenario: Direct different-ID navigation
- **WHEN** direct navigation changes an Admin submission ID while the route pattern remains the same
- **THEN** the outgoing activation is protected by the same policy before replacement
- **AND** pending recovery refusal remains actionable without an automatic decision dialog or checkpoint

#### Scenario: Dirty accepted recovery distinguishes removal from replacement
- **GIVEN** local fields differ from E while an explicit recovery checkpoint obligation remains
- **WHEN** another target/session is requested
- **THEN** replacement is refused without a dialog or automatic checkpoint/discard
- **AND** a separate page-only return to the dashboard offers the field choices while retaining the obligation after successful discard

#### Scenario: Query-only resume hint cannot bypass protection
- **WHEN** a same-pattern query change requests a different or mismatched session
- **THEN** source authority and account/target agreement are checked before rebinding
- **AND** no dirty fields or recovery obligation are abandoned by route-State reuse

### Requirement: Auth revocation preempts exit decisions
Logout, account replacement and loss of Admin authority SHALL immediately revoke private exit effects and allow required security navigation without waiting for a dirty-exit decision, local checkpoint or physical remote completion. Obsolete dialogs SHALL be retired by exact modal identity without popping underlying pages.

#### Scenario: Logout with open dialog or checkpoint
- **WHEN** authorization is revoked while a private exit decision or checkpoint is pending
- **THEN** required security navigation proceeds immediately and the dialog can authorize no further work or route effect
- **AND** an already-started local write can settle only for its original private owner and cannot expose data to the replacement account
