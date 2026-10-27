## Purpose

Provide reusable, account-isolated Admin draft persistence and local session semantics without activating a replacement editor or transitional remote Save workflow.

## ADDED Requirements

### Requirement: Draft foundations remain outside active editor workflows
The local draft foundation SHALL perform no remote Save, auth subscription, route binding or platform picker work. Its availability SHALL NOT activate durable editing in the existing production editor. Application-owned editor integration SHALL remain outside this capability's first delivery.

#### Scenario: Foundation is available alongside existing editor
- **WHEN** the application contains the local foundation and an administrator uses the existing editor
- **THEN** its existing Create/Update, moderation, validation, picker and navigation behavior remains unchanged
- **AND** no new checkpoint, uncertain-Create or session-switch UI appears

### Requirement: Local identity binds exact account session and target
A local draft SHALL have a stable secure local session identity and editing-account identity distinct from its technical storage key and optional remote submission ID. Durable lookup SHALL distinguish a new target from each existing remote target. Account/target changes SHALL NOT reassign an existing session's fields or assets.

#### Scenario: Untouched local context
- **WHEN** a caller prepares a fresh local context without requesting persistence
- **THEN** it receives a stable local identity without any disk write or remote ID

#### Scenario: Admin edits another contributor's submission
- **WHEN** account A prepares local work for a remote submission created by B
- **THEN** A owns the local session independently of the contributor
- **AND** mutable display name/email changes do not rotate ownership

#### Scenario: Inactive session is retained
- **WHEN** a caller activates another account or target
- **THEN** prior durable sessions and their files remain isolated and recoverable

### Requirement: Incomplete fields are immutable and losslessly checkpointed
A draft snapshot SHALL preserve nullable category, city, name, description, deeply immutable rich-text operations, complete event temporal state and exact coordinate text. Persistence SHALL not require valid remote input or include transient presentation, search, preview, acknowledgement or command state. Structural equality SHALL include every editable value and owner identity.

#### Scenario: Incomplete temporal and coordinate values round-trip
- **WHEN** an enabled event has an unresolved start, retained final civil day, all-day mode or invalid raw coordinate half-pair
- **THEN** checkpoint restoration retains those exact values without inventing a time or numeric pair

#### Scenario: Original description is mutated
- **WHEN** nested caller-owned rich-text data changes after snapshot capture
- **THEN** the snapshot, equality and hash remain unchanged

#### Scenario: Local text remains exact
- **WHEN** whitespace or decimal-comma coordinate text changes
- **THEN** structural local equality reflects the exact text change
- **AND** persistence does not coerce it through remote validation

### Requirement: Effective local baseline is separate from physical durability
Local user dirtiness SHALL compare current fields with their effective comparison baseline, separately from the last physically persisted checkpoint and confirmed remote baseline. Authoritative hydration SHALL NOT claim a local write or mark an unmodified editor locally dirty. Known owner existence SHALL NOT imply that current fields match disk.

#### Scenario: Clean A is authoritatively hydrated to B
- **WHEN** checkpoint A has no unconfirmed remote edits and verified remote B is accepted without user mutation
- **THEN** current/effective state becomes B and local dirtiness remains false
- **AND** physical checkpoint remains A without a write

#### Scenario: Switch immediately after hydration
- **WHEN** B was authoritatively hydrated over clean A and another target is requested without user edits
- **THEN** the local component permits switching without forcing a checkpoint of B

#### Scenario: User changes hydrated B to C
- **WHEN** the user changes accepted B into C
- **THEN** C differs from effective baseline B and is locally dirty
- **AND** the existing physical checkpoint A remains separately identifiable

#### Scenario: Restart before B is checkpointed
- **WHEN** the component restarts after hydration B with no later checkpoint
- **THEN** it restores physical A and its recorded remote baseline
- **AND** it does not report B as persisted or the saved remote context as freshly verified

### Requirement: Checkpoint completion confirms only its captured snapshot
Field mutations SHALL NOT autosave. Explicit checkpoint success SHALL advance the physical checkpoint and effective baseline only to the captured immutable snapshot; failure SHALL preserve both. An equal known physical checkpoint, including its recorded remote baseline, SHALL skip rewriting and establish its fields as the effective baseline. An untouched absent ordinary checkpoint SHALL be a no-op, while required durable ownership SHALL force its first write.

