## ADDED Requirements

### Requirement: Admin editor resolution retains admission-time source evidence

Reject, Promote, Link and Apply SHALL preserve their distinct semantics and capture the submission identity, target, source acknowledgement and shown source hash for the admitted attempt. Existing Pending, loaded, clean, category and temporal guards SHALL remain. Backend locks, authorization, idempotency and validation SHALL remain authoritative.

#### Scenario: Acknowledgement changes after admission
- **WHEN** a resolution is admitted with acknowledgement for displayed hash Y and checkbox state subsequently changes
- **THEN** the admitted request still carries exactly its captured acknowledgement and Y
- **AND** source drift is decided authoritatively by the backend

#### Scenario: Distinct mutation semantics
- **WHEN** Reject, Promote, Link or Apply succeeds or returns an idempotent same-target resolution
- **THEN** the editor preserves its exact result and respective rejected, promoted, linked or applied meaning
- **AND** it does not replay the mutation or fabricate Event/media writes in Flutter

#### Scenario: Target change during resolution
- **WHEN** a target change or competing mutation is attempted while an admitted resolution is pending
- **THEN** it cannot overwrite or reinterpret that resolution's identity, target or preview payload

### Requirement: Admin editor Apply retains exact preview evidence

Apply SHALL use a current target-compatible preview and send its original opaque submission and Event token strings unchanged. Dirty, source or target revision changes SHALL invalidate readiness. Token-conflict errors SHALL require a fresh preview before another Apply; server-authoritative replay semantics SHALL remain unchanged.

#### Scenario: Token conflict
- **WHEN** Apply returns EVENT_CHANGED or SUBMISSION_CHANGED
- **THEN** specific feedback remains visible and the obsolete preview no longer enables another Apply
- **AND** explicit preview reload is required without client token rewriting or an automatic mutation retry

#### Scenario: Exact microsecond token
- **WHEN** a preview contains a token with database microsecond precision or a non-normalized timestamp representation
- **THEN** Apply sends the identical string without parsing, timezone conversion, ordering or substituting a newer token

### Requirement: Admin editor resolution refresh preserves original outcome and order

For external resolution success or SOURCE_CHANGED, the editor SHALL revoke acknowledgement and preview, refresh the original submission, then fetch a returned follow-up if present. Expected refresh errors SHALL retain prior data and original mutation outcome. Revocation SHALL stop later phases. Raw private refresh failures SHALL remain one outer runtime failure without implying remote rollback.

#### Scenario: Source changed while resolving
- **WHEN** a resolution returns SOURCE_CHANGED
- **THEN** acknowledgement and preview are revoked and current original-submission detail is reloaded before renewed explicit acknowledgement
- **AND** the original source-change failure is not converted into success

#### Scenario: Follow-up after successful handling
- **WHEN** successful handling returns follow-up pending ID P
- **THEN** original detail refresh precedes the P lookup
- **AND** P remains follow-up information without replacing the route's submission identity

#### Scenario: Expected detail or follow-up read failure
- **WHEN** an expected read failure occurs after successful remote resolution
- **THEN** the original mutation success is retained, unavailable read data is not invented and remaining authorized follow-up lookup still occurs after the original detail attempt

#### Scenario: Raw read failure after commit
- **WHEN** a private refresh throws after the remote mutation may have committed
- **THEN** that original runtime failure is reported once by the outer operation, later phases stop and the editor neither automatically retries the mutation nor claims rollback

### Requirement: Admin editor KeepCurrent owns one atomic group workflow

KeepCurrent SHALL accept only a group from the current preview, copy its complete current Event group, save through the ordinary editor persistence boundary, then preview the persisted state. Its internal phases SHALL share the accepted outer authority without self-rejection or independent Save navigation. Failure and revocation SHALL stop subsequent phases without erasing newer data.

#### Scenario: Save then preview under outer ownership
- **WHEN** KeepCurrent is accepted for a current description, location, schedule, name or category group
- **THEN** all fields of that group are copied together and saved once
- **AND** successful Save is followed by one current preview despite the outer operation being busy
- **AND** no internal Save completion closes the route

#### Scenario: Failed Save or obsolete group
- **WHEN** its Save returns an expected failure or an old-preview group callback is invoked
- **THEN** no stale preview or misleading outer success is published
- **AND** copied unsaved fields remain dirty after failed Save, while an obsolete group starts no persistence

#### Scenario: Dispose between phases
- **WHEN** the owner is revoked while KeepCurrent's Save is pending
- **THEN** the already-started request may settle privately but no later preview or public synthetic success occurs

### Requirement: Admin editor assets reflect confirmed persistence and real cancellation limits

Asset addition SHALL retain persisted Pending eligibility, capacity and picker-to-upload-to-association order. Deletion SHALL require owned asset identity. Local lists SHALL change only on confirmed repository success. Owner revocation SHALL cancel the active upload task once and prevent unstarted phases without claiming cancellation of remote association or deletion.

#### Scenario: Picker cancelled or upload fails
- **WHEN** the picker returns no image or the upload returns an expected failure
- **THEN** no association request starts and the confirmed asset list remains unchanged
- **AND** live picker cancellation is a successful no-op while upload failure retains its original expected error

#### Scenario: Dispose during upload
- **WHEN** the owner is revoked while its upload task remains active
- **THEN** that task is cancelled once and any late result cannot start an association or publish an asset

#### Scenario: Dispose during remote asset persistence
- **WHEN** revocation occurs after association or deletion starts
- **THEN** the remote mutation may still commit while no later local list update, feedback or navigation occurs
- **AND** the editor does not describe that transaction as rolled back or guaranteed cancelled
