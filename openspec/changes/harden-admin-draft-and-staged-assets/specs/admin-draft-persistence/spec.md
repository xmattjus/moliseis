## Purpose

Provide account-isolated, recoverable Admin editor checkpoints while preserving the distinction between incomplete local work and confirmed remote submission state.

## ADDED Requirements

### Requirement: Admin draft identity is distinct from remote and storage identity
The system SHALL give each logical Admin draft a stable local session identity owned by an authenticated Admin account, separately from its technical storage key and optional existing remote submission ID. Opening an untouched new editor SHALL NOT write storage. Ownership SHALL use account identity rather than mutable email or display name.

#### Scenario: New draft has no remote identity
- **WHEN** an authorized administrator opens an untouched new editor
- **THEN** a fresh stable local identity exists without a remote ID or local write
- **AND** repeated edits and checkpoint failures retain that identity

#### Scenario: Existing submission has a separate local owner
- **WHEN** account A edits an existing submission created by contributor B
- **THEN** the local draft belongs to A and references the remote submission separately
- **AND** changing A's display name or email does not rotate local ownership

#### Scenario: Restoration retains exact identity
- **WHEN** a valid checkpoint is restored after process recreation
- **THEN** its local identity, account and remote target are restored together
- **AND** no constructor-generated identity replaces them

### Requirement: Checkpoints faithfully represent incomplete immutable fields
The system SHALL checkpoint structurally immutable category, city, name, description, rich-text operations, full event temporal draft and exact coordinate text. Checkpoints SHALL preserve incomplete or invalid editable state without validating it as remote input. Transient presentation, search, preview, acknowledgement and command state SHALL NOT be persisted as editable content.

#### Scenario: Incomplete event and coordinate text round-trip
- **WHEN** a checkpoint contains an enabled event with unresolved start, retained end civil day, temporal mode and invalid half-pair coordinate text
- **THEN** restoration retains those exact editable values without inventing times or numeric coordinates
- **AND** remote Save validation still rejects invalid remote input

#### Scenario: Caller mutates original Delta
- **WHEN** caller-owned nested description operations are mutated after a snapshot is captured
- **THEN** the captured checkpoint and equality outcome remain unchanged

#### Scenario: Snapshot equality is deterministic
- **WHEN** equivalent snapshots are independently constructed or one raw coordinate string changes
- **THEN** equality respectively remains true or becomes false
- **AND** transient loading/dialog state has no effect on equality

### Requirement: Local persistence requires explicit captured checkpoints
An effective field mutation SHALL NOT autosave. An explicit checkpoint SHALL persist its captured immutable snapshot and advance only the successful local baseline. Equal known-durable checkpoints and untouched ordinary checkpoints SHALL be no-ops. A caller requiring durable ownership SHALL force the initial write. Local checkpoint success SHALL NOT confirm remote changes.

#### Scenario: Mutation has no delayed autosave
- **WHEN** fields change and time advances without an explicit persistence action
- **THEN** the current draft changes and no checkpoint write occurs

#### Scenario: A finishes after current state becomes B
- **WHEN** checkpoint A is pending, current draft changes to B, and A succeeds
- **THEN** A becomes the local baseline and B remains current and locally dirty

#### Scenario: Checkpoint failure preserves baseline
- **WHEN** a dirty checkpoint fails
- **THEN** the prior checkpoint, identity and current fields remain unchanged
- **AND** the persistence error is returned

#### Scenario: Equal snapshots with different durability
- **WHEN** an ordinary checkpoint is requested for an untouched editor or equal known-durable snapshot
- **THEN** no redundant storage write occurs
- **AND** a later picker preparation for an absent durable owner performs the required initial write

#### Scenario: Local success does not authorize moderation
- **WHEN** remotely dirty fields are successfully checkpointed locally
- **THEN** local dirtiness clears only for that snapshot
- **AND** remote dirtiness and moderation eligibility remain governed by remote confirmation

### Requirement: One active editor preserves other recoverable targets
The system SHALL keep one active Admin editor in memory and recoverable checkpoints by account and new-or-existing target. Reopening the active target SHALL preserve uncheckpointed memory. A different-target activation SHALL refuse to abandon uncheckpointed fields or unsettled mutations; it SHALL NOT autosave or delete inactive recoverable sessions.

