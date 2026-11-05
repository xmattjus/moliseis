## ADDED Requirements

### Requirement: Cloudinary upload diagnostics represent terminal client outcomes

Each admitted Cloudinary upload operation SHALL distinguish recoverable attempts, valid new upload, content-addressed reuse, expected cancellation, and terminal client non-success without treating an intermediate retry as a terminal error. Logging SHALL NOT alter the existing upload, retry, or progress result.

#### Scenario: Transient failure followed by success

- **WHEN** an HTTP 5xx or upload/body timeout is retried and a later attempt returns valid asset metadata
- **THEN** interim attempts have diagnostic severity below error, one new-upload success is reported and no terminal upload failure or application exception capture is emitted for those attempts

#### Scenario: Retry attempts are exhausted

- **WHEN** all permitted retries end without a confirmed successful upload
- **THEN** one terminal client non-success is reported with a bounded safe failure classification
- **AND** a timeout or transport failure does not assert that Cloudinary definitely did not create an asset

#### Scenario: Expected cancellation

- **WHEN** an upload is deliberately cancelled before preparation, during transfer/response, or during retry backoff
- **THEN** it produces no error-level cancellation signal or application-initiated Sentry exception capture
- **AND** no late completion is reported as an upload success

#### Scenario: Reused Cloudinary asset

- **WHEN** server preparation confirms an existing content-addressed asset
- **THEN** the asset is returned without a new binary upload and the diagnostic distinguishes reuse from a newly completed transfer

#### Scenario: Local preparation and invalid response

- **WHEN** file inspection, upload preparation, size/option validation or successful-HTTP response validation prevents a confirmed upload
- **THEN** its client result is preserved and any failure event describes the appropriate stage without inventing a completed remote upload or an HTTP POST that never occurred

### Requirement: Post-upload association diagnostics require authoritative confirmation

Post-upload diagnostics SHALL distinguish a valid backend acknowledgement from an explicit rejection or unconfirmed request outcome at both public submission and Admin staged-association boundaries. An upload success SHALL NOT be logged as database persistence, and diagnostic ambiguity SHALL NOT change retry or receipt rules.

#### Scenario: Public submission acknowledges associated assets

- **WHEN** public `submit-content` returns a validated successful or replay acknowledgement after asset preparation
- **THEN** the final submission is reported as backend-confirmed separately from Cloudinary upload or reuse
- **AND** the diagnostic does not claim one server transaction per asset or create a new backend contract

#### Scenario: Public final request is rejected or unconfirmed

- **WHEN** public submission returns an explicit rejection, a transport failure, or an invalid or missing acknowledgement after any uploaded assets
- **THEN** the diagnostic distinguishes explicit rejection from an unconfirmed remote outcome where evidence permits
- **AND** it does not claim a definite orphan, roll back Cloudinary assets, or report backend association as confirmed

#### Scenario: Admin association is confirmed or replayed

- **WHEN** an Admin staged asset's exact-receipt association returns a valid confirmed or replayed asset response
- **THEN** the association is reported as confirmed separately from the preceding Cloudinary upload
- **AND** existing receipt persistence and exact-replay behavior are unchanged

#### Scenario: Admin association response fails or is ambiguous

- **WHEN** an Admin association is explicitly rejected or its response cannot prove whether a write committed
- **THEN** the diagnostic distinguishes a confirmed rejection from an unconfirmed remote outcome without announcing association success
- **AND** the existing receipt and staged work remain available under current recovery contracts

### Requirement: Cloudinary-related diagnostics are privacy-safe and non-duplicative

Cloudinary and related association diagnostic reporting SHALL use bounded, non-sensitive metadata. The reporting owner SHALL NOT send arbitrary HTTP bodies, exception text, stack content, identifiers or contributor material to Sentry. Expected retries and cancellations SHALL NOT generate duplicate error reports; telemetry consent SHALL continue to govern remote emission.

#### Scenario: Sensitive HTTP error body and exception data

- **GIVEN** a Cloudinary response body or an affected association error contains sensitive test canaries
- **WHEN** local diagnostics and consent-enabled Sentry forwarding execute
- **THEN** typed breadcrumbs, console breadcrumbs, and remotely serialized exceptions omit the sensitive data
- **AND** diagnostic cause/classification remains available without exposing arbitrary payloads

#### Scenario: Telemetry disabled

- **WHEN** consent for remote error reporting is disabled
- **THEN** the relevant local failure classification remains inspectable and no application-initiated remote exception capture is made

#### Scenario: Passive request completion observes the same failure

- **WHEN** the Cloudinary passive request-completion listener and the main upload path observe one underlying request error
- **THEN** at most one terminal failure is reported for that operation and the passive listener still prevents unhandled asynchronous errors

#### Scenario: Unrelated operations are unaffected

- **WHEN** synchronization, other Admin repository operations or existing Sentry tracing run outside the affected upload and association boundaries
- **THEN** their diagnostic contracts, exception ownership, consent, and sampling remain unchanged