#### Scenario: Checkpoint A finishes while current fields are B
- **WHEN** A is being persisted, fields change to B, and A succeeds
- **THEN** physical/effective checkpoint becomes A while current B remains locally dirty

#### Scenario: Failed checkpoint preserves all baselines
- **WHEN** captured C fails to persist
- **THEN** current C remains available and neither effective nor physical checkpoint advances

#### Scenario: Checkpoint after hydration
- **WHEN** B is effective/current, physical checkpoint is A, and an explicit checkpoint is requested
- **THEN** B is physically written despite local dirtiness being false
- **AND** success makes B the physical/effective checkpoint without confirming a remote Save

#### Scenario: Checkpoint edited C
- **WHEN** B was hydrated, user edits C, and C checkpoints successfully
- **THEN** physical/effective checkpoint becomes C and confirmed remote baseline remains B

#### Scenario: Known equal physical checkpoint
- **WHEN** current fields and recorded remote baseline equal the known physical checkpoint
- **THEN** another explicit checkpoint succeeds without a redundant write

#### Scenario: Returning to physical fields after hydration
- **WHEN** physical A records remote A, hydration accepts B, and the user returns the fields to A and checkpoints
- **THEN** the checkpoint persists A with remote baseline B and establishes effective A
- **AND** restart retains the unconfirmed revert instead of treating A as remotely confirmed

#### Scenario: Fresh ordinary versus required checkpoint
- **WHEN** a fresh untouched absent context requests an ordinary checkpoint and later requires a durable owner
- **THEN** the ordinary request makes no write and the ownership request performs the first real checkpoint before file acquisition

### Requirement: Hydration preserves unconfirmed local intent
Remote hydration supplied by a caller SHALL be accepted only when it cannot overwrite uncheckpointed edits or a checkpoint containing incompatible unconfirmed remote edits. Rejected hydration SHALL preserve local content and durability. Local checkpoint success SHALL never imply remote Save success, fresh authorization or moderation readiness.

#### Scenario: Checkpointed dirty remote intent is protected
- **WHEN** a restored checkpoint equals its effective baseline but contains edits relative to its recorded remote baseline and new remote detail conflicts
- **THEN** hydration returns a preserved/blocked outcome without replacing its fields/checkpoint

#### Scenario: Uncheckpointed typing is protected
- **WHEN** current fields differ from effective baseline as a remote candidate arrives
- **THEN** that candidate cannot replace current fields by convenience

#### Scenario: Local checkpoint cannot confirm remote fields
- **WHEN** a remotely unconfirmed local snapshot checkpoints successfully
- **THEN** only local durability changes and its remote confirmation remains outstanding

### Requirement: Hydration publication follows latest request admission
Within an activation, each hydration request SHALL receive an increasing admission revision. Only the latest admitted token with matching owner/target/activation SHALL publish success or failure after rechecking inside local arbitration. Stale results SHALL change none of C/E/P/R, readiness or accepted context metadata and SHALL NOT checkpoint. Newer failure SHALL NOT revive older authority. The local component SHALL not fetch remote data.

#### Scenario: HYDRATION-01 Older request completes last
- **WHEN** B1 is admitted, B2 supersedes it, B2 is accepted and B1 completes afterward
- **THEN** B1 changes no state or readiness and cannot replace accepted B2

#### Scenario: HYDRATION-02 Older request completes first
- **WHEN** B1 is admitted, B2 supersedes it and B1 completes before B2
- **THEN** B1 is already stale and cannot publish
- **AND** only B2 may publish if its token remains authoritative and local-intent checks permit it

#### Scenario: HYDRATION-03 Newer request fails
- **WHEN** B2 supersedes B1, B2 fails and B1 later completes
- **THEN** B1 remains stale and cannot replace B2's failure/readiness outcome or change any baseline
- **AND** another attempt requires a new admission token, without a local checkpoint caused by stale rejection

#### Scenario: HYDRATION-04 Checkpoint overlaps hydration
- **WHEN** checkpoint A starts and a newer hydration is admitted while results become available in either order
- **THEN** the actual checkpoint write and baseline settlement finish inside local arbitration before a waiting hydration can publish
- **AND** physical P reports only successful writes, while hydration rechecks latest-request authority after waiting
- **AND** a checkpoint entering after accepted hydration captures current state rather than replaying an older snapshot

