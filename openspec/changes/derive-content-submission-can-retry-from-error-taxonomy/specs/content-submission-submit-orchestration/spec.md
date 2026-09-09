## MODIFIED Requirements

### Requirement: Submit acknowledgement and errors
Each final-submission call SHALL make exactly one `submit-content` request and SHALL report success only when the response is an object containing a positive integer `submission_id`; additional response keys SHALL be accepted. A missing, non-integer, zero, negative, or otherwise invalid identifier SHALL be reported as a response-format failure. A backend Function failure SHALL be surfaced as a public Content Submission-specific error that always preserves the HTTP status. When failure details are a map, a non-empty `code` SHALL be preserved and a non-empty `message` SHALL be used. When failure details are instead a non-empty string, that string SHALL be used as the message. Otherwise, a non-empty reason phrase SHALL be used, followed by a stable public Content Submission fallback message. Other client or transport failures SHALL be reported as errors. A positively identified transient transport failure SHALL be normalized into a Content Submission-specific failure that retains the original exception as its diagnostic cause and exposes the domain retry semantic. No failure, malformed response, or retry classification SHALL trigger an automatic second `submit-content` request.

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
- **THEN** it is logged and reported as an error after one invocation attempt, and any transient normalization retains the original exception as its diagnostic cause

## ADDED Requirements

