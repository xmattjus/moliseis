## ADDED Requirements

### Requirement: Immediate manual retry requires safe replay across the supported rollout
The Content Submission immediate-retry semantic SHALL mean that the user may safely execute the current manual retry action now. It SHALL NOT mean only that the technical cause may be transient or eventually recoverable. A structured error SHALL permit immediate retry only when the currently observable contract proves both that repeating the operation is appropriate and that repeating it is safe under every server generation supported by the released client.

The released client SHALL remain compatible with both the legacy non-idempotent `submit-content` implementation and the hardened idempotent implementation during the client-first rollout. While the client cannot determine which generation served a final request, it SHALL NOT expose immediate remote retry for any failure whose safety depends on hardened server-side idempotency. This includes `INTERNAL_ERROR`/500, legacy 500 outcomes, final-submit timeouts or other ambiguous transport failures, malformed acknowledgements, and unknown or mismatched outcomes. Classification SHALL NOT use `message`, `reasonPhrase`, `toString()`, raw response bodies, or localized text. No classification SHALL add an automatic request, a 409 category, a capability probe, or version negotiation.

#### Scenario: Legacy-compatible rollout blocks ambiguous remote replay
- **GIVEN** the client cannot determine whether the serving `submit-content` implementation is legacy or hardened
- **WHEN** a final remote request ends in a server or transport failure that does not prove whether remote commit occurred
- **THEN** immediate remote `Riprova` is unavailable, the current submission session remains intact, and the user can return to the form without executing another remote request

#### Scenario: Validation failure is not immediately repeated
- **WHEN** final submission returns `VALIDATION_ERROR` with HTTP 400
- **THEN** the structured API fields remain preserved and immediate manual retry is unavailable

#### Scenario: Authentication failure requires another recovery path
- **WHEN** final submission returns `UNAUTHORIZED` with HTTP 401
- **THEN** the structured API fields remain preserved and immediate manual retry is unavailable

#### Scenario: Method contract failure is not immediately repeated
- **WHEN** final submission returns `METHOD_NOT_ALLOWED` with HTTP 405
- **THEN** the structured API fields remain preserved and immediate manual retry is unavailable

#### Scenario: Rate limit does not create an immediate loop
- **WHEN** final submission returns `RATE_LIMIT_EXCEEDED` with HTTP 429
- **THEN** immediate manual retry is unavailable even though the condition may recover later, because the current action has no delay, cooldown, or `Retry-After` contract

#### Scenario: Current internal error is unsafe during coexistence
- **WHEN** final submission returns `INTERNAL_ERROR` with HTTP 500 while the released client must support the legacy server
- **THEN** immediate remote retry is unavailable because the pair does not identify the serving generation or prove that the legacy path did not commit

#### Scenario: Legacy persistence errors are unsafe to replay immediately
- **WHEN** final submission returns a legacy `RATE_LIMIT_READ_FAILED`, `RATE_LIMIT_UPDATE_FAILED`, `SUBMISSION_INSERT_FAILED`, `ASSET_INSERT_FAILED`, or `INTERNAL_ERROR` outcome
- **THEN** immediate remote retry is unavailable because legacy quota, submission, and asset effects are separate and the client identity is not an authoritative replay key

#### Scenario: Final-submit transport failure remains conservative
- **WHEN** `submit-content` ends with a timeout, client exception, socket exception, or equivalent ambiguous transport failure
- **THEN** immediate remote retry is unavailable because the client cannot distinguish failure before receipt from failure after legacy remote commit

#### Scenario: Malformed acknowledgement fails closed
- **WHEN** a successful final-submit status carries a missing, non-integer, zero, negative, or otherwise invalid `submission_id`
- **THEN** the response-format failure exposes no immediate retry and performs no hidden request

#### Scenario: Unknown final-submit outcome fails closed
- **WHEN** a final-submit API failure has a missing or unknown code, a mismatched status/code pair, or another unrecognized result
- **THEN** immediate manual retry is unavailable even if its message appears temporary

### Requirement: Preparation and upload failures remain boundary-specific and fail closed
Cloudinary preparation, direct binary upload, and final `submit-content` transport SHALL remain separate failure boundaries. The client SHALL NOT infer one boundary's retry policy from another boundary's exception classes.

Every current `prepare-cloudinary-upload` failure SHALL be non-retryable for the immediate submission action. This includes validation, authentication, method, request-size, configuration, unknown/mismatched failures, and `CLOUDINARY_PREPARATION_ERROR`/502. The 502 pair SHALL NOT be treated as transient evidence because the current server maps both operational failures and deterministic invalid prepared fields to it.

The shared direct Cloudinary client's existing bounded internal retry, content-addressed reuse, progress, and cancellation contracts SHALL remain unchanged. A terminal direct-upload failure SHALL fail closed for the progress-screen retry decision because the public task result does not expose a simple Content Submission-owned discriminator proving safe immediate replay. This change SHALL NOT make shared Cloudinary exceptions implement a Content Submission-specific contract and SHALL NOT wrap or refactor `ImageUploadTask` solely to classify a terminal failure.

