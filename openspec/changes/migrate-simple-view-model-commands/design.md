> **Traceability:** Sections before “Apply evidence — 2026-10-20” record historical planning/remediation. Apply evidence precedes the independent CR-F1–CR-F3 review. Post-apply remediation explicitly supersedes the historical prohibition on reconciling Sentry consent after disposal, without restoring presentation authority. Publication is recorded separately at the end.

## Context — historical planning

See proposal.md for motivation/scope. **VERIFIED** means inspected code/documents or executed commands; **PROPOSED** means planned strategy; **INFERENCE** means source-derived consequences requiring regression tests. This documentation-remediation phase changed four existing artifacts without apply.

### Preflight and provenance

F1–F6 preflight re-read AGENTS.md, five artifacts, six ViewModels in the earlier scope and the canonical specification. R1–R3 re-read those instructions/artifacts, canonical command-execution-concurrency and relevant cleanup/Favourite/Theme/repository/reporting sources/tests against origin/main and resolved packages. No nested AGENTS applied. The remediation request authorized the document changes without per-artifact confirmation. Repository-local root, spec-driven schema; .openspec.yaml unchanged (`created: 2026-10-19`, no skip_specs).

Fetched origin/main was `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, matching the requested baseline. HEAD was `556c62b0d1e57dbebc24d2fb2e19da1785aeab09` on `codex/resolve-flutter-analyzer-diagnostics-pr3`, 0 ahead/7 behind. This old checkout was not the implementation base: apply required the latest verified origin/main and reconciled drift. No checkout/reset/merge/worktree creation occurred in that phase.

Initial state: ` M AGENTS.md`, `?? openspec/changes/migrate-simple-view-model-commands/`, `?? openspec/changes/resolve-flutter-analyzer-diagnostics-pr4/`; empty index. Initial tracked/nonignored-untracked hashes were captured to verify only four authorized artifacts changed; all other work was preserved.

Targeted HEAD↔origin/main comparison found the six ViewModels, foundation, canonical and dependencies identical. Main also included PR4 explicit awaits in UseCases/Result/fakes/tests; the Category selector difference was excluded. Main code and archived PR4, rather than untracked planning or old PR3 fakes, were authoritative. Foundation archive `2026-10-12-adopt-command-it-restartable-foundation` and PR4 archive `2026-10-19-resolve-flutter-analyzer-diagnostics-pr4` (including ledger 125) were inspected as history, not substitutes for current code.

Foundation: lib/utils/{command,result_command,restartable_command,command_configuration}.dart and test/utils/{result_command_test,command_it_disposal_behavior_test}.dart. Resolved source: `<pub-cache>/hosted/pub.dev/command_it-9.5.2/lib/command_it.dart`, especially run 312–413, dispose 799–825, runAsync 859–870. Pubspec ^9.5.2/lock/package_config resolved command_it 9.5.2 and listen_it 6.0.0; Flutter 3.47.5/effective Dart 3.13.4. No pub get/upgrade. Lifecycle conclusions used this source, not an online latest version.

### Baseline and diagnostics — R3

**Verified historical result.** The first analysis used origin/main snapshot `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, from `<worktree>`, with the direct Dart SDK:

```sh
<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <snapshot> > <evidence-dir>/molise-command-planning-analyze.log
```

These are portable placeholders for the historical executable/cwd/snapshot/output locations, not verbatim path evidence. Arguments were `--format machine` and one absolute snapshot directory: no --fatal-infos or explicit fatal-warning override. Resolved Dart help confirmed warnings fatal by default and INFO nonfatal. The process transcript recorded **125 INFO, 0 WARNING, 0 ERROR, raw exit 0**; counts alone do not establish exit, and the machine log alone lacks argv/cwd/exit. This was not flutter analyze.

**Historical independent replay.** R1–R3 re-read the original log (SHA-256 `aa6b5d4f212e9a0305ff5c8526c1b2ff6b2f6ba74ed378944ad28f23a7a87f11`). A nonmutating subprocess replay used the same argv/cwd, saving stdout/stderr/metadata as `<evidence-dir>/molise-r123-analyzer-replay.log`, `.stderr` and `.json`. Measured **raw exit 0; 125 INFO, 0 WARNING, 0 ERROR; empty stderr**. Stdout was byte-identical with the same SHA-256. This was a distinct verification run, not the original process.

All 1.072 regular Git-archive files matched the snapshot before replay. Temporary package_config SHA-256: `081b825b3c18f33193decbd1ad6c94f0b69c3a6510ec84d6298d8a8315ae1356`. Versions: Dart **3.13.4 stable macos_arm64**, Flutter SDK metadata **3.47.5 stable**, framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`; command_it 9.5.2/listen_it 6.0.0 from lock/package_config. No Flutter suite ran in this planning replay.

**Proposed reproduction.** From project root, extract `git archive <verified-origin/main-SHA>` into a new empty temporary directory without checkout. Copy only resolved package_config to `<snapshot>/.dart_tool/package_config.json`; in that copy change only moliseis.rootUri from `../` to the resolved snapshot absolute URI (`Path(snapshot).resolve().as_uri() + '/'`). Preserve SDK/dependency entries and verify targets exist. A discarded attempt used a temporary-directory alias rather than its resolved location and produced artificial part-of diagnostics. Do not adapt checkout package_config or run pub get/generation/upgrade.

Use the command above with the new snapshot as sole positional argument/new log. Capture cwd/base SHA/versions/full argv/temporary adaptations/stdout/stderr/severity counts and **analyzer process returncode**; read subprocess.returncode or immediate shell `$?`, without masking pipelines. Compare metadata before/after apply. Record `flutter analyze --no-pub` independently if used; wrapper defaults/exits are not interchangeable. Temporary logs are historical ephemeral evidence, not current accessible prerequisites. Their existence was verified then; this reconciliation does not claim they remain available.

**Ledger.** All 125 machine rows were `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. The durable full identity/multiplicity inventory is the appendix of `openspec/changes/archive/2026-10-19-resolve-flutter-analyzer-diagnostics-pr4/design.md`. Apply required regeneration on its execution head. First-change targets:

| File under lib/ui | Baseline origin/main line:column | Total |
| --- | --- | ---: |
| settings/view_models/settings_view_model.dart | 13:25, 21:8 | 2 |
| settings/view_models/theme_view_model.dart | 11:26, 12:20, 25:8, 27:8 | 4 |
| explore/view_models/explore_view_model.dart | 15:18, 21:8 | 2 |
| explore/view_models/suggestion_view_model.dart | 13:12, 21:8 | 2 |
| favourite/view_models/favourite_view_model.dart | 20:12, 29:14 | 2 |

Gate: **12 targets** (six constructions/six declarations), **113 remaining**, including eight excluded Category diagnostics. Compare file/rule/symbol/context identities and multiplicity with root/shifted-line normalization, not merely 125−12. Record raw flutter analyze exit separately (INFO may make it nonzero); no lint/suppression/config changes.

## Goals / Non-Goals — historical plan

Five ViewModels/six ordinary lanes; unchanged domain/persistence dependencies. Command owns execution/state; ViewModel owns orchestration/optimism/publication; repository owns domain/persistence; View owns rendering/feedback. Keep Provider/ChangeNotifier, KISS/YAGNI/DRY/SRP/DIP, minimal changes/Rule of Three. No package/interface/speculative infrastructure.

### F1 resolved by authorized exclusion

CategoryViewModel load/setSelectedCategories/setSelectedTypes/setSort and exclusive consumers/tests/tasks were outside this change. Deferred factories do not automatically preserve inline legacy entry/nested queries. Category was reserved for its independent `migrate-category-view-model-commands` change, without incidental error/sort/router-seed/lifecycle fixes or preparatory adapter/scheduler/wrapper/factory here.