#### Scenario: HYDRATION-05 Activation replacement
- **WHEN** an A1 hydration completes after B then A2 has started, even with an equal request revision
- **THEN** its old activation token prevents all publication independently of same-activation ordering

### Requirement: Initialization preserves absent valid and unknown ownership
Concurrent local initialization callers for one activation SHALL share completion. Valid restoration SHALL expose the exact checkpoint and fully reconciled assets. Authoritative absence SHALL be scoped to its account/target. Loading or decoding failure SHALL preserve unknown ownership and block identity-dependent writes/cleanup instead of overwriting it with a fresh session.

#### Scenario: Concurrent callers wait for one complete restoration
- **WHEN** activation and checkpoint requests await initialization
- **THEN** the draft loads once and readiness waits for reconciliation
- **AND** provisional constructor identity does not overwrite restored identity

#### Scenario: Store or decoding failure
- **WHEN** draft loading fails or an unsupported/conflicting row is encountered
- **THEN** no fresh checkpoint or destructive absence cleanup is authorized
- **AND** durable rows/files remain preserved for explicit retry

#### Scenario: Restored and fresh baselines are distinct
- **WHEN** lookup returns a valid checkpoint, authoritative absence or a read failure
- **THEN** a valid restoration sets C = E = P = restoredSnapshot with historical R
- **AND** absence sets C = E = freshSnapshot and P = null, with a stable unpersisted identity and clean local state
- **AND** read failure instead leaves P/ownership unknown and owner-dependent writes/acquisition unavailable

#### Scenario: One target is absent
- **WHEN** target X is authoritatively absent and Y remains stored
- **THEN** X does not adopt Y's assets and Y is not orphaned

#### Scenario: Reconciliation fails before readiness
- **WHEN** full asset restoration fails
- **THEN** initialization settles as unavailable without partial publication or indefinite loading
- **AND** an explicit retry shares a new attempt

### Requirement: Local actions retain activation authority
Local initialization, synchronous field mutation, checkpoint, acquisition, removal and hydration SHALL bind account, session, target and activation generation. Replacement or explicit revocation SHALL suppress late runtime publication into a new context. Already-started durable work SHALL remain with its captured owner. Normal switches SHALL refuse uncheckpointed work or unsettled local mutation without autosaving it.

#### Scenario: Delayed setter retains its original editing context
- **WHEN** a setter callback captures authority when its editing context is established and runs after target/account replacement or revocation, including A1 to B to A2
- **THEN** the setter requires that captured authority and rejects it as stale without looking up replacement authority
- **AND** rejection preserves current/effective/physical/remote state, dirty state and assets without writing a checkpoint

#### Scenario: A to B to A rejects old completion
- **WHEN** activation A1 work settles after B then A2 becomes current
- **THEN** the old completion cannot publish into A2 solely because the target matches

#### Scenario: Account revocation
- **WHEN** a caller revokes A and activates B while local work is pending
- **THEN** A's private runtime state is not exposed to B
- **AND** already-started commits remain recoverable only under A's owner

#### Scenario: Dirty switch is refused
- **WHEN** a normal target switch would abandon current uncheckpointed fields
- **THEN** the local component refuses it without saving or deleting those fields

#### Scenario: Hydration and checkpoint are ordered
- **WHEN** checkpoint completion and authoritative hydration both request the local boundary
- **THEN** their baseline effects have a deterministic order and an earlier checkpoint cannot reset a later accepted hydration

### Requirement: Field persistence never retires recoverable ownership
Replacing a checkpoint or accepting remote baseline data SHALL preserve the durable session owner and every valid asset belonging to it. This delivery SHALL expose no owner-retirement or remote-success-finalization path. Removing the last staged item SHALL retain its owner. Future retirement SHALL require absence of all staged, inbox and in-flight recovery obligations, not merely a superseded field checkpoint.

#### Scenario: Snapshot changes while files remain
- **WHEN** a session with valid staged bytes checkpoints new fields or accepts authoritative baseline data
- **THEN** the same durable owner remains and restart can still restore those bytes

#### Scenario: Last staged asset is removed
- **WHEN** exact-owner local removal deletes the final staged item
- **THEN** the durable draft owner is not implicitly retired

#### Scenario: No remote-success deletion path
- **WHEN** callers use the local foundation API
- **THEN** no field-only success or remote confirmation can invoke owner deletion or a temporary Create/Update finalization workflow