#### Scenario: Preparation contract failures are not immediately retried
- **WHEN** preparation returns `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `REQUEST_TOO_LARGE`/413, or `CLOUDINARY_CONFIGURATION_ERROR`/500
- **THEN** the submission operation reports an ordinary non-retryable failure

#### Scenario: Ambiguous preparation 502 fails closed
- **WHEN** preparation returns `CLOUDINARY_PREPARATION_ERROR` with HTTP 502
- **THEN** immediate manual retry is unavailable because the observable pair does not distinguish an operational failure from deterministic invalid prepared fields

#### Scenario: Unknown preparation outcome fails closed
- **WHEN** preparation returns a missing, unknown, mismatched, malformed, or transport failure
- **THEN** immediate manual retry is unavailable without message or exception-string parsing

#### Scenario: Existing direct-upload handling remains internal
- **WHEN** the shared Cloudinary client encounters a direct-upload HTTP 5xx or streaming/body timeout
- **THEN** only its existing bounded internal retry policy applies and this change adds no progress-screen retry classification or task-wrapper behavior

#### Scenario: Terminal direct-upload failure is not elevated
- **WHEN** direct upload still returns an error after its existing internal handling, or terminates with another upload, socket, filesystem, format, validation, or cancellation error
- **THEN** the Content Submission progress flow fails closed without coupling shared Cloudinary infrastructure to feature-specific retry semantics

### Requirement: Immediate retry availability is derived from authoritative submission state
The Content Submission presentation boundary SHALL expose retry availability as a read-only value derived from the current submission Command result and confirmed-success finalization state. It SHALL NOT maintain an independently mutable retry flag. The value SHALL be false while the operation is idle, running, successful, or stopped with any ordinary failure. It SHALL be true only when the current operation is stopped with an error and confirmed remote success still requires local finalization.

#### Scenario: Idle, running, and success cannot retry
- **WHEN** the submission operation is idle, currently running, or completed successfully
- **THEN** immediate retry availability is false

#### Scenario: Ordinary failures cannot retry during this rollout
- **WHEN** the submission operation stops with any pre-acknowledgement local, upload, final-submit, malformed-response, transport, or unknown failure
- **THEN** immediate retry availability is false directly from the current Command and finalization state

#### Scenario: A new execution cannot retain stale retryability
- **WHEN** a finalization retry starts and the submission Command clears its previous result while entering the running state
- **THEN** immediate retry availability becomes false without synchronizing or clearing a second mutable flag

#### Scenario: Failed finalization remains immediately retryable
- **WHEN** remote success is confirmed, local finalization fails, and the submission operation is no longer running
- **THEN** immediate retry availability is true and executing the existing action invokes only identity-bound local finalization

### Requirement: Retry and recovery preserve submission lifecycle invariants
Classifying a failure, returning to the form, or exposing finalization retry SHALL NOT alter captured-attempt ownership, staged-asset ownership, Cloudinary reuse/deduplication, explicit clear/discard ownership, or the current submission identity lifecycle. An ordinary failure SHALL preserve the current logical session and `client_submission_id` without claiming that a later remote submission is deduplicated by every supported server. A finalization retry SHALL retain the acknowledged identity until successful local retirement and SHALL perform no checkpoint, asset upload, or remote submission.

#### Scenario: Non-retryable failure preserves recoverable work
- **WHEN** a pre-acknowledgement attempt fails and immediate retry is unavailable
- **THEN** classification and return-to-form do not clear the draft, delete staged assets, rotate identity, or prevent the existing edit and explicit-discard paths

#### Scenario: Return-to-form performs no replay
- **WHEN** the user leaves a non-retryable failed progress state for the form
- **THEN** the same session identity, draft fields, and staged assets remain available and no checkpoint, upload, or final-submit request is triggered by that navigation

#### Scenario: Finalization retry cannot resubmit remotely
- **WHEN** retry is available because confirmed remote success has incomplete local finalization
- **THEN** the existing action retries only matching-session local retirement and performs no request preparation, Cloudinary upload, remote submit call, session rotation before success, or premature draft clear

#### Scenario: Repeated finalization failure preserves ownership
- **WHEN** one or more local finalization retries fail before a later retry succeeds
- **THEN** the acknowledged identity and staged session remain owned and current until one successful retirement rotates identity exactly once

### Requirement: Final-submit retry relaxation is a separate future decision
The client SHALL retain the fail-closed final-submit policy after the hardened server is deployed until a separate reviewed change establishes that the hardened idempotent implementation is guaranteed for all supported clients or defines another reliable capability signal. This change SHALL NOT automatically enable retry based on deployment timing or repository source state.

#### Scenario: Hardened deployment does not silently change released-client policy
- **WHEN** the hardened idempotent server becomes deployed after client adoption
- **THEN** this client's `INTERNAL_ERROR`/500 and ambiguous final-submit transport outcomes remain non-retryable until a separate specification and implementation deliberately relax them