Historical sequence: seven OpenSpec changes on one branch/one integration PR, no coordination change or implementation dependency on later migrations. The original plan associated command.dart removal/global zero deprecations with final integration. Publication later retained compatibility code; deletion is separately authorized work.

## Historical audit and six-Command matrix

All actions retain Result<void> via `ResultCommand<P, void>` (P=void for no-param). F3 removes any need for payload changes/completion observers merely to relocate legitimate feature-owned mutations.

| ViewModel / Command | Verified legacy behavior | Proposed migration |
| --- | --- | --- |
| Settings / setCrashReporting | Optimism/notify, repository write, Result.error inversion/notify, SentryLoggingFlag follows final value | createResultCommand<bool, void>; runAsync only for required feedback, verified admission/own Result; lifecycle guards |
| Theme / setThemeBrightness | Optimism/local oldBrightness/error rollback; screen wait has no meaningful continuation | createResultCommand<ThemeBrightness, void>; UI run, runAsync for explicit waits/tests; independent lane |
| Theme / setThemeType | Separate field, same policy; commented color selector; active tests/sync_redirect_test | createResultCommand<ThemeType, void>; same policy without reactivating UI |
| Explore / loadLatest | Autoload/direct getLatest; success replaces list/notify, error retains | createResultCommandNoParam<void>; constructor/retry run; live continuation commit |
| Suggestion / load | Autoload/getSuggestions; error assigns []; notify; immediate legacy disposal | createResultCommandNoParam<void>; preserve distinct retention, guard continuation/safe cleanup |
| Favourite / load | Place IDs/objects/commit, then events/commit; first failure; ViewModel forwarding | createResultCommandNoParam<void>; sync admission, capture load rejection during writes, results forwarding/post-settlement cleanup |

### Consumers and tests

SettingsScreen consumes both preference owners; main.dart Consumer<ThemeViewModel> reads themeMode on notify. Change only ExploreScreen latest, not Event/coordinator. SuggestionHorizontalListView observes load/skeleton/error/retry/empty. FavouriteScreen observes **the ViewModel**; FavouriteButton reads isUpdating/membership and directly awaits setFavourite. Preserve Provider scopes in dependencies.dart/router.dart.

Five suites: test/ui/settings/view_models/{settings_view_model_test,theme_view_model_test}.dart, test/ui/explore/view_models/{explore_view_model_test,suggestion_view_model_test}.dart and test/ui/favourite/view_models/favourite_view_model_test.dart. Relevant consumers: settings_screen_test, favourite_button_test, latest/suggestion/screen widgets, sync_redirect_test and Provider tests instantiating these owners. Reuse execution-head test/support/{fake_repositories,fixtures,command_test_support,favourite_button_harness,sync_harness}; add no tests exclusive to excluded features.

## Decisions — historical planning

### D1 — Foundation and F3 MODIFIED resolution

Use existing createResultCommand/createResultCommandNoParam/ResultCommandSnapshot, not RestartableCommand/new factories/legacy adapters or forced terminal staging. Live owner plus accepted single-flight execution retains authority; no generation token is needed without supersession. Theme fields remain independent; Favourite direct mutation is coordinated explicitly with its read Command.

Authorized MODIFIED delta preserves canonical requirement name `Only authoritative completion can commit asynchronous data` and its existing scenario. Restartable/latest-intent retrieval remains pure with synchronous authoritative completion commits, including Search/GeoMap. Ordinary single-flight may retain optimism/progressive publication/rollback inside live authoritative continuations. Disposal revokes presentation commit/rollback/notify/new repository phases; it does not physically cancel already-started persistence. Do not force Favourite terminal staging.

Capability compatibility: execution states/failure kinds unchanged; Result.error is not a throw; privacy-aware reporting once/assertion policy unchanged. Newest intent/cross-type Map ownership/late stale-error reporting unchanged. Public completion/forwarding observers detach before owner notifier disposal; retained Commands serve private settlement/reporting/cleanup only. Forecast/unmigrated lanes receive no semantics. No canonical synchronization during planning.

### D2 — Snapshots and rendering

Observe command.results once per build through existing extensions. Command.value may retain an old Result and is not current-outcome proof; factories exclude last-result data from loading/failure snapshots.

| Snapshot | Consumer contract |
| --- | --- |
| idle/never-run: data=null, no error | No false success/empty success; expected discovery bootstrap skeleton permitted |
| isRunning | Loading/shimmer; feature-specific ViewModel retention; sync admission separate |
| completed: Success<void>(null) | Actual success distinct from initial null; list/grid or empty state |
| domainError | Original application Exception and expected error/retry |
| unexpectedError | Terminal runtime failure/error UI and original global reporting; no fabricated Result.error |
| next run | New loading/outcome, never old value promoted to current success |

Explore retains on Result.error, Suggestion clears and Favourite preserves progressive sides. Assertions remain fail-loud development failures. Favourite results forwarding includes outcomes without a new Command value.

### D3 — run, runAsync and Settings feedback

Verified resolved source: run synchronously admits/raises isRunningSync/publishes loading, then awaits Duration.zero before handler entry. Duplicate run is ignored. runAsync can join a pending completer, including work started by run; restrictions/no-start can leave waiting pending. Dispose completes waiters with current value, not operation success. Handled raw throws fail runAsync as well as global reporting; Result.error is an ordinary value.

Use run for constructors/retry/UI callbacks without continuations, without async/unawaited wrappers. Use runAsync for explicit test waits and Settings feedback only from a live owner with a new admissible request (`!isRunningSync.value && canRun.value`), no await between check/call. Async notifier state is not admission. Feedback call sites are UI events, not reentrant terminal listeners; runAsync from such listeners does not establish a new execution.

SettingsScreen captures owner/input before await, ignores rejected duplicate callbacks and observes **its own returned Result**, not command.value or a later run snapshot. Snackbar requires enable=true, Success<void>, mounted context and identical current Provider owner. Observe Future errors locally without Object→Result conversion or another report (an error continuation may end the already-reported UI wait). Restore test handlers. Disposal/owner replacement wait completion gives no feedback; add no widget lifecycle holder.

Declared UX correction: legacy callback showed success for value=true even after Result.error. Migration suppresses that message on failure; this is the only authorized intentional UX correction, not failure-branch equivalence.

### D4 — Error handling

Preserve Result.error/Exception identity, factory globalHandler, reporting while results are observed, and assertion policy. Replace legacy FlutterError.reportError only for migrated Commands with foundation reporting, without duplicate reports or command_configuration/whitelist/logging changes.

setFavourite remains direct Future<Result<void>>: preserve _persistFavourite catch on Exception; non-Exception errors still throw with no automatic Command-global report. Raw StateError does not become application rollback; a normal live application failure retains exact rollback.

### D5 — Local lifecycle cleanup — R1

**Immediate public revocation; deferred physical cleanup for every Command, including idle.** Owners set _disposed immediately/idempotently and detach owned listeners, including results forwarding and F2c admission capture. removeListener is supported during dispatch/tombstones removed elements. Never reattach public listeners after revocation; retained listeners are private settlement/cleanup observers only.

Guard action entry, every post-await, post-notify and every new repository phase. _notifyListeners guarding alone cannot prevent forbidden commits/I/O. Already-started writes retain physical behavior; no cancellation claim.

