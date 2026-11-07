# Design: simplify-application-logging

## Context, chronology and evidence authority

Initial planning on November 5 used main `3246b04c8518aef235eab016f42beca4a4fd7bc6`: logger severity, remote forwarding and special-case reports were mixed; diagnostic rendering could interfere with draft persistence. Gate A selected the typed switch, explicit ownership and best-effort execution. The November 6 closure and implemented migration are retained below as historical decisions, not undone by this revision.

On November 7 the independent [sanitization investigation](research/2026-11-07-sentry-sanitization-investigation.md) tested PR head `03cd3eb6d854ad45ef1335638f61749babe9639b`. Its sections A–I preserve construction, controls, initial failures, actual results, ablations and limitations. This documentation preflight found the same local and remote head, main base `3246b04c`, and only the unrelated untracked ZIP. No implementation changed during this revision. The report's recommendations were evaluated as evidence, not accepted as architecture by authority.

Historical versions: Flutter 3.47.5 / Dart 3.13.4; Sentry Dart/Flutter/Supabase 10.0.0-rc.2; Cocoa 9.27.0; Android 8.56.0; Talker packages 5.1.20; command_it 9.5.2. Current lockfile/package-resolution sources and native dependency pins agree for these packages. Toolchain version execution was not repeated for this documentation task. The 59 host passes and one iOS probe are historical, not newly executed acceptance.

Current source inspection covers `lib/utils/logging/app_logger.dart`, event policy, `lib/main.dart`, bootstrap, HTTP factory, consent use case, Talker viewer/composition, contributor masks and existing diagnostic/native-enrichment/console/Supabase tests. Installed Sentry sources independently confirm throwable-to-string conversion, frame path handling, processor ordering and attachment collection; native pins are in sentry_flutter's Package.swift/build.gradle. Native mitigation selection still requires platform source investigation in task 9.1.

Canonical [application-observability](../../specs/application-observability/spec.md), [sentry-consent-lifecycle](../../specs/sentry-consent-lifecycle/spec.md) and [session-replay-privacy](../../specs/session-replay-privacy/spec.md) are the compatibility baseline. Proposed requirements live only in this change's deltas. Decisions D1–D9 below govern the expansion; historical statements about unchanged automatic-event/Replay scope or optional native checks do not discharge the new tasks 6–12.

## Goals and execution boundaries

Preserve the original logging migration: one entry point, Provider composition, typed bounded remote policy, truthful business outcomes, no duplicate owner and full eligible local causes. Add the smallest verified protection for each independent telemetry path. No new framework, universal sanitizer, dependency, database change or sampling change is selected. Characterization must resolve uncertain SDK mechanisms before implementation; a discovered material conflict stops affected work for review.

### D1 — Local diagnostics, console and voluntary sharing

**Problem/evidence:** reducing local error detail would sacrifice investigation value without closing all remote paths. T02/T07/T08 retain original Talker objects/stacks. T07 observes actual Talker console output even with Sentry console interception disabled. `LoggingScreen` embeds the installed TalkerScreen; its share action exports history via the platform share sheet. The experiment did not execute that sharing flow or establish OS log retention/access.

**Decision:** keep original exception, available stack and detailed local metadata for eligible events. Keep `enablePrintBreadcrumbs=false` as an intentional automatic-acquisition boundary. Sentry must not reconstruct Talker history from console output, export files, Replay or another automatic sink. Local-only means no forwarding by the logger; local console/system log visibility remains possible independently of sharing. Voluntary export is a separate user action and can contain private diagnostics; Sentry opt-in is neither authorization to export history nor a prerequisite for user-directed sharing. Inspect export/copy/preview and log-view Replay paths before adding any necessary safeguard (7.2/10.1).

**Alternatives/tradeoff:** reject deleting local originals, suppressing all local console output or resurrecting Talker-frame string matching: they lose evidence or depend on formatting. Export UX changes are conditional on characterization, not an automatic new workflow. Verify local identity, explicit user action, consent independence and no automatic history acquisition. Revisit on Talker export, console integration or log viewer changes; OS policy remains outside the Sentry guarantee.

### D2 — Typed remote projection and the limits of PII-off

**Threat/evidence:** arbitrary application values bypass default-PII gates. T03's projection ablation sends route query/reason, precise coordinates, repository user text and image URL through final diagnostic contexts/breadcrumbs; some reach synthetic exception value. T02 shows final restoration trusts the already approved copy and cannot repair unsafe construction. Cache remains local-only; image is breadcrumb-only, not a new report path.

**Decision:** retain the centralized typed projection and separate local-only, breadcrumb and owned-report eligibility. Keep bounded command/repository/category/status/backend-code fields; arbitrary `extra`, URL/query/body, user text and unscreened error data remain local. `sendDefaultPii=false` is an SDK collection option, not a classifier for explicit context, user fields or error strings. Preserve the legacy classification/owner inventory below.

**Alternatives/tradeoff:** reject PII-off alone, forwarding event.data wholesale, universal recursion and regex blacklists: none supplies a reviewed semantic contract. T04 already establishes SDK-owned Supabase query/body gates, so do not add a duplicate scrubber there. Verify positive telemetry counts and approved fields alongside absence canaries; absence in an empty envelope proves nothing. Revisit per new event family, changed metadata origin or SDK gate behavior; additions cost policy review rather than permitting unbounded context.

### D3 — Useful privacy-safe exception discrimination

