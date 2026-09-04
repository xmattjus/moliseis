## Purpose

Make locally selected Content Submission attachments a durable, recoverable part of the same single-draft session before remote submission, including safe Android lost-data recovery and retry from feature-owned files.

## ADDED Requirements

### Requirement: Asset picking starts only for a durably identified draft
Before launching an external asset picker, the system SHALL await completion of the one idempotent draft/staged-state initialization, establish durable existence of the resulting current draft, and capture its `clientSubmissionId` as the picker operation's ownership snapshot. Durable existence SHALL be tracked independently from equality with the last checkpoint snapshot: a fresh in-memory draft SHALL be written once even when its value equals that snapshot, while a draft already known to exist durably MAY retain the unchanged-checkpoint write optimization. If initialization/reconciliation or the required checkpoint fails, the system SHALL return the persistence error without opening the picker, staging files, or mutating the current assets.

#### Scenario: Fresh equal snapshot is physically checkpointed before picking
- **GIVEN** a newly constructed draft whose current value equals its in-memory checkpoint snapshot
- **AND** that draft identity is not yet known to exist in durable storage
- **WHEN** asset addition is requested
- **THEN** the current draft and `clientSubmissionId` SHALL be saved successfully before the picker is invoked
- **AND** the saved identity SHALL be captured for the picker operation

#### Scenario: Known durable unchanged draft preserves the checkpoint optimization
- **GIVEN** the active draft was loaded from durable storage or saved successfully
- **AND** its current value still equals its checkpoint snapshot
- **WHEN** another checkpoint is required before opening the picker
- **THEN** the system SHALL treat the existing durable identity as sufficient without performing a redundant draft save

#### Scenario: Failed checkpoint prevents picker launch
- **GIVEN** the current draft identity is not known to exist durably
- **WHEN** its required checkpoint returns an error
- **THEN** the same error SHALL be returned from asset addition
- **AND** the external picker SHALL NOT be invoked
- **AND** no staged file, descriptor, or runtime asset SHALL be created

#### Scenario: Persisted draft establishes durable existence on initialization
- **GIVEN** initialization successfully loads a valid persisted draft
- **WHEN** that draft and its exact `clientSubmissionId` become active
- **THEN** the system SHALL record that identity as durably existing without issuing an initialization save

#### Scenario: Early asset addition cannot overwrite a loading persisted draft
- **GIVEN** ViewModel construction created a fresh in-memory identity
- **AND** initialization is still loading a different persisted draft identity
- **WHEN** asset addition is requested before that load completes
- **THEN** asset addition SHALL await the shared initialization result before checkpointing
- **AND** it SHALL NOT save or open a picker for the constructor identity
- **AND** any later picker ownership SHALL use the restored active identity

#### Scenario: Session rotation resets durable-existence knowledge
- **GIVEN** explicit discard has retired the previous draft and created a fresh identity
- **WHEN** the new in-memory draft has not yet been saved
- **THEN** equality with its fresh checkpoint snapshot SHALL NOT cause the system to treat the new identity as durable

### Requirement: Local asset lifecycle mutations are serialized across Commands
The system SHALL use one Content Submission-local arbitration boundary to prevent draft checkpoint writes, staging commits, recovered-data processing, persistent single-asset removal, and staged cleanup/session rotation from committing concurrently. Re-entry protection belonging to separate Commands SHALL NOT be treated as mutual exclusion. The boundary SHALL cover the pre-picker durable-checkpoint/session-capture phase and the post-picker staging-commit phase separately, and SHALL NOT remain held while the user is interacting with the external picker. A standalone checkpoint SHALL capture its snapshot inside the same boundary so it cannot persist a retired identity after clear.

#### Scenario: Different Commands share lifecycle arbitration
- **GIVEN** asset addition and clear are exposed through different Command instances
- **WHEN** their local mutation phases overlap
- **THEN** those phases SHALL commit in one deterministic serial order rather than relying on either Command's own running flag

