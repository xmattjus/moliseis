# Admin submission editor delta

## ADDED Requirements

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