**Upstream evidence, beyond idle.** command_it.dart:249–251 results uses CustomValueNotifier with asyncNotification=false by default (listen_it/src/custom_value_notifier.dart:391–396); results/value notifiers are synchronous, whereas `_isRunningAsync` is asynchronous (775–779). On success terminal results dispatch precedes false sync/value notify; on failure results precedes global reporting/false in finally (369–407, 1000–1024). False’s internal decoupler schedules asynchronous isRunning through Future; finally schedules another zero-delay before optional logging. runAsync may complete before this work. False/terminal snapshot/completed Future alone cannot prove all dispatch finished.

**Deterministic local strategy:**

1. At revocation retain only a private isRunningSync listener per Command and local closing flags (check queued/barrier invalidated by later transition/released). If active, await false; if idle/never-run still request deferred checking. Never call Command.dispose inline from owner/Command notifier dispatch.
2. Coalesce into a microtask that exits the current stack then schedules one event callback through `Future<void>(...)`. Begin a valid barrier when requested; any sync true/false before callback invalidates it. False requests checking without duplicating an already queued check and without modifying public listeners. Do not release in the microtask alone: scheduling the event afterward places it behind known asynchronous notifications/finally zero-delay. This derives from resolved source, not an arbitrary delay or general dispatch detector.
3. Event callback consumes queued flag and rechecks revocation, unreleased state, isRunningSync and barrier validity. If a transition occurred and it is already idle again, request a fresh post-settlement barrier instead of reusing the old one (R1.3). This is event-driven rechecking, not polling/dispose retry. Safety combines revoked authority, exited dispatch, valid barrier across known terminal events and currently nonrunning state. Pending ordinary work remains true; handled failure reporting precedes false; finally lowers false for assertions without normalizing their failure.
4. If still active, do not dispose/poll/schedule periodic retries; wait for next false to request the same barrier. True invalidates the old barrier without periodic checks. Reentrant run before checking is detected; revoked actions cannot start I/O. Public listeners remain detached.
5. When safe, detach private listener and mark released **before** the only Command.dispose call, without retry. Upstream then marks _isDisposing and schedules its own internal 50ms teardown (799–825). Do not duplicate that timer/dispose internal notifiers/use 50ms as action-settlement proof.

A microtask exits current synchronous dispatch but does not run upstream queued events; microtask→event is the required additional step. It does not establish arbitrary external-callback quiescence. This policy applies to resolved ordinary factories without new restrictions/progress handlers; upgrades need another audit. A run after upstream disposal begins is rejected by _isDisposing.

**Owner notifier:** Flutter ChangeNotifier.dispose asserts depth==0 (foundation/change_notifier.dart:376–383). Favourite results→ViewModel.notify→listener.dispose makes super.dispose reentrant too. Always schedule exactly-once owner super.dispose in a microtask after revocation, without awaiting repository work. _disposed already blocks new notify/commits; an existing dispatch may finish its stack. No depth tracker/state holder/hierarchy to retroactively cancel entered callbacks.

No lifecycle manager/factory/reference counting/shared scheduler/polling/unbounded retry/dependency/arbitrary timeout. Local flags coalesce/invalidate/release once; owner disposal is idempotent. Nonterminating work retains private resources until settlement. Late runtime failures preserve one original global report/no secondary notifier errors; assertions remain fail-loud. Action finally/runAsync/results alone are insufficient safe-cleanup evidence.

### Regression matrix R1.1–R1.6 — historical apply gates

Use real Commands/Completers/existing virtual clock/support, reused fixtures/parameterized cases rather than six copies. MockCommand does not prove actual lifecycle. Observe identity/event ordering, not microtask counts. Debug FlutterMemoryAllocations disposal events, installed before construction and identity-filtered (memory_allocations.dart), may prove exactly-once release; restore in teardown. Add no production counter/API. Combine with no double-dispose assertion and flag inspection; absence of FlutterError alone does not prove release.

| Case | Deterministic coordination | Required result |
| --- | --- | --- |
| R1.1 terminal | Dispose from terminal results callback and already-logically-idle value callback | Immediate revocation; no reentrant teardown/notifier-after-dispose/new owner notify; exactly-once release after barrier |
| R1.2 idle | Dispose never-run/completed; Theme one idle/one pending | Always outside-stack release once; pending lane retained until own settlement |
| R1.3 same turn | Settle Completer/dispose in both orders, including terminal callback/new transition during queued barrier | No settlement/dispatch/cleanup collision or lost original report |
| R1.4 active | Revoke with repository pending, then success/Result.error | Private retention; zero new commit/rollback/notify/repository phase; one release |
| R1.5 late failure | Original StateError after revocation; AssertionError variant | Original object/stack once globally, no secondary notifier failure; assertion remains fail-loud, not Result.error/normal global failure; one cleanup |
| R1.6 Favourite | results forwarder→ViewModel.notify→reentrant disposal | Forwarding/admission capture detach immediately; owner notifier outside dispatch; no late commit/notify; Command released once |

Preserve upstream skips: new tests prove owner policy avoiding premature disposal. Use virtual pump/event turns/barrier and documented internal 50ms timer where physical-teardown events require it; no real sleep/invented safety duration.

| Owner | Specific guards/resources |
| --- | --- |
| Settings — historical decision superseded by CR-F1 | One Command; guard after notify/before write and post-await/before presentation rollback/notify. Banning SentryLoggingFlag reconciliation after disposal was incorrect; post-apply shared-consent remediation supersedes it. |
| Theme | Two independent Commands; guards before writes/rollback/notify; app scope does not replace lifecycle |
| Explore | One Command; guard single list commit/notify; no new payload/completion observer |
| Suggestion | One Command; guard error [] assignment; replace immediate disposal with safe settlement |
| Favourite | One Command/direct write API; guards post-await/post-notify/before lookups/later phases/rollback; distinguish public revocation/load cleanup |

## Settings/Theme timing audit — historical planning

Read ViewModels/all preference call sites/main.dart Consumer/tests/SettingsRepositoryImpl on origin/main. Repository copies settings at call time and updates cache after successful persistence; no repository change planned. Independent local lanes do not imply atomic shared-write merging (R2).

| Phase | Verified legacy | Proposed ordinary factory |
| --- | --- | --- |
| 1. Admission | running=true/reset in execute stack; Command notify | isRunningSync=true/loading in run stack; duplicates excluded |
| 2. Local update | Inline action/field assignment; Theme captures old value | Same update/capture after Duration.zero |
| 3. ViewModel observers | Synchronous notify after assignment | Same action-local order later than dispatch; guard if observer disposes |
| 4. Persistence | Repository call after notify, then await | Same order after notify/live guard, then await |
| 5. Outcome | Error rollback/notify; success retains; Settings flag follows outcome | Same live presentation policy; no post-dispose rollback/notify. Historical flag prohibition is superseded by CR-F1; Result.error remains distinct from raw throw |

Real timing difference: same-stack getter after run may still be old. SettingsScreen awaits consent; brightness has no getter-dependent continuation; main rebuilds on notify. Type UI is commented; tests/routing await it. No verified current consumer required same-stack optimism or getter-dependent orchestration immediately after dispatch. Theme lanes affect distinct fields without new latest-wins/common serialization.

Decision: preserve action-local order and explicitly permit deferred entry. Synchronous-call timing changes, but inspected consumer contracts revealed no material regression. Add no inline-entry bridge/snapshot-listener state updates or universal frame/microtask promise.

PREF1–5 gate: record notify values/repository entry using Completers; optimism/notify before write; success retention/application rollback; pre-pump and notify-listener duplicate rejection; both controlled response orders for independent Theme fields and success/failure/disposal combinations. Tests establish local state/rollback/single-flight, not repository lost-update absence. Widget Consumer shows pending optimism/rollback; disposal before entry/from notify/during write prevents forbidden phases. Settings snackbar: zero on failure/throw/duplicate/replacement, one for own enable success. No sleeps/microtask-count assertions. Any newly found same-stack-dependent consumer required stopping affected apply/reconciling the plan.