#### Scenario: Picker interaction does not block clear
- **GIVEN** asset addition has checkpointed and captured draft A's identity
- **WHEN** the external picker remains open
- **THEN** the local lifecycle arbitration boundary SHALL be available for `clear()` to run

#### Scenario: Clear follows a staging commit already inside arbitration
- **GIVEN** staging for draft A entered its serialized commit phase before clear requested the boundary
- **WHEN** staging commits and clear then acquires the boundary
- **THEN** clear SHALL run afterward
- **AND** clear SHALL remove draft A's committed staged state before rotating to the next active session

#### Scenario: Removal cannot interleave with staging or rotation
- **GIVEN** removal and either a staged commit or clear/session rotation are requested concurrently
- **WHEN** they enter local lifecycle arbitration
- **THEN** each operation SHALL observe the complete result of the operation ordered before it
- **AND** no runtime asset SHALL be left associated with a descriptor or session it does not own

#### Scenario: Standalone checkpoint cannot resurrect a cleared draft
- **GIVEN** a standalone checkpoint and clear/session rotation overlap
- **WHEN** lifecycle arbitration orders them
- **THEN** clear SHALL either wait for and then delete the completed old-session checkpoint or the checkpoint SHALL capture only the fresh identity after clear
- **AND** no late save SHALL recreate the retired draft identity

### Requirement: Picker results cannot cross a draft-session rotation
After an external picker returns, the system SHALL re-enter lifecycle arbitration and compare the picker operation's captured `clientSubmissionId` with the current active identity before validating or committing candidates. A mismatch SHALL be treated as stale/cancelled work: the returned files SHALL NOT create temporary or final staged files, descriptors, or runtime assets for either session, and the system SHALL NOT surface an unactionable generic failure to the user.

#### Scenario: Clear rotates while picker is open
- **GIVEN** an asset picker was opened for draft A
- **WHEN** clear succeeds and rotates the ViewModel to draft B before the picker returns
- **THEN** draft B SHALL remain the active session while the picker is still open

#### Scenario: Stale picker results are discarded
- **GIVEN** the picker captured draft A and the active identity is now draft B
- **WHEN** the picker returns selected media
- **THEN** no candidate SHALL be validated, staged, persisted, or added to runtime state
- **AND** neither draft A nor draft B SHALL gain a staged file or descriptor from that result
- **AND** asset addition SHALL complete as non-actionable stale work rather than a generic local error

### Requirement: Accepted assets transfer to private session-owned staging
Normal picker files and recovered Android files SHALL use one candidate pipeline in this order: size/capacity validation, SHA-1 digest calculation, session-scoped deduplication, private local staging, descriptor persistence, and runtime asset creation. A successful staging commit SHALL copy bytes away from picker-owned storage into feature-controlled durable private storage owned by `clientSubmissionId`, verify that the completed copy still has the candidate digest and remains within the existing file-size maximum, expose only a fully written final file, persist only a path relative to the feature staging root, and make the runtime asset path resolve to that final staged copy. A descriptor SHALL contain no remote asset metadata or original picker path.

#### Scenario: Candidate bytes are acquired into feature storage
- **GIVEN** an under-limit, non-duplicate candidate at a picker-owned source path
- **WHEN** staging succeeds
- **THEN** the candidate bytes SHALL exist in the active draft's private staging directory
- **AND** the persisted descriptor SHALL contain the active `clientSubmissionId`, SHA-1 digest, and relative staged path only
- **AND** the runtime asset path SHALL resolve to the staged file rather than the source path

#### Scenario: Partial copies are never valid assets
- **GIVEN** a candidate is being copied into staging
- **WHEN** the copy has not completed and closed successfully
- **THEN** it SHALL exist only as a temporary file in the target session directory
- **AND** no descriptor or runtime asset SHALL reference it

#### Scenario: Final rename precedes descriptor persistence
- **GIVEN** a temporary copy completed successfully
- **WHEN** the staging commit continues
- **THEN** the file SHALL be renamed to its deterministic digest-derived final name before a descriptor pointing to that final file is persisted

