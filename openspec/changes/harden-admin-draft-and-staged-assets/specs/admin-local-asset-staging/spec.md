## Purpose

Make Admin attachments durable within their exact account and local editor session, without automatic upload, unsafe reassignment or deletion of recoverable inactive sessions.

## ADDED Requirements

### Requirement: Admin picker launch requires durable attributed ownership
Before launching a picker the system SHALL verify the active Admin account/session, await initialization and reconciliation, establish a durable checkpoint and record shared picker ownership. Failure at any required boundary SHALL prevent launch. No picker result SHALL be attributed by whichever editor happens to be visible when it returns.

#### Scenario: Failed checkpoint prevents picker
- **WHEN** the required local checkpoint fails before persisted-editor image selection
- **THEN** the picker, local staging, upload and association are not invoked
- **AND** previous fields/assets remain available with the persistence error

#### Scenario: Ticket persistence fails
- **WHEN** the draft is durable but shared ownership cannot be recorded
- **THEN** no external picker opens and no remote image action starts

#### Scenario: Launch waits for restored owner
- **WHEN** selection is requested while activation restores another persisted identity
- **THEN** selection waits for that bound initialization and uses only its verified owner

### Requirement: Admin staged copies belong to one account and session
Accepted staged assets SHALL use private feature-owned copies distinct from Public and picker storage. Each descriptor SHALL identify its account, session, digest and canonical relative path without original picker paths or remote upload metadata. Normal selection and recovery SHALL preserve the same ownership and validation guarantees.

#### Scenario: Picker cache disappears after commit
- **WHEN** a valid Admin staged copy commits and the original picker file disappears
- **THEN** the committed staged file remains resolvable within its exact owner

#### Scenario: Identical content under different owners
- **WHEN** two sessions or accounts acquire identical bytes
- **THEN** each owns independent descriptors/files and neither references the other's bytes

#### Scenario: Feature roots remain isolated
- **WHEN** Admin staging or cleanup occurs
- **THEN** Public staged files/descriptors and shared inbox files are not scanned or deleted by that feature cleanup

### Requirement: Asset publication preserves verified commit order
A staged asset SHALL become observable only after its private copy is complete, size/digest verified, final file published and descriptor committed. Partially copied files SHALL NOT be valid assets. A failure SHALL preserve earlier confirmed local work and SHALL NOT reconstruct an attachment from a descriptor-less file.

#### Scenario: Copy is interrupted
- **WHEN** acquisition stops during a temporary copy
- **THEN** no descriptor or runtime asset refers to the incomplete file
- **AND** contained temporary residue is eligible for exact-session cleanup

#### Scenario: Source changes after digest calculation
- **WHEN** copied bytes no longer match the original digest or exceed the size maximum
- **THEN** no final descriptor/runtime asset is committed for those bytes

#### Scenario: Rename completes before descriptor commit
- **WHEN** the process terminates after final rename but before descriptor persistence
- **THEN** that uncommitted attachment may be lost and its orphan file is cleaned best-effort
- **AND** previously committed siblings and the form checkpoint remain recoverable

#### Scenario: Later batch item has a hard failure
- **WHEN** a later acquisition fails after earlier candidates committed
- **THEN** the hard error is reported without rolling back the earlier descriptor-backed files

### Requirement: Deduplication capacity and ordering use durable session state
The system SHALL deduplicate staged content within the exact Admin account/session, enforce the existing per-file limit and maximum five combined associated/staged images, and restore explicit descriptor order. It SHALL not infer remote byte deduplication from URLs. Rejected candidates SHALL NOT replace confirmed work; backend pending/capacity enforcement remains authoritative.

#### Scenario: Duplicate within one session
- **WHEN** selection or recovery supplies bytes already committed to the session
- **THEN** no additional descriptor/file/count or order change occurs

#### Scenario: Combined maximum is reached
- **WHEN** four associated images and one staged image exist
- **THEN** a sixth combined image is rejected before acquisition/upload
- **AND** removing the staged image restores only that local capacity

