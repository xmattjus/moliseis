# Tasks: simplify-application-logging

> Single implementation PR (#33). Sections 0–5 preserve the original migration and its historical completion state (39 checked tasks, 5.3 still open). Gate A was closed for that scope. Sections 6–12 are the November 7 expansion and are initially unchecked; historical investigation passes do not complete them. Characterize uncertain mechanisms before the affected implementation. No new production work is performed by this documentation revision. Do not merge, archive, sync main specs or deploy as a side effect.

## 0. Revalidate the implementation baseline

- [x] 0.1 Identify the execution branch, HEAD, tracked/untracked changes, and relation to planning baseline `3246b04c8518aef235eab016f42beca4a4fd7bc6`. Inspect any changes to logging/command/telemetry since the baseline; do not overwrite unrelated work.
- [x] 0.2 Read current `AGENTS.md`, the relevant OpenSpec main specs, `openspec/config.yaml`, and the actual resolved versions of `sentry_flutter`, `sentry`, `sentry_supabase`, `talker_flutter`, `command_it`. Recheck version-sensitive SDK options/behaviors against installed source.
- [x] 0.3 Confirm the planning home and change status using OpenSpec CLI in the development checkout; compare this change's delta with canonical `application-observability`, `sentry-consent-lifecycle`, and `session-replay-privacy`. Do not treat archived proposals as stronger than current canonical specs.

## 1. Characterize current reporting (Phase A; no application migration)

- [x] 1.1 Inventory the existing `LogEvent` classes and remote-eligible call sites. Record level, current local/remote behavior, cause attached/missing, metadata keys, any untrusted values, intended diagnostic purpose and prospective destination. Group equivalent low-risk events without silently dropping existing high-value breadcrumbs.
- [x] 1.2 Trace terminal failure ownership and propagation through canonical sync, repositories, `SyncViewModel.sync`, the global `command_it` reporter, Cloudinary upload/cancellation/retry, public submission, Admin staged association/save, and representative route/image failures. Distinguish `Result.error`, rethrows, handled-reportable failures, unexpected throws, automatic SDK captures and multiple independent operations.
- [x] 1.3 Characterize and test `SyncFailure` without an attached cause, `SyncFailureCategory.connectivity`, `CloudinaryRequestFailed.report`, `FileSystemException` command special cases, severity filtering, and the ambient/synthetic `scope.clear()` behavior using `RecordingSentryTransport`. Record actual capture attempts, transported event counts and context independently; do not infer Sentry Issue counts.
- [x] 1.4 Build one or more deterministic envelope tests for a required application breadcrumb preceding an owned report. Exercise the current `unawaited(_addBreadcrumb(...))` path **without test-side artificial awaiting**, and the scope-cleared synthetic path. If feasible control SDK hook delays to expose ordering assumptions. Identify whether missing context is caused by ordering, scope isolation or sanitization.
- [x] 1.5 Inspect active automatic Sentry sources: print/debugPrint integrations, HTTP and `SentrySupabaseClient`, navigation, unhandled framework/native errors, tracing, and Replay. Use synthetic URL/query, header, stack/message, and contributor canaries in representative serialized envelopes. Record the exact observed categories/fields and which protections are owned by the SDK, not `AppLogger`.
- [x] 1.6 Probe failure isolation: event accessor failure, Talker failure, remote call throwing synchronously, remote Future failing asynchronously, and sink independence. Inspect call-site expressions evaluated before `log()`, especially `state.toString()` before and after `ContentSubmissionDraftRepositoryImpl.saveDraft` persistence.
- [x] 1.7 For sync, Cloudinary terminal failure, submission/Admin association, unexpected command, and selected route/image failure, document the minimum *safe and useful* diagnostic fields. Contrast safely reported vs current synthetic errors; distinguish distinct causes in one category when required. Do not claim historical grouping improvement without real Sentry Issue evidence.
- [x] 1.8 Check whether any real application parser/serializer failure justifies a Unicode-specific diagnostic. If no reproducible source/input exists, explicitly defer exact-text reproduction; do not add escaped windows, original strings or user payload capture.

## 2. Gate A — finalized decisions recorded in design (F1–F4 scope)

- [x] 2.1 Update the design with the centralized typed switch and complete local/breadcrumb/report matrix across missing/present causes, `minLevel` and remote level gates, consent flag, category-dependent ownership and whether a report also requires a breadcrumb. Preserve or explicitly justify changing cause-less sync captures.
- [x] 2.2 Mark each existing remotely eligible event as retained, reclassified, localized or removed with an explicit reason, bounded remote field contract, and a justified owner. State separately the conservative default for **new** events; do not apply it retroactively without an inventory.
- [x] 2.3 Document the failure paths that must produce zero, one, or SDK-owned captures and exactly where they terminate/propagate. Reconcile existing sync/Cloudinary ownership with public/Admin and generic handled failures; reject global object-identity deduplication.
- [x] 2.4 Decide which error type/value, stack/frame information, safe origin, breadcrumb and context fields can be forwarded for the selected report families; define the accepted diagnostic loss and testable minimum. Explicitly reject raw arbitrary exception text/stack and `extra` in remote payloads. Preserve original exception/stack locally.
- [x] 2.5 Specify best-effort isolation for both logger internals and diagnostic argument evaluation at call sites, including successful-write/post-log cases. State why the chosen fix does not swallow business failures or require per-call-site broad catches.
- [x] 2.6 Define required breadcrumbs in each report that currently clears scope, and how serialized-envelope tests prove their presence and causal order. Do not prescribe awaiting breadcrumbs unless a demonstrated defect needs the smallest correction.
- [x] 2.7 Resolve only substantiated automatic integration/privacy risks, record sampled evidence limitations and any owner/privacy decision required. Keep consent, Replay and stream tracing under their existing canonical specifications.
- [x] 2.8 Reconcile `proposal.md`, `design.md`, this task list and the `application-observability` delta with Gate A findings. **Stop affected Phase B work** if an architecture/payload decision that changes behavior remains unapproved or contradictory. Do not mark this gate done merely because all characterization tests pass.

## 3. Minimal logging implementation (Phase B; requires approved Gate A on the same PR)

- [x] 3.1 Preserve the public `Logger.log` method and existing Talker/Sentry stack. Implement the smallest reviewed explicit remote-intent policy, with severity independent of capture decision and without a generic three-method API or new dependency. Preserve current `minLevel` unless Gate A justifies changing it.
- [x] 3.2 Migrate legacy event classes and call sites per Gate A inventory; remove redundant special-case switches/flags where the reviewed typed policy subsumes them. Preserve cause-less reports only where deliberately authorized; do not introduce new implicit captures on event severity.
- [x] 3.3 Keep full original error/available stack in local diagnostics. Build safe bounded remote breadcrumbs and error representations that satisfy the approved per-family diagnostic minimum without exporting arbitrary `extra`, input text, URLs, credential material or unscreened exception frames.
- [x] 3.4 Isolate synchronous logger operations and asynchronous Sentry failures per sink without recursive reporting/retries; a Talker failure must not suppress an otherwise independently valid remote attempt. Preserve exception propagation semantics at business boundaries.
- [x] 3.5 Remove or simplify fallible call-site diagnostic pre-rendering in touched flows, especially draft-save before/after successful persistence. Do not change ObjectBox writes, return `Result`, or content-submission session semantics.
- [x] 3.6 Explicitly disable automatic Sentry print/debugPrint breadcrumbs. Retire `filter_breadcrumb.dart` and its hook only when verified that sensitive Talker fragments are absent from remote envelopes and legitimate app breadcrumbs persist. Keep a narrowly scoped hook only if Gate A proves another active integration needs it.
- [x] 3.7 Apply only evidence-backed changes to route/image/URL/coordinate metadata and automatic HTTP/Supabase breadcrumb paths. Preserve necessary distinctions and the existing SDK consent, network ownership, Replay masks and tracing/sample rates.
- [x] 3.8 Update a concise `AGENTS.md` logging contract after the API is stable; reconcile conflicting generic Sentry SDK skill instructions by making project rules authoritative. A project-specific logging skill is optional, not mandatory.

## 4. Verification and anti-regression (Phase B/C)

- [x] 4.1 Test representative policy/cause/level/minLevel/consent equivalence cases, including legacy cause-less `SyncFailure`, category-dependent report decisions and no implicit error-level captures. Observe actual Sentry envelopes and Talker logs, not only mocks.
- [x] 4.2 Test logger and call-site best effort separately: getter/metadata failures, Talker failures, synchronous and asynchronous remote failures, no unhandled diagnostic Futures, no duplicate capture, and unchanged business exception/result identity. Inject before-write and after-durable-write diagnostic failures in draft persistence.
- [x] 4.3 Test required breadcrumb visibility **in the final serialized envelope**, with the actual scope-clearing path, without papering over ordering by extra test-side waits. Retain `unawaited` if it satisfies the contract; introduce sequencing only for a reproduced violation.
- [x] 4.4 Run privacy canaries through typed event data, `extra`, URI query/signed URLs, raw exception message/stack, relevant HTTP/Supabase automatic instrumentation and isolated scopes. Verify allowed diagnostic fields are preserved while prohibited canaries are absent; do not confuse Replay masks with payload sanitization.
- [x] 4.5 Preserve canonical sync outcomes: one truthful terminal, deterministic phase for concurrent preparations, fetched vs committed counts, settings failure after durable content commit, and original throwable/stack locally.
- [x] 4.6 Preserve Cloudinary and public/Admin outcomes: retry-recovered success without terminal alert, voluntary cancellation without error, validated new upload vs reuse, rejected vs unconfirmed post-upload association, replay/idempotency and retained staged receipts. Verify captured count and unchanged functional `Result`/throw behavior.
- [x] 4.7 Check with consent disabled that local diagnostics and normal networking remain available with no custom app capture or SDK initialization. Verify deferred opt-in and bounded opt-out behavior remain covered by their existing tests.
- [x] 4.8 Expand `sdk_boundary_test.dart` to cover actual bypasses (direct capture/logging/breadcrumb/configureScope/tracing, import aliases, direct Talker calls) and file+operation-scoped exceptions; include positive and negative fixtures. Do not adopt AST unless the improved static test has a demonstrated unresolved bypass.
- [x] 4.9 Verify `.github/workflows/pull-request.yml` runs the updated static gate and focused autonomous tests. Check branch rules separately for required status checks. Document that `integration_test/**` is not run by the existing autonomous `find test` invocation; execute relevant native checks separately where the existing consent/Replay acceptance contract calls for them.
- [x] 4.10 Run focused tests, the applicable full Flutter test suite, `flutter analyze`, `dart format` checks and `openspec validate simplify-application-logging --strict` in the implementation checkout. Record exact observed commands/outcomes, distinguish pre-existing failures, and do not claim native, production, privacy or grouping verification without corresponding evidence.

## 5. Delivery hygiene and later lifecycle (Phase C)

- [x] 5.1 Review the entire PR #33 diff (planning plus implementation) against current mainline, applicable `AGENTS.md` and canonical/delta specs. Include only implementation, required tests and justified agent guidance; exclude temporary diagnostics, printed dumps, test logs, local paths and unrelated code.
- [x] 5.2 Obtain a separate review of observable correctness, reporting ownership, privacy boundaries, failure isolation, and deletion of unnecessary logging complexity. Do not equate a passing test suite with absence of defects.
- [ ] 5.3 With explicit user authorization, merge PR #33 after accepted implementation. Only **after** implementation is accepted and integrated, synchronize the approved deltas with `application-observability`, `sentry-consent-lifecycle` and `session-replay-privacy`, archive the change and publish those documentation-only changes in a **separate PR**, requiring its own explicit merge authorization. Do not automatically perform these steps now.


## Historical completion evidence and remaining lifecycle

Tasks 1.5, 3.6, 3.8, 4.8 and 4.9 were completed for the original scope. The November 7 expansion does not imply their tests already cover the new automatic/native/Replay contracts. The console heuristic is removed; actual print/debugPrint integrations and automatic unhandled capture are tested. Final app-report isolation is verified after the installed native-context processor, including approved causal breadcrumbs and synthetic privacy canaries. SDK-owned controls retain native enrichment. The source gate covers aliases, static operations, Hub/HubAdapter construction and direct Talker use with narrow exceptions; it deliberately remains a source check, not semantic analysis.

CI discovers the gate and autonomous regression tests. The active main ruleset requires both Flutter jobs. Native integration tests and OpenSpec validation are not run by that workflow. Historical consent/Replay native acceptance is not presented as fresh execution; the original scope retained those contracts with processor-level regression evidence and device/production limitations. Sections 9–12 now require separate runtime acceptance for the expanded native/Replay/privacy scope; historical completion does not waive it.

Historical original-implementation local verification (not rerun by the November 7 documentation revision): `openspec validate simplify-application-logging --strict` exited 0 without warnings; `flutter test --no-pub test/utils/logging` passed 192 tests; `flutter test --no-pub test/utils/command_configuration_test.dart` passed 6 tests; `flutter analyze` exited 0 with no issues. The CI-equivalent `find test` selection (excluding `test/integration/**`), run with `TZ=Europe/Rome` and `flutter test --no-pub --reporter expanded`, passed 4,053 tests with 4 skips across 191 files. Formatting checks and `git diff --check` exited 0. This includes the affected Supabase, sync, Cloudinary, draft, public/Admin submission and consent regressions, but excludes native integration tests.

Task 5.3 remains unchecked: merging, canonical synchronization and archival require later authorization and a separate documentation PR. No canonical specs are modified here.


## 6. Safe exception discrimination (D2/D3)

- [x] 6.1 Inspect installed SDK exception/frame/grouping-relevant representations and compare bounded category/type/origin versus reviewed source-location alternatives. Include filename/function/line/column, app/package/framework/generated frames, source maps/obfuscation, platforms and missing/unparsable stacks. Complete when a reviewed field contract and privacy/utility comparison identify the smallest viable representation without raw-message fallback or an unjustified dependency.
- [x] 6.2 Implement that bounded diagnostic improvement with maintained real-transport paired tests: distinct same-category causes, unsafe messages/filenames, generated/release representations and absent/malformed stacks. Complete when private canaries are absent, useful distinction/localization is demonstrated where feasible, remaining limits and possible grouping changes are recorded, original local causes and capture ownership remain unchanged. Do not claim server grouping from payloads.

## 7. Isolation assessment and local/export boundaries (D1/D4)

- [x] 7.1 Reproduce C/D single-factor and combined controls through installed processors and full serialized envelopes, including scope/hint attachments, screenshot/hierarchy, malformed contexts, safe technical fields and native scope observer effects. Complete when each retained layer has a distinct justified responsibility and evidence either supports a narrow simplification/allowlist improvement or explicitly retains current protection; any selected change must preserve causal breadcrumbs, correlation and attachment exclusion in regression tests.
- [ ] 7.2 Exercise Talker history/console, viewer copy/export/share/cancel and relevant preview behavior with Sentry consent on/off. Complete when tests confirm original local objects/stacks, no automatic history reconstruction/upload and user-directed sharing independence; implement only observed necessary safeguards, with their focused tests and accurate sharing/privacy explanation. OS-log visibility must not be represented as voluntary sharing.

## 8. SDK-owned automatic Dart policy (D5)

- [x] 8.1 Characterize genuinely unhandled zone, framework and platform-dispatcher routes with synthetic content, installed SDK processing and final envelopes. Complete when a separately reviewed automatic-event field/fallback contract covers mechanisms, chained errors, safe frames/origin, enriched scope/breadcrumbs, privacy and no duplicate app capture; distinguish host controls from mobile runtime evidence.
- [x] 8.2 Implement the reviewed automatic policy and entry-specific transport regressions, deliberately updating the historical hint-less pass-through expectation. Complete when working positive controls deliver identifiable unexpected errors with safe useful diagnostics, private message/frame/context canaries are absent, filter failures retain bounded error visibility, and app-owned reporting/SDK ownership remain intact. Mobile entry limitations require explicit evidence disposition in 12.2.

## 9. Native Android/iOS boundary (D6)

- [ ] 9.1 Inspect authoritative installed/pinned Cocoa and Android sources and Flutter bridges for native event/error/crash entry points, privacy configuration, native callbacks, NSError description/user-info/mechanism fields, Java/NDK differences, frame/thread/image data and consent/cache behavior. Complete when a per-platform field/entry/callback matrix selects the smallest necessary mitigation and distinguishes native sends from Dart-event enrichment; no Dart callback coverage assumption.
- [ ] 9.2 Apply only the necessary platform mitigation selected in 9.1 with focused tests. Complete when native private descriptions/user-info and equivalent Android content are excluded while reviewed technical stacks/threads and capture visibility survive, configuration follows consent, and no replacement native pipeline or diagnostic shutdown is introduced without evidence.
- [ ] 9.3 Execute Android and iOS isolated-destination controls for native-origin nonfatal events and representative automatic native crashes, plus framework errors, before/after effective opt-out and crash-cache/relaunch recovery. Complete when final native envelopes prove private-content exclusion, safe technical utility and working positive controls; separate simulator/device/debug/release evidence, new acquisition and old draining. The historical iOS NSError pass cannot satisfy Android or autonomous-crash acceptance. Unavailable mechanisms/platforms remain unresolved and go to 12.2.

## 10. Replay characterization and necessary safeguards (D7)

- [ ] 10.1 Inventory rendered content and actual Replay capture for public contribution/restored drafts, identity/contact, free text/location, assets/previews, submission errors/confirmation, moderation list/editor/rejection details and log-view/export previews. Complete when synthetic recordings plus source/rendering analysis classify private/unpublished versus deliberately public content, establish on-error behavior and identify Flutter/native overlay/image/platform-view limits. Record unsafe/unobservable surfaces before prescribing masks.
- [x] 10.2 Apply targeted safeguards required by the reviewed classification and add widget-boundary regressions in the same work. Complete when private contributor/contact and classified private user-authored/submission/moderation/diagnostic content are protected while public tourism/editorial context and intentionally public administrator account context remain visible; document and review a fallback if selective protection cannot meet the contract.
- [ ] 10.3 Obtain bounded native Android/iOS recordings and attributed actual Replay inspection for affected private categories, public adjacent controls and error-triggered Replay, plus opt-out/cache lifecycle controls. Complete when masks protect actual recordings without impairing authorized UI use and no new recording acquisition follows verified shutdown. Meet existing canonical combined acceptance; widget masks/beforeSend alone are insufficient. Missing runtime evidence remains unresolved for 12.2.

## 11. Integrated consent, channel and concurrency regressions (D4/D8)

- [ ] 11.1 Reuse consent/bootstrap/networking harnesses and platform controls to cover fresh opt-out/unreadable consent, active consent, persistence-first opt-out, deferred opt-in, shutdown rejection/timeout and old buffered delivery. Complete when app/Dart/native/Supabase/Replay evidence identifies effective channel state, new acquisition stops after verified shutdown, ordinary networking/local diagnostics/export remain functional and UI feedback semantics stay unchanged.
- [ ] 11.2 Add maintained transport-level canaries with acquisition controls for typed projection/raw exceptions, console on/off, SDK-owned events, actual native enrichment, full-envelope attachments and Supabase final event/stream-span payloads. Complete when privacy absence is paired with positive capture/span/approved-field counts, SDK-provided PII/body/SQL protection is retained without duplicate scrubbers, and active HTTP wiring is distinguished from optional wrapper/native capabilities.
- [x] 11.3 Extend deterministic concurrent capture tests beyond T09: delayed processors, app/app/SDK overlap, malformed data and consent transition. Complete when each report retains its own approved diagnostics/hint/causal breadcrumb order without cross-event private data, destructive shared-scope changes or duplication; no invocation-ordered transport assumption or arbitrary test sleeps.

## 12. Readiness evidence and repository hygiene (D9)

- [ ] 12.1 Run focused and repository-required tests/analysis plus strict OpenSpec validation on the implemented expansion; review the entire PR and field-contract/utility comparisons. Complete when production/tests/design/deltas agree, all privacy boundaries have positive controls, links and research provenance are intact and no raw operational evidence, temporary fixtures, SDK copies or unrelated changes are retained.
- [ ] 12.2 Perform final adversarial review with an evidence matrix naming SHA/SDK/platform/build/channel, executed controls, observed results and diagnostic loss. Complete only when each mandatory Dart/native/Replay/consent criterion is met, or its exact environmental limitation, consequence and owner-approved disposition is recorded before any readiness claim. Do not silently waive a failed privacy guarantee, use unavailable platforms as passes, infer server grouping, or reuse historical tests as new acceptance. Retain canonical consent/Replay blockers where their guarantees cannot be met; no merge/deployment is implied.


## November 7 expansion execution state

Seven expansion tasks are complete: 6.1, 6.2, 7.1, 8.1, 8.2, 10.2 and 11.3.
See the [implementation evidence](research/2026-11-07-hardening-implementation.md)
for field contracts, final-envelope controls, exact task dispositions and
remaining acceptance. Checkbox completion does not establish whole-channel
privacy: automatic scope attachments, native SDK reporting, actual Replay
recordings and production export overlays remain explicitly open. The owner
instructed native reporting to remain unchanged after source characterization.
The expansion is BLOCKED, not READY. The archived investigation remains
byte-for-byte unchanged and canonical specs are not synchronized.

New full autonomous execution: 4,101 passing tests and 4 skips across the 195
CI-selected files, with `TZ=Europe/Rome`; `test/integration/**` and native
`integration_test/**` are excluded exactly as in CI. Native/runtime/Replay
privacy is not inferred from this result. Task 5.3 remains outside authorization.

A final source audit temporarily reopened 10.2: dashboard `summary.name` and `summary.city`
are contributor-provided values without a proof-of-publication marker. Their
canonical visibility scenario conflicts with the expanded unpublished-content
contract. The owner then authorized masking original dashboard title/city and revising
only the delta so visibility requires proven public content. The row now masks
those values for every status; all 44 dashboard widget tests pass, including
pending/accepted/rejected controls and preserved normal interaction. Task 10.2
is complete again; actual recording acceptance remains in 10.1/10.3.