#### Scenario: Source mutation cannot mislabel staged bytes
- **GIVEN** a picker-owned source changes after its candidate digest is calculated
- **WHEN** the completed temporary copy no longer hashes to that digest
- **THEN** the temporary copy SHALL be rejected before final rename
- **AND** no descriptor or runtime asset SHALL be committed under the stale digest

#### Scenario: Source growth cannot bypass the size maximum
- **GIVEN** a candidate passed the initial size check but grew before or during staging
- **WHEN** the completed temporary copy exceeds the existing maximum file size
- **THEN** it SHALL be rejected before final rename
- **AND** no descriptor or runtime asset SHALL be committed for the oversized copy

#### Scenario: Hard failure later in a batch preserves earlier commits
- **GIVEN** one or more candidates in a selected batch committed successfully
- **WHEN** a later candidate fails because the staging directory, copy, rename, or descriptor write fails
- **THEN** the operation SHALL return an error for the hard failure
- **AND** every earlier committed staged asset SHALL remain persisted and available
- **AND** the batch SHALL NOT be rolled back as a whole

### Requirement: Deduplication and capacity include durable session state
The system SHALL preserve SHA-1 as the local accidental-content-deduplication digest and SHALL scope duplicate ownership to `clientSubmissionId`. It SHALL enforce the existing maximum of five runtime/staged assets using restored and newly committed assets together. Oversized, over-capacity, and duplicate candidates SHALL retain the existing soft-rejection behavior where practical, allowing other valid candidates from the same batch to commit.

#### Scenario: Duplicate content in one session is staged once
- **GIVEN** an active draft already owns a staged descriptor and final file for a digest
- **WHEN** normal selection or Android recovery supplies identical content
- **THEN** no second final file or descriptor SHALL be created
- **AND** runtime asset count SHALL remain unchanged

#### Scenario: Identical content in different sessions has separate ownership
- **GIVEN** two different `clientSubmissionId` values encounter identical bytes
- **WHEN** each valid session stages those bytes
- **THEN** each session MAY own its own descriptor and file under its own directory
- **AND** neither session SHALL reference the other's staged state

#### Scenario: Restored assets consume capacity
- **GIVEN** initialization restores four valid staged assets
- **WHEN** a candidate batch is processed
- **THEN** only one additional non-duplicate, under-size candidate SHALL be eligible to commit
- **AND** the existing maximum-five rejection semantics SHALL apply to the remainder

#### Scenario: Oversized candidate is not staged
- **GIVEN** a candidate exceeds the existing maximum file size
- **WHEN** the common candidate pipeline validates it
- **THEN** no temporary file, final file, descriptor, or runtime asset SHALL be created for that candidate
- **AND** valid candidates in the same batch MAY continue

### Requirement: Initialization restores one coordinated durable session
Initialization SHALL be idempotent and shared by all local checkpoint/session mutations. It SHALL first resolve the persisted draft result and whether a durable active identity exists, then reconcile and restore staged state for that identity, and only afterward mark initialization complete, expose `loadState == ready`, and notify listeners. Repeated callers SHALL await the same work rather than load twice. Valid descriptors SHALL be loaded using explicit ascending local entity-ID order, and runtime assets SHALL be reconstructed with staged absolute paths. If no persisted active draft exists, leftover staged state SHALL NOT be adopted by the fresh in-memory identity.

#### Scenario: Ready waits for staged restoration
- **GIVEN** draft loading has completed but staged reconciliation is still pending
- **WHEN** initialization state is observed
- **THEN** `loadState` SHALL remain loading
- **AND** partially restored staged assets SHALL NOT be exposed as a completed session

#### Scenario: ViewModel recreation restores staged paths and order
- **GIVEN** a persisted draft owns multiple valid staged descriptors
- **WHEN** a new ViewModel initializes after recreation or process restart
- **THEN** it SHALL restore the same valid assets in explicit ascending descriptor-ID order
- **AND** every runtime asset path SHALL resolve to its existing staged file
- **AND** no implicit ObjectBox storage order SHALL determine presentation order

