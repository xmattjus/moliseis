## Purpose

Make each authenticated public Content Submission commit atomic and idempotent so a retry can recover an ambiguous acknowledgement without duplicating content, assets, or quota consumption.

## ADDED Requirements

### Requirement: Authenticated client identity is the idempotency key
Every public Content Submission request SHALL carry a canonical lowercase UUID-v4-compatible `client_submission_id`. The submission boundary SHALL authenticate and fully validate both first attempts and replays before privileged database work, persist the identity with the resulting submission, and scope uniqueness to the authenticated user identity established from the bearer token. An existing key SHALL NOT bypass request validation, and a request SHALL NOT supply or override its database `user_id`. Legacy rows and non-public/Admin insertion paths MAY retain a null client identity, but the hardened public path SHALL NOT create a new row without one.

#### Scenario: Valid identity is persisted for the authenticated user
- **WHEN** an authenticated public request carries a canonical UUID-v4-compatible client identity and creates a submission
- **THEN** the resulting row stores that identity together with the server-derived authenticated user ID

#### Scenario: Missing or malformed identity fails before a write
- **WHEN** a public request omits the client identity or supplies a non-canonical, non-v4, uppercase, or otherwise malformed value
- **THEN** validation fails before quota, submission, or asset state is written

#### Scenario: Existing identity does not bypass request validation
- **WHEN** a request carries an already committed client identity but another request field is invalid
- **THEN** the boundary rejects the malformed request before invoking privileged persistence or returning the replay acknowledgement

#### Scenario: Same identity is independent across users
- **WHEN** two different authenticated users submit the same client identity
- **THEN** each user may create one independently owned submission without learning or replaying the other user's result

### Requirement: First committed submission wins
For one authenticated user and client identity, the first transaction that commits SHALL establish the immutable remote submission, its asset set, and its positive backend identifier. Every later otherwise-valid authenticated request with that same ownership key SHALL return the original identifier without inserting, updating, or deleting submission or asset data, even when later request content differs. A replay SHALL NOT turn a pending, accepted, or rejected submission back into another state.

#### Scenario: Sequential equivalent retry replays the acknowledgement
- **WHEN** the same authenticated user repeats an already committed request with the same client identity
- **THEN** the boundary returns the original positive submission identifier and creates no additional submission or asset rows

#### Scenario: Changed retry cannot overwrite the committed payload
- **WHEN** a later otherwise-valid request reuses a committed client identity with changed content or assets
- **THEN** the original submission and asset rows remain unchanged and the original identifier is returned

#### Scenario: Moderated submission still replays
- **WHEN** a committed submission has since been accepted or rejected and its original client identity is retried by the same user
- **THEN** the existing identifier is returned without changing moderation or publication state

### Requirement: Submission persistence is one atomic operation
Quota accounting, submission creation, and attachment association for a new idempotency key SHALL commit as one database transaction. Any database error or rejected persistence invariant SHALL leave all three areas unchanged. The operation SHALL reuse the existing authoritative maximum-five asset invariant, preserve the established public-field mapping including storing `unknown` when the validated category is null, and SHALL not expose a partial submission as a successful acknowledgement.

#### Scenario: Asset persistence failure rolls back the submission
- **WHEN** attachment persistence fails after submission creation has begun
- **THEN** no submission row, asset row, or quota increment from that attempt is committed

#### Scenario: Submission persistence failure does not consume quota
- **WHEN** a new logical submission cannot be committed
- **THEN** the user's quota state remains as it was before the attempt

#### Scenario: Successful no-asset submission commits atomically
- **WHEN** a valid new request contains no assets
- **THEN** its submission and one quota consumption commit together and a positive identifier is returned

#### Scenario: Null category preserves the existing database default
- **WHEN** a valid new public request carries a null category
- **THEN** the committed submission stores `unknown` exactly as the existing public submission path does