**Problem/evidence:** T02 raw-exception ablation exports synthetic email/token and stack filename despite PII-off and final restoration. T08's two same-category FormatExceptions at distinct source files/lines serialize to identical app type/value with no original stack. This is demonstrated diagnostic loss, not observed server Issue grouping or measured diagnosis time.

**Decision:** retain a bounded exception representation, but improve safe distinction/localization where feasible. Task 6.1 must first inspect installed exception/frame representations and grouping-relevant inputs: type/value, mechanism, fingerprint, in-app classification and frames. Compare reviewed type/category/origin discrimination with reviewed code locations. Evaluate normalized filenames, function and line/column; package/framework versus application frames; generated code, symbolication/source maps and obfuscation; runtime/platform differences; paths and user-controlled filenames/functions. SDK basename stripping alone does not make a filename safe. No specific frame algorithm or new dependency is selected.

Missing/unparsable stacks must still produce a useful bounded failure/category and preserve capture visibility; no fallback to raw stack/message. Record what distinction cannot safely be retained. Keep original local objects/stacks and business propagation. Technical runtime/build metadata omitted by restoration is a candidate for field-by-field review, not wholesale restoration.

**Alternatives/tradeoff:** reject raw exception passthrough and generic substitution of every automatic crash. Keeping today's exact synthetic representation forever accepts demonstrated loss unnecessarily; hashing arbitrary private content or hand-setting a fingerprint is not selected without analysis of privacy, stability and grouping effects. Verification pairs same-category distinct causes, unsafe filename/message controls, absent/malformed stacks and generated/release cases. Compare safe retained fields, capture counts and baseline compatibility. Changes may regroup Sentry Issues; document that risk and rollback the added representation if unsafe, preserving existing boundaries. Server equivalence requires separate server evidence and is not a readiness promise. Revisit after SDK parser/symbolication/grouping-input changes.

### D4 — Scope isolation, enrichment and full-envelope filtering

**Threat/evidence:** T06 shows event-field overlap between scope isolation C and restoration D: C removed alone still excludes tested scope fields under D, both removed expose them. C independently removes a scope attachment later collected outside event reconstruction; no application attachment producer was found. This is a capability control, not a current app leak. The installed native-context processor with controlled binding reintroduces fields/replaces three causal breadcrumbs with one native HTTP breadcrumb after scope application. It demonstrates merge behavior, not natural native acquisition of the canaries.

Installed Dart order is throwable preparation → scope application/processors → option/native-context processors → default IP handling → beforeSend → sampling/lifecycle → attachment collection/envelope transport. In the inspected client, attachments are collected after beforeSend (currently around lines 201–210; historical report line references are version-specific). A clean event object is not proof of a clean envelope or native scope observer state.

**Decision:** retain both protections pending task 7.1's narrow ablation assessment. Required guarantees are per-report isolation; no shared-scope destruction or approved-hint crossover; exclusion of unrelated user/tags/extra/contexts and unapproved attachment bytes; final approved causal breadcrumbs; safe correlation and reviewed technical metadata. Retain selected OS/app versions and trace/span/Replay IDs without raw descriptions/data. Final app restoration fails closed, while automatic event error handling has its separate D5 contract. Do not confuse native enrichment of a Dart event with independently transmitted native events.

**Alternatives/tradeoff:** removing either boundary wholesale is unjustified. Narrow duplicated field handling or technical allowlist expansion is optional only after event, attachment and native observer evidence proves equivalence and utility. D drops benign runtime/culture/device details in T08; no privacy benefit was demonstrated for every omitted field. Measure that diagnostic cost separately. Verify whole serialized envelopes including attachments, real installed processors, absent/malformed contexts, causal chronology and controlled overlapping captures (T09 baseline plus new schedules). No total transport order is required. Revisit on SDK processing/attachment/scope-sync changes; do not assume beforeSend remains the last effective processing boundary.

### D5 — Automatic SDK-owned Dart exceptions

**Threat/evidence:** T01 genuinely unhandled guarded-zone StateError retains original message/parsed frames with PII-off, callback on/off. AppLogger.beforeSend currently returns every hint-less event unchanged. Existing native_enrichment_test's SDK control intentionally expects native canaries to pass; that is a historical ownership characterization, not a future privacy acceptance test. Host zone evidence does not verify mobile framework or PlatformDispatcher paths.

**Decision:** establish a separate SDK-owned privacy policy (8.1), preserving real unexpected-error visibility, mechanism/handled state, reviewed type/category, safe stack/thread/source diagnostics and necessary correlation. It must exclude arbitrary private exception content and unsafe enriched fields without making every crash the application synthetic report. Inspect final entry-specific fields, including chained errors and scope data; automatic breadcrumbs have their own reviewed acquisition policy. Preserve SDK ownership/deduplication and prevent an extra application capture for the same unhandled failure. Filtering failure must not silently erase the error: define and verify a bounded safe fallback retaining an identifiable failure, not an unsafe original payload.

**Alternatives/tradeoff:** unchanged pass-through is no longer sufficient for the expanded contract. Disabling automatic capture or dropping all unexpected events loses crash visibility. A generic recursive scrubber or message regex has no field contract. Select the smallest SDK-supported transformation after characterization; task 8.2 updates the old pass-through assertion deliberately and independently from app-report tests. Verify real unhandled SDK entry routes with positive controls and serialized envelopes, including framework/platform paths on supported mobile runtimes. Revisit on SDK integration, parser or dedup changes; residual private automatic content is a known current risk until implementation.

### D6 — Native telemetry is a separate boundary

