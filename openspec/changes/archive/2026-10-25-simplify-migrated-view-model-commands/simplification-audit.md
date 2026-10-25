# Independent simplification audit

## Baseline and method

Audit date: 2026-10-24. PR [#12](https://github.com/xmattjus/moliseis/pull/12), open/Draft, remote branch `codex/migrate-legacy-commands`, exact requested checkpoint `c6e4a21b17f9d14299f7a159dd7bebe5b31d9af1`; base `main` at `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. There was no checkpoint delta at preflight. Primary local HEAD/main agrees with base. GitHub connected read-only metadata was used after local gh DNS failed; no remote mutation occurred.

Dedicated branch `codex/plan-simplify-migrated-view-model-commands` starts at the checkpoint. Directory was derived as `<git-toplevel-parent>/moliseis-worktrees/simplify-migrated-view-model-commands`; no machine-specific absolute path was assumed in choosing it. Ten pre-existing worktrees were inventoried before creation with HEAD/branch, status, index-byte hash and tracked/nonignored-untracked content hash. Final preservation proof belongs in validation.md.

Read-only explorers independently mapped editor/submission, search/session and remaining migrations; an architect resolved the actual package concurrency boundary, and a fresh reviewer challenges the completed plan. Delegated conclusions were checked against the cited source. No finding is treated as valid from LOC alone. P2/P3 describe maintainability severity, not an asserted production bug; P1-if-removed describes consequence of removing a needed mechanism. No frequency/probability is invented.

KISS/YAGNI/least power/local reasoning/delete-first are balanced against durable data and identity. Raw runtime failures are never ordinary successes; read retry never replays a remote mutation. Scope is modified PR code plus only the dependencies needed to verify its contracts. Utility foundation code is inspected but pre-existing.

## Ranked decisions

| ID | Decision | Benefit | Implementation risk | Disposition |
|---|---|---|---|---|
| S01 | SIMPLIFY | Remove revision-aware dashboard drain + seven fields | low | ordinary refresh; explicit stale-UI recovery |
| S02 | SIMPLIFY | Remove history projection/rebase/epoch and reader scheduler | moderate | preserve FIFO/detach; confirmed display + read reload |
| S03 | SIMPLIFY | Remove editor execution engine and paired observers | higher | fixed commands, semantic captures, one post-turn observer |
| R04 | REMOVE | Remove physical test topology/probes | low with behavioral replacements | included in S03, no duplicate savings |
| R01/R02 | REMOVE | Remove marker ticket and stored classification | low | unchanged marker behavior |
| R03 | REMOVE | Delete four dead execution declarations | low | preserve mutation method token/identity |
| K01–K06 | KEEP | Prevent lifecycle/data/identity regressions | high consequence if removed | no hardening added |
| N01–N03 | NEEDS EVIDENCE | Potential further reductions not established | unproven | explicitly excluded, no implementation task |

## S01 — SIMPLIFY — Dashboard revision-aware editor refresh

**1. Severity:** P2

**2. Files and symbols:** lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:103–109,200–278,442–465; widgets/admin_dashboard_screen.dart:51–73

**3–4. Observed behavior and PR-introduced complexity:** Each changed editor return allocates a revision waiter; a drain waits for qualifying post-revision submissions/ignored receipts and rearms on settlement. Seven dedicated owner fields and three drain methods were added relative to main.

**5. Protected invariant:** Every caller receives a batch covering its own persisted editor change, even during busy or reentrant reads.

**6. Concrete necessity evidence:** One production route-return callback requests refresh; the save has already persisted. Old/new-demand interleavings are primarily enforced by admin_dashboard_command_lifecycle_test.dart:670–1180 and the session spec, not a second persistence boundary.

**7. Consequence of removal:** Deleting the drain allows an older in-flight read to remain visible; it does not undo save, repeat moderation or lose local draft data.

**8. Recoverability / regression risk:** Recoverable stale UI. Low implementation risk if normal accepted-refresh/lifecycle and unIgnore paths are untouched. Busy/failed reads require manual refresh, never mutation replay.

**9. Smaller alternative:** Design D2: ordinary sequential refresh request with no retained obligation. Check live owner and a normal terminal snapshot before next phase; assertion is not ordinary completion.

**10. Decision and test treatment:** Adopt. Replace per-revision freshness acceptance and revision-scheduler tests; keep true/false/stale return, selected ignored list, retained data, retry, assertion/no-next-phase and accepted-refresh lifecycle.

## S02 — SIMPLIFY — Search projection and read-demand protocols

**1. Severity:** P2

**2. Files and symbols:** lib/ui/search/view_models/search_view_model.dart:42–64,132–211,244–407; lib/ui/search/widgets/components/app_search_anchor.dart:110–139,262–282; lib/data/repositories/search_repository_impl.dart:72–97,212–247

**3–4. Observed behavior and PR-introduced complexity:** New _HistoryWriter/_HistoryMutation implement base/projection/pending transforms, uncertainty and epoch reconciliation; reader adds requested/attempted demand and detached/drain settlement. VM grew 188→407 LOC.

**5. Protected invariant:** Immediate optimistic chips, ordered writes, rollback/rebase, accepted persistence after navigation and stable read demand across every interleaving.

**6. Concrete necessity evidence:** FIFO/detach has real evidence: popup navigates immediately after add, opposite operations can reorder persisted intent. Repository adds are case-insensitive idempotent per serial caller, removes exact/idempotent. No production consumer uses pastSearchesState or explicit refresh; no history reload control exists. Optimism and stable-demand guarantees come from the migration delta/test scheduler matrix.

**7. Consequence of removal:** Removing everything would lose accepted writes and is rejected. Removing projection/revision reads while keeping FIFO yields delayed or stale confirmed chips, recoverable by read reload; no mutation is replayed.

**8. Recoverability / regression risk:** Moderate risk. FIFO across dispose and one attempt per accepted mutation are mandatory. Read failure is recoverable; an unexpected write may already have committed, so read reconciliation is safe while automatic write retry is not. No measured frequency is claimed.

**9. Smaller alternative:** Design D3: one write-only Future tail, two fixed ordinary commands, a small package completion bridge, independent best-effort single-flight reads, retained confirmed list and visible failure/read-only reload.

**10. Decision and test treatment:** Adopt with explicit loss of immediate optimism, VM no-op suppression and per-demand automatic freshness. Keep ordering/navigation/storage/error regressions; replace epochs/projection/rebase tests with confirmed-read behavior and retry. Reads must not block the write tail.

## S03 — SIMPLIFY — Editor generic physical-execution engine

**1. Severity:** P2

**2. Files and symbols:** lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:24–55,90–101,1384–1550; lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:186–243

**3–4. Observed behavior and PR-introduced complexity:** Two new generic classes wrap eleven ordinary commands. Each lane holds 8 fields; each execution 10. Three listener registrations per lane and a revision-rescheduled microtask/event barrier manage physical receipts. Owner and UI also hold semantic revisions/logical effect IDs.

**5. Protected invariant:** Synchronous conflict refusal; no old completion resets a newer request; immutable inputs; once-only effects; live command retained for late-error reporting; assertion cleanup.

**6. Concrete necessity evidence:** Package ordering and disposal limitation are concrete, but they need a post-turn completion boundary rather than per-execution revisions and paired observation. Architect source review confirms assertions prevent replacing this with runAsync alone. Save/context/source revisions have independent data-integrity meaning.

**7. Consequence of removal:** Blind removal risks duplicate/dropped writes, false clean Save or stale preview Apply. Replacing physical receipts only, with one stable observer and reservation through post-turn release, preserves these guarantees. Editor disposal before entry still skips I/O; dispose from admission notification requires direct idle release because no running transition occurs. Search accepted writes deliberately have different persistence ownership.

**8. Recoverability / regression risk:** Higher implementation regression risk because writes and navigation are involved. No relaxed persistence/identity guarantee. Terminal publication can occur later, and new admission after published terminal may succeed. Assertion-driven automatic owner reuse is intentionally dropped; development failure stays loud.

**9. Smaller alternative:** Design D4: explicit typed fixed commands/request captures, existing conflict matrix, one stable completion observer each, logical effect IDs only where UI consumes them. No generic execution replacement or foundation change.

**10. Decision and test treatment:** Adopt a bounded increment after cheap removals and Search. Keep Save revision, source hash/preview token, outer KeepCurrent phases, asset identity, disposal and covered-route effect tests. Replace physical counts and exact terminal-dispatch timing assertions.

## R01 — REMOVE — GeoMap request ticket duplicates object identity

**1. Severity:** P3

**2. Files and symbols:** lib/ui/geo_map/view_models/geo_map_view_model.dart:40–56,243–267,307–313

**3–4. Observed behavior and PR-introduced complexity:** Each fresh immutable marker request contains a fresh ticket; commit checks both identical(request,currentRequest) and identical(request.ticket,currentRequest.ticket). Request class/ticket were added by this migration.

**5. Protected invariant:** Only the latest admitted filter request can publish, including A→B→A.

**6. Concrete necessity evidence:** The first identity check proves the second; RestartableCommand already forwards only current executions. Marker A→B→A regression exists at geo_map_markers_test.dart:126–163.

**7. Consequence of removal:** Deleting the ticket and second comparison changes no accepted request or outcome, provided request identity remains.

**8. Recoverability / regression risk:** Low risk; no persistence involved. Keep stale-marker/no-old-error behavior. No guarantee is relaxed.

**9. Smaller alternative:** Delete one field and redundant check; retain immutable sets and current request identity.

**10. Decision and test treatment:** Adopt. Keep behavior tests; remove only any direct ticket oracle. No spec change.

## R02 — REMOVE — GeoMap stored marker classification

**1. Severity:** P3

**2. Files and symbols:** lib/ui/geo_map/view_models/geo_map_view_model.dart:153–167,233–267,307–324; geo_map_screen.dart:536–568

**3–4. Observed behavior and PR-introduced complexity:** _markerStatus mirrors admission/terminal classification and is independently assigned loading, empty and data/failure alongside _markerTerminal. Both are new migration state.

**5. Protected invariant:** Loading, empty, data and partial/full failure must stay distinguishable synchronously on admission and during retry.

**6. Concrete necessity evidence:** Null owner terminal already means loading. Terminal hasFailure or outcome.firstError defines failure; outcome events/places define empty/data. Partial source failures must not be lost by checking only snapshot.hasFailure.

**7. Consequence of removal:** Remove only the stored status. A getter over owner terminal gives the same rendering; using the deferred command result instead would regress immediate admission.

**8. Recoverability / regression risk:** Low risk; recoverable reads, no identity or mutation boundary changes. Empty programmatic selection is still terminal empty with no query.

**9. Smaller alternative:** Derive markerStatus from markerTerminal and its full outcome.

**10. Decision and test treatment:** Adopt with existing marker/widget retry, empty, stale, partial-source regressions. No spec relaxation.

## R03 — REMOVE — Dashboard dead receipt bookkeeping

**1. Severity:** P3

**2. Files and symbols:** lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:15–28,101,288–337

**3–4. Observed behavior and PR-introduced complexity:** _AdminExecution.id and .token are assigned but never read; .started is only assigned. _nextExecution only supplies unused ids. These are introduced by the PR.

**5. Protected invariant:** No concrete invariant depends on these fields; method token identity in _canRead is separate and remains.

**6. Concrete necessity evidence:** Reference search of the entire file finds constructors/assignment only for these fields. Actual mutation ownership uses object identity, read boolean, terminal and settlement state.

**7. Consequence of removal:** No behavior changes when declarations, constructor arguments and assignments are removed together.

**8. Recoverability / regression risk:** Low risk; preserve the real method token authorization and mutation object identity. No recovery or guarantee change.

**9. Smaller alternative:** Delete four declarations, constructor parameters and writes.

**10. Decision and test treatment:** Adopt locally alongside S01. Do not use this as justification to remove the whole mutation coordinator.

## R04 — REMOVE — Editor test-only physical probes

**1. Severity:** P2

**2. Files and symbols:** lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:161–180; test/ui/admin/submissions/view_models/{admin_submission_editor_commands_test,admin_editor_admission_matrix_test,admin_editor_phase_test}.dart

**3–4. Observed behavior and PR-introduced complexity:** Four @visibleForTesting getters expose command identities, settlement counts, disposal counts and private observer counts. There are 30 reference lines across three test files, all introduced with migration tests.

**5. Protected invariant:** Exact topology, physical reuse and observer pairs; only indirect evidence of safe behavior.

**6. Concrete necessity evidence:** No production consumer uses these getters. RF1.1 at commands_test.dart:32–89 mixes real persistence/admission assertions with internal counts; similar assertions occur at :107–144,301–342,526–597.

**7. Consequence of removal:** Removing probes alone loses white-box diagnostics; removing mixed tests wholesale loses useful real regressions and is prohibited.

**8. Recoverability / regression risk:** Low risk when useful behavioral assertions remain. Keep original Object/stack, no notifier errors, one repository call/effect and working retry oracles.

**9. Smaller alternative:** Delete getters and storage needed only for them; surgically replace count-only assertions with observable behavior.

**10. Decision and test treatment:** Adopt as part of S03; count savings are not additive to its estimate. Preserve foundation child cleanup tests: those test foundation resource ownership, which this PR did not introduce.

## K01 — KEEP — Resolved command lifecycle and Result foundation

**1. Severity:** P1 if removed

**2. Files and symbols:** lib/utils/{result_command,restartable_command,command}.dart; test/utils/{result_command,restartable_command,command_it_disposal_behavior}_test.dart; command_it 9.5.2 lib/command_it.dart:310–407,429–430,799–825,1011–1025

**3–4. Observed behavior and PR-introduced complexity:** Neutral Result projections, single-flight admission and latest-intent child authority are pre-existing main code. Migration adds feature-specific safe command release around this foundation.

**5. Protected invariant:** No disposed-notifier secondary failure; original handled error reported once; no stale result; nullable void success distinct from initial null.

**6. Concrete necessity evidence:** Direct package source and the initial 2026-10-24 record of 298 passing focused foundation/ordinary lifecycle tests in a temporary checkout copy, 3 existing skips; not rerun during F1–F3 remediation. Late raw path updates a disposed notifier before global handler if command is destroyed early; runAsync assertion does not settle.

**7. Consequence of removal:** Immediate disposal or generic catches can lose the original failure, throw secondary errors or invent success. Removing latest-intent authority permits stale UI commits.

**8. Recoverability / regression risk:** Actual runtime failure/reporting consequence. Keep pending work alive; assertions fail loudly. No package upgrade or probability assumption.

**9. Smaller alternative:** Keep foundation and ordinary disposal implementations. Only S03/D3 replace larger local receipt protocols with the smaller proven-order boundary.

**10. Decision and test treatment:** KEEP; shared cleanup-shortening candidate is N01, not executable scope. No new raw-error normalization or legacy utility removal.

## K02 — KEEP — Content Submission durable session and finalization

**1. Severity:** P1 if removed

**2. Files and symbols:** lib/ui/content_submission/view_models/content_submission_view_model.dart:66–103,379–485,936–1019,1139–1500; lib/data/repositories/content_submission_repository_impl.dart:32–58; supabase/migrations/20260908065810_harden_content_submission_server_idempotency.sql:72–110

**3–4. Observed behavior and PR-introduced complexity:** Five private commands capture immutable session/digest/membership; existing lifecycle tail orders drafts/staged changes; submitted success marker supports local finalization-only retry. VM grew 1038→1500, but its lifecycle queue predates the PR.

**5. Protected invariant:** No wrong-session clear/remove, lost checkpoint/asset, duplicate final send or retry under a fresh identity after uncertain mutation.

**6. Concrete necessity evidence:** Repository passes clientSubmissionId; SQL returns existing same-user/key submission before quota/payload writes and serializes same-key races. Staged repository scopes cleanup by identity. Existing S10 and finalization tests prove one send after acknowledged success with failed local cleanup.

**7. Consequence of removal:** Loss of local data, wrong-asset deletion or duplicate/uncertain remote mutation; retry alone cannot restore destroyed staged data.

**8. Recoverability / regression risk:** High consequence even with unmeasured frequency. Preserve same identity across uncertain retry and local-only retry after confirmed success; never equate a refresh failure to submit failure.

**9. Smaller alternative:** No simplification of persistence protocol; optional forwarding reductions remain N03.

**10. Decision and test treatment:** KEEP all persistence/ownership/phase tests and backend contracts; no submission delta or implementation task.

## K03 — KEEP — AdminAuth correlation and credential separation

**1. Severity:** P1 if removed

**2. Files and symbols:** lib/ui/admin/auth/view_models/admin_auth_view_model.dart:57–67,94–166,195–267; lib/routing/router.dart:88–95; test/ui/admin/auth/view_models/admin_auth_view_model_test.dart:340–348,409–445,587–643

**3–4. Observed behavior and PR-introduced complexity:** Shared login/logout gate, credential-free no-param commands, current session/response identity checks before rejected-account cleanup; VM grew 165→343.

**5. Protected invariant:** Never sign out/restore a different current identity; do not publish credentials in command snapshots/logging; current admin session controls routing.

**6. Concrete necessity evidence:** Tests replace account A with B during deferred/reentrant cleanup. command_it publishes parameters before action entry, making a credential parameter unsafe. No compare-and-swap session primitive is established.

**7. Consequence of removal:** Can terminate the wrong user session or route using stale identity; password could enter diagnostics if moved to parameter snapshots.

**8. Recoverability / regression risk:** Authorization/identity risk; retry is not an adequate substitute for wrong-user protection.

**9. Smaller alternative:** Keep current local contract and tests; do not generalize Auth with ordinary read handling.

**10. Decision and test treatment:** KEEP; no Auth simplification task or requirements relaxation.

## K04 — KEEP — Persistent reactivation and source moderation

**1. Severity:** P1 if removed

**2. Files and symbols:** lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:129–144,318–329,467–509; supabase/migrations/20261002175147_moderate_external_event_sources.sql:50–74; supabase/migrations/20261002181549_resolve_external_event_submissions.sql:341–378

**3–4. Observed behavior and PR-introduced complexity:** Reactivation is single-flight and reserves reads through post-commit refresh. Moderation uses backend source locks/tokens and returned exact pending ID. Post-editor refresh is a separate read-only policy.

**5. Protected invariant:** One accepted persistent attempt, truthful result, correct pending/source identity; no blind replay after uncertain response.

**6. Concrete necessity evidence:** RPC locks source row, clears ignored state, enqueues proposal and returns pending_submission_id. UI gates exact pending link; editor/backend enforce actual authorizations and hash/token checks.

**7. Consequence of removal:** Dropping mutation gate or replaying after refresh error can duplicate/reinterpret persistent work. Dropping only post-commit read gating may be safe but is not established here.

**8. Recoverability / regression risk:** Persistent/identity consequence, distinct from stale dashboard rows. Keep safe read retry without repeating unIgnore RPC.

**9. Smaller alternative:** KEEP mutation and exact link policy; N02 records evidence needed for any later phase reduction.

**10. Decision and test treatment:** KEEP all unIgnore/phase/pending-route tests. S01 removes only independent editor-demand state.

## K05 — KEEP — Event day and Home temporal ownership

**1. Severity:** P2 if removed

**2. Files and symbols:** lib/ui/event/view_models/event_view_model.dart:49–75,119–200,231–319; event/widgets/components/events_modal.dart:32–87; changes/migrate-content-view-model-commands/specs/{command-execution-concurrency,home-ongoing-events}/spec.md

**3–4. Observed behavior and PR-introduced complexity:** Day request captures annual revision/candidate; Home uses shared UTC/coalesced refresh and waiters. Event grew 248→364, but Home queue and day loaded revision cache already existed on main.

**5. Protected invariant:** Current selected day/data revision only; failure vs empty; fallback not in annual dataset; one UTC snapshot per discovery pass and documented coalescing.

**6. Concrete necessity evidence:** Event command/day widget tests cover annual rebase, A→B→A, empty fallback/cache/retry. Actual router and Explore refresh consumers rely on shared Home Future.

**7. Consequence of removal:** Removing day authority permits stale selected-date data. Removing Home scheduler changes a pre-existing deliberate contract, not just migration complexity.

**8. Recoverability / regression risk:** Read failures recover by retry but no proven smaller local design preserving cache and Home behavior was found. Complexity is not attributed entirely to PR.

**9. Smaller alternative:** Keep existing command/state until a separate concrete simplification is evidenced.

**10. Decision and test treatment:** KEEP; no new day-state abstraction or opportunistic Home redesign.

## K06 — KEEP — Category and remaining ordinary feature behavior

**1. Severity:** P2 if removed

**2. Files and symbols:** lib/ui/category/view_models/category_view_model.dart:17–21,82–176; category/widgets/category_content_and_type_selection.dart:50–59,110–160; all remaining feature files in coverage table below

**3–4. Observed behavior and PR-introduced complexity:** Category already uses simple synchronous filter setters plus one restartable atomic load. Other ordinary VMs mostly add safe release and direct ResultCommand outcome UI.

**5. Protected invariant:** Valid first Category frame, latest filters/current sort; no modal callback after unmount/owner change; exact preference/favourite rollback, distinct content-retention policies.

**6. Concrete necessity evidence:** Category tests cover atomic places/events failure and pending sort. Ordinary regressions prove different Explore/Suggestion failure retention, Favourite progressive load/rollback, consent committed-cache reconciliation, Sync fatal routing.

**7. Consequence of removal:** Generic removal or unification would drop established behaviors or recreate state inconsistently; simple setter/read design is already used where appropriate.

**8. Recoverability / regression risk:** Most are recoverable UI/read operations; no disproportionate additional protocol was established outside repeated cleanup (N01). Selector identity guard adds only local checks.

**9. Smaller alternative:** Keep explicit local patterns; no generalized abstraction or speculative modal rewrite.

**10. Decision and test treatment:** KEEP all behavior tests; no spec relaxation justified solely by large historical scenario counts.

## N01 — NEEDS EVIDENCE — Repeated ordinary command disposal closures

**1. Severity:** P2 candidate

**2. Files and symbols:** lib/ui/{settings,explore,favourite,category,event,post,sync,content_submission}/view_models/*view_model.dart; e.g. settings_view_model.dart:61–99,category_view_model.dart:180–220

**3–4. Observed behavior and PR-introduced complexity:** queued/invalidated/released + microtask/event/listener release logic is repeated in ten owner implementations. No common release helper was introduced; shared foundation is unchanged.

**5. Protected invariant:** Safe late raw reporting, no reentrant notifier teardown, settled resource cleanup.

**6. Concrete necessity evidence:** Package limitation is proven, but no deterministic experiment establishes that invalidated/requeue or event turn can be deleted across these public-command owners; their API differs from private editor/history commands.

**7. Consequence of removal:** Unproven shortening may create disposed-notifier errors or old finally clobbering new runs.

**8. Recoverability / regression risk:** Runtime/reporting risk. The local private-command simplification does not prove broad public-command cleanup equivalence.

**9. Smaller alternative:** No executable replacement now; keep existing behavior. Future evidence would need ordinary reentry/assertion/dispose and late-throw tests on actual public APIs.

**10. Decision and test treatment:** Excluded from this plan; do not add a generalized disposer as a speculative DRY response.

## N02 — NEEDS EVIDENCE — Post-unIgnore read/navigation phase

**1. Severity:** P2 candidate

**2. Files and symbols:** lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:467–509; widgets/admin_dashboard_screen.dart:307–320

**3–4. Observed behavior and PR-introduced complexity:** Mutation success is withheld until two reads settle, then exact pending link can open; failure of reads does not repeat mutation.

**5. Protected invariant:** Correct exact pending navigation after persistent commit, separate list/mutation outcomes.

**6. Concrete necessity evidence:** RPC already returns committed pending ID, suggesting reads may be presentation only; route/editor safety of exposing the ID earlier has not been independently proven for all status/source outcomes.

**7. Consequence of removal:** Early navigation could change lifecycle/identity behavior; effect on backend integrity is not established.

**8. Recoverability / regression risk:** Insufficient evidence; retain current phase. Read-only S01 is independent.

**9. Smaller alternative:** No alternative authorized. A later inquiry would verify exact returned ID/current session/editor hydration before relaxing this contract.

**10. Decision and test treatment:** Excluded; no discovery task blocks the bounded simplification plan.

## N03 — NEEDS EVIDENCE — Content Submission forwarding/cache choreography

**1. Severity:** P2 candidate

**2. Files and symbols:** lib/ui/content_submission/view_models/content_submission_view_model.dart:214–231,240–248,329–376,488–519; widgets/content_submission_progress_screen.dart:44–58

**3–4. Observed behavior and PR-introduced complexity:** Five cached snapshots plus results and running forwarding mirror private commands; progress combines isSubmitting and snapshot.isRunning. New forwarding accounts for admission-before-snapshot and terminal-before-safe-idle ordering.

**5. Protected invariant:** Immediate busy refusal/UI, no stale owner callbacks, truthful terminal state across route/session transitions.

**6. Concrete necessity evidence:** Cached frozen-after-dispose state and both notification orders are tested. A direct result getter is not proven to preserve all consumer timing and lifecycle requirements.

**7. Consequence of removal:** Potential false idle or reentrant duplicate admission near submission/finalization boundary, where persistent consequences matter.

**8. Recoverability / regression risk:** High consequence if simplified incorrectly; do not infer redundancy from overlapping getter names.

**9. Smaller alternative:** Keep current forwarding in this change; no new command facade or shared bridge for Content.

**10. Decision and test treatment:** Excluded. Duplication is documented, not a confirmed removable invariant.

## Complete seven-change coverage

Every metadata/proposal/design/tasks/delta file in these seven change directories was inspected; editor/session validation and analyzer ledgers, editor test-plan and machine evidence were inspected as historical records, not rerun results. `historical-artifact-inventory.json` hashes all 50 artifacts, including analyzer machine rows and autonomous manifest. Historical apply reports preserve original checkpoint provenance; no old count is represented as this audit's test result.

| Change | ViewModels and consumer path | Decision / relevant existing tests |
|---|---|---|
| migrate-simple-view-model-commands | Settings → SettingsScreen; Theme → app settings; Explore → ExploreScreen; Suggestion → suggestion_horizontal_list_view; Favourite → favourite_screen/button | KEEP consent from committed cache (Settings :37–57), independent theme writes/rollback (:38–78), Explore retain-on-error vs Suggestion clear-on-error, Favourite admission capture (:218–291), progressive lists and exact rollback (:61–195). Existing corresponding VM/widget suites and ordinary lifecycle suite cover real behavior. No generic unification justified. |
| migrate-category-view-model-commands | Category → category_screen and shared category_content_and_type_selection, Category route seed | KEEP synchronous filters/immutable combined read/current sort/atomic success and mounted-owner modal guards. Tests category_view_model_test, category_view_model_lifecycle_test, selector/screen and real GeoMap owner replacement. Modal A→B→A contract looks detailed, but current local identity guard is small; replacing it yields no evidenced benefit. |
| migrate-content-view-model-commands | Event → calendar/modal/Home discovery; Post → PostScreen/Nearby; Sync → SyncScreen/router | KEEP Event request/revision and pre-existing Home coalescing; Post route `(id,type)` ownership and first-error partial Nearby; Sync admission/fatal retry/routing. event_command_migration_test, event_day_migration_test, post_view_model_test/post_screen_test, sync_view_model_test/sync_screen_test/sync_redirect_test. |
| migrate-search-map-commands | Search → AppSearchAnchor/results; GeoMap → geo_map_screen markers, semantic selection/Nearby | S02/R01/R02. KEEP Search result/suggestion restartability and Map cross-type selection/route/weather ownership. History tests replaced only for relaxed optimism/demand; marker partial/error/empty/A→B→A/retry tests retained. |
| migrate-content-submission-commands | ContentSubmission → form/asset-list/progress/routing | K02/N03. All session/draft/staged/dedup/upload/finalization contracts stay. Existing content_submission_view_model, asset-list/progress/form and route/restoration/lifecycle tests remain; no backend change. |
| migrate-admin-session-commands | AdminAuth → login/settings/router; AdminSubmissions → dashboard/route editor return | S01/R03, K03/K04/N02. Keep credential/session guards, original reporting, pending exact ID, mutation/refresh distinction. Tests admin_auth_view_model/lifecycle/login and admin_dashboard_screen/admin_submissions_view_model/admin_dashboard_command_lifecycle/admin_route. |
| migrate-admin-editor-commands | AdminSubmissionEditor → editor form/dialog/current-route effects | S03/R04; preserve Save revision, admission matrix, candidate/preview/source semantic generation, asset/private phases, covered-route effects. admin_submission_editor_commands_test, admission_matrix, phase, VM/screen and real admin_route tests retain their behavior assertions. |

`lib/utils/command.dart` remains 159 LOC on both refs for legacy compatibility; no deletion/reintroduction is proposed. `result_command.dart` (57) and `restartable_command.dart` (216) are unchanged. Their test-only child counters are foundation resource tests, distinct from the PR-added editor physical probes.

## Test coupling and what can be deleted

Thirty **reference lines**, not thirty test cases, use the editor's four physical probes across commands (26), phase (3) and admission-matrix (1) test files. These lines can be removed or replaced; useful assertions in the same tests remain. Twelve feature-test reference lines use foundation child counters (Category 9, Event 2, GeoMap 1); no blanket deletion is proposed. `admin_dashboard_command_lifecycle_test.dart:670–1180` and Search demand/projection tests encode relaxed policy; replace those scenarios, not whole files or real failure regressions. `test/support/admin_editor_command_harness.dart`, dashboard/history harnesses can shrink only when no retained behavioral test needs the gate. Keep existing support reuse and controlled Completers; do not build a new scheduler-test framework.

## Metrics and estimates

See metrics.md for verified per-file LOC, introduced classes, listener/scheduling call sites, explicit semantic field inventories and custom mechanism provenance. Estimates concern future implementation, never measured post-simplification code. Main→PR VM growth is +2,506 LOC; it includes necessary fixes and is not a removable-code target. Readability and independently traceable operations take priority over percentage reduction.

## Acceptance and boundaries

Design D1–D5, delta spec and test-plan.md state what is preserved/relaxed, acceptable failure and recovery for every executable decision. No existing source, test, historical change or canonical spec is edited in this planning run. N01/N02/N03 are decisions to retain current code for insufficient evidence; they do not block review of the bounded plan and must not turn into hidden implementation investigations.

## F1–F3 documentation remediation — 2026-10-25

The initial audit and review above remain historical evidence. F1 adds the concrete popup subscription/rebuild path in design D3/F1 and rendered H10 acceptance in task 3.2/test-plan; the empty branch of `_buildViewBuilder` renders its own cache and ignores suggestions, so a suggestions-only listener would be insufficient. F2 adds D4/F2's local permanent release-identity claim and E11 convergence acceptance to task 4.1 without restoring the removed physical probes. Effective release is still exactly once; R04 removes its diagnostic API, not the safety invariant. F3 corrects seven misleading requirement names using installed rename-before-modify semantics; the exact old→new mapping and all thirteen supersessions are authoritative in design's effective-spec ledger. The other six titles remain accurate and unchanged. No excluded candidate is reopened, baseline metric is altered, or implementation result is claimed.

Current remediation verification and evidence normalization are recorded in validation.md/validation-evidence.json; focused-test-output.txt is normalized historical evidence, not a fresh or verbatim raw run.
