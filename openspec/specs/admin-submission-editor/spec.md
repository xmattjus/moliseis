# admin-submission-editor Specification

## Purpose

Provide one account-owned durable Admin editing session with continuous Save, recoverable staged progress and navigation that observes admitted work.

## Requirements

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

### Requirement: Account and activation authority guard every effect
Revocation SHALL immediately hide private editor state and prevent new remote phases or stale publication. Callbacks and effects SHALL retain their original account/session/target/activation authority. Already-sent HTTP MAY complete, but SHALL NOT mutate a replacement session. A physical operation reservation SHALL release only on its own settlement.

#### Scenario: Account A to B
- **WHEN** A's operation completes after revocation and activation of B
- **THEN** B receives none of A's fields, assets, errors, navigation effects or successful status
- **AND** captured durable commits remain recoverable only for A

#### Scenario: Session A1 to B to A2
- **WHEN** a setter, dialog, load, picker or command from A1 completes after A2 activates
- **THEN** equal target or session identifiers do not restore A1 publication authority

### Requirement: Remote hydration preserves local intent
Restoration and fresh detail loading SHALL keep physical durability, effective local baseline and confirmed remote state distinct. Hydration SHALL not erase typing or checkpointed unconfirmed edits. Incompatible or failed loading SHALL settle as unavailable/conflicting while preserving work and permitting return or explicit reload.

#### Scenario: Typing during restore or hydration
- **GIVEN** a remote request was admitted before local edit B
- **WHEN** that request completes
- **THEN** B is not replaced, and stale success/failure cannot authorize a newer activation

#### Scenario: Checkpointed unconfirmed edit
- **GIVEN** local checkpoint A differs from its recorded remote baseline
- **WHEN** incompatible fresh remote B arrives
- **THEN** A remains intact even if locally checkpoint-clean and remote mutation stays unavailable until compatible authority exists

### Requirement: Save confirms only captured work
Save SHALL capture immutable fields and ordered staged identities at admission, checkpoint the attempt, persist remotely, adopt Create identity, then persist remaining staged assets in order. Later fields/checkpoints or uncaptured staged items SHALL remain pending. All remote calls SHALL execute outside local persistence arbitration.

#### Scenario: Checkpoint A settles after typing B
- **WHEN** A's checkpoint or remote confirmation finishes while C contains B
- **THEN** A alone is confirmed and B remains current and remotely unconfirmed
- **AND** a newer physical checkpoint B is not overwritten with A

#### Scenario: First Save followed by Save
- **GIVEN** new local UUID A has no remote ID
- **WHEN** Create and local adoption succeed and the user later Saves again
- **THEN** the same logical session uses Update for the authoritative ID and never issues a second Create

### Requirement: Staged Save preserves monotonic confirmed progress
New submissions SHALL permit local selection, preview and exact-identity removal before Create. Save SHALL preserve separate local bytes, confirmed upload and confirmed association facts. Retry SHALL skip confirmed work and retain failed/unstarted files. Moderation SHALL remain unavailable while fields, staged work or remote outcomes remain unconfirmed.

#### Scenario: Second image upload fails
- **GIVEN** first association and second upload receipt are confirmed but later work fails
- **WHEN** retry is explicitly admitted
- **THEN** confirmed association is not uploaded or inserted again, and confirmed second upload is reused
- **AND** unstarted files retain deterministic order

#### Scenario: Association reply is lost
- **WHEN** database association may have committed but its response is unavailable
- **THEN** the upload receipt and local file remain available and retry uses association replay rather than another upload

#### Scenario: Existing pending submission receives a new image
- **WHEN** a normal live picker returns for an already-persisted pending submission
- **THEN** its existing immediate upload/association behavior remains available with existing size/status/capacity protections
- **AND** interrupted-media restoration never starts that upload automatically

