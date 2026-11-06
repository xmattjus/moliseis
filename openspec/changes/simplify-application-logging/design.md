# Design: simplify-application-logging

## Baseline, evidence, and authority

Planning baseline: committed `xmattjus/moliseis` `main`, SHA `3246b04c8518aef235eab016f42beca4a4fd7bc6` (2026-11-05). Source and canonical spec inspection was read-only. No Flutter tests, Sentry production inspection, native recordings, or deployed-config verification were executed while creating this proposal.

Primary source links, pinned to the baseline:
- [Logger contract](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/logger.dart), [LogEvent](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/log_event.dart), [AppLogger](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/app_logger.dart).
- [Sync event policy](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/events/sync_events.dart), [Cloudinary event policy](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/events/service_log_events.dart), [command reporting](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/command_configuration.dart).
- [Sentry startup](https://github.com/xmattjus/moliseis/blob/3246b04/lib/main.dart), [bootstrap and consent](https://github.com/xmattjus/moliseis/blob/3246b04/lib/config/bootstrap.dart), [tracing adapter](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/run_traced_result.dart).
- [Draft persistence](https://github.com/xmattjus/moliseis/blob/3246b04/lib/data/repositories/content_submission_draft_repository_impl.dart), [route event](https://github.com/xmattjus/moliseis/blob/3246b04/lib/ui/core/ui/route_error_screen.dart), [event definitions](https://github.com/xmattjus/moliseis/blob/3246b04/lib/utils/logging/events/core_events.dart).
- [Sentry transport fixture](https://github.com/xmattjus/moliseis/blob/3246b04/test/support/recording_sentry_transport.dart), [logger tests](https://github.com/xmattjus/moliseis/blob/3246b04/test/utils/logging/app_logger_test.dart), [SDK boundary test](https://github.com/xmattjus/moliseis/blob/3246b04/test/utils/logging/sdk_boundary_test.dart), [PR CI](https://github.com/xmattjus/moliseis/blob/3246b04/.github/workflows/pull-request.yml).
- Canonical [application-observability](https://github.com/xmattjus/moliseis/blob/3246b04/openspec/specs/application-observability/spec.md), [sentry-consent-lifecycle](https://github.com/xmattjus/moliseis/blob/3246b04/openspec/specs/sentry-consent-lifecycle/spec.md), and [session-replay-privacy](https://github.com/xmattjus/moliseis/blob/3246b04/openspec/specs/session-replay-privacy/spec.md).

The canonical specs, not earlier review summaries, are the compatibility baseline. The planning change modifies only `application-observability`; other capabilities retain their authority. Before implementation, compare the execution checkout/HEAD and relevant package versions with this baseline and reconcile drift.

### Observed implementation behavior

`Logger.log(event, {error, stackTrace, extra})` is the sole application-facing logging method. `LogEvent` is a sealed typed hierarchy with `name`, `level` and `data: Map<String, Object?>`. `AppLogger` checks `minLevel`, builds `{...event.data, ...extra}`, calls Talker synchronously, and—when its Sentry flag is enabled and severity is at least info—adds a breadcrumb asynchronously.

For generic error/critical events, an attached non-null `error` causes `Sentry.captureException`. Sync and a fixed group of Cloudinary/submission/Admin events instead use special-case typed fields and (when reportable) a synthetic `SentryEvent` with `SentryException` and a cleared scope. `SyncFailure.report` may lead to a synthetic capture without an attached cause, while `CloudinaryRequestFailed.report` requires an attached error and excludes validation/file-read categories. The global command handler separately routes unexpected throws. These policies **must not be flattened mechanically**.

The production Sentry options use `SentryTraceLifecycle.stream`, existing sample rates, `sendDefaultPii=false`, `maskAllText=false`, `maskAllImages=false`, and a `beforeBreadcrumb` function that tries to filter framed Talker console fragments. The code does not explicitly disable `enablePrintBreadcrumbs`. Sentry initialization is conditional on persisted crash-reporting consent, with runtime opt-in deferred and opt-out invoking SDK shutdown under the separate lifecycle contract. Other sources may emit telemetry independently of `AppLogger`, including the Sentry/Supabase HTTP wrapper and automatic SDK integrations.

A concrete call-site hazard exists: `saveDraft` evaluates `state.toString()` *before* invoking the logger, both before persistence and after `putAsync`. A failure in this optional diagnostic expression could suppress a write or return `Result.error` after a successful write. This is a plausible failure mode from the control flow, not an observed production incident.

## Target invariants

1. **One stable application entry point.** Prefer preserving `Logger.log` and the existing event hierarchy; do not add three public logger methods unless characterization demonstrates a material benefit. Talker remains local; Sentry remains remote.
2. **Severity is not reporting intent.** Error-level events can remain local or breadcrumb-only; reportable failures require explicit typed authorization. Debug/info/warning remain meaningful for local presentation.
3. **No silent legacy migrations.** A conservative `localOnly` default applies to new unclassified events only. Every existing remotely visible event must be inventoried and deliberately classified, preserving or intentionally correcting material diagnostics.
4. **A failure has one application capture owner.** Owner is based on propagation and terminal handling, not just event class. Expected failures need not open Issues; handled-but-reportable failures may. Unhandled errors belong to SDK automatic capture without an extra manual application capture.
5. **Remote reports are useful and bounded.** Original errors/available stacks remain available locally. Remote content is explicitly approved per family, never an arbitrary copied exception string/stack, `extra`, URL, request body, token, email/name, or unrestricted object dump. Safe stack/frame information is desirable where evidenced safe, not categorically mandatory.
6. **Logging is best effort.** Diagnostic work may not change successful/failed business outcomes, written state, retry/compensation behavior, exception identity or propagation. This covers construction of diagnostic arguments at call sites as well as synchronous and asynchronous backend operations.
7. **Required breadcrumbs are observable in the serialized report.** Do not prescribe `await` for each breadcrumb; establish the actual behavior using envelope-level tests, including isolated scope paths and controlled delay/interleavings. Scope privacy takes priority over ambient breadcrumb retention.
8. **Console frames are not telemetry.** Disable automatic print/debugPrint breadcrumbs and retire Talker-shape filtering once confirmed safe; explicit app breadcrumbs, SDK crash capture, tracing and Replay remain governed by their existing contracts.
9. **No parallel telemetry policy.** Preserve persisted consent/bootstrap/shutdown and targeted Replay masks under their canonical capabilities. `localOnly` means only that this logger does not forward the event: it does not promise invisibility to separate SDK integrations.
10. **Proportionate enforcement.** Extend the existing static gate and real transport tests; constrain agent guidance only after the logger contract is finalized. No new packages, ad hoc middleware layer, global deduplication, new CI workflow, or arbitrary Unicode capture without evidence.

## Proposed boundary and policy matrix

`RemotePolicy` with values `localOnly`, `breadcrumb` and `report` is the preferred smallest candidate. The final declaration site (event getter, typed descriptor, or equivalent), and any category-dependent policy, must be resolved from the migration inventory. This is a **candidate design**, not authority to introduce a new abstraction before the gate is closed.

Baseline-compatible policy behavior to evaluate and lock:

| Policy | Attached cause? | Local (passes minLevel) | App breadcrumb (flag enabled) | App exception/event capture (flag enabled) |
| --- | --- | --- | --- | --- |
| localOnly | either | yes | no | no |
| breadcrumb | either | yes | yes, with approved fields and applicable remote level gate | no |
| report | yes | yes | only when required by the report's approved context contract | one safe, owned capture |
| report | no | yes | only when required and approved | only for explicitly reviewed cause-less diagnostic reports; otherwise zero |

Rules to preserve until characterization justifies a specific, documented change:
- `minLevel` currently filters the **entire** `log()` operation before local or remote work. Keep this initially; separately evaluate whether suppressing a report on severity filtering is undesirable.
- Existing debug events have no app-originated Sentry breadcrumb under the present remote level gate. Do not silently promote their remote visibility.
- A report may be synthetic *when deliberately chosen* (e.g., the existing cause-less sync report); the mere label `report` must not fabricate a meaningless exception.
- The existing sync category `connectivity` is not reportable; existing Cloudinary `validation` and `fileRead` exclusions and the handled `FileSystemException` case in upload command reporting need explicit representation at their ownership boundary. Do not add a second mutable report flag unless a concrete use case requires it.
- For any change in capture counts, exported fields, or important breadcrumb coverage, record a before/after classification and rationale. `localOnly` does not turn off SDK-generated uncaught error telemetry or Replay.
- Separate `extra` from remote data completely. Do not change local merge precedence solely to achieve this: overriding event fields in the *local* record is an independently reviewable behavior.

### Event migration inventory (characterization deliverable)

For each event previously eligible for remote forwarding, record: name, level, call site, owner, current local/breadcrumb/capture behavior for cause present/absent, approved target intent, data keys/size/possible private values, and whether a later failure report relies on that breadcrumb. Cover core, network, repository, persistence, sync, Cloudinary, content submission, Admin and command events; group truly equivalent low-value cases but do not assume all error-level events warrant Issue creation.

High-impact explicit cases:
- `SyncStarted`, `SyncFinished`, `SyncFailure`; separate returned `Result.error`, raw throws via `SyncViewModel.sync`, and post-commit settings failure.
- `CloudinaryUploadRetry`, `CloudinaryRequestFailed`, `CloudinaryUploadCompleted`, `CloudinaryDuplicateDetected`, and `CloudinaryUploadCancelled`; distinguish successful POST vs reuse, preflight vs terminal client failure, and expected cancellation.
- Public `ContentSubmissionUploadFailed`, confirmation/replay events, Admin association/replay/ambiguous outcome, and global command failures; avoid second reporting owners.
- `ContentSubmissionDraftSaveStarted` and `ContentSubmissionDraftSaveSuccess` with `state.toString()`: remove unnecessary remote noise and fallible pre-rendering.
- `RouteErrorScreenShown`, `ImageLoadFailed`, `UrlLaunchFailed`, network-related events and coordinate-bearing events: inspect raw URI/query, signed URL, exception text, location precision and useful diagnostic alternatives before forwarding.

## Error ownership and diagnostic representation

Classify failures by their actual path: originating boundary; expected vs unexpected classification; propagation as `Result.error` or throw; terminal owner; any previously initiated capture; possible SDK auto-capture. One underlying terminal failure within one operation must have at most one application-initiated remote capture unless an explicitly justified exception is documented. A second independent operation may legitimately report an equal-looking exception; never deduplicate globally by object identity.

Sync's known contract remains: terminal phase and fetched counters truthful; thrown objects/available stacks preserved locally; expected connectivity stays out of app captures; an unexpected sync throw reaching `command_it` is owned by the global command reporter. Cloudinary's request token already has a single terminal reporting gate; no retry or cancellation may become a spurious terminal capture. Content submission and Admin ownership require explicit path mapping before changing capture policy. `runTracedResult` must never become an exception reporting owner.

For a small representative set (sync expected connectivity, unexpected command failure, Cloudinary terminal HTTP/transport, submission/Admin association rejection vs ambiguity, and one UI route/image failure), specify the minimum data needed to localize a fault: operation/phase, controlled failure category, status where grounded, whether server acknowledgement is definitive, safe technical origin, and any safe stack/location information actually available. Check that at least two distinct causes with equal categories remain distinguishable where troubleshooting requires it. Preserve raw `error` and stack locally; do not assert original remote stack or historical Sentry grouping without an inspected serialized envelope or Issue evidence.

Privacy controls operate on **all transmitted fields**: exception type/value/frames, breadcrumbs and their data, contexts, request/HTTP integration data, tracing attributes and automatic SDK event sources. A substituted `SentryException.value` alone is insufficient. Prefer explicit bounded fields and small reviewed exception representations; avoid generic catch-all sanitization. The existing `scope.clear()` protects from ambient untrusted data but can also remove desired diagnostic breadcrumbs: test the final envelope, preserve only approved context if needed, and do not disable that isolation reflexively.

A user agreeing to submission terms is not automatically consent for pre-submission crash telemetry. Keep crash-reporting consent separate, follow canonical Replay contributor-name/email masks, and do not introduce an automatic excerpt of editorial text to reproduce malformed Unicode. Reproduce a real parsing failure first; if none is found, defer exact-input reproduction without blocking logger simplification. Neither planned nor existing Replay configuration is a legal compliance determination.

## Failure isolation and sequencing

Inside the logger, isolate synchronous event accessor/rendering and Talker calls, synchronous exceptions thrown while starting Sentry work, and asynchronous completion errors. An error in one sink must not suppress an otherwise valid attempt in the other when the data for it are available. Avoid recursive diagnostic reporting, background retry queues, or swallowing business exceptions in application code. Prefer small independent guarded operations over one blanket catch around the whole method.

At call sites, diagnostic arguments are evaluated *before* `log()`. Audit and remove fallible conversions (e.g., `state.toString()` before/after `putAsync`) rather than wrapping every log in a broad `try/catch`. Inject faults into representative pre-write and post-success diagnostic construction and verify unchanged persisted state, results and exception identity.

For breadcrumb ordering, use `RecordingSentryTransport` to inspect the **serialized, delivered event**, not merely the hub scope. Run the real `unawaited(_addBreadcrumb(...))` path and cause/report path without artificial test-side synchronization; include deterministic delayed hooks where feasible. The contract is required context present in causal order in the report. If it already holds, retain `unawaited`. If not, first distinguish SDK sequencing, scope clearing and data policy before introducing the smallest targeted correction. No global ordering or serialization across four concurrent sync preparations is required: their existing deterministic terminal failure selection is a separate invariant.

## Console capture, integrations, consent and Replay

Change the production Sentry option to disable automatic print/debugPrint breadcrumb collection. Only then remove the Talker console-frame heuristic after verification that:
- Talker still displays local error objects and stacks, and no automatic console frames containing them enter subsequent Sentry envelopes.
- Approved explicit app breadcrumbs and required report context survive.
- Unexpected framework/native error capture, stream tracing and Replay remain operational under eligible consent and existing sampling.
- Non-logger automatic channels are characterized independently: SDK navigation, HTTP instrumentation, Supabase client, request URLs (including Cloudinary where instrumented), and other active integrations. Apply a narrowly scoped `beforeBreadcrumb` change only when concrete payload evidence warrants it.
- A private value on a screen masked in Replay may still leak in an unrelated error, breadcrumb, URL or stack payload; these protections are tested separately.

Preserve `bootstrapApplication`, `SetCrashReportingUseCase`, the `SentryLoggingFlag`, transport ownership and runtime opt-in/opt-out semantics. `localOnly` does not prevent SDK automatic reporting of truly unhandled errors. Retain the canonical streaming `startSpan` adapter and installed SDK versions unless the observed behavior requires a narrowly justified compatibility change.

## Agent enforcement and verification boundary

Extend `test/utils/logging/sdk_boundary_test.dart` rather than introducing a second checker. Start with deterministic source checks for unapproved direct `Sentry.capture*`, `Sentry.addBreadcrumb`, `Sentry.logger.*`, `Sentry.configureScope`, `Sentry.startTransaction` and direct Talker creation/use, including alias and file-boundary bypasses actually representable in Dart. Allow explicit bootstrap, consent, tracing adapter, Replay mask, instrumentation and Talker viewer exceptions by file/operation, not a blanket directory escape. Retain negative fixtures and positive authorized-boundary examples. Escalate to AST only after demonstrated regex bypasses cannot be handled reliably.

`.github/workflows/pull-request.yml` includes autonomous `test/**/*_test.dart` except `test/integration/**`, but does **not** discover separate `integration_test/**` files. Verify required-check branch rules separately; a passing job alone does not prove required enforcement. Native Android/iOS consent/Replay behavior requires separate targeted tests or owner evidence under the existing contracts, not false attribution to the autonomous suite.

After finalizing the contract, add a short `AGENTS.md` policy with examples and precedence over generic bundled Sentry SDK skills. A separate project-specific skill is optional; do not create one just to repeat the test contract. Do not commit runtime test dumps, SDK envelopes containing canaries, trial artifacts or temporary audit output.

## Phased execution and explicit gate

### Phase A — characterization (tests/spikes only, no production migration)

1. Revalidate actual HEAD, sources, package versions and spec precedence; identify parallel changes and baseline differences.
2. Build a finite inventory of existing remote-eligible events and failure propagation/ownership paths, including cause-less sync and command/repository ownership.
3. Characterize actual logger/Sentry console capture, envelope contents, breadcrumb causality and scope isolation; test selected automatic integration payloads with synthetic canaries. Collect results using existing fixtures, without shipping canaries or real user data.
4. Probe best-effort behavior in the logger and representative fallible call-site diagnostic construction; distinguish demonstrated faults from potential faults.
5. Define minimum useful, safe remote fields for the high-value failure families; record intentional removals, existing limitations and unresolved legal/production claims as limitations, not invented evidence.

**Gate A must be closed before any application migration**: update this design and tasks within authorized scope with (a) an explicit final policy matrix including missing causes, `minLevel`, breadcrumb-on-report rules and category-dependent decisions; (b) an existing-event classification/exception list; (c) per-path report owner mapping; (d) agreed remote fields and minimum diagnostic usefulness; (e) the call-site best-effort boundary; (f) required breadcrumbs for scope-cleared captures; and (g) narrowly scoped test outcomes/known unknowns. Do not silently choose an architecture or sanitize payloads speculatively. If material uncertainty cannot be resolved from a test or an approved product/privacy rule, stop the affected implementation and obtain a decision; unrelated proven work need not stop.

### Phase B — implementation after Gate A

Implement only the approved, smallest contract: refine event types as needed, separate local/remote payloads, remove severity-implied report capture, consolidate legacy switches where behavior allows, protect logging sinks and call sites, disable print breadcrumbs, adjust only proven problematic automatic channels, extend contract tests and SDK boundary enforcement. Keep `Logger.log`, tracing, consent and workflows unless evidence supports an exception. Update tests that encode intentionally retired behavior, but never loosen privacy/outcome assertions to make them pass.

### Phase C — verification, publication and later archival

Run focused tests and the full applicable Flutter test suite, analyzer and formatter, and strict OpenSpec validation in the actual development checkout. Inspect the branch diff, no unintended files, and compare against mainline. Record concise verified evidence in the PR review process (not transient files in Git). Native tests and real Sentry Issue/Replay inspection are separate, provenance-tagged acceptance where required; do not claim they ran in ordinary CI.

The planning PR contains only the five change artifacts. Future source code changes, AGENTS changes, canonical spec sync, archival, merge and deployment require their own authorization and appropriately scoped PR/delivery step.
