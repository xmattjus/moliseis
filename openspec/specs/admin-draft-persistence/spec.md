# admin-draft-persistence Specification

## Purpose

Provide account-isolated Admin draft persistence and local session semantics for the application-owned editor, including lossless checkpoints, confirmed identity adoption and durable unresolved Save intent.

## Delivery Boundary

The local persistence boundary supports the active Admin editor and SHALL remain free of authentication subscriptions, HTTP, platform picker, route and widget orchestration. The application layer owns those integrations and remote Save; local arbitration orders checkpoints, hydration publication, identity adoption and staged commits without holding remote or picker interactions. Local identifiers alone do not establish backend idempotency; server replay and conditional Update are defined in `admin-submission-save-idempotency`.

Durable owners remain retained after Save and asset cleanup; owner retirement/finalization is not implemented. Admin restores its exact-account editor independently of interrupted media and does not consume native lost data. The accepted Android shared-cache attribution limitation remains unresolved; Public recovery is unchanged. Explicit stale field recovery is defined below. Admin field-exit decisions are defined in `admin-submission-editor`; the local boundary provides reviewed checkpoint and effective-field discard authority without owning presentation or navigation.

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

### Requirement: Explicit reconciliation preserves baseline distinctions
Existing protected hydration SHALL be extended with explicit current-observation reconciliation. Accepting remote SHALL set current/effective/remote to observed fields while leaving physical checkpoint unchanged. Preserving local SHALL leave current/effective/physical unchanged and set remote baseline to the observation. Neither transition SHALL persist, retire an owner or confirm a remote Save.

#### Scenario: Accept remote while a different local checkpoint exists
- **GIVEN** current C, effective E and physical checkpoint P preserve local work
- **WHEN** an authorized explicit choice accepts remote B
- **THEN** current and effective become B, remote baseline becomes B, physical P and its recorded metadata remain unchanged, and local field dirtiness is false
- **AND** staged identities, receipts, bytes, navigation metadata and owner remain unchanged

#### Scenario: Keep checkpoint-clean but remotely unconfirmed local fields
- **GIVEN** C equals E and physical local L but differs from observed pending remote B
- **WHEN** an authorized explicit choice preserves local fields
- **THEN** C, E and P remain L while remote baseline becomes B
- **AND** local field dirtiness remains false but remote field confirmation remains outstanding

#### Scenario: Keep uncheckpointed incomplete local fields
- **GIVEN** C contains invalid raw coordinate text, unresolved event dates or incomplete fields and C differs from E
- **WHEN** the user explicitly preserves C against compatible pending observation B
- **THEN** C and its dirtiness remain exact and the later Save still requires ordinary validation
- **AND** no normalization, implicit checkpoint or synthetic remote field confirmation occurs

### Requirement: Reconciliation requires exact serialized local authority
The local reconciliation boundary SHALL validate captured account/session/target/activation, latest observation and local field revision within existing local ordering. Pending field intent or settlement and conflicting work SHALL block reconciliation. Failed or obsolete choices SHALL change none of current/effective/physical/remote baselines, readiness, capacity, assets or persistence.

#### Scenario: An unresolved field intent exists
- **WHEN** a field choice attempts to use another token while an original intent remains durable
- **THEN** it is refused and the original intent plus all local snapshots and receipts remain unchanged

#### Scenario: Local edit arrives before queued choice publication
- **WHEN** a captured choice waits behind checkpoint work and C changes before that choice reaches its local publication boundary
- **THEN** the choice is obsolete and cannot replace the newer fields or reset the successful physical checkpoint

#### Scenario: Revocation during an already-started durable write
- **WHEN** a checkpoint starts for A and authorization changes before it completes
- **THEN** it can commit only to A's captured owner and cannot authorize or publish a recovery choice into B or A2
- **AND** its physical settlement does not release another operation's reservation

### Requirement: Reconciliation durability follows ordinary checkpoint semantics
Runtime reconciliation SHALL not rewrite P. Explicit Accept whose chosen fields/R are not physically represented SHALL establish an activation-owned checkpoint obligation that refuses ordinary target replacement. Only matching successful checkpoint proof SHALL release it. Ordinary hydration SHALL establish no obligation. Explicit checkpoints SHALL retain existing capture/ownership guarantees; restart SHALL restore P and require fresh authority.

#### Scenario: Restart before persisting accepted remote fields
- **GIVEN** P stores local A with its original remote baseline and the user accepts remote B without checkpointing
- **WHEN** the real store reopens
- **THEN** A and its recorded baseline restore, not B, and no runtime acceptance or token authority is invented

#### Scenario: Explicit checkpoint after local preservation
- **GIVEN** current L is retained against observed remote B
- **WHEN** an explicit checkpoint succeeds and the real store reopens
- **THEN** exact L restores with recorded remote B and the same owner/receipts/files
- **AND** B remains historical evidence requiring a fresh read before remote authority

#### Scenario: Checkpoint fails after remote acceptance
- **WHEN** explicit persistence of accepted B fails
- **THEN** physical P and its metadata remain unchanged, B is not described as durable and explicit retry remains available
- **AND** checkpoint failure never triggers remote Save or cleanup

#### Scenario: Typing during explicit post-choice checkpoint
- **WHEN** chosen current A is checkpointed while typing creates B
- **THEN** successful physical/effective checkpoint is captured A with its captured remote baseline, current B remains uncheckpointed and no newer field intent or receipt is erased

#### Scenario: F1 Accepted remote state blocks ordinary target replacement
- **GIVEN** physical P=A and an authorized explicit Accept establishes C=E=B, R=B without persisting B
- **WHEN** another target or session activation is requested after other operations settle
- **THEN** replacement is refused and the exact active owner, C/E/P/R and acceptance obligation remain intact despite C=E
- **AND** same-session rebinding retains the obligation without a write or changed dirty-state definition

