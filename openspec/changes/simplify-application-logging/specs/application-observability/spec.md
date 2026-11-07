## ADDED Requirements

### Requirement: Typed logging declares remote intent separately from severity

The application SHALL retain `Logger.log` and explicitly classify local diagnostics, safe breadcrumbs and owned reports independently of severity. Reviewed policy SHALL cover causes, filtering, consent and legacy migration.

#### Scenario: Error severity alone does not open a report

- **GIVEN** reporting consent is active
- **WHEN** an error-level or critical-level event is explicitly classified local-only or breadcrumb-only and has an attached exception
- **THEN** the logger initiates no exception/report capture for that event, while maintaining its appropriate Debug local diagnostics
- **AND** a breadcrumb-only event includes only its reviewed remote fields
- **AND** new unclassified events default to local-only; existing remote events require a reviewed migration inventory
- **AND** local-only describes this logger, not independent SDK integrations

#### Scenario: Report policy with and without a cause

- **WHEN** an explicitly reportable event is logged with an exception or without one
- **THEN** the reviewed policy determines a single safe report representation or zero capture for each case; the logger does not fabricate a meaningless exception merely from severity
- **AND** cause-less legacy sync reporting is preserved or deliberately revised only after characterization of its current behavior and owner

#### Scenario: Filtering and consent are explicit

- **WHEN** an event is below the existing minimum local severity or the remote reporting flag is inactive
- **THEN** the logger honors the reviewed level filtering semantics and prevents new application-initiated remote work while retaining the existing consent-independent Debug local diagnostics for eligible levels
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

Remote application telemetry SHALL use approved bounded fields that distinguish and localize representative failures. Arbitrary local metadata, throwable text and stack text SHALL NOT be copied remotely. Original causes and stacks SHALL remain available locally in Debug only.

#### Scenario: Arbitrary extra and raw URL are not transmitted

- **GIVEN** an event contains a signed URL or URI query with a synthetic sensitive canary and `extra` includes a second canary
- **WHEN** the logger emits an approved remote breadcrumb or report
- **THEN** the final transmitted payload omits both prohibited values and all arbitrary `Logger.log(extra: ...)` data
- **AND** request/response bodies, credentials, contributor identities and untrusted event fields are not sent merely because they are available locally
- **AND** retains only reviewed, useful route/image/operation classifications or appropriately bounded fields

#### Scenario: Exception value and frames are evaluated separately

- **GIVEN** an original error, message, attached stack or ambient context contains sensitive synthetic values
- **WHEN** an owner produces a reportable event
- **THEN** the serialized report omits disallowed values across exception fields, stack frames, breadcrumbs and contexts
- **AND** retains reviewed technical origin and category information sufficient for the selected representative troubleshooting case, without claiming universal stack safety or historical grouping equivalence

#### Scenario: Automatic telemetry channels are inspected independently

- **WHEN** Sentry HTTP, Supabase, navigation, unhandled-error, tracing or Replay integrations can emit telemetry independently of application event forwarding
- **THEN** their relevant active payload paths are characterized with synthetic canaries and addressed only through evidence-backed, narrowly scoped changes
- **AND** handled Supabase integration capture is disabled where application REST boundaries already own reporting; breadcrumbs and tracing remain enabled
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
- **AND** subsequent native SDK enrichment cannot restore unapproved ambient fields or replace the required breadcrumbs in the final serialized application report; SDK-owned automatic captures follow the separate automatic-event privacy contract

### Requirement: Console interception is disabled without suppressing legitimate telemetry

Automatic capture of Talker `print` and `debugPrint` output as Sentry console breadcrumbs SHALL be disabled in the production SDK configuration. Talker-frame-dependent console filtering SHALL be retired only after representative envelope tests verify that sensitive local output cannot re-enter remotely via the prior automatic channel and that approved explicit breadcrumbs, SDK error capture, streaming traces and Replay retain their established behavior.

#### Scenario: Talker error remains local

- **WHEN** Talker displays a Debug error object and original stack locally
- **THEN** Sentry does not automatically acquire its console fragments merely from `print` or `debugPrint`
- **AND** local error diagnostics remain inspectable without requiring a rendered-output string filter

#### Scenario: Existing platform telemetry remains active when eligible

- **WHEN** console interception is disabled under valid telemetry consent
- **THEN** approved explicit application breadcrumbs and the existing automatic error, trace and Replay contracts, including the expanded channel-specific privacy requirements, continue to operate
- **AND** sampling, transport resource ownership and consent lifecycle are unchanged

### Requirement: Privacy-safe exception discrimination

