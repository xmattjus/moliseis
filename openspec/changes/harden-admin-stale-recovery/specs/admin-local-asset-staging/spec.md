# Admin local asset staging delta

## ADDED Requirements

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
