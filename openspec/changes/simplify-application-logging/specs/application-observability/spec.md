## ADDED Requirements

### Requirement: Typed logging declares remote intent separately from severity

The application SHALL retain a single application-facing `Logger.log` entry point and SHALL make local-only diagnostics, safe remote breadcrumbs, and application-initiated error reports explicit outcomes independent of `AppLogLevel`. The concrete typed policy SHALL define behavior for missing/present errors, `minLevel`, consent, remote level thresholds, and whether a report includes an approved breadcrumb. A conservative default for new events SHALL NOT retroactively reclassify existing remotely visible events without a reviewed inventory. `localOnly` SHALL refer only to forwarding initiated by this application logger, not independent SDK automatic integrations.

#### Scenario: Error severity alone does not open a report

- **GIVEN** reporting consent is active
- **WHEN** an error-level or critical-level event is explicitly classified local-only or breadcrumb-only and has an attached exception
- **THEN** the logger initiates no exception/report capture for that event, while maintaining its appropriate local diagnostics
- **AND** a breadcrumb-only event includes only its reviewed remote fields

#### Scenario: Report policy with and without a cause

- **WHEN** an explicitly reportable event is logged with an exception or without one
- **THEN** the reviewed policy determines a single safe report representation or zero capture for each case; the logger does not fabricate a meaningless exception merely from severity
- **AND** cause-less legacy sync reporting is preserved or deliberately revised only after characterization of its current behavior and owner

#### Scenario: Filtering and consent are explicit

- **WHEN** an event is below the existing minimum local severity or the remote reporting flag is inactive
- **THEN** the logger honors the reviewed level filtering semantics and prevents new application-initiated remote work while retaining the existing consent-independent local diagnostics for eligible levels
- **AND** any change to the current minimum-level or debug-remote threshold requires a separately recorded compatibility decision

### Requirement: Logging failures do not modify application outcomes

Application logging SHALL be best effort and SHALL NOT change business return values, exception identity/stack propagation, persistence, retry decisions, or mutation sequencing. This obligation SHALL cover diagnostic arguments evaluated before calling `Logger.log`, synchronous logger/transport invocation and asynchronous diagnostic work. An isolated failure in one sink SHALL NOT suppress an otherwise eligible independent sink when the required data remain available.

#### Scenario: Diagnostic construction before persistence fails

- **WHEN** an optional diagnostic argument or rendering operation fails before a draft persistence write
- **THEN** the diagnostic failure does not prevent the business write from executing or replace its original result
- **AND** the implementation does not blanket-catch business failures merely to conceal logging errors

#### Scenario: Diagnostic construction after durable write fails

- **WHEN** a persistence operation succeeds but a later diagnostic expression, event getter, or output sink fails
- **THEN** the already successful operation does not return `Result.error` solely because logging failed
- **AND** local and remote logging sink failures neither undo the durable write nor cause an extra business attempt

#### Scenario: Diagnostic Future or sink fails

- **WHEN** an event accessor, local Talker sink, Sentry API invocation, or asynchronously completed remote logging Future fails
- **THEN** the logger does not throw that diagnostic failure into business code or leave a new unhandled diagnostic error
- **AND** a failed local sink does not prevent a safe remote capture whose data are independently available, without recursive logging, speculative retry or a global queue

### Requirement: Remote diagnostic payloads are reviewed and useful

Remote application-originated telemetry SHALL use approved, bounded, purpose-specific fields. `Logger.log(extra: ...)` SHALL NOT be forwarded remotely, and original arbitrary throwable messages, stack text, URLs, request/response bodies, credentials, contributor identities, or untrusted event fields SHALL NOT be sent merely because they are present locally. For each reportable family, the approved fields SHALL provide the minimum safe context required to distinguish and localize representative failures; local original throwable/stack retention SHALL remain. This requirement SHALL NOT assert that SDK-generated HTTP, Replay, navigation or unhandled-error payloads are controlled by the application logger.