**Evidence precision:** T10 invoked Cocoa 9.27.0 `SentrySDK.capture(error: NSError(...))` through a temporary adapter on an iOS 26.5 simulator, using a fake loopback destination. The matching envelope retained synthetic description in mechanism data/description and `contexts["user info"]`, not the top-level exception value. Dart beforeSend ran zero times. One error plus one session item and native thread/frame diagnostics were observed. This was nonfatal native capture, not an autonomous native crash, Android execution, hardware/release acceptance or production disclosure.

**Decision:** task 9.1 inventories native error/event entry points, NSError user-info/mechanisms, Java/NDK differences, native configuration/callbacks and Dart/native consent bridge for the installed pins; inspect authoritative Cocoa/Android sources before choosing mitigation. Dart beforeSend cannot be assumed to sanitize an independent native send. Use available platform processing callbacks/configuration only where necessary, retaining safe stack, thread, image/symbol diagnostics and normal crash capture. No replacement native pipeline is required by this evidence.

**Alternatives/tradeoff:** reject extending only the Dart callback as a presumed native fix, disabling all native diagnostics, or prescribing identical platform callbacks without source verification. Platform work costs runtime acceptance, justified by the demonstrated boundary. Tasks 9.2/9.3 require controlled native-origin canaries and representative automatic crashes on Android/iOS, working positive controls, final native envelopes, cache/relaunch and consent shutdown observations. Separate app/Dart enrichment tests remain necessary. Native path/thread/image fields require explicit review; do not erase all frames to hide descriptions. Revisit on native pins, bridge/configuration or capture/cache changes. Environmental limits must remain explicit and cannot become a passing checkbox.

### D7 — Replay content classification and selective protection

**Current contract/evidence:** global text/images are unmasked; SentryMask protects contribution name/email, dashboard contributor name and editor `Proposto da`; public editorial controls and `Creato come` account context remain visible. Canonical acceptance combines native dashboard recordings, widget boundaries and attributed actual public-form/editor Replay inspection. The investigation only source-inspected Replay; no pixels/recording privacy was established. Event beforeSend does not sanitize recordings.

**Decision:** characterize affected surfaces before choosing mask changes: public contribution identity/contact and restored drafts; free-text title/description/location, attachments/previews; submission confirmation/errors; dashboard/list/editor and moderation/rejection details; log viewer/export previews reachable during recording. Classify deliberately public tourism/editorial content separately from private contributor/user-authored or unpublished content. Do not classify all user-authored material private merely because of authorship; do not classify a draft public merely because the same widget displays public content. Preserve intentional administrator account visibility unless a concrete new private field justifies review.

Task 10.1 establishes which private categories can be rendered/captured, including keyboard/native overlays, Flutter image/platform-view masking limitations, and on-error Replay. Task 10.2 supplies targeted safeguards for demonstrated private surfaces, preserving public content and authorized UI access. Blanket global masking is not selected; if selective masks cannot satisfy the classified contract, stop affected implementation and review the smallest safe fallback. The focused Replay delta changes the old blanket visibility of editorial input only for classified private content. Task 10.3 requires bounded native recording evidence and consent/cache lifecycle controls, not just widget flags. Revisit on added sensitive screens, mask SDK/rendering changes or sampling/error-trigger changes; lack of recordings remains an explicit readiness gap.

### D8 — Consent and ownership by channel

Persisted consent, first-install behavior, fail-closed unreadable preference, deferred runtime opt-in, one bounded shutdown observation, stale-feedback protection and independent HTTP ownership remain unchanged. See `bootstrap.dart` and `SetCrashReportingUseCase`. No experiment demonstrates a need to rewrite this orchestration.

| Channel | Acquisition/reporting owner | Consent and sharing boundary |
| --- | --- | --- |
| App reports/typed breadcrumbs | AppLogger and designated terminal owner | Active process flag plus eligible initialized SDK; opt-out stops new app forwarding |
| Automatic Dart | Framework/platform/zone SDK integrations | Same automatic telemetry consent; no extra manual capture; independent D5 filtering |
| Native errors | Cocoa/Android SDK capture/cache | Same consent intent, separately verified native activation/shutdown; Dart flag alone proves nothing |
| Supabase breadcrumbs/spans | SentrySupabaseClient with errors disabled | SDK active state and existing stream sampling; typed app projection does not sanitize spans |
| Replay | Flutter/native Replay pipeline | Same telemetry eligibility and shutdown; on-error acquisition/flush/cache verified separately |
| Talker memory/console | Local diagnostic sink | Independent of Sentry consent; console visibility/OS retention is a separate local boundary |
| Voluntary export | User action through Talker viewer/platform sharing | Explicit action independent of Sentry opt-in/out; never automatic history upload |

T04 shows query/body protection from Supabase PII/body gates and parameterized SQL; error-wrapper disabling resolves capture ownership. T05 distinguishes the unwrapped app HTTP factory (no host request capture) from an unused SentryHttpClient capability that retains path/query. `options.httpClient` is the telemetry transport, not blanket application HTTP instrumentation. Native networking acquisition remains unverified. Do not add a Supabase scrubber or global HTTP wrapper from these findings; regress final event and streaming span envelopes with positive controls instead.

Task 11.1 verifies fresh opt-out/unreadable preference, active consent, persistence-first opt-out, deferred opt-in, shutdown failure/timeout and pre-revocation drains versus new post-shutdown acquisition across channels. Preserve application networking and local/export functionality. Native crash/recovery and Replay acceptance remain distinct from facade/widget tests. Revisit on lifecycle/transport ownership or integration changes; no immediate-zero-network-traffic promise is introduced.