### R2 — Pre-existing shared-repository lost-update risk

Verified origin/main: separate Theme Commands (initialization 11–12/actions 30–60); SettingsRepositoryImpl.setThemeBrightness/setThemeType both build `_cache.copyWith(...)` (96–104). `_persistNewSettings` awaits `_dataSource.save(newSettings)` and updates `_settings` only on Success (43–50). No mutex/post-await merge/per-field write/transactional lane coordination.

If A=brightness/B=type both copy cache S0 before either save completes, S_A=(new brightness, old type), S_B=(old brightness, new type). Completion order may leave cache/storage with one snapshot, losing the other update while the ViewModel displays both. This demonstrates a pre-existing risk, not inevitability or migration causation.

Keep independent single-flight lanes/local optimism/per-field rollback. No atomicity/serialization/persisted lost-update guarantee or identical global interleavings; deferred entry is declared in F4. A demonstrated additional migration regression requires plan reconciliation, not incidental repair of pre-existing storage behavior. Repository/data source/mutex/queue/coordinator/global serialization fixes belong to separate work. R2 remains a known accepted scope limitation.

Correct PREF acceptance: controlled fake admits both lanes, rejects same-lane duplicate, observes each local update/notify before its write and rollback only for its application failure; exercise both completion orders/success-failure combinations/disposal, no coupling/post-dispose commit. Fake results establish ViewModel behavior, not merging of real AppSettings. Keep tests without requiring final repository to contain both fields; add no persistence promise to delta.

## Favourite adversarial review — historical F2/F3 reconciliation

### Contract and admission

Verified: constructor autoload; isUpdating=load.running||_mutationRunning; setFavourite sets mutation flag before optimism; _load checks it on entry. Optimistic IDs/objects retain exact list/index rollback on Result.error; deduplicated membership IDs survive missing objects. Load publishes the complete place side before events, still queries events after place application failure and chooses the first error; a failed side does not erase the successful other side. MODIFIED permits this progression.

Proposed setFavourite admission: `_disposed || load.isRunningSync.value || _mutationRunning`; preserve sync isUpdating/independent flag and no post-dispose finally update. Load rejects active writes. Keep one results→ViewModel forwarder because Screen/Button observe Provider/ViewModel; detach on disposal. Partial/optimistic ViewModel notifications remain separately necessary.

### F2c — Inverse race and captured admission rejection

Source-derived inference: load.run during a write whose completion precedes deferred handler entry would see _mutationRunning=false and start, whereas legacy entry rejected unavailable. Screen retry is a real input after earlier failure.

Capture one necessary historical fact `_loadRejectedAtAdmission` (initial false). Before autoload attach isRunningSync listener: every true captures _mutationRunning; false does not rewrite it. _load checks _disposed, captured rejection and defensive current mutation flag, returning the same unavailable Result.error without queries when blocked. Next accepted run overwrites capture; duplicates/runAsync joins have no new true transition and cannot alter it.

Single-flight permits one accepted load; sync admission prevents a later write. No token/queue/Future/finally reset is needed. This fact is not derivable from current mutation state. Admission listener performs no I/O/commit/ViewModel forwarding and is distinct from results forwarding; detach before notifier disposal. It covers direct public Command invocation without new entry API/factory/adapter. At planning time this test remained an apply gate, not an executed result.

### Progressive commits, rollback and disposal

Guard after every ID/object await before commit/next lookup. Accumulate each side privately and publish only live. Recheck after place notify before events, and after optimistic notify before persistence (observer may dispose). Already-started write retains direct Result/throw; skip disposed rollback/notify. _notifyListeners guard alone is insufficient. Use D5 for load cleanup without turning the direct write into a Command.

FAV1–8 gates: (1) constructor/run then immediate pre-pump mutation rejected/zero write; (2) pending write→run→write settles before load handler yields unavailable/zero query, duplicate/join preserve capture and next free load works; (3) second mutation rejected; (4) places while events pending/partial success both ways/first failure/dedup IDs/missing object/retry; (5) exact add/remove ordering/rollback including ID without object; (6) disposal in IDs/lookups/between sides/write/from notify before write/events causes no new phase/commit/rollback/notify while preserving started write outcome; (7) late StateError report once/no secondary FlutterError/cleanup once/assertion/reentrancy; (8) forwarding updates Screen and reenables Button on start/terminal/retry. Use real Commands/reused fakes/Completers, not MockCommand for races.

Historical F2 status: strategy defined/compatible with F3 but not yet implemented or verified. Existing partial/rollback/no-FlutterError cases alone did not establish absence of late commits or all races.

## Simplification opportunities — historical decisions

| ID / verified surface | Complexity / proposal | Invariants / risk / tests | Decision |
| --- | --- | --- | --- |
| S1 legacy builders read several state getters | One results snapshot/build + existing extensions (KISS/DRY) | Neutral/void/errors/retry distinct; avoid missed rebuild/false success; widget matrix | ADOPT |
| S2 unawaited(execute) without continuation | Direct run for bootstrap/retry/UI (minimal change/SRP) | One operation, no Future confirmation; preserve necessary waits; counts/Settings feedback | ADOPT |
| S5 Favourite load→ViewModel forwarder | Apparently duplicated; proposal to remove | Screen/Button need load/membership updates and reenabling; FAV8 | REJECT: keep results forwarder with distinct responsibility |
| S6 four Favourite Event/Place add/remove branches | Generic mutation helper despite differing indices/rollback | Exact predecessor/order; abstraction can hide rollback; FAV5–6 | REJECT: Rule of Three does not compel unproven abstraction |
| S7 Favourite mutation/disposal/IDs/objects | Proposal to merge into load Result<void> | Not derivable: direct mutation/missing-object membership/lifecycle; FAV1–6 | REJECT: preserve state; F2c is another necessary distinct fact |
| S8 missing/immediate/incomplete disposers | Immediate revoke, always microtask→event barrier even idle, recheck/release once (KISS/SRP) | Reporting/no new commit/notify/assertions; reentrancy/nontermination; R1.1–R1.6 | ADOPT: no dynamic dispatch detector/manager |
| S9 similar local cleanup in five owners | Global helper across migrations | Different owners/observers; upstream-specific premature framework; lifecycle matrix first | DEFER: no helper/task here |

F3 permits live continuation commits: do not add payload/completion observers/parallel loading-completed-error merely for uniformity, remove required state, rewrite repositories or unify Explore/Suggestion retention.

## Invariants and acceptance gates — historical plan

Six migrated Commands/five legacy-free ViewModels; 12 identities removed/113 preserved with reconciled drift/no new diagnostics. No domain/repository/persistence/backend/ObjectBox change or ID/N+1 latest API. local-content-retrieval membership/order/direct limits remain; SuggestionViewModel is not Search.loadSuggestions. URI/Provider/router retention unchanged.

Only declared Settings false-success UX correction; preserve action-local optimism→notify→write→success/rollback with declared deferred entry and single-flight authority. Distinct application/runtime outcomes, report once/assertions intact; no post-dispose presentation commits/notify/rollback/new phase. Always nonreentrant cleanup including idle after settlement/barrier/recheck D5/R1.1–R1.6. R2 promises no Theme persistence atomicity/serialization; PREF is local. Capture full analyzer metadata/raw exit/identity ledger R3. Five owner suites/relevant widgets/Provider/router/full Flutter suite must pass with identified pre-existing skips. No migration of later areas or global-zero/legacy-deletion gate at this checkpoint.

## Risks / Trade-offs — historical plan