Remote errors SHALL retain reviewed technical information sufficient to distinguish and localize materially different representative failures where feasible, without arbitrary exception messages, unsafe frames or private content. Original causes and stacks SHALL remain local in Debug only. Missing stacks SHALL NOT suppress an otherwise reportable failure.

#### Scenario: Same category has different safe source evidence

- **GIVEN** two failures share event/category/type but originate at different reviewed technical locations
- **WHEN** their reports are serialized through the installed SDK
- **THEN** useful safe source or cause discrimination is retained where available and prohibited message/path/filename canaries are absent
- **AND** the comparison records retained fields, diagnostic limitations and possible grouping-input changes without asserting actual server Issue grouping

#### Scenario: Stack cannot be used safely

- **GIVEN** a missing, unparsable, generated, platform-specific or user-controlled stack representation
- **WHEN** a report is otherwise eligible
- **THEN** a useful bounded category/origin report remains visible without fallback to raw stack or private message
- **AND** release/source-map differences and deliberately omitted diagnostics are stated in verification evidence

### Requirement: Complete application report envelopes are isolated

Application reports SHALL exclude unapproved ambient fields and attachment content through final envelope serialization, including post-scope enrichment. Isolation SHALL preserve approved breadcrumbs, safe technical context and correlation without corrupting shared scope or another capture.

#### Scenario: Enrichment and attachment controls

- **GIVEN** synthetic private scope/native-processor fields, scope/hint attachments and approved causal breadcrumbs
- **WHEN** an application report passes installed SDK processing to transport
- **THEN** its complete envelope omits prohibited values and attachment bytes while preserving required approved chronology and safe correlation
- **AND** event-only beforeSend assertions are not treated as attachment protection or proof of real native acquisition

#### Scenario: Captures overlap

- **WHEN** two app reports and one SDK-owned error overlap under controlled processing delays
- **THEN** each event keeps its own approved representation and required breadcrumb order without hint/data crossover or destructive shared-scope changes
- **AND** transport arrival order need not equal invocation order

### Requirement: Automatic Dart errors retain safe visibility

SDK-owned automatic Dart errors SHALL retain SDK ownership, safe unexpected-error visibility and reviewed technical diagnostics while excluding private message/frame/enriched event content. This policy covers event/hint fields reaching Dart `beforeSend`; SDK-owned scope attachments outside that boundary retain the accepted limitation in design. Application logging SHALL NOT duplicate the SDK capture or claim full automatic-envelope sanitization.

#### Scenario: Genuinely unhandled private-content error

- **GIVEN** active consent and an operational automatic capture positive control
- **WHEN** a genuine unhandled Dart error includes private synthetic content
- **THEN** the final serialized SDK report retains identifiable safe error/mechanism/source diagnostics and excludes the prohibited content
- **AND** no extra application report is created; PII-off or an app-report-only hook is not accepted as proof

#### Scenario: Automatic policy encounters malformed diagnostics

- **WHEN** automatic-event privacy processing encounters unsupported or malformed error/frame/context data
- **THEN** a bounded safe representation retains unexpected-error visibility without forwarding unsafe originals or silently dropping the error
- **AND** framework/platform/zone entry-specific behavior is verified independently of owned app-report substitution

### Requirement: Native reporting retains the official SDK boundary

The application SHALL retain official native SDK integration and public lifecycle APIs without SDK forks, private hooks, custom native sanitization or replacement reporting/recovery/transport. Dart event filtering SHALL NOT be claimed to sanitize independently transmitted native events. The accepted SDK limitations in the change design SHALL remain accurately disclosed; new native probes or mitigation are not acceptance prerequisites for this change.

#### Scenario: Native event bypasses the Dart hook

- **WHEN** a native-origin event follows an SDK path that does not invoke Dart `beforeSend`
- **THEN** reporting remains SDK-owned and is not described as sanitized or verified by the Dart projection
- **AND** no custom native pipeline is introduced to satisfy a withdrawn requirement

### Requirement: Talker diagnostics are Debug-only

Talker and all application-owned local diagnostic capabilities SHALL exist only under Flutter `kDebugMode`. Sentry forwarding SHALL remain independent of nullable Talker, preserving `Logger.log`, `minLevel`, remote intent, ownership, consent and sampling. Disabled local branches SHALL skip local-only metadata construction.

#### Scenario: Debug developer diagnostics

- **WHEN** an eligible event is logged in Debug with an injected Talker sink
- **THEN** original error objects and available stacks remain inspectable locally, with the Debug route, observer, viewer and explicit copy/export available independently of Sentry consent
- **AND** sink failure cannot suppress an otherwise eligible safe Sentry attempt and does not authorize automatic history upload

