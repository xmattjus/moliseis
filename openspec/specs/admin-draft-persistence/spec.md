# admin-draft-persistence Specification

## Purpose

Provide account-isolated Admin draft persistence and local session semantics for the application-owned editor, including lossless checkpoints, confirmed identity adoption and durable unresolved Save intent.

## Delivery Boundary

The local persistence boundary supports the active Admin editor and SHALL remain free of authentication subscriptions, HTTP, platform picker, route and widget orchestration. The application layer owns those integrations and remote Save; local arbitration orders checkpoints, hydration publication, identity adoption and staged commits without holding remote or picker interactions. Local identifiers alone do not establish backend idempotency; server replay and conditional Update are defined in `admin-submission-save-idempotency`.

Durable owners remain retained after Save and asset cleanup; owner retirement/finalization is not implemented. Admin restores its exact-account editor independently of interrupted media and does not consume native lost data. The accepted Android shared-cache attribution limitation remains unresolved; Public recovery is unchanged. Rich conflict-resolution UX (Plan 3) and Dirty Exit UX (Plan 4) remain future work.

## Requirements

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

### Requirement: Confirmed identity adoption is atomic locally
A confirmed new-to-persisted identity transition SHALL retain account/local UUID, draft technical identity, latest checkpoint fields, staged order and private files. Lookup and every same-session descriptor target SHALL change atomically. Destination conflicts SHALL preserve both owners without merge or overwrite.

#### Scenario: Create succeeds but adoption is interrupted
- **GIVEN** the original account/new owner has a durable pending Create intent
- **WHEN** remote Create commits and the process dies before adoption commits
- **THEN** reopening retains the original UUID and files, and explicit same-key replay recovers the remote ID

#### Scenario: Death during adoption transaction
- **WHEN** the process interrupts lookup and descriptor rebinding
- **THEN** reopen sees either the complete old identity or complete adopted identity, never mixed ownership or duplicate owner records

#### Scenario: Destination already belongs to another local session
- **WHEN** adoption encounters a different account/remote-target owner
- **THEN** no row or file is deleted/reassigned and local adoption returns a settled unavailable conflict

#### Scenario: Adopted session is reopened through an old new-editor intent
- **WHEN** navigation resumes the exact original account/session UUID
- **THEN** lookup resolves its adopted remote target without allocating a new owner

### Requirement: Unresolved field-write intent survives later local checkpoints
Each Create or Update SHALL durably retain its captured valid input, kind, target, expected field-version token for Update and stable session identity before HTTP. Later checkpoints SHALL preserve the unresolved intent. Confirmed adoption or durable Update baseline settlement SHALL clear only the matching intent. Restored Update intent SHALL require read-back before any explicit original A/V continuation, without ordinary resend; initialization SHALL not replay remotely.

#### Scenario: Local B is incomplete after ambiguous Create A
- **WHEN** checkpoint B replaces editable fields after Create A lost its response
- **THEN** explicit retry can replay original valid A under the same UUID while preserving B as current/local work

#### Scenario: Process dies with server Update still pending
- **GIVEN** unresolved Update A is durable and a later checkpoint contains B
- **WHEN** the process restarts before the server operation settles
- **THEN** read-back compares captured A and normal Save cannot resend A or B while outcome remains unknown
- **AND** old baseline equality, restart or elapsed time cannot prove cancellation

### Requirement: Remote confirmation preserves newer local work
Confirmation SHALL record only the captured remote projection and SHALL not overwrite newer current fields, effective baseline or physical checkpoint fields. Required local metadata failure SHALL preserve disk truth and return partial/local repair rather than claim physical success.

#### Scenario: Update A versus checkpoint B
- **WHEN** B checkpoints before remote confirmation of A
- **THEN** B remains the physical field snapshot and is not declared remotely saved

### Requirement: Save and staging retain owners
Successful remote Save, baseline replacement, association cleanup and last-asset removal SHALL retain the exact durable owner. Already-admitted local commits SHALL remain bound to their captured owner and serialize with adoption and checkpointing. No owner-retirement obligation registry SHALL be introduced.

#### Scenario: Staged commit overlaps Update completion
- **WHEN** a local acquisition commits before or after remote Update confirmation
- **THEN** its parent remains durable and valid staged bytes restore on reopen

#### Scenario: Revocation or failed cleanup
- **WHEN** authorization changes during a local commit or file cleanup fails after descriptor deletion
- **THEN** committed work stays private to its original owner and failed cleanup cannot authorize owner deletion or media resurrection

### Requirement: Exact field-intent settlement preserves local work
A proven first-dispatch rejection or an observed field-version fence SHALL retire only the matching intent under exact account/session/activation, attempt and kind. Settlement SHALL preserve newest C/E/P, historical remote evidence, staging receipts/files and navigation, and SHALL NOT confirm remote success or grant fresh mutation authority. Empty intent SHALL be an idempotent local no-op; another intent or obsolete activation SHALL fail closed.

#### Scenario: Rejected A with newer checkpoint B
- **GIVEN** the current live Save first captured A and a typed response proves its only dispatch did not write
- **WHEN** A is durably settled after B checkpoints
- **THEN** B and all retained local assets remain unchanged, and reopen does not restore A’s intent
- **AND** an Update requires compatible fresh remote authority before another field mutation

#### Scenario: Settlement persistence fails
- **WHEN** removing the matching rejected intent fails locally
- **THEN** the durable intent remains and normal remote Save is not admitted
- **AND** an explicit request-bound local-only settlement retry is available while its proof survives

#### Scenario: A later rejection does not settle an earlier ambiguous request
- **GIVEN** an intent was restored or retried and an earlier request might still have committed
- **WHEN** the current HTTP request is rejected before dispatch or by its conditional predicate
- **THEN** that response alone SHALL NOT declare the entire intent unapplied
- **AND** Update uses observed projection/version recovery; Create retains the original server UUID

### Requirement: Explicit corrected Create retains uncertain server identity
After a verified pre-dispatch rejection of a restored/ambiguous Create, an authorized, explicitly admitted Save of corrected valid fields SHALL replace the captured Create request with a new local attempt identity under the original session UUID. It SHALL preserve newer C/P, staged work and prior-outcome uncertainty. Replay SHALL adopt the authoritative existing/created record and stop on differing or moderated fields without overwriting it.

#### Scenario: Earlier Create A may have committed while corrected B is submitted
- **WHEN** the user explicitly saves valid B after the current request for A was rejected before dispatch
- **THEN** the request still uses A’s original client submission UUID
- **AND** an earlier committed A is discovered rather than duplicated, while B remains local and later phases stop on conflict
- **AND** replacement requires exact account/session/activation authority and successful local persistence; failure SHALL NOT claim success or authorize an unsafe remote request

### Requirement: Explicit remote routes and resume identities agree
A session hint on an explicit remote-ID editor route SHALL resolve under the current account and match that ID before any activation. Rejection SHALL preserve previously active work. New-editor and Progress bindings without an explicit remote target SHALL retain adopted-session restoration.

#### Scenario: Route 123 carries session 456
- **WHEN** `/admin/submissions/123` supplies a same-account session belonging to remote submission 456
- **THEN** the route is settled unavailable and submission 456 is not activated or published through route 123
- **AND** neither existing draft is overwritten or discarded
