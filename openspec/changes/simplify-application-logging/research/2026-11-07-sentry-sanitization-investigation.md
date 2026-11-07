<!--
Molise Is — PR #33 archival evidence (sanitized copy of REPORT.md)
Source archive: moliseis-pr33-investigation-20261107.zip
Original REPORT.md SHA-256: 8d2fd463d6f0a8a2c01ccb89fbe7cc93b395194f1010541689356a1e35b84a00
Anonymization: replaced local temporary paths, simulator identifier, and
synthetic DSN identifiers. The original raw archive (envelopes, fixtures,
logs and SDK source snapshots) is NOT included in this document.
This is a historical evidence report, not evidence that the experiments
have been rerun at the current branch HEAD or on deployed systems.
-->

# PR #33 — necessity of application-level Sentry sanitization

Investigation date: 7 November 2026. Experimental investigation only; no remediation.

## A. Executive findings

1. **Typed projection (A), bounded exception substitution (B), and disabling print breadcrumbs (F) have demonstrated privacy value beyond `sendDefaultPii=false`.** Removing each independently exposes synthetic application content in serialized telemetry. `beforeSend` does not repair an approved payload that was already constructed from unsafe fields.
2. **Scope clearing (C) overlaps final restoration (D) for the event fields tested.** Removing C alone leaves poisoned user/tags/extras/contexts absent when D remains. Removing both exposes them. C also removes scope attachments, which are collected outside the event after `beforeSend`; an attachment capability control exposed content when C alone was removed. The app has no inspected `addAttachment` wiring, so this is a boundary capability, not a demonstrated current attachment leak.
3. **D has demonstrated processor-boundary value:** the installed native-context processor can reintroduce user/tags/extra/context and replace selected app breadcrumbs after C. Controlled native-binding inputs demonstrate this behavior; they do not establish that a real native SDK normally creates those particular private values. D also drops benign technical information; the usefulness/privacy tradeoff is not uniformly justified by those canaries.
4. **There is demonstrated synthetic exposure without custom protection, and automatic Dart/native SDK boundaries remain outside the app-owned callback.** An actually unhandled Dart error retains its original message and parsed stack in the final event, with and without the app callback and with PII disabled. A real iOS native NSError control also sent its synthetic description fields to loopback with zero Dart beforeSend invocations. No real-user disclosure was investigated or claimed.
5. **Diagnostic loss is material.** App reports retain operation/repository/category/known cause/status/backend-code information but remove original stack locations and message distinctions. Two different `FormatException`s at different files/lines yield identical app exception type/value. This is observable payload equivalence, not proof of server-side Issue grouping.
6. **There is evidence for narrower future simplification, not for removing the sanitizer wholesale.** Supabase already omits query/body values under the current setting; duplicated event-field clearing and wholesale removal of technical context deserve separate review. No tested replacement simultaneously preserves every privacy boundary and restores stack usefulness. Useful local Talker objects and stacks should remain intact.

## B. Verified baseline

### Repository and drift