### Requirement: Save progress observes admitted work
Save SHALL be admitted synchronously before progress navigation. The progress route SHALL only observe the shared session/attempt and SHALL NOT start or repeat commands from initialization, build or restoration. Running work SHALL block ordinary Back paths while auth revocation remains effective.

#### Scenario: Route rebuild or reconstruction
- **WHEN** progress rebuilds or is reconstructed without a matching live attempt
- **THEN** no Save is issued and an interrupted presentation permits return to the exact editor session

#### Scenario: Cold progress restoration for an adopted new session
- **GIVEN** restorable route metadata identifies the original local session UUID
- **WHEN** progress/editor routes reconstruct after Create adoption
- **THEN** account-checked local lookup restores the adopted session without allocating a fresh new owner or invoking Save

#### Scenario: Repeated Save tap
- **WHEN** a Save is already admitted or physically settling
- **THEN** another tap cannot admit or navigate for a second execution

### Requirement: Terminal Save states remain usable and honest
Progress SHALL distinguish completed, partial, recoverable failure, unknown remote outcome and unexpected failure. Every terminal state SHALL allow return to the same editor. Retry SHALL require matching presentation authority and a safe phase policy; ambiguous Update SHALL use explicit read-back rather than blind resend.

#### Scenario: Unknown Update
- **WHEN** Update response is lost
- **THEN** the editor retains local fields and progress offers return/read-back without claiming failure or success
- **AND** equality confirms observed fields and further writes remain conditional on the exact server token, while different/missing/moderated remote state follows the guarded recovery branches below

#### Scenario: Local adoption or receipt persistence fails
- **WHEN** remote work is confirmed but local metadata is not committed
- **THEN** progress reports partial/local repair, preserves confirmed evidence and does not repeat confirmed remote work solely to clean up

### Requirement: Successful Save preserves the open editor
Save success SHALL keep the editor open, adopt authoritative identity/status without erasing newer fields or known assets, and invalidate obsolete moderation confirmations. Other moderation operations SHALL retain their existing protections and SHALL NOT be moved into Save Progress.

#### Scenario: Save completes with a status dialog open
- **WHEN** the admitted Save settles
- **THEN** it neither closes the editor nor executes the old confirmation
- **AND** a fresh confirmation is required under current revision/authority

#### Scenario: Update response omits associations
- **WHEN** a field Update succeeds with an incomplete asset envelope
- **THEN** known confirmed associations are preserved until a complete authoritative asset refresh replaces them

### Requirement: Dashboard refresh does not depend on Save pop result
Returning from either editor entry route SHALL refresh the current authorized dashboard regardless of a boolean result. Progress return to the editor SHALL not be treated as editor exit.

#### Scenario: Save remains open then user returns
- **WHEN** an administrator Saves and later leaves the editor normally
- **THEN** the current dashboard reloads even without a true route result

#### Scenario: Untouched editor exits
- **WHEN** an editor returns without changing remote content
- **THEN** the same harmless dashboard refresh occurs subject to owner/account/mounted checks

### Requirement: Unresolved Update recovery distinguishes version and projection
Read-back SHALL compare captured A/V with the authoritative row. Compatible pending A SHALL confirm only its observed row/token. A compatible pending row still at V SHALL permit explicit original A/V retry through the existing Save Command. Other outcomes SHALL follow the scenarios below without borrowing a fresh token or inferring old HTTP settlement. All branches SHALL preserve newer C/P.

#### Scenario: Intent committed before dispatch and remote remains V
- **GIVEN** durable Update A/V and newer local checkpoint B survive process death
- **WHEN** explicit read-back observes the compatible pending row at V with fields different from A
- **THEN** the editor/progress offers explicit original A/V continuation, leaving B untouched
- **AND** initialization, route reconstruction and read-back perform no Update

#### Scenario: Original A and retry race
- **WHEN** explicit original A/V retry races the old request
- **THEN** the existing exact-token predicate fences a later incompatible write
- **AND** token rejection requires read-back again rather than blind retry, fresh-token substitution or presumed success

