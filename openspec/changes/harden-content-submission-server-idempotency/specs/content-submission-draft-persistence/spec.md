## MODIFIED Requirements

### Requirement: Each logical local submission has a stable client identity
The local draft-session lifecycle SHALL give every fresh logical Content Submission session one secure-random, UUID-v4-compatible `clientSubmissionId` and SHALL persist it with the draft when that session is checkpointed. The submission repository SHALL propagate the supplied identity and SHALL NOT generate or replace it. The identifier SHALL remain distinct from the fixed ObjectBox entity ID and any backend row ID, and SHALL remain unchanged throughout edits, local checkpoints, checkpoint failures, Cloudinary failures, final-submission failures, local-finalization retries, process restart, and valid draft recovery. Creating a session solely to open an untouched form SHALL NOT persist the identifier. Every final public submission request SHALL carry that exact value as `client_submission_id`. The backend SHALL persist it as the authenticated user's idempotency key so retry after an ambiguous acknowledgement resolves to the first committed submission without creating a duplicate. The identifier SHALL rotate only after successful local retirement creates a fresh logical session.

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
- **WHEN** the hardened remote submit flow constructs or sends a submission
- **THEN** its established content and asset fields and server-owned authenticated user identity remain unchanged while the request additionally carries the same local session identity as `client_submission_id`

#### Scenario: Final submission carries the stable identity
- **WHEN** the client sends the final public submission request for a prepared logical session
- **THEN** the repository propagates that session's exact `clientSubmissionId` as `client_submission_id` without generating a replacement or sending it as an authenticated user ID or backend row ID

#### Scenario: Retryable failures retain the identity
- **WHEN** checkpointing, Cloudinary upload, final submission, acknowledgement delivery, or local finalization fails retryably
- **THEN** every later remote attempt or finalization-only retry for that logical session retains the same client identity

#### Scenario: Successful retirement rotates the identity once
- **WHEN** the backend has created or replayed a valid acknowledgement and local session retirement later succeeds
- **THEN** the completed identity is retired and exactly one different valid identity represents the fresh session

#### Scenario: Client identity does not yet guarantee backend deduplication
- **WHEN** only the Subplan 4 compatibility-field behavior is deployed
- **THEN** the client does not infer that the field was persisted or that duplicate final submissions are prevented

#### Scenario: Client identity prevents duplicate backend submissions
- **WHEN** Subplan 5 is deployed and the same authenticated user retries a final request carrying an identity that has already committed
- **THEN** the backend returns the original submission identifier without creating another submission, asset set, or quota charge