### D9 — Minimal mechanisms, acceptance and residual risk

Retain A/B/D/F boundaries demonstrated by ablations. C/technical-context simplification is a measured hypothesis, not a required refactor. No additional logger abstraction, new SDK dependency, global dedup queue, universal sanitizer, fragile blacklist or broad automatic-diagnostic disablement is authorized. Each retained layer must identify its own data contract and processing boundary. Existing reliable SDK Supabase gates are reused, not duplicated.

New work proceeds through characterization → reviewed field/mechanism choice → focused implementation and tests → cross-channel/native acceptance. Roll back unsafe diagnostic additions while retaining prior privacy boundaries; do not roll back ownership/consent/business semantics. Tasks 6–11 own their tests and evidence; task 12 checks integrated readiness. SDK upgrade review rechecks exception/frame serialization, processor/envelope order, attachment handling, scope observers, automatic/native callbacks, Replay masking/error lifecycle, Supabase body/query/SQL fields and consent shutdown/cache. A changed assumption or failed positive control requires recharacterization; unchanged source alone does not prove runtime safety.

Accepted current limitations: same-category source discrimination loss, SDK-owned raw private text capability, incomplete native/Replay verification, and local OS-log visibility. These are explicitly current-state risks, not acceptance of an unsafe final contract. Readiness requires new platform evidence specified below; unavailable environments require a named unresolved criterion and explicit owner disposition/approval before a readiness claim. Server grouping, exhaustive crash families and production occurrence are not prerequisites unless used to support a new claim. No evidence supports a production incident assertion.

## Finding-to-contract traceability

All T identifiers refer to section D of the [archived report](research/2026-11-07-sentry-sanitization-investigation.md); results are historical SHA/version-specific. Requirement names are exact delta headers; task numbers refer to [tasks](tasks.md). The table gives the observable completion criterion rather than claiming it has passed.

