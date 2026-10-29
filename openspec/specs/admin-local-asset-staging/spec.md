# admin-local-asset-staging Specification

## Purpose

Provide account/session-owned Admin staged-file storage for the active editor, with verified private copies, safe recovery and separately persisted upload/association receipts. Local storage remains independent of platform picking and remote upload orchestration.

## Requirements

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
Admin staged assets SHALL be private copies under their exact account/session ownership, separate from Public and picker-owned storage. Local descriptors SHALL contain canonical relative paths, owner and digest without original picker paths. Separately versioned persistence receipts SHALL not change that local path/identity contract. Neither feature's cleanup SHALL traverse the other's files.

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

### Requirement: Confirmed asset progress is durable and exact-owner
Confirmed upload receipts and association IDs SHALL persist separately from local descriptor identity, bound to the exact account/session/digest/remote target. Legacy descriptors SHALL restore as local-only. Malformed progress SHALL not erase valid private bytes or authorize remote retry.

#### Scenario: Restart after upload confirmation
- **GIVEN** a confirmed receipt was durably recorded before association
- **WHEN** the real local store reopens
- **THEN** Save reuses the receipt and private source rather than uploading that file again

#### Scenario: Ambiguous association response
- **WHEN** remote association may have committed without confirmation
- **THEN** the descriptor and upload receipt remain available for exact-receipt server replay

#### Scenario: Receipt persistence failed before process death
- **WHEN** upload success was received but its receipt did not commit locally
- **THEN** restart does not invent confirmation and can use existing deterministic upload lookup/retry without claiming cross-service atomicity

### Requirement: Confirmed cleanup is item-specific and capacity remains accurate
Save SHALL remove only captured confirmed descriptors after recording association evidence. Failed removal SHALL preserve reusable confirmation. Capacity SHALL count a remotely associated receipt once after authoritative reconciliation, preserve uncaptured staged items and continue enforcing five images and 10 MiB.

#### Scenario: Remote association confirmed but descriptor removal fails
- **WHEN** local cleanup cannot commit
- **THEN** retry repairs that exact item without another upload and does not delete siblings or the owner

#### Scenario: New staging overlaps remote completion
- **WHEN** an uncaptured staged item commits while Save A completes
- **THEN** it remains local pending work for a later Save and is not swept by A's cleanup

#### Scenario: Concurrent capacity requests
- **GIVEN** associated and unconfirmed staged images consume four slots
- **WHEN** two candidates request local acquisition concurrently
- **THEN** local arbitration accepts at most one new distinct item while server insertion independently enforces five

#### Scenario: Size limit
- **WHEN** a selected file exceeds 10 MiB
- **THEN** it is not accepted into staging or uploaded and existing valid siblings remain

### Requirement: Field reconciliation preserves staged evidence independently
Existing exact-owner bytes and separate upload/association receipts SHALL survive either field recovery choice unchanged. Field acceptance SHALL not accept, discard, replay or complete staged work. Complete fresh associations SHALL determine current visible remote state and capacity even when the editable-field token has not changed.

#### Scenario: Remote fields change with uploaded-only work
- **GIVEN** an exact-owner private file has a durable upload receipt and no confirmed association ID
- **WHEN** the user accepts remote fields or preserves local fields against a new pending baseline
- **THEN** file, descriptor, order and upload receipt remain unchanged and no upload/association starts
- **AND** a later explicit eligible staged Save reuses that receipt through existing server replay

#### Scenario: Assets change without a field-token change
- **WHEN** complete fresh detail has the same field token but another association list
- **THEN** the editor uses that complete list for visible remote associations and qualified capacity
- **AND** it retains local-only work without truncation and does not reuse capacity from the older observation

#### Scenario: Reconciliation exceeds capacity
- **WHEN** current remote associations and retained pending local work exceed five
- **THEN** valid local work remains preserved and unavailable continuation has explicit local removal/recheck/return
- **AND** recovery makes no automatic deletion or server request to fit capacity

### Requirement: Contradicted association confirmation cannot recreate deleted work
A confirmed association receipt SHALL remain historical evidence when its ID is absent or contradicted in the latest complete remote detail. That item SHALL retain its private bytes and receipt but SHALL not continue through automatic replay or cleanup based only on old confirmation. Explicit exact local removal SHALL remain available without remote deletion or owner retirement.

#### Scenario: Confirmed row was removed while local cleanup failed
- **GIVEN** retained staged progress confirms association ID X and local descriptor removal previously failed
- **WHEN** a later complete remote observation omits X
- **THEN** recovery reports that item's association as unavailable and preserves its file and receipt
- **AND** accepting or preserving fields and later ordinary captured continuation neither reinsert X nor clear its association ID to manufacture new work

#### Scenario: Confirmed row contradicts exposed metadata
- **WHEN** complete detail carries the recorded ID with conflicting URL or dimensions
- **THEN** that item remains preserved and blocked for continuation without inferred receipt correction, upload or association

#### Scenario: Confirmed row still exists
- **WHEN** complete detail contains the confirmed ID and matching exposed URL/dimensions
- **THEN** it occupies one current capacity slot and eligible existing local cleanup requires no upload or association
- **AND** omitted MIME/duration do not establish full receipt equality for unrelated items

#### Scenario: Unknown association is not inferred from URL
- **GIVEN** an uploaded-only receipt has no confirmed association ID
- **WHEN** a remote row has a similar URL or dimensions
- **THEN** the client does not fabricate association confirmation from that partial comparison
- **AND** only explicit eligible existing exact-receipt replay can confirm the ambiguous association

#### Scenario: Final or missing parent retains bytes
- **WHEN** fresh recovery observes a final or missing parent or receives metadata conflict/unreadable progress
- **THEN** remote continuation remains unavailable with retained bytes/evidence and local removal/recheck/return
- **AND** recovery never deletes an owner, rolls back Cloudinary, resets confirmation or starts background replay

#### Scenario: Unknown association evidence cannot authorize historical cleanup
- **GIVEN** retained progress confirms an association but no complete current association observation is available
- **WHEN** another immediate or staged association is confirmed
- **THEN** that addition does not establish complete evidence or authorize cleanup of the historical item
- **AND** known absence or contradictory metadata for another historical item remains blocking; its bytes and receipt remain retained

#### Scenario: Newly confirmed association completes its own cleanup
- **WHEN** an explicitly admitted eligible association returns its own confirmed result and its receipt is persisted
- **THEN** that item may complete existing exact-owner local cleanup without another upload or association
- **AND** receipt persistence or descriptor-removal failure preserves its evidence and bytes for safe repair; after restart historical cleanup requires complete current evidence
