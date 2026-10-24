# Design

## Context — historical planning and later evidence

See proposal.md for problem/scope. **FACT** denotes source/actual output, **INFERENCE** reconstructed interleavings rather than already-executed runtime proof, and **PROPOSAL** the future apply contract. Planning was explicitly authorized on 2026-10-20; independent review then requested F1/F2 documentation remediation. Initial sections retain that history. Apply was authorized later on 2026-10-20 after F1/F2/RF3. Actual implementation/gates and final code-review remediation follow separately. Publication, which did not occur during those local phases, is recorded at the end.

### Verified baseline and provenance — initial planning

- Repository `xmattjus/moliseis`; fetch/push origin `https://github.com/xmattjus/moliseis.git`.
- Dedicated `<worktree>`; local branch `codex/plan-migrate-category-view-model-commands`.
- HEAD `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, created in the preceding turn with `git worktree add -b <branch> <path> <checkpoint>`, no merge/cherry-pick. This was the newly authorized existing checkout, not an unrelated collision; identity/branch/clean state rechecked before writes.
- Dedicated-worktree `git fetch origin`: exit 0. origin/codex/migrate-legacy-commands and Draft PR #12 metadata (`draft=true`, `state=open`, `head=codex/migrate-legacy-commands`) matched checkpoint. The planning request did not authorize apply through older PR gate text, which remained unchanged.
- `git merge-base --is-ancestor <checkpoint> HEAD`: exit 0; rev-list beyond checkpoint zero. No invented child commit during planning.
- Initial working tree/index empty. Three existing worktrees preserved: main at `ee60777c7fdfc5c16daa1151050c134fbb7cde29`, a Codex detached checkout at that SHA and first OpenSpec branch at checkpoint. No duplicate cumulative checkout; main was not baseline.
- Only five change artifacts written. Requested fetch updated shared refs but no other checkout contents/index/branch. External resolved-dependency/metadata reads were read-only; later commands used dedicated-worktree cwd.

### Instructions, schema and dependencies

FACT: AGENTS.md read; no nested AGENTS. openspec-propose skill used; `openspec context --json`/`list --json` resolved repository-local root. CLI **1.14.3**, **spec-driven**, no added config context/rules; proposal/specs/design/tasks instructions read. .openspec.yaml: spec-driven, created 2026-10-20, no skip_specs. Historical CLI versions were not treated as current ones.

Resolved pubspec/lock/package_config: **command_it 9.5.2**, **listen_it 6.0.0**, **go_router 18.0.2**, Flutter **3.47.5**, framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`, Dart **3.13.4 stable macos_arm64**. No pub get/upgrade/generation/new dependency. Timing authority: `<pub-cache>/hosted/pub.dev/command_it-9.5.2/lib/command_it.dart`, run 312–413/dispose 799–825/runAsync 859–870. Also consulted [versioned official API](https://pub.dev/documentation/command_it/9.5.2/command_it/Command-class.html) and [changelog](https://pub.dev/packages/command_it/changelog). Context7 returned no data before interruption and supported no conclusion.

### Regenerated diagnostic baseline — historical initial planning evidence

FACT: analysis ran on Git checkpoint content, not another branch. `git archive <checkpoint>` extracted to `<snapshot>`; only temporary .dart_tool/package_config.json was added from already-resolved main metadata, changing only moliseis.rootUri to resolved snapshot URI and verifying other targets. Main metadata was untouched. Cwd dedicated worktree; portable historical command:

```text
<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <snapshot>
```

Portable placeholders replace historical workstation/snapshot paths; flags are unchanged. No fatal-infos flag; Dart defaults fatal warnings/nonfatal INFO. subprocess.run measured **raw returncode 0**, empty stderr, **113 INFO / 0 WARNING / 0 ERROR**, all `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. Do not attribute exit to flutter analyze. Historical output category-plan-analyzer.log/.stderr/.json under `<evidence-dir>`; stdout SHA-256 `a542fd96198de78a678731293b66ccd6b1ff01dde1726ff597a6ae69b964d6c0`. Temporary evidence was available then; present accessibility is not asserted.

Eight identities in `lib/ui/category/view_models/category_view_model.dart`:

| Line:column | Symbol | Context | Multiplicity |
| --- | --- | --- | ---: |
| 22:12 | Command0 | load construction | 1 |
| 23:29 | Command1 | setSelectedCategories construction | 1 |
| 24:15 | Command1 | setSort construction | 1 |
| 25:24 | Command1 | setSelectedTypes construction | 1 |
| 35:8 | Command0 | load declaration | 1 |
| 36:8 | Command1 | setSelectedCategories declaration | 1 |
| 37:8 | Command1 | setSort declaration | 1 |
| 38:8 | Command1 | setSelectedTypes declaration | 1 |

Durable ledger 125: `openspec/changes/archive/2026-10-19-resolve-flutter-analyzer-diagnostics-pr4/design.md`. Automated ledger comparison after subtracting OpenSpec 1’s 12 occurrences matched all **113** by file/symbol/multiplicity. Future apply required rule/context/multiplicity comparison with root/shifted-line normalization: eight targets removed/**105 unchanged residual identities/zero new**, not count alone. Planning removed no diagnostics. F1/F2 remediation reran no analyzer; baseline remained historical evidence.

### Sources read and consumer map

| Surface read | Evidence/responsibility |
| --- | --- |
| lib/utils/{command,result_command,restartable_command,command_configuration,result}.dart | Real legacy/foundation/Result/reporting/ownership contracts |
| test/utils/{result_command,restartable_command,command_configuration,command_it_disposal_behavior}_test.dart | Deferred entry/single-flight/join/neutral/void/errors/stale/reentrancy/assertions/upstream limits |
| First migration’s metadata/proposal/design/tasks/delta | Category exclusion/D5/R1/remediation; Favourite progression does not imply Category progression |
| Canonical command-execution-concurrency/routing/navigation/local-content-retrieval | Restartable authority/unchanged route bootstrap; local retrieval historical targets do not automatically include Category |
| category_view_model.dart:15–151 | Four Commands/shared list/mutable filters/sort/no dispose override |
| core_routes.dart:23–75 | Sole production Category creation/slug Provider key/unawaited bootstrap/invalid slug before Provider |
| category_screen.dart:45–124 | Menu observes setSort; filter callbacks; body observes ViewModel and load.completed OR setSort.completed |
| category_content_and_type_selection.dart:34–157 | Mutable drafts/wrapper-identity comparison F1/unsafe empty first and empty types labeled Luoghi F2/close-only all reset/post-modal mounted |
| category_use_case.dart:18–24; explore_use_case.dart:25–33 | Result delegation to getByCategories/getAllPlaces/getByCurrentYear; preserve sequence/event temporal semantics |
| settings_repository.dart; settings_repository_impl.dart:43–50,72–75 | Real write Result/cache only on successful save; session/persisted sort may differ |
| Category ViewModel tests | Five existing cases: both sides/first-second failure/equal selection/places only; local builder assumes empty categories |
| Shared selector tests | Sheet/dialog/reset/unmount; not first route frame/replacement |
| test/routing/{route_parameter_redirect,route_ownership,back_navigation_integration,geo_map_route,main_navigation_restoration,restoration_behavior}_test.dart | Slug/all/invalid/branch/Post parent/chrome/shell-Search-Map-Gallery restoration; pending-first-frame Category regressions absent |
| test/support/{command_test_support,ordinary_view_model_lifecycle_support,route_ownership_fixture,sync_harness,fake_repositories,fixtures}.dart; ordinary lifecycle test | Existing real fixtures/fakes/reporting/virtual time; production Category used by route fixture |

Repository-wide reference search found only route/CategoryScreen direct production consumers. Selector is callback-driven; ContentSliverGrid/story callbacks read content, Provider/ChangeNotifier observe ViewModel. Tests/route fixture also consume it. Same-named GeoMap Commands have another owner/excluded scope.

Read-only F1/F2 audit: GeoMapScreen uses shared CategoryContentAndTypeSelection at geo_map_screen.dart:525–532 with legacy callbacks; getters geo_map_view_model.dart:130–141 recreate UnmodifiableSetView, setters :230–258 replace backing sets. Shared fix must preserve callback signatures/confirmation timing/mounted checks. Extend existing parameterized component test; one distinct real GeoMapScreen test verifies wiring/owner rebuild without duplicating sheet/dialog matrix. No production consumer awaits filter-setter outcomes/reads their Command state/requires Commands.

## Goals / Non-Goals — historical plan

Coherent pre-build selection; one combined-filter latest-intent domain; atomic authoritative commit/current sort; no post-dispose presentation. Keep domain/repository/Provider without reconstructing legacy API. No physical cancellation/cross-owner settings serialization/automatic write recovery/session-filter process restoration promise. Do not migrate later areas; shared F1/F2 selector correction and real GeoMap compatibility only.

## Decisions — historical plan

### D1 — Four-Command matrix

| Command | Verified legacy | Proposed alternative | Reason | Future gates |
| --- | --- | --- | --- | --- |
| load | Awaitable single-flight/shared clear/places→events/early error/notify only full success | RestartableCommand<CategoryLoadRequest, List<ContentBase>>; refresh captures filters; ViewModel observer commits | Immediate filter replacement/existing authority-cleanup | C1–C4/P1–P4/L1–L4 |
| setSelectedCategories | Command1 single-flight/equal no-op/inline update-clear/await ignores load Result | Synchronous void method/copy-normalize/equal no-op/update intent/latest dispatch | No independent async operation/state consumer; remove fake nested waits | B1–B3/C1–C3/U2 |
| setSelectedTypes | Separate legacy lane changes during occupied load/nested rejection/false setter success | Synchronous void method/same coordination/combined snapshot | No artificial field exclusion/lost intent | C2–C4/P4 |
| setSort | Single-flight/equal no-op/optimistic sort-notify/ignores write Result/always Success | createResultCommand<ContentSort, void>; sync sort/notify/existing write/real Result | Actual asynchronous persistence, preserve lane/local ordering | S1–S4/L2–L4 |

CategoryLoadRequest is a local typedef record (`Set<ContentCategory> categories`, `Set<ContentType> types`) copied unmodifiable at each dispatch. It improves lane-type readability without layer/factory/framework. Sort is applied at commit, not captured in query. Keep observable load; refresh() captures a new current-selection snapshot for bootstrap/retry. UI neither builds query records nor directly queries repositories. No new repository interface.

### D2 — Synchronous bootstrap and selection normalization

FACT: legacy execute enters action inline until first await, so route setter seeds categories before rendering. Route validates slug/all before Provider but legacy ViewModel starts empty; selector accesses first unless all selected. Source INFERENCE: execute→run alone opens empty-window failure because command_it defers action through zero-event.

Direct legacy empty types can succeed empty without query; empty categories query an empty filtered set. Production selector already resets all on close. Proposed boundary normalization intentionally changes only anomalous direct inputs (C3), not slug parsing.

Require constructor initialCategories (validated singleton or minusUnknown from route); copy before exposure. Remove unknown; empty categories become all known, empty types all types, matching selector confirmation. Initial types all/sort settings.contentSort. Install observer/Commands, admit one constructor refresh **without constructor notifyListeners**. Remove unawaited bootstrap setter. Restartable publication is deferred; no synchronous widget notification during Provider creation.

F2 distinguishes **nonempty confirmed ViewModel selection** from **possibly empty widget draft**. Safe draft labels: `Nessuna categoria`/`Nessun tipo`, distinct from all-options `Categoria`/`Tipo`; first only in explicit nonempty branch. Do not normalize mid-edit; only normal mounted/current close (D7/RF3) resets all before one callback. No persistent empty semantics. Invalid/numeric/unknown slug errors remain before creation/query. Same slug/retained owner never reseeds/refetches on build; new slug/owner initializes independently. Restoration seeds URI only, without new restorable session-filter fields.

### D3 — Remove nested execution; distinguish admission and outcome

Legacy second execute is rejected while running with immediately completed Future<void>; accepted execute is awaitable but returns no Result. Setters await load then report Success despite error/rejection; their own single-flight can reject new filters. Re-reading filters after await mixes places A/events B.

Upstream run returns void with immediate runningSync admission/deferred entry. runAsync joins existing completer, even after run; disposal may complete waiters with current value. Neither proves accepted/loaded filter intent (foundation tests cover differences).

Live changed-filter setter synchronously copies selection, clears _content and dispatches combined snapshot **before notify**, revoking old intent without await. Running/notify observers may reenter/dispose: no later mutation after dispatch/phase after notify. UI calls ViewModel method only. Set equality is semantic, not wrapper identity; copy caller input. Replace backing sets rather than in-place clear/add, keeping old widget parameters/UnmodifiableSetViews independently comparable. UnmodifiableSetView alone cannot prevent backing mutation. Draft does not mutate confirmed parameters; C3/U3 verify snapshots. refresh() deliberately starts a fresh equal-filter intent.

| Event | Contract |
| --- | --- |
| Equal setter | No query/clear/notify or false load confirmation |
| Changed filter | Not rejected by setter single-flight; load immediately authoritative |
| Equal refresh | New latest-intent execution, no join |
| Busy sort duplicate | Rejected, no queue/second write |
| Complete load Success | Live observer copies/sorts/commits/notifies |
| Load Result.error | Original terminal domainError; no candidate commit |
| Raw throw | Runtime snapshot/original global report once; no Object→Result |
| AssertionError | Original fail-loud path, not ordinary UI failure |
| Post-dispose completion | No new commit/notify/phase; private settlement/reporting |

### D4 — Concurrency and pure retrieval

Action reads **captured record only** to choose CategoryUseCase/ExploreUseCase and place/event sides. Existing getByCategories maps set indices without mutation, compatible with unmodifiable copies. Keep places→events/first Result.error short-circuit/all-events=current-year. Assemble local List<ContentBase>/return Result without _content/filter/sort writes. Owner access is only _disposed entry/post-await guard before next phase; disposed during places means no events. A started phase may settle/throw; owner-unavailable Result privately interrupts multistage work rather than fake complete success, without catching runtime as unavailable.

One synchronous load.results observer installed before autoload/removed on disposal commits retrieval. Current Success copies list/sorts with current _sort/assigns/notifies with no later effect. Running/failure does not mutate content; results drive rebuild. Foundation suppresses stale snapshots after admission: no generation token/counter; equal A values alone cannot distinguish A→B→A.

| Sequence | Outcome |
| --- | --- |
| A→B, A pending | B starts without waiting; only B commits, A cannot end B running |
| A→B→A | Last A new execution, first A obsolete |
| Type changes during places | New complete snapshot, no mixed old data |
| Category/types same turn | Latest record includes both; queued superseded records may never enter |
| Change during events/private partial | Old part remains private; latest complete success only |
| Equal during query | No unnecessary query/supersession |
| Initial route | One already-valid snapshot, no empty step |

Physically superseded work may continue captured phases while owner lives, without publication. No cooperative cancellation/phase tokens/new foundation API to save stale I/O. After disposal no later phase. Nonterminating Future may retain private resources.

### D5 — Atomic publication and data state

Verified legacy: clears first, appends places then events, first failure leaves empty/skips events, second failure leaves places **not necessarily sorted**. ViewModel notify only on full success, but partial getter data can surface through sort/other notifications; no explicit partial state. Sort can expose grid while load mutates list. These are not implicit guarantees to retain.

Complete-success atomic commit prevents mixed provenance. Changed filter clears immediately (old data describes another selection); same-filter refresh keeps previous success internally while loading/error govern UI. No per-filter cache/partial-success model.

| Case | Stored content | UI |
| --- | --- | --- |
| Complete success | One replacement/current sort | Grid or explicit empty |
| First query error | No candidate; cleared new filter/retained same-filter success | Error/retry |
| Second query error | Same; candidate places discarded | Error/retry, no partial grid |
| Complete zero results | Commit [] | Empty, not skeleton |
| Retry | New intent/replace only complete success | Loading→actual outcome |
| Filter change after places | Clear exposed list/old partial private | New loading→new outcome |

This intentionally changes legacy partial retention and leaves OpenSpec 1 Favourite progression untouched. Preserve sequential query order/short-circuit rather than introducing parallelism.

### D6 — Sorting and persistence

Legacy _sortContent was async without await, synchronously assigned/sorted name.compareTo asc or modifiedAt desc. _setSort awaited it, notified, awaited setContentSort, discarded Result and returned Success. Repository saves copyWith snapshot/cache only after Success.

Use synchronous helper for current/candidate lists. Ordinary setSort remains single-flight: equal returns no-op Success without write/notify. Accepted live change sets _sort/sorts/notifies, then rechecks _disposed before write (reentrant observer may dispose). Revoked means unavailable/no write. Started write returns **original Result**, without post-await commit/notify/rollback, including runtime throw. Correcting false success changes action outcome intentionally, not repository contract.

On Result.error session sort stays chosen, repository cache stays previous and new owner starts from cache. Equal post-failure remains no-op, no persistence-retry protocol/snackbar/save confirmation. Observers can read real failure. Other-owner whole-snapshot/lost-update risk remains without storage/cross-owner serialization changes.

Load sorts at **commit time**, not using pre-await sort or refetch on every sort. Load before deferred sort gets reordered by later sort; load after uses new sort. Obsolete never commits. Menu/body follow ViewModel during write, not merely Command terminal. setSort.completed cannot imply load success.

### D7 — UI observation and replacement owners

Use affected ListenableBuilders with combined ViewModel/load.results; add setSort.results only where write state needed. Widget owner replacement rebinds; avoid redundant load→ViewModel rebuild forwarder, retain necessary load→commit observer. ResultCommandSnapshot distinguishes idle/isRunning/completed/domainError/unexpectedError; value/completed alone does not establish stored-data authority.

Body: neutral/running SkeletonContentSliverGrid; completed+nonempty ContentSliverGrid; completed+empty explicit EmptyView; failure existing EmptyView/SliverFillRemaining plus `Riprova`→refresh. Reuse Favourite/Explore patterns without framework component. Filters remain usable pending; menu follows vm.sort; pending sort does not change load surface.

**Apply-verified clarification:** deferred public results can still show old terminal on the first frame of equal-filter refresh. Body checks `load.isRunningSync.value` as admission barrier before snapshot, with no sync listener. refresh notifies live ViewModel after admission; constructor calls private _startLoad without notify. VM/results remain only observation and snapshots define terminal outcome. Test first frame after refresh/filter change excludes old grid/empty. No async isRunning admission assumption/parallel loading flag.

**F1 semantic per-field comparison.** New UnmodifiableSetView wrappers make identity-based didUpdateWidget reset drafts on harmless query/sort/other rebuilds. Compare old/new **confirmed** sets via setEquals, never draft/new confirmed. Equal wrappers/order preserve local set/State; actual value changes replace only changed field with Set.of, without callback/resetting other field. D3 independent backing keeps old/new values comparable. Changed confirmed during modal retires old draft per RF3; reopened labels/selection use new values. Local Flutter foundation/collections.dart:25–41 setEquals compares cardinality/membership.

**RF3 draft-session ownership.** Modal receives materialized children/checkbox selected bool once. Replacing State field but letting old row callbacks mutate its new value mixes sessions. Capture draft-set reference before opening; row callbacks mutate only it. Real confirmed-value change replaces field with new copy, leaving old rows tied to old draft. After await check **mounted first, then identical(capturedDraft,currentField)**; mismatch returns without setState/normalization/callback. Reopen uses new confirmed values. Observed A→B→A across separate rebuilds invalidates old session; coalesced updates observed only A→A preserve F1 draft (no revision/token for unobserved events). Semantic comparison avoids spurious invalidation; identity tests concrete session authority. Other-field changes do not retire current modal. No live-row controller/notifier/route close from didUpdateWidget/stale-draft restore/new token.

**F2 empty draft/total labels.** Mutable draft differs from confirmed. Deselecting last checkbox neither resets all nor calls parent, allowing continued editing. Empty branch precedes first/singleton fallback every build, including parent rebuild while open: `Nessuna categoria`/`Nessun tipo`. Preserve all-options `Categoria`/`Tipo`, category name/count, singleton `Eventi`/`Luoghi`. Empty is not all/place. Only mounted/current normal close restores minusUnknown/categories or ContentType.values/types if empty, then emits one copied-set callback. Never reset in build/didUpdateWidget/toggle or notify ViewModel during edit; safe labels do not excuse draft loss.

**Owner identity differs from set equality.** ObjectKey(viewModel) in CategoryScreen unmounts previous selector even for equal sets. Final code-review remediation applies same ObjectKey(owner) to GeoMapScreen trailing selector because screen didUpdateWidget can replace owner while preserving screen State. Mounted guard precedes all post-await widget/context/setState/normalization/callback access. Old modal, empty or otherwise, cannot update either owner; same owner preserves draft/State on harmless rebuild. No domain behavior in View; apply async-mounted skill before State edits.

Shared selector fix is necessary for real GeoMap too. Preserve callback signatures/close-only publication/empty reset in both layouts, without GeoMapViewModel/Command/concurrency edits. Component tests width 400/1000 × category/type; real CategoryScreen replacement and one GeoMap wiring regression. No modal controller/state wrapper/early notification.

### D8 — Lifecycle and cleanup

Idempotent _disposed; all ViewModel methods/commit callbacks reject revoked work. dispose first revokes/detaches load commit/public forwarding, then disposes RestartableCommand. Existing foundation revokes authority/defers notifier teardown/retains children for settlement/reporting; duplicate no tracker/manual child disposal.

Only ordinary setSort uses local OpenSpec 1 D5: retain while isRunningSync; cleanup microtask→event outside dispatch, including never-run/idle; invalidate barrier on new observed transition/recheck running+barrier/detach private listener/mark release before one dispose. No polling/timeout/arbitrary timer/new helper; retained listener private only. Upstream 50 ms is not settlement proof.

Schedule owner super.dispose outside own notify in microtask without awaiting repository; revocation already blocks new notify. Reentrant owner/terminal/running listeners remain safe; entered notify stack may finish. Do not access unmounted State.widget/context to check owner.

Known command_it 9.5.2 limitation: early disposal followed by late raw throw can fail in destroyed notifiers before global report. notify-only guard/runAsync wait/false-sync alone insufficient. Retain sort for original object/stack report; restartable already does so for children. Preserve upstream skips/StateError-TypeError-AssertionError distinctions. No new post-revoke repository phase; started persistence is not remotely cancelled/rolled back.

### D9 — Alternatives and simplification

| Alternative | Decision |
| --- | --- |
| Four type substitutions/execute→run | REJECT: empty bootstrap/nested nonawaitable run/lost requests/stale commit |
| Ordinary filter setter factories | REJECT: no state consumers; deferred single-flight adds lanes/cleanup/lost-intent risk for synchronous mutation |
| Single-flight load rejecting filters while pending | REJECT: violates current-filter/latest-intent contract |
| Single-flight + desired snapshot + settlement rerun | Credible but REJECT: queue/coalescing/revocation/A→B→A/lifecycle exceeds existing foundation coordination |
| Restartable load/sync filter setters | ADOPT: existing authority, two Commands rather than four/no redundant token |
| Generation token/generic scheduler/awaitable execute adapter | REJECT: duplicates authority/legacy API |
| Progressive Category partials | REJECT: new emission-authority/partial semantics no consumer requires; declared atomic simpler |
| Restartable sort | REJECT: uncancellable persistence/storage ordering risk, unnecessary |
| Sort error rollback/automatic retry | DEFER: changes UX/persistence; session choice/real Result suffice |
| Parallel UI state/per-filter cache/global lifecycle factory | REJECT: existing snapshots/committed list/owner guard suffice |
| Remove defensive foundation lifecycle | REJECT: verified owner defenses avoid actual upstream problem; no opportunistic removal |
| Wrapper identity or draft→new confirmed compare | REJECT F1: loses edits; use old/new confirmed setEquals/independent backing |
| Reset all immediately on empty draft | REJECT F2: prevents editing; safe labels/close-only reset |
| F1/F2 modal controller/parallel state/package | REJECT: local comparison/label branches suffice |

Do not preserve four wrappers for symmetry: two synchronous ViewModel methods, one existing latest-intent read lane, one ordinary write. Do not rename/migrate other features’ same-named operations.

### D10 — Delta and later OpenSpec 1 consolidation

Canonical `Only authoritative completion can commit asynchronous data` still reflects preconsolidation general text. First delta distinguishes ordinary/restartable and preserves Favourite progression/rollback/consent. Add **seven distinctly named Category requirements**, no second MODIFIED; load follows restartable, setSort ordinary. Equal refresh is new intent/equal setter never invokes lane. Category atomicity does not impose terminal-only Favourite.

A separately authorized canonical reconciliation must combine first MODIFIED/Category ADDED without duplicate headers or lost Search/Map/Favourite/consent scenarios. No sync/archive/canonical edit here. Routing/navigation-shell remain binding without delta (URI/branch/restoration unchanged); local-content-retrieval/backend unchanged.

## Regression plan — historical future gates

These were **future gates**, not planning test passes. Before test edits load dart-add-unit-test/test-support-reuse, widget skill where applicable, async-mounted-context for State/callbacks and static-analysis; search/reuse test/support before extension.

| ID | Required cases/observations | Location/reuse |
| --- | --- | --- |
| B1 | Singleton/all pending first frame: nonempty selection/correct labels/one admission/no first or notify-during-build error | Category ViewModel/production categoryRoute/route_parameter_redirect |
| B2 | Invalid/numeric/unknown: error/zero Category query; same slug-owner rebuild no reseed/refetch; new owner same URI once | RouteOwnershipFixture/existing routing |
| B3 | Post Back retains Category/filters/branch; slug changes recreate; canonical restoration URI seed/parentage | route_ownership/main_navigation_restoration/real restorable harness |
| C1 | A→B/A→B→A both completion orders/identical A values: latest only; old domain/runtime cannot change current failure/running | Existing controlled fake queries/Completers |
| C2 | Types while places/events pending; categories/types same and separate turns: coherent snapshot/final output | Minimal shared getByCategories/getAll/getByCurrentYear hooks |
| C3 | Equal new-wrapper sets no-op during/after load; caller mutation cannot alter request; empty/unknown normalize; same-filter retry new intent | ViewModel |
| C4 | Old partial→new success/error; queued already-superseded records suppressed where foundation does so | Existing foundation + ViewModel integration without duplicated matrix |
| P1 | Filtered/all places→events; first failure skips second/second discards places; selected types only | ViewModel/existing fakes |
| P2 | Private places while events pending; complete empty success; whole single commit for nonempty success | ViewModel/widget |
| P3 | Refresh failure retains internally/shows error; retry full replacement; changed filter clear/no stale resurrection | ViewModel/screen |
| P4 | Result.error never becomes throw; original StateError/TypeError object/stack once globally even stale; fail-loud assertion | installCommandTestReporting/MockLogger/foundation |
| S1 | Name asc/modifiedAt desc/equal no write; session order/menu before persistence settlement/no refetch | ViewModel/screen |
| S2 | Query before/after sort action/write, both orders/obsolete later return: current sort | Separate query/write Completers |
| S3 | Success/Result.error/raw throw: real Result/original Exception/session retained/cache contract/new owner cached preference/equal after failure no write | FakeSettingsRepository/existing real repository checks, no storage change |
| S4 | Duplicate pre-pump/during write/reentrant notify: one admission/write/no queue; independent filters | Real Command/ViewModel |
| U1 | Neutral/loading/grid/empty/domain/runtime/retry; sort completion never unlocks loading/error; current header/menu | Existing Material/Provider screen harnesses |
| U2 | Nonempty/empty modal plus replacement (even equal selections)/pop: no old-new publication/reset; normal close one callback/no edit-time callback | Existing width 400/1000 selector tests/real CategoryScreen ObjectKey |
| U3 F1/RF3 | Category/type draft preserved on equal same-owner wrappers/order; observed changed-confirmed updates field/label and retires old captured draft, including separately delivered A→B→A; later toggle/close cannot reset/publish, reopen new values. Coalesced observed A→A preserves/confirms normally (empty reset/one callback). Other field does not invalidate; old ViewModel snapshot immutable | Sheet/dialog tests/ViewModel C3 without duplicating rebuild causes |
| U4 F2+F1 | Deselect all/open modal/equal parent rebuild preserves empty/unchecked draft, safe labels/zero callback-error; later select proves no premature reset; empty normal close resets once; U2 covers revoke | Existing width 400/1000 × field reset/unmount extensions |
| U5 shared consumer | Real GeoMapScreen edited/empty draft survives same-owner notify; close once updates correct filter/existing callback without other-field/lane effects | One distinct real GeoMap test; full layout matrix remains component test |
| L1 | Disposal pre-entry/places/events/terminal; late success/domain/runtime/assertion, no commit-notify-new phase | Real Commands/reporting/virtual clock |
| L2 | Sort never-run/idle/pending/owner notify before write/terminal-value dispose; both same-turn orders/transition during barrier | Existing ordinary lifecycle support/test adapter |
| L3 | Pending beyond 50 ms virtual after revoke then original throw once/no notifier error/assertion path/exactly-once cleanup | pumpCommandTurns/testOwnerUI where needed/FlutterMemoryAllocations sort/restartable debug child count |
| L4 | Pop/replacement with pending query/sort, public detach/no replacement contamination/idempotent dispose | Production route fixture, never MockCommand as lifecycle proof |

Existing getByCategories fakes lacked pending hooks: extend only required test/support/fake_repositories.dart methods/call records consistent with existing defaults. Reuse/move local builder according to support policy, not duplicate Category fakes. No tests of mere type names/per-diagnostic repetition. New concurrency/lifecycle cases use Completer/testWidgets virtual clock/pumpCommandTurns/testOwnerUI only where teardown timers require it. No real sleep/arbitrary delay/microtask-count assertions. Restore handlers/zones/memory probes; explicit unmount/virtual upstream drain. Existing real-wait/upstream skips document limitations, not new-test patterns.

## Risks / Trade-offs — historical plan

Atomic changes partial retention intentionally (D5/P1–P3). Removed setter Commands have no state consumers; callbacks sync/tests await load, no adapter. Constructor seed/deferred UI B1/U1 closes build window without notify during build. Dispatch before notify/guards prevent reentrant new phases (L1/L2).

F1 wrapper/aliased snapshot risk uses per-field confirmed setEquals/backing replacement (D3/U3). RF3 stale rows use captured draft/mounted then identity, no reset/callback on mismatch; U3 distinguishes observed/coalesced A→B→A. F2 empty draft is not all/confirmed; explicit label/close-only reset (U4/U2). Owner keys handle equal-set replacement without state holders. U5 covers real shared GeoMap wiring without its Command migration/duplicate matrix.

Obsolete I/O may continue while live/no publication; disposed owner starts no phase/private resources await settlement. Sort session may differ from storage after error or cross-owner lost update; expose real Result without invented rollback/serialization (S3). Preserve resolved foundation/local ordinary cleanup; no early disposal. Recheck branch/SDK before apply; material drift requires reconciliation, no automatic reset/rebase.

## Migration plan — historical

After independent review/separate apply authorization: recheck this authorized checkpoint/cumulative branch, rebuild ledger; implement ViewModel/route/bootstrap tests then sort/lifecycle/UI tests, integration/analyzers/full suite. No substitute main baseline/other Commands. Rollback only attributable diff, preserving first checkpoint/others; no reset/clean.

Acceptance: no Category legacy/new diagnostics, **113→105 only after implementation/identity comparison**; coherent snapshots/bootstrap/sort/lifecycle/deterministic tests/no unjustified dependency/abstraction. Global zero was not OpenSpec 2 gate. Cumulative PR/merge required later authorization.

## Evidence, uncertainty and historical readiness

Verified Git/remote/PR/sources/versions/new baseline analysis/PR4 ledger comparison. New behavior tests **not yet written or run** at planning; no claimed Flutter pass. Legacy interleavings were source/foundation-derived inferences, not new runtime characterization. Bootstrap/concurrency/publication/sort/lifecycle decisions were settled. Explicit limits: no physical cancellation, indefinite private retention, failed sort save without local rollback, existing snapshot risk. Any source/test divergence required reconciliation before affected execution. Strict/document audit did not substitute independent review/implementation proof.

## Initial document validation — 2026-10-20 (historical, before F1/F2)

- Strict validate: **exit 0**, valid change; status 4/4 planning artifacts complete (metadata plus four artifacts), not apply completion.
- Five files (.openspec.yaml/proposal/design/tasks/delta), **21 unique unchecked tasks; 7 ADDED requirements/27 scenarios**, no first-delta header overlap. Added descriptions ≤500 characters/internal resolved paths.
- `git diff --check`/cached: exit 0; five untracked files explicitly checked for final newline/trailing whitespace/tabs. **1.073 tracked files** matched HEAD, including production/tests/support/canonical/first change/dependencies/AGENTS. Only five nonignored untracked artifacts.
- Final only `?? openspec/changes/migrate-category-view-model-commands/`, empty index/unchanged branch-HEAD/positive ancestry/zero commits beyond checkpoint. Read-only GitHub: open Draft/checkpoint head/updated_at `2026-10-20T12:18:05Z` unchanged. No mutation.
- Self-review distinguished no-op/refresh/A→B→A/raw throw-Result/atomic partial/session-storage/pending-reentrant cleanup/modal replacement/delta integration. Existing ViewModel test count corrected to five; no known material plan blocker.

Historical **READY FOR INDEPENDENT PLAN REVIEW** preceded later F1/F2 findings and did not resolve them. No apply/production-test edit/commit/push/PR/merge/sync/archive then.

## F1/F2 document remediation and independent review — 2026-10-20

### Baseline and scope

Same dedicated branch/checkpoint `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, ancestry exit 0/zero later commits. Start/end only five untracked artifacts/empty index/no tracked diff. Reused authorized checkout without worktree creation/checkout/fetch/reset/clean/merge/rebase/cherry-pick.

Read AGENTS/openspec-update-change/config/status/context/five artifacts and real CategoryScreen/GeoMapScreen/backing sets/selector/tests/local setEquals/first delta. User directly authorized four document edits; no per-artifact gate. Only proposal/design/tasks/delta changed; metadata unchanged/no new files. Baseline **113 INFO/eight Category** stayed historical: **no analyzer/Flutter test/build in this remediation**, no 105 claim. Compared initial texts/1.073 tracked hashes; no unknown existing work overwritten.

| ID | Root cause | Plan correction/future gates |
| --- | --- | --- |
| F1 MEDIUM | Fresh wrapper identity resets harmless-rebuild drafts | D3 independent old backing/D7 confirmed setEquals per field; equal preserves, actual change updates only field. U3/tasks 2.2/4.2/scenarios Equal confirmed categories-types/Changed confirmed selection. RESOLVED IN PLAN, code unchanged. |
| F2 MEDIUM | Confirmed nonempty does not imply nonempty draft; first crash/empty types Luoghi | D2/D7 separate invariants/explicit labels/nonempty first/close-only current-mounted reset. U4+F1/U2/U5/Empty drafts-confirmation scenarios. RESOLVED IN PLAN, code unchanged. |
| RF3 MEDIUM (independent review) | Materialized row bool/old callback/new State field mixes sessions | Capture draft; mounted before identity; superseded session no normalize/publish. Observed A→B→A invalidates, coalesced A→A preserves/confirms; other field independent. U3/task4.2/Confirmed changes supersede scenario. RESOLVED IN PLAN, no controller/notifier/token. |

Functional/contractual corrections, not style. Separate read-only reviewer found RF3/coalescing limit, then verified four artifacts/source/diff/corrected U3: **no remaining material document finding**, not implementation review/test evidence.

Preserved invariants: confirmed ViewModel normalized/no alias/backing replacement; widget draft possibly empty/equal rebuild retention/captured session/current-only confirmation once; ObjectKey owner separation/mounted before post-await access/no old-new contamination. Shared callbacks/sheet-dialog close behavior preserved, no GeoMap Commands/orchestration change. D1/D4/D5/D6/D8/D10 compared identical to initial text: command matrix/latest retrieval/atomic/sort-Result/cleanup/delta unchanged; no layer/controller/dependency/state manager.

### Document validation

Strict validate **exit 0**: seven ADDED/**34 scenarios**, disjoint headers/no second MODIFIED/≤500-character descriptions. **21 unique unchecked tasks**, 4.2 expanded only within scope; U2–U5 cover 400/1000 sheet-dialog/category-type/combined cases/one shared wiring regression.

Existing marked GFM lexer/parser checked four Markdown headings/tables/fences; Psych.safe_load with Date read unchanged schema/date YAML, exit 0/no package install. Diff-check/cached/quiet/cached-quiet **exit 0**, with separate successful untracked whitespace/tab/newline checks. Hashes: all **1.073 tracked unchanged**, only four documents changed/metadata and exact five-untracked inventory preserved; other change/canonical/code/tests/support/dependency/config untouched. HEAD/all branch refs/worktree registrations identical. GitHub read-only open Draft/checkpoint/updated_at `2026-10-20T12:18:05Z`, no mutation.

Historical **READY FOR INDEPENDENT PLAN REVIEW**: F1/F2/RF3 resolved in documents/no known material blocker; production still needed authorized implementation/testing. No apply/commit/push/PR/merge/archive/sync in this phase.

## Apply evidence — 2026-10-20

Authorized after READY FOR APPLY. Earlier no-apply/count statements retain their phase; implementation itself did not authorize Git/canonical consolidation.

### Preflight, provenance and environment

Cwd `<worktree>`, branch `codex/plan-migrate-category-view-model-commands`, initial HEAD `9d17d224d5094c5b043128113d9aba6a1ce69f0a`. Fetch exit 0; cumulative ref/open Draft PR head matched checkpoint; positive ancestry/zero later commits/empty index. Only five reviewed untracked artifacts initially. Initial tracked/artifact/worktree manifest was `<evidence-dir>/category-apply/initial.json`. Other three worktrees not writable surfaces; no new worktree/checkout/reset/clean/merge/rebase/cherry-pick.

Apply/test-unit-widget-reuse/async-mounted/static-analysis skills used. Reused reporting/turns/disposal/fakes/production routing/OpenSpec 1 ordinary matrix. command_it 9.5.2/listen_it 6.0.0/go_router 18.0.2/Flutter 3.47.5/Dart 3.13.4, unchanged dependencies/lock; no pub get/upgrade. Ignored local metadata derived from resolved package_config without changing external packages.

### Characterization before production edits — task 1.4

```text
flutter test --no-pub test/ui/category/view_models/category_view_model_test.dart test/ui/category/widgets/category_content_and_type_selection_test.dart test/routing/route_parameter_redirect_test.dart --reporter expanded
```

**Exit 0, 78 passed**. Temporary legacy cases established inline bootstrap/places→events/busy nested rejection/first error/second-error partial/false sort Success on persistence Error. Later replaced with approved expectations, not preserved as future partial/false-success requirements. Historical local legacy-characterization.log/.json/legacy-characterization-test.dart were outside repository in the temporary evidence directory; current availability not claimed.

### Implementation and clarifications

D2/D3: required normalized initial categories/full types/cached sort before exposure; observer before one autoload/direct route seed; invalid route excluded. Sync setters compare values/replace immutable backing/preserve exposed snapshots/capture both fields; equal no-op versus explicit fresh refresh.

D4/D5: sole RestartableCommand authority; action uses immutable snapshot/private candidates/all-filtered/current-year/places→events/first original error without commits. Pre-autoload listener publishes only authoritative Success with current sort. New filter clears; refresh internally retains. No progression/token/fake cancellation.

D6: createResultCommand preserves single-flight/no-op, updates menu/order before write/rechecks after notify/returns original Result; failure retains session without false cache claim/refetch/rollback. Tests with opposite name/date ordering distinguish sorting policies.

D7 regression found stale terminal on first refresh frame: immediate isRunningSync read precedes snapshot without observing that notifier; public refresh notifies post-admission, constructor _startLoad never notifies. No parallel loading state/forwarder; snapshots still distinguish skeleton/grid/empty/failure-retry, independent of sort completion.

F1 confirmed setEquals per field/equal-wrapper draft retention/changed-field-only update/old snapshot independence. F2 safe empty labels/first guard/normal-close-only reset/no persistent empty semantics. RF3 rows capture opening draft/callback, mounted→identity after await/no superseded publication, ObjectKey for equal-selection different owners; observed A→B→A invalidates/coalesced A→A preserves. No new controller/notifier/token.

D8: sync idempotent revoke/detach before restartable dispose/deferred super.dispose; local invalidatable microtask→event setSort cleanup retains actual Command to settlement/reporting. No global foundation change/runtime conversion.

### Focused gates executed

All historical tests used `flutter test --no-pub` with expanded reporter from dedicated Category worktree. Overlapping runs are not summed as distinct tests.

| Gate | Evidence | Outcome |
| --- | --- | --- |
| B1–B3 | route_parameter_redirect/route_ownership/main_navigation_restoration: pending singleton-all first frame/invalid zero query/same-owner Back-branch/new slug/production restoration | Pass in aggregate |
| C1–C4/P1–P3/S1–S4 | Category ViewModel **26 cases**: controlled snapshots/atomic sequential/first-second errors/retry/A→B/A→B→A/types/sort-query orders/single-flight/identical Result | Pass in aggregate |
| U1 | CategoryScreen **11 cases**: initial skeleton/domain-runtime retry-empty/first retained-refresh frame/pending filter/optimistic menu | Pass in aggregate |
| U2–U4/F1/F2/RF3 | Selector **41 cases**, 400/1000 × field, edited-empty draft/real-other-coalesced confirmed changes/stale toggle/reopen/replacement | Pass in aggregate |
| U5 | One real GeoMap draft-empty/parent-notify/retention/existing callback case, no migration | Pass in aggregate |
| L1/L3/L4/P4 | Category lifecycle **15 cases**, before-entry/places-events/late success-error-StateError-TypeError-assertion beyond 50 ms virtual/original stack/report/reentrancy/child cleanup once | **15 passed, exit 0** |
| L2/L3 | categorySort ordinary matrix **+14 cases** and foundation Result/restartable/reporting/upstream disposal | Pass in aggregate, existing upstream skips only |

Final aggregated command:

```text
flutter test --no-pub test/ui/category test/ui/ordinary_view_model_lifecycle_test.dart test/routing/route_parameter_redirect_test.dart test/routing/route_ownership_test.dart test/routing/main_navigation_restoration_test.dart test/ui/geo_map/widgets/geo_map_screen_test.dart test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart --reporter expanded
```

**Exit 0, 375 passed, 3 pre-existing skipped** (targeted-tests-final.log/.json, temporary historical evidence).

Development corrections: nonexistent Place.copyWith in first test compile replaced with optional modifiedAt fixture parameter. Lifecycle Completers initially constructed outside awaiting error Zone; moved into same Zone without weakening original object/stack/fail-loud assertions. First screen regression exposed stale first-frame terminal, fixed D7. Imports/lints corrected only affected files; no weakened expectation/new skip/production seam for green tests.

### Apply analyzer and formatter

Baseline checkpoint Git archive at `<evidence-dir>/category-apply/baseline`; resolved package_config only local root adapted. Direct Dart:

```text
<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <evidence-dir>/category-apply/baseline
```

**Raw returncode 0, 113 INFO, 0 warnings/errors**, all DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE; baseline-analyzer.json/.log/.stderr.

Final byte-verified nonignored-file snapshot `<evidence-dir>/category-apply/final-snapshot`, equivalent metadata/direct command with that argument: **raw returncode 0, 105 INFO, 0 warnings/errors**. Counter by severity/rule/file/message/multiplicity after root/line normalization: **exactly eight Category removed/105 unchanged/zero new**. final-analyzer.json/associated stdout-stderr; SHA256 manifest `cd14356fd692252f8a3c95997371b1e574ae02ef59031737dda488674279c34a`. Later document-only edits did not alter analyzed code. No separate flutter analyze/no inferred wrapper exit/no suppression/config change.

Last dart format: **exit 0, 19 files, 0 changed**, intentional Dart only. No Category legacy import/type/use; no dependency/UseCase/production repository/foundation/other Command/canonical change.

### Preserved limitations and local review

Obsolete physical query may finish captured phases while live, never publish; no new phase after disposal. Nonterminating work retains private cleanup without invented timeout. Original runtime object/stack/assertion fail-loud retained. Session sort may diverge from cache after write failure; no new retry/cross-owner serialization. Unserialized filters are not promised restorable.

Self-review plus separate local read-only reviewer found no material bootstrap/snapshot/latest-intent/atomic/sort/F1-F2-RF3/reporting/cleanup/scope issue. Reviewer requested explicit first-frame barrier/current artifact status; D7/evidence updated. This local review did not replace later independent cumulative code review.

### Full suite, validation and integrity

`flutter test --no-pub --reporter expanded`: final **exit 0, 2.476 passed, 6 skipped, 0 failed**, **90,85 s** (full-tests-final.log/.json in temporary historical evidence). Same checkpoint skips: three upstream StateError disposal cases, one existing GeoMap route skip and local E2E gates MOLISE_ALL_DAY_LOCAL_E2E/MOLISE_EXTERNAL_TOKEN_LOCAL_E2E. No new skip.

First two full runs failed **exit 1, 2.254 passed, 6 skipped, 222 failed** because native ObjectBox unavailable, with cascading setup/teardown failures. Second DYLD_LIBRARY_PATH-only attempt did not fix search. Environment correction: byte-identical already-available main-checkout binary copied read-only into ignored Category `lib/libobjectbox.dylib`, SHA256 `1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751`. No download/manifest-lock/ObjectBox-code change. Final ordinary command needed no DYLD override. Ignored runtime/build/resolved metadata are not production sources. Failed logs retained then as full-tests.log/.json/full-tests-native.log/.json; availability now not guaranteed.

Strict validate **exit 0**. Four Markdown parsed through marked; YAML Psych safe_load **exit 0**. Initial safe_load_file unavailable in local Ruby (**exit 1**), corrected to safe_load(contents), no package installation. Explicit fence/whitespace/newline checks on all **24 diff files including ten untracked** succeeded; git diff --check/cached exit 0, not substitutes for untracked checks.

Historical final inventory: **14 tracked modified/10 untracked/none staged**. Four production files: lib/routing/core_routes.dart (Category seed only), Category ViewModel/screen/shared selector. Fifteen Dart test/support files:

- test/routing/main_navigation_restoration_test.dart, route_ownership_test.dart, route_parameter_redirect_test.dart;
- test/support/fake_repositories.dart, fixtures.dart, ordinary_view_model_lifecycle_support.dart;
- test/support/category_screen_test_support.dart, category_selection_test_support.dart, category_view_model_test_support.dart;
- test/ui/category/view_models/category_view_model_test.dart, category_view_model_lifecycle_test.dart;
- test/ui/category/widgets/category_content_and_type_selection_test.dart, category_screen_test.dart;
- test/ui/geo_map/widgets/geo_map_screen_test.dart and test/ui/ordinary_view_model_lifecycle_test.dart.

Five existing OpenSpec artifacts still untracked then; proposal/design/tasks updated, metadata/approved delta unchanged. **7 requirements/34 scenarios**, disjoint names/no second MODIFIED. First change/canonical unchanged/no sync/archive. **All 21 tasks verified**, including reviewer’s post-D7 artifact reread without material finding.

Initial-manifest comparison confirmed outside-allowlist tracked hashes unchanged/four worktree registrations identical/empty index/unchanged branch-final HEAD `9d17d224d5094c5b043128113d9aba6a1ce69f0a`/positive ancestry/zero later commits. No other checkout/branch modified/commit-push-PR-merge-archive-sync. Temporary paths held evidence/snapshots, not alternative bases.

Historical **READY FOR INDEPENDENT CODE REVIEW**: B/C/P/S/U/L covered/full suite green/105 reconciled/strict green/no known material blocker. Existing upstream/persistence limits explicit; no implicit cumulative publication authorization.

## Final code-review remediation — F1 GeoMap callback owner

This supersedes prior local verdict only for later independent finding. Code-review **F1 MEDIUM** differs from planning F1: consumer ownership, not set semantics. Earlier planning/F1-F2-RF3/apply results stay historical.

### Incremental baseline and reused support

Same branch/head `codex/plan-migrate-category-view-model-commands` / `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, positive ancestry/empty index. Initial apply inventory unchanged: 14 tracked modified/10 untracked/five artifacts/**21/21 tasks**. All 19 apply Dart hashes matched previously analyzed snapshot; no unknown changes. No checkout/fetch/reset/clean/merge/rebase/cherry-pick/new worktree. Initial.json/initial.diff under `<evidence-dir>/category-final-remediation/` recorded then; ephemeral provenance, not guaranteed accessible now.

Reused existing private geo_map_screen_test builders/production-owner-replacement ValueListenableBuilder/FakeEventRepository.pendingGetById/getByIdCallCount/makeEvent/testOwnerUI/pumpCommandTurns. No new helper/fake/support. Relevant test/reuse/async-mounted/static-analysis skills read before edits.

### Verified root cause and minimal correction

GeoMapScreen.didUpdateWidget already detaches old ViewModel/revokes selection-nearby work. AnimatedGeoMapSearchBar trailing selector lacked owner key. A→B with equal confirmed filters preserved selector State/draft legitimately via setEquals, but opening callback belonged to A. Mounted/draft identity stayed true, authorizing obsolete callback.

Only production change: `key: ObjectKey(owner)` on actual built selector, same owner used by selection/callbacks. Replacing ViewModel preserves GeoMapScreen State/didUpdateWidget but unmounts old selector/mounts B. Old modal may stay visible; existing mounted guard returns before normalization/callback. Same-owner key equality preserves drafts.

Authorized minimal shared-compatibility extension: fifth production file versus original four, one GeoMapScreen line. No GeoMapViewModel/Command/shared-selector/CategoryViewModel/factory-foundation/repository/UseCase/dependency edit, token/controller/notifier/duplicate RF3 guard. Existing requirement already discards obsolete-owner callbacks; delta unchanged **seven requirements/34 scenarios**, no canonical duplication/change.

### New R1–R5 regressions and red/green

Four parameterized real-GeoMapScreen tests: category/type × nonempty/empty draft. Preserve screen State; ValueListenableBuilder replaces distinct A→B with equal filters. Before close assert modified old rows still visible/old State unmounted/new selector mounted. After close assert zero admission to either owner’s filter Commands, including empty→all semantic no-op (listeners still detect executions); both selections unchanged/new selector seeded B.

All four include actual pending A/B lookup Completers. didUpdateWidget revokes A without transferring authority. After close dispose A while pending/advance beyond 50 ms virtual/complete stale A and current B: no post-dispose notify/A mutation/extra action/lifecycle exception, only B’s content. No real sleep/microtask-count dependency.

R4 reuses existing same-owner empty-draft/notify/one-confirmation GeoMap regression and shared Category nonempty/other-field/sheet-dialog/normal-close matrix, avoiding duplication. R1/R2/R3 cover both fields; R5 adds pending/post-dispose settlement in that real scenario.

Discriminating pre-production-edit command:

```text
flutter test --no-pub test/ui/geo_map/widgets/geo_map_screen_test.dart --plain-name 'Map selector owner replacement' --reporter expanded
```

**Exit 1, 0 passed / 4 failed**, all oldPublications expected 0/actual 2 (stale setter start/terminal). After key alone **exit 0, 4 passed**, same tests/expectations. Historical red.log/.json/green.log/.json temporary evidence. Later test changes lint/format only (cascade/braces/comments), no weakened expectations.

Earlier setup attempts were not red proof: pumpAndSettle could not finish intentionally animated skeleton; finder used ValueKey<Object> instead of real typed key. Corrected modal animation through Durations.long4/virtual clock/typed keys; no production edit before real red run.

### Remediation gates and diagnostic comparison

Dedicated Category cwd; logs/raw metadata under temporary category-final-remediation evidence. No old apply result reattributed to remediation.

- Focused: `flutter test --no-pub test/ui/geo_map/widgets/geo_map_screen_test.dart test/ui/category test/routing/route_ownership_test.dart test/ui/ordinary_view_model_lifecycle_test.dart --reporter expanded`: **exit 0, 264 passed, zero failed/skipped** (targeted.log/.json).
- Final aggregate: same full aggregated command as apply above: **exit 0, 379 passed, 3 pre-existing upstream skips, zero failures** (aggregate-final.log/.json). B/C/P/S/U/L remain covered; +4 versus apply 375.
- First remediation full suite `flutter test --no-pub --reporter expanded`: **exit 0, 2.480 passed, 6 pre-existing skips, zero failures** (full.log/.json), same skip identities. Existing ignored ObjectBox runtime reused/hash unchanged. Final lint-only tests were followed by aggregate/final full run below.
- Formatter `dart format lib/ui/geo_map/widgets/geo_map_screen.dart test/ui/geo_map/widgets/geo_map_screen_test.dart`: **exit 0, 2 files, zero residual changes**, no other surfaces.
- Direct Dart `analyze --format machine <evidence-dir>/category-final-remediation/analyzer-snapshot`: **raw returncode 0, 105 INFO / zero warnings / zero errors**, all DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE. Byte-identical nonignored-source snapshot/resolved metadata with local root adapted to canonical physical path. Counter by severity/type/rule/file/message/multiplicity versus prior final-analyzer.log, root/shifted-position normalization: **105 unchanged identities, zero added/removed** (analyzer.log/.stderr/.json). No Category legacy/GeoMap Command changes. No separate flutter analyze/inferred wrapper exit.

First analyzer preparation used unresolved temporary-directory alias while analyzer resolved its physical path, splitting one package into two roots (**exit 3**). Discarded/corrected with Path.resolve without checkout changes. Intermediate valid run found three new test lints (two >80-character comments/one cascade), corrected/rerun to identical 105. Intermediate logs preserved then; no suppression/config change.

### Adversarial review and unchanged boundaries

Self-review plus independent local read-only diff/red-green review: **no remaining material finding**. Verified correct key site/retained screen State/distinct-owner remount even equal sets/mounted before callback/still-visible old modal/empty-nonempty drafts/pending queries. No new selector ownership responsibility or changed legacy GeoMap semantics. Local review did not replace final independent review.

Exactly **five incremental files**: GeoMapScreen, its test and Category proposal/design/tasks. Production diff one line; removing it reproduces initial file byte-for-byte. Original GeoMap test suffix byte-identical/four new tests prepended/no original expectation changed. All other source/support/artifact hashes unchanged, including metadata/delta/first change/canonical. Overall apply+remediation **15 tracked modified/10 untracked**, empty index; **21 original tasks**, seven requirements/34 scenarios unchanged.

Read-only GitHub open Draft/checkpoint branch head/updated_at `2026-10-20T12:18:05Z` unchanged. No PR mutation/other-checkout write/commit/push/merge/rebase/archive/canonical sync. Same branch/HEAD/positive ancestry/worktree registrations. View key neither changes GeoMap Commands nor query order; earlier Category limits/decisions unchanged.

### Final historical remediation result

Final post-lint full suite: `flutter test --no-pub --reporter expanded`, **exit 0, 2.480 passed, 6 pre-existing skips, zero failures**, **91,99 s** (full-final.log/.json). Both Dart hashes matched analyzer/delivered files; no later code changes.

Strict validate **exit 0**; four Markdown/YAML safe-load valid; git diff --check/cached exit 0; separate whitespace/newline checks on **25 overall files including ten untracked** clean. Empty index/unchanged branch-HEAD/positive ancestry/zero later commits/other worktrees preserved. integrity-final.json recorded only five incremental files/rest unchanged hashes. No new artifact/metadata-delta-canonical-first-change edit.

**Code-review F1 closed with red/green and complete gates; no known remaining material finding. READY FOR INDEPENDENT CODE REVIEW.** Existing apply limitations remain, not new blockers. Readiness did not itself authorize publication.

## Published checkpoint — later reconciliation

Git verifies `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, parent `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, committed 2026-10-20 and included in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12). This later record distinguishes published status from original local closeouts and does not invent self-referential commit metadata. Next checkpoint Content `1f3753b10c18061c6655cb32d078bf93aff1b05e` has this parent. All seven implementations are now published; historical INFO progression **125 → 113 → 105 → 87 → 66 → 52 → 37 → 0** describes successive checkpoints, not reconciliation runs. Category had 105 INFO, not zero.

Tracked sources/tests/docs and Git history are persistent evidence. Temporary logs/snapshots above document historical provenance/results without claiming current access. Historical local tests do not establish exact-SHA GitHub Actions success; use actual workflow records separately. PR remains Draft. Legacy compatibility removal/canonical synchronization/archival/merge require separate authorization.

Historical remote CI is separate from the local passes above: the [GitHub Actions run](https://github.com/xmattjus/moliseis/actions/runs/39501097232) associated with `e3d9d891c5b560524e66b35f0bf70f9108cacb7e` concluded **failure**. This publication record does not relabel that checkpoint as CI-clean or infer the failure cause from local results. Later-head workflow results belong to their own exact SHAs.