#### Scenario: Concurrent initialization callers share one result
- **GIVEN** dependency injection starts initialization without awaiting it
- **WHEN** a local checkpoint or mutation requests initialization before that call completes
- **THEN** both callers SHALL await the same initialization future
- **AND** draft load and staged reconciliation SHALL each run once

#### Scenario: No persisted draft does not adopt leftover assets
- **GIVEN** initialization finds no recoverable persisted active draft
- **AND** one or more old staged descriptors or directories exist
- **WHEN** initialization reconciles local state
- **THEN** it SHALL keep the newly generated in-memory draft asset-free
- **AND** the leftover state SHALL be treated as orphan state rather than reassigned to the new identity

#### Scenario: Hard reconciliation failure completes safely
- **GIVEN** active staged reconciliation returns an infrastructure error
- **WHEN** initialization completes its reconciliation attempt
- **THEN** no partially restored runtime assets SHALL be exposed
- **AND** the initialization barrier SHALL complete without introducing an indefinite loading wait
- **AND** normal asset addition SHALL retry reconciliation and SHALL NOT open the picker while staged state remains unknown
- **AND** lost-data processing SHALL NOT commit against that unknown state

#### Scenario: Unavailable staged state blocks submission without cleanup
- **GIVEN** reconciliation, staged path resolution, or restored-count validation left the active durable staged state unavailable or quarantined
- **WHEN** submission is requested, including before initialization had otherwise completed
- **THEN** the system SHALL await shared initialization and return an error before any Cloudinary upload or final remote submission
- **AND** no runtime staged asset SHALL be exposed or mutated
- **AND** the durable descriptors and files SHALL remain unchanged for later recovery or explicit discard

### Requirement: Filesystem and descriptor state reconcile deterministically
The local staged-asset boundary SHALL reconcile ObjectBox descriptors and filesystem state without exposing temporary, symlinked, digest-mismatched, oversized, path-escaping, or broken assets and without a transaction journal or staging state machine. For the active durable identity it SHALL restore descriptor/final-file pairs whose bytes match their digest, remove descriptors whose final files are missing or invalid, delete temporary files, and reconstruct missing descriptors only for deterministic final files whose bytes match their basename digest and remain within the file-size maximum. It SHALL sort descriptor-less valid finals lexicographically by digest before assigning their new auto IDs, retain the lowest valid auto-ID row when duplicate descriptors exist, and remove later duplicates. It SHALL exclude and clean descriptor/directory state owned by every non-active identity; with no durable active identity, all existing staged session state SHALL be treated as orphan state. Cleanup SHALL remove malformed rows by technical ID and SHALL NOT follow filesystem links outside the staging root.

#### Scenario: Descriptor and final file restore normally
- **GIVEN** an active-session descriptor points to its existing valid final staged file
- **WHEN** reconciliation runs
- **THEN** that asset SHALL be retained and returned for runtime restoration

#### Scenario: Missing final file removes stale descriptor
- **GIVEN** an active-session descriptor's final file does not exist
- **WHEN** reconciliation runs
- **THEN** the broken asset SHALL NOT be restored
- **AND** the stale descriptor SHALL be removed

#### Scenario: Temporary files are removed
- **GIVEN** one or more temporary-copy files remain after interruption
- **WHEN** reconciliation or per-session cleanup runs
- **THEN** those files SHALL be deleted
- **AND** they SHALL NOT create descriptors or runtime assets

#### Scenario: Valid final file reconstructs a missing descriptor
- **GIVEN** an active draft directory contains a valid deterministic final staged file
- **AND** ObjectBox contains no descriptor for its digest
- **WHEN** reconciliation runs
- **THEN** exactly one active-session descriptor SHALL be reconstructed from that file
- **AND** the asset SHALL be eligible for restoration

#### Scenario: Filename digest must match final-file content
- **GIVEN** a descriptor-less final file has a deterministic digest basename but different content
- **WHEN** reconciliation runs
- **THEN** no descriptor SHALL be reconstructed for that file
- **AND** the mismatched file SHALL NOT be exposed as a runtime asset