#### Scenario: Newer remote fields have another token
- **WHEN** read-back returns fields other than A at a different exact token
- **THEN** local work remains and the obsolete intent is locally settled as conflict
- **AND** no immediate Save using the historical token or automatic overwrite with the new token is allowed

#### Scenario: Read-back cannot establish a compatible pending row
- **WHEN** the row is missing, finalized, provenance-incompatible, or cannot be read
- **THEN** no remote mutation is admitted and local work is retained
- **AND** a read failure retains the unresolved intent rather than proving non-application

### Requirement: Protected remote fields have explicit recovery choices
Existing hydration protects local intent. The editor SHALL additionally present the current local fields alongside a fresh incompatible remote observation, identify differing editable groups and status, and offer explicit acceptance or local preservation. Neither observation nor either choice SHALL execute Save, merge fields automatically or imply physical durability. Uncheckpointed explicit acceptance SHALL refuse ordinary target replacement with access to explicit checkpoint recovery.

#### Scenario: Incompatible checkpointed work is reviewed
- **GIVEN** local checkpoint L differs from its recorded remote baseline
- **WHEN** fresh pending remote B has incompatible editable fields
- **THEN** L remains current until a deliberate choice and the editor shows local versus B values for differing groups
- **AND** description and its rich content, schedule values, and city/coordinates are presented as coherent groups without automatic merging

#### Scenario: Accept observed remote fields
- **GIVEN** a current authorized observation and no unresolved write or settlement barrier
- **WHEN** the user accepts its remote fields
- **THEN** current and effective fields become the observed snapshot and confirmed remote baseline becomes that observation
- **AND** the physical checkpoint, owner and staged work remain unchanged, no persistence or remote mutation starts, and the UI explains that explicit checkpointing is still needed for durability

#### Scenario: Preserve local fields for later Save
- **GIVEN** a current authorized compatible pending observation and no unresolved write or settlement barrier
- **WHEN** the user chooses to keep local fields for a later Save
- **THEN** current/effective/physical fields remain unchanged while that observation becomes the remote comparison baseline and conditional authority
- **AND** only a separately admitted validated Save can send the preserved fields with the observed exact token under a new attempt identity

#### Scenario: F1 Refused switch has an actionable recovery path
- **GIVEN** explicit remote B was accepted over physical A and its checkpoint obligation remains
- **WHEN** an ordinary target change or explicit route/session hint requests another editor
- **THEN** the current activation and B remain available and the refused presentation explains that accepted fields must be checkpointed, with access back to that exact editor and its explicit local checkpoint action
- **AND** failed checkpoint keeps the refusal; matching success permits later switching subject to existing barriers
- **AND** no confirmation dialog, automatic discard/checkpoint, remote write or second editor is created

#### Scenario: F1 Page return retains application-owned acceptance
- **WHEN** the user leaves the editor page while an accepted decision remains uncheckpointed
- **THEN** the application owner retains B and its obligation; reopening the same session reuses them, and ordinary activation of a different target still refuses
- **AND** actual auth revocation immediately hides A's private state and permits security redirects under the existing account lifecycle

### Requirement: Recovery choices require current observation authority
Existing account and operation guards SHALL also govern recovery choices. A choice SHALL bind exact account, session, target, activation, observation and current local field revision. Superseding reads, edits, mutations or revocation SHALL invalidate old choices. Rechecking SHALL occur before baseline effects; rejected stale choices SHALL produce no field, persistence, mutation or navigation effect.

#### Scenario: Repeated callback after a completed choice
- **WHEN** a recovery choice has already completed for an observation
- **THEN** its consumed callback cannot apply another choice or repeat baseline effects

#### Scenario: Edit or refresh supersedes a rendered choice
- **WHEN** a field edit, another read admission or a mutation occurs after a recovery choice is rendered
- **THEN** the old callback is refused and a current comparison must be reviewed
- **AND** failure of a newer read does not reactivate the older observation

