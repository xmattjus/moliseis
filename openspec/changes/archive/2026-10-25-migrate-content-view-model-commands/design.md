# Design

## Published checkpoint

Migration 3 was published in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12) at `1f3753b10c18061c6655cb32d078bf93aff1b05e`, parent `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, verified from Git history. All seven migrations are now published. The historical analyzer progression is **125 → 113 → 105 → 87 → 66 → 52 → 37 → 0 INFO**; this migration contributed **105→87**, not an analyzer-clean result. The records below distinguish original planning, subsequent implementation and review remediation. Local-only/publication restrictions describe their original authorization phase, superseded by publication; they are not current PR status. Canonical synchronization, archival, legacy compatibility removal and merge remain separate work.

## Context — planning history

See proposal.md for motivation. **VERIFIED** means source inspected or a command executed against the original baseline; **PROPOSED** means the contract to implement after review; **INFERENCE** means a source-supported consequence still requiring future tests. This planning section claims no implementation result; actual implementation evidence appears later.

### B0 — Preflight and provenance, 2026-10-21

- Repository: `xmattjus/moliseis`; origin fetch/push `https://github.com/xmattjus/moliseis.git`.
- Authorized checkpoint and dedicated worktree HEAD: `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, parent OpenSpec 1 `9d17d224d5094c5b043128113d9aba6a1ce69f0a`; OpenSpec 2 commit `refactor(category): migrate legacy commands to command_it`.
- Initial primary checkout: main, HEAD `ee60777c7fdfc5c16daa1151050c134fbb7cde29`, clean status and index. Local origin/main also pointed there. No fetch, reset or checkout was performed: main lacked the two checkpoints and could not replace the requested baseline.
- Reused `<temporary-worktree>`, already registered with Git, detached at the exact authorized checkpoint, initially clean with empty index. The new change did not exist. This was a distinct checkout, not a copy or symlink of the Category worktree.
- Initial other-worktree inventory: app-managed detached checkout at ee60777; Category worktree at e3d9d891 on `codex/plan-migrate-category-view-model-commands`; Simple worktree at 9d17d224 on its corresponding branch. None was modified or reused; no destructive operation was necessary.
- Read-only GitHub connector check: [PR #12](https://github.com/xmattjus/moliseis/pull/12) open, Draft, unmerged; head `codex/migrate-legacy-commands` e3d9d891, base main ee60777. Its body then documented 2/7 migrations published with gates pending; this was not new proof of passing suites or automatic approval.
- `openspec list --json` and `openspec context --json` resolved the nearest/repo-local root to `<temporary-worktree>`; `spec-driven` schema, no additional config context. CLI created `.openspec.yaml` without skip_specs. No nested AGENTS found on affected surfaces.
- Read AGENTS.md, OpenSpec 1/2 proposals/designs/tasks/deltas and foundation archive `2026-10-12-adopt-command-it-restartable-foundation` design/audit evidence, comparing them with actual source/tests. Historical sections are separate from final remediations: OpenSpec 1 D5 and OpenSpec 2 D8 supply the lifecycle pattern; OpenSpec 1 MODIFIED permits live ordinary continuations, including progressive publication. No Nearby conflict required new payloads/infrastructure.

### B0.1 — Verified persistent relocation, remediation F4

B0 above and the original closeout below document historical temporary planning, not current operating instructions. Remediation preflight: registered temporary worktree detached at `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, empty tracked diff/index, exactly six expected untracked artifacts. Destination and local destination branch absent, no drift against the approved manifest. PR #12 reconfirmed open/Draft at e3d9d891, base ee60777.

Historical commands, both exit 0; machine paths are represented by placeholders:

```text
git worktree move <temporary-worktree> <worktree>
git switch -c codex/plan-migrate-content-view-model-commands
```

The first ran from the primary checkout, the second from the relocated worktree. No recreation/copy, symlink, remove/prune, reset/clean/rebase/cherry-pick or commit. Initial/final HEAD e3d9d891 unchanged, 0 additional commits. New location registered, old location unregistered. Local branch unpublished, index empty. Artifact hashes **before = immediately after relocation, before remediation edits**:

| Change-relative artifact | Identical SHA-256 before/after move |
| --- | --- |
| .openspec.yaml | `30cfdee007123f96b2ab27ca107e406084602caf445d6b7cd2130ab329668ed3` |
| design.md | `9471379962a56c3d97586aae3a469a4c72b36e0f088c52741a55921d61f68e5c` |
| proposal.md | `891ada5f0592179e65846982e065250585f175e5d18f43eaf7e469b41c7f63a6` |
| specs/command-execution-concurrency/spec.md | `54554baab4f6745ca275d02edd269cbe0d23892c40218bc08c1aff36f03cc94f` |
| specs/home-ongoing-events/spec.md | `6147360877bb34697fe70a2e30c9c780f09f03d4dfa504da8f6b141ca1b06a03` |
| tasks.md | `dcccd65e6f4c67dd331b2400b233f9b9e10439f148167715d02955f1d434814d` |

All four other worktrees retained their prior paths, branches/detached state, HEAD/status: primary main ee60777; app-managed detached ee60777; Category `codex/plan-migrate-category-view-model-commands` e3d9d891; Simple `migrate-simple-view-model-commands` 9d17d224; all clean. PR read only.

**Operating location at that phase:** dedicated persistent `<worktree>`, branch `codex/plan-migrate-content-view-model-commands`; subsequent planning/apply/preflight used it. Temporary B0/B1 paths record provenance, not durable prerequisites. Proposal/design/tasks/concurrency-delta hashes changed after authorized F1–F3 edits; `.openspec.yaml` and Home delta stayed byte-identical during that remediation. These hashes describe historical revisions, not this translated narrative.

### B1 — Reconfirmed diagnostic baseline