- Deferred preferences: declare timing, characterize current consumers/order, no generic bridge/same-stack promise.
- Favourite races in both directions: sync write admission/captured load rejection, deterministic FAV1–2.
- Reentrant notify disposal: guard after notify before new I/O, as well as post-await.
- R1 idle dispatch: immediate revoke/detach; deferred owner notifier and microtask→event Command cleanup/recheck/once flags; R1.1–R1.6.
- Upstream late throw after disposal: retain Command until safe settlement/reporting; assertions fail loud; idle alone insufficient.
- R2 lost updates: local independence without repository atomicity; separate storage fix, no new infrastructure.
- R3 incomplete log metadata: exact executable/argv/cwd/defaults/raw exit; separate replay/history and apply identity ledger.
- Nonterminating Future: private retention, no added timeout/cancellation.
- Already-started writes: no late presentation or persistence-cancellation promise; preserve direct outcome.
- Settings join/retained value: no-await admission check/own Result/current owner/context; observe UI wait error without duplicate report.
- Base/SDK drift: repeat preflight/resolved lifecycle source/ledger, no implicit caret upgrade.

## Migration plan — historical

At this phase only documentation remediation was authorized. After independent review/apply authorization: common branch from verified origin/main, isolated checkout if user work present, transfer approved artifacts only (not old PR3 code/PR4 plans). Characterize/migrate Settings/Theme, Explore/Suggestion, Favourite, consumers/routing, then validate. No future implementation dependencies; one later integration PR. Any rollback is limited to attributable diff, preserving others, never global reset/clean.

Before apply tests/edits load test-support-reuse/dart-add-unit-test/relevant widget-integration/lifecycle/static-analysis skills. Reuse updated main support, Completers/virtual pumps; MockCommand only for projections; no sleep/production test seam. Focused tests precede full `flutter test --no-pub`, analysis and full base diff.

## Adversarial planning self-review

| Finding | Severity / evidence | Historical disposition |
| --- | --- | --- |
| F1 deferred entry/nested orchestration | HIGH; inline legacy action vs upstream zero timer | RESOLVED BY EXCLUSION to separate Category change |
| F3 uniform commit rule | HIGH; general canonical text vs progression/rollback | RESOLVED IN PLAN by authorized MODIFIED distinction; stale scenario/Search/GeoMap retained |
| F2 async admission/late rollback-commit | HIGH; async isRunning/post-await _load/mapError | STRATEGY DEFINED: sync admission/independent write/progression/guards/cleanup; apply tests required |
| F2c write finishes before load entry | HIGH; zero timer before mutation guard | STRATEGY DEFINED: capture rejection at sync admission without API/bridge |
| F4 preference timing | MEDIUM; getter can be old after dispatch | RESOLVED IN PLAN: declared delay/no verified same-stack consumer/PREF1–5 |
| F5 Settings false snackbar | MEDIUM; callback ignores Result | EXPLICIT CORRECTION: own Success<void>, failure/throw/duplicate/dispose tests |
| F6 notify disposal before I/O | HIGH; synchronous notify followed by phase | STRATEGY DEFINED: post-notify/post-await guards, unavailable if write never began/no late rollback |
| R1 idle cleanup/settlement dispatch | HIGH; sync notifiers/async UI running/depth assertions | REMEDIATED IN PLAN: D5/barrier/deferred owner/once flags/R1.1–R1.6; tests future |
| R2 shared Theme storage | MEDIUM; copyWith/save/cache timing | DOCUMENTED: pre-existing risk/no persistence promise/serialization; local PREF |
| R3 analyzer provenance | LOW; machine log lacks argv/exit | REMEDIATED: exact metadata/URI adaptation/historical exit/separate measured replay/hashes/ledger |

No runAsync admission/success assumption, Object→Result catch, forwarding removal, premature cleanup or preparatory production refactor for later migrations. ADOPT items enter feature tasks; DEFER does not. Concrete strategies were not yet executed. Historical **READY FOR INDEPENDENT REVIEW** meant no known material planning blocker after audit, not approved review/tests/READY FOR APPLY. Independent review needed to challenge F2c, reentrant disposal, feedback ownership and restartable compatibility.

## Earlier F1–F6 remediation validation — 2026-10-19 (historical)

- Strict `openspec validate migrate-simple-view-model-commands --strict --no-interactive`: **exit 0**.
- `git diff --check`: exit 0; all five untracked files checked for trailing spaces/tabs/final newline.
- Five artifacts/four edited/.openspec.yaml unchanged; **1 MODIFIED requirement, 4 ADDED, 23 scenarios; 23 unique unchecked tasks**. No Category in requirements/tasks, only provenance/exclusion in proposal/design.
- Exact canonical MODIFIED name and `Superseded retrieval returns data` scenario preserved; other six canonical blocks unchanged. D1 checked ordinary allowance did not weaken restartable/error/assertion/ownership/lifecycle contracts.
- Tracked/nonignored-untracked SHA-256 comparison showed only proposal/design/tasks/delta changed. Metadata/canonical/production/tests/support/dependencies/config/AGENTS.md/existing PR4 plan unchanged; no future change created.
- HEAD/branch/origin/main/empty index and three initial working-tree entries unchanged. No apply/implementation test/commit/push/PR/archive. Cited baseline analysis was earlier actual execution on that same main.

Verdict: **READY FOR INDEPENDENT REVIEW**; structural validity did not establish architectural approval/apply readiness. Regression gates remained future work.

## R1–R3 self-review/validation — 2026-10-19 (historical)

R1 documented immediate revoke/detach, deferred owner teardown/barrier even idle, transition invalidation/recheck/once release. Idle/Future/microtask alone was not universal dispatch completion; no infrastructure/polling/arbitrary delay. R1.1–R1.6 became owner/common future gates.

R2 documented copyWith/save/cache lost-update risk and no implicit atomicity/serialization/repository/coordinator fix. PREF verifies local admission/single-flight/rollback/disposal rather than persistent fake merging. MEDIUM risk remains known/outside scope.

R3 separated historical command/cwd/defaults/SDK/temp URI/exit from new replay (raw exit 0, identical 125 INFO/0 WARNING/0 ERROR). Apply still required identity regeneration; Dart/Flutter exits were not conflated.

Scope stayed 5/6/12/113, seven changes/one PR, Category excluded. F1–F6/F2c/direct setFavourite/forwarding retained. MODIFIED and existing scenarios stayed; one observable nonreentrant terminal-dispatch scenario was added, without persistence guarantees.

Current-at-that-time counts: five artifacts/.openspec.yaml unchanged, **24 unique unchecked tasks, 24 scenarios**, 1 MODIFIED/4 ADDED. Earlier 23/23 counts above remain an earlier checkpoint. S8 strengthened; S1/S2 ADOPT, S5/S6/S7 REJECT, S9 DEFER retained.

Strict validate, `git diff --check`, `git diff --cached --check`: exit 0; untracked whitespace/newline checked. Hashes confirmed only four authorized artifacts changed. HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`, fetched main `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, empty index; same modified AGENTS/untracked change+PR4 entries.

Historical **READY FOR INDEPENDENT REVIEW**: R1–R3 applied to documents/no known material planning blocker, R2 unresolved in product but explicit. No apply/full Flutter suite/commit/push/PR/merge/archive; strict validity was not apply authorization.

## Apply evidence — 2026-10-20

### A. Baseline and environment

User explicitly authorized apply on 2026-10-20. Earlier readiness labels refer to planning. Dedicated `<worktree>`, branch `migrate-simple-view-model-commands`; initial/final HEAD and local origin/main `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. Compared with historical `d16f737`, only AGENTS/skill metadata changed: no affected code/foundation/dependency/canonical drift. This local apply did not fetch/sync/checkout/create worktree/commit/push/update PR.

Initially only the five reviewed untracked artifacts; finally implementation/test/artifact diff uncommitted, empty index. No PR3 code imported. Flutter 3.47.5/framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`, Dart 3.13.4, command_it 9.5.2/listen_it 6.0.0; no pub get/upgrade.

