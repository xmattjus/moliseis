## Purpose

Provide deterministic local persistence, recovery, dirty-state, identity, and discard guarantees for one logical Content Submission draft session.

## ADDED Requirements

### Requirement: Draft mutations require an explicit checkpoint to persist
An effective Content Submission form mutation SHALL update and emit the in-memory draft without immediately or eventually writing local draft storage. The system SHALL provide one explicit, awaitable ordinary checkpoint operation that captures the current immutable draft snapshot, skips persistence when that snapshot equals the checkpoint baseline, awaits the existing local draft save boundary, and returns its `Result<void>` outcome. On success, the checkpoint baseline SHALL advance to the captured snapshot that was written; on failure, it SHALL remain unchanged.

#### Scenario: Form mutation does not persist implicitly
- **WHEN** a form setter makes an effective change and execution advances beyond the former three-second autosave interval
- **THEN** the emitted in-memory state contains the change, the session is dirty, and local draft save has not been called

#### Scenario: Explicit checkpoint persists the captured snapshot
- **WHEN** a dirty session explicitly awaits a checkpoint and local persistence succeeds
- **THEN** exactly one save contains the captured draft content and client submission identity, the successful result is returned, and that persisted snapshot becomes the checkpoint baseline

#### Scenario: Clean checkpoint is a no-op
- **WHEN** the current snapshot already equals the checkpoint baseline and a checkpoint is requested
- **THEN** the operation returns success without calling local draft save

#### Scenario: Failed checkpoint preserves the previous baseline
- **WHEN** a dirty snapshot is checkpointed and local persistence returns an error
- **THEN** the same error result is returned, no checkpoint baseline is advanced, and the current session remains dirty with the same client submission identity

#### Scenario: Mutation during checkpoint remains unsaved
- **WHEN** snapshot A starts checkpointing, the in-memory draft changes to snapshot B before A finishes, and persistence of A succeeds
- **THEN** A becomes the checkpoint baseline, B remains the current in-memory snapshot, and the session remains dirty

### Requirement: Dirty state is derived from structural draft snapshots
The system SHALL expose `hasUnsavedChanges` as structural inequality between the current immutable draft snapshot and its checkpoint baseline. The comparison SHALL include all persisted draft content and `clientSubmissionId`; individual setters SHALL NOT maintain a separate mutable dirty flag. A fresh session, a valid recovered session, and a newly created session after successful discard SHALL establish their current snapshot as the clean baseline.

#### Scenario: Fresh session starts clean without persistence
- **WHEN** a genuinely new Content Submission session is created
- **THEN** its current snapshot equals its checkpoint baseline, `hasUnsavedChanges` is false, and no local draft write occurs

#### Scenario: Effective mutation makes the session dirty
- **WHEN** a setter changes any structurally compared draft value
- **THEN** the current snapshot differs from its checkpoint baseline and `hasUnsavedChanges` is true

#### Scenario: Semantically unchanged setter preserves dirty state
- **WHEN** a setter produces a snapshot structurally equal to the current snapshot
- **THEN** `hasUnsavedChanges` retains the value implied by comparison with the existing checkpoint baseline and no persistence occurs

#### Scenario: Successful checkpoint makes only its matching snapshot clean
- **WHEN** a checkpoint succeeds and the current snapshot still equals the snapshot that was persisted
- **THEN** `hasUnsavedChanges` becomes false

### Requirement: Each logical local submission has a stable client identity
Every fresh logical Content Submission session SHALL receive one locally generated, secure-random, UUID-v4-compatible `clientSubmissionId`. The identifier SHALL remain distinct from the fixed ObjectBox entity ID and SHALL remain unchanged throughout edits, local checkpoints, checkpoint failures, retries, process restart, and valid draft recovery. Creating a session solely to open an untouched form SHALL NOT persist the identifier. The identifier SHALL remain local to this capability and SHALL NOT alter remote submission payloads, Supabase contracts, or finalization behavior.