| Finding | Historical evidence / current source | Decision | Requirement (capability) | Task | Verification criterion |
| --- | --- | --- | --- | --- | --- |
| Typed projection excludes raw fields | [T02](research/2026-11-07-sentry-sanitization-investigation.md#t02--handled-exception-through-applogger)/[T03](research/2026-11-07-sentry-sanitization-investigation.md#t03--typed-private-structured-data) | D2 | Remote diagnostic payloads are reviewed and useful (application-observability) | 6.2, 11.2 | Positive app/breadcrumb counts with private URL/coordinates/text absent |
| Raw exception unsafe with PII off | [T01](research/2026-11-07-sentry-sanitization-investigation.md#t01--genuinely-unhandled-dart-exception)/[T02](research/2026-11-07-sentry-sanitization-investigation.md#t02--handled-exception-through-applogger); installed exception factory | D2/D3/D5 | Privacy-safe exception discrimination; Automatic Dart errors retain safe visibility (application-observability) | 6.1–6.2, 8.1–8.2 | Raw-message/frame canaries absent with useful errors still delivered |
| Same-category diagnostic collapse | [T08](research/2026-11-07-sentry-sanitization-investigation.md#t08--diagnostic-usefulness) | D3 | Privacy-safe exception discrimination (application-observability) | 6.1–6.2 | Distinct safe source/category evidence where feasible; explicit missing-stack limits |
| Scope event-field overlap and attachments | [T02](research/2026-11-07-sentry-sanitization-investigation.md#t02--handled-exception-through-applogger)/[T06](research/2026-11-07-sentry-sanitization-investigation.md#t06--scope-poisoning-and-post-enrichment-restoration); installed client attachment collection | D4 | Complete application report envelopes are isolated (application-observability) | 7.1 | Full-envelope attachment control plus no ambient field leakage |
| Native processor enrichment/replaced crumbs | [T06](research/2026-11-07-sentry-sanitization-investigation.md#t06--scope-poisoning-and-post-enrichment-restoration); installed LoadContextsIntegration | D4 | Required application breadcrumb context survives report capture (application-observability) | 7.1, 11.3 | Approved chronology/correlation survives actual processor, not just pre-hook object |
| Automatic Dart pass-through | [T01](research/2026-11-07-sentry-sanitization-investigation.md#t01--genuinely-unhandled-dart-exception); AppLogger.beforeSend no-hint return | D5 | Automatic Dart errors retain safe visibility (application-observability) | 8.1–8.2 | Genuine unhandled capture and entry-specific envelopes without private content/duplicates |
| Native Cocoa bypasses Dart callback | [T10](research/2026-11-07-sentry-sanitization-investigation.md#t10--androidios-native-boundary) | D6 | Native error telemetry has an independent privacy boundary (application-observability) | 9.1–9.3 | Platform-source choice and Android/iOS native-origin/crash envelope controls |
| Talker console acquisition | [T07](research/2026-11-07-sentry-sanitization-investigation.md#t07--local-talker-versus-automatic-telemetry); Talker viewer/export source | D1 | Local diagnostics and voluntary export have explicit boundaries; Console interception is disabled without suppressing legitimate telemetry (application-observability) | 7.2, 11.2 | Original local data and user-directed export retained; no automatic console/history capture |
| SDK Supabase PII gates and SQL | [T04](research/2026-11-07-sentry-sanitization-investigation.md#t04--supabase-integration); main enableErrors:false | D2/D8 | Independent telemetry channels retain bounded acquisition (application-observability) | 11.2 | Serialized events/spans preserve DB operation and omit query/body/header canaries |
| App HTTP vs optional SDK wrapper | [T05](research/2026-11-07-sentry-sanitization-investigation.md#t05--http-urlquery-handling); http_client.dart | D8 | Independent telemetry channels retain bounded acquisition (application-observability) | 9.1, 11.2 | Verify active wiring before attributing acquisition; no new general wrapper |
| Consent and concurrent association limits | [T09](research/2026-11-07-sentry-sanitization-investigation.md#t09--deterministic-concurrent-captures); consent use case; canonical lifecycle | D4/D8 | Telemetry channel acceptance follows effective consent (sentry-consent-lifecycle) | 11.1, 11.3 | Correct per-report ownership/breadcrumbs and no new post-shutdown acquisition |
| Android/autonomous crash limits | [T10](research/2026-11-07-sentry-sanitization-investigation.md#t10--androidios-native-boundary) limitations; canonical native acceptance | D6/D9 | Native error telemetry has an independent privacy boundary (application-observability) | 9.3, 12.2 | Separate positive native controls and recovery evidence; unresolved platform gap explicitly gated |
| Replay privacy not experimentally verified | Report H; existing masks and canonical Replay | D7 | Private submission and diagnostic content is selectively protected; Recording acceptance covers classified private surfaces (session-replay-privacy) | 10.1–10.3 | Actual recording redaction with adjacent public context visible and on-error/consent controls |
| Actual server grouping unverified | [T08](research/2026-11-07-sentry-sanitization-investigation.md#t08--diagnostic-usefulness)/H | D3/D9 | Privacy-safe exception discrimination (application-observability) | 6.2, 12.2 | Payload distinction only; no Issue-equivalence claim without server evidence |

Not translated into unconditional production changes: T05's unused wrapper capability (no proven active app leak); T06's attachment producer (none found; maintain boundary/tests); every omitted technical field (utility/safety review first); Android/native crash and Replay outcomes (unverified, characterize first); server grouping (no server evidence); OS console retention (outside automatic telemetry policy). T04 argues against a redundant query scrubber. These exclusions preserve scope without discarding the observed risks.

## Verification, research retention and readiness record

Reuse existing `RecordingSentryTransport`, `NativeContextBinding`, logging-fault, Supabase and real ObjectBox helpers. Existing `diagnostic_payload_test.dart` asserts safe command/sync/upload origin and original local identities; `native_enrichment_test.dart` checks real installed processor behavior, malformed/missing contexts and correlation; `talker_console_privacy_test.dart` uses actual console integrations; `supabase_reporting_test.dart` checks ownership and SDK breadcrumbs/spans. `sdk_boundary_test.dart` prevents representative bypasses. These tests establish only their inspected assertions; historical pass counts do not verify the new requirements.

Promote focused historical controls into maintained tests where needed; the temporary experiment fixture names in the report are not claimed to exist in this checkout. Test final serialized envelopes/attachment items and stream spans, not only hook objects. Pair exclusion assertions with acquisition/capture/diagnostic positive controls. Record exact versions, options, platform/build, synthetic destination, commands, counts, failed attempts and limits. Native/Replay acceptance must meet their focused deltas and unchanged canonical obligations; host target overrides are not device evidence.

Autonomous PR CI covers `test/**` except `test/integration/**`, and does not execute `integration_test/**` or OpenSpec validation. The original implementation records 192 logging tests, 6 command tests and 4,053 CI-selected tests (4 skips), analysis/format/strict validation; these remain historical records in tasks.md, not results of this documentation revision. Native consent/Replay acceptance recorded in earlier archives is also historical and insufficient by itself for newly changed surfaces.

Retain only curated Markdown research here: the supplied report is copied byte-for-byte with SHA-256 `ca31dc990c460e6206fe85111d16daf9dde5fd7820d12ad259cad84af7eac11a`. Its original REPORT.md hash is distinct provenance, not this attachment's hash. Artifact filenames mentioned in the report are historical evidence locators, not required current links or committed files. The report records inputs, controls, exact relevant fields, results and limits without depending on the raw bundle for interpretation; rerunning temporary fixtures would require reconstruction from that protocol. Do not commit raw envelopes/logs/ZIPs, SDK source copies, binaries, manifests or scratch outputs. Preserve meaningful implementation evidence as concise versioned summaries; never claim absent operational artifacts remain available.

## Historical Gate A closure — original remediation (2026-11-06)

This section preserves the original migration rationale and event classification. It describes the implementation before the November 7 expansion; D1–D9 above supersede its scope exclusions and define the new work. It is not a second current policy.

The original execution started at PR HEAD `3c12e6b`, two documentation commits ahead of main `3246b04`, before the application migration. Installed Flutter/Dart are 3.47.5/3.13.4, Sentry packages 10.0.0-rc.2, Talker 5.1.20 and command_it 9.5.2. Baseline analyzer passes. Nine isolated review probes were rerun successfully before production edits: real Supabase cursor connectivity emits one integration envelope containing the original message; HTTP 500 emits two envelopes; Talker throws escape and suppress capture; draft diagnostic failures prevent a write or misrepresent durable success; generic immediate breadcrumbs survive while isolated synthetic captures clear them; distinct prepare causes share identical synthetic exception fields. These are recording-transport observations, not production ingestion or server Issue counts.

### Final policy and legacy classification

The centralized switch is selected over event getters because the 64-class catalog already has local fields and severity, while approved remote projection and cause-dependent ownership must be reviewed together. Adding a getter to each event would duplicate these decisions. New unknown types default local-only. Existing types are deliberately classified below; fields not listed are local only. All eligible local logs retain original error/stack and existing extra-merge precedence.

| Existing family | Previous remote behavior | Approved target and fields |
| --- | --- | --- |
| SyncStarted/Finished/ContentCommitSucceeded | Breadcrumbs | Retained with existing bounded mode/phase/counts/category; content commit remains distinct from settings success |
| SyncFailure | Breadcrumb; report unless connectivity or deferred, including no attached cause | Retained owner/category plus bounded repository origin, controlled cause type; cause-less reports remain explicit; prepare/commit repository origin added at source |
| RepositorySyncStarted/Finished/Failed | Breadcrumbs; failed with cause reports | Retained using only known repository name; failed reports remain owned by boundary |
| Entity insert/load/remove/update failures | Breadcrumb plus raw capture with cause | Retained owned capture with known entity/method and controlled error type; IDs and embedded extra removed |
| Entity insert/delete/update success | Breadcrumb | Retained event and known entity only; IDs removed |
| Cloudinary request start/retry | Debug, no remote | Unchanged local-only under remote level gate |
| Cloudinary completed/reuse/cancel | Breadcrumb | Retained typed reuse source; cancellation never reports |
| Cloudinary terminal failure | Conditional synthetic report | Retained stage/category/status; validation/fileRead only breadcrumb; original FunctionException retained locally so preparation status is available without exporting details |
| Public submission start/confirmed/replay/failure | Breadcrumb; failure with cause reports | Retained event/outcome/status and controlled cause; repository owns failure, never tracing adapter |
| Admin backend/association | Breadcrumb; failure with cause reports | Retained known operation and association outcome/status; repository owns; receipt/replay behavior unchanged |
| CommandExecutionFailed | Cause-dependent report | Retained allowlisted command and controlled type; selected upload FileSystemException remains breadcrumb-only; sync command owns unexpected sync throws |
| Core route/image errors | Raw URL/reason plus cause-dependent capture | Route retains owned capture. Handled image errors become breadcrumb-only with controlled cause type/status: Flutter rebuilds can repeat one errorBuilder failure, and synthetic capture bypasses throwable dedup. No widget state/global dedup is added; URI/query/reason/image URL stay local |
| URL launch, weather, reverse geocoding | Raw URL/coordinates; failure capture by severity | Retain event, controlled cause/status; remove URL and coordinate precision; expected connectivity breadcrumb-only |
| Network timeout, snackbar, image sharing, contributor asset warnings/retrieval | Breadcrumb; warnings do not capture | Retain event identity only; remove rejected filenames and textual reason |
| Draft save/load/clear, local init/settings failures, asset add/removal | Breadcrumb; error with attached cause captures | Retain event and controlled cause type; remove draft rendering entirely; handled cause-less failures stay breadcrumbs |
| AdminLocalStorageFailed | Breadcrumb with operation | Retain event; local operation/extra remain local until a concrete remote need exists |
| Auth login/logout/state/anonymous/user-id failure | Cause-dependent capture | Retain event and controlled cause/status; expected connectivity breadcrumb-only |
| Cache and Sentry enabled/disabled debug events | No remote | Unchanged local-only |

`minLevel` still filters the entire operation; debug remains local-only; inactive remote flag starts no logger remote work. An approved report with a cause emits one bounded synthetic event; all ordinary error severity alone authorizes nothing. Only SyncFailure permits a cause-less report. Non-report policies never capture even with an attached cause. Existing handled connectivity is deliberately breadcrumb-only, including GoTrue AuthRetryableFetchException without status (the network wrapper); Auth server failures retaining HTTP status remain reportable. Unknown events never inherit remote eligibility from severity.

An independent source review additionally verified that Flutter may repeat Image.errorBuilder for the same failed load during rebuilds; SDK throwable dedup no longer applies to synthetic events. The affected image decision is therefore deliberately revised to breadcrumb-only before its production policy change. Other independently owned failures remain reportable.

### Capture ownership including integrations

Disable only `SentrySupabaseClient.enableErrors`; retain its independent breadcrumb/tracing defaults and the existing client/resource ownership. Installed integration captures handled REST transport errors and HTTP 500–599. Every application `/rest/v1` operation is either cursor RPC or City/Place/Event/Media pagination through BaseSyncRepository, already owning returned failures; no exclusive valuable REST reporter was found. Functions endpoints (public/Admin/preparation) and Auth are outside that integration's REST matcher and retain their existing owners. Unexpected sync non-Exception objects retain original rethrow and command ownership; SDK uncaught/framework/native capture remains enabled. No object-identity registry is added. SDK deduplication can still drop raw automatic captures; application synthetic captures have no throwable and are counted separately from Issues.

### Historical diagnostic minimum, context and privacy decisions

Sync report minimum is owner/category, repository when known, controlled cause type and approved current-run sync breadcrumbs (start, repository preparation evidence, content commit, terminal selected phase). Distinct city/media preparation contract failures must differ by repository; unexpected commands also retain safe preceding source diagnostics. Settings reports must preserve preceding durable-content evidence when present, without inventing a commit for standalone settings writes. Upload minimum is stage/category/status and controlled cause; preserve original FunctionException rather than discard preparation status. Association minimum is event/operation, rejected versus unconfirmed, status and controlled cause. Generic repository minimum is known entity/method and cause type; UI minimum is event/cause type and status where available. Known PostgREST backend codes are allowlisted; numeric fallback codes supply HTTP status only when actually preserved by the SDK, never inferred from SQLSTATE. At this implementation baseline no original exception value or stack/frame is exported; this deliberately sacrifices exact remote source lines in favor of controlled technical origin. D3 now requires investigating safe improvements; this historical choice is not a permanent prohibition on reviewed technical frames. Full originals remain local. No historical grouping equivalence or improvement is claimed.

Every application report uses isolated scope and an explicit diagnostic context. Preserve only narrowly reprojected current-run sync breadcrumbs, in original causal order; no arbitrary ambient app/HTTP/console/context is restored. Other report families carry sufficient explicit current diagnostic context and their own approved breadcrumb; they do not require ambient history. Installed scope insertion is synchronous before native observers, so retain unawaited best-effort breadcrumb submission; no global queue or blanket awaiting. Disabling print/debugPrint interception closes the local-console path; the completion tests justify removing the obsolete frame filter. At Gate A, independent SDK unhandled payloads and Replay remained under their canonical contracts, without a universal sanitization claim. D5–D8 above expand their verification and privacy obligations.

### RT-01–RT-03 diagnostic refinements

Command reporting and remote projection share `safeCommandDebugName` in the existing command-event library. Its finite catalog preserves exact application identities, including the twelve actual Admin editor operation suffixes; unknown strings become `command`, never prefix-matched. A source-catalog regression detects newly declared names omitted from that policy. Sync keeps its separate owner and upload commands retain the handled filesystem exclusion. Controlled cause types plus command identity distinguish failures without restoring arbitrary remote exception messages or stack frames.

Final app-report projection retains only typed `os.name` from known SDK platform names, bounded `os.version`, `app.app_version` and `app.app_build`. Version/build values must be nonempty numeric-leading ASCII version tokens of at most 64 characters; unsupported shapes/values are omitted. OS/app source fields come from SDK platform/package metadata. Top-level `platform` denotes Dart, while release/dist can be customized, so these selected fields retain useful OS and package context without parsing release identifiers. Device family/model and all identifiers, names, descriptions, unknown fields, native users/tags/extras/HTTP data remain excluded; no whole context map is copied. At that baseline trace/span/replay correlation and SDK-owned captures were unchanged; D5 now expands the automatic-event privacy contract.

A source guard beside the existing Supabase configuration assertion pins both production `SentryFlutter.init` settings: `enablePrintBreadcrumbs=false` and `beforeSend=AppLogger.beforeSend`. It reuses the CR-01 masker and rejects missing, changed, commented-out or conflicting assignments. This supplements the existing behavioral tests without extracting production initialization or adding analysis infrastructure. Task 5.3 remains pending; RT-04 breadcrumb eviction behavior is unchanged.

### Best effort and bounded scope

Guard event metadata, local rendering/Talker and remote work independently. Consume both synchronous start failures and asynchronous diagnostic rejection without recursive reporting. Missing local data must not block a remote projection that can use typed fields independently. Remove saveDraft pre-rendering, rather than catching business work. The route fallback keeps its existing deduplication semantics but narrowly guards optional error-reason rendering, another pre-call diagnostic expression. A bad diagnostic cannot replace a real Result/throw or cause extra writes/retries. Representative tests use real ObjectBox and installed SDK, with production-mode versus automated-test-mode distinctions recorded.

Gate A was closed for the original authorized remediation: the above choices resolve its policy, migration, ownership, payload, context and isolation decisions. The original completion record in tasks.md describes subsequent integration, enforcement and agent-guidance work. No new Unicode-specific diagnostic is justified by a reproducer; exact-input capture is deferred. Actual native recordings, Sentry ingestion/grouping and deployed options remain unverified; publication checks must be inspected for the actual final HEAD. Existing canonical consent/Replay/tracing behavior must be preserved; no database, schema, RPC or Edge Function change is needed.

## November 7 implementation evidence — expansion at `5f044865`

This section records new implementation after the planning baseline, rather
than reclassifying the archived investigation as new execution. Native SDK
reporting is unchanged: after inspecting the bridge limitation, the owner
explicitly instructed: “Keep this evidence, do not make any changes to the SDK
native reporting.” That disposition does not satisfy native privacy acceptance.
The expansion is **not ready** while the mandatory channel guarantees remain
unmet. Detailed execution and remaining acceptance are recorded in the
[implementation evidence](research/2026-11-07-hardening-implementation.md).

### Reviewed exception and source contract (6.1–6.2, 8.1–8.2)

`safe_error_diagnostics.dart` retains exact reviewed source URI literals and
bounded positive line/column numbers. Application reports keep their existing
family/value/category/operation representation and add those locations from
VM-format stacks. Original throwable and stack objects still go to Talker.
Functions, arbitrary package/file names, absolute paths, query-bearing paths,
source snippets, variables and unparsed lines are not forwarded. Only selected
reporting-owner files and exact Dart runtime source identities are accepted;
there is no basename, path-prefix, hash, dynamic source manifest, new parser
package or fingerprint policy. The VM line parser accepts one anchored known
shape; missing/malformed, generated, absolute-path and app AOT stacks retain the
bounded failure without a location. These are explicit localization limits,
not evidence that release builds were executed or symbolicated.

Automatic Dart errors have a separate policy in the existing `beforeSend`
boundary. They keep a finite known exception type (unknown/obfuscated types
become `DartError`), SDK mechanism/handled state and exception-group linkage,
reviewed source frames and numeric thread identity/state. Original values,
thread names, arbitrary mechanism data, requests/users/tags/extras and unknown
contexts are omitted. Exception chains retain the last sixteen entries,
including the root. No new capture, automatic-error shutdown or object-identity
deduplication is introduced. Supabase core-table operation breadcrumbs and
current-run sync breadcrumbs are reprojected in acquisition order; other
automatic/navigation/console crumbs are omitted until their fields are reviewed.
This is a diagnostic tradeoff, not a universal breadcrumb compatibility claim.

For automatic AOT errors, the installed SDK parser's numeric native instruction
addresses survive, along with numeric image addresses/sizes, finite image types
and architectures, UUID-shaped debug identifiers and hex code identifiers.
Image names, paths, symbols and registers are omitted. These fields retain
symbolication inputs, but actual release symbolication and Sentry server Issue
grouping were not tested. No native SDK callback or reporting pipeline changes
are involved: these are Dart-event protocol fields only.

OS/app version and trace/span/Replay linkage retain the earlier field contract;
automatic trace operation is `sdk.error`, while app reports keep `app.report`.
If optional enrichment restoration fails, the already-sanitized automatic event
retains its identity and diagnostics. If projection itself fails, a bounded
`DartError` event survives without the unsafe input. This fallback begins after
SDK throwable preparation: it cannot repair an SDK failure before `beforeSend`.
Host tests exercise a genuinely unhandled zone and extracted chain, Flutter's
actual framework reporting entry and the installed dispatcher handler. Direct
handler invocation is explicitly not mobile engine-origin capture evidence.

### Retained isolation layers and remaining attachment capability (7.1, 11.2)

New C/D controls independently retain event reconstruction and cloned-scope
clearing. Reconstruction removes tested polluted event fields; scope clearing
independently removes attachments collected later by the SDK. Hint attachments,
screenshot and hierarchy items are excluded by finalization. Scope cloning has
native synchronization disabled in this SDK; the observer control confirms no
shared native-user reset. The real installed native-context processor remains
covered with controlled binding data, which is not native acquisition evidence.
No deletion of either protection or new technical-context expansion is justified.

A separate positive control proves that **SDK-owned automatic events can still
inherit ambient scope attachments** after `beforeSend`. The installed API has no
`beforeSendEnvelope`, and `maxAttachmentSize=0` is unsupported. There is no
production attachment producer in the inspected application, and screenshot/
hierarchy acquisition remains disabled by SDK defaults. Nevertheless the broad
full-envelope attachment guarantee remains open. No destructive shared-scope
clear or replacement transport was added to disguise this SDK boundary.

### Rendered content classification and local export (7.2, 10)

Editable submission proposals, restored drafts, their original asset previews,
precise location editor/map, recovery comparison values, candidate-search input,
proposed merge values and unbounded preview-error text are private/unpublished.
They now have targeted masks. Original submission assets remain protected even
after approval: approval does not prove every original field or asset is the
same as promoted public content. Existing contributor masks remain. Dashboard
summary date/category/status, public source/current editorial context,
public tourism screens and `Creato come` retain their intentional visibility.
The log viewer and monitor detail content are protected by typed `TalkerView`
and `TalkerDataCard` rules because pushed monitor routes leave LoggingScreen's
subtree. Global text/images remain unmasked; no navigation or form semantics
changed. These are widget/source guarantees, not recording acceptance.

The installed Replay integration triggers buffered error Replay through its
`OnBeforeSendEvent` lifecycle callback, independently of event reconstruction.
Mask rules operate on Flutter render bounds. Native keyboard/picker/share
surfaces, platform views, native overlay pixels, actual image recordings and
buffer/cache shutdown need separate runtime evidence. No Android/iOS Replay
recording or attributed Sentry Replay inspection was performed here, and no
production project received synthetic probes. Tasks 10.1/10.3 remain open.

Talker originals and console output remain local and independent of consent.
Isolated package tests exercise viewer copy plus its actual export controller,
real temporary-file contents and mocked share dismissal, with consent on/off.
Export contents remain private diagnostics requiring a separate explicit action;
Sentry never reconstructs that history. This does not prove OS share-preview
redaction. Production-style viewer characterization also exposed existing
material_ui/Flutter overlay incompatibilities: missing legacy localizations and
ScaffoldMessenger, plus a pinned-package debug decorated-ListTile assertion.
The package control uses Flutter MaterialApp and a transparent test theme;
it is not evidence that production overlays work. No app-wide compatibility or
navigation redesign was introduced. Task 7.2 remains open for that flow and
platform preview acceptance.

### Dashboard classification conflict resolved by the owner

`AdminSubmissionListItem` renders `AdminSubmission.name` and `.city` directly.
The model describes these as contributor-provided values; status/promotion does
not prove that the original text equals current published content. The existing
canonical dashboard scenario requires title/city visibility, whereas the new
contract protects unpublished text. The owner explicitly authorized masking
original dashboard title/city and revising only the delta to make visibility
conditional on proven public content. The row now masks those originals in
pending, accepted and rejected states: its model has no independent public-value
proof. Date/type/status and normal row taps remain visible/functional; public
tourism content elsewhere remains visible. The delta updates both contributor
masking and combined native-recording acceptance to remove the contradictory
unconditional title/city guarantee. Canonical specs are unchanged. All 44
dashboard widget cases pass, including status-specific private/public controls.
Task 10.2 is complete; actual recording acceptance remains separate.