#### Scenario: Checkpointed A to B to A
- **WHEN** account A checkpoints target X, opens target Y, then reopens X
- **THEN** X restores its exact checkpoint/assets with a new activation generation
- **AND** Y and all other valid account-owned checkpoints remain recoverable

#### Scenario: Switch would abandon uncheckpointed work
- **WHEN** target X has uncheckpointed edits and target Y is requested
- **THEN** X remains active and the switch reports why it was refused
- **AND** the current editor offers explicit local checkpoint and return navigation without an exit dialog

#### Scenario: Untouched session switches without a write
- **WHEN** a fresh unmodified session switches to another target with no work in flight
- **THEN** the switch does not create a checkpoint for the untouched session

#### Scenario: Route detaches and returns
- **WHEN** the editor route detaches and the same account/target returns in the same process
- **THEN** current uncheckpointed memory remains available
- **AND** old route terminals are not replayed as new navigation effects

### Requirement: Initialization distinguishes absent restored and unknown ownership
Concurrent initialization for one activation SHALL share one completion. Valid restoration SHALL publish fields and reconciled assets coherently. Authoritative absence SHALL be scoped to the exact target. Read or decoding failure SHALL preserve unknown storage, block identity-dependent mutations and prohibit destructive reconciliation as absence.

#### Scenario: Concurrent initialization waits for assets
- **WHEN** activation and checkpoint callers await the same pending initialization
- **THEN** the draft loads once and readiness waits for staged reconciliation
- **AND** no provisional constructor identity is checkpointed over the restored identity

#### Scenario: Hard read failure
- **WHEN** draft lookup fails or returns an unsupported/corrupt payload
- **THEN** identity-dependent writes and picking are unavailable
- **AND** existing descriptors, rows and files remain preserved for retry

#### Scenario: Target absent while other targets exist
- **WHEN** target X is authoritatively absent but target Y has a checkpoint
- **THEN** X starts without adopting old assets
- **AND** Y is not eligible for deletion merely because X is active

#### Scenario: Reconciliation fails
- **WHEN** an infrastructure failure prevents complete asset reconciliation
- **THEN** initialization completes as unavailable without partial runtime publication
- **AND** explicit retry shares a new attempt without opening a picker prematurely

### Requirement: Restored edits retain a separate authoritative remote baseline
Existing-target checkpoints SHALL retain the last confirmed remote editable baseline separately from local fields. Restoration SHALL fetch current remote context before allowing remote actions. Matching pending context SHALL preserve local edits; changed, missing, final or unavailable context SHALL preserve the checkpoint and block unsafe remote actions without automatic rebase or discard.

#### Scenario: Local checkpoint differs from unchanged remote baseline
- **WHEN** incomplete local edits restore and fetched pending remote context matches their saved baseline
- **THEN** local edits remain current and remotely dirty while status/assets come from current remote context

#### Scenario: Dirty checkpoint encounters changed remote context
- **WHEN** fresh detail differs from a remotely dirty checkpoint's saved baseline or is missing/final/unavailable
- **THEN** local fields remain recoverable in a blocked read-only state
- **AND** Save, moderation and remote asset mutation cannot overwrite that context

#### Scenario: Remotely clean checkpoint can use fresh detail
- **WHEN** a restored checkpoint has no remote field changes and fresh detail loads
- **THEN** fresh detail may hydrate the editor without an implicit local checkpoint

#### Scenario: Detail finishes after local changes
- **WHEN** a captured detail request settles after the editor has acquired later field/session revisions
- **THEN** it does not overwrite those fields or publish into another activation

### Requirement: Authentication and activation revoke stale authority
Every async editor action SHALL bind account, session, activation and target before deferred work. Logout, privilege loss, account change, session retirement and application disposal SHALL revoke publication and unstarted phases. Old operations SHALL NOT regain authority when the same target is later reopened. Durable work SHALL remain isolated to its original owner.

#### Scenario: Account changes during an operation
- **WHEN** account A loses privilege or account B becomes active while A's work is pending
- **THEN** A's private UI state is removed and no late result publishes or starts a later remote phase
- **AND** A's already-durable checkpoints remain inaccessible to B

#### Scenario: Original account returns
- **WHEN** A later reauthenticates and explicitly activates the matching target
- **THEN** only A's valid checkpoints may restore under a new activation
- **AND** a completion captured before revocation has no publication authority

#### Scenario: A to B to A rejects original A completion
- **WHEN** a read for activation A1 completes after activation B then A2
- **THEN** identity equality alone cannot authorize that result and A2 remains unchanged

