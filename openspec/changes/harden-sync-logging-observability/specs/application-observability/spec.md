## Purpose

Make Molise Is diagnostic events and manual traces useful, truthful, and safe across canonical synchronization and content submission, while preserving existing local logging and Sentry consent contracts.

## ADDED Requirements

### Requirement: Sync runs produce one locally identifiable terminal outcome

Every admitted canonical sync invocation SHALL generate typed local diagnostic events identifying its start and exactly one terminal result (success or failure), including early `Result.error` returns and unexpected throws. The terminal result SHALL identify the last relevant phase (cursor acquisition, per-repository preparation, atomic commit, or sync-state persistence) and bootstrap/delta mode determined from the **local persisted `contentSyncCursorAt` read at sync entry**, not the fetched server cursor. It SHALL carry bounded elapsed time and safe aggregate counts when known. Fetched DTO counts SHALL NOT be mislabeled as persisted changes. Telemetry opt-out SHALL NOT suppress local diagnostics.

#### Scenario: Cursor acquisition fails before preparation

- **WHEN** cursor RPC or decoding fails
- **THEN** sync emits a terminal failure identifying the cursor phase and does not claim a fetch, content commit, or successful sync

#### Scenario: Preparation fails after other fetches started

- **WHEN** any one of four concurrently started preparations returns an error
- **THEN** sync emits one terminal failure identifying the failing repository/prepare phase and does not claim that any content committed

#### Scenario: Settings persistence fails after content committed

- **WHEN** all content commits but durable sync-state persistence fails
- **THEN** the terminal event identifies settings persistence failure, without a sync success
- **AND** any separate content-commit diagnostic describes only the actually committed content

#### Scenario: Successful bootstrap, delta, and empty retrieval

- **WHEN** all phases complete for bootstrap, delta, or a sync fetching zero DTOs
- **THEN** one local terminal success is emitted after sync-state persistence
- **AND** mode, duration, and count fields retain their declared meaning

### Requirement: Error reporting is owned and preserves available causes

A caught `Exception` SHALL retain its original identity wherever `Result.error` permits, and the first owning reporting boundary SHALL preserve the original throwable and `StackTrace` for **local** diagnosis. A non-`Exception` `dart:core.Error` SHALL be distinguished from `Result.Error<T>` and retained locally before any contract-required `Exception` wrapper. For runtime `setSyncState` failures, `SettingsLocalDataSource.update` owns the original cause/stack report; `SyncUseCase` emits only the terminal `settings` outcome, distinct from startup `load` reporting. Callback `Result.error` failures already logged by repositories SHALL NOT be recaptured as transaction-native faults.

Remote reporting SHALL distinguish expected/transient failures (**zero** application-initiated exception captures) from reportable unexpected contract/storage failures (**exactly one** sanitized capture when consent is enabled). The original throwable, untrusted message/stack and arbitrary HTTP/URL/credential/contributor fields SHALL NOT be forwarded verbatim. Only allowlisted safe categories/context and reviewed-safe stack fields may reach Sentry exception payloads, breadcrumbs or spans. Because `AppLogger.log(error: ...)` forwards the original error automatically today, the new sync reporting paths SHALL explicitly separate local cause retention from safe remote reporting; safe `LogEvent.data` alone SHALL NOT be considered sufficient. Consent off SHALL suppress these remote captures, without hiding local diagnostics. This policy applies to app-initiated reporting of handled failures, not unrelated automatic SDK crashes.

#### Scenario: Original exception caught at the cursor or settings boundary

- **WHEN** an infrastructure `Exception` with a stack is caught and returned as a `Result.error`
- **THEN** the reporting owner receives the original throwable and stack, not only their interpolated textual representation
- **AND** a subsequent terminal sync failure does not capture it again

#### Scenario: Transaction wrapper handles a runtime Error

- **WHEN** an ObjectBox transaction or callback raises a `dart:core.Error` that the existing Result contract must translate
- **THEN** the original runtime error and stack remain available locally before a necessary `Exception` wrapper, distinct from `Result.Error<T>`
- **AND** an already-logged callback `Result.error` used to roll back the transaction causes no additional capture

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

#### Scenario: Unexpected raw throw

- **WHEN** business work unexpectedly throws rather than returning `Result.error`
- **THEN** the original thrown object and stack remain propagatable without silent conversion to a normal result
- **AND** its terminal failure remains identifiable without duplicate application-initiated exception capture

### Requirement: Manual traces use Sentry streaming lifecycle

The application SHALL explicitly select `SentryTraceLifecycle.stream` for Sentry 10 and use the streaming `startSpan` family for manual sync and content-submission tracing, not legacy `startTransaction`. A small adapter under `lib/utils/logging` SHALL execute each `Result`-returning action exactly once, preserve its result, mark returned `Result.error` as `SentrySpanStatusV2.error`, and allow unexpected throws to propagate while the SDK marks those spans failed. The adapter SHALL NOT call `captureException`. Existing sampling rates, SDK shutdown/consent semantics, and business workflows SHALL remain unchanged.

#### Scenario: Sync succeeds or returns an error

- **WHEN** sync is traced under a recording, consent-enabled streaming SDK
- **THEN** an actual span is emitted with status ok for success and error for `Result.error`, without legacy static transactions

#### Scenario: Content submission succeeds or fails

- **WHEN** content submission returns success or a normalized failure
- **THEN** its recorded streaming span accurately reflects that result without changing submission exception normalization or duplicate capture

#### Scenario: Callback throws unexpectedly

- **WHEN** the traced operation throws
- **THEN** the original throw propagates and the emitted span is marked as failed

#### Scenario: Reporting disabled or not sampled

- **WHEN** Sentry was never initialized by consent, is closed, or declines the span by sampling
- **THEN** the business callback still executes exactly once and returns/throws the same value
- **AND** local logging remains independently available

### Requirement: Logging implementation maintains constrained SDK boundaries

Application logging implementation and typed events SHALL remain under `lib/utils/logging`. New direct Sentry tracing/reporting use outside approved adapter and composition/privacy boundaries SHALL be rejected by a proportionate regression check. Legitimate SDK bootstrap, consent lifecycle, network instrumentation, `SentryMask`, and Talker route-viewer uses SHALL not be prohibited solely due to their directory.

#### Scenario: New business-layer direct transaction

- **WHEN** a new production business file introduces `Sentry.startTransaction` or an unapproved direct SDK capture call
- **THEN** the scoped regression check fails with an actionable path and exception policy

#### Scenario: Authorized platform integration remains

- **WHEN** existing consent/bootstrap, Replay masks, or route observers use their intended SDK integrations
- **THEN** the check does not require unrelated relocation or block those legitimate boundaries