#### Scenario: Oversized candidate
- **WHEN** a candidate exceeds the existing 10 MiB maximum
- **THEN** it creates no accepted descriptor/runtime image and leaves previous assets unchanged

#### Scenario: Restart restores order
- **WHEN** a session with committed descriptors is recreated
- **THEN** valid assets restore in explicit stable descriptor order rather than incidental storage iteration order

#### Scenario: Restored combined count exceeds five
- **WHEN** remote additions while the session was inactive make associated plus valid staged count exceed five
- **THEN** all committed staged bytes are preserved and an over-capacity state blocks new selection, Save and moderation
- **AND** exact-owner local removal remains available to bring the combined count within capacity

#### Scenario: Remote capacity changed concurrently
- **WHEN** the server refuses a live immediate association because another writer consumed capacity
- **THEN** the existing error is surfaced without bypassing the RPC or deleting other confirmed local work

### Requirement: Reconciliation validates descriptors and contained final files
For a verified owner, reconciliation SHALL restore only valid descriptor/final-file pairs, remove invalid descriptors and contained incomplete/orphan files, and retain one deterministic valid duplicate. A hard storage failure SHALL leave the session unavailable rather than publish a partial asset list. Unknown draft ownership SHALL never authorize reconciliation as absence.

#### Scenario: Missing corrupted or oversized final file
- **WHEN** a descriptor's final file is missing, digest-mismatched or oversized
- **THEN** that asset is not restored and its stale descriptor is removed
- **AND** valid siblings remain eligible for restoration

#### Scenario: Duplicate descriptors
- **WHEN** multiple valid descriptors identify the same owned digest/file
- **THEN** only the lowest valid technical-order descriptor is retained

#### Scenario: Invalid descriptor and orphan file
- **WHEN** a malformed descriptor or a final file without a valid descriptor is encountered
- **THEN** malformed rows are removed by technical identity and contained orphan files are cleaned best-effort
- **AND** arbitrary file bytes never become reconstructed attachments

#### Scenario: Hard ObjectBox failure
- **WHEN** a read or required reconciliation write fails
- **THEN** no partial runtime list is published and no broad session deletion occurs
- **AND** later explicit retry can reconcile the original owner

### Requirement: Path and link validation cannot escape owned roots
The system SHALL reject noncanonical, absolute, traversing, wrong-owner or digest-inconsistent descriptor paths. It SHALL not follow symlinked ownership directories/files or recursive cleanup links outside the private root. Diagnostics SHALL not disclose private local paths or file-bearing stack traces.

#### Scenario: Traversal descriptor
- **WHEN** a descriptor contains an absolute path or parent traversal
- **THEN** it cannot resolve, expose or delete an external file

#### Scenario: Symlink at an ownership segment
- **WHEN** a staging root child, account/session directory or asset is a link to outside storage
- **THEN** staging/restoration refuses the linked target
- **AND** cleanup may unlink only the contained link without traversing its destination

#### Scenario: Cleanup failure logging
- **WHEN** contained cleanup fails
- **THEN** a path-free diagnostic is recorded and no raw local path is exposed through feedback/logging

### Requirement: Removal and retirement preserve exact ownership
Local removal SHALL target the captured account/session/digest and be idempotent when the asset or file is already absent. Session retirement SHALL establish durable retirement before abandoning the owner. Inactive valid sessions SHALL remain recoverable; failure or inactivity SHALL NOT authorize cleanup of unrelated sessions.

#### Scenario: Removal index is reused
- **WHEN** a rendered callback's session/generation/digest no longer matches its asset
- **THEN** no removal is admitted against the new occupant

#### Scenario: Removed recovered asset cannot be replayed
- **WHEN** recovered staging succeeded, inbox acknowledgement failed, and the user removes the recovered image
- **THEN** its pending inbox references are terminally rejected before descriptor deletion
- **AND** later recovery cannot restore the deliberately removed asset

#### Scenario: Missing file removal
- **WHEN** the descriptor is removed and the file is already missing
- **THEN** removal completes successfully without a remote delete

