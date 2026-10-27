## Purpose

Provide account/session-owned Admin staged-file storage as an inert prerequisite for integrated editing, with verified copies and safe recovery independent of platform picking or remote uploads.

## ADDED Requirements

### Requirement: File intake requires an exact known durable owner
File acquisition SHALL require the exact account/session owner to be known durable. Missing or unreadable ownership SHALL prevent acquisition rather than create a substitute owner. Local storage SHALL neither launch a picker, consume platform lost data nor upload/associate media; callers must provide already-attributed files.

#### Scenario: Owner checkpoint fails
- **WHEN** required owner persistence fails before file intake
- **THEN** no accepted staged file/descriptor is committed and the persistence error is returned

#### Scenario: Missing or unknown owner
- **WHEN** intake references an absent, different or unreadable owner
- **THEN** no new owner or unrelated attachment is created

#### Scenario: Storage receives a verified handoff file
- **WHEN** a caller supplies bytes for a known exact owner
- **THEN** storage validates/acquires them without any platform retrieval, remote upload or association

### Requirement: Admin and Public storage roots remain isolated
Admin staged assets SHALL be private copies under their exact account/session ownership, separate from Public and picker-owned storage. Descriptors SHALL contain canonical relative paths, owner and digest without original picker paths or remote metadata. Neither feature's cleanup SHALL traverse the other's files.

#### Scenario: Original source disappears
- **WHEN** intake committed and the original file is removed
- **THEN** its private staged copy remains resolvable for that exact owner

#### Scenario: Identical content in two sessions
- **WHEN** two valid sessions acquire identical bytes
- **THEN** each owns independent files/descriptors and neither references the other's storage

#### Scenario: Feature cleanup
- **WHEN** either feature reconciles or removes contained local files
- **THEN** the other feature's sessions and descriptors remain unchanged

### Requirement: Publication follows verified file and descriptor commits
A staged item SHALL become observable only after a complete private copy, size/digest verification, final publication and descriptor commit. Failure SHALL preserve previously committed siblings. Incomplete or descriptor-less files SHALL not be reconstructed as supported attachments.

#### Scenario: Copy interruption
- **WHEN** copying stops before completion
- **THEN** only temporary residue exists and no descriptor/runtime item references it

#### Scenario: Source changes or grows
- **WHEN** copied bytes differ from the candidate digest or exceed the size limit
- **THEN** no accepted descriptor/runtime item is committed for that candidate

#### Scenario: Rename succeeds before descriptor commit
- **WHEN** the process stops after final rename but before descriptor persistence
- **THEN** the uncommitted item may be lost and its contained orphan file is cleaned best-effort
- **AND** prior committed siblings and owner remain recoverable

#### Scenario: Later batch candidate fails
- **WHEN** a hard copy/rename/descriptor error occurs after earlier acquisitions committed
- **THEN** those earlier acquisitions remain valid and the batch is not rolled back

### Requirement: Capacity deduplication and order include durable state
Storage SHALL deduplicate within exact owner/session, enforce the existing per-file maximum and five combined known-associated/staged items, and restore explicit stable descriptor order. Unknown associated capacity SHALL block new acquisition. It SHALL not infer remote byte deduplication from URLs or discard valid local files to satisfy capacity after restoration.

#### Scenario: Duplicate content
- **WHEN** intake supplies bytes already staged for that session
- **THEN** no additional file/descriptor/count or order change occurs

#### Scenario: Five combined images
- **WHEN** supplied verified context reports four associated images and the session has one staged image
- **THEN** another acquisition is rejected before commit

#### Scenario: Unknown associated count
- **WHEN** associated capacity is not known for the target
- **THEN** intake reports unavailable capacity without accepting more files or discarding existing ones

#### Scenario: Oversized candidate
- **WHEN** a candidate exceeds the existing 10 MiB maximum
- **THEN** it creates no accepted descriptor/runtime image

#### Scenario: Restart restores order
- **WHEN** multiple committed files restore
- **THEN** their explicit descriptor ordering is preserved

#### Scenario: Restored combined count exceeds five
- **WHEN** newly supplied verified associated count plus valid staged count exceeds five
- **THEN** all valid committed local files remain preserved, intake reports over-capacity and exact-owner local removal remains available

### Requirement: Capacity context matches the accepted owner and remote context
Acquisition SHALL validate account, local session, activation, target and associated count against current local context inside arbitration. Existing-target count SHALL belong to its exact accepted remote detail/baseline revision; missing, invalid or incompatible context SHALL return unavailable capacity without asset mutation. A genuine new target SHALL derive zero remote associations from its own identity, not an empty query. Storage SHALL not fetch remotely.

#### Scenario: CAPACITY-01 Different target
- **WHEN** capacity from target A is supplied while B is active, including a different account/session/activation
- **THEN** acquisition is refused without mutating either target's assets

#### Scenario: CAPACITY-02 Superseded remote snapshot
- **WHEN** a count belongs to an older accepted remote context than the active one, even with equal editable fields or server timestamp
- **THEN** acquisition is refused until a compatible context is supplied
- **AND** queued work rechecks compatibility inside arbitration before acquisition