#### Scenario: Existing invalid active files are not retained or reconstructed
- **GIVEN** an active descriptor/final pair or descriptor-less final has mismatched content, an oversized final, or a structurally plausible relative filename that does not match its digest
- **WHEN** reconciliation runs
- **THEN** the invalid asset SHALL not be restored or reconstructed
- **AND** its stale descriptor, if any, and invalid in-root file SHALL be removed without affecting valid active assets or their explicit ID order

#### Scenario: Duplicate descriptors retain deterministic order
- **GIVEN** multiple active-session descriptor rows exist for one digest
- **WHEN** reconciliation runs
- **THEN** the lowest valid auto-ID descriptor SHALL be retained
- **AND** every later duplicate row SHALL be removed

#### Scenario: Missing descriptors are reconstructed in stable order
- **GIVEN** multiple valid descriptor-less final files exist for the active session
- **WHEN** reconciliation reconstructs their rows
- **THEN** it SHALL sort the files lexicographically by digest before insertion
- **AND** subsequent explicit auto-ID ordering SHALL produce a stable restored order

#### Scenario: Foreign session state is orphaned
- **GIVEN** a persisted active draft has identity A
- **AND** descriptors or directories exist for identity B
- **WHEN** initialization reconciliation runs
- **THEN** identity B's state SHALL NOT be attached to A
- **AND** identity B's descriptors, files, temporary files, and empty directory SHALL be eligible for idempotent orphan cleanup

#### Scenario: Malformed and linked state cannot escape cleanup containment
- **GIVEN** a malformed descriptor path, malformed root child, or filesystem link exists in staging
- **WHEN** reconciliation or cleanup runs
- **THEN** the system SHALL NOT resolve or follow that state outside the feature root
- **AND** malformed descriptor rows SHALL be removed by technical ID
- **AND** in-root link entries SHALL be unlinked rather than traversed

### Requirement: Android lost data is acquired early and processed after restoration
On Android, the recovery Command SHALL be allowed to call the platform lost-data API immediately when triggered, including before ViewModel initialization completes. It SHALL retain that response in memory for the operation, await the initialization/reconciliation barrier, and only then process recovered files within local lifecycle arbitration through the same candidate pipeline as normal selection. After every attempted Android platform call, including a thrown exception, recovery SHALL start and await the shared initialization result before returning. Recovery SHALL be best-effort: empty, error, oversized, or duplicate results SHALL NOT invalidate existing staged assets. Recovered files SHALL NOT be associated with a newly generated identity when initialization did not restore a matching durable draft.

#### Scenario: Production startup ordering waits after retrieval
- **GIVEN** a ViewModel is created and initialization starts without being awaited
- **AND** the screen immediately triggers Android recovery
- **WHEN** the lost-data API returns media before persisted draft and staged-state restoration complete
- **THEN** the response SHALL be retained without staging it
- **AND** processing SHALL begin only after initialization/reconciliation completes
- **AND** recovered media SHALL be owned by the restored draft identity

#### Scenario: Recovery deduplicates against restored assets
- **GIVEN** initialization restores a staged asset
- **AND** Android recovery returns identical content
- **WHEN** deferred recovery processing runs
- **THEN** it SHALL calculate the same digest through the common pipeline
- **AND** it SHALL create no duplicate file, descriptor, or runtime asset

#### Scenario: Clear makes a deferred recovery response stale
- **GIVEN** initialization restored draft A and Android recovery retained a response for A
- **WHEN** clear rotates the active session to draft B before recovered-file processing enters lifecycle arbitration
- **THEN** recovery SHALL compare its captured eligible identity with B and discard the response
- **AND** no recovered file SHALL be attached to either session

#### Scenario: Recovery honors restored capacity and size limits
- **GIVEN** restored staged assets already consume some or all available capacity
- **WHEN** Android returns recovered media including oversized or excess candidates
- **THEN** the existing maximum-five and file-size rules SHALL be calculated against restored runtime state
- **AND** valid staged assets SHALL remain unchanged by rejected recovery candidates