#### Scenario: Descriptor removal fails
- **WHEN** deleting the descriptor fails
- **THEN** runtime removal is not published and the original owner is preserved for retry

#### Scenario: File cleanup fails after descriptor removal
- **WHEN** descriptor deletion succeeds but file deletion fails
- **THEN** residue remains non-restorable and retryable for exact-session cleanup
- **AND** no unrelated session cleanup is attempted

#### Scenario: Retirement failure
- **WHEN** durable retirement fails
- **THEN** current identity and checkpoint remain available without rotating to a fresh owner

#### Scenario: Inactive A survives active B reconciliation
- **WHEN** B is reconciled and valid account-owned A is inactive
- **THEN** A's checkpoint, descriptors and files remain intact

### Requirement: Local lifecycle mutations have one ordering boundary
Checkpoint, staging commit, removal, activation and retirement SHALL have deterministic feature-local ordering. External picker interaction and remote requests SHALL not hold that boundary. Per-command reentrancy SHALL not substitute for cross-command ordering. Revoked results SHALL not start new commits or mutate a replacement activation.

#### Scenario: Checkpoint overlaps retirement
- **WHEN** a checkpoint and retirement overlap
- **THEN** either checkpoint completes before retirement deletes it or the stale checkpoint is refused
- **AND** no late save resurrects the retired owner

#### Scenario: Picker is pending during revocation
- **WHEN** a picker remains open while logout or retirement revokes its owner
- **THEN** local revocation can complete without waiting on the external UI
- **AND** the later result creates no feature-owned staged descriptor or remote phase

#### Scenario: Commit was already started
- **WHEN** owner revocation occurs after repository commit work began
- **THEN** a completed durable copy stays owned by the original session
- **AND** no late runtime publication into the replacement owner occurs

### Requirement: Recovered Admin media is local only
Shared recovery SHALL hand Admin media only to its exact verified account/session under the shared recovery contract. Recovery SHALL never upload or associate automatically, including for existing pending submissions. Unavailable auth/context SHALL retain private committed inbox work. New-mode image UI and remote persistence of staged recovery remain disabled until a complete Save workflow exists.

#### Scenario: Admin recovery while Public is visible
- **WHEN** startup retrieves Admin-owned media while Public is active
- **THEN** Public receives no attachment and no remote action starts
- **AND** committed bytes wait for explicit matching authorized Admin activation

#### Scenario: Auth not restored or different account active
- **WHEN** Admin recovery is acquired before auth restoration or account B is active for account A's ticket
- **THEN** A's committed inbox stays private and is not attached to B
- **AND** matching authorized activation by A is required for consumption

#### Scenario: Persisted picker result recovered after process recreation
- **WHEN** a persisted pending Admin picker result is recovered after restart
- **THEN** its verified bytes become local staged work only
- **AND** the editor shows recoverable local work/removal and blocks legacy Save that cannot persist it

#### Scenario: Retired session cannot recover into a fresh draft
- **WHEN** a ticket's original session has been discarded or retired
- **THEN** its result is rejected rather than attached to a newly generated draft

### Requirement: Live persisted asset behavior remains immediate and guarded
A normal live selection for an already-persisted pending submission SHALL retain immediate upload and association after ownership checks, without deferred Save semantics. Its existing delete, pending-only, capacity and command-exclusion guards SHALL remain. Auth/session revocation after selection SHALL prevent unstarted upload/association phases.

#### Scenario: Existing pending editor selects normally
- **WHEN** a normal live picker returns to its still-authorized persisted pending owner
- **THEN** the existing upload and association run immediately under existing command exclusion

#### Scenario: Logout between upload and association
- **WHEN** a live upload finishes after its account/session authority was revoked
- **THEN** no later association starts and no replacement editor receives the result
- **AND** already-started remote effects are not compensated or automatically replayed

#### Scenario: Final-status editor cannot pick
- **WHEN** an accepted or rejected submission requests image mutation
- **THEN** the existing guard refuses the operation before picker/upload/association
