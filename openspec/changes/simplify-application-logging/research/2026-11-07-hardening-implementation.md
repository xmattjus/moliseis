# Telemetry hardening implementation — November 7, 2026

## Baseline and authority

Implementation starts at `5f04486526756c124a655efccec52637384f4db1` on
`codex/simplify-application-logging`, the live head of draft
[PR #33](https://github.com/xmattjus/moliseis/pull/33). Main/base remains
`3246b04c8518aef235eab016f42beca4a4fd7bc6`. Remote metadata and a non-forcing
fetch were verified. Initial tracked tree was clean, with only the unrelated
`harden-imported-asset-persistence-and-cleanup.zip`; that file is preserved.
The commit containing this evidence identifies the implemented source revision.
Canonical specifications and archived investigation are unchanged.

Executed toolchain verification: Flutter 3.47.5, framework `6a19cca564`,
Dart 3.13.4. Lockfile and package resolution still select Sentry
Dart/Flutter/Supabase 10.0.0-rc.2, Talker/Flutter/Logger 5.1.20 and command_it
9.5.2. Cocoa resolves to 9.27.0 / `aaf96c4a417d30208b3c25d90910d6156ddc973d`;
Flutter's Android build pins 8.56.0. No dependencies or toolchains changed.

## Implementation and compatibility

- `app_logger.dart` retains the typed projection, original owners, cause-less
  sync reports, connectivity/local-only/breadcrumb-only behavior, cloned scopes
  and post-enrichment reconstruction. It adds reviewed source locations to
  application exceptions and a separate automatic Dart policy.
- `safe_error_diagnostics.dart` holds the finite type/source/mechanism contract,
  VM location extraction and automatic AOT/debug-image projection. The detailed
  field/alternative/limitation comparison is in the design's November 7 section.
- `main.dart` adds only typed diagnostic-widget Replay masks. Its consent,
  sampling, HTTP ownership, PII-off, print-off and Supabase error-off wiring
  remain unchanged. No native reporting change is made.
- Shared proposal fields/assets, Admin location/recovery and sensitive merge
  displays gain targeted masks. Masking affects recording bounds, not validation,
  persistence, callbacks, staff access, navigation or displayed values. Public
  summaries, tourism context and intentionally public admin identity remain.
- Existing support is extended for complete envelope serialization, deterministic
  delivery observation, processor gates/faults, native observer counts and a real
  exception cause extractor. No new test infrastructure package is introduced.

No sync transaction, retry, compensation, Cloudinary association, idempotency,
result/throw propagation, application HTTP client or consent orchestration is
changed. Local original throwable/stack identities are asserted. The source
boundary guard remains active, with a narrowly permitted Talker import in main
for typed masking. There is no object-identity deduplication or new global queue.

## Newly executed payload evidence

| Boundary | Positive acquisition/control | Observed final serialized result | Limit |
| --- | --- | --- | --- |
| Application location | Two distinct same-category FormatExceptions and package source locations | Two reports retain identical bounded family/value but different reviewed file/line values (42/88); message/function/private-filename canaries absent; local originals retained | Unknown/generated/absolute/malformed/app AOT stacks omit locations; no server grouping claim |
| Automatic zone | Actual scheduled unhandled StateError, filtered/unfiltered pair | One event per case; unfiltered final value/stack contains canary; filtered event keeps StateError, handled=false, runZonedGuarded, reviewed line 42 and omits canary | Host automatic Dart, not mobile crash/relaunch |
| Framework | FlutterError.reportError through installed integration | One event keeps FlutterError mechanism and safe StateError/frame; library/context/information/scope canaries absent | Framework entry invoked on host |
| Dispatcher | Installed OnErrorIntegration bound to actual PlatformDispatcher wrapper | Handler returns unchanged handled value; one event keeps dispatcher mechanism and safe frame; private data absent | Handler invoked directly, not engine-origin runtime delivery; Flutter test dispatcher's setter is a no-op |
| Chained errors | Genuine unhandled wrapper with registered SDK cause extractor and group processing | One event, two exception entries; child StateError/chained/parent 0 and root runZonedGuarded handled=false survive with private values absent | Test extractor is configured only in the test; no production extractor added |
| AOT diagnostics | Installed SDK parses split-debug-info address text; controlled processor adds debug-image data | Native instruction address and reviewed debug ID/image address survive; image/path canaries absent | Controlled image metadata, not mobile symbolication or a release build |
| Filtering failure | Broken prepared-frame getter; malformed post-processor trace separately | Projection failure delivers bounded diagnostic-failure event; malformed optional enrichment retains already-safe chain | Cannot repair SDK errors before beforeSend |
| Scope/restoration | C/D single-factor and combined controls with real scope attachment; real logger receives hint/screenshot/hierarchy injections | Scope clearing independently excludes late-collected attachment; reconstruction excludes event fields; real app envelope has event only; shared scope stays intact | Controlled native-context processor is not native acquisition |
| Automatic attachments | Working SDK-owned capture with ambient scope attachment | Event JSON is filtered but the final attachment bytes remain | Explicit unresolved SDK capability; no production producer found; not a privacy pass |
| Concurrency | Completer-gated app/app/SDK processing, rejection and shutdown during capture | Distinct hints and app diagnostics, approved own crumbs, no private crossover or duplicate captures; old acquisition may deliver after close; new attempts do not transport | Deterministic host schedules, not native observer/runtime exhaustion |
| Supabase | Actual installed wrapper, mocked request responses, sampled stream spans and final flush; PII true/false controls | Event and streaming envelopes keep core table, operation and parameterized SQL; private query/body absent with PII false; PII true event control acquires values; automatic filter retains approved DB breadcrumb | Request transport mocked; no live database; SDK beforeSend is not a span sanitizer |
| Console | Actual SDK zone acquisition on/off plus real Talker console regressions | Enabled positive control acquires the canary breadcrumb in scope; disabled control does not; filtered SDK follow-up remains private and identifiable | Local console/OS visibility persists; production remains print-off |
| Local copy/export | Isolated Talker viewer copy and actual export-controller pipeline with consent on/off | Original diagnostics copied and written to a real temporary file only after explicit action; mocked platform share returns dismissed; event count unchanged, private history absent remotely | Production overlays and OS preview pixels not accepted |
| Replay | Widget ancestor/typed-rule/source controls with normal interactions | Private proposal text/assets/location/recovery/diagnostic displays protected; public adjacent/account context preserved | No actual Android/iOS recording or Sentry Replay inspection |

## Test construction and verification boundaries

The recording transport is the real installed Sentry event/span pipeline's sink;
only network delivery is replaced. Full-envelope checks serialize attachment and
span items too. Native context binding fixtures supply synthetic native data to
the actual installed enrichment processor. They do not claim native collection.
Supabase uses the installed SDK wrapper with MockClient responses; PII-on
controls establish acquisition. StreamingInstrumentationSpan rejects Map-valued
body attributes even with PII enabled, so body-leak claims are not invented.

`error_localization_test.dart` covers paired sources plus null, malformed,
generated, AOT, unsafe absolute filename and query-bearing path controls.
`automatic_error_privacy_test.dart` covers the entry/fallback/chain/AOT/console
cases above. `envelope_isolation_test.dart` covers C/D, every attachment source,
observer effects, delayed overlap, rejection and consent transition. Existing
logging, Supabase, sync, command, Cloudinary, draft and consent suites run as
part of the autonomous suite. Affected public/Admin widget tests retain their
functional assertions alongside mask boundaries.

Early failed attempts were investigated: concurrent Flutter processes raced the
shared native-assets build; commands were serialized. The Flutter test dispatcher
silently ignores its onError setter, so the installed handler control explicitly
uses the real dispatcher wrapper and keeps its runtime limitation. Malformed
trace injection before scope application failed inside SDK scope processing; it
was moved to the actual post-processor filter boundary. Initial widget export
attempts timed out in fake async; the maintained export test executes the actual
controller/file pipeline outside widget fake async, separately from viewer copy.
Production-style Talker overlays exposed preexisting missing legacy Material
localizations/ScaffoldMessenger and a package debug ListTile assertion. No
privacy assertion was weakened, and those production-flow criteria remain open.
Analyzer findings were corrected before final validation; preliminary failures
are not counted as passes.

No native reporting mitigation or new native runtime probe was executed.
The [native assessment](2026-11-07-native-integration-assessment.md) records exact
pinned mechanisms and the owner's subsequent instruction to leave native
reporting unchanged. iOS 26.5 simulators and an Android AVD exist; neither
platform is falsely labelled unavailable. No isolated Replay recording fixture
was configured/executed, and no authenticated Replay inspection was performed.
The gap is missing runtime evidence, not proof that the installed environment
cannot run those platforms. No production project received synthetic telemetry.

## Task disposition and minimum next actions

| Task | State | Evidence / minimum remaining action |
| --- | --- | --- |
| 6.1 | COMPLETE | Installed protocol/parser inspection and reviewed field/utility contract in design |
| 6.2 | COMPLETE | Maintained paired localization/fallback final-envelope controls; local identity preserved |
| 7.1 | COMPLETE | Independent C/D controls, late attachment exclusion, processor and observer controls; both layers retained |
| 7.2 | OPEN — IMPLEMENTATION REQUIRED | Package copy/export controls pass; resolve production overlay compatibility without changing navigation, then verify OS share/cancel/preview |
| 8.1 | COMPLETE | Genuine zone/framework, chain and host dispatcher-handler characterization; runtime attribution explicit |
| 8.2 | COMPLETE | Separate automatic exception policy and maintained positive/negative/fallback controls; mobile entry and complete-envelope gaps remain separately gated |
| 9.1 | BLOCKED | Source/callback assessment complete; no supported pre-start app hook selected within unchanged native integration |
| 9.2 | BLOCKED | Owner explicitly requires native reporting unchanged; later supported hook/design authorization required |
| 9.3 | OPEN — VERIFICATION REQUIRED | After permitted mitigation: isolated Android/iOS nonfatal, representative crash/relaunch and shutdown envelopes |
| 10.1 | OPEN — VERIFICATION REQUIRED | Source/rendered inventory complete; obtain synthetic actual recordings including overlays/platform views/on-error buffers |
| 10.2 | COMPLETE | Targeted masks and affected widget regressions; recording acceptance separate |
| 10.3 | OPEN — VERIFICATION REQUIRED | Android/iOS dashboard plus actual attributed form/editor/private-category Replay inspection and shutdown/cache controls |
| 11.1 | OPEN — VERIFICATION REQUIRED | Host consent/bootstrap/networking/local regressions run; mandatory native/Replay channel cessation unverified |
| 11.2 | OPEN — IMPLEMENTATION REQUIRED | Core event/span/console controls implemented; unsupported automatic scope-attachment capability and actual native/Replay evidence remain |
| 11.3 | COMPLETE | Deterministic app/app/SDK overlap, failure, hint isolation and transition controls; no global ordering assumption |
| 12.1 | OPEN — VERIFICATION REQUIRED | Local repository commands run; whole-channel acceptance remains unmet |
| 12.2 | OPEN — VERIFICATION REQUIRED | Source review corrected two diagnostic issues; native/Replay/production export guarantees unresolved, so no readiness claim |

**Readiness: BLOCKED.** Native implementation authority/mechanism and automatic
scope-attachment closure are implementation boundaries. Native/Replay runtime,
production viewer overlays and mobile engine delivery are separately named
verification gaps. The owner's instruction preserves native evidence, not a
privacy waiver. Optional server grouping research and exhaustive crash-family
coverage are not invented blockers. No merge, ready-for-review transition,
canonical synchronization, archival or deployment is authorized or performed.

## Executed final verification

Final command outcomes and publication metadata are appended after observation.

Observed final commands/results:

- `flutter --version`: Flutter 3.47.5 / Dart 3.13.4, as recorded above.
- `openspec list --json`, `openspec status --change simplify-application-logging --json`,
  `openspec instructions apply --change simplify-application-logging --json`:
  existing repo-local spec-driven change, executable state `ready`; after verified
  task updates, 46/57 complete, 11 remaining (including later lifecycle 5.3).
  CLI `ready` means ready to continue implementation, not release readiness.
- `flutter test --no-pub --reporter expanded test/utils/logging/error_localization_test.dart test/utils/logging/native_enrichment_test.dart`:
  initial focused control, 11 passes.
- Combined automatic/localization/envelope/native/Supabase/best-effort run:
  initial 44 passes/1 dispatcher-fixture failure, then corrected and reverified.
- `flutter test --no-pub --reporter expanded test/utils/logging` plus the five
  affected viewer/proposal/Admin widget files: 379 passes before the final
  additional chain/console/attachment/Supabase controls.
- `flutter test --no-pub --reporter expanded test/utils/logging/automatic_error_privacy_test.dart test/utils/logging/supabase_reporting_test.dart test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart`:
  95 passes after chain/diagnostic fixes.
- `flutter test --no-pub --reporter expanded test/ui/core/ui/logging_screen_test.dart`:
  4 passes for isolated copy and actual export pipeline, consent off/on.
- CI-equivalent selection: enumerate/sort `test/**/*_test.dart`, exclude
  `test/integration/**`, execute `TZ=Europe/Rome flutter test --no-pub --reporter expanded <selected files>`:
  **4,101 passed, 4 skipped, 195 files**, exit 0. The selection was constructed
  using `rg --files`; it matches CI's documented `find` selection. Existing skip
  declarations were preserved, not expanded. No Supabase local-stack tests,
  native integration tests or real Replay inspection are included.
- Final `flutter test --no-pub --reporter expanded test/utils/logging`:
  **234 passed**, exit 0. After strengthening application-location assertions
  from final event JSON to the entire serialized envelope, its 7 tests passed
  again; the final logging run includes that stronger check.
- `flutter analyze --no-pub`: final exit 0, **No issues found**. Preliminary
  analyzer/format failures were corrected rather than waived.
- `dart format --output=none --set-exit-if-changed <47 affected/logging Dart files>`:
  final 0 changes; an earlier check identified one test needing formatting,
  which was formatted and rerun.
- `openspec validate simplify-application-logging --strict`: exit 0, valid.
- `git diff --check`: exit 0. Source URI existence assertions and research
  provenance/hygiene assertions pass. Archived investigation SHA-256 remains
  `ca31dc990c460e6206fe85111d16daf9dde5fd7820d12ad259cad84af7eac11a`.
- Read-only simulator/device inventories and pinned-source checks are detailed
  in the native assessment. No new native crash/nonfatal/Replay test is counted.

Independent source review identified and verified corrections for automatic AOT
address loss and loss of already-sanitized exceptions on malformed optional
contexts. The reviewer reported no further material production defect in the
examined logging/Replay changes, and explicitly did not execute tests or accept
native/Replay runtime guarantees. This review is distinct from CodeRabbit and
from the historical investigation.

Publication remains on draft PR #33. A full CodeRabbit review is requested after
implementation publication; its live result belongs to the PR, not a fabricated
local acceptance result. No required-check or bot-review outcome is inferred
from the local test suite.
