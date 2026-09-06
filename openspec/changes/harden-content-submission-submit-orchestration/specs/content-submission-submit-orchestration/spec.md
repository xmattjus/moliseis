## Purpose

Define one durable, immutable, and retry-safe public Content Submission attempt from local checkpoint through asset upload, Edge acknowledgement, and successful local session retirement.

## ADDED Requirements

### Requirement: Explicit final submission contract
The public Content Submission contract SHALL name the final whole-submission operation `submit` and SHALL accept the stable client submission identity, immutable submission content, and ordered uploaded asset metadata as distinct inputs. Binary asset upload SHALL remain separately exposed as `uploadImageTask`. Final submission SHALL report success or failure without exposing the backend row identifier as a new domain result. The former final whole-submission name `upload` SHALL not be retained unless an external compatibility obligation is verified.

#### Scenario: Caller submits one logical attempt
- **WHEN** a caller invokes final submission with a client identity, immutable content, and ordered uploaded assets
- **THEN** the final Content Submission boundary uses those three inputs and reports success or failure without returning a backend row identifier

#### Scenario: Binary upload remains independently addressable
- **WHEN** a caller needs to upload one local asset to Cloudinary
- **THEN** it continues to use `uploadImageTask` without invoking or depending on final whole-submission

#### Scenario: Old final-operation name is not retained speculatively
- **WHEN** every verified production consumer is migrated to `submit`
- **THEN** the public repository exposes no final whole-submission `upload` alias

### Requirement: Public submit wire envelope
The final `submit-content` request SHALL contain exactly the top-level keys `client_submission_id`, `category`, `city`, `name`, `description`, `description_delta`, `latitude`, `longitude`, `address`, `start_date`, `end_date`, `user_email`, `user_name`, and `assets`. It SHALL carry the supplied client identity unchanged; represent nullable content values as null; serialize every non-null event instant as a UTC ISO-8601 string; preserve the existing immutable JSON-compatible description Delta structure; and preserve uploaded asset order. Each nested asset SHALL use the existing wire fields `url`, `width`, `height`, nullable `mime_type`, and nullable `duration_seconds`. Authenticated database ownership SHALL continue to be derived server-side from the request's bearer identity rather than from a client-supplied `user_id`.

#### Scenario: Complete request uses the public wire contract
- **WHEN** final submission is invoked with content, event instants, and uploaded assets
- **THEN** exactly one `submit-content` request carries every allowlisted top-level field, UTC temporal values, the unchanged description Delta, and asset metadata in supplied order

#### Scenario: Nullable values remain explicit
- **WHEN** an optional content, temporal, location, MIME, or duration value is absent
- **THEN** its corresponding allowlisted wire field is null rather than synthesized from unrelated local state

#### Scenario: Persistence and lifecycle fields are excluded
- **WHEN** the final request body is constructed
- **THEN** it contains no `user_id`, `created_at`, `modified_at`, `accepted_terms`, ObjectBox entity ID, checkpoint metadata, or other local lifecycle state

### Requirement: Submit acknowledgement and errors
Each final-submission call SHALL make exactly one `submit-content` request and SHALL report success only when the response is an object containing a positive integer `submission_id`; additional response keys SHALL be accepted. A missing, non-integer, zero, negative, or otherwise invalid identifier SHALL be reported as a response-format failure. A backend Function failure SHALL be surfaced as a public Content Submission-specific error that always preserves the HTTP status. When failure details are a map, a non-empty `code` SHALL be preserved and a non-empty `message` SHALL be used. When failure details are instead a non-empty string, that string SHALL be used as the message. Otherwise, a non-empty reason phrase SHALL be used, followed by a stable public Content Submission fallback message. Other client or transport failures SHALL be reported as errors. No failure or malformed response SHALL trigger an automatic second request.

#### Scenario: Positive acknowledgement succeeds
- **WHEN** the Edge Function responds with a positive integer `submission_id`, with or without additional metadata
- **THEN** final submission returns success without exposing the identifier through the domain result

#### Scenario: Malformed success envelope fails closed
- **WHEN** the response is not an object or its `submission_id` is missing, non-integer, zero, or negative
- **THEN** final submission reports a response-format failure and performs no hidden retry

#### Scenario: Map Function details preserve fields
- **WHEN** the Edge Function responds with an HTTP failure carrying non-empty `code` and `message` details
- **THEN** the returned public API exception preserves the HTTP status, code, and message and the failure is logged once

#### Scenario: String Function details provide the message
- **WHEN** the Edge Function responds with an HTTP failure whose details are a non-empty string rather than a map
- **THEN** the returned public API exception preserves the HTTP status and uses that string as its message

#### Scenario: Missing details use stable fallbacks
- **WHEN** Function failure details do not provide a usable message
- **THEN** final submission uses a non-empty reason phrase when available and otherwise uses the stable public Content Submission fallback message while preserving HTTP status

#### Scenario: Generic transport failure is not retried
- **WHEN** a non-Function client or transport exception occurs
- **THEN** that exception is logged and returned as an error after one invocation attempt

### Requirement: Durable submission attempt
Before any remote side effect begins, the system SHALL establish one submission attempt from an immutable capture of the current draft, its stable client identity, and ordered staged-asset membership. The exact captured draft SHALL be durably checkpointed before the first asset upload or final backend request. Remote work SHALL be authorized only after submission eligibility and durable ownership are established and that checkpoint succeeds. A snapshot already known to be durable SHALL not require a redundant save. This guarantee SHALL apply to direct submission as well as the existing UI transition, whose separate pre-submit checkpoint remains in force. Existing submission eligibility and feedback rules SHALL be preserved without adding accepted-terms, form, category, geolocation, description-length, or email-policy validation.

