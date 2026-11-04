## Purpose

Make Molise Is diagnostic events and manual traces useful, truthful, and safe across canonical synchronization and content submission, while preserving existing local logging and Sentry consent contracts.

## ADDED Requirements

### Requirement: Sync runs produce one locally identifiable terminal outcome

Every admitted canonical sync invocation SHALL generate typed local diagnostic events identifying its start and exactly one terminal result (success or failure), including early `Result.error` returns and unexpected throws. The terminal result SHALL identify the last relevant phase (cursor acquisition, per-repository preparation, atomic commit, or sync-state persistence) and bootstrap/delta mode, with bounded elapsed time and safe aggregate counts when known. Counts of remotely fetched DTOs SHALL NOT be mislabeled as persisted insert/update/delete operations. The telemetry opt-out SHALL NOT suppress these local diagnostics.

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

An exception caught for conversion into `Result.error` SHALL retain its original exception object wherever the contract permits, and the first responsible reporter SHALL log the original stack trace before that context is lost. For non-`Exception` errors handled by an existing compatibility boundary, reporting SHALL retain the original `Object` and stack before conversion. An already reported failure SHALL NOT be captured a second time by the sync terminal event. No new diagnostic or span metadata SHALL expose tokens, credentials, private contributor data, arbitrary HTTP request/response bodies, or secret-bearing URLs.

#### Scenario: Original exception caught at the cursor or settings boundary

- **WHEN** an infrastructure `Exception` with a stack is caught and returned as a `Result.error`
- **THEN** the reporting owner receives the original throwable and stack, not only their interpolated textual representation
- **AND** a subsequent terminal sync failure does not capture it again

#### Scenario: Transaction wrapper handles an Error

- **WHEN** ObjectBox raises a non-`Exception` error that existing Result handling must translate
- **THEN** the original error and stack are available at the reporting boundary, with any necessary downstream `Exception` wrapper clearly distinct
- **AND** ordinary `Result.error` rollback from an already-logged repository callback does not cause duplicate capture

#### Scenario: Unexpected raw throw

- **WHEN** business work unexpectedly throws rather than returning `Result.error`
- **THEN** the original thrown object and stack remain propagatable without silent conversion to a normal result
- **AND** its terminal failure remains identifiable without duplicate exception capture

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