Missing ignored .dart_tool/package_config.json/package_graph.json were prepared temporarily from already-resolved main-checkout dependencies; only moliseis.rootUri was adapted to resolved worktree URI. No tracked config changed. Flutter wrapper required writing external SDK cache.

### B. Six implemented Commands

| Owner/operation | Factory/consumer | Concurrency/lifecycle |
| --- | --- | --- |
| Settings/setCrashReporting | createResultCommand<bool, void>; screen awaits its accepted request Result | Single-flight, optimism/notify before write; live rollback; isDisposed blocks admission/feedback. Historical live-only flag rule was subsequently corrected by CR-F1 below. |
| Theme/setThemeBrightness | createResultCommand<ThemeBrightness, void>; screen run | Independent lane/local old brightness/rollback; before-I/O/post-await guards |
| Theme/setThemeType | createResultCommand<ThemeType, void>; sync_redirect_test runAsync/virtual pump/Result check | Independent lane/local old type/rollback; commented selector remains inactive |
| Explore/loadLatest | createResultCommandNoParam<void>; bootstrap/retry run/latest results | Single-flight/live atomic list commit; error retains, empty success clears |
| Suggestion/load | createResultCommandNoParam<void>; bootstrap/retry run/SuggestiondHorizontalListView results | Single-flight/neutral-loading skeleton; error clears; empty success distinct; unmodifiable list |
| Favourite/load | createResultCommandNoParam<void>; bootstrap/retry run/screen snapshots/direct Button API | Single-flight/F2c capture/live progressive publication/results forwarding detached on revoke |

All owners implement local D5: immediate idempotent revocation, entry/post-notify/post-await guards, microtask super.dispose and private active-Command retention. microtask→event cleanup rechecks running/barrier invalidation; detach private listener/mark released before one disposal. No global lifecycle abstraction/new factory. S1/S2/S8 adopted; S5/S6/S7 rejected and S9 deferred.

Intentional differences: deferred preferences; runtime failures distinct from Result.error; Settings snackbar only for own enable Success<void>/mounted context/current live owner. Ignored/joined/failure/throw/unmount/disposal/replacement yields no positive feedback. R2 unchanged, no mutex/serialization/persistent merge guarantee.

### C. Favourite evidence

F2 sync admission rejects writes immediately after bootstrap; independent mutation flag rejects second writes. F2c listener before autoload captures every accepted load, not duplicate/join; write finishing before load entry still yields unavailable/zero new query, next free load succeeds. Places publish before events; partial successes in both directions/previous failed-side retention/first error preserved. Deduplicated IDs/membership without objects and exact Event/Place add-remove rollback/order preserved.

Disposal during IDs/lookups/between sides/writes/optimistic notify prevents new commits/rollback/notify/I/O. A started direct write retains its Result/throw; late direct StateError does not use Command-global reporting or undo revoked optimism. Real Provider Screen/Button confirms forwarding/error/retry/reenabling; reentrant disposal tested separately.

### D. Lifecycle R1.1–R1.6

`test/ui/ordinary_view_model_lifecycle_test.dart`: 79 real-Command cases over six lanes; `test/support/ordinary_view_model_lifecycle_support.dart`. R1.1 terminal results/value; R1.2 never-run/completed/Theme other idle lane; R1.3 both settlement-disposal orders and queued-barrier invalidating true→false; R1.4 pending success/error and pre-entry revoke; R1.5 original StateError/ArgumentError object/stack once and original fail-loud AssertionError; R1.6 Favourite forwarding→ViewModel notify→dispose. Optimistic Settings/both Theme notification revocation before persistence added.

Identity-filtered FlutterMemoryAllocations ObjectDisposed events prove zero release during dispatch/pending and one after settlement, including duplicate dispose. Not merely absence of errors. Restore global handlers/SDK probes; no production seam. Virtual event turns/internal 50ms timer, no sleep. Nonterminating Future deliberately retains private resources, without timeout/external-write cancellation promise.

### E. Analyzer R3

Same executable/argv for baseline/final; cwd dedicated worktree. Portable command representation:

```text
<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <worktree>
```

Default fatal warnings/nonfatal INFO; no --fatal-infos. Baseline **raw exit 0**, final **0**, empty stderr. **125 INFO → 113 INFO**, zero warnings/errors both. Counter comparison by path/rule/message (symbol/context), normalizing root/line shifts: exactly 12 identities removed, zero new, all 113 residual identities/multiplicities unchanged. Original positions are the R3 target table above (Settings 13:25/21:8; Theme 11:26/12:20/25:8/27:8; Explore 15:18/21:8; Suggestion 13:12/21:8; Favourite 20:12/29:14).

No flutter analyze ran; no exit attributed to it. Historical stdout/stderr/argv/cwd/SHA/version metadata/baseline-final ledgers/comparison JSON were in `<evidence-dir>/molise-simple-apply-evidence/`, ephemeral local provenance, not currently guaranteed accessible. Tracked ledger/history remain durable.

### F. Tests actually run — historical local apply

- Baseline five legacy suites: 34 passed; preference characterization: 11 passed; Favourite write→load characterization: 1 passed before edits.
- Settings/Theme/widgets: 31 passed first gate; later Settings/Favourite widget run: 21 passed (overlapping suites).
- Explore/Suggestion/Home gate C: 24 passed.
- Favourite gate D: 23 passed; final late-direct-throw/event-lookup-disposal version: 25 passed.
- Lifecycle initially 76 passed, finally 79. Final combined lifecycle/Favourite: **104 passed**, exit 0.
- Router sync/four foundation suites: **65 passed, 3 pre-existing skips**, exit 0; result_command/restartable_command/command_configuration/command_it_disposal_behavior.
- Provider/router after cleanup adaptation: 277 passed, one skip; that run’s one failure was unavailable shell-loaded ObjectBox runtime. DI smoke with correct runtime: 1 passed, exit 0.
- Final full suite: **2366 passed, 0 failed, 6 pre-existing skips**, exit 0. 191 hidden framework events were not application pass counts.

First full run failed for absent native ObjectBox runtime and pending timers after automatic migrated-Provider unmount. No assertions weakened: testOwnerUI executes original callbacks then unmounts/drains virtual barrier/upstream teardown. Other-feature tests changed registration/import/format only; those production Commands were not migrated.

Official ObjectBox C 5.3.2 macOS runtime was temporary only; objectbox-macos-universal.zip SHA-256 `680c598573ede04b9762565d48d4e161ad286f786f159abb8da89353bfa1d0bc`, checked against official release digest. No dependency changed. Because the macOS shell dropped DYLD_LIBRARY_PATH, final full run launched Flutter directly (portable paths):

```text
DYLD_LIBRARY_PATH=<evidence-dir>/molise-simple-apply-evidence/runtime/lib TZ=Europe/Rome <flutter-sdk>/bin/cache/dart-sdk/bin/dart <flutter-sdk>/bin/cache/flutter_tools.snapshot test --no-pub --reporter json
```

Exit 0 belongs to this process, not the earlier failed wrapper. Historical outputs: full-suite-final.jsonl/.stderr/.json in that temporary evidence directory. Same six HEAD skips: local all_day_pipeline, local external_event_token_pipeline, three upstream command_it_disposal_behavior late-StateError cases, inactive-branch Back upstream #188018 in geo_map_route_test. No new skip; two local Supabase/Deno smokes were **NOT RUN**, not simulated passes.

### G. OpenSpec and consistency