#### Scenario: CAPACITY-03 New local submission
- **WHEN** the exact authorized new-target session has no remote ID
- **THEN** combined capacity uses zero remote associations plus that session's staged count without querying or inventing a remote row
- **AND** a previous persisted target's count/context cannot authorize acquisition

#### Scenario: CAPACITY-04 Unknown context
- **WHEN** count, ownership or accepted remote revision is missing, invalid or unverifiable for an existing target
- **THEN** unavailable capacity prevents new acquisition and existing staged work remains untouched

#### Scenario: CAPACITY-05 Over-capacity restoration
- **WHEN** a compatible latest remote count makes restored associated-plus-staged count exceed five
- **THEN** all valid local assets remain durable and removable without automatic deletion or truncation

#### Scenario: CAPACITY-06 Backend changes after local validation
- **WHEN** local admission succeeds and concurrent backend changes later consume capacity or finalize the submission
- **THEN** local validation provides no guarantee of remote acceptance
- **AND** future remote association must handle the server's pending-only/max-five rejection, without a backend call from local storage

### Requirement: Reconciliation requires reliable owner knowledge
Reconciliation SHALL restore valid exact-owner descriptor/file pairs, retain one deterministic valid duplicate and remove invalid descriptors or contained temp/orphan residue. Hard storage failure SHALL return unavailable state without partial runtime publication. Failed draft loading SHALL not authorize absence cleanup, and inactive valid sessions SHALL not be treated as orphaned.

#### Scenario: Missing corrupt or oversized final file
- **WHEN** a descriptor's final file is missing, digest-mismatched or oversized
- **THEN** that item is not restored, its stale descriptor is removed and valid siblings remain eligible

#### Scenario: Duplicate descriptors
- **WHEN** multiple valid descriptors identify the same owned file/digest
- **THEN** only the lowest valid technical-order descriptor is retained

#### Scenario: Invalid descriptor or arbitrary file
- **WHEN** a malformed descriptor or descriptor-less final file is encountered
- **THEN** malformed rows are removed by technical identity and contained orphan residue is cleaned best-effort
- **AND** no attachment is reconstructed from arbitrary files

#### Scenario: Hard ObjectBox failure
- **WHEN** a required read/reconciliation write fails
- **THEN** the session remains unavailable, no partial list publishes and no broad owner deletion occurs

#### Scenario: Inactive A and active B
- **WHEN** B reconciles while valid A is stored
- **THEN** A's checkpoint, descriptors and files remain recoverable

### Requirement: Path and link validation preserves containment
Storage SHALL reject absolute, traversing, noncanonical, wrong-owner and digest-inconsistent paths. Acquisition, resolution and cleanup SHALL not follow linked ownership directories/files outside their private roots. Failure diagnostics SHALL not disclose private local paths or path-bearing stack traces.

#### Scenario: Traversal path
- **WHEN** a descriptor contains an absolute or parent-traversing path
- **THEN** it cannot expose, mutate or delete an external file

#### Scenario: Linked directory or asset
- **WHEN** root/account/session/file state is a symlink
- **THEN** storage refuses the linked target and cleanup unlinks only contained links without traversing destinations

#### Scenario: Cleanup logging
- **WHEN** contained cleanup fails
- **THEN** path-free diagnostics leave external files and unrelated sessions untouched

### Requirement: Exact-owner removal is idempotent and retains its parent
Removal SHALL bind account/session/digest rather than a mutable index, remove descriptor ownership before contained file cleanup, and retain the draft owner. Missing files SHALL not prevent success. Descriptor deletion failure SHALL preserve runtime state; later cleanup failure SHALL leave non-restorable contained residue rather than broaden deletion.

#### Scenario: Stale rendered identity
- **WHEN** a captured removal target no longer matches current owner/digest
- **THEN** a replacement item cannot be removed by index reuse

#### Scenario: Missing file
- **WHEN** its descriptor is removed and its file is already absent
- **THEN** removal succeeds without remote deletion or parent retirement

#### Scenario: Descriptor removal fails
- **WHEN** descriptor deletion fails
- **THEN** runtime removal is not published and original ownership remains available

#### Scenario: File cleanup fails
- **WHEN** descriptor removal succeeds but file deletion fails
- **THEN** residue is not restored and only contained exact-owner cleanup is retryable

### Requirement: Local lifecycle commits preserve retained owners
Checkpoint, staged commit, removal, local activation and baseline publication SHALL use one feature-local ordering boundary. It SHALL not hold remote or external-picker interactions. Revocation SHALL stop new owner-dependent work/publication, while already-started commits retain their original owner. Field snapshot success SHALL never clear staged ownership.

#### Scenario: Checkpoint and acquisition overlap
- **WHEN** checkpoint A and acquisition for the same owner request local ordering
- **THEN** a deterministic order preserves the owner and every committed descriptor

#### Scenario: Revocation during commit
- **WHEN** authority changes after a repository commit starts
- **THEN** the commit can finish under its captured durable owner but cannot publish into the replacement context

#### Scenario: Restart after field update and staging
- **WHEN** a field snapshot changes before or after a staged commit and the component restarts
- **THEN** the session and its valid staged file restore together regardless of field checkpoint timing