#### Scenario: Disposal waits for physical settlement
- **WHEN** application ownership is disposed with a command in flight
- **THEN** no runtime publication or new phase occurs after revocation
- **AND** command release waits for physical settlement without disposed-notifier access

### Requirement: Legacy remote Save cannot resurrect completed local drafts
Legacy Create and Update SHALL retain their remote APIs and navigation semantics. Create SHALL lock editable fields through settlement and prevent repeated creation after confirmed success. Already-durable new drafts SHALL record an attempt fence before Create; a surviving fence SHALL block replay until outcome verification. Local repair after remote success SHALL NOT repeat a remote write or adopt a remote ID in place.

#### Scenario: Failure fencing prevents Create
- **WHEN** a durable new draft cannot record its Create attempt fence
- **THEN** no remote Create starts and the original local checkpoint remains recoverable

#### Scenario: Crash around fenced Create
- **WHEN** the process stops after recording the fence, before or after sending Create
- **THEN** restart retains the draft as requiring remote outcome verification
- **AND** no automatic or ordinary retry Create is permitted for that fenced session

#### Scenario: Checkpoint cannot make an in-flight non-durable Create recoverable
- **WHEN** a non-durable new session has reserved Create and an explicit checkpoint is requested before settlement
- **THEN** that checkpoint is refused without persisting an unfenced new row
- **AND** an earlier pending checkpoint settles before deciding whether Create needs a fence

#### Scenario: A separate new draft preserves uncertain history
- **WHEN** an administrator explicitly chooses a separate new draft from the fenced-outcome message
- **THEN** the uncertain session is retained under its own historical key before releasing the new-draft slot
- **AND** a fresh identity starts without adopting the old fields/assets or retrying its remote operation
- **AND** failure retaining that history preserves the original session instead of switching

#### Scenario: Create confirmed but local retirement fails
- **WHEN** Create succeeds and retiring its local checkpoint fails
- **THEN** the session cannot Create again and reports local finalization failure
- **AND** retry repairs only local retirement without invoking Create

#### Scenario: Create locks fields and covered success stays complete
- **WHEN** fields are changed during initial Create or its successful route is covered
- **THEN** in-flight field changes are refused and a confirmed completed session cannot Create again on return
- **AND** a current authorized route retains its existing successful close behavior after local retirement

#### Scenario: Update A succeeds after B is typed
- **WHEN** Update A succeeds while current fields contain B
- **THEN** only A becomes the confirmed remote baseline and B remains remotely dirty
- **AND** the old success cannot close the editor or clear confirmed associated assets

#### Scenario: New checkpoint arrives during Update
- **WHEN** a newer explicit checkpoint B commits after Update A was admitted and A later succeeds
- **THEN** B remains durable with A as its confirmed remote baseline
- **AND** B is not declared remotely saved or replaced by current uncheckpointed fields

#### Scenario: Earlier checkpoint is superseded by confirmed Update
- **WHEN** Update succeeds and no newer explicit checkpoint has committed since its admission
- **THEN** the superseded checkpoint may retire only through its exact local owner
- **AND** local cleanup failure is repaired locally without replaying Update

#### Scenario: No backend exactly-once claim
- **WHEN** a non-durable live Create fails with an ambiguous response
- **THEN** existing error/retry behavior does not imply backend deduplication
- **AND** local session identity is not sent as an invented Admin idempotency contract

### Requirement: Existing editor behavior remains compatible with the foundation
Pending/final guards, validation, moderation, event resolution, previews, command exclusion and route effects SHALL remain in force. New-mode asset selection and staged remote Save SHALL remain unavailable. Local recovered assets SHALL block legacy Save that cannot persist them. Local checkpoint controls SHALL be clearly distinguished from remote Save.

#### Scenario: Ordinary persisted workflow remains functional
- **WHEN** a valid pending editor uses Update, Reject, Promote, Link, Apply or preview
- **THEN** existing validation, readiness, source tokens, execution exclusion and authorized effects remain effective

#### Scenario: Foundation cannot expose incomplete Save
- **WHEN** new-mode UI is shown or recovered staged assets exist
- **THEN** new-mode photo selection remains disabled
- **AND** legacy Save with staged assets returns an actionable unavailable explanation before any remote call

#### Scenario: Final status remains read-only
- **WHEN** an accepted or rejected submission opens
- **THEN** field and asset mutation remain unavailable regardless of local durability