#### Scenario: Profile or Release diagnostics

- **WHEN** `kDebugMode` is false
- **THEN** no Talker instance, local sink work, console/history, logging route, observer, viewer or export is available
- **AND** eligible typed reports and approved breadcrumbs continue through Sentry with a null Talker sink while nonreportable events remain nonreportable
- **AND** no runtime diagnostics toggle, production diagnostics mode or application log-file writer is introduced
- **AND** normal Debug widget tests are not presented as proof of non-Debug runtime behavior

### Requirement: Independent telemetry channels retain bounded acquisition

Active SDK breadcrumbs and spans SHALL retain reviewed useful diagnostics under their own acquisition/privacy contracts. Event projection SHALL NOT be claimed to sanitize streaming spans, Replay recordings or independently transmitted native events.

#### Scenario: Supabase SDK controls remain effective

- **GIVEN** the configured Supabase client with independent error capture disabled and PII/body gates active
- **WHEN** synthetic private query/body/header data traverse representative requests and a sampled stream span
- **THEN** final event and span payloads omit prohibited values while positive controls retain operation/table/status and parameterized-query diagnostics
- **AND** application-owned error reporting remains nonduplicative

#### Scenario: HTTP capability differs from active acquisition

- **WHEN** request telemetry is evaluated
- **THEN** evidence identifies the actual app client, Supabase wrapper, SDK transport and native instrumentation separately
- **AND** an unused general HTTP wrapper's private query capability is not represented as demonstrated application exposure

## MODIFIED Requirements

### Requirement: Error reporting is owned and preserves available causes

Canonical sync reporting SHALL preserve original throwable/stack locally in Debug only; original business propagation remains unchanged in every build. For unexpected throws through `SyncViewModel.sync`, the global command handler SHALL own remote exception reporting. Expected sync failures SHALL initiate zero app captures; reportable handled failures SHALL initiate exactly one safe, consent-gated application capture at the designated path owner. Local diagnostics and safe remote event reporting SHALL be distinct operations; error severity alone SHALL NOT authorize an application capture. Automatic SDK capture of unhandled failures SHALL NOT be redundantly repeated by application reporting. Application reporting SHALL NOT send arbitrary Talker print/debugPrint fragments to Sentry. Content-submission reporting SHALL preserve established error ownership, user-visible semantics, and the specifically scoped Cloudinary upload and post-upload association contracts from `reduce-cloudinary-logging-noise`, including the prohibition on introducing a second application capture for those diagnostics. Changes to destination policy SHALL be characterized and explicitly mapped for existing events rather than implicitly dropping or creating captures.

#### Scenario: Runtime settings failure has a distinct reporting owner

- **WHEN** `SettingsLocalDataSource.update` catches an exception from `setSyncState`
- **THEN** it retains the original throwable/stack locally in Debug and `SyncUseCase` emits only terminal phase `settings`
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
- **THEN** after the separate caught-`Exception` to `Result.error` path, that repository records the original object and stack locally in Debug and rethrows them unchanged without repository remote capture or conversion to `Result.error`
- **AND** `SyncUseCase` attributes the corresponding `prepare_*` phase and emits one terminal failure without capturing the cause again

#### Scenario: Transaction wrapper handles a runtime Error

- **WHEN** an ObjectBox transaction or callback raises a `dart:core.Error` that the existing Result contract must translate
- **THEN** the original runtime error and stack remain available locally in Debug before a necessary `Exception` wrapper, distinct from `Result.Error<T>`
- **AND** an already-logged callback `Result.error` used to roll back the transaction causes no additional capture

#### Scenario: Unexpected sync throw reaches the configured global handler

- **WHEN** `SyncViewModel.sync` propagates any thrown non-null `Object` through `createResultCommand` with `ErrorReaction.globalHandler`, including an object that is neither `Exception` nor `dart:core.Error`
- **THEN** `configureCommandReporting` recognizes `sync_view_model.sync` and alone owns any app-initiated remote capture for that throw
- **AND** the original error/stack remain available locally in Debug; a reportable failure yields one consent-gated sanitized capture without repository or terminal recapture
- **AND** unrelated commands, their error handling and direct sync use-case calls retain existing behavior

#### Scenario: Talker console fragments cannot bypass remote sanitization