#### Scenario: Arbitrary extra and raw URL are not transmitted

- **GIVEN** an event contains a signed URL or URI query with a synthetic sensitive canary and `extra` includes a second canary
- **WHEN** the logger emits an approved remote breadcrumb or report
- **THEN** the final transmitted payload omits both prohibited values
- **AND** retains only reviewed, useful route/image/operation classifications or appropriately bounded fields

#### Scenario: Exception value and frames are evaluated separately

- **GIVEN** an original error, message, attached stack or ambient context contains sensitive synthetic values
- **WHEN** an owner produces a reportable event
- **THEN** the serialized report omits disallowed values across exception fields, stack frames, breadcrumbs and contexts
- **AND** retains reviewed technical origin and category information sufficient for the selected representative troubleshooting case, without claiming universal stack safety or historical grouping equivalence

#### Scenario: Automatic telemetry channels are inspected independently

- **WHEN** Sentry HTTP, Supabase, navigation, unhandled-error, tracing or Replay integrations can emit telemetry independently of application event forwarding
- **THEN** their relevant active payload paths are characterized with synthetic canaries and addressed only through evidence-backed, narrowly scoped changes
- **AND** existing consent and Replay privacy requirements remain authoritative

### Requirement: Required application breadcrumb context survives report capture

When an application-generated remote report depends on specific approved application breadcrumbs, those breadcrumbs SHALL be present in the **final serialized event** in the required causal order. This SHALL be evaluated with the real installed SDK path, including any scoped capture isolation, without prescribing synchronization unless a demonstrated behavior requires it. No global total order is required across concurrent operations.

#### Scenario: Required breadcrumb precedes a report

- **WHEN** the application logs a relevant breadcrumb and then initiates a report that requires that context
- **THEN** its delivered Sentry envelope contains the approved breadcrumb in the required causal relationship
- **AND** the test does not mask a potential race by introducing extra test-side awaiting between logging and capture

#### Scenario: Scoped capture intentionally removes ambient data

- **WHEN** a report path isolates the Sentry scope to prevent ambient untrusted console, HTTP or other data
- **THEN** unrelated or prohibited context remains excluded
- **AND** the report's specifically required approved application context is preserved by the smallest verified method, without disabling isolation solely to retain all ambient breadcrumbs

### Requirement: Console interception is disabled without suppressing legitimate telemetry

Automatic capture of Talker `print` and `debugPrint` output as Sentry console breadcrumbs SHALL be disabled in the production SDK configuration. Talker-frame-dependent console filtering SHALL be retired only after representative envelope tests verify that sensitive local output cannot re-enter remotely via the prior automatic channel and that approved explicit breadcrumbs, SDK error capture, streaming traces and Replay retain their established behavior.

#### Scenario: Talker error remains local

- **WHEN** Talker displays an error object and original stack locally
- **THEN** Sentry does not automatically acquire its console fragments merely from `print` or `debugPrint`
- **AND** local error diagnostics remain inspectable without requiring a rendered-output string filter

#### Scenario: Existing platform telemetry remains active when eligible

- **WHEN** console interception is disabled under valid telemetry consent
- **THEN** approved explicit application breadcrumbs and the existing automatic error, trace and Replay contracts continue to operate
- **AND** sampling, transport resource ownership and consent lifecycle are unchanged

## MODIFIED Requirements

### Requirement: Error reporting is owned and preserves available causes