### Requirement: Idempotent replay and quota are concurrency safe
Database arbitration SHALL serialize quota decisions for each authenticated user while allowing unrelated users to proceed independently. It SHALL preserve the existing fixed 24-hour window anchored by `window_started_at`: a window remains active only while its start is later than the transaction time minus 24 hours, and an expired window resets for the next new submission. Concurrent requests for one user and client identity SHALL create at most one submission and consume quota once. Concurrent new identities SHALL never make the committed count exceed five in the active window. Replays SHALL succeed without creating, resetting, or incrementing quota state even when the user is currently at the limit.

#### Scenario: Concurrent duplicate requests converge
- **WHEN** two requests for the same authenticated user and client identity race before either receives an acknowledgement
- **THEN** exactly one submission and one asset set are committed, both calls resolve to the same positive identifier, and quota increases once

#### Scenario: Concurrent distinct requests respect the last quota slot
- **WHEN** one user has four committed submissions in the active window and two different new client identities race
- **THEN** at most one new submission commits, the other request is rate-limited, and the committed count does not exceed five

#### Scenario: Replay at the limit remains successful
- **WHEN** a user at the active quota limit retries a previously committed client identity
- **THEN** the existing identifier is returned without another quota increment or a rate-limit failure

### Requirement: Created and replayed acknowledgements resolve the same client session
The public boundary SHALL distinguish a newly created commit from an idempotent replay for HTTP and diagnostic purposes while returning the same positive `submission_id` contract in both cases. A newly created submission SHALL use HTTP 201 and a replay SHALL use HTTP 200. Both SHALL be successful acknowledgements to the existing client repository, which SHALL not expose the backend identifier or require a new result variant. A client-side transport failure SHALL not trigger a hidden automatic retry; a later explicit retry with the same identity SHALL recover the committed acknowledgement if the first transaction succeeded.

#### Scenario: New commit returns created acknowledgement
- **WHEN** the first request for an authenticated client identity commits successfully
- **THEN** the boundary returns HTTP 201 with its positive submission identifier

#### Scenario: Ambiguous acknowledgement is recovered by retry
- **WHEN** the server commits a submission but the client does not receive the response and later explicitly retries the same identity
- **THEN** the retry returns HTTP 200 with the original positive identifier and the client follows its existing successful local-finalization path

#### Scenario: Existing client contract accepts replay metadata
- **WHEN** a replay response includes the positive identifier and additional replay metadata
- **THEN** the current public repository treats it as success without changing `Result<void>`, Command, Provider, ViewModel, progress, or navigation contracts

### Requirement: Privileged submission persistence remains server-only
The atomic submission operation SHALL be callable only by the server-side service role. Anonymous and authenticated database roles SHALL have no direct execute permission, existing deny-by-default table RLS SHALL not be relaxed, and every relation access SHALL remain explicitly scoped. Failures and replay diagnostics SHALL not log authored content, contact fields, bearer credentials, local paths, or the client identity.

#### Scenario: Direct public execution is denied
- **WHEN** an anonymous or authenticated database role attempts to invoke the atomic submission operation directly
- **THEN** execution is denied and no quota, submission, or asset state changes

#### Scenario: Edge invocation derives ownership from authentication
- **WHEN** the authenticated Edge boundary invokes the privileged operation
- **THEN** it passes the verified user's identifier as ownership and ignores any attempted body ownership field

#### Scenario: Operational diagnostics contain no submission payload
- **WHEN** creation, replay, rate limiting, or persistence failure is recorded
- **THEN** diagnostics contain only safe operation/outcome metadata and no authored content, contact information, credentials, client identity, or local path

### Requirement: Subplan 5 completion is bounded
Completion SHALL be reported as Content Submission Hardening Subplan 5: server-side idempotency and atomic acknowledgement recovery. It SHALL NOT claim Cloudinary rollback/deletion, persistent background submission, multi-draft support, guaranteed cleanup of every best-effort local staging residue, or whole-feature release proof unless those concerns are separately specified and verified.

#### Scenario: Subplan verification passes
- **WHEN** every requirement and regression in this capability passes
- **THEN** the result is reported as Subplan 5 complete with any remaining non-idempotency hardening limitations still explicit