24 tasks verified; no canonical synchronization/archival. OpenSpec 1.14.3 strict originally warned four approved ADDED requirements exceeded 500 characters; wording was shortened while names/obligations/all 24 scenarios remained unchanged. No D1–D5/F2c/scope change. Subsequent strict validation exit 0. Metadata/proposal unchanged; design/tasks/delta reconciled.

### H. Apply self-review/adversarial review

Full approved-base/HEAD diff limited production to five ViewModels/four consumers. No foundation/command.dart/domain/repository/DI/router/backend/generated/dependency/analyzer/CI change. Other Provider/router test changes served migrated-owner teardown only. Re-read admission/join/rollback/progression/reentrant notify/idle-pending-assertion cleanup/reporting/feedback. Separate read-only reviewer found no remaining material issue and claimed no autonomous tests; user independent approval remained separate.

### I. Historical apply readiness

This verdict preceded CR-F1–CR-F3: **READY FOR INDEPENDENT CODE REVIEW** for the first change only. Diff remained uncommitted then; no push/PR/merge/canonical synchronization/archive/automatic next change. R2/nonterminating-work limits remained explicit.

## Post-apply remediation — CR-F1–CR-F3

### Status and provenance

Later independent review found CR-F1 HIGH (Sentry consent not reconciled after disposal), CR-F2 MEDIUM (obsolete document status), CR-F3 LOW (unselective wrapper expansion). These differ from 2026-10-19 planning IDs. Remediation prompt authorized this phase; earlier readiness neither resolved these findings nor approved merge.

Historical preflight: dedicated worktree/branch migrate-simple-view-model-commands, HEAD/local main `ee60777c7fdfc5c16daa1151050c134fbb7cde29`, implementation already uncommitted. No reset/checkout/fetch/sync/commit/push/PR/main-checkout change. Initial hashes/status were recorded as initial-hashes.json/initial-status.txt under `<evidence-dir>/molise-simple-remediation/` (temporary provenance, availability not asserted now).

### CR-F1 — Shared consent is distinct from presentation

Verified root cause: post-await _disposed guard also blocked SentryLoggingFlag, allowing already-persisted opt-out to leave telemetry enabled. D5 presentation restriction had been wrongly extended to application state shared by AppLogger.

Minimal fix: on normal Result return, before presentation guard, SettingsViewModel assigns flag from _settingsRepository.crashReporting, not request enable/optimistic _crashReporting. Real repository commits cache only after save Success and before Future completion; getter reads it without I/O. Read/flag assignment are synchronous without await/notify, so delayed delivery reads current committed cache rather than old-owner snapshot.

Result.error retains original identity/outcome and does not commit cache; flag still reflects current confirmed consent, never failed request. Unexpected throw does not commit cache here and retains original command_it reporting; no conversion/reporting catch/finally. Assertion/D5 presentation policies unchanged. No post-revoke optimism/rollback/notify/new writes/phases; reconciliation performs no new I/O.

No serialization/latest-request-wins was added. Whole-settings snapshots retain R2 concurrent-write risk. Flag follows current committed cache, which may reflect an older request if its write completed last. No cross-await storage/cache/flag atomicity or cancellation of started writes; no general coordinator.

F1.1–F1.6: six deterministic settings_view_model_test cases cover enable/disable after dispose, original Result.error, both commit orders with reversed Result delivery and original late StateError once. Real SettingsRepositoryImpl, FakeSettingsLocalDataSource optional save callback/shared A-B flag. Test-only DeferredSettingsRepository delays delivery after actual commit/cache; it demonstrates the race without production API/seam or a new repository guarantee. Assert simulated persistence/cache/flag/no late notify-rollback/first I/O admission.

F1.6 retains SettingsScreen own-success/duplicate/dispose/unmount/same-context owner replacement/Result.error/throw cases. SettingsScreen/AppLogger unchanged. R1 common snapshot now concerns **presentation** and excludes shared flag, positively tested by six consent cases. SDK exactly-once/reporting/fail-loud evidence is retained, not replaced with generic teardown.

### CR-F2 — Artifact traceability

Proposal separates current status/planning/remediation/authorization/actual apply. Historical design remains; Settings table explicitly marks CR-F1 supersession. MODIFIED clarifies presentation commits and permits current repository-consent reconciliation without I/O/restored UI authority; restartable Search/Map paragraph unchanged. Two owner-disposed/reversed-commit-delivery scenarios supplement 24 originals (**26**). No canonical change. Task 2.3/6.1–6.4 were selectively reopened until reverified; 7.1–7.3 capture remediation, not wholesale task reopening.

### CR-F3 — Selective test-support audit

Audited all 160 testOwnerUI registration sites in 18 files against initial remediation snapshot. Two unwrapped probes preserved callbacks/assertions/skips; 154 executions intentionally failed solely for “A Timer is still pending even after the widget tree was disposed.” Each KEEP site had a generated case proving migrated-owner timers by stack. This was fixture teardown, often root Providers, not a new architecture requirement for excluded features.

| Test group | Decision | Verified reason |
| --- | --- | --- |
| Direct migrated consumers | Selective KEEP/REVERT | Explore 7; FavouriteButton 8/Screen 1/ViewModel disposal 2 retained. Suggestion reverted all 7 testWidgets (external owner/equivalent cleanup). Settings uses explicit cleanup. |
| Routing with migrated owners | Selective KEEP | Only reproduced Explore/Suggestion/root Favourite/Settings/Theme paths require drain; restoration/router ownership unchanged |
| Unmigrated features | REVERT independent cases | Admin retains 3 Settings cases; Content Submission 2 Home-reaching registrations. Nearby reverts 8 (2 need local pumpCommandTurns for external Favourite bootstrap, no owned-provider teardown). Events retains card case instantiating lazy Favourite. |
| Foundation/lifecycle | Explicit evidence KEEP; no new wrapper | SDK exactly-once/reporting/assertion/interleaving tests remain testWidgets; wrapper does not prove release or replace R1 |

