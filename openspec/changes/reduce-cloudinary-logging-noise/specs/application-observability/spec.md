## ADDED Requirements

### Requirement: Cloudinary upload diagnostics represent terminal client outcomes

Each admitted Cloudinary upload operation SHALL distinguish recoverable attempts, valid new upload, content-addressed reuse, expected cancellation, and terminal client non-success without treating an intermediate retry as a terminal error. Logging SHALL NOT alter the existing upload, retry, or progress result.

#### Scenario: Transient failure followed by a new upload

- **WHEN** an HTTP 5xx or upload/body timeout is retried and a later attempt returns valid asset metadata without `existing: true`
- **THEN** interim attempts have diagnostic severity below error, one new-upload success is reported and no terminal upload failure or application exception capture is emitted for those attempts

#### Scenario: A Cloudinary POST response indicates an existing asset

- **WHEN** a completed Cloudinary POST, on the first attempt or after retries, returns valid asset metadata with `existing: true`
- **THEN** the client reports successful reuse rather than a newly created transfer, without a terminal failure or application exception capture
- **AND** the successful functional result is preserved and the diagnostic does not claim that no POST occurred

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

## MODIFIED Requirements

### Requirement: Error reporting is owned and preserves available causes

Canonical sync reporting SHALL preserve original throwable/stack locally. For unexpected throws through `SyncViewModel.sync`, the global command handler SHALL own remote exception reporting. Expected sync failures SHALL initiate zero app captures; reportable handled failures SHALL initiate exactly one sanitized, consent-gated capture. Sentry console breadcrumbs SHALL NOT leak Talker error text or stack. Content-submission reporting SHALL retain its existing failure ownership, exception-capture policy, and user-visible semantics, except for the explicitly scoped Cloudinary upload and post-upload association diagnostics added by `reduce-cloudinary-logging-noise`. Those diagnostics SHALL NOT introduce another application-initiated Sentry exception capture, alter Sentry consent or sampling, or change Result values and backend persistence/replay behavior.

#### Scenario: Runtime settings failure has a distinct reporting owner

- **WHEN** `SettingsLocalDataSource.update` catches an exception from `setSyncState`
- **THEN** it retains the original throwable/stack locally and `SyncUseCase` emits only terminal phase `settings`
- **AND** `SettingsRepositoryImpl` passes the failure through and startup `handleSettingsRepositoryInitialization` for `load` does not recapture it

#### Scenario: Deliberate rollback does not become a new transaction exception

- **WHEN** `BaseSyncRepository` has already reported a returned `Result.error` and the ObjectBox coordinator rolls back the transaction
- **THEN** the coordinator preserves that result without a second exception capture or treating it as a new transaction-native error

#### Scenario: Original exception caught at the cursor or settings boundary

- **WHEN** an infrastructure `Exception` with a stack is caught and returned as a `Result.error`
- **THEN** the reporting owner receives the original throwable and stack, not only their interpolated textual representation
- **AND** a subsequent terminal sync failure does not capture it again

#### Scenario: Repository preparation raises a non-Exception object

- **WHEN** `fetchRemote` throws a non-Exception `Object`, including `dart:core.Error`, a custom object or a string, inside `BaseSyncRepository.prepareSync`
- **THEN** after the separate caught-`Exception` to `Result.error` path, that repository records the original object and stack locally and rethrows them unchanged without repository remote capture or conversion to `Result.error`
- **AND** `SyncUseCase` attributes the corresponding `prepare_*` phase and emits one terminal failure without capturing the cause again

#### Scenario: Transaction wrapper handles a runtime Error

- **WHEN** an ObjectBox transaction or callback raises a `dart:core.Error` that the existing Result contract must translate
- **THEN** the original runtime error and stack remain available locally before a necessary `Exception` wrapper, distinct from `Result.Error<T>`
- **AND** an already-logged callback `Result.error` used to roll back the transaction causes no additional capture

#### Scenario: Unexpected sync throw reaches the configured global handler

- **WHEN** `SyncViewModel.sync` propagates any thrown non-null `Object` through `createResultCommand` with `ErrorReaction.globalHandler`, including an object that is neither `Exception` nor `dart:core.Error`
- **THEN** `configureCommandReporting` recognizes `sync_view_model.sync` and alone owns any app-initiated remote capture for that throw
- **AND** the original error/stack remain available locally; a reportable failure yields one consent-gated sanitized capture without repository or terminal recapture
- **AND** unrelated commands, their error handling and direct sync use-case calls retain existing behavior

#### Scenario: Talker console fragments cannot bypass remote sanitization

- **WHEN** real Talker outputs a locally preserved error/stack as separate `debugPrint`/`print` lines, including `│ Exception:` and `│ StackTrace:` fragments
- **THEN** the production `beforeBreadcrumb` path prevents those sensitive lines from reaching Sentry console breadcrumbs while original local in-memory diagnostics remain
- **AND** unrelated safe breadcrumbs remain available, and exception payloads/typed breadcrumbs/spans contain only safe allowed fields

#### Scenario: Expected connectivity failure stays local

- **GIVEN** telemetry consent is enabled
- **WHEN** an expected timeout/connectivity failure is returned during sync
- **THEN** its original cause is diagnosable locally while the application initiates zero Sentry exception captures
- **AND** terminal reporting does not capture it again

#### Scenario: Reportable exception uses safe remote fields

- **GIVEN** a reportable failure's throwable message, stack or context contains synthetic private URLs, credentials, contributor data or HTTP bodies
- **WHEN** the owner reports it with consent enabled
- **THEN** exactly one application-initiated Sentry exception capture uses only allowlisted, sanitized fields and omits those synthetic values
- **AND** Sentry breadcrumbs and span attributes omit them too, while the original error/stack remain locally available

#### Scenario: Content-submission reporting remains independent

- **WHEN** content submission moves from legacy Sentry transactions to stream spans
- **THEN** the canonical-sync zero-or-one application capture policy is not imposed on submission failures
- **AND** the migration introduces no new exception capture or change to consent and sampling

#### Scenario: Unexpected raw throw

- **WHEN** business work unexpectedly throws rather than returning `Result.error`
- **THEN** the original thrown object and stack remain propagatable without silent conversion to a normal result
- **AND** its terminal failure remains identifiable without duplicate application-initiated exception capture