#### Scenario: Recovery consumes only remaining restored capacity
- **GIVEN** four valid staged assets were restored in explicit order
- **AND** Android returns multiple candidates including a duplicate or oversized file
- **WHEN** recovery processes the candidates
- **THEN** at most one new valid non-duplicate under-limit candidate SHALL commit
- **AND** the four restored assets SHALL retain their paths, digests, and order
- **AND** every remaining recovered candidate SHALL leave existing staged state unchanged

#### Scenario: No durable recovered session prevents reassociation
- **GIVEN** initialization returns no valid persisted draft or cannot restore one safely
- **WHEN** an early lost-data response contains files from an interrupted picker interaction
- **THEN** those files SHALL NOT be staged for the unrelated fresh in-memory identity
- **AND** existing orphan cleanup rules SHALL remain authoritative

#### Scenario: Non-Android and empty recovery remain no-ops
- **GIVEN** the current platform is not Android or the Android response is empty
- **WHEN** recovery is triggered
- **THEN** it SHALL complete without changing staged or runtime assets

#### Scenario: Thrown Android recovery still initializes
- **GIVEN** no caller previously started initialization
- **AND** the Android lost-data platform call throws
- **WHEN** recovery completes non-actionably
- **THEN** draft loading and staged reconciliation SHALL each have run once
- **AND** the initialization barrier SHALL complete with `loadState == ready`
- **AND** no recovered or valid existing staged asset SHALL be mutated

### Requirement: Disposed ViewModels do not publish late local asset mutations
After disposal, local asset commands SHALL not add or remove runtime assets or notify listeners after an asynchronous picker, staging, path-resolution, or persistent-removal operation completes. A durable staging/removal operation that committed before disposal is detected SHALL remain recoverable through the ordinary next initialization; this capability SHALL not introduce cancellation, rollback, or a generic scheduler.

#### Scenario: Disposed picker result is not published
- **GIVEN** a picker or staging operation remains in flight
- **WHEN** the ViewModel is disposed before the operation completes
- **THEN** its completion SHALL not mutate runtime assets or notify listeners
- **AND** any already committed staged descriptor/file SHALL remain available for subsequent restoration

#### Scenario: Disposed removal result is not published
- **GIVEN** persistent removal remains in flight
- **WHEN** the ViewModel is disposed before it completes
- **THEN** its completion SHALL not mutate runtime assets or notify listeners

### Requirement: Removal and discard clean persistent staged ownership
Single-asset removal SHALL run inside lifecycle arbitration and remove the active session's descriptor, staged file, and matching runtime asset before notifying the UI; an already-missing file SHALL not prevent successful removal. The staged-asset boundary SHALL also expose one idempotent primitive that clears all descriptors, final files, temporary files, and the empty directory for one `clientSubmissionId`. Explicit discard SHALL preserve the existing persistence-first draft-clear guarantee, SHALL perform old-session staged cleanup before rotating runtime identity, and SHALL leave any interruption residue safely orphaned for later reconciliation rather than attaching it to a new session.

#### Scenario: Removing one asset persists the removal
- **GIVEN** the active session owns a staged runtime asset
- **WHEN** its index is removed
- **THEN** the matching active-session descriptor and final staged file SHALL be deleted
- **AND** the runtime asset SHALL be removed and the UI notified
- **AND** other staged assets SHALL retain their order and ownership

#### Scenario: Queued removal cannot target a replacement session
- **GIVEN** removal captured an asset digest and identity from draft A
- **WHEN** clear rotates to draft B before removal enters lifecycle arbitration
- **THEN** removal SHALL become stale work without deleting an asset from B
- **AND** it SHALL NOT reinterpret the old index against B's runtime list

#### Scenario: Removal tolerates an already-missing file
- **GIVEN** the selected asset's descriptor exists but its final file is already missing
- **WHEN** removal runs
- **THEN** descriptor and runtime removal SHALL still complete successfully

#### Scenario: Per-session cleanup is idempotent
- **GIVEN** a session has any combination of descriptors, final files, temporary files, or no remaining state
- **WHEN** its cleanup primitive is called one or more times
- **THEN** every call SHALL converge toward no staged state and no per-session directory
- **AND** repeated calls SHALL remain safe