A fresh run was actually completed at that phase, not copied from the historical ledger: **105 INFO, zero WARNING, zero ERROR; raw Dart exit 0; stderr empty**. All rows `LINT|DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. Direct Dart SDK **3.13.4 stable macos_arm64**; Flutter metadata **3.47.5**. Existing lockfile/resolved configuration confirmed command_it **9.5.2**, listen_it **6.0.0**; no pub get/upgrade/generation.

Measured historical command, cwd `<temporary-worktree>`:

```text
<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <evidence-dir>/analyzer-baseline
```

Code-preserving preparation: `git archive HEAD` extracted into a separate temporary directory; primary checkout's resolved package_config copied into snapshot `.dart_tool`, relative rootUri values resolved against the original config and only moliseis pointed to the snapshot's actual absolute URI. Every package root existed. No metadata/production file written in the planning worktree. Initial extraction with unsupported Python `filter` failed before analysis; replay used the available API and produced this result. Ephemeral logs: `<evidence-dir>/os3-analyzer.{stdout,stderr,json}`; stdout SHA256 `4555c585ada165fc65c09ccd530bc45a93950be265c02e477da0b0a958c2d545`. Those raw logs are not tracked or guaranteed accessible. Their historical hash is retained, but cannot be independently recomputed from this narrative. The published baseline sources remain available for replay, which is a separate execution.

Reconfirmed target identities (line:column, symbol; one occurrence per position):

| File | Baseline identities | Total |
| --- | --- | ---: |
| lib/ui/event/view_models/event_view_model.dart | 19:15 Command0; 21:18, 22:19, 23:16 Command1; 30:8 Command0; 31:8, 34:8, 37:8 Command1; 221:32 Command | 9 |
| lib/ui/post/view_models/post_view_model.dart | 13:17, 14:23, 15:17 Command1 constructions; 21:8, 22:8, 23:8 Command1 declarations | 6 |
| lib/ui/sync/view_models/sync_view_model.dart | 15:12 construction and 37:8 Command1 declaration | 2 |
| test/ui/event/widgets/components/events_calendar_test.dart | 234:30 Command in the waiting helper | 1 |

Planned target **87 INFO**, zero warnings/errors or new identities. Compare normalized Counter by path/rule/message-symbol/context/multiplicity rather than net count; lines may move. Remaining 87 identities can be obtained by replaying this SHA and subtracting the 18 above. No ignore/exclusion/config lint hiding. Direct Dart does not make INFO fatal by default; no `flutter analyze` ran in this planning section and its exit cannot be inferred from Dart. If run during apply, record argv/exit separately, including nonzero exit for remaining INFO.

### A0 — Source and consumer audit

All six requested files were read fully. References below belong to the baseline and require rechecking if moved during apply.

| Surface | Verified evidence and actual consumers |
| --- | --- |
| Event VM | `lib/ui/event/view_models/event_view_model.dart:11–55,94–150,159–250`: four Commands, annual autoload, year/day cache, discovery and waiters. |
| Event UI/route | `lib/routing/router.dart:300–337,422–445`: distinct Home/Events owners; Home starts refresh, Events requests current day before Provider listeners attach. `events_screen.dart:66–88` selects day; `components/events_calendar.dart:58–97` observes annual/markers/retry; `events_modal.dart:60–87` observes day/reads byMonth; `explore_screen.dart:68–104,222–267,275+` observes ongoing/next and requests refresh on return/retry. Menu refresh at :409 forces Sync. |
| Post VM | `lib/ui/post/view_models/post_view_model.dart:10–87`: **three** Commands, two detail lanes and Nearby events→places; late content; disposed guards but no Command disposal. |
| Post route/UI | `core_routes.dart:84–170`: inherited-category/positive-id/type validation, `(id,type)` Provider/screen keys, bootstrap one lane. `post_screen.dart:45–99,124–229`: detail/Weather listener, content only after completed, Nearby loadKey/ownership/coordinates; baseline detail failure leaves spinner. `post/widgets/components/` retains rendering/navigation; `post_section_nearby_content.dart` delegates to shared widget. |
| Shared Nearby | `lib/ui/core/ui/content/nearby_content_horizontal_list.dart:17–75,99–180`: pending/items/error record, post-frame scheduling by key/listenable, error/empty/list/partial-error, optional retry. Post supplies items only on success: VM retains partial data but baseline Post UI hides it on aggregate failure. Preserve that projection and onRetry null; do not extend the component's partial UX to Post. |
| Sync VM/UI | `sync_view_model.dart:14–50`: **one** Command, bootstrap when due, force/schedule, fatal only on Result.error without lastSyncedAt, never reset. `sync_screen.dart:19–127`: error listener, post-frame latch, fatal retry/loader/EmptyBox; captured late final owner needs replacement awareness. |
| Sync router/DI | `router.dart:83–93,539–595`: refresh on legacy Command value/admin auth; running→syncFor(uri), fatal stays, otherwise `_validatedFrom`/Home. `dependencies.dart:211–225`: app-scoped SyncUseCase/SyncViewModel; scope change unnecessary. |
| Foundation | `lib/utils/command.dart:75–107`: inline running/action, result reset to null at start, duplicate drop, catch Object→Result.error plus original FlutterError.reportError. `result_command.dart`: typedef/factory/snapshot; `restartable_command.dart`: authoritative envelope, switchMap/private child settlement. `command_configuration.dart`: privacy-aware global handler, reportAllExceptions=false, no parameter logging. |

Canonical contracts read: `command-execution-concurrency/spec.md` (neutral/domain/runtime/assertion, immediate revocation, reporting/cleanup); `canonical-app-routing/spec.md` (validated id/type/parameters, deep links); `main-navigation-shell/spec.md` (branch ancestry, owner retention, predictive back, restoration); `event-temporal-integrity/spec.md` (annual/day overlap, UTC next snapshot, 30 Rome civil days); `home-ongoing-events/spec.md:81–178` (classification, shared snapshot, errors/retention, returns/coalescing); `local-content-retrieval/spec.md` (direct atomic materialization, feature-owned query semantics). No standalone canonical Sync/Nearby capability exists to invent: router/tests contract the redirect and Home references Sync. New Sync/Post requirements therefore extend existing concurrency capability; no new routing architecture.

`SyncUseCase.sync` read fully: server cursor before fetches; lower bound C−24h; four concurrent prepare phases, including U=C; city/place/event/media committed in one atomic transaction; server cursor/completion timestamp saved in Settings only after commit; Settings failure retains committed content and old cursor for replay; finally closes tracing transaction. VM disposal **must not interrupt** already-started internal phases. No UseCase/repository/coordinator/backend edit.

### A1 — Actual command_it 9.5.2 semantics

Authoritative resolved package sources: `<pub-cache>/hosted/pub.dev/command_it-9.5.2/lib/command_it.dart`, `async_command.dart`, and listen_it notifier. `pubspec.lock` pins this version; no inference from README/latest.

| API/fact | Evidence and project effect |
| --- | --- |
| run :312–349 | void async; rejects disposed/restricted/busy, sets isRunningSync=true and results loading inline, then zero-delay before action. Immediate admission, deferred I/O. |
| runAsync :859–870 | Creates a completer or returns the active one; a concurrent call can join another execution. Refused run without active execution does not guarantee its own terminal. Never proof of admission. |
| success :369–386 | Terminal results **before** isRunningSync=false/Command value notification; completes Future with Result. Command.value can retain old success during running/runtime error. |
| errors :420–446,920–1024 | AssertionError rethrows before filters; handled error publishes terminal results before global handler and false in finally. globalHandler factories treat Result.error as an unreported value; raw throw retains Object+stack and runAsync completesError. No second manual report. |
| notifier :249–251,775–779 | results/Command value notify synchronously; only UI isRunning is deferred. Restartable instead exposes its own deferred results/isRunning. Do not generalize deferred snapshots to ordinary lanes. Observable interface remains results/ResultCommandSnapshot. |
| dispose :799–825 | Marks disposing immediately, destroys notifiers after 50ms; pending runAsync may complete with current value rather than physical outcome. Late raw throw after teardown may fail on notifiers before reporting. Isolated sync false/terminal/completed Future does not prove dispatch ended. |

Foundation tests read: `test/utils/{result_command_test,restartable_command_test,command_configuration_test,command_it_disposal_behavior_test}.dart`; upstream skips characterize the defect, not a solution for these owners. Existing ordinary D5 and restartable wrapper are approved remedies. No execute compatibility shim/foundation change.

## Goals / Non-Goals — planning

**Goals:** seven ordinary lanes, one latest-intent lane; business/orchestration in VMs, result/admission in Command, rendering/feedback in Views. Observable route/day identity, synchronous exclusion, retention, terminal state and revocation before teardown.

**Non-Goals:** new Post/Nearby retry UX (unchanged); manual Event day retry F1 is in scope. Other four migrations, command.dart removal, Weather Command, new Nearby foundation/routes/URIs/Provider scope, backend/persistence/temporal policy, automatic retry, physical cancellation, periodic refresh, new packages/global controllers/schedulers/adapters, duplicate generation counters, canonical sync, archive and PR publication. No Dart/test edits during planning; test/support edits require later authorized apply and applicable repository test/lifecycle skills.

## Decisions — approved planning contracts

### D1 — Matrix of eight Commands

Common legend, integral to every row: **L**, baseline legacy = inline admission/action, per-lane single-flight/drop, previous result reset at start; domain errors retain Exception, runtime Object is incorrectly projected into Result.error and reported with original FlutterError; no lane disposal. **O**, proposed ordinary = ResultCommand, inline admission/deferred action, single-flight/drop without queue; snapshots do not retain old data during loading/error, Command.value is not the outcome; original domain errors remain distinct from unexpectedError, global reporting once, assertions fail loud. **R**, proposed restartable = immediate new authority even for equal parameters, pure retrieval and commit only in the live observer; stale runtime remains reportable without publication. **CL**, D5 cleanup below, applies to all seven O lanes; wrapper already owns R children. VM data and previous Result are distinct concepts.

| Command / responsibility | Verified baseline: consumers, state, retention, concurrency and problems | Proposal / intended change / discriminating tests |
| --- | --- | --- |
| Event.loadAll / annual bootstrap and markers | L; constructor, calendar/retry/tests; VM all + byMonth/selectedDate and Command running/completed. Success increments yearlyRevision/recomputes day; failure retains data/revision. May overlap day. Guard after await but not before entry; Command undisposed. | O<void,void>; autoload run once after lanes/observers initialize; guarded entry. Same retention; annual rebases day D2 to prevent old terminals. E1/E3/E5, C/L. No latest-intent need for overlapping annual reloads. |
| Event.loadByDate / selected day and fallback | L; Events route/EventsScreen/modal/tests. Selection changes inside action; date+revision cache avoids query, nonempty annual cache wins; empty fallback success cacheable, failure retryable. B taps dropped during A. No disposed guard after query; future A→B→A overlap cannot rely on equality. Error retains annual-derived day (including []), not previous day's contents. | R<Request,DayResult> + synchronous VM selectDate; immutable identity-bearing date/revision/candidate request D2, data only in completion observer; full modal error/retry and F1 stale barrier. New intents retained, old A revoked. Annual revision remains necessary across lanes; no day generation. E2/E3/E4/E5, L. |
| Event.loadOngoing / ongoing classification | L; coordinator, Explore sections/direct tests; running/completed/error/ongoing. Success atomically replaces list in repository order; error retains prior data; independent of next, one pass awaits both. Guards before/after await, lane undisposed. | O<DateTime,void>; same snapshot/retention, VM coalescing, not restartable. Distinct runtime terminal must not abort next. E6/E7/E8, C/L. |
| Event.loadNext / upcoming classification | L; coordinator, Explore/tests; analogous next list; receives caller's instant without recapturing. | O<DateTime,void>; separate lane ordered by D3 coordinator. No latest-intent: every pass resolves both sides. E6–E8, C/L. |
| Post.loadEvent / Event detail | L; core_routes starts, PostScreen observes completion for body/Weather, tests. Success sets late content, error does not; failure leaves spinner. Single-flight only within lane, theoretical overlap with loadPlace but no actual consumer does so; new route creates owner. Guards before/after await, no lane disposal. | O<int,void>; preserve lane/route key without new latest-intent controller. Terminal UI hasFailure D4, no late read, Weather only after actual Success. P1/P2/P3, C/L. |
| Post.loadPlace / Place detail | L; same role for another route type/shared content property; theoretical cross-lane risk without caller. No prior content transferred to new VM. | O<int,void>; same decision as loadEvent. Do not generalize same-owner retargeting; id/type changes owner. P1/P2/P3, C/L. |
| Post.loadNearContent / nearby data | L; PostScreen/shared Nearby observes running/completed/error; clear all on accepted action, events→places even after events Result.error, append successful sides, first error. VM partial list hidden by Post failure projection; onRetry null. Does not start places after disposal. | O<LatLng,void>; live ordinary continuations per OpenSpec 1 delta, no new outcome wrapper. Preserve original clear/partial retention; runtime aborts action as unexpected without starting next phase after throw. Preserve projection/retry D4. P4/P5/P6, C/L. |
| Sync.sync / use-case protocol and routing availability | L; constructor when due, Explore menu/pull, SyncScreen retry, router refresh; force bool/result/running/fatalError. Duplicate drop; fatal only set true for domain/no timestamp, never reset; no VM guard/disposal. Legacy runtime conversion does not update fatal and can leave inconsistent redirect. | O<bool,void>; no restartable write/transaction. Admission before frame, force/schedule unchanged, current fatal for both distinct failure channels D6; async router wake after sync false. S1–S8, C/L; UseCase protocol unchanged after disposal. |

Reentrancy: same-lane ordinary run while true is refused; terminal listener may still see true and must not retry inline. UI retries in a later callback. R observer may select B/dispose owner: every post-notify step rechecks ownership and performs no further A assignment. CL never disposes inline, even when apparently idle. Eight Commands do not become eight new coordination controllers.

### D2 — Event: selection, annual data and revisions

PROPOSED: synchronous orchestration entry `selectDate(EventCalendarDate)` for routes/consumers. `loadByDate` remains the sole observed R, without disguised execute API. Immutable feature-local request holds day/yearlyRevision/optional annual candidate/cacheable. F1 requires a small payload class with instance identity, no equality override: a value-only record cannot distinguish equal-parameter A intents. VM retains the **actually admitted request** (`currentDayRequest`), not another UI flag/generation counter/controller. Outcome may remain a record of original request/data. `_loadedDate`, `_loadedDateRevision`, `_yearlyRevision` track cross-lane validity, not intent identity.

**F5 — Single-day cache before any derivation.** Baseline `event_view_model.dart:117–150` checks loadedDate/revision and returns **before** `_byDate = getEventsOnDay(date)`, preserving successful fallback X absent from `_all`. Earlier annual-candidate wording does not authorize rebuilding `_byDate` on a cache hit: that would erase X without refetching. `_byDate` is authoritative for the current day when committed by a current successful request (annual or getByDate) with valid loadedDate/loadedDateRevision. It is not always an `_all` projection.

**Exact F1/F5 selection/admission order:** disposed → no-op. **Before** request creation, selection/marker mutation, notification or annual derivation, jointly check date == selectedDate == loadedDate, loadedDateRevision == yearlyRevision, no pending intent (`!isRunningSync`), current completed snapshot, terminal request identical to currentDayRequest with current day/revision. If true, cache hit: **return without any mutation**, new admission/query/VM notification, request/terminal replacement or pending sequence. Preserve `_byDate`, including nonempty fallback absent from `_all` or getByDate Success([]). UI retains grid X/terminal empty; no skeleton or incorrect `_all`-derived empty.

This caches **one current selection**, not multiple days. Different date/revision or invalid current success means miss, even if an old marker equals the requested date. In A→B→A, admitted B revoked A: returning to A creates new authority rather than reviving original A. Otherwise, one synchronous section without intermediate await/notify:

1. After excluding a hit, compute annual candidate once locally without touching `_byDate`; create immutable request and set currentDayRequest. Old request immediately loses commit/projection authority by identity comparison.
2. On **miss/new intent**, invalidate old `_loadedDate`/`_loadedDateRevision` before replacing `_byDate`, update selectedDate and install the already computed candidate. Markers cannot certify A while `_byDate` holds B's candidate. Cache hits never derive; previous-day data never represents the new day.
3. Call `loadByDate.run(request)`: foundation atomically revokes old envelope/admits new one, setting isRunningSync=true before return. No separate invalidate producing unnecessary neutral publication. Application revocation at 1 and foundation revocation at 3 share an uninterrupted section without intervening publication.
4. Notify VM last if live; make no further assignment for that intent after notification, whose listener can reenter with B/dispose.
5. R asynchronously publishes loading/terminal only from authoritative envelope. VM completion observer installed before consumers commits success/notifies; rendering uses the projection below.

**Barrier and identity are distinct:** isRunningSync is immediate; R isRunning/results are deferred. After B admission, results may still contain terminal A. R also lowers isRunningSync before publishing new terminal: false alone does not establish a current public terminal. Modal/observer accept terminal only if `identical(snapshot.paramData, currentDayRequest)` and current day/revision match. Payload instance distinguishes first/last A despite equal date/revision. No R action mutates VM after await. Only a miss resolves nonempty annual candidate as new Success without repository; hit runs no action and preserves entire previous `_byDate`, nonempty or empty. Fast path cannot leave B authoritative when returning to A.

**EventsModal F1 projection (binding branch order):** directly observe `Listenable.merge([viewModel, loadByDate.results])`, rebinding on owner change; title also reads current VM selectedDate rather than old parent-captured argument. Check synchronous admission, then request identity/snapshot validity, then ResultCommandSnapshot outcomes. Read VM fields in build only under these guards; title follows current day independently of previous terminal. UI neither subscribes to synchronous notifier nor adds loading flag.

| Effective state | Presentation |
| --- | --- |
| Neutral, no resolved day | Skeleton |
| New admitted intent, isRunningSync true | Skeleton even if results retains previous terminal |
| Snapshot stale for request/date/revision | Skeleton; never A grid/empty/error under B |
| Current isRunning or idle snapshot | Skeleton |
| Current completed snapshot, nonempty list | Grid of committed current events |
| Current completed snapshot, empty list | EmptyView “Nessun evento trovato per questa data.” |
| Current domainError snapshot | EmptyView.error, generic message and “Riprova”; original Exception in Command, no global report |
| Current handled unexpectedError snapshot | Same error/retry surface; original Object/stack in runtime channel and global reporting once, no Result.error conversion |

Retry uses still-current owner callback reading `viewModel.selectedDate` **at invocation**, then selectDate(value). No date captured from old error, annual reload, new owner or automatic retry. Noncacheable failure → new intent/query; empty/items successes remain distinct. Callback surviving replacement/unmount must be revoked or verify mounted/current owner before State access; VM guard rejects disposed owner. No new Post/Nearby retry UI.

**EventsCalendar F1:** baseline ListenableBuilder observes only loadAll, while EventsScreen also preserves children in AnimatedBuilder. Directly observe VM + loadAll.results where selectedDate/markers are computed: admission notification updates highlight before action entry without relying on parent Consumer. No isRunningSync subscription/calendar/package/marker/temporal rewrite. Modal title/body observe same VM selection.

Action: no I/O if disposed before entry; supplied candidate → Result.success(outcome); otherwise one getByDate using request revision without rereading selection. Results observer installed before runs/consumers ignores loading/failure and commits Success only for live owner, identical currentDayRequest and matching selected day/current revision. Foundation distinguishes repeated equal dates. Update byMonth/cache markers together before notify. Failure retains miss-derived candidate, leaves markers invalid and remains noncacheable terminal; equal tap/“Riprova” retries. getByDate Success replaces entire `_byDate` and marks date/revision together even for Success([]), distinct from failure. Commit/notify follow request+day+revision check before UI consumes terminal. No Command.value outcome or temporal policy changes.

Annual: ordinary autoload once; only new Success replaces all, increments yearlyRevision and invalidates previous-revision cache including fallback X absent from annual data. Rebuild `_byDate` from annual data for **current** selectedDate; do not reuse prior fallback as new-revision cache. Nonempty marks date/revision; empty clears both. If day selection already requested (nonneutral snapshot or active R admission), replace currentDayRequest and admit a new resolution in the same VM operation/F1 order, with annual candidate **including empty** at new revision and no implicit query. Revoke any previous fallback, including failed terminal, and settle presentation with current annual dataset. Annual empty yields Success empty without loadedDate marker; later explicit selection can fallback as before. Distinguish supplied empty from “no candidate, query”; local bool cacheable suffices, no new domain Result. Intentional day-outcome rebase prevents spinner/failure tied to superseded data; modal barriers then shows success-items/success-empty without awaiting obsolete physical fallback. No automatic retry/second initial query. Annual-only Home never bootstraps day lane.

Year/day concurrency: newest annual data invalidates old dataset in either completion order; R commit also checks revision. Annual failure neither increments revision nor invalidates/rederives valid fallback cache: `_all`, `_byDate`, markers unchanged. Annual notify may reenter selection: rebase before notify and recheck before any subsequent request. Current day derives from EventTimePolicy Europe/Rome; no UTC/device reinterpretation as civil day. Inclusive all/day and startDate/remoteId sort unchanged. Midnight does not autorefresh: currentCalendarDate reads clock when requested; Home pass retains its instant.

### D3 — Event: Home refresh and settlement

Keep `_homeRefresh`, pending bit and temporary finish registry in VM. Non-async `refreshHomeDiscovery` returns **the same Future** to concurrent callers; each batch during a pass requests one subsequent pass, not one per caller. Requests during that subsequent pass may require another: coalescing is not a global two-pass limit.

Replace legacy Command-typed waiter with local helper over ResultCommand<DateTime,void> lanes. Coordination uses `isRunningSync`; UI observes results. Subscribe before final check and detach exactly once on settlement/revocation to prevent check/subscribe lost wakeup. Waiting means lane ended, **not** successful result or own run. No runAsync or catch Object→Result to await/absorb throws.

Algorithm: before a pass, wait until both lanes are free, rechecking both after each wait and owner before I/O. Only then capture `_nowUtc().toUtc()` once; pass same DateTime to ongoing, await terminal/false, then next. If direct request occupies next after capture, wait and admit pass's next with **same** instant. Free check+run share synchronous section, no intermediate await; refused run is not an executed pass. No global fairness guarantee for arbitrary callers; Home consumers use only coordinator.

Ongoing Result.error/handled runtime terminal does not abort next; each Command exposes own failure/retention, upstream reports runtime once. No conversion catch/second coordinator log. Fail-loud assertion is not normal terminal: sync false releases waiter/cleanup without fabricating lane success. Coordination does not certify both succeeded.

Revocation: pending=false, detach/close all waiters even while physical lane pending, release public refresh Future without new query; runner rechecks disposed at each resume. Guard completer with isCompleted and own `_homeRefresh` identity so duplicate finish neither completes twice nor clears later refresh. Dispose does not await physical Future. Ongoing/next lists replace only on live Success in repository order; each error retains its side, empty success clears it. New pass recaptures clock only at start, never while waiting/between lanes. Rome midnight/DST/next-window tests use existing policy/repository; no corrective View classification.

### D4 — Post: detail, Weather, Nearby

Keep three O lanes, `(id,type)` keys, validation and core_routes bootstrap using `run(id)` on selected lane only. Admission before returning Provider, deferred query. Unchanged route does not reseed/refetch; different identity replaces owner, so no additional R lane. Both detail actions retain ordinary guarded commits before/after await and before notify. No actual consumer retargets both lanes on one owner; no generalized content-selection API for a theoretical case.

PostScreen observes selected lane results, capturing one snapshot per decision; neutral/running → loader; completed → only then read content/render sections; hasFailure → EmptyView.error with existing generic text, no content read/new route/snackbar/retry button. This intentionally fixes infinite loading. No UI stack details; outcome stays accessible in Command. A newly accepted VM attempt/new owner can recover without adding absent retry UX.

Weather binding: detach old results listener/clear target on Post owner/type/Weather owner change; bind only after actual current-lane Success, using id/type/coordinates assigned before terminal. Pending/failure/replacement → null target. Init reconciles already terminal snapshot. Same owner/target rebuild does not refetch; new Weather instance receives current target. Do not migrate Weather Command or move its I/O into Post VM.

Nearby retains `_nearContent.clear()` on accepted entry, events→places, successful-side append and first Result.error precedence. Return consistent original Result<void>, no extra payload: OpenSpec 1 ordinary MODIFIED permits live progressive continuations, resolving tension with not-yet-consolidated canonical spec. Post-events guard prevents places after disposal; post-places guard prevents append/notify; runtime throw aborts next side and remains unexpected. No list rollback/new result cache. Programmatic retry when idle clears/restarts; Post UI keeps onRetry null.

Nearby consumer observes `loadNearContent.results`, projects pending from idle/isRunning and error from domainError ?? unexpectedError. Items only when completed: VM partial data remains readable but baseline Post projection hides it on aggregate failure; **do not** alter shared presentation to show it. Preserve loadKey `(owner,remoteId,type,coordinates)`, ownsContent/coordinates.isValid guards and shared post-frame scheduling. Old callback checks mounted before current owner/content rather than reading widget after unmount; no query after disposal/new detail. No NearbyContentHorizontalList edit absent demonstrated contradiction and plan review.

### D5 — Common local lifecycle, already approved

Apply existing Explore/Theme and Category.setSort ordinary pattern: immediate idempotent `_disposed`; detach commit/public forwarding/router-owned observations; defer VM super.dispose outside dispatch via microtask. Guard action entry, post-await, post-reentrant-notify and every owner-controlled mutation/notification/phase. Disposed before entry → no I/O, local owner-unavailable Result.error without presentation. Already-started I/O retains original outcome without commit; Post starts no places, Event no next side/pass. Invoked SyncUseCase is one domain-owned phase; do not cancel its internal steps.

Privately retain each active O Command; after revoke only private isRunningSync cleanup listener remains. Never-run/idle still require deferred cleanup. Coalesce check through microtask→event callback; invalidate barrier on every sync transition, then recheck not-running/released/valid barrier. If running, await next false without polling; if invalidated, renew for that transition. Remove listener/mark released **before** sole command.dispose. Never dispose during results/value/VM dispatch, action finally or solely from runAsync Future. Upstream 50ms timer is teardown, not settlement; do not copy into owner. R reuses child cleanup; detach VM observer before wrapper disposal, no parallel tracker.

This preserves original late StateError/TypeError global reporting once after owner disposal without secondary disposed-notifier failure. Assertions retain rethrow policy with private cleanup on sync false, no invented UI terminal. Never-settling Future can retain Command/private closure indefinitely: deliberate known limit. No generalized helper/hierarchy/reference counting/timeout/global logging/new package. Test support may parameterize genuinely shared contracts without eight copies/generalized production wrapper.

### D6 — Sync: admission, outcome and routing refresh

Create `ResultCommand<bool,void>`; install results classification before autoload. Constructor calls `sync.run(false)` if `_useCase.isSyncRequired`: isRunningSync true before first frame even before action calls UseCase. `_sync(force)` guards disposal at entry, then checks force||due at entry time; true forces, false not-due returns Success without UseCase. Duplicate run drops, never queues/coalesces/restarts. Accepted usecase.sync is indivisible to VM and continues privately after revocation.

**Availability and error are separate axes.** VM results observer synchronously classifies current execution: loading/neutral/Success → fatalError false; domainError **or** unexpectedError terminal → `lastSyncedAt == null`. No raw Object→Result.error conversion/VM report; assertion does not pass through normal terminal. Runtime fatal text generically says update unavailable, not that StateError necessarily means network error; reuse layout/retry. Intentionally fixes sticky fatal and unclassified no-cache runtime failure. Existing lastSyncedAt remains proxy, not physical-data diagnosis: Settings failure after first commit can leave data without timestamp and remains conservatively fatal. Cache-health criterion/domain contract changes are outside scope.

Apply clarification: preserve object/stack received from SyncUseCase, no VM conversion/unwrapping. Existing four-prepare tuple `.wait` can produce ParallelWaitError for async prepare throw, original cause in corresponding AsyncError slot. That wrapper is actual boundary runtime error, reported once; cursor/commit throws may arrive directly as original StateError/TypeError. Tests distinguish paths; domain protocol/Command assertion policy unchanged.

Router merge replaces legacy Command value with `sync.results` **and** deferred `sync.isRunning`, retaining adminAuthViewModel. `_redirectForSync` reads `sync.isRunningSync.value` for admission and `sync.results.value.hasFailure` for terminal, not upstream isSuccess/value/deferred isRunning alone. First terminal results may notify while sync true; deferred isRunning supplies later refresh after false. VM fatal classifier installed before router/Screen updates before terminal wake; deferred refresh still reads current snapshot. No UI sync notifier listener/new loading flag. Verify no early/stuck redirect after success/failure.

URI semantics unchanged: running outside sync→RoutePaths.syncFor(state.uri); already on sync preserves from. Non-running fatal failure stays for retry; other non-running states on sync, including restored neutral, use `_validatedFrom`/Home fallback. Preserve full URI/id/type/q/category/admin guards/branch ancestry. No redirect side effects.

**F2 — Current feedback before normal return.** Actual `test/routing/sync_redirect_test.dart:146–175` requires Home return **and visible snackbar after return**. Earlier plan suppressing every post-unmount callback contradicted that gate and is superseded here. SyncScreen owns feedback; router/VM do not show snackbar or coordinate notifications.

SyncScreen `sync.results` listener sees ordinary terminal synchronously while isRunningSync may remain true. Distinguish snapshot.isRunning from physical settlement still finishing. Check State mounted, Sync route current (`ModalRoute.of(context)?.isCurrent == true`), Provider still supplies owner, snapshot identical to `owner.sync.results.value`, hasFailure and VM-classified !fatalError. **Do not require !isRunningSync for current terminal authorization:** that loses pre-return window. Normal path does not wait for deferred isRunning/post-frame.

Normal async action terminal arrives outside synchronous frame construction because command_it deferred entry. Mark owner/snapshot pair authorized **before** immediately calling `showSnackBar(context: context, ...)` with existing update text. This delivers to global infrastructure in same stack, not merely permission for later closure. Original runtime reporting/upstream finally sync false then proceed; deferred router wake may unmount Screen/return from. Router/Screen results-listener order is irrelevant while true keeps redirect on /sync. No artificial redirect delay.

**Verified snackbar compatibility:** `lib/ui/core/ui/custom_snack_bar.dart:60–99` uses `$scaffoldMessengerKey.currentState`, but `_buildSnackBar` immediately reads `context.appColors`/`context.appShapes` (:122–140 and final shape); logging reads `context.read<Logger?>()`. Content Builder later reads Theme/MediaQuery/Localizations from **its own** messenger context, not unmounted State. `lib/main.dart:197` and `test/support/sync_harness.dart:146,267` install same global messenger. Thus invoke with valid context; once built/enqueued globally, normal Sync unmount must not remove/retroactively cancel snackbar. No closure captures context/widget/Provider for post-dispose use; no global helper/new service change.

**Deferred paths and obsolescence:** Flutter ScaffoldMessengerState.showSnackBar (`scaffold.dart:314–380`) mutates state and forbids build-time calls. Reconciling already terminal owner during didChangeDependencies or delivery during SchedulerPhase.persistentCallbacks therefore registers one **not-yet-authorized** post-frame callback. No showSnackBar in build/didChangeDependencies or captured context used after unmount. Callback checks mounted first, then current Sync route, binding owner/current `context.read<SyncViewModel>()` identical to capture, still-identical terminal snapshot, !fatalError and no new admission (`!isRunningSync` only for this reconciliation path, not normal terminal listener). If valid, mark authorized and invoke helper with current context; otherwise discard. This never replaces immediate normal terminal delivery: normal return must not depend on callback survival. Binding already terminal B reconciles UI immediately and, if consumer remains current/live, at most one deferred nonfatal B feedback; no sync invocation for notification.

Accepted attempt's loading invalidates pending snapshot; busy refusal changes neither snapshot nor dedup. Detach/unmount invalidates every unauthorized callback. Unrelated unmount before authorization → zero feedback/actions; normal return **after global delivery** → feedback retained. No clearAppSnackBars in dispose/rebind or withdrawal of delivered message; it is not a new post-dispose State action.

**F2 dedup:** terminal owner/snapshot identity, pending reference and last authorized reference for observed owner, marked before delivery against reentrancy. Not Exception equality or CommandResult == attempt key. Every new attempt has loading/new terminal: two failures with same Exception each deliver once; repeated snapshot rebuild/notify delivers no duplicate. Harmless didChangeDependencies does not clear authorization. Contract covers current route consumer, no global historical replay/new controller. Fatal failures never take nonfatal snackbar path.

**F3 — Provider dependency and State ownership.** Baseline initState `late final owner = context.read` is not reactive: nested Consumer updates body but not State listener. didChangeDependencies must use `final currentOwner = Provider.of<SyncViewModel>(context);` with implicit listen=true. Resolved Provider **6.1.5+1** (`provider.dart:296–335`) registers dependOnInheritedWidgetOfExactType, invoking didChangeDependencies for changed Provider value preserving State. Non-listening read there is insufficient. Callback context.read only verifies identity, not rebinding.

Same owner: no detach/attach/dedup reset/new feedback/schedule merely on rebuild. New owner: (1) detach A results/running listeners; (2) invalidate unauthorized A callbacks; (3) assign mutable State field B; (4) attach B once; (5) reconcile available B snapshot via current projection/build-safe path without mutating B; (6) dependency rebuild updates UI; (7) dispose detaches actual bound owner/invalidates pending before super.dispose. Do not reset dedup each Provider notify. A callback also checks current Provider to reject replacement even before delayed State rebind. Projection remains synchronous admission→spinner, fatal hasFailure→error/retry, otherwise EmptyBox during exit. Provider/DI scope unchanged.

**F6 — Two distinct owners, no implicit router rebind.** Baseline `_MoliseIsAppState.didChangeDependencies`, `lib/main.dart:174–181`, creates `_router ??= buildAppRouter(syncViewModel: context.read<SyncViewModel>(), ...)` once per State; Theme rebuilds reuse router, dispose releases it. `lib/routing/router.dart:58–95` refreshListenable/redirect closure retain construction-time argument. Reactive SyncScreen Provider.of updates **only** that consumer's listener/body/feedback owner, not router capture.

F3.1–F3.5 is local: same Screen State A→B detaches A, invalidates unauthorized pending, observes/renders already terminal B without sync and detaches B on dispose. It does not prove B-driven redirects while router retains A. Do not claim support via artificial Provider B/router A end-to-end test.

Normal app-scoped Sync owner (`config/dependencies.dart:211–225`) is same instance passed to router and supplied to Screen. Bootstrap/redirect/fatal/retry/completion/feedback use it. New B session/restoration requires consistently recreated app/router lifecycle with B, not Provider replacement under old `_MoliseIsAppState`/`_router`. No dynamic router owner replacement or MoliseIsApp/buildAppRouter change to support it. Scope only adapts router listenables/snapshots for owner already passed.

Harness evidence: `test/support/sync_harness.dart:126–151,167–230` supplies harness.viewModel to both buildAppRouter/Provider; buildRealSyncApp uses MoliseIsApp for real root lifecycle. SyncRestorationFixture:234–276 creates new router with new harness/owner and same Providers. Reuse these and sync_redirect_test.dart bootstrap/fatal/retry/preserved URI/restoration/Theme-router identity entrypoints, no shadow router/new DI.

### D7 — Alternatives and tradeoffs

| Alternative | Reasoned decision |
| --- | --- |
| Mechanical execute→run | Rejected: void run/deferred action incompatible with legacy UI/waiters; detail failure/Sync refresh still wrong. |
| Restartable for all eight | Rejected: Sync persists; Nearby/annual/both Home sides need single-flight; Post route ownership already suffices. |
| Single-flight/drop day | Rejected: B unselected and rapid A→B→A loses intent. |
| Single-flight day + latest desired + relaunch | Possible but rejected: duplicates scheduling/authority, waits for old work and needs more coordination than existing R. |
| Day generation counter besides R | Rejected duplication: admitted request identity associates results/selection; yearlyRevision handles cross-lane dataset invalidation. |
| Annual rebase through automatic new query | Rejected extra query/implicit retry; resolving fresh dataset, including noncacheable empty, suffices to end loading. |
| runAsync coordinator/catch Object→Result | Rejected: joining does not prove own admission and fabricates domain failure from crash; local synchronous waiter preserves independent failures. |
| New R unifying Post event/place detail | Rejected: no actual same-owner retarget, route keys isolate already; unnecessary scope/payloads. |
| New Nearby outcome carrying partial data in Error | Rejected: OpenSpec 1 ordinary allowance already permits VM partial data; baseline UI hides it on failure. |
| Post/Nearby retry button/not-found redirect | Rejected UX/navigation expansion beyond required terminal detail correction. |
| Always post-frame feedback cancelled on every unmount | Rejected F2: loses normal-return snackbar; immediate delivery with live context in terminal window lets global messenger retain it. Only unauthorized pending is revocable. |
| context.read rebinding in didChangeDependencies | Rejected F3: no dependency, may retain A listener; listening Provider.of + identity rebinds without duplicate observations. |
| Cache hit rebuilt from _all | Rejected F5: loses fallback X/changes valid terminal. Hit returns before mutations; annual derivation only on miss/new rebase. |
| Provider B implies router B on existing router | Rejected F6: router captures construction-time A; Screen rebind is local. New app owner needs coherent app/router lifecycle, no new infrastructure here. |
| Day UI based only on completed/deferred isRunning | Rejected F1: endless failure skeleton or A grid under B; use synchronous admission/current request/terminal-retry matrix. |
| Router observing only results/Command.value | Rejected: terminal results precedes sync false, value may not notify runtime failure; results + deferred isRunning cover both. |
| Runtime Sync always nonfatal/converted to domain | Rejected: without timestamp it abandons failed bootstrap or loses crash nature; availability and unexpected outcome stay separate. |
| Interrupt SyncUseCase on dispose | Rejected atomicity/cursor/save risk; VM revokes only presentation/new invocations. |
| Global lifecycle helper for these lanes | Rejected: requested existing patterns, not more foundation; verifiable local cleanup suffices. |

### D8 — Delta consistency and later consolidation

Distinctly named ADDED requirements in command-execution-concurrency/Home. Do not yet rewrite `Only authoritative completion can commit asynchronous data`: OpenSpec 1 MODIFIED remains sole cumulative definition to consolidate. Event day uses pure retrieval/authoritative commit; ordinary lanes respect approved feature-owned exception including Nearby partial data. Search/Map/Category unchanged. Canonical temporal/routing/shell/local-retrieval rules remain binding without policy delta. No sync/archive at this phase. Later cumulative integration remains PR #12 with independent checkpoint per change; planning itself authorizes no commit/push/merge/PR update.

## Regression plan — historical acceptance criteria

These were **future gates at planning time**, not newly executed tests. Subsequent execution is recorded in the apply sections. Controlled Completers, FakeRepository/injected clocks; testWidgets/fake clock for timer/dispatch and actual reporting. No real sleep/polling/microtask-count expectation. Observe executions, selection, content, feedback, URI/release; pumpCommandTurns drives runtime, not product contract.

### Support and suites to reuse

- `test/support/{fake_repositories,fixtures,command_test_support,events_harness,sync_harness,ordinary_view_model_lifecycle_support,sync_use_case_test_support}.dart`; existing pending handlers/recorders. Read real members before extending; no duplicated local fake/store/router.
- `test/ui/event/view_models/event_view_model_test.dart`: annual/day/revision, Home order/retention, midnight/pending batches/manual lane waiters/dispose. `test/ui/event/widgets/components/events_calendar_test.dart` legacy helper :234, relevant modal/screen tests; `test/routing/{events_route_test,home_event_discovery_test}.dart` for actual owners/reloads.
- `test/ui/post/view_models/post_view_model_test.dart`: both detail success/error, between-phase disposal, Nearby order/partial/error precedence. `test/ui/post/widgets/post_screen_test.dart`: Weather replacement/pending, invalid coordinates, no-retry Nearby, stale callback.
- `test/ui/sync/{view_models/sync_view_model_test,widgets/sync_screen_test}.dart`; `test/routing/sync_redirect_test.dart` bootstrap/force/menu/pull, query retention, invalid from/admin/Home reload. `test/domain/use_cases/sync_use_case_test.dart` characterizes unchanged protocol, no new VM protocol mock.
- `test/ui/ordinary_view_model_lifecycle_test.dart`, FlutterMemoryAllocations fixture/probe for disposal identity/reporting restoration; A1 foundation utils. `test/routing/{route_ownership_test,main_navigation_restoration_test,back_navigation_integration_test}.dart`/shell tests for NAV-07/branch retention/predictive back/restoration.
- Before test edits load dart-add-unit-test, test-support-reuse and applicable widget/integration skill; before State/callback edits load async-mounted-context-safety. Planning edits none of those files and needs no new production helper.

### Discriminating test matrix

| ID | Deterministic observable case |
| --- | --- |
| C1 | Every real O lane: never-run neutral, inline run admission/zero I/O before entry; running, Success<void>(null), original domainError, unexpected StateError/TypeError with original stack/report once; value/completed are not equivalent. |
| C2 | Two pending same-lane O runs: one action/initial parameter, no queue; readmission after terminal; reuse foundation runAsync-join test, never treat waiter as own success. Independent lanes do not accidentally exclude each other. |
| E1 | Annual autoload once per owner, success/error/retry/empty success/pending duplicate drop; retain all/revision on failure; calendar markers ordered and correct Rome day. |
| E2 | selectDate changes before pump; query-free cache hit; started A→started B→started A, old A completes first/last and B after final A: only final A commits/outcomes. Same-turn superseded intents may never enter; do not require I/O for each pre-entry discarded intent. |
| E3 | Annual/day both pending in both completion orders; annual revision/rebase nonempty/empty; old fallback neither overwrites nor leaves loading; no extra rebase query; explicit same selection after annual empty falls back; annual-only Home does not start day. |
| E4 | Cacheable fallback empty success, repeat query-free; noncacheable Result.error/handled runtime, equal tap retries; new day never shows old data; failed annual preserves good cache. |
| E5 | Stale day Result.error ignored by UI, stale runtime reported once; disposal before entry/during query/from notify prevents commit/notify. Reentrant B from A notify retains B authority. |
| E6 | Identical shared Future for concurrent requests, one additional pass per batch; clock recorded once per pass/new instant only after external lanes free; both queries get same snapshot across Rome midnight/DST. |
| E7 | Ongoing domain/runtime failure does not skip next; either/both failures, independent retention/empty clears; external ongoing/next pending before pass and next occupied after capture wait without losing query/recapturing clock. |
| E8 | Dispose during manual wait/ongoing/next with coalesced pending: public refresh Future releases without physical completion, no next side/pass, temporary listeners removed; late Result/throw settles privately. Reuse tab/detail/search/category/settings Home-return tests and no popup/rebuild reload. |
| P1 | Valid Event/Place route admits only chosen lookup before frame/deferred I/O; same-owner rebuild no refetch; invalid id/type/inherited category no query. Never read content before completed. |
| P2 | Detail Result.error/runtime → terminal error, no persistent spinner/Weather/Nearby query, report runtime only; newly accepted success recovers content/current target once; no new retry UI. |
| P3 | Pending A→B event/place, including same id/different type; late A success/domain/runtime cannot contaminate B. New Weather owner for same content receives target once; pending/failure clears, stale source detaches. Real NAV-07/predictive-back/restoration retained. |
| P4 | Nearby events→places: both success, either-side failure/other success, both failure (first original Object Exception); VM partial list/UI projection/no “Riprova” retained. Programmatic clear/reload retry after settlement. |
| P5 | Invalid coordinates zero query; equal loadKey rebuild zero query; owner/content/coordinates change before post-frame invokes current target only; captured old onLoad cannot invoke old owner. Shared-widget suite unchanged. |
| P6 | Dispose during events prevents places; during places prevents commit/notify; events runtime stops places, places runtime stays unexpected; already published partial never transfers to replacement owner. |
| S1 | Due constructor admits before first frame/UseCase entry; not-due remains neutral; force true invokes, false not-due skips, false due invokes, schedule rechecked before entry. |
| S2 | Concurrent force true/false during admission/I/O: one sync/no pending pass; admitted result/fatal only, refused request produces no feedback. |
| S3 | No timestamp: domain/runtime stay /sync with retry; timestamp: both nonfatal return; fatal→retry loading→Success/reset→destination. Same Exception over two attempts preserves dedup correctness. |
| S4 | Terminal results while sync true then deferred refresh after false: no early/stuck return; first router frame auto-sync correct, no UI sync listener. |
| S5 | Extend sync_redirect_test: complete detail/search from URI, forced menu/pull, malformed/external/network/recursive/unmatched from→Home, restored idle /sync, admin-return guard; shell/back/restoration green. |
| S6 | All F2.1–F2.8/F3.1–F3.5 below: current delivery before return/visibility after, stale pending revocation, identity dedup/reactive Provider. Normal post-delivery unmount retains global feedback. |
| S7 | Dispose pre-entry zero UseCase; during UseCase late Success/Result.error cannot update fatal/notify/old-owner route; raw throw reported once beyond virtual 50ms without secondary error. Started domain protocol completes without VM intervention. |
| S8 | Existing SyncUseCase suite green for cursor-before-fetch/parallel prepare/atomic commit/rollback/settings-after-commit/overlap/replay; VM tests do not replace guarantees with four imitation writes or cancel phases after disposal. |
| L1 | Seven O plus R: disposal pre-entry/during action/before terminal, success/domain/StateError/TypeError/double dispose; no commit/notify/new phase; original late error/stack global once, expected failures zero global; stale R runtime still reports. |
| L2 | Dispose from terminal results, already idle value listener, VM.notify, never-run/completed; settlement/dispose same turn in both orders and new transition during queued barrier; identity release exactly once after settlement, never during dispatch/pending. |
| L3 | Original upstream assertion fail-loud/cleanup, assertionsAlwaysThrow not lowered; nonterminating Future loses authority without timeout/polling. Statics/handlers always restored; no new skip. |

### Additional F1/F2/F3/F5/F6 remediation gates

At planning time these required future real-foundation tests, controlled Completers/virtual clock without sleep/microtask counts. Reuse actual EventsModal/EventsCalendar and SyncScreen StatefulWidget; isolated VM test insufficient. Preserve D6 sync_redirect_test.dart post-return snackbar assertion.

| Gate | Planned discriminating verification |
| --- | --- |
| F1.1 | Completed A→select B: before B entry, selectedDate/highlight/title B, modal pending/no A grid. Pump consumers directly without incidental parent Consumer rebuild. |
| F1.2 | B Result.error removes skeleton, shows EmptyView.error/“Riprova”, original domainError/no global report/no old data as current. |
| F1.3 | B StateError/TypeError same surface, unexpectedError/original Object+stack report once, no Result.error conversion/persistent skeleton. |
| F1.4 | Retry reads current selectedDate; change selection before retained error callback, ensure old B not restored. Current intent/one necessary query, pending→empty/items, no annual reload/owner recreation. |
| F1.5 | A→B→A with initially completed A and with old pending queries, reverse completions: never show obsolete terminal during admission, only last A identity commits/projects despite equal parameters. |
| F1.6 | Nonempty/empty annual rebase revokes pending fallback, ends grid/empty from new dataset without waiting old Future/extra query. |
| F1.7 | Modal/owner disposed before entry/during query/before terminal: late success/domain/runtime changes no widget/VM, original reporting once/no post-dispose notifier. |
| F2.1 | Preserve nonfatal→original URI (Home/detail) test with snackbar **actually visible after return**, one delivery. Never remove assertion to pass. |
| F2.2 | Nonfatal runtime same navigation/snackbar after return, original Object/stack global once/distinct unexpectedError. |
| F2.3 | Two admitted attempts observed by current Screen fail with same Exception, reopen sync if needed: one feedback each by snapshot identity, no execution from busy refusal. |
| F2.4 | Harmless rebuild/repeated notify/same-owner didChangeDependencies duplicates no listener/pending/snackbar. |
| F2.5 | Admit retry before unauthorized build-safe pending callback for already terminal reconciled owner: old feedback zero, new terminal still reportable. Normal terminal delivers immediately without depending on callback. |
| F2.6 | A→B with unauthorized A pending: reject A even before delayed didChangeDependencies; B may publish own feedback, no A context read after unmount. |
| F2.7 | Unrelated navigation/unmount before authorization: old callback performs no actions/State.context/widget/Provider reads; normal post-authorization return retains messenger snackbar. |
| F2.8 | Fatal domain/runtime stays /sync with error/“Riprova”, no nonfatal snackbar. |
| F3.1 | Local Screen gate, no router claim (F6.1): mount SyncScreen with Provider.value A, replace B preserving **same State identity**; listening dependency detaches A/attaches B, ignores late A. |
| F3.2 | Already terminal B success/fatal/nonfatal projects body without run B; nonfatal build-safe feedback at most once if still current/mounted. |
| F3.3 | Same-owner harmless rebuild/dependency changes do not reset dedup/double attach/new feedback. |
| F3.4 | Provider A→B before pending A callback: no A feedback, current B snapshot alone has presentation authority. |
| F3.5 | Unmount actual State: detach all listeners from last owner/invalidate pending; late results no effect, do not remove normal-return feedback already delivered. |

### F5 — Cache tests: state, order, Future and projection

Five cases extend existing Event VM/modal tests with actual Commands, separate annual/fallback Completers and virtual clock. Query counts alone are insufficient: inspect byMonth, selectedDate/marker behavior via VM contracts, results sequence and actual modal grid/empty/error. No production test-only API; verify markers through cache/refetch behavior and crossed revisions.

| Gate | Controlled setup/order | Observable result/notifications and discriminator |
| --- | --- | --- |
| F5.1 nonempty fallback | Annual bootstrap Success([]); select A, hold getByDate(A) D1, release Success([X]) belonging to A. Observe settled VM/results/UI; select A again at same revision. | D1 yields byMonth=[X]/completed/grid X; second A preserves X and identical request/terminal with no query/admission/VM notify/pending. Reject implementation counting one query but overwriting `_byDate` with `_all`-derived []. |
| F5.2 empty fallback | Annual []; A pending D1→Success([]), observe terminal/reselect without new year. | Skeleton→current EmptyView/completed; cacheable success-empty, second A stays empty without refetch/notify/loading. Not error/neutral/skeleton. |
| F5.3 annual rebase | Establish F5.1 X at r; start loadAll held Y2; during Y2 reselect A, preserving X/cache r. Release Y2 Success([Y]) for A, variant Success([]), separate Result.error. | Success r+1 replaces X with Y/grid or []/empty without fallback query; day terminal request r+1, markers rebuilt only nonempty. Explicit A after annual empty may query; after annual nonempty retains Y/no query. Annual failure retains X/cache r without derivation. Observe commit/rebase VM notification, no X restored as r+1-valid. |
| F5.4 obsolete completion | Hold D_old(A,r); admit B/final A with D_new→[X], then D_old→[OLD]. Cross-lane variant annual r+1→[Y] before old release; repeat old domain/runtime error. | Old completion changes no current content/marker behavior/request/terminal/selection/grid/empty/error and emits no stale commit notification. Old runtime reports once without stale UI. Repeated current selection retains valid X/Y, never OLD; A→B→A identity-based. |
| F5.5 failure/retry | Annual []; A D1→Result.error(E), then same selection/current “Riprova” starts D2; no error-derived cache hit. Release Success([X]) or Success([]); variant D1 handled runtime. | Error surface/original E/no domain report; retry new intent/new query/skeleton without annual reload, then grid X/terminal empty. Only D2 Success marks cache; later A no refetch/data loss. Distinct runtime/report once; verify error→pending→success, not only counts. |

### F6 — Ownership tests: separate local and end-to-end gates

- **F6.1, local (refines F3.1–F3.5):** actual SyncScreen/existing widget harness, Provider A→B preserving State identity; do not claim B properties with router retaining A. Non-due owners/controlled Completers, late A notifications/already terminal B. Verify A detach/B attach once, B UI/no rebind sync, invalid A pending/no stale or duplicate snackbar/final detach. Widget Scaffold/MaterialApp suffices, no second route implementation. Does not prove router refresh/redirect rebind.
- **F6.2, coherent end-to-end:** reuse buildSyncRouterApp/buildRealSyncApp/SyncRestorationFixture/sync_redirect_test. Same A instance to real router/Provider; controlled Futures verify bootstrap→/sync, no-cache fatal→retry, force/schedule/duplicate/completion→valid from with current post-return feedback. Theme test retains router/owner A through harmless rebuilds. Restoration/new session detaches/disposes old app/router lifecycle, creates B fixture/router/Provider; B drives bootstrap/fatal/retry/return, late A cannot move new URI or produce B UI/feedback. No MoliseIsApp edit/dynamic router to satisfy gate.

Targeted tests prove observable differences/failure modes, not internal timer counts. testOwnerUI applies only to actual owners requiring virtual cleanup; do not indiscriminately convert all suites.

## Risks / Trade-offs

- [Deferred Event public snapshot] → isRunningSync barrier + request identity, F1 terminal/retry matrix, direct modal/calendar VM/results observation; barrier alone misses false-before-terminal window.
- [Fallback erased by annual-derived empty] → hit returns before any mutation, retaining `_byDate` even with empty `_all`; invalidate markers on miss/new revision, forbid stale commit. F5 checks data/UI beyond refetch counts.
- [Event cache data race] → R handles A→B→A, revision preserves cross-lane invalidation; annual empty/nonempty rebase in both orders. Obsolete physical query completion does not release current cache.
- [Coalescing/listener leak] → register waiter before final check, idempotent finish/revoke; public Future releases even with blocked physical work. No starvation-freedom promise for arbitrary direct callers.
- [Post late content/false success] → success-only content/Weather projection, explicit terminal error. Independent detail lanes remain on one owner, but route contract uses one; arbitrary cross-lane retargeting outside scope.
- [Nearby partial/UI mismatch] → preserve VM data, aggregate outcome and Post projection separately; do not incidentally extend shared widget's partial UX.
- [Sync return loses feedback] → authorize/deliver current terminal with live context before false; global messenger retains after redirect. Unauthorized build-safe pending revocable, no post-unmount call; existing F2.1 remains gate.
- [Screen/router owner confusion] → F3 local lifecycle; F6 separates widget rebind from end-to-end same router/Provider owner. No implicit Provider B/router A support/main refactor.
- [Unobserved Provider owner] → listening Provider.of in didChangeDependencies plus identity attach/detach; Consumer body/read alone insufficient. F3 exercises same State.
- [Sync routing order] → results + deferred isRunning wake, isRunningSync admission, fatal classification before consumers. Cover pre-pump startup/terminal before false.
- [No-cache Sync runtime] → fatal availability does not normalize error; generic text/retry preserve recovery/global reporting once. Timestamp conservative proxy, not physical-cache certification.
- [Sync disposal/persistence] → no new invocation after revoke, already-started UseCase completes own protocol; VM promises no remote cancellation/rollback.
- [command_it 9.5.2 late throw] → no early disposal, CL/wrapper retain private settlement; infinite Future can retain resources, approved known limit.
- [Unconsolidated cumulative plans] → read OpenSpec 1/2 deltas with canonical, no concurrent merge/requirement rewrite. Strict validity proves neither design correctness nor apply approval.

## Migration Plan — historical

Apply required independent review and separate authorization. Work only from persistent B0.1 worktree/dedicated branch; repeat preflight/baseline comparison, characterize discriminating tests, implement each surface in tasks.md order, then aggregate gates. No data migration/deploy/backend. Local rollback of future cohesive diff must preserve others' work without destructive reset. Planning did not update cumulative PR.

### Measurable acceptance criteria for the subsequent apply

1. Eight properties migrated: seven O/one R; no legacy import/type/execute on three VMs/relevant consumers/tests; no other Command/foundation/policy/query/persistence/dependency change.
2. All applicable C/E/P/S/L and F1.1–F1.7/F2.1–F2.8/F3.1–F3.5/F5.1–F5.5/F6.1–F6.2 demonstrated with deterministic real-Command tests; no new skip/weakened test; unchanged UseCase protocol/Nearby presentation.
3. Comparable analyzer replay: exactly 18 target identities removed, 87 residual INFO with same identities/multiplicity, zero warnings/errors/new diagnostics; logs/exits/versions recorded.
4. Targeted/full **Flutter suite** actually green (`flutter test --no-pub`, identified pre-existing skips only), then strict OpenSpec/diff/whitespace including untracked. Historical OpenSpec 2 count 2.480 does not satisfy this gate.
5. Artifacts reconciled to actual evidence and independent adversarial implementation review; schema validity alone no integration readiness. No implicit commit/push/merge/archive.

### Planning status at that phase

Proposal/design/tasks/two deltas were documentary output with all future tasks unchecked. No material question deferred to executor: annual rebase/Sync runtime/Nearby partial/Post retry were explicit proposed decisions for review, not pre-existing facts. No apply/full Flutter suite ran during planning. Actual checks/final integrity follow in documentary closeout.

### Original documentary closeout — 2026-10-21 (historical, before F1–F4 review)

- `openspec status --change migrate-content-view-model-commands --json`: proposal/specs/design/tasks present, planning complete. CLI isComplete meant artifact availability, not implementation; all 27 apply tasks unchecked.
- `openspec validate migrate-content-view-model-commands --strict --no-interactive`: **valid**, exit 0, no warning. Eight added concurrency requirements/two Home requirements, no canonical requirement rewritten.
- `git diff --check`/`git diff --cached --check`: exit 0. Python checked untracked artifacts for final newline/no trailing whitespace. Empty tracked/staged name lists; exactly six untracked change files, no other worktree change.
- HEAD e3d9d891 still detached; final main/four-other-worktree checks clean, no mutations from this execution. PR read only, no commit/push/merge/update.
- B1 read-only analyzer: 105 INFO/18 targets reconfirmed, zero warnings/errors. No Flutter suite/implementation/test written in planning.

**Historical READY FOR INDEPENDENT PLAN REVIEW, superseded by F1–F4 review/remediation below:** complete valid artifacts/explicit testable decisions, no baseline blocker/unresolved execution question; D2/D6 proposals/D5 limits still needed independent adversarial assessment before apply. This did not claim independent approval or implementation/integration readiness.

### F1–F4 remediation — closeout before F5/F6 review

Authorization covered documentary edits/local relocation, no apply. Proposal/design/tasks/concurrency delta changed; `.openspec.yaml`/Home delta byte-identical to original manifest because F1–F3 do not alter Home contract. Eight concurrency requirements retained (two strengthened without renaming, eight net scenarios added), two Home requirements; no new capability/OpenSpec 1 MODIFIED rewrite. Five groups/**27 future unchecked tasks**.

| Finding | Planning resolution | Gates/traceability |
| --- | --- | --- |
| F1 MEDIUM | D2 full modal matrix, sync barrier/request identity, selection/admission order, current retry/direct calendar observation | F1.1–F1.7; Calendar selection delta; tasks 2.2/2.3/2.6/5.1 |
| F2 MEDIUM | D6 current snackbar delivery with live context before normal return, global messenger retention, revocable stale pending/attempt dedup | F2.1–F2.8, original sync_redirect assertion retained; Sync return delta; tasks 4.3/4.4/5.1 |
| F3 LOW/MEDIUM | D6 listening Provider.of/identity, detach/attach/terminal reconciliation without run | F3.1–F3.5 actual SyncScreen State; Sync return delta; tasks 4.4/5.1 |
| F4 operational | Git move of same worktree/dedicated local branch, no recreation/publication | B0.1 HEAD/index/manifest/6/6 hashes identical at move; other worktrees preserved |

Final read-only adversarial plan/source review, including separate reviewer, found no remaining material F1–F4 finding across all twelve requested conditions. This remediation check did not replace user's later independent re-review/authorize apply. New UI/lifecycle guarantees remained future tests, not observed Dart success.

Repeated persistent-worktree checks: `openspec status --change migrate-content-view-model-commands --json` exit 0/planning complete; strict validation exit 0/valid/no warning. YAML parsed by Ruby/Psych (`ruby --disable-gems -ryaml`, exit 0); Python checked six untracked files for UTF-8/newline/trailing whitespace/fences/headings/requirements/scenarios/task count; tracked/staged diff checks exit 0. Markdown structural checks were not visual rendering/future UI proof.

Integrity: HEAD e3d9d891/persistent B0.1 branch, zero extra commits, empty tracked diff/index, six expected untracked artifacts, no Dart/test/other file edits. Other-worktree HEAD/branch/status equal preflight. PR read only/open/Draft at checkpoint; no commit/push/PR/merge/rebase/archive/canonical sync. No analyzer/Flutter rerun during remediation: B1 historical **105 INFO / 18 targets**, future **87 INFO**, zero new diagnostics/full suite still apply gate.

**Historical READY FOR INDEPENDENT PLAN RE-REVIEW**

### F5/F6 remediation — historical planning status

Phase preflight: persistent B0.1 worktree/branch at e3d9d891, empty index/tracked diff, six reviewed artifacts inventoried with pre-edit SHA-256. Old `<temporary-worktree>` absent/unregistered. Read-only PR check open/Draft at authorized head. Four other worktrees clean with prior HEAD/branch/status; no Git mutation in this phase.

**F5 resolved in plan:** hit returns before mutation/derivation, preserves `_byDate` fallback/current terminal including empty; miss/new revision explicitly invalidates. D2/Calendar delta/tasks 2.2/2.3/2.6/5.1/F5.1–F5.5 verify data/outcome/notification/UI. No multi-day cache/new state layer.

**F6 resolved in plan:** D6/Sync return delta/tasks 4.3/4.4/4.6/5.1 distinguish local F3 lifecycle from F6.2 end-to-end router. Router retains constructor owner; new session requires new coherent app/router/Provider lifecycle. No dynamic main/router rebind infrastructure.

Only proposal/design/tasks/concurrency delta changed. Metadata/Home delta unchanged from prior manifest; no new capability, eight Commands (seven O/one R), five groups/27 unchecked tasks. F1–F4 verdicts above are historical, not premature F5/F6 closure. No apply/Dart/test/new runtime result.

F5/F6 documentary checks from persistent worktree: strict valid exit 0/no warning; Ruby/Psych YAML exit 0; all six untracked artifacts UTF-8/newline/whitespace checked; 27/27 unchecked tasks/five groups; tracked/staged diff checks exit 0. Six-file pre/post hashes captured; metadata/Home delta byte-identical. Temporary comparison manifest `<evidence-dir>/os3-f56-integrity.json`, finalized after last edit to include final design hash without recursive self-hash. That ephemeral file is not tracked or promised accessible; recorded historical comparison remains a provenance claim, not independently recoverable raw evidence.

Focused read-only adversarial source/plan review with separate reviewer found no remaining material F5/F6 issue; gates/boundaries aligned with first two OpenSpecs. Proposed tests remained future: no flutter test/flutter analyze rerun/new runtime claim. Baseline 105 INFO/18 targets/87 target unchanged. No code/test/dependency/backend/canonical/other-worktree changes, empty index/no commit/push/PR update/merge/archive/sync.

**Historical READY FOR INDEPENDENT PLAN RE-REVIEW** — still subject then to independent final verification/separate apply authorization.

## Authorized apply — 2026-10-23

User authorized all 27 tasks without commit/push/PR update/archive/canonical sync at this phase. Planning/remediation above is historical; following evidence records actual apply executions. Persistent B0.1 branch/worktree, HEAD e3d9d891; initially empty index/tracked diff, six artifacts identical to approved F5/F6 hashes. Other-worktree inventory captured/all clean. PR #12 open/Draft at same codex/migrate-legacy-commands checkpoint. No fetch/checkout/new commits incorporated.

**Evidence provenance:** filenames/`<evidence-dir>` below identify original ephemeral local logs, not tracked or guaranteed accessible. Outcomes/hashes are preserved as historical reports; missing raw files cannot be recovered or independently hash-checked from this narrative. Sources/tests remain inspectable in published checkpoint `1f3753b10c18061c6655cb32d078bf93aff1b05e`; replay is a separate execution. Earlier artifact hashes describe original revisions, not this reconciliation. No historical test count is a new consolidation run.

### Group 1 — Preflight, B1 and characterization

Fresh B1 via direct Dart 3.13.4 on git archive HEAD with adapted temporary package_config, cwd persistent worktree, argv `<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <evidence-dir>/baseline`: raw exit 0, 105 INFO, zero WARNING/ERROR, empty stderr. Same 18 B1 targets; all 87 nontarget identities retained in baseline.stdout machine ledger. Flutter `--version --machine`: 3.47.5/framework 6a19cca/Dart 3.13.4; unchanged command_it 9.5.2/listen_it 6.0.0. No pub get/upgrade; only ignored .dart_tool metadata copied from existing resolved dependencies for worktree tests.

Pre-production characterization: `flutter test --no-pub` selecting Event VM/calendar, Post VM/screen, Sync VM/screen and sync_redirect_test: exit 0. Full historical log `<evidence-dir>/characterization.log`. Cold start prepared ignored Flutter outputs, no test/dependency resolution failure.

Reuse audit: fake_repositories pending Futures/handlers/model fixtures; command_test_support reporting restoration/pumps/virtual owner teardown; ordinary_view_model_lifecycle_support identity probes; events_harness/sync_harness/SyncRestorationFixture/SyncUseCase fixtures. No new mocking framework. Ordinary D5/Category D8 confirm local cleanup; resolved source confirms synchronous results before false/reporting, deferred action/50ms teardown. Result/test skills do not replace required domain/runtime distinction; no blanket catch Object→Result/analyzer suppressions.

### Group 2 — Event verified

Three ordinary/one restartable lanes implemented without foundation edits. selectDate first validates cache hit, including fallback X absent from all/empty Success; immutable request identity/revision and query-free annual rebase. Modal/calendar directly observe VM/results: stale barrier, explicit domain/runtime terminal/“Riprova” for current date. Home retains coalescing/shared snapshot, waits external lanes, immediately releases public waiters on disposal.

`flutter test --no-pub test/ui/event test/ui/explore/widgets/explore_screen_test.dart test/routing/events_route_test.dart test/routing/home_event_discovery_test.dart`: exit 0, 84 passed. New F1/F5 event_command_migration/event_day_migration cases cover UI content/annual rebase/stale completions/retry/direct calendar/Home next occupied after capture/reentrancy/dispose. Targeted Event/consumer/test/support/route analyzer exit 0/no diagnostics. `flutter test --no-pub test/ui/ordinary_view_model_lifecycle_test.dart`: exit 0, 129 passed after existing support extended to three Event O lanes; late success/domain/runtime/assertion, barrier/settlement/identity disposal verified. Extended-support analyzer exit 0/no issues. Only intended files formatted; whitespace diff clean.

Initial red runs exposed deferred-entry test adaptations and a newly introduced wrong Builder signature, corrected before Post. Home tests now wait actual query entry before pending/unmount assertions; no coalescing/continuation assertion removed. Synthetic-stack tests disable command_it detailedStackTraces locally and restore it, distinguishing original forwarding from upstream Chain reconstruction. Historical logs `<evidence-dir>/event-final-green.log`, event-analysis-green.log, event-lifecycle.log are temporary, not durable prerequisites.

### Group 3 — Post verified

loadEvent/loadPlace/loadNearContent migrated to ordinary lanes; route still `(id,type)`, admits only selected detail. PostScreen observes results, no late content read before current Success, explicit generic terminal failure without new retry. Weather results listeners detach on replacement/dispose; Nearby retains loadKey/coordinates/owner, events→places, VM partial data/first error/aggregate-failure projection without retry.

`flutter test --no-pub test/ui/post test/routing/route_ownership_test.dart test/routing/route_parameter_redirect_test.dart test/ui/core/ui/content/nearby_content_horizontal_list_test.dart`: exit 0, 160 passed/no skips. New cases: Event/Place × domain/StateError/TypeError terminal/recovery/Weather clear; every Nearby partial/double-error outcome, programmatic retry/runtime at both stages; same id/new type/late success/domain/runtime; query-free rebuild/invalid URI; reentrant notify disposal. Targeted Post/core_routes/test machine analyzer exit 0/empty stdout+stderr; intentional formatting/clean whitespace. Weather VM/shared Nearby unchanged.

Existing lifecycle support extended to three Post lanes: common matrix exit 0, 165 passed (post-lifecycle-green.log), including late throw/assertion/private settlement beyond virtual 50ms teardown, identity release once/no later Post phase after revoke. Test-only sentinel distinguishes initialized/unresolved public late slot without production API. Event self-review aligned pre-entry guard with D5 local unavailable; late annual test establishes physical entry before disposal, while pre-entry zero-query separately covered. `flutter test --no-pub test/ui/event test/ui/ordinary_view_model_lifecycle_test.dart` replay exit 0, 231 passed. Temporary logs `<evidence-dir>/post-final.log`, post-analyzer-final.json, event-post-lifecycle-guard-green.log.

### Group 4 — Sync verified

Single ordinary bool lane, fatal observer before autoload/pre-entry guard; force/schedule/single-flight unchanged. Router observes results/deferred isRunning and sync admission, retaining construction owner. SyncScreen listening Provider.of in didChangeDependencies/identity rebind; current terminal delivered globally with live context before normal return, revocable pending reconciliation/owner-snapshot dedup. No main/SyncUseCase/foundation/protocol/backend edit.

`flutter test --no-pub test/ui/sync test/routing/sync_redirect_test.dart test/domain/use_cases/sync_use_case_test.dart test/domain/use_cases/sync_use_case_objectbox_test.dart test/routing/geo_map_route_test.dart`: exit 0, 131 passed/one pre-existing GeoMap root Back skip (upstream 18.0.2). New S1/S2/S3 cases: direct runtime/parallel-prepare wrapper, fatal retry/runtime feedback after return, same Exception across attempts, Provider rebind preserving State, terminal B/pending retry/replacement/unrelated navigation. Original post-Home-return snackbar assertion retained/green. Targeted Sync/router/Explore/support/test machine analyzer exit 0/empty stdout. Common lifecycle matrix exit 0, 177 passed, covering all seven new O lanes including previously verified three Event lanes. Cursor raw late throw/assertion/private teardown retain identity/reporting; invoked UseCase indivisible.

Environment: initial ObjectBox run failed missing dylib, not regression; DYLD_LIBRARY_PATH insufficient for hardened Flutter process. Only existing native library copied from primary checkout to ignored lib/libobjectbox.dylib; identical SHA-256 1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751, unchanged dependency/version/original source. Replay including real ObjectBox tests green. Historical evidence `<evidence-dir>/sync-verification.json`, sync-targeted-green.log, sync-lifecycle-green.log, native-runtime.json.

Independent read-only Event/Post then Sync/crossfeature review found no confirmed material finding. Provider-pending test limit: Element.update under BuildOwner.buildScope exercises replacement/rebind before feedback callback; buildScope also drains dirty rebuilds. It proves A feedback suppression on retained State, not separately the narrower Provider B/State-field-still-A interval. Production context.read current-Provider check exists/reviewed; test name/comment corrected to avoid overclaiming.

### Group 5 — Final integration, 2026-10-23

- Complete aggregate foundation/Event/Post/Sync/lifecycle/Explore/Nearby/routing (back/shell/restoration) and SyncUseCase/ObjectBox gate: exit 0, 679 passed/four pre-existing skips. Historical argv/cwd/exit/duration `<evidence-dir>/aggregate.json`. First invocation used nonexistent scaffold_shell_test path, sole loading failure; corrected invocation without test edit/removal. Real routing/back/restoration retains shell coverage. Failed attempt log aggregate-invalid-path.log preserved historically.
- Explicit S4 probe added after aggregate: success/domain/runtime results notify terminal while admission true, later deferred isRunning notifies sync false/terminal snapshot. Current Sync VM suite exit 0, 21 passed (sync-order-green.log). Listener assertion uses expectSync; initial expect violated pump guard, corrected without weakening condition. Independent probe review found no material issue.
- Full final-content `flutter test --no-pub`: exit 0, **2.619 passed, zero failures, six pre-existing skips**, 101,08 seconds. Flutter 3.47.5/Dart 3.13.4, persistent worktree, HEAD e3d9d891. Historical metadata/log `<evidence-dir>/full.json`, full.log. This was a new apply execution, not OpenSpec 1/2 evidence; it is now historical, not a new reconciliation run.
- Six retained skips: three StateError variants in command_it 9.5.2 late-dispose characterization (command_it_disposal_behavior_test); documented GeoMap root Back/go_router 18.0.2; two opt-in local E2E all_day_pipeline/external_event_token_pipeline, MOLISE_ALL_DAY_LOCAL_E2E/MOLISE_EXTERNAL_TOKEN_LOCAL_E2E not enabled. No new skip/weakened assertion.
- Final formatting only 32 intentional Dart files, exit 0/no further changes. After S4, B1 replay with same SDK/machine argv/flags/defaults/temporary package metadata: **exit 0, 87 INFO, zero WARNING/ERROR, empty stderr**. Exactly 18 targets removed; all 87 nontarget file/rule/message/multiplicity identities match despite line shifts; missing/new empty. Historical baseline/final metadata/ledgers `<evidence-dir>/{baseline.json,baseline-ledger.json,final.json,final.stdout}`. No separate flutter analyze claimed/configuration/suppression introduced.

### Apply self-review and independent review

Checked admission/reentrancy/settlement, A→B→A, fallback cache/annual rebase/failure retention, Home waiters/clock, Post detail/Weather/Nearby, Sync bootstrap/redirect/snackbar/Provider-router ownership, late errors/cleanup. Execution corrections: D5 Event pre-entry unavailable guard; pending annual/Home tests establish actual query entry; required terminal projections; stack tests respect upstream Chain; ParallelWaitError versus direct throw documented; ObjectBox native runtime prepared without new version. No architectural deviation/foundation/UseCase/repository/backend change required.

Separate read-only reviewer inspected Event/Post, Sync/crossfeature, then S4/reconciled artifacts: **no remaining material finding**. Provider/buildScope test limitation explicit in group 4, never claimed proof of narrower interval. Does not replace later user-requested independent code review. Remaining D5 limits: noncancelable physical work retains private resources until settlement; no timeout/early teardown hides upstream issue.

### Historical final manifest and Git constraints

HEAD/branch unchanged from apply preflight, empty index. Expected inventory: 30 tracked edits (11 production/15 tests/4 support), two new Dart tests/six untracked OpenSpec artifacts. No extra change artifact/canonical/other-change/main/dependency/backend/SyncUseCase/WeatherVM/shared Nearby/foundation edit. lib/utils/command.dart retained. YAML/two deltas byte-identical to approved revision; only proposal/design/tasks reconciled with apply. Native runtime/SDK metadata ignored, separate from source diff.

Historical tracked/untracked inventory, six-artifact pre/post SHA-256/index/HEAD/branch/other-worktree comparison in `<evidence-dir>/final-integrity.json`, not guaranteed accessible. Old temporary worktree absent/unregistered, other worktrees same HEAD/branch/status as preflight. PR #12 then open/Draft at e3d9d891, unchanged; no commit/push/merge/PR update/archive/canonical sync in that phase. Subsequent publication is recorded at the top.

Closeout ran strict OpenSpec/YAML/explicit UTF-8/newline/whitespace including six untracked files/tracked+staged diff checks. All 27 tasks completed only after their gates. **Historical READY FOR INDEPENDENT CODE REVIEW**, without implied publication/integration authorization.

Historical tracked edits:



- `lib/routing/core_routes.dart`
- `lib/routing/router.dart`
- `lib/ui/event/view_models/event_view_model.dart`
- `lib/ui/event/widgets/components/events_calendar.dart`
- `lib/ui/event/widgets/components/events_modal.dart`
- `lib/ui/event/widgets/events_screen.dart`
- `lib/ui/explore/widgets/explore_screen.dart`
- `lib/ui/post/view_models/post_view_model.dart`
- `lib/ui/post/widgets/post_screen.dart`
- `lib/ui/sync/view_models/sync_view_model.dart`
- `lib/ui/sync/widgets/sync_screen.dart`
- `test/routing/events_route_test.dart`
- `test/routing/geo_map_route_test.dart`
- `test/routing/home_event_discovery_test.dart`
- `test/routing/route_ownership_test.dart`
- `test/routing/route_parameter_redirect_test.dart`
- `test/routing/sync_redirect_test.dart`
- `test/support/events_harness.dart`
- `test/support/fake_repositories.dart`
- `test/support/ordinary_view_model_lifecycle_support.dart`
- `test/support/sync_harness.dart`
- `test/ui/event/view_models/event_view_model_test.dart`
- `test/ui/event/widgets/components/events_calendar_test.dart`
- `test/ui/event/widgets/components/events_modal_test.dart`
- `test/ui/event/widgets/events_screen_test.dart`
- `test/ui/explore/widgets/explore_screen_test.dart`
- `test/ui/post/view_models/post_view_model_test.dart`
- `test/ui/post/widgets/post_screen_test.dart`
- `test/ui/sync/view_models/sync_view_model_test.dart`
- `test/ui/sync/widgets/sync_screen_test.dart`

Historical untracked source/planning files:

- `openspec/changes/migrate-content-view-model-commands/.openspec.yaml`
- `openspec/changes/migrate-content-view-model-commands/design.md`
- `openspec/changes/migrate-content-view-model-commands/proposal.md`
- `openspec/changes/migrate-content-view-model-commands/specs/command-execution-concurrency/spec.md`
- `openspec/changes/migrate-content-view-model-commands/specs/home-ongoing-events/spec.md`
- `openspec/changes/migrate-content-view-model-commands/tasks.md`
- `test/ui/event/view_models/event_command_migration_test.dart`
- `test/ui/event/widgets/components/event_day_migration_test.dart`