- **WHEN** real Talker emits Debug local errors and stacks through `debugPrint` or `print`, including multiline output
- **THEN** the production Sentry SDK does not automatically acquire those console outputs as breadcrumbs, without relying on string matching of Talker's rendered frame characters
- **AND** original Debug local in-memory throwable/stack evidence remains available and approved explicit application breadcrumbs remain observable where required
- **AND** automatic error capture, tracing and Replay retain their existing contracts; sanitization does not depend on recognizing Talker console formatting
- **AND** exception payloads, approved application breadcrumbs and spans continue to enforce safe remote fields

#### Scenario: Expected connectivity failure stays local

- **GIVEN** telemetry consent is enabled
- **WHEN** an expected timeout/connectivity failure is returned during sync
- **THEN** its original cause is diagnosable locally in Debug while the application initiates zero Sentry exception captures
- **AND** terminal reporting does not capture it again

#### Scenario: Reportable exception uses safe remote fields

- **GIVEN** a reportable failure's throwable message, stack or context contains synthetic private URLs, credentials, contributor data or HTTP bodies
- **WHEN** the owner reports it with consent enabled
- **THEN** exactly one application-initiated Sentry exception capture uses only allowlisted, sanitized fields and omits those synthetic values
- **AND** Sentry breadcrumbs and span attributes omit them too, while the original error/stack remain locally available in Debug

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

Application logging implementation and typed events SHALL remain under `lib/utils/logging`. New direct Sentry error capture, breadcrumb/structured logging, manual tracing, or scope mutation outside explicitly approved file/operation integration boundaries SHALL be rejected by a proportionate regression check. Direct Talker use by business call sites SHALL likewise be disallowed except for approved composition and viewer boundaries. Legitimate SDK bootstrap, consent lifecycle, network instrumentation, `SentryMask`, stream tracing adapter, and Debug-only Talker route-viewer uses SHALL NOT be prohibited merely due to their directory. The existing check SHALL be extended rather than replaced with a parallel checker.

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


### Requirement: Sync runs produce one locally identifiable terminal outcome

Every canonical sync invocation SHALL emit a typed start and exactly one terminal result, including early `Result.error` and unexpected throws. Terminal diagnostics SHALL identify the phase and bootstrap/delta mode from the persisted `contentSyncCursorAt` read at entry, not the server cursor. Elapsed time and per-repository fetched DTO counts SHALL follow the numeric-field scenario below and be accurately labeled. Telemetry consent SHALL NOT suppress Debug local diagnostics. Profile and Release SHALL still emit typed events for policy-eligible Sentry forwarding, without retaining Talker history or promising remote delivery for every event.

#### Scenario: Safe terminal data with telemetry disabled

- **WHEN** a bootstrap/delta sync yields any fetched DTO count or failure with consent off
- **THEN** Debug local events remain available, bootstrap/delta derives from the locally persisted cursor at entry, and elapsed time/counts follow the numeric-field contract below
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
- **THEN** one typed terminal success is emitted after sync-state persistence
- **AND** mode, duration, and count fields retain their declared meaning


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
- **AND** Debug local logging remains independently available; Profile and Release retain independently eligible Sentry forwarding


### Requirement: Cloudinary-related diagnostics are privacy-safe and non-duplicative

Cloudinary and related association diagnostic reporting SHALL use bounded, non-sensitive metadata. The reporting owner SHALL NOT send arbitrary HTTP bodies, exception text, stack content, identifiers or contributor material to Sentry. Expected retries and cancellations SHALL NOT generate duplicate error reports; telemetry consent SHALL continue to govern remote emission.

#### Scenario: Sensitive HTTP error body and exception data

- **GIVEN** a Cloudinary response body or an affected association error contains sensitive test canaries
- **WHEN** Debug local diagnostics and consent-enabled Sentry forwarding execute
- **THEN** typed breadcrumbs, console breadcrumbs, and remotely serialized exceptions omit the sensitive data
- **AND** diagnostic cause/classification remains available without exposing arbitrary payloads

#### Scenario: Telemetry disabled

- **WHEN** consent for remote error reporting is disabled
- **THEN** the relevant Debug local failure classification remains inspectable and no application-initiated remote exception capture is made

#### Scenario: Passive request completion observes the same failure

- **WHEN** the Cloudinary passive request-completion listener and the main upload path observe one underlying request error
- **THEN** at most one terminal failure is reported for that operation and the passive listener still prevents unhandled asynchronous errors

#### Scenario: Unrelated operations are unaffected

- **WHEN** synchronization, other Admin repository operations or existing Sentry tracing run outside the affected upload and association boundaries
- **THEN** their diagnostic contracts, exception ownership, consent, and sampling remain unchanged