#### Scenario: Account and session return do not revive callbacks
- **WHEN** A1's read or choice completes after account/session replacement B then A2
- **THEN** none of A1's fields, receipt effects, errors, navigation or authority publishes into A2 even if durable identities match
- **AND** physically running work retains and releases only its original reservation on settlement

#### Scenario: Choice races queued checkpoint
- **WHEN** a recovery choice waits behind local work and its captured revision becomes obsolete
- **THEN** it is refused without resetting any newer checkpoint or accepted baseline

### Requirement: Fresh Save authority cannot replace unresolved request authority
Existing A/V recovery SHALL remain authoritative until safe durable settlement and physical barriers release. New Save SHALL capture its token from the accepted remote baseline, qualified by account/session/target/activation/observation. Display metadata SHALL grant no authority or change an intent. Token observation SHALL NOT imply cancellation or retry. Conditional Update and no-op field skipping SHALL remain.

#### Scenario: Original request remains possible at V
- **GIVEN** unresolved Update A/V and newer local B
- **WHEN** read-back observes compatible pending fields different from A at V
- **THEN** only existing explicit original A/V continuation or another read-back is available
- **AND** accepting or preserving an observation cannot clear the intent or authorize B/V, while checkpoint/return preserves B

#### Scenario: Another token fences the original request
- **GIVEN** unresolved A/V and observed incompatible fields at another exact token W
- **WHEN** existing read-back durably settles A/V as fenced conflict
- **THEN** no Save is automatically admitted
- **AND** a subsequent current observation and explicit local-preservation choice can authorize only a new captured Save against W

#### Scenario: Local proof settlement fails
- **WHEN** clearing a proven rejected or fenced intent fails in local persistence
- **THEN** all field choices granting mutation remain blocked, original work remains, and only existing safe local repair or read-back paths can remove that barrier
- **AND** retrying repair sends no remote field request

#### Scenario: Replayed Create returns changed remote content
- **WHEN** same-UUID Create replay discovers a changed or finalized authoritative record
- **THEN** existing atomic identity adoption is retained and subsequent recovery reviews that record without allocating another owner or creating again

#### Scenario: F2 New field attempt captures authorized W
- **GIVEN** original A/V was safely durably settled or fenced, its physical operation settled, and a current pending observation W is explicitly reconciled with Keep local
- **WHEN** a separate validated Save of local B is admitted
- **THEN** it captures the exact W from the accepted remote baseline and current account/session/submission/activation/observation qualification
- **AND** the same qualification is checked before new intent persistence and dispatch; the new B/W intent cannot take its token from display metadata
- **AND** later detail publication cannot rewrite B/W or historical A/V

#### Scenario: F2 Unresolved A/V cannot borrow W
- **GIVEN** original A/V still requires read-back or settlement and W is displayed by a detail refresh
- **WHEN** Keep local or a new Save tries to use W
- **THEN** no new field Save is authorized and any permitted original continuation still sends captured A/V unchanged

#### Scenario: F2 Superseded observation cannot authorize the attempt
- **WHEN** W is superseded, fails current qualification or becomes obsolete before reconciliation commits or before a newly captured attempt passes its pre-dispatch checks
- **THEN** that completion authorizes no new Save, performs no token substitution and preserves current local work for renewed recovery

#### Scenario: F2 Server advances W to X
- **GIVEN** a new local B/W attempt was safely admitted from reconciled W
- **WHEN** a concurrent server change advances W to X before the conditional Update applies
- **THEN** existing SUBMISSION_CHANGED handling preserves local fields/checkpoint and follows existing intent-settlement/read-back rules
- **AND** no automatic retry substitutes X

#### Scenario: F2 A1 token cannot authorize A2
- **WHEN** A1's observed W or reconciliation callback arrives after B and A2 activate, even with the same durable account/session/target identifiers
- **THEN** A1 cannot publish or supply the accepted baseline/token for A2 or release its operation reservation

