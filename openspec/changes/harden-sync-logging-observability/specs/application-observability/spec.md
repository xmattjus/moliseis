## Purpose

Make Molise Is diagnostic events and manual traces useful, truthful, and safe across canonical synchronization and content submission, while preserving existing local logging and Sentry consent contracts.

## ADDED Requirements

### Requirement: Sync runs produce one locally identifiable terminal outcome

Every canonical sync invocation SHALL emit a typed start and exactly one terminal result, including early `Result.error` and unexpected throws. Terminal diagnostics SHALL identify the phase and bootstrap/delta mode from the persisted `contentSyncCursorAt` read at entry, not the server cursor. Elapsed time and per-repository fetched DTO counts SHALL follow the numeric-field scenario below and be accurately labeled. Telemetry consent SHALL NOT suppress local diagnostics.

#### Scenario: Safe terminal data with telemetry disabled

- **WHEN** a bootstrap/delta sync yields any fetched DTO count or failure with consent off
- **THEN** local events remain available, bootstrap/delta derives from the locally persisted cursor at entry, and elapsed time/counts follow the numeric-field contract below
- **AND** fetched counts are not mislabeled as durable insert/update/delete totals

#### Scenario: Numeric diagnostic fields have portable bounds

- **WHEN** sync emits elapsed time or available fetched DTO counts
- **THEN** `elapsed_ms` comes from a `Stopwatch` started at sync entry and stopped at terminal publication; each repository count comes from its successfully prepared list's `length`, with unavailable counts omitted and no cross-repository total
- **AND** each numeric field SHALL be an integer clamped before emission to `0..9007199254740991` (`2^53 - 1`), the portable contiguous safe-integer range for native/JavaScript numeric metadata: negative input becomes zero, input above the maximum saturates at the maximum, and in-range input remains unchanged
- **AND** the maximum denotes a saturated diagnostic; these bounds are neither a sync timeout nor a retrieval/storage limit, and clamping does not change business outcomes

#### Scenario: Cursor acquisition fails before preparation

- **WHEN** cursor RPC or decoding fails
- **THEN** sync emits a terminal failure identifying the cursor phase and does not claim a fetch, content commit, or successful sync

#### Scenario: Preparation fails after other fetches started

- **WHEN** any one of four concurrently started preparations returns a `Result.error`
- **THEN** sync emits one terminal failure identifying the failing repository/prepare phase and does not claim that any content committed

#### Scenario: Concurrent preparation unexpectedly throws

- **WHEN** city, place, event, or media `prepareSync` throws any non-null `Object` (including an `Exception`, `dart:core.Error`, custom object or string) while other preparations are running
- **THEN** the orchestrator uses positional `AsyncError` entries in `ParallelWaitError.errors` from the existing record `.wait` to identify `prepare_city`, `prepare_place`, `prepare_event` or `prepare_media`, without new per-future wrappers
- **AND** exactly one terminal failure describes that phase without a second capture or a false commit
- **AND** the selected throwable identity and the stack from its `AsyncError` propagate unchanged; all four preparations remain concurrent
- **AND** when multiple preparations fail, the primary failure SHALL be selected regardless of completion order: all thrown non-null `Object` failures take precedence over returned `Result.error`; within either category, precedence is `prepare_city` → `prepare_place` → `prepare_event` → `prepare_media`, and exactly one terminal failure identifies that selected phase/cause

#### Scenario: Returned preparation failure has no Result stack

- **WHEN** a preparation normally completes with `Result.error`, including a value in `ParallelWaitError.values` during a mixed returned/thrown failure
- **THEN** its original returned exception identity remains available, but no stack is expected from the Result; available catch-site stacks are verified separately at the reporting source
- **AND** thrown-object identity and stack come from the corresponding `AsyncError` in `.errors`, and thrown-over-returned precedence and city/place/event/media order remain unchanged

#### Scenario: Settings persistence fails after content committed

- **WHEN** all content commits but durable sync-state persistence fails
- **THEN** the terminal event identifies settings persistence failure, without a sync success
- **AND** any separate content-commit diagnostic describes only the actually committed content

#### Scenario: Successful bootstrap, delta, and empty retrieval

- **WHEN** all phases complete for bootstrap, delta, or a sync fetching zero DTOs
- **THEN** one local terminal success is emitted after sync-state persistence
- **AND** mode, duration, and count fields retain their declared meaning

### Requirement: Error reporting is owned and preserves available causes

Canonical sync reporting SHALL preserve original throwable/stack locally. For unexpected throws through `SyncViewModel.sync`, the global command handler SHALL own remote exception reporting. Expected sync failures SHALL initiate zero app captures; reportable handled failures SHALL initiate exactly one sanitized, consent-gated capture. Sentry console breadcrumbs SHALL NOT leak Talker error text or stack. Content-submission reporting SHALL remain unchanged.

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

### Requirement: Manual traces use Sentry streaming lifecycle

The application SHALL use `SentryTraceLifecycle.stream` and streaming `startSpan` for manual sync and content-submission tracing. One minimal adapter under `lib/utils/logging` SHALL execute the `Result` callback once, preserve original values and throws, mark returned `Result.error` with `SentrySpanStatusV2.error`, and SHALL NOT capture exceptions. Existing sampling, consent and business workflow behavior SHALL remain unchanged.

#### Scenario: Streaming adapter preserves execution semantics

- **WHEN** a traced `Result` action runs with Sentry enabled, sampled out or inactive
- **THEN** its callback executes once, its original result/throw propagates and no exception capture is initiated by the tracing adapter
- **AND** existing sampling, consent and business behavior are preserved

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