| File | Original wrapper sites | KEEP | REVERT | Evidence / actual dependency |
|---|---:|---:|---:|---|
| `test/ui/core/ui/content/nearby_content_horizontal_list_test.dart` | 8 | 0 | 8 | All 8 revert. Two external `.value` Favourite owners leave constructor automatic-run zero timers; a local `pumpCommandTurns` at callback end drains them. No owned-provider teardown needed. Other 6 already drain/dispose or create no migrated owner. |
| `test/ui/event/widgets/events_screen_test.dart` | 3 | 1 | 2 | Only the nonempty current-day rendering creates the lazy Favourite Provider through event-card Consumers; its constructor/disposal timer needs virtual drain. Empty/error calendar cases never instantiate it. |
| `test/routing/admin_route_test.dart` | 13 | 3 | 10 | Only 3 Settings-screen cases instantiate Settings/Theme providers; 10 authentication/admin/editor/error cases do not. |
| `test/routing/content_submission_route_test.dart` | 27 | 2 | 25 | Only 2 registration sites reach real Home/Explore (successful Home action, failed progress Home exit). Other form/progress/session cases never create migrated owners. |
| `test/routing/route_ownership_test.dart` | 19 | 13 | 6 | Real Post/card paths instantiate root Favourite Provider; stub roots, category/search-only empty paths and unavailable Gallery leave it lazy/uncreated. Keep only reproduced paths. |
| `test/routing/geo_map_route_test.dart` | 22 | 19 | 3 | Real retained Home and populated selected/map/chrome paths instantiate Explore/Suggestion/root Favourite; remove the preexisting skipped registration, explicit route-destruction cleanup case, and direct-map case with no retained Home owner. |
| `test/routing/route_parameter_redirect_test.dart` | 15 | 4 | 11 | Only canonical populated Post, canonical Category Post, cold Search Post and search text round-trip registrations create root Favourite; invalid/error-only and empty category/search cases do not. |
| `test/routing/main_navigation_restoration_test.dart` | 2 | 2 | 0 | Production restored Map/Search Post paths create migrated root Favourite; wrapper acts after restoration assertions, does not manipulate router restoration. |
| `test/routing/events_route_test.dart` | 1 | 1 | 0 | Retained production Home creates Explore/Suggestion and root Favourite owners before Events navigation. |
| `test/routing/home_event_discovery_test.dart` | 6 | 5 | 1 | Five registrations retain real Home Explore/Suggestion; explicit-unmount regression already drains cleanup and reverts. |
| `test/routing/sync_redirect_test.dart` | 16 | 13 | 3 | Retained Home paths own Explore/Suggestion/Favourite; Settings and real MoliseIsApp paths additionally instantiate root Settings/Theme. Error routing after Home still retains those owners. 3 admin/fatal paths never instantiate migrated owners and pass without wrapper. |
| `test/main_scroll_behavior_test.dart` | 2 | 2 | 0 | Actual MoliseIsApp/Home root Provider creates migrated Theme/Explore/Suggestion owners despite unrelated scroll assertion. Existing explicit unmount needs event/50 ms drain. |
| `test/config/dependencies_test.dart` | 1 | 1 | 0 | Directly resolves all advertised root providers including Settings, Theme and Favourite; production-owned disposal needs virtual teardown drain. |
| `test/ui/explore/widgets/explore_screen_test.dart` | 7 | 7 | 0 | All execute production Home with Provider-owned migrated Explore/Suggestion and root Favourite. |
| `test/ui/explore/widgets/suggestion_horizontal_list_view_test.dart` | 7 | 0 | 7 | All 7 revert: fixture owns VM externally; pumpAndSettle and existing explicit loop unmount/dispose/drain already suffice; no added wrapper obligation. |
| `test/ui/favourite/widgets/favourite_button_test.dart` | 8 | 8 | 0 | All instantiate migrated Favourite via owning Provider; actual owner disposal leaves local requestCleanup timer. |
| `test/ui/favourite/widgets/favourite_screen_test.dart` | 1 | 1 | 0 | Owning Provider forwards migrated Favourite load; real cleanup timer reproduced. |
| `test/ui/favourite/view_models/favourite_view_model_test.dart` | 2 | 2 | 0 | Two explicit disposal regression registrations create migrated command cleanup; preserve wrapper to advance its documented internal 50 ms timer. Assertions remain inside callbacks. |

Totals: **160 → 84 retained / 76 removed**. Only registration names changed except two local virtual-clock drains in nearby-content tests. No original assertions, callbacks (other than these drains), variants, skip metadata, production code, or router fixtures changed for F3.

Shared helper unchanged: virtual clock only, no catch/takeException/global handler/automatic skip/router access. It passes original callbacks/variants/skips to the runner and consumes no sync/async framework failures. All 270 probed case names occur in final audit. 84 KEEP/76 REVERT, 10 files reduced, no original assertion lost. Per-execution f3-audit.json was temporary local evidence under `<evidence-dir>/molise-simple-remediation/`; current accessibility is not claimed.

### Post-remediation validation — historical local results

- F1/Settings UI/Theme/lifecycle: 117 passed, exit 0.
- Final 18-file F3 audit: 291 passed, 0 failed, 1 pre-existing skip, exit 0.
- Four foundation suites/SettingsRepositoryImpl: 49 passed, 3 pre-existing skips, exit 0.
- Full Flutter suite: **2372 passed, 0 failed, 6 pre-existing skips**, raw exit 0; same two external local smokes/three upstream command_it/#188018 identities as apply.
- Final test-fixture super-parameter naming adjustment (dataSource → _dataSource for matching_super_parameters): 17 Settings ViewModel/repository tests rerun/passed, then final analyzer comparison.
- Final analyzer: **113 INFO, 0 WARNING, 0 ERROR, raw exit 0**; no identity added/removed relative to approved apply 113; original 12 targets remain absent from 125 baseline. Same R3 executable/argv/cwd, unchanged package_config, empty stderr.
- Strict OpenSpec/`git diff --check`/`git diff --cached --check`: exit 0; untracked whitespace/newline checked.
- Only 15 remediation-changed Dart files formatted. No tracked repository/backend/domain/logging/foundation/DI/router/dependency/generated/analyzer/CI/canonical change.

Approved analyzer reference remained apply’s 113 INFO. A probe-overlapping run temporarily saw 10 unused imports (**123 diagnostics, exit 2**); it was rejected as stable baseline but preserved in baseline.stdout/.stderr/.json for transparency. Final comparison used approved identity/multiplicity ledger without suppressions/rule changes, not that transient attempt.

### Historical remediation closeout

Re-reviewed synchronous cache/flag assignment, commit/delivery order, Result.error/throw/assertion, UI/feedback guards, D5, fixtures/wrappers. Separate read-only adversarial reviewer inspected sources/diff/reported logs, found no material issue and ran no tests; user independent review remained separate. No architectural expansion needed.

Remediation changed 19 files: SettingsViewModel, settings_view_model_test, three support files (ordinary_view_model_lifecycle_support/settings_local_data_source/new settings_consent_support), ten F3-reduced tests and four change artifacts. Full manifest/initial hashes were remediation-files.json/initial-hashes.json in ephemeral evidence. No initial file deleted/other change/main checkout modified. HEAD/branch/local main/empty index remained preflight values during that local phase.

Historical evidence names in `<evidence-dir>/molise-simple-remediation/`: f1-targeted.log, f3-audit.md/.json, f3-probe1.jsonl, f3-probe2.jsonl, f3-final.jsonl, foundation.log, constructor-final-check.log, full-suite.jsonl/.stderr/.json, final.stdout/.stderr/.json, analyzer-comparison.json. These temporary logs are provenance records, not guaranteed current artifacts. Runtime remained official temporary ObjectBox 5.3.2/TZ=Europe/Rome, with the direct Flutter command shown in apply evidence.

Historical verdict: **READY FOR INDEPENDENT CODE REVIEW**, CR-F1/CR-F2/CR-F3 resolved; not merge readiness. At that closeout no commit/push/PR/merge/archive/canonical sync/next migration had occurred. Known pre-existing limitations remained explicit.

## Published checkpoint — subsequent reconciliation

Git verifies implementation/remediation commit `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, parent `ee60777c7fdfc5c16daa1151050c134fbb7cde29`, committed 2026-10-20 and included in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12). This later record supersedes local/unpublished status as a current claim while preserving it as historical evidence. The next checkpoint is Category `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, whose parent is this commit. All seven implementations are now published; historical analyzer progression is 125 → 113 → 105 → 87 → 66 → 52 → 37 → 0 INFO, not measurements made during reconciliation. This checkpoint had 113 INFO, not zero.

The durable code/tests/documentation are in Git. Temporary local logs remain historical evidence with the availability limitations above; recorded SHA-256/counts/outcomes are preserved. CI status must be taken from exact-SHA GitHub Actions checks, separately from these historical local runs; no new-head CI approval is inferred here. Legacy compatibility removal/canonical synchronization/archival/merge remain outside this reconciliation.

Historical remote CI is separate from the local passes above: the [GitHub Actions run](https://github.com/xmattjus/moliseis/actions/runs/39418170941) associated with `9d17d224d5094c5b043128113d9aba6a1ce69f0a` concluded **failure**. This publication record does not relabel that checkpoint as CI-clean or infer the failure cause from local results. Later-head workflow results belong to their own exact SHAs.