#### Scenario: F2 No-op and asset-only Save preserve field skipping
- **GIVEN** no unresolved field intent and captured fields equal the current qualified accepted remote projection
- **WHEN** explicit Save has no field changes or only staged work
- **THEN** no field Update is sent merely to consume W or clear an acceptance checkpoint obligation
- **AND** existing local checkpoint and eligible staged receipt work retain their ordering without another mutable token authority

### Requirement: Unavailable recovery outcomes are explicit and settled
Existing protected failures SHALL additionally distinguish retryable reads, incompatible detail, finalized targets, missing targets and denied authority. Each attempt SHALL stop loading and retain local work. Explicit retry or recheck SHALL use new read authority without remote replay. Final/missing/denied state SHALL not authorize remote mutations or silently become Create.

#### Scenario: Transient read failure after a previous success
- **WHEN** a current remote read fails with a transport or expected transient error
- **THEN** current/effective/physical/remote baselines and staged evidence remain, old mutation authority is unavailable, and explicit Retry, local checkpoint and return remain usable
- **AND** retry starts one read without Save, upload, association or moderation

#### Scenario: Pending becomes final
- **WHEN** a fresh observation reports accepted or rejected status while local work remains
- **THEN** remote final status is shown separately from preserved local fields and Save, remote asset changes and moderation are unavailable
- **AND** local checkpoint/removal, return and deliberate recheck remain available without clearing unresolved intent merely because status is final

#### Scenario: Initial or later record is missing
- **WHEN** a read returns typed NOT_FOUND
- **THEN** a settled record-unavailable state retains local work and permits return, checkpoint when initialized, and deliberate recheck
- **AND** it offers no acceptance of invented remote fields, conversion to Create or automatic owner/intent deletion

#### Scenario: Backend denies authorization before local auth updates
- **WHEN** a current request returns 401 or 403
- **THEN** remote mutation and recovery-choice authority and old moderation acceptance are invalidated immediately
- **AND** only valid current staff authorization plus a new successful detail observation can restore remote availability
- **AND** actual account/role revocation hides private local state through the existing auth lifecycle

#### Scenario: Observation has no usable token or identifies another target
- **WHEN** a detail response lacks an exact field token, identifies another remote target or has unsupported context
- **THEN** it authorizes no field choice or Save, retains local work and settles unavailable with explicit reload/return

#### Scenario: Local initialization or remote decoding is incompatible
- **WHEN** local restoration/reconciliation fails or detail cannot be decoded into a usable observation
- **THEN** the attempt settles unavailable with explicit retry and return, creates no substitute owner and preserves rows/files
- **AND** recovery choices remain disabled until complete local initialization and a usable remote observation exist

### Requirement: Field recovery cannot revive moderation evidence
Existing source and preview guards SHALL also apply across field recovery. Accepting remote fields or preserving local fields against a new baseline SHALL invalidate prior acknowledgement, preview, apply-group and confirmation authority. SOURCE_CHANGED SHALL require current source observation; EVENT_CHANGED and Apply SUBMISSION_CHANGED SHALL require fresh preview. No recovery action SHALL replay moderation.

#### Scenario: Source refresh fails
- **WHEN** SOURCE_CHANGED invalidates acknowledgement and its original-detail refresh fails
- **THEN** explicit read retry is available without reviving old source acceptance or issuing another resolution

#### Scenario: Field reconciliation follows token conflict
- **WHEN** the user resolves fields after SUBMISSION_CHANGED or EVENT_CHANGED
- **THEN** old preview/groups/confirmation cannot apply, and current target/source evidence requires a separately requested preview and any required acknowledgement

#### Scenario: Recovery with an open confirmation
- **WHEN** recovery changes the accepted field baseline while an older moderation confirmation remains open
- **THEN** its captured callback cannot execute moderation or close the editor as a successful old operation

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