#### Scenario: Failed draft clear preserves the recoverable session
- **GIVEN** clear is requested for an active durable draft with staged assets
- **WHEN** the existing draft-clear boundary returns an error
- **THEN** staged cleanup SHALL NOT retire the current session
- **AND** draft identity, runtime assets, descriptors, files, and current form state SHALL remain recoverable

#### Scenario: Successful discard cleans old ownership before rotation
- **GIVEN** the existing draft-clear boundary succeeds
- **WHEN** clear continues inside lifecycle arbitration
- **THEN** old-session staged cleanup SHALL run before a fresh in-memory identity becomes active
- **AND** interrupted cleanup residue SHALL remain foreign orphan state eligible for the next reconciliation

### Requirement: Remote failures preserve the staged upload source
Cloudinary upload failure, partial sequential upload failure, and final remote Content Submission failure SHALL NOT delete, rewrite, or roll back local staged descriptors or source files. Initial upload and retry SHALL read each asset from its feature-controlled staged path, remain independent of the original picker-owned path, and preserve the existing sequential remote behavior. This capability SHALL NOT add Cloudinary deletion, rollback, or compensating remote transactions.

#### Scenario: Upload reads the staged copy after source loss
- **GIVEN** an asset was staged from a picker-owned source path
- **AND** that original source is deleted or made unavailable after staging
- **WHEN** submission uploads the asset
- **THEN** the upload boundary SHALL receive and read the staged file inside Content Submission storage
- **AND** upload SHALL NOT depend on the original source path

#### Scenario: Cloudinary failure preserves staged assets for retry
- **GIVEN** one or more assets are durably staged
- **WHEN** a Cloudinary upload fails, including after an earlier sequential upload succeeded
- **THEN** every local staged descriptor and source file SHALL remain unchanged
- **AND** retry SHALL use those same staged source paths

#### Scenario: Final remote submission failure preserves staged assets
- **GIVEN** all local assets uploaded but the final Content Submission request fails
- **WHEN** the submit Command completes with that error
- **THEN** local staged descriptors, files, runtime paths, and ordering SHALL remain available for retry

#### Scenario: No eager Cloudinary rollback is introduced
- **GIVEN** a remote operation fails after one or more Cloudinary assets may exist
- **WHEN** failure handling runs
- **THEN** this capability SHALL NOT invoke Cloudinary deletion or redesign existing remote rollback behavior

### Requirement: Subplan completion is not release readiness
Completion of local asset staging SHALL be assessed as Content Submission Hardening Subplan 2 only. The per-session cleanup seam SHALL support explicit clear/discard. Because the current progress route already invokes that same clear operation after completed submission, this existing retirement path SHALL also clean staged state without adding a new submit-success hook; any redesign of definitive finalization remains deferred. The system SHALL NOT be declared release-ready or release-proof until all Content Submission Hardening subplans and their cross-subplan behavior have been implemented and verified.

#### Scenario: Existing post-success clear reuses staged cleanup
- **GIVEN** per-session cleanup is implemented through the existing clear operation
- **AND** the existing progress route invokes clear after a completed submit when retiring the form session
- **WHEN** that clear runs
- **THEN** it SHALL clean the completed session's staged state through the same tested primitive
- **AND** `_submit()` itself SHALL gain no eager cleanup, rollback, or new finalization callback

#### Scenario: Later finalization redesign remains deferred
- **GIVEN** a later hardening subplan may refine definitive successful-submit retirement
- **WHEN** Subplan 2 is completed
- **THEN** the tested per-session cleanup primitive SHALL remain available for that future caller
- **AND** no speculative finalization abstraction SHALL be introduced here

#### Scenario: Subplan verification does not claim whole-feature readiness
- **WHEN** every requirement in this capability passes
- **THEN** the result SHALL be reported as completion of Subplan 2 only
- **AND** whole Content Submission release readiness SHALL remain deferred to the complete hardening sequence
