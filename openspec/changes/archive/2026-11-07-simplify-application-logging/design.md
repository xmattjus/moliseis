# Design: simplify application logging

## Context and authority

The original typed logging migration and November 7 Dart hardening were merged through [PR #33](https://github.com/xmattjus/moliseis/pull/33) into `main` at `479250e213de46bd4bb6374e14d36873ee66476a`. The owner's final logging decision freeze supersedes contradictory planning assumptions, including mandatory native sanitization/probes, native Replay recording campaigns and production Talker diagnostics. This design records the current contract, not a new architecture.

Historical investigation and execution details remain in [the archived investigation](research/2026-11-07-sentry-sanitization-investigation.md), [native integration assessment](research/2026-11-07-native-integration-assessment.md) and [hardening implementation evidence](research/2026-11-07-hardening-implementation.md). Those reports retain their original observations and historical BLOCKED verdicts; the owner subsequently revised the acceptance contract. A historical pass is not new execution evidence.

## Decisions

### D1 — Talker is Debug-only

Use `kDebugMode` at composition and every application-owned Talker boundary. The composition root provides nullable Talker; Profile and Release do not instantiate it. `AppLogger.log` guards only its local sink branch, including local metadata construction, and retains original errors/stacks in Debug. A missing or failed sink cannot suppress eligible Sentry work. No runtime toggle, replacement framework or application log-file writer is introduced.

The `/logging` route itself and `TalkerRouteObserver` are registered only in Debug. Explore retains its existing Debug menu guard. Viewer copy/export remains an explicit Debug developer action independent of consent; no production viewer or export exists. Focused viewer/route/source checks replace the obsolete extensive OS sharing-preview acceptance campaign. Debug console output is local diagnostic output, not a guarantee of absence from system logs.

### D2 — Sentry forwarding and reporting ownership are unchanged

`Logger.log` keeps its API and typed event policy. `minLevel`, remote level gates, consent, cause classification and intentional cause-less sync reports remain unchanged when Talker is absent. Local-only and breadcrumb-only events do not become captures merely because their severity is high. A terminal failure has its established designated reporting owner; SDK-owned genuinely unhandled errors are not recaptured by application logging. No global exception-object deduplication is introduced.

Sync, Cloudinary upload/association, submission idempotency, persistence, retries, compensation, navigation, business `Result` values and original throw propagation retain their existing owners and behavior. The stream tracing adapter executes the business callback once, annotates status and never captures exceptions. Existing trace/Replay sampling and application networking ownership are unchanged.

### D3 — Retain implemented Dart privacy and diagnostic usefulness

Application reports use reviewed bounded technical fields, not arbitrary `LogEvent.data`, `extra`, original exception messages or raw stack text. The shared safe-frame extraction accepts canonical source identities in the approved app, Flutter and Dart namespaces with bounded line/column locations; functions remain excluded. Malformed, noncanonical, generated or unsupported stack forms receive a bounded useful fallback. Same-category paired transport tests distinguish safe source locations without claiming Sentry server Issue grouping. Original local exception objects and available stacks are retained only in Debug; business propagation is unchanged in every build.

Automatic Dart errors use a separate SDK-owned projection that preserves reviewed type/mechanism/source information and safe fallback visibility. It is not application-owned synthetic substitution and does not create an extra application capture. Genuine zone, framework and supported dispatcher host controls remain distinct from mobile runtime proof.

Retain scope isolation and final event reconstruction because they have distinct responsibilities. Application scope clearing excludes attachments collected later by the SDK; final projection removes ambient enrichment after processors. Approved causal breadcrumbs and safe trace/replay correlation survive without a global ordering requirement. Do not remove a layer merely because an event-only fixture omits fields. Existing scope/hint defenses, malformed-context fallback, observer isolation and deterministic overlapping capture tests remain in force.

Automatic print/debugPrint acquisition stays disabled; Talker history cannot be reconstructed through the former console path. Supabase retains `enableErrors: false`, active breadcrumbs/streaming spans and SDK PII/body/SQL protections; no duplicate scrubber or unused HTTP wrapper is added. Final serialized transport privacy assertions retain operational positive controls and useful approved fields.

### P2-1 — Restore ordinary automatic Dart source locations

The exact-file list retained repository controls but dropped ordinary UI/ViewModel and Flutter frames. A new genuine guarded-zone regression reproduced five transported source identities without projection versus only repository/runtime identities with the old projection. The pinned Sentry 10.0.0-rc.2 factory derives package/Dart `absPath` from `Frame.uri.toString()`; it does not authenticate a supplied stack. Web origins and non-package basenames are outside this source contract.

Validate the original `absPath` spelling without URI decoding or normalization. Accept at most 512 characters in `package:moliseis/`, `package:flutter/` or `dart:<library>/`, with lowercase ASCII identifier segments (digits after the first character, underscores and directory hyphens) and a lowercase single-stem `.dart` filename. Reject other schemes/packages, absolute paths, empty/dot segments, percent escapes, query/fragment syntax, backslashes, control characters and unsupported characters. Multi-dot generated filenames remain excluded. Reuse this validator for application stack extraction and automatic exception/thread frames; preserve the 256-frame limit, location bounds, native addresses and reviewed debug images unchanged.

This is a structural source-identity contract, not provenance authentication. A deliberately forged canonical URI containing a lowercase private value is indistinguishable from a genuine source at this boundary and can survive. A separate serialized capability test demonstrates that limitation; it is not counted as a privacy-negative pass. Arbitrary user-provided filenames must not be supplied as trusted stack data. Noncanonical representations remain conservatively excluded, with no fallback to raw stack text. No source registry or manifest is introduced.

The installed SDK and Dart runtime confirm `NoSuchMethodError`, `UnsupportedError`, `ConcurrentModificationError` and VM `LateError`; only those exact additional technical type strings are retained. Unknown types still become `DartError`, and original values still become `SDK error`. Real SDK transport tests cover UI, ViewModel, repository, Flutter and Dart locations, malformed/private source cases, location bounds, standard types and the existing native/AOT controls. The automatic positive control uses an actual unhandled guarded-zone entry with a supplied synthetic stack. Negative frame fixtures pass through SDK processing and final envelope serialization. Neither proves backend Issue grouping, device delivery or authenticity of forged frames. Breadcrumb filtering, reporting ownership and all frozen architecture remain unchanged.

P2-1 diagnostic-source remediation verification at commit `2b88cb3782b460a94fdf53ac2a417e822a8b74a7`, subsequent to the logging freeze, on Flutter 3.47.5 / Dart 3.13.4 and Sentry 10.0.0-rc.2: 22 focused automatic/localization tests and 241 logging tests passed; the CI-equivalent 195-file autonomous suite passed 4,112 tests with four existing skips. Analysis, changed-file formatting, static logging boundaries, strict OpenSpec validation and diff hygiene passed. No native/Replay campaign or additional build was run for this platform-independent remediation. At that implementation checkpoint, task 5.3 remained open; final implementation remote/CI/review evidence belongs to PR #33.

### D4 — Official native integration only

Retain the official pinned Flutter/native SDK initialization, reporting, caching, recovery, transport and public `Sentry.close` lifecycle. The native assessment found no supported pre-start customization hook meeting the former guarantee. The owner explicitly declined native reporting changes and now accepts that boundary. No SDK fork, private hook, post-start sanitizer, replacement pipeline or custom native shutdown/recovery code is authorized. Tasks 9.1–9.3 record source evidence and withdrawn obligations, not completed native mitigation or runtime verification.

Consent still resolves durable preferences before initialization, fails closed on unreadable preferences, persists opt-out before stopping custom forwarding and observes one shared SDK close Future with the existing deadline. Runtime opt-in stays deferred until a fresh process. Rejection/timeout retain saved opt-out and accurate unconfirmed feedback. Successful observation means the supported SDK close operation settled; it does not certify inaccessible native internal state. Old buffered delivery is distinct from new acquisition. Application clients remain independently owned and usable.

### D5 — Official selective Replay masks

Retain `maskAllText = false`, `maskAllImages = false`, existing sample rates, applicable `SentryMask` boundaries and typed masking rules. The application classifies rendered private content and wraps it using official APIs; it does not reproduce SDK masking internals.

Private contributor identity/contact, unpublished contribution/draft text and assets, moderation details and Debug diagnostic displays retain their existing masks. Dashboard original title/city are not proven public by acceptance or promotion alone and remain masked for every current status. Public tourism/editorial content retains useful visibility where publicness is established; the intentionally visible administrator `Creato come` context remains unchanged. The pending-contribution match warning includes an unpublished title and must be wrapped in `SentryMask` without changing text, layout, interactions or backend behavior.

Focused widget tests prove the relevant ancestor boundaries and preserve adjacent public/account controls. They do not prove native pixels, overlays, platform views, image masking or all buffered/error-triggered rendering paths. No new Android/iOS recording, native pixel comparison or server-side Replay inspection campaign is required for this PR. Event `beforeSend` is never presented as Replay sanitization.

## Accepted SDK limitations

The owner accepts the following residual boundaries for this PR, without claiming they are sanitized, fully verified or compliant:

- Native-origin events may bypass Dart `beforeSend`; native descriptions, crash recovery/cached envelopes and internal native shutdown state are not verified by this change. The public SDK integration remains unchanged.
- SDK-owned automatic scope attachments collected outside the application's supported sanitization boundary have a documented capability limit; existing application event/hint/scope protections remain effective and are retained.
- Actual device Replay acquisition, every rendering path and recorded pixels have not been verified here. Application widget-boundary tests establish configuration/wrapping only.
- Potential Sentry server-side scrubbing is a separate future activity.

See the historical investigation and native assessment linked above for provenance. These owner-accepted SDK limits are not implementation blockers under the revised deltas. They must not be converted into positive verification claims, privacy certification or proof of server grouping.

## Implementation verification and delivery (historical)

Reuse existing maintained policy, envelope, concurrency, consent/networking, functional sync/Cloudinary/submission/moderation and command tests. Add focused null-Talker independence, Debug sink/source-guard and pending-warning widget regressions. Ordinary `flutter test` runs in Debug and cannot prove Profile/Release behavior; combine compile-time structural checks with a supported non-Debug build when tooling permits and state any build limitation precisely.

Run focused tests, the applicable complete Flutter suite, `flutter analyze --no-pub`, formatting, static logging boundaries, strict OpenSpec validation and repository hygiene checks. Review the complete PR diff against current main and distinguish existing failures from new regressions. Only actual executed checks may complete tasks 7.2, 10.2, 11.1–11.2 and 12.1–12.2.

The implementation delivery sequence required all fixes, commits, pushes, remote-HEAD/CI verification and PR-description updates before exactly one final top-level `@coderabbitai full review` request, with its status reported externally and no automatic push afterward. PR #33 was to remain draft at implementation readiness; task 5.3 required separate post-merge authorization. These historical instructions do not govern publication of the separately authorized documentation PR.


## Historical final logging freeze verification

- Flutter 3.47.5 / Dart 3.13.4; dependency locks and native SDK integration unchanged.
- Focused logging, Debug viewer/navigation/Explore and Admin editor suite: 324 passes. The null-Talker regression also passed independently, with zero local metadata reads, one eligible application capture, no nonreportable captures and one separately owned SDK capture. Final serialized envelopes excluded its private canary and retained approved operation/breadcrumb context.
- CI-equivalent autonomous selection: `TZ=Europe/Rome flutter test --no-pub --reporter expanded` across all 195 `test/**/*_test.dart` files except `test/integration/**` at commit `1ccdbe3aecebd6a733fd38db6b6a44372540fdd1`: 4,107 passes and four existing skips. This includes sync, Cloudinary/association, public/Admin submissions, command, routing, bootstrap/consent/settings, networking and envelope/concurrency regressions. Local-service integration tests remain excluded under the existing CI contract.
- `flutter analyze --no-pub`: clean. `dart format --output=none --set-exit-if-changed` on changed Dart files, static logging-boundary tests, `git diff --check` and `openspec validate simplify-application-logging --strict`: passed.
- `flutter build apk --profile --no-pub`: passed. This validates a real non-Debug compilation alongside structural guard checks; the artifact was not deployed or executed. Existing toolchain/plugin deprecation warnings do not establish a runtime defect. No Release runtime, native privacy or actual Replay recording claim follows.
- Independent read-only review covered the complete PR against current main, connected production paths and applicable tests/deltas. No material production defect was found; an automatic-event scope-attachment qualification was corrected without changing application-envelope protections. The reviewer inspected tests rather than independently executing them.

The implementation PR description was reconciled to the frozen contract. Final implementation commit/remote HEAD, CI and CodeRabbit request/status belong to PR #33 and its delivery response. Task 5.3 was deferred at that checkpoint.

## Post-merge documentation lifecycle

PR #33 is verified merged, and its merge commit `479250e213de46bd4bb6374e14d36873ee66476a` is contained in the fetched `main` baseline. Separately authorized task 5.3 synchronizes all three approved deltas and archives this change on November 7, 2026. Historical research and implementation verification remain attributed to their original checkpoints; this documentation work supplies no new native, Replay, runtime or server-grouping evidence. The separate documentation PR is prepared for publication and owner review, with live publication/check status recorded externally. Its merge requires explicit authorization; no deployment is authorized.