Canonical sync reporting SHALL preserve original throwable/stack locally. For unexpected throws through `SyncViewModel.sync`, the global command handler SHALL own remote exception reporting. Expected sync failures SHALL initiate zero app captures; reportable handled failures SHALL initiate exactly one safe, consent-gated application capture at the designated path owner. Local diagnostics and safe remote event reporting SHALL be distinct operations; error severity alone SHALL NOT authorize an application capture. Automatic SDK capture of unhandled failures SHALL NOT be redundantly repeated by application reporting. Application reporting SHALL NOT send arbitrary Talker print/debugPrint fragments to Sentry. Content-submission reporting SHALL preserve established error ownership, user-visible semantics, and the specifically scoped Cloudinary upload and post-upload association contracts from `reduce-cloudinary-logging-noise`, including the prohibition on introducing a second application capture for those diagnostics. Changes to destination policy SHALL be characterized and explicitly mapped for existing events rather than implicitly dropping or creating captures.

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

#### Scenario: Talker console output is not automatically collected remotely

- **WHEN** real Talker emits local errors and stacks through `debugPrint` or `print`, including multiline output
- **THEN** the production Sentry SDK does not automatically acquire those console outputs as breadcrumbs, without relying on string matching of Talker's rendered frame characters
- **AND** original local in-memory throwable/stack evidence remains available and approved explicit application/SDK breadcrumbs remain observable where required
- **AND** exception payloads, approved application breadcrumbs and spans continue to enforce safe remote fields

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

#### Scenario: Failure ownership is resolved by propagation path

- **WHEN** a failure originates in an infrastructure or repository boundary and is later returned as `Result.error`, propagated through a command, or left unhandled
- **THEN** the designated reporting boundary decides whether and when to capture based on terminal ownership and expected/handled/unexpected classification, not solely on the event's type or severity
- **AND** one terminal failure within one operation initiates at most one application capture unless a reviewed exception explicitly justifies more, without global deduplication by object identity
- **AND** an unhandled error captured by the SDK does not receive an additional manual application capture solely because a local log was written

#### Scenario: Existing remote diagnostics are explicitly migrated

- **WHEN** the logging policy is migrated for existing sync, Cloudinary, submission, Admin, repository, command, persistence, route, or image events
- **THEN** each materially remote-visible event has a reviewed destination, owner, approved fields, and capture behavior for an attached or missing cause
- **AND** a new conservative event default alone does not silently remove existing high-value breadcrumbs or create new Issues from ordinary error-level events

### Requirement: Logging implementation maintains constrained SDK boundaries

Application logging implementation and typed events SHALL remain under `lib/utils/logging`. New direct Sentry error capture, breadcrumb/structured logging, manual tracing, or scope mutation outside explicitly approved file/operation integration boundaries SHALL be rejected by a proportionate regression check. Direct Talker use by business call sites SHALL likewise be disallowed except for approved composition and viewer boundaries. Legitimate SDK bootstrap, consent lifecycle, network instrumentation, `SentryMask`, stream tracing adapter, and Talker route-viewer uses SHALL NOT be prohibited merely due to their directory. The existing check SHALL be extended rather than replaced with a parallel checker.

#### Scenario: New business-layer direct transaction

- **WHEN** a new production business file introduces `Sentry.startTransaction` or an unapproved direct SDK capture call
- **THEN** the scoped regression check fails with an actionable path and exception policy

#### Scenario: Authorized platform integration remains

- **WHEN** existing consent/bootstrap, Replay masks, or route observers use their intended SDK integrations
- **THEN** the check does not require unrelated relocation or block those legitimate boundaries

#### Scenario: Direct logging bypasses and aliases are rejected

- **WHEN** an application file invokes an unapproved Sentry logger, capture, breadcrumb, scope or tracing API, or a direct Talker API, including via an import alias or a previously blanket-exempt logging directory
- **THEN** the existing static regression check fails with actionable file/operation information
- **AND** representative approved integration boundaries still pass positive control fixtures

#### Scenario: CI coverage and native acceptance are stated accurately

- **WHEN** logging boundary tests run in a pull request
- **THEN** their actual execution in the configured CI job is established, and required-status-check enforcement is verified separately
- **AND** native `integration_test/**` results and real Sentry/Replay inspection are not inferred from the autonomous `test/**` suite