### Requirement: Immediate manual retry is classified from structured failure evidence
Every failure returned by the Content Submission operation SHALL expose an immediate-manual-retry decision only when its owning boundary can positively classify the failure. The decision SHALL NOT be derived from a message, `toString()` output, localized text, or the mere presence of an error. The current public `submit-content` taxonomy SHALL be interpreted only as the verified pairs `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `RATE_LIMIT_EXCEEDED`/429, and `INTERNAL_ERROR`/500. Validation, authentication, method/contract, and rate-limit failures SHALL NOT permit immediate manual retry; `INTERNAL_ERROR`/500 SHALL permit it. A missing, unrecognized, or status-inconsistent API code, a malformed success acknowledgement, an unknown client/contract failure, and any otherwise unclassified exception SHALL fail closed as not immediately retryable. The current boundary SHALL NOT synthesize a conflict/409 category. A reliably identified transient transport/network failure or terminal temporary upload/server failure SHALL permit immediate manual retry, while local eligibility/preparation failures, staged-state failures, ordinary checkpoint failures without a positive transient classification, upload validation/contract/cancellation failures, and unknown upload failures SHALL NOT.

#### Scenario: Validation failure is permanent for the immediate action
- **WHEN** final submission returns `VALIDATION_ERROR` with HTTP 400
- **THEN** the failure preserves its structured API fields and immediate manual retry is unavailable

#### Scenario: Authentication failure requires another recovery path
- **WHEN** final submission returns `UNAUTHORIZED` with HTTP 401
- **THEN** the failure preserves its structured API fields and immediate manual retry is unavailable

#### Scenario: Method contract failure is not repeated
- **WHEN** final submission returns `METHOD_NOT_ALLOWED` with HTTP 405
- **THEN** the failure preserves its structured API fields and immediate manual retry is unavailable

#### Scenario: Rate limit does not create an immediate loop
- **WHEN** final submission returns `RATE_LIMIT_EXCEEDED` with HTTP 429
- **THEN** immediate manual retry is unavailable because the current client has no delayed or `Retry-After` action

#### Scenario: Known internal failure is retryable
- **WHEN** final submission returns `INTERNAL_ERROR` with HTTP 500
- **THEN** the failure preserves its structured API fields and immediate manual retry is available

#### Scenario: Reliable transport transient is retryable
- **WHEN** a submission or asset-upload boundary positively identifies a terminal timeout as a transient transport/network failure
- **THEN** immediate manual retry is available without parsing user-visible text

#### Scenario: Generic client and socket failures fail closed
- **WHEN** submission or upload returns an undifferentiated client or socket exception without additional structured transient evidence
- **THEN** immediate manual retry is unavailable even if the exception originated while performing network work

#### Scenario: Terminal temporary upload failure is retryable
- **WHEN** the upload boundary exhausts its existing handling and positively identifies the terminal failure as a timeout or temporary server failure
- **THEN** immediate manual retry of the submission is available without changing the upload boundary's existing internal retry behavior

#### Scenario: Unknown API combination fails closed
- **WHEN** an API failure has a missing or unrecognized code, a status that does not match the verified code, or any outcome outside the verified taxonomy
- **THEN** immediate manual retry is unavailable even if its message appears temporary

#### Scenario: Local and upload contract failures fail closed
- **WHEN** submission fails because of local eligibility, unavailable or inconsistent staged state, an unclassified checkpoint error, upload cancellation/validation/contract failure, malformed acknowledgement, or another unclassified exception
- **THEN** immediate manual retry is unavailable and the current draft/session remains available for safe recovery under its existing lifecycle rules

### Requirement: Retry availability is derived from authoritative submission state
The Content Submission presentation boundary SHALL expose retry availability as a derived semantic of the current submission operation result and confirmed-success finalization state. It SHALL NOT maintain an independently mutable retry flag. Idle, running, and successful submission states SHALL expose no retry action. A failed ordinary submission SHALL expose retry only when its structured failure classification permits immediate manual retry. Confirmed remote success with incomplete local finalization SHALL expose retry after the current finalization attempt stops running, regardless of the local error's generic exception type, and that retry SHALL remain finalization-only.

#### Scenario: Idle, running, and success cannot retry
- **WHEN** the submission operation is idle, currently running, or completed successfully
- **THEN** retry availability is false

#### Scenario: Retryable ordinary failure follows the current result
- **WHEN** the submission operation completes with a failure positively classified as immediately retryable and no finalization is pending
- **THEN** retry availability is true directly from that current result

#### Scenario: Permanent or unknown ordinary failure cannot retry
- **WHEN** the submission operation completes with a permanent or unclassified failure and no finalization is pending
- **THEN** retry availability is false directly from that current result

#### Scenario: A new execution cannot retain stale retryability
- **WHEN** a retry starts and the submission operation clears its previous result while entering the running state
- **THEN** retry availability becomes false without synchronizing or clearing a second mutable flag

#### Scenario: Failed finalization remains locally retryable
- **WHEN** remote success is confirmed, local finalization fails, and the submission operation is no longer running
- **THEN** retry availability is true and executing the existing submission action invokes only the identity-bound local finalization path

### Requirement: Retry classification preserves submission lifecycle invariants
Classifying a failure or exposing retry availability SHALL NOT alter captured-attempt ownership, staged-asset ownership, Cloudinary reuse/deduplication, explicit clear/discard ownership, or server idempotency. A legitimate ordinary remote retry SHALL retain the same logical draft, ordered staged sources, and `client_submission_id`. A finalization retry SHALL retain the acknowledged identity until successful local retirement and SHALL perform no checkpoint, asset upload, or remote submission.

#### Scenario: Legitimate remote retry keeps one identity
- **WHEN** a retryable pre-acknowledgement failure is followed by an immediate manual retry
- **THEN** the later remote attempt uses the same `client_submission_id`, current logical session, and existing staged/upload reuse behavior

#### Scenario: Permanent failure does not destroy recoverable work
- **WHEN** immediate retry is unavailable for a failed pre-acknowledgement attempt
- **THEN** classification alone does not clear the draft, delete staged assets, rotate identity, or prevent the existing edit/discard recovery paths

#### Scenario: Finalization retry cannot resubmit remotely
- **WHEN** retry is available because confirmed remote success has incomplete local finalization
- **THEN** the existing action retries only matching-session local retirement and performs no request preparation, Cloudinary upload, remote submit call, session rotation before success, or premature draft clear