#### Scenario: Fresh identity is valid and not persisted by creation
- **WHEN** a fresh session is created and no effective form mutation or explicit persistence action occurs
- **THEN** it has a UUID-v4-compatible client submission identity, starts clean, and performs no local or remote write

#### Scenario: Identity survives edits and repeated checkpoint attempts
- **WHEN** one logical session is edited and undergoes successful checkpoints, failed checkpoints, or retry checkpoints
- **THEN** every in-memory and persisted snapshot for that session carries exactly the identity generated when the session began

#### Scenario: Client identity is not an ObjectBox record key
- **WHEN** the logical session is saved repeatedly
- **THEN** the existing single-draft record is replaced using the fixed local entity strategy while `clientSubmissionId` remains persisted as draft data

#### Scenario: Remote submission remains unchanged
- **WHEN** the existing remote submit flow constructs or sends a submission during this change
- **THEN** it does not add `clientSubmissionId` or `client_submission_id` to a remote model, request, RPC, Edge Function, or database write

### Requirement: Valid persisted draft state and identity recover together
Initialization SHALL use the existing local draft load boundary. When a valid persisted draft is returned, the system SHALL restore its content and exact `clientSubmissionId`, establish that recovered snapshot as the checkpoint baseline, expose a clean session, and perform no automatic persistence. A persisted row without a valid client submission identity is unsupported legacy data and SHALL fall back without crashing to a fresh clean session with a new identity; recovery SHALL NOT migrate, backfill, delete, or automatically rewrite that row.

#### Scenario: Valid draft recovery is clean and non-writing
- **WHEN** initialization loads a valid persisted draft with a known client submission identity
- **THEN** the exact content and identity are restored together, `hasUnsavedChanges` is false, and local draft save is not called

#### Scenario: Recovered identity continues across later checkpoints
- **WHEN** a recovered session is edited and explicitly checkpointed
- **THEN** the checkpoint writes the recovered client submission identity rather than generating a replacement

#### Scenario: Legacy row falls back safely
- **WHEN** initialization encounters an otherwise readable fixed-ID draft row whose client submission identity is absent or invalid
- **THEN** initialization completes without exposing the legacy content as a current session, creates a fresh clean session with a new valid identity, and performs no save, clear, migration, or backfill

#### Scenario: Next dirty checkpoint replaces unsupported legacy shape
- **WHEN** the fresh fallback session is effectively edited and explicitly checkpointed after unsupported legacy recovery
- **THEN** the normal fixed-ID save writes the current draft shape and its new identity without a special migration path

### Requirement: Explicit discard retires a session only after persisted clear succeeds
An explicit discard SHALL await the existing local draft clear boundary before abandoning the current in-memory submission. Only a successful clear SHALL reset form state and selected in-memory assets, clear transient validation state, retire the old client submission identity, create a fresh identity, and establish the fresh empty snapshot as clean. A failed clear SHALL return the repository error and preserve the current form state, assets, checkpoint baseline, dirty state, and client submission identity.

#### Scenario: Successful discard clears before rotating identity
- **WHEN** discard is requested and local draft clear remains pending
- **THEN** the current form, assets, dirty state, and identity remain unchanged until clear succeeds

#### Scenario: Successful discard creates a fresh clean session
- **WHEN** local draft clear succeeds
- **THEN** the persisted fixed-ID draft is absent before the old identity is retired, the in-memory form and assets are empty, a different valid identity represents the new session, and `hasUnsavedChanges` is false

#### Scenario: Failed discard preserves the current session
- **WHEN** local draft clear returns an error
- **THEN** discard returns that error, the current form and assets remain available, the client submission identity does not rotate, and dirty state remains derived from the unchanged current snapshot and checkpoint baseline

#### Scenario: Clear removes draft content and identity together
- **WHEN** a persisted current-format draft is successfully discarded and local storage is loaded afterward
- **THEN** neither its draft content nor its client submission identity is returned