#### Scenario: F1 Successful explicit checkpoint makes accepted B resumable
- **GIVEN** an outstanding acceptance obligation for C=E=B, R=B over P=A
- **WHEN** an explicit checkpoint captures its revision and B/R, succeeds under the same activation, and no other admission barrier remains
- **THEN** P/E become captured B with recorded R=B and the matching obligation clears
- **AND** ordinary switch is permitted and real-store reopen restores B, not A
- **AND** the checkpoint phase of explicitly requested Save may satisfy the same proof without another write or unnecessary field Update

#### Scenario: F1 Failed checkpoint retains old durable data and refusal
- **GIVEN** accepted B has an outstanding checkpoint obligation over durable A
- **WHEN** its explicit checkpoint fails
- **THEN** P remains A with its recorded metadata, C=E=B and R=B remain available, and the obligation still refuses target replacement
- **AND** retry never reports B physically saved or starts automatic remote work

#### Scenario: F1 Ordinary clean hydration has no acceptance obligation
- **GIVEN** clean checkpoint A has no unconfirmed remote edits and no explicit-acceptance obligation
- **WHEN** ordinary authorized hydration establishes C=E=B and R=B while P=A
- **THEN** no new switch restriction exists solely because C differs from disk and ordinary replacement remains permitted after existing barriers settle

#### Scenario: F1 Later reconciliation protects its own obligation revision
- **GIVEN** a checkpoint captured acceptance revision one before a later authorized reconciliation
- **WHEN** another Accept establishes revision two or Keep changes R while retaining and advancing the outstanding obligation
- **THEN** completion or callback from revision one cannot clear revision two, even if field values happen to match
- **AND** stale or failed reconciliation changes no obligation; Keep with no prior obligation creates none
- **AND** a new current Accept already represented by actual P needs no obligation

#### Scenario: F1 Reads and typing cannot erase an outstanding acceptance
- **WHEN** hydration, a read error, typing or remote-intent metadata settlement occurs while explicit acceptance awaits checkpoint
- **THEN** none clears the obligation, and hydration cannot silently replace its accepted C/E/R
- **AND** a matching checkpoint that captures later current fields can satisfy its obligation, while typing after capture remains protected by existing C versus E dirtiness

#### Scenario: F1 Revocation remains stronger than transition refusal
- **GIVEN** A owns accepted but uncheckpointed B over physical A-data
- **WHEN** account authority is revoked or the application owner is disposed
- **THEN** runtime state, obligation and callbacks lose access immediately without delaying security redirects or checkpointing
- **AND** original durable data remains private to A; an already-started checkpoint may finish only for its captured owner without releasing a replacement activation's obligation
- **AND** process restart restores physical truth without reconstructing the runtime obligation or claiming B survived

### Requirement: Field discard restores only the effective baseline
Explicit local discard SHALL restore current editable fields C to the effective field baseline E under exact activation authority. It SHALL NOT load or overwrite physical checkpoint P, change accepted remote baseline R, delete an owner, or change staged descriptors, bytes, receipts, navigation metadata, unresolved write intent or recovery checkpoint obligations. It SHALL NOT perform persistence or remote work.

#### Scenario: Hydration makes effective fields newer than disk
- **GIVEN** physical P=A and accepted hydration establishes C=E=B without writing disk
- **WHEN** the user edits C and explicitly discards those uncheckpointed edits
- **THEN** current fields become B, E stays B, physical P stays A and R stays unchanged
- **AND** no disk write occurs and A is not incorrectly restored as the effective baseline

#### Scenario: Explicit acceptance obligation remains after discard
- **GIVEN** explicit recovery Accept established E=B and an outstanding checkpoint obligation over P=A, followed by local edits C
- **WHEN** an authorized field discard restores C to B
- **THEN** the acceptance obligation remains and still refuses unsafe target/session switching
- **AND** leaving the page does not retire the application-owned activation or claim B durable

#### Scenario: Remotely unsaved checkpoint and staged receipts are retained
- **GIVEN** E contains checkpointed remotely unconfirmed work, durable staged assets with upload receipts and an unresolved field-write intent
- **WHEN** newer local fields are discarded
- **THEN** only current fields return to E, with exact incomplete input preserved
- **AND** P including its recorded metadata, R, intent identity/input/token, staged order, receipts, files and owner remain unchanged

### Requirement: Discard cannot overwrite superseding field intent
Discard SHALL validate captured account/session/target/activation and the reviewed field/baseline revision within existing local arbitration. Stale authority, unsettled conflicting local work or a superseded revision SHALL return refusal without field effects. Expected failure SHALL preserve all local work; unexpected failures SHALL retain existing reporting behavior.

#### Scenario: Edit or checkpoint supersedes reviewed discard
- **WHEN** a field edit, checkpoint or baseline reconciliation changes the reviewed state before queued discard can act
- **THEN** discard is refused without replacing newer current/effective fields or changing physical evidence
- **AND** removal remains unauthorized until a fresh decision

#### Scenario: Account or activation changes while waiting
- **WHEN** A1 discard waits behind local work and A1 is revoked or replaced by B then A2
- **THEN** A1 changes no A2 fields, errors, route effects or persistence even when identifiers match

#### Scenario: Discard refusal leaves work available
- **WHEN** discard cannot establish current authority or safely enter local arbitration
- **THEN** it returns failure and leaves C/E/P/R, staged work, write intent and recovery obligation intact
- **AND** the current editor remains usable for retry or cancellation