#### Scenario: Dirty direct submission checkpoints before the first asset
- **WHEN** a dirty valid draft with staged assets is submitted directly
- **THEN** the exact captured draft is durably saved before the first asset upload begins

#### Scenario: No-asset submission checkpoints before final request
- **WHEN** a dirty valid draft with no staged assets is submitted directly
- **THEN** the exact captured draft is durably saved before final submission is invoked

#### Scenario: Known durable snapshot avoids a redundant save
- **WHEN** the captured draft structurally equals the known durable checkpoint baseline
- **THEN** preparation succeeds without another draft save and may proceed to remote work

#### Scenario: Failed checkpoint prevents all remote work
- **WHEN** persistence of the captured submission snapshot fails
- **THEN** submission reports that error without starting an asset upload or final backend request, and the current identity and dirty-state relationship remain unchanged

#### Scenario: Unknown persisted ownership prevents submission
- **WHEN** durable draft ownership cannot be established during preparation
- **THEN** submission returns the retained persistence error without checkpointing a fresh identity or beginning remote work

### Requirement: Remote work uses captured state
Every remote operation for a submission attempt SHALL use only its captured draft, stable client identity, and ordered asset membership, even if current local state changes afterward. Asset uploads SHALL occur one at a time in captured order, successful asset metadata SHALL retain that order, and the first asset-upload failure SHALL stop the attempt before the final backend request. Later local asset changes SHALL not add or remove entries from the in-flight attempt. Remote failure handling SHALL not delete or roll back assets already uploaded to Cloudinary.

#### Scenario: Draft changes while checkpoint is pending
- **WHEN** draft A is captured and its save remains pending, live draft B replaces it, persistence of A succeeds, and the later remote attempt fails
- **THEN** remote work uses A and A's client identity while B remains current and dirty relative to durable baseline A

#### Scenario: Draft changes during Cloudinary upload
- **WHEN** an asset upload for a prepared attempt remains pending and the live form is edited
- **THEN** the final submission content is still built from the draft captured before remote work

#### Scenario: Asset membership changes during remote work
- **WHEN** the live staged-asset list changes after preparation
- **THEN** the in-flight attempt neither adds nor removes payload entries based on that later membership and processes only its captured assets in captured order, reporting the ordinary first-upload error if a captured source independently becomes unavailable

#### Scenario: First asset failure stops final submission
- **WHEN** any sequential Cloudinary upload returns an error
- **THEN** submission returns that error, sends no final request, preserves local staged sources, and retains the same client identity for retry

#### Scenario: Final request failure preserves retryable session
- **WHEN** every asset upload succeeds but final submission returns an error
- **THEN** local finalization does not begin, staged sources and live session remain available, and a later attempt uses the same client identity

### Requirement: Finalization-only retry after success
After valid final acknowledgement, the system SHALL record confirmed remote success before attempting the existing persistence-first local retirement. A failed local retirement SHALL keep the completed session's identity current and its finalization recoverable. Every later retry for that confirmed submission SHALL perform only local finalization: it SHALL perform no new attempt preparation, draft checkpoint, asset upload, or final backend request. One successful finalization SHALL retire the old session and create exactly one different valid fresh client identity.

#### Scenario: Local finalization failure does not resend
- **WHEN** final submission succeeds and one or more local clear attempts fail
- **THEN** exactly one final backend request has been sent, finalization remains recoverable, and the old client identity remains current

#### Scenario: Finalization-only retry rotates once
- **WHEN** a later finalization-only retry succeeds
- **THEN** no remote work is repeated, the old persisted/staged session is retired through the existing clear policy, and exactly one fresh identity becomes current

#### Scenario: Final request failure does not enter finalization
- **WHEN** final submission returns an error or malformed acknowledgement
- **THEN** successful local session retirement does not start and the same logical session remains retryable

### Requirement: Client identity is not idempotency
The deployed `submit-content` boundary SHALL continue to accept an otherwise valid request carrying a UUID-v4-compatible `client_submission_id`. This change SHALL NOT require the backend to persist or act on that field, and sending it SHALL NOT be represented as server-side deduplication, definitive acknowledgement recovery, or idempotency.

#### Scenario: Submission boundary accepts client identity
- **WHEN** an otherwise valid request includes a UUID-v4-compatible `client_submission_id`
- **THEN** the submission boundary accepts the request even though backend processing need not expose or persist the field

#### Scenario: Backend idempotency remains deferred
- **WHEN** this capability is completed
- **THEN** no production backend component is claimed to consume the client identity or prevent duplicate database submissions

### Requirement: Subplan completion is not release readiness
Completion of this capability SHALL be reported only as Content Submission Hardening Subplan 4. Ambiguous remote acknowledgement and server-side idempotency SHALL remain explicit open hardening work, and the Content Submission feature SHALL NOT be declared globally release-proof solely because this capability passes.

#### Scenario: Subplan verification passes
- **WHEN** every requirement and regression in this capability is verified
- **THEN** the result is reported as Subplan 4 complete and ready for the next hardening subplan rather than as whole-feature release readiness