- Repository: `xmattjus/moliseis`; open [PR #33](https://github.com/xmattjus/moliseis/pull/33), title `fix(logging): isolate diagnostics and own reports`.
- Actual PR base: `main`, **3246b04c8518aef235eab016f42beca4a4fd7bc6**.
- Actual PR head and local HEAD: **03cd3eb6d854ad45ef1335638f61749babe9639b**.
- Branch: `codex/simplify-application-logging`. No HEAD drift from the supplied observation. The live base was fetched rather than inferred from a tracking ref.
- Initial checkout status: `?? harden-imported-asset-persistence-and-cleanup.zip`. That unrelated file was preserved.
- Experiments used a **disposable `git archive` snapshot**, an equivalent isolated environment without `.git`, at `<TEMP_WORKSPACE>`. Historical code ran in a separate archive of the exact base. Neither snapshot reads production configuration or starts production `main()`.

### Active production configuration

Verified in `lib/main.dart:79–110`, `lib/config/bootstrap.dart:21–48`, `lib/utils/http_client.dart:15–44`:

| Setting | Current value / wiring |
|---|---|
| SDK initialization | `SentryFlutter.init`, only after stored consent resolves enabled |
| PII | `sendDefaultPii=false` |
| Console breadcrumbs | `enablePrintBreadcrumbs=false`; no app `beforeBreadcrumb` hook |
| Event finalization | `beforeSend=AppLogger.beforeSend` |
| Tracing | stream lifecycle; sample rate debug 0, production 0.4 |
| Replay | session sample debug 0/production 0.4; on-error debug 0/production 1.0 |
| Replay global privacy | text/images globally unmasked, with existing selective contributor masks |
| Supabase | `SentrySupabaseClient(client:httpClient, enableErrors:false)`; default breadcrumbs/tracing remain enabled |
| General app HTTP | Cronet on Android, Cupertino on iOS/macOS, IO fallback; not wrapped in general `SentryHttpClient` |
| SDK `options.httpClient` | SDK networking transport client, not automatic instrumentation of every application HTTP request |
| Automatic attachments | screenshot/view-hierarchy defaults false; no application attachment producer found |

Native SDK pins inspected in the installed Flutter package: Cocoa **9.27.0** (`darwin/sentry_flutter/Package.swift:17`) and Android **8.56.0** (`android/build.gradle:65–66`); Android runtime was not executed. Lockfile and resolved package sources agree: `sentry`, `sentry_flutter`, `sentry_supabase` **10.0.0-rc.2**; Talker/Talker Flutter/Talker Logger **5.1.20**; `command_it` **9.5.2**. No dependency changed.

Host: macOS 26.5.2, arm64; Flutter **3.47.5**, framework revision `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`; Dart **3.13.4**. Host tests run in `flutter_tester`; they are not native-device tests. Native availability and execution are reported under T10.

The supplied configuration assumptions were accurate. Additional distinctions established here: the general Sentry HTTP wrapper is absent; absolute Dart stack directory paths already receive SDK filtering; the application callback intentionally excludes SDK-owned events; scope attachments are outside the final event object.

### Inspected files

Application: `lib/main.dart`; `lib/config/bootstrap.dart`; `lib/utils/http_client.dart`; `lib/utils/command_configuration.dart`; `lib/utils/logging/{app_logger,log_event,logger,sync_failure_category}.dart`; event definitions under `lib/utils/logging/events/`; route/image logging callers; `lib/data/core/base_sync_repository.dart`; `lib/data/core/supabase_sync_cursor_source.dart`; repository error call sites, including event/place/media/search and draft persistence; PR changes to upload-preparation errors. The relevant full PR diff is included as `pr.diff`.

Planning: `openspec/config.yaml`; `openspec/changes/simplify-application-logging/{proposal,design,tasks}.md` and its `specs/application-observability/spec.md`; canonical `application-observability`, `sentry-consent-lifecycle`, `session-replay-privacy`. These are context, not evidence that behavior works. No specification was changed or archived.

Existing tests/support: `diagnostic_payload_test.dart`, `native_enrichment_test.dart`, `talker_console_privacy_test.dart`, `supabase_reporting_test.dart`, relevant `app_logger_test.dart`; `RecordingSentryTransport`, `NativeContextBinding`, logging faults, mock Supabase, ObjectBox store and loopback helpers. Relevant installed SDK sources are copied into `sdk_sources/` with exact paths and SHA-256 hashes in `sdk-source-manifest.json`.

SDK source roots below use `S=sentry-10.0.0-rc.2/lib/src`, `F=sentry_flutter-10.0.0-rc.2/lib/src`, `SB=sentry_supabase-10.0.0-rc.2/lib/src`, all relative to the installed pub cache or the copied `sdk_sources/` directory. Line ranges are inclusive source references, not claims of executed behavior unless a test is named.

## C. SDK data handling matrix

### Verified event processing order

1. Hub creates an event containing the throwable and clones scope when a per-event callback is supplied: `S/hub.dart:87–175`.
2. Client `_prepareEvent` converts the throwable and stack, applies basic metadata: `S/sentry_client.dart:140–144,250–361`; `S/exception/sentry_exception_factory.dart:18–86`.
3. Scope merges user, tags, extras, breadcrumbs, contexts, fingerprint, level and trace; scope processors run last: `S/scope.dart:399–460`.
4. Option processors run: `S/sentry_client.dart:157–162`. Flutter registers its processors/integrations in `F/sentry_flutter.dart:144–223`. Supported native-context enrichment is an event processor and therefore runs here, after scope: `F/enrichment/load_contexts_integration.dart:155–257`.
5. SDK handles default IP assignment: `S/sentry_client.dart:364–375`.
6. `beforeSend` runs, then event sampling and the pre-send lifecycle callback: `S/sentry_client.dart:169–204,546–592`.
7. Scope/hint attachments and correlation envelope metadata are collected; event becomes an envelope and reaches transport: `S/sentry_client.dart:206–237`; `S/envelope/sentry_envelope.dart:34–65`.

This is the **Dart event pipeline**. It is not an assertion that autonomous native events, streaming spans or Replay payloads traverse the same callback.

| Data category | SDK protection | Application protection | Actual active path | Evidence |
|---|---|---|---|---|
| Exception message | `toString()` becomes exception value; no generic PII classification | B substitutes bounded type/value for app reports | App reports and automatic Dart errors | T01/T02; `S/exception/sentry_exception_factory.dart:63–86` |
| Dart stack directories | Non-package/non-dart absolute path reduced to basename | B omits all original frames | Automatic Dart and direct exception capture | T01/T02; `S/stack_trace/sentry_stack_trace_factory.dart:167–182` |
| Stack filename, function, package, line/column | Preserved after parsing; no PII-based removal of arbitrary filename | B removes original stack in app reports | Same | T01/T08; same factory `:116–163` |
| Explicit user id/email/IP/data | `sendDefaultPii=false` prevents default IP assignment; it does not remove explicit user fields | C clears cloned scope, D excludes enriched user | Explicit scope API is SDK capability; app-owned isolation is active | T06 direct positive control; `S/scope.dart:399–403`; `S/sentry_client.dart:364–375` |
| Tags/extras/custom contexts | Ordinary explicit values merge without generic scrubbing | A excludes raw event fields/extra; C/D isolate app reports | Logger and SDK scope | T02/T03/T06; `S/scope.dart:399–455` |
| App breadcrumbs | No semantic classification of arbitrary message/data | A projects fields; sync history reprojected; D restores selected history | App logger | T03/T06/T09; app `:149–161,443–507` |
| Talker console output | Zone print and Flutter debugPrint interception are configurable | F disables both through option; local Talker retained | Talker and Sentry integrations | T07; `S/zone/sentry_run_zoned_guarded.dart:43–86`; `F/breadcrumbs/debug_print_integration.dart:17–39,49–59` |
| Supabase query/body | Breadcrumb/context/body acquisition gated by `sendDefaultPii`; SQL placeholders preserve operation without values | App projection protects separately logged causes, not the integration's own spans | Supabase breadcrumb/tracing active; auto errors disabled | T04; `SB/sentry_supabase_breadcrumb_client.dart:24–47`, request `:24–62,87–122`, tracing `:63–123`; body also gated by `S/sentry_options.dart:128` default never |
| Supabase server HTTP error details | Enabled error wrapper builds a status exception, not response detail text; thrown errors may carry raw text | `enableErrors=false` removes independent reporter; A/B handle app-owned cause | Current errors reported by application owner | T04; `SB/sentry_supabase_error_client.dart:23–84` |
| General HTTP URL/query/header | `SentryHttpClient` sanitizes named security headers and separates query from URL, but query values are retained | No general app HTTP wrapper; app route/image projections remove their own URLs | Wrapper is SDK-only capability; raw app client exercised separately | T05; `S/utils/http_sanitizer.dart:8–60,83–91`; `S/protocol/sentry_request.dart:94–117` |
| Device/OS/app/runtime metadata | Hostname and executable/script/arguments are PII-gated; OS/runtime/culture/counts are not uniformly gated | D keeps selected OS/app version and trace IDs; drops device/runtime/culture and other fields | Dart host enrichment and native-context processor fixture | T02/T06/T08; `F/enrichment/load_contexts_integration.dart:155–257`; `S/platform/io_platform_context_provider.dart:45–50`; `S/enrichment/io_enricher_event_processor.dart:85–105` |
| Attachments | Collected from scope **after** beforeSend; not classified by PII switch | C clears scope attachments; D clears hint attachments/screenshots/view hierarchy | No app attachment producer found; capability control only | T06 attachment probe; `S/sentry_client.dart:206–221`; `S/scope.dart:332–350` |
| Trace/span payloads | Supabase uses parameterized query and origin-only DB URL | App event beforeSend is not a span sanitizer | Streaming Supabase spans active when a parent exists | T04; `SB/sentry_supabase_tracing_client.dart:63–123` |
| Native-origin NSError | PII-off did not remove synthetic description fields in observed iOS event | Dart app callback not invoked | Native SDK-only test adapter using real configured Cocoa pipeline | T10 actual loopback envelope; no automatic-crash claim |
| Replay | Separate acquisition and native transport; event lifecycle may trigger Replay flush | Existing selective masks; app beforeSend does not sanitize recording payloads | Replay configured in production | Source-derived only here: `F/replay/replay_integration.dart:37–45,91–115`; `F/replay/network_details_capture.dart:80–115,161–164`. No Replay privacy verification claimed |

## D. Test construction and actual results

### Shared protocol, commands and comparison definitions

Every host experiment used an explicitly fake DSN (`https://<SYNTHETIC_PUBLIC_KEY>@example.invalid/1`, or equivalent `.test`), a local `RecordingSentryTransport`, synthetic inputs and either mock HTTP or loopback. Sentry did not use a real ingestion destination. `sendDefaultPii=false`, print breadcrumbs disabled and `AppLogger.beforeSend` were the production-relevant baseline unless a test explicitly changed one. Release/environment were synthetic where set. For T01 and Supabase PII comparisons, test-only final hooks consistently replace unrelated host-name metadata with a synthetic value; they do not alter asserted private application fields. Host fixtures use `Sentry.init` (and, where necessary, `SentryFlutterOptions` plus installed Flutter integrations), not the credential-bearing application entry point. `automatedTestMode=true` makes SDK failures observable; it is a test option, not production configuration. Sampling is deterministic for tests; Supabase tracing uses rate 1 rather than production 0.4 so acquisition has a positive control.

Primary event evidence is a delivered envelope serialized through `envelopeStream`, including its event item. Assertions do not rely only on the event processor's earlier object. Span-callback evidence is labelled separately from final transport evidence. `.envelope` files retain synthetic values; this report replaces private-looking values with `<EMAIL>`, `<TOKEN>`, `<QUERY>`, `<TEXT>`, `<FILE>`, `<SCOPE>`, `<NATIVE>`.

- **A/current:** original AppLogger plus current callback.
- **B/SDK baseline:** genuine SDK automatic/direct capture with PII off and no app sanitizer; normal SDK-owned events with the callback are also tested.
- **C/projection:** copy of current logger changes only `diagnostic.data` to actual `event.data`; report eligibility, exception substitution, isolation and final callback retained.
- **C/raw:** copy changes the exception list to the installed SDK's `SentryExceptionFactory.getSentryException(original, stackTrace: originalStack)`. The original stack is threaded through the private method. All projection/isolation/finalization remains. This is a controlled raw representation, not a second automatic-capture test.
- **C/scope:** removes only scope clearing/context removals; breadcrumb selection retained; final callback retained.
- **C/no-final:** disables only `beforeSend`; current logger retained.
- **C/no-final-no-scope:** explicitly a two-factor positive control to locate overlapping protections, not single-factor attribution.
- **D/historical:** exact base snapshot, original logging implementation and same generic route event. It is deliberately separate from B and single-factor ablations. Print interception is disabled for this comparison to avoid conflating console effects.

Fixture paths in the evidence bundle: `fixtures/tests/investigation_core_test.dart`, `investigation_http_console_test.dart`, `investigation_supabase_test.dart`, `investigation_historical_test.dart`; support includes the three generated ablation logger copies and `investigation_core.dart`. Existing fixtures are in the repository paths named below.

Executed commands, in the HEAD disposable snapshot unless stated otherwise:

```text
C1 flutter test --no-pub --reporter expanded test/utils/logging/investigation_core_test.dart
C2 flutter test --no-pub --reporter expanded test/utils/logging/diagnostic_payload_test.dart test/utils/logging/native_enrichment_test.dart test/utils/logging/talker_console_privacy_test.dart test/utils/logging/investigation_http_console_test.dart
C3 flutter test --no-pub --reporter expanded test/utils/logging/supabase_reporting_test.dart
C4 flutter test --no-pub --reporter expanded test/utils/logging/investigation_historical_test.dart
   [C4 executed inside historical base snapshot]
```

Final observed results: **C1 19/19 PASS**, **C2 22/22 PASS**, **C3 9/9 PASS**, **C4 1/1 PASS**. T04's additional command and T10 are detailed in their sections. These are test-case counts, not capture totals or server Issue counts.

Initial observations are preserved: ordinary Flutter invocation could fail before startup on shared SDK cache permissions; direct snapshot invocation failed on cache lockfile write permission. Authorized execution with writable SDK cache resolved startup. Initial core compilation failed because this SDK requires an `EventProcessor` object rather than a callback and `configureScope` returns `FutureOr<void>`; the disposable fixtures were corrected, not production. The first combined run had three experimental Supabase assertion/setup failures plus nine existing Supabase setup failures from missing `libobjectbox.dylib`. The original local library was copied into the snapshot, after which C3 passed. Console probe's first early envelope assertion was test timing; it was corrected to await the existing delivery helper. No privacy expectation was silently weakened; T04 explains its initial assumptions.

### T01 — genuinely unhandled Dart exception

- **Objective/hypothesis:** determine whether PII-off or app beforeSend removes private message/stack from automatic capture.
- **Source/components:** `investigation_core_test.dart`, tests `T01 unhandled ...`; installed SDK run-zoned guarded integration, exception and stack factories, live processing and recording transport.
- **Input:** `StateError` containing synthetic email/JWT-shaped text; a syntactically valid two-frame stack with a synthetic contributor filename at line 42 and a package frame at line 88. No real identifiers.
- **Trigger:** scheduled microtask calls `Error.throwWithStackTrace`; genuinely unhandled inside the SDK error zone. Completion is observed through the SDK's error callback; no direct `captureEvent` substitutes for this scenario.
- **Configuration/variants:** PII false/true × app beforeSend on/off; print capture off in all four.
- **Interception/assertions/command/result:** final serialized envelopes, original throwable identity, handled=false, message and filename/stack present; **C1, PASS**, exactly **one event per combination**, no application breadcrumbs.
- **Fields:** `exception.values[0].value = "Bad state: <EMAIL> <TOKEN>"`; mechanism `{type:runZonedGuarded,handled:false}`; `stacktrace.frames` retained `filename=<FILE>.dart`, `abs_path=<FILE>.dart`, function and line 42/column 7 plus package frame at 88/4. Absolute contributor directories were absent because the SDK stripped them.
- **Proves:** automatic Dart capture and private message/filename survive the PII switch; callback's approved-hint check leaves this event intact; removing app sanitizer makes no relevant difference to this path.
- **Does not prove:** direct Flutter framework or PlatformDispatcher capture on a mobile runtime, native crash handling, real-user occurrence, or server grouping. Production Flutter may select a different automatic entry integration; this test proves the installed automatic Dart route.
- **Evidence:** `T01-false-true.json`, `T01-false-false.json`, `T01-true-true.json`, `T01-true-false.json` and matching envelopes.

### T02 — handled exception through AppLogger

- **Objective/hypothesis:** attribute privacy differences to projection, exception representation and isolation, separately from reporting count.
- **Source/components:** `investigation_core_test.dart`, six `T02 T03 T06 T08 variant=` cases; real `RouteErrorScreenShown`, original/current AppLogger or narrowly changed copy, real Talker and SDK factory/transport. Existing `diagnostic_payload_test.dart` additionally executes real failing commands through `configureCommandReporting`.
- **Input/trigger:** actual reportable route event with a query secret and user text; attached `FormatException(<EMAIL> <TOKEN>)`, valid two-frame private stack, local `extra`, poisoned ambient user/tags/extra/context/breadcrumb. Call `logger.log` once per variant.
- **Configuration/variants:** shared baseline A, C/raw, C/projection, C/scope, C/no-final, combined C/no-final-no-scope. D uses actual historical base source with same route fixture and no ambient poisoning.
- **Assertions/interception/commands/result:** serialized envelopes, exact original exception/stack in local Talker, count and private-field presence; **C1/C4 PASS**. **One report and one own breadcrumb per route variant**; historical one report/one metadata-bearing breadcrumb. The command regression captures four commands with distinct approved debug-name/cause combinations.
- **Fields:** A has `exception.values[0]={type:ApplicationFailure,value:route_error_screen_shown::FormatException}`, `contexts.app_diagnostic.cause_type=FormatException`, no original stack. C/raw contains private original value and stack filenames/lines. C/projection contains query/reason in `breadcrumbs[0].data`, both diagnostic contexts, **and** synthetic exception value. C/scope stays clean under D. C/no-final stays clear of the injected scope canary under C but retains normal SDK technical enrichment. Removing both exposes `user`, `tags.private`, `extra.private`, `contexts.private`. Historical contains private exception/stack and breadcrumb URI/reason/local extra.
- **Proves:** raw exception replacement has privacy purpose beyond grouping; projection is independently necessary and finalization is not a content classifier for approved fields. No report-count improvement is attributable to these ablations: count stays one.
- **Does not prove:** every call site, production-frequency impact, historical console behavior (held fixed), or Sentry Issue grouping.
- **Evidence:** `T02-*.json/.envelope`, `historical-run-1.log`, `core-final.log`, existing command tests in `transport-console-final.log`.

### T03 — typed private structured data

- **Objective/hypothesis:** distinguish call-site exclusion, remote projection, final callback and local-only data.
- **Source/components:** core route cases, `T03 other real typed events projection versus current`, and bounded-sync case; actual reverse-geocoding, repository, image, cache and sync typed events.
- **Input/trigger:** synthetic precise coordinates; `EntityLoadFailed('event',method:'getById',extra:{userText:<TEXT>})`; image URL with user-like path/query; cache key; sync breadcrumbs with invalid mode/repository and extra text. Log actual events; then capture an innocuous SDK follow-up to positively observe acquired breadcrumbs.
- **Variants/configuration:** A versus C/projection, baseline PII off and D on. Cache is debug/local only; image emits a safe breadcrumb but no app report. Draft-save event data is already empty in current event definitions/call site (`content_submission_events.dart:235–273`), source-derived attribution rather than a fabricated remote path.
- **Interception/assertions/command/result:** **C1 PASS**. Per A/projection sequence: **two app reports**, each one own breadcrumb, then **one SDK follow-up with three breadcrumbs**. Four original local Talker entries. Bounded-sync fixture: **one report, three projected breadcrumbs**.
- **Fields:** C/projection transmits coordinates and text in `contexts.app_diagnostic`, `failure_diagnostic`, breadcrumb data and exception value; the image URL appears in follow-up `breadcrumbs[2].data.url`. A omits all those private values. Cache key appears locally and never remotely. Current sync projection outputs repository/mode `other`, excludes extra text and HTTP breadcrumb.
- **Proves:** these fields exist on actual typed events before AppLogger; A is the excluding boundary; D merely restores its approved data. This is not Supabase PII filtering. Image data can reach an SDK-owned follow-up if projection is removed even though no image report is made.
- **Does not prove:** a new remote-report path for image/cache, all coordinate-producing call sites, or that an arbitrary local value is automatically a leak.
- **Evidence:** `T03-current.json`, `T03-projection.json`, `T03-bounded-sync.json` and envelopes.

### T04 — Supabase integration

- **Objective/hypothesis:** determine which protection comes from the active SDK integration versus AppLogger, and distinguish event/breadcrumb acquisition from streaming spans.
- **Source/components:** `investigation_supabase_test.dart` (four tests), `investigation_supabase_transport_test.dart` (four independent transport controls), plus existing `supabase_reporting_test.dart` (nine tests). Actual installed `SentrySupabaseClient`, `SupabaseClient`, request parser, breadcrumb/error/tracing wrappers, mock HTTP backend; existing tests additionally use real cursor/city repository/command paths and temporary ObjectBox store.
- **Synthetic input/trigger:** select filter `<QUERY>`, Authorization/private custom header `<HEADER>`, JSON insert `content:<BODY>`, mock HTTP 500 JSON error with `<SERVER_DETAIL>` and `XX000`; explicit native `http.Request` body control as well as normal Supabase builder requests. Successful GET/insert, expected PostgREST/auth/connectivity failures and unexpected StateError are exercised. No database or real endpoint is contacted.
- **Configuration/variants:** production baseline PII=false, error wrapper disabled, request body setting default `never`, stream tracing forced rate 1. Independent 2×2 controls vary PII false/true and body-size `never/always`, changing one gate per comparison. SDK error positive control independently enables only `enableErrors`. App-owned comparison logs an actual typed sync error; existing tests trigger it through real application owners. Stream transport controls use `automatedTestMode=false` to flush final span envelopes rather than relying only on `beforeSendSpan`.
- **Interception/assertions:** final serialized event and span-v2 envelope items; positive table/operation/SQL/span counts; query/body/header/details checked at their exact payload boundaries. Test-only hooks replace unrelated host device-name metadata with a synthetic name in **every** control so retained artifacts contain no incidental machine identity. Those hooks do not modify the asserted request, breadcrumb, error, SQL or canary fields.
- **Commands actually executed:** `flutter test --no-pub --reporter expanded test/utils/logging/investigation_supabase_transport_test.dart test/utils/logging/investigation_supabase_test.dart` (**8/8 PASS**, `supabase-experiment-final.log`); C3 (**9/9 PASS**). C1 plus these eight were also executed together, **27/27 PASS**, `final-core-supabase.log`.
- **Actual observations/counts:** each narrow final-transport cell made two successful requests and emitted **one SDK control event with two Supabase breadcrumbs**, plus **one span envelope containing three spans** (two child DB spans and parent). The broader PII-on/body-always control made select plus two insert paths: **one event with three breadcrumbs**, **one span envelope with four spans**. Baseline success test's four spans were additionally observed at the hook. Expected HTTP 500 with `enableErrors=false` threw PostgREST error to caller but produced **zero error envelopes**, with one active DB breadcrumb; changing only to true produced **one SDK-owned error event**. App-owned typed failure produced **one report/one breadcrumb**. Existing tests observed zero captures for handled connectivity, one safe report for cursor/city/auth failures, one command-owned report for unexpected city fetch throw and real active DB spans/breadcrumbs.
- **Exact relevant fields:** event `breadcrumbs[*].data.table/operation` always present. PII-on `data.query` contains filter `<QUERY>`; PII-off does not. With PII-on **and** body-always, `data.body.content=<BODY>`; body-never omits it. Both builder and explicit Request insert breadcrumbs in the final broader control contained the body under those enabled gates. Serialized span `attributes["db.query.text"].value` is parameterized `SELECT ... WHERE name = ?`; DB operation/table/origin/status present, filter absent. Map body absent from final streamed span attributes even in PII-on/body-always: the source streaming adapter accepts scalar/typed-list attributes but does not accept this JSON Map (`S/telemetry/span/instrumentation/instrumentation_span.dart:143–166`). That is a separate implementation effect, not a generic privacy guarantee. HTTP error control has exception value `Supabase HTTP Client Error with Status Code: 500`, context `supabase={table,operation}` and no server-detail/query/header canary. App error has `CanonicalSyncFailure` and `contexts.app_diagnostic` owner/category/`cause_type=PostgrestException`/`backend_code=XX000`, no server details.
- **Initial failures and investigation:** first assertions expected obsolete key `db.sql.query` instead of actual `db.query.text`, incorrectly expected raw filter values in spans despite SQL placeholders, and awaited 500 as success despite Supabase throwing `PostgrestException`. These were **test assumptions**, preserved in `combined-run-1.log`; corrected assertions follow serialized evidence. A preliminary report that the normal builder body could not be acquired was contradicted by final envelopes; it is rejected here. Existing ObjectBox setup failures were environment-related and resolved by copying the already installed local library into the disposable snapshot.
- **Proves:** current Supabase filter/body protection is provided by SDK gates/defaults, independently of AppLogger; disabling its error wrapper is a reporting-ownership choice, not the query/body scrubber. AppLogger protects the separately logged raw server exception. PII-off does not generically redact arbitrary contexts; T03/T06 remain relevant. Final span envelopes confirm parameterized SQL in the selected stream path.
- **Does not prove:** all REST/RPC/storage/auth URL shapes, every request/body encoding or header family, native span paths, legacy transaction mode, or all Supabase errors globally safe with the error wrapper enabled. The map-body adapter behavior is not a safe reason to remove the PII gate.
- **Evidence:** `T04-transport-*.envelopes`, `T04-pii-on.envelopes`, `T04-sdk-error-event.json`, `T04-app-error-event.json`, `supabase-experiment-final.log`, `supabase-existing-final.log`, initial `combined-run-1.log`.

### T05 — HTTP URL/query handling

- **Objective/hypothesis:** establish whether application HTTP is instrumented at all before attributing a query disclosure to it.
- **Source/components:** `investigation_http_console_test.dart`, two HTTP tests; actual `httpClientFactory(platformClientFactory:()=>null)` IO fallback, loopback HTTP server; separate actual `SentryHttpClient` positive control.
- **Input/trigger:** HTTP GET returning 500, non-sensitive `/public` path plus query secret and Authorization; second case user-like `/user/<PATH>` plus query/header. No outbound service request.
- **Configuration/variants:** PII false, recording transport; actual app-client path versus explicitly added SDK capability. This is an instrumentation control, not an AppLogger ablation.
- **Interception/assertions/command/result:** **C2 PASS**. Raw app-client request produced **zero request events and zero breadcrumbs**. Explicit Sentry wrapper produced **one error event**.
- **Fields:** wrapper control final `request.query_string` includes `<QUERY>`; `request.url` includes user-like `/user/<PATH>`; Authorization is absent from `request.headers`. The failed-request client omits request headers under PII-off (`S/http_client/failed_request_client.dart:189–194`); this observed absence is not attributed solely to the separate named-header sanitizer. Arbitrary query/path content remained.
- **Proves:** SDK HTTP capability can transmit query/path data with PII off. General wrapping is not active in inspected Molise wiring. The independent Supabase wrapper is handled in T04.
- **Does not prove:** absence of iOS native URLSession/Android native telemetry, Cupertino or Cronet runtime behavior, or any current app request exposure through the unused general wrapper. No span acquisition was established for these two HTTP controls.
- **Evidence:** `t05_http_active_client.json`, `t05_http_sdk_only.json`; successful command log `transport-console-final.log`.

### T06 — scope poisoning and post-enrichment restoration

- **Objective/hypothesis:** distinguish ambient scope removal from later native processor enrichment and full-envelope attachments.
- **Source/components:** core scope cases, installed `LoadContextsIntegration` with `NativeContextBinding`, direct scope baseline, artificial processor and attachment tests; existing `native_enrichment_test.dart`.
- **Input/trigger:** explicit synthetic user id/email/IP/properties, tag, extra, custom context and breadcrumb; native fixture supplies user/tag/extra/device/app/OS fields plus HTTP query breadcrumb. A separate artificial processor writes private values after scope. Attachment capability adds a synthetic text attachment to scope. Capture current app report and SDK control.
- **Configuration/variants:** PII false; native processor with D on/off and C retained; C on/off under D from T02; SDK-owned direct control; artificial processor clearly separate; attachment C on/off with D on.
- **Interception/assertions/commands/result:** **C1/C2 PASS**. Native pair: **two events per D setting** (app + SDK). D-on app has **three causal sync breadcrumbs**; D-off app has **one replacement native HTTP breadcrumb**. Direct poisoned SDK event has one explicit poisoned breadcrumb. Attachment pair: one event each, current envelope event-only versus ablated envelope event plus attachment.
- **Fields:** without D, final app event contains `user.id=<NATIVE>`, `tags.native`, `extra.native`, device/app native values and `breadcrumbs[0].data.url` query. With D these are removed while `contexts.os={name:Android,version:16}` and app version/build survive; SDK control retains native canaries either way. Direct scope control retains explicit email/IP and arbitrary user data despite PII off. Artificial processor canary appears without D only. Scope attachment body `<ATTACHMENT>` survives when C is removed despite D, because client attaches scope items after beforeSend.
- **Proves:** real installed processor ordering/mutation behavior and D's restoration; C/D overlap for event fields; C covers attachments outside D's event reconstruction. Existing native fixture tests preserve trace/span/replay identifiers and reject malformed technical-context values after the installed processor.
- **Does not prove:** native SDK naturally acquires the fabricated private values; native-origin crash privacy; actual attachment producer in Molise. The artificial processor is adversarial injection only.
- **Evidence:** `T06-native-*.json/.envelope`, `T06-SDK-scope.*`, `T06-artificial-*`, `T06-attachment-*.envelope`; `native_enrichment_test.dart` executed in C2.

### T07 — local Talker versus automatic telemetry

- **Objective/hypothesis:** local diagnostic retention and automatic console acquisition are different privacy domains; F should prevent only the latter.
- **Source/components:** actual `TalkerFlutter.init`, AppLogger, installed Sentry zone integration and `DebugPrintIntegration`, non-debug runtime checker/Android target override; existing `talker_console_privacy_test.dart` and paired temporary console tests.
- **Input/trigger:** synthetic exception and multiline stack passed to logger; direct `print` and `debugPrint` in existing tests; innocuous SDK-owned follow-up capture. Actual Talker formatter output is observed, not a mock formatter.
- **Configuration/variants:** `enablePrintBreadcrumbs=false/true` with baseline PII false and D enabled. Non-debug checker activates actual SDK release branches; this does not turn host tests into Android runtime tests.
- **Interception/assertions/command/result:** **C2 PASS**. Each paired temporary case produces **two events**: app report with one approved breadcrumb; SDK follow-up with **one breadcrumb when disabled**, **two when enabled**. Original exception/stack identities retained in local history. Current disabled configuration visibly still writes formatted local console output in test logs.
- **Fields:** enabled follow-up contains `breadcrumbs[*].category=console` and its `message` includes the complete multiline Talker output, exception and stack canary. Disabled follow-up has no private console canary. App report remains clean in both because it restores approved breadcrumbs. T01 independently proves the original private error can travel through automatic unhandled capture even when console capture is off.
- **Proves:** F has concrete remote privacy value that D does not replace; local useful error/stack remain available; disabling interception does not disable console output.
- **Does not prove:** OS log storage/access/retention or a native system-log-to-Sentry channel, voluntary sharing UI/upload, or Replay.
- **Evidence:** `t07_print_capture_false.json`, `t07_print_capture_true.json`, `transport-console-final.log`.

### T08 — diagnostic usefulness

- **Objective/hypothesis:** measure actual information loss separately from privacy and server grouping.
- **Source/components:** `T08 two same category errors ...`, T02 and native fixtures; current versus raw SDK-factory representation and no-final control.
- **Input/trigger:** two `FormatException`s with distinct synthetic messages and package source files/lines, identical repository/method; representative route, sync, command and upload failures in executed existing tests.
- **Configuration/variants/interception/command/result:** shared baseline; A versus C/raw, plus D on/off technical context; final envelopes; **C1/C2/C3 PASS**. Two captures per A/raw pair; no deduplication inference.
- **Observed useful fields:** A retains `contexts.app_diagnostic` event/origin/cause, known HTTP statuses/backend codes, one relevant app breadcrumb or current-run sync chronology; release/environment, selected OS version, native-fixture app version/build, trace correlation survive. Representative tests retain 502/422/503 upload status/outcome and XX000 PostgREST backend code.
- **Lost fields:** both current exceptions are exactly `type=ApplicationFailure`, `value=entity_load_failed:event:getById:FormatException`, without stacktrace. Raw variants retain two distinct values, functions, files and line numbers. D also drops actual host Dart/Flutter runtime version, OS build/raw description, culture, processor count and app memory; benign native fixture device model is omitted. There is no canary-based privacy benefit demonstrated for every one of those technical fields.
- **Proves:** reduced discrimination and source localization in app-owned remote reports; no loss of original local Talker exception/stack. The synthetic exception is a privacy boundary **and** an apparent grouping-input policy.
- **Does not prove:** identical Sentry Issues, regression in diagnosis time, safe forwarding of all arbitrary stack frames, or that all dropped native technical fields are harmless.
- **Evidence:** `T08-current.json`, `T08-raw.json`, `T02-current.json`, `T02-no-final.json`, existing diagnostic/native/Supabase logs.

### T09 — deterministic concurrent captures

- **Objective/hypothesis:** a delayed app capture must not corrupt another app capture, destroy shared scope, or acquire another report's approved hint.
- **Source/components:** core `T09 deterministic interleaving ...`; actual async capture withScope, scope cloning and final callback; a controlled processor gate.
- **Input/trigger:** start sync/city report and block it after it enters event processing; while blocked emit media report and await a distinct SDK exception; then release city via completer. Scope carries synthetic private values. No arbitrary sleeps.
- **Configuration/variants/interception/command/result:** A with baseline SDK options and a scheduling-only processor; **C1 PASS**. Exactly **three delivered events**, two app reports and one SDK event. Their arrival order differed from invocation order, as expected for independent async enrichment.
- **Fields/assertions:** city has three causal breadcrumbs and no later media data; media has five same-run approved breadcrumbs ending with its own repository/cause; SDK event has six ambient breadcrumbs, original SDK exception and original poisoned scope. Each app's final diagnostic matches its own last breadcrumb; neither includes scope canary. No missing capture or approved-hint crossover observed.
- **Proves:** tested deterministic interleaving preserves per-report association and chronological selected breadcrumbs and does not globally clear Dart scope.
- **Does not prove:** all schedules, native scope observer ordering, async processor deep mutation, every consent shutdown race, or invocation-ordered transport delivery (not promised).
- **Evidence:** `T09-interleaved.json` and three envelopes; `core-final.log`.

### T10 — Android/iOS native boundary

- **Objective/hypothesis:** verify a safe native SDK boundary on an available platform, rather than infer native delivery from a Dart fixture.
- **Availability:** initial `flutter devices --device-timeout 5` showed only macOS/Chrome; `adb devices -l` was empty. `xcrun simctl list devices available`/`list runtimes` established an installed iOS **26.5** runtime and shutdown simulators. A disposable iPhone 17 Pro simulator was booted for this probe. No Android device/emulator test executed; an AVD definition alone is not runtime verification.
- **Source/components:** temporary `integration_test/t10_native_context_probe_test.dart` and temporary snapshot-only `ios/Runner/AppDelegate.swift` method-channel adapter. Real `SentryFlutter.init`, real Sentry Cocoa **9.27.0**, real iOS simulator native SDK transport, local HTTP ingestion listener. The adapter invokes `SentrySDK.capture(error: NSError(...))`, a native-origin nonfatal SDK error. It does not crash the device or launch credential-bearing production main.
- **Input/trigger:** synthetic NSError domain `T10SyntheticNativeFailure`, code 1, `NSLocalizedDescription=<EMAIL>`. Flutter invokes the temporary method channel. This is a controlled native capture, **not a genuinely automatic native crash**.
- **Configuration:** explicitly fake `http://<SYNTHETIC_PUBLIC_KEY>@127.0.0.1:<PORT>/1` DSN for native and Dart; PII off; app beforeSend installed behind a counter. Final native probe also explicitly disables print breadcrumbs. Debug simulator; production trace/Replay sampling was not reproduced because this focused test does not assess traces/recordings.
- **Interception:** native request bytes arrive only at the loopback listener; gzip is decoded; listener waits for the **matching synthetic NSError domain**, not an arbitrary startup/session envelope. Exact event/session JSON and command output are saved.
- **Assertions/command/result:** `flutter test integration_test/t10_native_context_probe_test.dart -d <IOS_SIMULATOR_ID>` — **PASS, 1/1**. Matched envelope contains **one error event plus one session item**; event has **30 thread records, 31 total native stack frames, one breadcrumb**. The exception itself has no stacktrace interface; the 31 frames are in `threads.values[*].stacktrace.frames`. Native transport reached local receiver. Dart `beforeSend` counter was **0** for this native-origin error. An earlier Dart-only probe is not used here as native-origin evidence. The matched-envelope count does not claim an exhaustive count of unrelated startup/session traffic.
- **Exact relevant serialized fields:** `exception.values[0].type=T10SyntheticNativeFailure`, `.value="Code: 1"`; private canary resides in `.mechanism.data.NSLocalizedDescription`, `.mechanism.description`, and `contexts["user info"].NSLocalizedDescription` — **not** the exception's top-level value. Context keys: app, culture, device, os, trace, user info. The native event additionally includes technical/debug/thread metadata and native user information. Debug simulator native image/frame paths were retained; no inference to release/hardware path shapes is made.
- **Initial failures:** temporary fixture initially failed Dart compilation (part-of import and nullable-list sort). First native assertion looked for plain text in gzip bytes and therefore failed; correcting decompression resolved the observation error. A later ad hoc parser assumed a breadcrumb wrapper shape; event `breadcrumbs` was actually a List. Final native test assertions passed; it was not an application/privacy fix.
- **Proves:** the installed native SDK can transmit synthetic private NSError description fields despite PII off, through real native transport, and this Dart beforeSend callback does not process that event. This extends the boundary finding beyond fabricated native-context fixtures.
- **Does not prove:** Android behavior; hardware; SIGSEGV/NDK/Java fatal error paths, every automatic native error family, native HTTP query acquisition, Replay, shutdown privacy, or production native event frequency/content. **NOT VERIFIED — Android native runtime not exercised; autonomous native crash acquisition not exercised.** iOS runtime was available and the described nonfatal native event was verified, so it is not labelled unavailable.
- **Evidence:** `t10-native-envelope.txt`, `t10-native-run.txt`, `t10-native-run-print-default.txt`, preserved native Dart/Swift adapters. Adapter/source changes existed only in the disposable snapshot and were restored/removed with cleanup.

## E. Ablation results

### Mechanism decomposition

| Mechanism / source | Intended problem and exact fields | Ownership | Existing executed evidence / effect on diagnostics if removed |
|---|---|---|---|
| A: `_remoteDiagnostic`, `_known`, `_repository`, `_errorStatus`, `_causeType` (`app_logger.dart:169–357,510–541`) | Prevent arbitrary local `event.data`/`extra`, repository/command/operation strings, URLs and coordinates crossing remote boundary. Emit selected enum/string identifiers, cause category, numeric status 100–599, allowlisted backend codes. Reporting eligibility lives here too but is a separate policy. | App-owned reports and app breadcrumbs, including breadcrumbs later attached to SDK events | Diagnostic payload and Supabase regressions plus T03. Removal adds private context and may destroy bounded stable identifiers; it does not inherently improve report count. |
| B: `_capture` exception list (`:395–410`) | Original throwable text/stack may contain private content; substitute exception family plus bounded event/data/cause string. | App-owned reports only | Existing command/sync/upload/route tests plus T02/T08. Removal restores diagnostic details as well as private content; no demonstrated loss of useful stack data from removing B, rather the opposite. |
| C: cloned-scope clearing and `_syncBreadcrumbs` (`:425–507`) | Ambient scope can be unrelated; clear user/tags/extra/attachments/trace state and contexts, then select/reproject current-run app sync breadcrumb data. | App-owned per-event scope, not global Dart scope | Existing native/diagnostic tests plus T06/T09. Removing only clearing does not remove the explicitly selected breadcrumb list; deleting all C including reconstruction would lose the tested causal sync history. Our clearing ablation deliberately keeps reconstruction to avoid conflating them. |
| D: `beforeSend`, approved hint and `_technicalVersion` (`:25,35–104,412–424`) | Later SDK/native processors can reintroduce payload. Rebuild event from approved exceptions/contexts/breadcrumbs; retain event ID/time/sdk/platform/release/dist/environment, selected OS/app version/build and selected trace/span/replay linkage; clear hint attachments/screenshot/hierarchy; discard on restoration failure. | Only reports carrying the app's approved hint | Existing native malformed-context/missing-context/correlation tests plus T06. Removal can replace selected causal breadcrumbs; also restores benign technical metadata. Scope attachment collection remains outside this field reconstruction. |
| E: early no-hint return (`:35–37`) | Avoid applying app ownership/payload contract to SDK automatic events. | SDK-owned automatic/direct events | Existing SDK native control and genuine T01. Removing the whole callback leaves tested automatic events unchanged; deleting automatic telemetry instead would lose useful errors and was not tested or proposed. |
| F: `enablePrintBreadcrumbs=false` (`main.dart:88`) | Detailed local Talker output must not be automatically acquired through zone print/debugPrint. | Console acquisition feeding any later event, including SDK-owned | Actual Talker/print/debugPrint tests and T07 pair. Removing F restores remote console chronology, including private original exceptions/stacks; local history remains intact either way. |

### Measured comparisons

| Mechanism | With mechanism | Without mechanism | Measured privacy difference | Diagnostic difference | Assessment |
|---|---|---|---|---|---|
| A. Typed remote projection | Bounded typed fields; raw local metadata retained | `event.data` forwarded with eligibility unchanged | Route query/reason, coordinates, repository user text and image URL enter final contexts/breadcrumbs; some also enter exception value | More raw context, with private content | **DEMONSTRABLY NECESSARY** for tested fields; individual allowlists are not all independently proven necessary |
| B. Exception substitution | Bounded family/type/value, no original frames | Installed factory converts original exception/stack | Original email/token and filename survive PII-off and D | Restores source locations and distinguishes two errors otherwise identical | **DEMONSTRABLY NECESSARY** as a raw-content boundary; exact synthetic family taxonomy/all-frame deletion are not uniquely proven necessary |
| C. Scope isolation | App scope fields/attachments cleared; selected breadcrumbs reconstructed | No scope clear/context removal, D retained | No event-field canary difference under D; synthetic scope attachment leaks in full envelope | Trace IDs/context differ; no measured useful gain in route fixture | **PARTIALLY NECESSARY**: redundant for event fields in verified D paths; independent attachment capability value. Actual native observer effects require separate evidence |
| D. Post-enrichment beforeSend | Approved app payload restored after processors | Native fixture values merged/replacement breadcrumbs retained | Native fixture user/tag/extra/query canaries pass without D; real processor, synthetic input | Preserves intended sync chronology but removes much technical context | **PARTIALLY NECESSARY**: demonstrated processor-boundary protection; individual native acquisition/privacy need is not established for every omitted field |
| E. Preserve SDK-owned telemetry | Hint-less automatic event returned unchanged | Callback omitted in automatic baseline | None: same private automatic exception value/stack in both | Preserves automatic error detail and capture; not sanitization | **REDUNDANT IN VERIFIED PATHS as a privacy protection**; it is an ownership/compatibility policy, not a recommendation to drop automatic events |
| F. Console isolation | No print/debugPrint automatic crumbs | Interception enabled | Actual Talker exception/stack enters SDK follow-up console breadcrumb | Loses console history remotely; local history unchanged | **DEMONSTRABLY NECESSARY** under the tested actual console integrations |

AppLogger policy also controls reporting ownership and noise: local-only events, connectivity suppression, upload file-read/validation behavior and `enableErrors=false` are not interchangeable with payload sanitization. The same report count in single-factor T02 comparisons is evidence against attributing deduplication effects to those sanitizer components.

## F. Material findings

### F1 — Automatic Dart and native SDK events are outside the app-owned privacy boundary

- **Location:** `lib/utils/logging/app_logger.dart:35–37`; SDK `S/exception/sentry_exception_factory.dart:63–86`.
- **Reproduction:** T01, genuinely unhandled synthetic `StateError`, PII off and callback on; T10, native Cocoa NSError capture to the local fake DSN.
- **Serialized evidence:** T01 `exception.values[0].value` contains `<EMAIL> <TOKEN>` and parsed stack contains `<FILE>.dart`/line 42. T10 native NSError retains `<EMAIL>` in mechanism data/description and user-info context; Dart beforeSend has zero invocations for that native-origin event.
- **Impact/severity:** **Medium, conditional privacy exposure** if real application-generated unhandled messages contain private input. The synthetic route is proven; no real-user incident is claimed.
- **Provenance:** preexisting/SDK-dependent behavior deliberately preserved by PR, not introduced by this sanitizer.
- **Minimal reasonable mitigation:** decide an explicit privacy contract for SDK-owned automatic errors before claiming whole-application payload sanitization. If that contract forbids raw private error text, use a separately scoped automatic-event policy; do not remove local causes or stacks. This is a later decision, not implemented here.
- **Verification:** repeat automatic-entry tests with positive controls and inspect final envelopes for each supported runtime; test retention of approved technical diagnostics separately.

### F2 — Typed projection and exception substitution cannot be replaced by PII-off

- **Location:** `lib/utils/logging/app_logger.dart:149–161,169–357,395–410`; relevant typed fields in `core_events.dart:23–41`, `service_log_events.dart:205–230`, `repository_log_events.dart:160–183`.
- **Reproduction:** independent T02/T03 A and raw/projection ablations.
- **Serialized evidence:** projection ablation puts private content in diagnostic contexts, breadcrumb data and exception value; raw ablation puts original text/filename in exception interface.
- **Impact/severity:** **Medium regression risk if these boundaries are removed**. This is a proven protection, not a defect in the current PR.
- **Provenance:** PR adds/extends projection to generic report families; synthetic reports already existed for some base sync/upload families.
- **Minimal mitigation:** retain an explicit bounded remote representation and raw-original local history. Any alternative must pass these same transport comparisons.
- **Verification:** route/geocoding/repository/image positive controls, not only absence assertions on empty telemetry.

### F3 — Final restoration has a real enrichment boundary to address, but broad technical omission has a cost

- **Location:** `lib/utils/logging/app_logger.dart:35–95,425–439`; `F/enrichment/load_contexts_integration.dart:155–257`.
- **Reproduction:** T06 installed native processor with controlled binding, D on/off.
- **Serialized evidence:** D off admits fixture native user/tags/extra/HTTP query and changes three causal breadcrumbs to one native breadcrumb. D on restores three breadcrumbs and excludes fixture canaries. T02 no-final additionally retains benign host runtime/OS/build/culture/device metadata omitted with D.
- **Impact/severity:** **Medium conditional privacy/correctness boundary; low diagnostic-policy cost for benign omitted technical metadata.** Native canary acquisition was synthetic, not proof of real native private collection.
- **Provenance:** SDK-dependent merge behavior; PR's D addresses it.
- **Minimal mitigation:** retain an after-enrichment boundary and approved breadcrumb chronology. A later selective technical allowlist expansion/simplification must be justified field by field; no evidence supports returning every native field unchanged.
- **Verification:** native runtime envelopes, including actual generated fields and distinct native-origin events, with fake loopback destination; do not substitute fabricated contexts for acquisition evidence.

### F4 — App reports lose source-level error discrimination

- **Location:** `lib/utils/logging/app_logger.dart:401–409`.
- **Reproduction:** T08, two same-category exceptions at different files/lines.
- **Serialized evidence:** identical type/value and no stacktrace in A; distinct message/frame identities in raw variants.
- **Impact/severity:** **Medium diagnostic limitation, not a merge-blocking correctness defect.** Remote reports cannot locate or distinguish these errors using the removed fields.
- **Provenance:** preexisting for selected base report families; PR broadens bounded reporting to generic failures.
- **Minimal mitigation:** review whether a bounded stable cause discriminator or approved code location can restore the specific missing diagnostic value. Do not forward arbitrary original text/frames merely because the SDK strips directories. No such alternative was implemented or validated here.
- **Verification:** construct two distinct causes and assert both safe serialization and useful distinction; server-side grouping needs independent evidence.

No production native data leak, real Sentry delivery, real contributor disclosure, or general application HTTP query leak was established. T10 does establish a synthetic native-origin description exposure at a loopback receiver. Scope attachment behavior is a capability limitation, not an active Molise finding.

## G. Recommended decision for PR #33

**KEEP CURRENT SANITIZATION**, with the measured tradeoffs and boundaries documented for the separate review. This is a recommendation to retain the present privacy boundaries, not an assertion that every line is minimal, all SDK telemetry is sanitized, or the PR is otherwise ready to merge.

- **Typed projection:** retain. T02/T03 prove independent privacy value; PII-off and D do not replace it. Reuse already bounded event fields where justified, but do not forward arbitrary metadata wholesale.
- **Synthetic exceptions:** retain a bounded remote exception representation. T02 proves privacy benefit. T08 proves diagnostic cost; the exact family/type/value scheme and removal of every useful frame have not been shown to be the unique minimal solution. A later safer diagnostic improvement requires its own executable comparison.
- **Scope isolation:** retain for this PR pending a narrow simplification review. Event-field clearing overlaps D in host tests, but scope attachments bypass D and native observer behavior is a separate boundary. There is evidence to consider simplifying duplicated field handling, not enough to delete all clearing globally.
- **Post-enrichment beforeSend:** retain an after-enrichment approved-payload boundary. Installed-processor evidence demonstrates why pre-enrichment scope clearing alone is insufficient. Its wholesale technical-context omission is a candidate for a smaller, separately validated allowlist rather than removal of the boundary.
- **SDK-owned automatic events:** preserve their reporting ownership, while explicitly recognizing F1. Leaving them unchanged is neither a privacy guarantee nor permission to transmit arbitrary private content. Decide that residual privacy contract separately; this investigation does not silently broaden the PR.
- **Console interception:** keep disabled. T07 proves a concrete automatic remote path for original Talker data when it is enabled. There is no need to degrade local Talker history.

The tested smallest defensible decision is to keep A/B/D/F, avoid adding a redundant Supabase query scrubber, and treat C/technical context as targeted future simplification candidates. No new logger abstraction, dependency or remediation is proposed or implemented.

## H. Verification limitations

- **Executed:** installed SDK host automatic Dart capture; real logger/Talker/command paths; final event envelope comparisons; HTTP loopback controls; Supabase mock requests; controlled native-context processor; deterministic three-capture interleaving; attachment envelope capability control. T04/T10 detail their additional execution boundaries.
- **Source-inspected:** exact pinned event order, PII gating, HTTP sanitization, Supabase wrappers, Flutter/native-context wiring, Replay lifecycle and network-details gates. Source-derived conclusions are labelled in C.
- **Inferences:** a real exception containing private content would follow the observed synthetic path; different serialized inputs may affect grouping; omitted technical context can be useful. Neither production occurrence nor server classification was measured.
- **Host/native separation:** host tests do not prove Android/iOS autonomous capture or native NSURLSession/Cronet acquisition. Native-binding fixtures only establish merge behavior. T10 is the sole native runtime probe.
- **Concurrency:** one deterministic Dart schedule, not all schedules or native observer races.
- **Server:** no real ingestion, server-side PII scrubbing, Issue grouping, retention, quota, dashboard behavior or deployed configuration observed. A server scrubber is not assumed to protect content leaving the device.
- **Replay:** no recording/pixels or final Replay payload inspected; `beforeSend` is not a Replay sanitizer. Existing selective masks and sampling were inspected, not reaccepted.
- **Local diagnostics:** local console visibility is not a Sentry leak. OS log policy, voluntary diagnostic sharing and user consent UX were outside scope.
- **Acquisition controls:** absence claims rely on paired positive controls where available. No positive native acquisition claim is inferred from empty envelopes.
- **No production equivalence overclaim:** host baseline reproduces relevant options and exact logger/SDK processing, but does not launch full production initialization, credentials, networking, release-mode build or every integration at once.

## I. Repository state

Final checkout status (same as initial):

```text
?? harden-imported-asset-persistence-and-cleanup.zip
```

`git rev-parse HEAD` remained `03cd3eb6d854ad45ef1335638f61749babe9639b`; `git diff --exit-code`, `git diff --cached --exit-code`, and `git diff --check` succeeded. Live PR metadata was fetched again: base/head unchanged and PR still open.

- Production source, tests, canonical/delta OpenSpec files and the unrelated ZIP in the original checkout were not modified by this investigation.
- No commit, push, merge, branch creation, PR creation or publication occurred. The source snapshots were created via `git archive`; no worktree was registered in `.git`.
- Temporary files consisted of two extracted source snapshots, copied package-resolution metadata/ObjectBox test library, generated ablation adapters, synthetic tests/envelopes/logs, iOS build/test artifacts and the temporary native Swift adapter. The Swift adapter was restored in the snapshot before cleanup. The extracted source/build snapshots were removed after evidence packaging; only the explicit report/evidence bundle remains outside version control at `<PRIVATE_EVIDENCE_BUNDLE_PATH>` and its ZIP.
- The iOS simulator booted by the investigation was shut down and verified with `simctl list devices booted`. **The Runner test app remains installed on that simulator; it was not uninstalled because preexisting installation/data ownership was not established.** No simulator app data was deliberately deleted. No Android runtime was started.
- Flutter's shared SDK cache required authorized writes to run the installed tool; no dependency or production configuration was changed. The evidence bundle excludes the copied ObjectBox binary, project build outputs and real configuration/credential files.
- No actual application-user records or real Sentry project credentials were accessed, and synthetic telemetry used only recording transports or local loopback ingestion. PII-on host controls replace incidental machine identity in retained event/span evidence with a synthetic value; all privacy-test canaries remain unchanged.

Final successful focused test counts: 59 host test cases across C1/C2/C3/C4 and the eight Supabase experiment cases, plus one iOS native-origin probe. Initial failed attempts are retained and explained; they are not counted as passes.

Skipped: real-user data, real Sentry delivery, server Issue grouping and Replay recordings. Residual risk: current SDK-owned automatic exceptions can still contain private text despite the app-owned sanitizer.
