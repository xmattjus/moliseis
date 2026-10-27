# Admin Save Idempotency Delta

## Purpose

Provide server-authoritative replay for Admin Create and staged asset association without overwriting committed content or weakening existing authorization and capacity rules.

## ADDED Requirements

### Requirement: Admin Create replay is first write wins
Admin Create SHALL require a stable UUID-v4 scoped to the authenticated creating account. Concurrent or repeated requests with that key SHALL converge to the same committed submission. Replay SHALL return authoritative identity/current detail without changing fields, status, assets, timestamps or moderation effects.

#### Scenario: Concurrent same-key Create
- **GIVEN** two authorized requests carry the same account and UUID
- **WHEN** both attempt insertion concurrently
- **THEN** one row is committed and both successful outcomes identify that row

#### Scenario: Changed replay after moderation
- **GIVEN** a key already created a submission which was later accepted or rejected
- **WHEN** Create replays with different editable input
- **THEN** the original ID/current status is returned without rewriting or undoing moderation

#### Scenario: Create commits but response is lost
- **WHEN** the client explicitly retries the original key after an ambiguous response
- **THEN** the server resolves the already-created record instead of inserting a duplicate

### Requirement: Replay retains server-owned authorization
Every Admin request, including replay, SHALL authenticate and authorize current staff authority at the server boundary. Creator identity SHALL derive from the authenticated user. Privileged replay functions SHALL be unavailable to public, anonymous and ordinary authenticated direct callers. Public quota and submission semantics SHALL remain unchanged.

#### Scenario: Client supplies another creator
- **WHEN** a caller tries to select a different account through request data
- **THEN** it cannot redirect Create replay ownership or obtain authority over another account's key

#### Scenario: Staff authority is absent
- **WHEN** a revoked, anonymous or nonstaff caller requests replay
- **THEN** the server rejects the request without privileged write or replay data exposure

### Requirement: Staged association replay uses an exact uploaded receipt
For Admin staged Save, one parent plus identical canonical URL, dimensions, MIME and duration SHALL identify one association. Under parent serialization, matching replay SHALL return the existing lowest-ID match before pending/capacity rejection. Same URL with conflicting metadata SHALL fail without insertion. This contract SHALL NOT impose global URL uniqueness or alter Public batch behavior.

#### Scenario: Association response lost then parent moderated
- **GIVEN** the exact receipt was associated before its response was lost
- **WHEN** the same receipt replays after the parent became final
- **THEN** the existing association is returned without changing the final submission

#### Scenario: Concurrent same receipt at capacity
- **GIVEN** four associations exist and two requests carry the same new receipt
- **WHEN** they run concurrently
- **THEN** exactly one additional association is created and replay returns it rather than consuming a sixth slot

#### Scenario: Conflicting metadata or legacy duplicates
- **WHEN** the URL exists with different metadata or multiple identical legacy rows exist
- **THEN** conflicting metadata causes no insert, and exact replay returns the lowest matching row without legacy cleanup

### Requirement: New association and deletion preserve existing invariants
A missing replay match SHALL insert only for a pending parent with available capacity. Association and deletion SHALL serialize with other supported asset mutations. Intentional deletion SHALL not require a tombstone; later explicit association of the same receipt SHALL be evaluated as new work.

#### Scenario: Concurrent distinct fifth and sixth requests
- **WHEN** different replay and legacy association calls compete for the final slot
- **THEN** the database admits at most one new association and retains the maximum of five

#### Scenario: Replay after explicit deletion
- **WHEN** the old association was deliberately deleted and an authorized explicit request re-associates its receipt
- **THEN** pending and capacity checks apply before a new association is inserted

### Requirement: Upload and database confirmations remain separate
The client SHALL not treat a Cloudinary upload as a database association or claim an atomic transaction across the services. Ambiguous upload and association outcomes SHALL preserve distinct retry behavior and confirmed receipts.

#### Scenario: Upload succeeds but association fails
- **WHEN** the client has a confirmed upload receipt but database insertion fails or is ambiguous
- **THEN** the receipt remains reusable and remote association is not reported as confirmed until server replay or response establishes it

### Requirement: Conditional Update fences outstanding old writes
Admin Save Update SHALL require the exact DB-owned field-version token captured with its remote context, retain pending/provenance guards and reject a changed token without overwrite. Real field changes SHALL advance the token. Token precision SHALL survive transport and persistence. Read-back equality alone SHALL not be treated as proof that an old request settled.

#### Scenario: Old Update remains pending after restart
- **GIVEN** old Update A expects V and a process restart lost its HTTP completion
- **WHEN** explicit conditional Save B changes fields before A executes
- **THEN** B advances the field token and A cannot overwrite B with its old V

#### Scenario: No-op old Update races a new field Save
- **GIVEN** old A equals current remote fields at V
- **WHEN** guarded A and guarded changed B race in either order
- **THEN** no-op A cannot overwrite B after B changes the token and a blocked request settles as a typed conflict

#### Scenario: Changed token or incomplete legacy baseline
- **WHEN** input carries a stale token or restored history has no exact token
- **THEN** the stale write is rejected or fresh detail is required, without manufacturing a token from display time
