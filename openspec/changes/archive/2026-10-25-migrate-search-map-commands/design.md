# Design

## Context — historical planning baseline, 2026-10-23

See `proposal.md` for motivation/scope. GitHub `get_pr_info(xmattjus/moliseis,12)` reported open, draft=true, merged=false, branch `codex/migrate-legacy-commands` at `1f3753b10c18061c6655cb32d078bf93aff1b05e`. There was no advance to reconcile. The three cumulative commits were `9d17d224` (simple), `e3d9d891` (category), `1f3753b1` (content), with 27/27, 21/21 and 27/27 tasks complete. Reading artifacts/commits did not repeat their historical verification.

The dedicated historical checkout is denoted `<worktree>`, branch `codex/plan-migrate-search-map-commands`; initial/authorized HEAD was `1f3753b10c18061c6655cb32d078bf93aff1b05e`. Branch/path were free before creation. Repository AGENTS.md, openspec-propose and `schema: spec-driven` were read; no nested AGENTS was found. OpenSpec context/list resolved that worktree as local root. Existing checkouts were preserved.

The initial primary and detached auxiliary checkouts were at `ee60777`; simple/category/content checkouts were at `9d17d224`/`e3d9d891`/`1f3753b1`. All were clean, including untracked files, with empty indexes. Final checks compared HEAD/branch, status, diff and contents. New worktree/ref registration was the sole authorized Git administrative change.

### Historical analyzer baseline

After successful `flutter pub get --offline` (cache/ignored files only, unchanged lockfile), `dart analyze --format machine` exited **0**, with **87 INFO / 0 WARNING / 0 ERROR**, matching the published baseline. This was not a green `flutter analyze` or CI claim. Historical stdout was `<evidence-dir>/search-map-analyzer-machine.txt`, stderr empty. These temporary logs are not tracked or established as currently accessible; this document preserves their reported results. Reproduction requires the checkpoint and matching resolved dependencies. No Flutter test ran during initial planning.

All 21 targets had severity INFO, type LINT, code `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`, with legacy Command0/Command1 deprecation messages. Baseline coordinates (line:column:length):

| Relative file | Diagnostic instances |
| --- | --- |
| lib/ui/search/view_models/search_view_model.dart | 23:25:15, 23:32:8, 24:24:15, 24:31:8, 31:30:15, 31:37:8, 56:15:8, 61:15:8, 72:15:8 |
| lib/ui/geo_map/view_models/geo_map_view_model.dart | 44:18:15, 44:25:8, 51:18:15, 51:25:8, 53:29:15, 53:36:8, 54:24:15, 54:31:8, 77:15:8, 80:15:8, 81:15:8, 82:15:8 |

The planned gate was 87→66 INFO: remove exactly these 21 targets and preserve non-target identities/multiplicities. Normalize roots only; map moved lines by symbol/message without hiding differences. No analyzer suppressions/configuration changes. Seven was the number of target Commands in these surfaces; 66 other INFO remained for later changes.

### Baseline source evidence

Line references identify the immutable planning checkpoint, not current line positions.

| Source | Observed baseline contract |
| --- | --- |
| `lib/ui/search/view_models/search_view_model.dart:21–49,103–158` | Three legacy Commands; automatic bootstrap; optimistic add/remove; load replaces the entire list; guards only after await; disposal destroyed only results/suggestions. Add excludes known category labels and deduplicates case-insensitively; remove uses exact case and rollback appended. |
| `lib/ui/search/widgets/components/app_search_anchor.dart:169–175,177–229,253–317,352–358` | Submit adds history, closes popup and navigates; suggestion/history/category chips add, delete removes. Empty input shows history. Popup may outlive State; cached history, mounted guards, timer/controller ownership and existing deferred chip reset matter. |
| `lib/domain/repositories/search_repository.dart:5–21`; `lib/data/repositories/search_repository_impl.dart:72–96,213–250` | getAllAsync preserves box order; add is case-insensitive, remove exact-case. Expected infrastructure Exceptions become logged Result.error. No inter-call serialization contract; repository/ObjectBox unchanged. |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:41–82,117–176,230–282` | Four legacy Commands; independent Events/Places bootstrap; initial all-known/all-types filters. Setters retained caller Set aliases, compared by value and cleared both lists; reload queried Events→Places or selected type, with no I/O for empty types. Child errors did not become setter failures. |
| `lib/ui/geo_map/widgets/geo_map_screen.dart:424–450,525–535` | Markers observed both legacy completions, rendering Events→Places. Selector used ObjectKey(owner); no consumer needed setter Command state/result. |
| `lib/ui/geo_map/widgets/geo_map_bottom_sheet.dart:105–175` | Projects mode/Search/Post/Nearby; owns no marker loading state. |
| `lib/domain/use-cases/geo_map_use_case.dart:12–45` | getAllEvents→EventRepository.getByCurrentYear; getAllPlaces→PlaceRepository.getAll (default byName). Separate direct-model fetches; preserve order/time filtering, no marker getById. |
| `lib/routing/router.dart:326–360,494–497`; `test/routing/geo_map_route_test.dart:856–906` | Per-route Search owners with real bootstrap/disposal; Map retains owner and semantic identities. |
| `lib/ui/category/widgets/category_content_and_type_selection.dart` and its tests | Per-field draft applies on permitted route completion (Save/Back/barrier/drag), with no Save/Cancel distinction. Empty→all requires mounted/current session; replacement invalidates old sessions. |

The complete target inventory was Search.addToPastSearches, Search.loadPastSearches, Search.removeFromPastSearches, Map.loadEvents, Map.loadPlaces, Map.setSelectedCategories and Map.setSelectedTypes. Search add/remove were independent optimistic repository lanes with late guards and undisposed legacy Commands; load could overwrite mutations. Map setters returned success despite child failures. Intended destinations were a private ordered Search writer, encapsulated ResultCommand reader, one restartable loadMarkers and synchronous immutable setters. No production history-result listener was found.

### Foundation and cumulative specifications

`pubspec.lock:228–234` resolved command_it **9.5.2**. Local `command_it.dart:312–386,420–446,799–870,920–1024`, `lib/utils/{command,result_command,restartable_command,command_configuration}.dart` and foundation tests were inspected. run raises isRunningSync inline, defers action entry one zero-duration turn and rejects duplicates; runAsync may join and cannot establish admission. Result.error remains data; raw Object/stack uses globalHandler; assertions remain fail-loud. Do not reproduce legacy Object→Error Result + FlutterError conversion. Debug names are constant and contain no query/parameters.

Ordinary results notify synchronously; only UI isRunning is deferred. Restartable envelopes/public results are deferred, authority revokes immediately and physical I/O is not cancelled. Restartable actions do not commit after await. command_it.dispose defers teardown 50ms and has a known late-throw limitation. Ordinary reader/private writer cleanup follows Category/Content: await private settlement, leave dispatch/reporting, then dispose, even if logically idle. No generic utility; runAsync completion or sync false alone proves neither success nor completed dispatch.

OpenSpec 1's ordinary MODIFIED requirement permits optimism/progressive results beyond the unsynchronized completion-only canonical wording. Category supplies synchronous setter/snapshot and owner-keyed-dialog precedent; Content supplies lifecycle, deferred-entry and terminal-authority rules. This delta adds requirements without replacing that MODIFIED. Future canonical synchronization must apply OpenSpec 1 before Search ordinary additions; until then read canonical plus cumulative deltas together.

`openspec/specs/local-content-retrieval/spec.md` mixed search, independent results/suggestions, short-query, ordering and atomicity contracts remain unchanged. `harden-geo-map-semantic-state/specs/geo-map-semantic-state/spec.md` is a completed-change capability, not an independent canonical file. Its Nearby partial order is **Places→Events**; marker order here is **Events→Places**. Mode/Post/Search fence/Weather/Nearby/routes retain their owners. No second semantic-state capability.

## Goals / Non-Goals

Commit one coherent marker snapshot; preserve optimistic history without stale-read overwrite or cross-operation rollback; verify lifecycle. Search ordering belongs to one writer session and accepted intentions, without global coordination across owners sharing a repository. Foundation, persistence, search queries, Post, Weather, Nearby, controllers/sheet and routing retain existing responsibilities.

## Decisions — approved planning contracts, later implemented

### D1 — F1/F2: synchronous admission and a local ordered writer

This superseded initial D1. Add/remove dispatch to a private feature session in the VM file, owning SearchRepository, FIFO, ordered base/projection and one reused `createResultCommand<HistoryMutation,void>`. It is neither DI service, repository, singleton nor cross-feature framework. VM observes only while live. Command action captures repository + immutable request, invokes add/remove once and never reads State, BuildContext, VM `_disposed` or UI callbacks.

| State | Meaning / ownership |
| --- | --- |
| unadmitted proposal | Callback not authorized; no obligation/epoch. |
| excluded / represented | Empty/category/proven duplicate; no new entry/write or independent persistence success. |
| accepted(sequence) | Immutable obligation transferred; FIFO/epoch/barrier installed before UI effects; navigation cannot revoke it. |
| Command-admitted | Head passed to run, synchronous running true; repository entry still deferred. |
| persistence-started | Action entered and invoked repository exactly once. |
| physical-settled | Repository Future returned Result/throw; Command reporting/dispatch may remain. |
| entry-settled | Pump outside dispatch acquired original outcome, reduced private state and released head/receipt. |
| UI-detached | No new acceptance/notify/UI rollback/read; writer drains accepted queued entries. |

Admission validates callback owner/session, classifies deduplication, assigns sequence, appends a private **Future<void>** receipt, increments epoch and installs FIFO drain before run/notify/observers. Void receipts mean settlement, never implied success or unobserved completeError. Run the first head before optimistic notify; later entries are accepted but not Command-admitted until predecessor settlement. Reentrant observers see complete state and cannot revoke accepted persistence.

Keep original strings with no new trim/threshold. Exclude empty/known category labels ignoring case; add compares case-insensitively, remove exact-case. Apply transformations to current projection P, including opposite pending entries. Represented status needs unchanged P plus a known non-uncertain base or equivalent pending intention not superseded by its opposite. Membership in base alone is insufficient. add(A)→add(a) is represented; opposite/different-entry intentions are accepted when changing desired state. Unknown bootstrap absence cannot prove persisted absence; remove(A) remains accepted (write=1, notification=0 for empty projection). Provisional runtime-failure state cannot prove redundancy. Reject stale callbacks before dispatch; never coalesce opposites or delete accepted entries retroactively.

Maintain base `B`, pending `Q` and `P = fold(Q, B)` (append absent ignoring-case; remove exact-case). Admission updates P synchronously; notify a live VM only for actual ordered-list changes. At head settlement, success transforms B; Result.error leaves B unchanged; runtime applies provisional optimism to B and marks uncertainty. Remove that entry only, rebase all later intentions and notify only for changed P. Do not restore a global old snapshot. Later accepted entries still attempt persistence if rebase makes them local no-ops. A private settlement/demand signal reaches live scheduling even when P is unchanged; detached callbacks are cleared. Original per-entry errors remain original, without invented batch success.

One repository method may be in flight per session. The pump observes head terminal/non-running, crosses the established microtask→event boundary, rechecks paramData identity/non-running/token and reduces/pops/completes receipt/runs next only outside dispatch/reporting. Neither listener nor action finally starts the next run. Success/domain error/handled runtime all drain; no automatic write retry. Nonterminating Future blocks physical FIFO without reordering or dropping.

F1 confirmation reserves a follow-through token and consumes popup admission before dispatch. Recheck mounted/current owner/controller/token after dispatch before closeView and again before host navigation. Own-close consumes popup admission but preserves that confirmation's valid navigation token; semantic supersession/replacement/unmount revokes it. Thus `accepted → run(head) → closeView → navigation/dispose → deferred entry → repository → settlement` writes once without awaiting navigation. Queued submits also persist after detach. Writer captures no VM; its only UI callback is detachable.

Rejected alternatives: a dropping common lane, concurrent independent writers, restartable mutations, View-side repository calls, awaiting bootstrap/persistence before navigation and a Command per entry. Session FIFO is justified by distinct accepted intentions while single-flight is busy. Replacement owns a new session; its bootstrap may precede old drain. No shared storage lock or cross-owner convergence guarantee.

### D2 — F3/F4: one admission/write/read protocol

This superseded initial D2. State comprises monotonic epoch `E` (acceptance and settlement), D1 Q/base, synchronously installed empty→nonempty drain, separate UI-detached signal, uncertainty and independent read `requested`/`attempted` generations. Update B/Q/E before receipts; complete physical drain only after all accepted entries settle outside dispatch. New reentrant acceptance installs a new barrier before notify; waking readers recheck Q/E.

Bootstrap registers one demand. Acceptance immediately invalidates active reads and demands reconciliation when reading or base unknown; runtime writes always demand reconciliation, even without pending G0. Success/domain failure on known base without concurrent read needs no extra query. Coalesce a write burst to latest requested generation.

1. A live idle scheduler starts one load for unattempted demand, never run while busy. Its action awaits `drain OR UI-detached`, then rechecks UI/Q. Writer never waits for bootstrap/read/UI.
2. Immediately before getPastSearches, with Q empty/live UI, capture E and consume current demand (`attempted = requested`) without intervening await/notify.
3. Publish success only while live, with unchanged E/current demand and empty Q. Copy ordered B, establish knowledge, resolve uncertainty and notify only if P changes. Resolve physical-get authority before notify so a reentrant write uses the confirmed base without a redundant get merely because Command dispatch remains busy.
4. Discard stale success without notify; the same load waits latest drain and attempts latest demand, with one physical read at a time.
5. Result.error preserves list/original Exception; raw get reports original runtime once. Neither recreates consumed demand merely because storage is unknown/uncertain. A newer demand created after old G0 began survives old failure and gets one post-terminal/reporting/post-drain attempt. Otherwise require explicit retry/new qualifying mutation; no failure loop.
6. Disposal wakes UI read waiters through detach, revokes scheduler/callbacks and starts no get/notify. Already-started get settles privately. Do not fake completion of writer drain/receipts; nonterminating accepted writes cannot strand UI waiters.

F4 marks uncertainty and demand before completing receipt/drain. One stable post-drain read, via this same scheduler, resolves storage after runtime before/after commit; no invented rollback or write retry. Accepted W2 must settle before reconciliation. Failed read consumes demand and retains provisional state; runtime write/read each report their own original failure once. Detached UI starts no read. Progress requires live UI and successful I/O; automatic convergence is not guaranteed.

Anti-deadlock: admission/write never await reads; read awaits drain or detach; next write awaits predecessor settlement/reporting only. State is installed before notifications; pump/scheduler recheck token/owner after reentry.

### D3 — GeoMap snapshots, bootstrap, empty and retry

Two synchronous void setters copy immutable category/type sets. Initially select all known categories (excluding unknown) and ContentTypes; normalize unknown away and compare set values. Empty programmatic category/type means successful-empty with zero I/O; shared dialog still normalizes empty draft→all on permitted current mounted-session completion.

One `RestartableCommand<MarkerFilterSnapshot,MarkerOutcome>` loadMarkers replaces both loads. Every accepted snapshot has immutable sets and a new Object ticket; completion checks snapshot identity/paramData ticket. Equality deduplicates sets only, not tickets. Constructor installs state/listeners before one bootstrap admission, immediately loading. Equal filter is a no-op even pending/failed; distinct current-filter retry gets a fresh ticket after failure, rejects busy/stale callbacks and retries every selected source. A→B→A uses three generations.

Clear both collections and terminal before run/invalidate, hiding old authority even before deferred public loading. Nonempty admission runs and notifies once if still owner after reentry. Empty invalidates old work and immediately commits local successful-empty, once; queued obsolete envelopes start no action. Command blank is not empty success. Empty retry has no I/O/extra notification.

### D4 — Fetch, atomicity and partial marker failure

Query selected Events then Places through GeoMapUseCase; no Future.wait that changes runtime wrapping/report order. This deliberately replaces independent bootstrap fetches with one coherent sequence. Events Result.error still permits selected Places. Excluded sources perform no query. Filter captured categories; preserve repository order and Events→Places, without sorting/deduplication even for equal IDs across types.

Action accumulates local immutable events/places/eventError/placeError. `Result.success(outcome)` means protocol completion, not all-source success. No errors→success-data/empty; any error→failure/retry, retaining successful partial items and both original errors with Events display precedence. Zero items plus error is failure.

After first await, check disposal before second source. Supersession revokes publication without promising physical cancellation of already-entered work; disposal prohibits new owner-controlled phases. Raw failure terminates before not-yet-started next source; no Object→Result conversion or required partial runtime commit. Original runtime/stack reports once even stale; assertions fail loud.

Live completion verifies current ticket/snapshot/terminal, atomically copies both lists and terminal, then notifies once. Runtime terminal is failure with empty lists. No isolated completed/!isRunningSync success inference or semantic/Nearby coupling.

### D5 — Marker presentation and callbacks

GeoMapScreen observes VM/loadMarkers.results, replacing merged legacy listeners. Loading overlay hides old markers; success-data renders MarkerLayer; success-empty shows `Nessun contenuto per i filtri selezionati`; failure shows generic error and `Riprova`, preserving current partial markers. UI strings are existing product text, not translated documentation. Status stays readable in Explore/Search/Post without hiding map/navigation, changing sheet/mode, printing raw errors or repeat snackbar rebuilds.

Retry/marker callbacks capture owner and terminal/generation, requiring mounted/current widget+Provider owner/current admission. Stale markers cannot select/retry against replacement B or revive old Post. Preserve ObjectKey(owner), dialog session guards and one setter callback on current route completion. Collection notifications do not replay semantic camera/sheet entry effects.

AppSearchAnchor checks mounted before State.widget/context; deferred/chip callbacks require current owner/controller/session. Deferred delete reset cannot clear replacement/new input. Capture before await, use safe cached popup defaults and never close an already-popped popup. Submit/suggestion recheck after synchronous dispatch and own-close before host callback; valid own-close preserves navigation token. `_handleOnClose` neither pops twice nor revives stale callbacks. Future widget/test edits require mounted-context-safety and relevant support skills.

### D6 — Two lifecycles, reporting and reentry

Idempotent VM disposal immediately revokes admission/presentation/read scheduling, detaches callbacks/observers, wakes only UI waiters and disposes existing results/suggestions/marker owners per their contracts. Unaccepted/stale requests create no write. Do not dispose writer Command with UI: private session still owns accepted entries, including queued/pre-entry work, without old VM/State/context access. Detached+drained releases listener/notifier/Command/entries/receipts once outside dispatch. Ordinary reader retains private Command until already-started get can report.

B/Q mutations after detach are private session state; disposed VM keeps its last immutable projection with no rollback/notify. Factory globalHandler reports original runtime once, no manual duplicate report. Result.error stays data; void receipt creates no second async error. Completion is not success.

Cleanup uses invalidatable microtask→event boundary, rechecks busy/reentry and never relies on terminal result, isolated sync false, receipt, action finally or upstream 50ms teardown as settlement proof. Assertion fail-loud is not Result.error/normal recovery; its no-terminal upstream branch must release waiters/private resources as development abort without claiming persistence success/normal FIFO continuation. Handled StateError/TypeError still drain.

OpenSpec 1–3 disposal rules remain: writer is a separate live owner initialized at acceptance; reader, results/suggestions, Map/Post/Nearby and prior lanes cannot start new owner-controlled phases after disposal. No app-scoped/cross-owner session reuse or shared serialization.

## Regression plan — historical acceptance matrix

Reuse `test/support/{fake_repositories,controllable_search_repository,command_test_support,ordinary_view_model_lifecycle_support,route_ownership_fixture,fixtures}.dart`. Extend missing Completer sequences/counters in shared support. ControllableSearchRepository stays results/suggestions-only. Use real GeoMapUseCase with fake Event/Place queues, preserving parameter/order observability. Do not duplicate local helpers.

Each ID denotes explicit tests/parameterizations, not a new test result. Assert same-stack state before controlled `pumpCommandTurns`/zero pumps, then resolve Completers and drain documented turns. `N` counts live VM list-notification deltas after stable setup; `C` counts described repository calls. Observe each phase, separate Command state (ordinary immediate, restartable deferred), and use virtual debounce/animation/reset/50ms clocks without wall-clock sleeps.

| ID | Controlled sequence and required oracle |
| --- | --- |
| S1 | New Search, G0 pending + duplicate demand: P=[], Cget=1 after entry; G0→[a,b], N=1, success distinct from neutral, no extra get. |
| S2 | Known [a,b], add c/remove a: optimistic [a,b,c]/[b], N=1 before action; success adds N=0, write=1; domain failure restores [a,b], extra N=1, same Exception/global=0, no unnecessary read. |
| S3 | Empty/category/duplicate A or proven absent/exact-case mismatch removal: E unchanged, N=0, write/get extra=0; unknown/uncertain absence accepts removal, write=1/N=0. |
| S4 | Eight F2 sequences below: distinct FIFO acceptance/represented duplicates; W2 cannot enter before W1 private settlement/reporting. Physical writes cannot complete out of order. |
| S5 | G0 E0 pending; add c accepted before W action; G0→[a,b] cannot commit: P=[c], N=1; discard N=0; Wwrite=1, then G1→[a,b,c] N=1, Cget=2 only after drain. |
| S6 | Known [a,b], reload G0, remove a, W succeeds then G0→[a,b], G1→[b]: P=[b], N=1, no resurrection; G1 same-list N=0, extra gets=2/write=1. Reverse G0/W with identical outcome. |
| S7 | Known [], add A raw before/after fake commit: P=[A], N=1/write=1, no invented rollback; original W global=1; mandatory post-drain get extra=1. Before-commit G1=[] gives N=1; after-commit G1=[A] gives N=0; no write retry. |
| S8 | G0 + accepted A/B before W1 entry: P=[A,B], N=2; writes=[add A,add B]; gets=G0+G1 (2); one burst reconciliation, no get between W1/W2. |
| S9 | Dispose before action/from notify/during await, possibly accepted W2: writes equal accepted count, immutable final UI snapshot; reject new requests; post-dispose N=0/new get=0; each runtime global=1, expected errors unreported; separate terminal/idle/assertion cleanup. |
| S10 | Stable read domain/runtime failure without newer demand consumes attempt; no loop, list retained; Cget=1/attempt, explicit retry +1; N only changed success; global domain=0/runtime=1. |
| S11 | Old G0 fails during accepted W: no rollback and cannot consume newer W demand; original G0 runtime global=1 if applicable; after drain G1, Cget=2, stop if G1 fails. |
| S12 | Stale G0, reader waits nonterminating W, disposal wakes UI-detached only: no new get/N; W may later settle write=1/private report/cleanup; no stranded UI waiter. |
| S13 | Runtime W1 with opposite/different W2 accepted, G0 present/absent: retain W2, no intermediate read; original global W1=1, one latest-E post-drain G1 (+existing G0); actual storage determines projection. |
| S14 | Runtime W without G0; G1 fails: provisional history retained; Wwrite=1/G1get=1, no automatic read/write retry; G1 domain global=0/runtime=1 independently of W. |
| S15 | Dispose after W throw but before scheduled G1 action/get: write=1/report=1, G1repo=0/post-dispose N=0, reader waiter released. |
| S16 | Reentrant admission A→B gives P=[A,B]/N=2 before write, writes=2/extra gets=0/settlement N=0. Stable get=[A] listener adds C: commit N=1 then [A,C] N=1, get=1/write=1/extra gets=0/settlement N=0. New W3 after old drain makes reader await new barrier/E; listener disposal forbids future N. |
| S17 | W1 domain failure with opposite/different W2, G0 before/during/after: remove only W1 contribution, retain W2, writes=2 ordered; one post-both G1 if invalidated; original W1 error/global=0. |
| S18 | Runtime makes B uncertain; apparent redundancy based only on B still accepts a new explicit intent, write=1 without automatic W retry; equivalent pending duplicate remains represented. Coalesced read after drain, unchanged P gives no notify; stable read resolves uncertainty. |
| G1 | Bootstrap Events pending: all-known/all-types/loading/empty; E=1/P=0 until Events settles. Events-only N=0; Places completion atomically publishes once, E=1/P=1, Events→Places. |
| G2 | Event-only/place-only/both and caller Set mutation: immutable getters, old lists hidden/loading N=1; E/P=(1,0)/(0,1)/(1,1), captured filter/order/cross-type ID, terminal N=1. |
| G3 | Equal pending/success/failure sets N=0; empty category/type N=1 immediate successful-empty; equal/empty C=0, late N=0; empty retry N=0/C=0. |
| G4 | Physical A→B→A2; distinct tickets/loading N=1 per admission; latest A2 terminal N=1; old A/B success/error N=0 and cannot change current running. Count entered source phases; obsolete physical Places may continue without commit. |
| G5 | Same-stack A→B→A or A→empty before entry: obsolete queued envelopes C=0; final nonempty alone E/P=1/1; empty C=0/no late notify. |
| G6 | Events error/Places data, reverse, both errors, both empty, empty+error: no phase partial/N=0; one terminal N=1, partial/retry or both-original-errors with Events precedence; E/P=1/1/global=0; empty success only without error. |
| G7 | Events/Places StateError, stale throw and separate assertion: current runtime failure N=1/global=1; stale N=0/global=1; Events throw P=0, Places throw E/P=1/1; assertion fail-loud/private cleanup, no synthetic domain error. |
| G8 | Captured retry then filter changes: stale callback N=0/C=0; current retry loading N=1, one call/selected source and terminal N=1; busy retry C=0, no old-filter reuse. |
| G9 | Admission/terminal observer admits B/empty/disposes: coherent state before listener; no subsequent A notify/phase; B publishes once; disposal before Events C=0/during Events P=0/post-dispose N=0. |
| U1 | Anchor admission→close→goNamed/dispose→entry→settlement, including queued submit: immediate navigation/one close, preinstalled E/barrier; exactly one accepted-submit write (+predecessor), post-dispose N=0/runtime global=1; stale closed popup creates no intent. |
| U2 | Delete chip then replacement/new text before deferred reset; cached callbacks after replace/unmount: zero stale writes/duplicate close/pop; reset same session/input only, virtual timer. |
| U3 | Real Map pending→empty/data/partial/error/retry: overlay/no stale markers, exact marker order/count and distinct messages with G1/G6 N; no infinite spinner, retry once, no repeated camera animation. |
| U4 | Category/type dialog empty/nonempty/unchanged × Save/Back/permitted barrier/drag/rebuild/unmount/replacement/stale session: no pre-completion I/O; callback once if current/mounted, empty→all; equal setter C/N=0, different one admission; stale callback=0; preserve four owner-key tests. |
| U5 | Map A pending→B, retained A marker/retry, late A settlement: B bootstraps independently; only B commits; A runtime report=1 with no B notify; same-owner/filter rebuild never refetches. |
| U6 | Optimistic notify or close callback replaces/unmounts host: acceptance installed/Cwrite=0 before action; no invalid-host follow-up; accepted write=1 after detach/post-dispose N=0/old navigation=0. Normal own-close preserves token/navigation=1 without allowing consumed-popup admission. |
| R1 | Map Explore→Search→Post→close/Back with query/lookup/Weather/Nearby pending, return/restoration/Gallery: retain mode/fence/owner/URI and excluded-lane counts; late history/markers cannot change selection/semantics. |

### F2 — Exact ordered-intention outcomes

N counts list changes only, excluding private Command/receipt events. Setup: known stable base, no concurrent read and no errors except specified domain failure without store mutation. Fake fails if W2 enters before W1 private settlement. Gets may settle in any write-relative order, protected by E.

| Sequence | Projection after each acceptance | Ordered physical writes | Local/store outcome | Total N |
| --- | --- | --- | --- | --- |
| []: add(A)→add(A) | [A], [A] (second represented) | add(A), once | [A], no rollback | 1 |
| []: add(A)→remove(A) | [A], [] | add(A), remove(A) | [], no rollback | 2 |
| [A,B]: remove(A)→add(A) | [B], [B,A] | remove(A), add(A) | [B,A], append as ObjectBox | 2 |
| []: add(A)→add(B) | [A], [A,B] | add(A), add(B) | [A,B] | 2 |
| [A,B,C]: remove(A)→remove(B) | [B,C], [C] | remove(A), remove(B) | [C] | 2 |
| []: add(A) fails→already accepted add(B) | [A], [A,B] | add(A) Error, add(B) Success | Failure P=[B], one rollback notification; final [B] | 3 |
| []: add(A) fails→already accepted remove(A) | [A], [] | add(A) Error, remove(A) repository no-op Success | P remains []; W2 already hides A, no rollback notification | 2 |
| [A,B]: remove(A) fails→already accepted add(A) | [B], [B,A] | remove(A) Error, add(A) repository no-op Success | Rebase B=[A,B] returns [A,B], one notification; preserve original order | 3 |

Reentrant acceptance uses the next sequence, without changing existing outcomes. Known absent removal is represented; unknown/uncertain absence is not. Runtime first failure uses S7/S13, not this domain rollback table: only G1 establishes actual storage.

### F5 — Actual dialog completion contract

`CategoryContentAndTypeSelection` captures draft/callback before await (`:110–164`, locate `_onTypeChipPressed`/`_onCategoryChipPressed` at the checkpoint), then checks mounted/draft identity without a Save/Cancel result. showDialog does not set barrierDismissible=false; appShowModalBottomSheet uses isDismissible=true/enableDrag=true. GeoMapScreen ObjectKey(owner) unmounts old State on replacement. Four real tests at `test/ui/geo_map/widgets/geo_map_screen_test.dart:53–200` cover categories/types × empty/nonempty with old modal open/new equal-filter owner: callbacks reach neither A nor B.

| Trigger/session | Preserved U4 contract |
| --- | --- |
| Save, modified current draft | Pop route, apply/callback once; setter loads only for genuinely different set. |
| Back/pop, modified draft | Same as Save on normal route completion; no cancellation semantics. |
| Permitted barrier/sheet drag | Same route-completion behavior in both adaptive layouts, tested virtually. |
| Empty draft | Stay empty during editing/rebuild; valid completion normalizes that field to all, callback once. |
| Unchanged draft | Selector callback once; equal setter admission/I/O/notify=0. |
| Widget unmount | No post-await normalization/setState/callback. |
| Owner A→B with equal filters | ObjectKey unmounts A; retained old modal cannot publish to either owner; preserve four tests. |
| Obsolete per-field session | Failed identity check: no normalization/callback. Changing only the other field does not invalidate it. |

Back/barrier/drag gates are additional: the four Save-based replacement tests alone cannot establish them. No new Cancel UX or earlier Category delta/widget change. Isolate semantic mode/Nearby notifications from marker N; never weaken counts to “at least one”. G4 records per-generation dispatch→entry phases; supersession does not promise cancellation. Disposal covers idle/running/terminal and throws beyond virtual 50ms.

Historical planned suites: `test/ui/search/view_models/search_view_model_test.dart`, `test/ui/search/widgets/components/{app_search_anchor,search_anchor_suggestion_list}_test.dart`, `test/ui/search/widgets/search_result_sliver_list_test.dart`, `test/ui/geo_map/view_models/geo_map_view_model_test.dart`, `test/ui/geo_map/widgets/{geo_map_screen,geo_map}_test.dart`, `test/ui/category/widgets/category_content_and_type_selection_test.dart`, `test/data/repositories/search_repository_impl_test.dart`, `test/routing/{geo_map_route,route_ownership,back_navigation_integration,main_navigation_restoration,restoration_behavior,route_parameter_redirect}_test.dart`, foundation/lifecycle and full suite. Execution results follow separately.

## Risks / Trade-offs

Session FIFO may retain pending resources indefinitely for nonterminating Futures; no timeout/cap drops intentions or persisted queue survives process kill. Stable read coalescing requires a mutation-free window and terminating I/O, without polling. Runtime write uncertainty may survive failed reconciliation/detach; consumed demand avoids loops. Replacement bootstrap may precede old writer drain; no cross-owner convergence. Marker bootstrap is slower/nonprogressive but coherent; protocol success still needs source-error projection. Unsynchronized canonical requires cumulative delta order. Noncooperative old physical I/O may retain private resources until settlement; supersession is authority revocation, not abort.

## Historical planning, remediation and authorization

The original plan required sequential gated tasks after independent review/new authorization, coherent VM/consumer/test API adaptation, no global command.dart removal/deploy/schema change and no destructive rollback of others' work. Revised D1/D2/D6 resolved F1–F4; D3/D5/U4 clarified F5. They were planning decisions at that time, not implemented code.

### Initial planning evidence — before F1–F5

Actually executed: PR/Git snapshots, offline pub get, machine analyzer, OpenSpec context/list/instructions/status, `openspec validate migrate-search-map-commands --strict` (**valid, exit 0**), `git diff --check` (**exit 0**) and all six untracked-artifact whitespace/newline checks. OpenSpec status **4/4 artifact groups complete** meant artifact existence; tasks were **0/25**, not 25 implemented. The six-file manifest was `.openspec.yaml`, proposal/design/tasks and the two deltas; no symlinks, tracked/staged diff or source/test/dependency/config changes. Five pre-existing checkouts retained HEAD/branch/status/digests. Ignored analyzer cache was not publishable evidence.

Seven targets matched 21 diagnostics; decisions mapped to scenarios/tasks; two existing capabilities used ADDED only. The initial matrix had **25 scenario groups** including parameterization. Flutter tests and independent adversarial review were **NOT RUN** during that planning. Historical verdict **READY FOR INDEPENDENT PLAN REVIEW** was superseded by F1–F5.

### F1–F5 documentation remediation

Reconfirmed six worktrees and open/Draft PR at `1f3753b10c18061c6655cb32d078bf93aff1b05e`. Six untracked artifacts plus externally added `openspec/changes/migrate-search-map-commands.zip` existed; ZIP was out of scope and preserved byte-for-byte. Empty index/no tracked diff; snapshots/hashes checked before overwriting, no concurrent edit detected or destructive Git action. Reread six artifacts/source/tests and local command_it 9.5.2 (sync run/deferred entry, joining runAsync, reporting, 50ms teardown), ObjectBox identity and fake/Completer/four owner-key tests. Historical analyzer **87/0/0** and strict results were not rerun during this documentation-only remediation.

| Finding | Corrective decision / rejected alternatives / discriminating gate |
| --- | --- |
| F1 — pre-entry disposal lost submit | D1/D5/D6, S9/U1/U6: transfer persistence to live private writer before detach; one repository call after admission→close→dispose→entry. Reject View repository calls, awaiting writes/bootstrap or writer disposal with VM. Tasks 2.4/2.5/2.7 and lifecycle/accepted-persistence delta. |
| F2 — single-flight dropped distinct operations | D1/S4/S17/S18/F2: reused Command FIFO, base+pending and per-operation rollback. Reject concurrent lanes, restartable/drop/global lock/per-entry Commands. Tasks 2.1/2.2 and order/dedup/rollback delta; eight exact state/store/N/order cases. |
| F3 — late epoch authorized G0 | D2/S5/S6/S8/S10/S11/S12/S16: E/entry/receipt/drain before run/notify; read waits drain OR detach; requested/attempted separate. Reject action-entry revision, late Future installation or write-blocking read lock. Task 2.3/read-authority/demands delta; G0 after acceptance but before W entry cannot commit/deadlock. |
| F4 — runtime optimism never reconciled | D1/D2/D6/S7/S13–S15/S18: same bounded stable post-drain reader, even without G0; no invented rollback, extra service, endless retry or duplicate manual reporting. Task 2.6/runtime-demand delta tests before/after commit, pending W2, failed read/disposal. |
| F5 — Save/Cancel wording contradicted widget | D3/D5/U4/F5: permitted Save/Back/barrier/drag completion applies mounted/current draft, empty→all; stale/unmounted none. Reject new Cancel UX, Save-only callback or ObjectKey removal. Task 4.2/current-session-close delta, all triggers and four owner replacement tests. |

`local-content-retrieval` delta and `.openspec.yaml` remained byte-identical. No remigration of results/suggestions/Nearby/marker retrieval or reporting. Revised matrix: **34 groups** S1–S18/G1–G9/U1–U6/R1; eight F2 rows and F5 triggers are parameterizations, not executed-test counts. At this stage **0/27** tasks, all unchecked. Strict valid/exit 0, status/instructions, names/scenarios/numbering/references, whitespace/newlines, manifest/Git/digest checks passed; no analyzer/pub get/Flutter rerun. Four files changed (proposal/design/tasks/concurrency delta); other metadata/retrieval/ZIP and five external checkouts preserved. Historical verdict **READY FOR INDEPENDENT PLAN RE-REVIEW** proposed F1–F5 closure without implementation authorization.

## Implementation evidence — historical authorized local apply

The later prompt authorized local fourth-change implementation after re-review **READY FOR APPLY**, initially excluding commit/push/PR update/sync/archive. Branch/HEAD stayed at baseline; origin/PR were reconfirmed, six reviewed artifacts present, empty index/tracked diff. Historical ZIP was absent at apply preflight and neither recreated nor removed. Five other checkouts were snapshotted. B0 reran: **87 INFO/0 WARNING/0 ERROR, exit 0**, `<evidence-dir>/search-map-apply-B0.txt`.

### R1 — Sole public reader entry, clarified before task 2.3

`void requestPastSearchesRefresh()` synchronously increments requested only while live and wakes the sole D2 scheduler. Constructor bootstraps through it once after initialization. Private reader exposes read-only ValueListenable snapshot only, no run bypass. Pre-physical-start demands coalesce; post-G0-start demand retains separate authority. Commit requires captured E/current demand/FIFO empty; next physical get waits old dispatch/settlement. Consume demand at physical start, not settlement; failure does not recreate it. R1.1–R1.7 cover bootstrap, domain/runtime explicit retry/no loops/report once, drain demand, post-start demand, disposal before API/while pending/during get and static encapsulation, with Completers/virtual clock.

### Search gates 1–2

Before VM edits, `search_history_characterization_test.dart` was RED: bootstrap overwrote accepted query (visible old instead of accepted), recorded in `<evidence-dir>/search-map-characterization-red.log`. Adapted to the new API it passed. Implementation added private writer/R1/session guards and removed redundant Explore/SearchResult host closeView calls, without Explore VM or route-ownership changes. FakeSearchRepository gained history/write hooks with unchanged defaults; SearchHistoryHarness reused it at the repository boundary.

`flutter test --no-pub test/ui/search/view_models test/ui/search/widgets test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart test/ui/ordinary_view_model_lifecycle_test.dart --reporter expanded`: **343 passed / 3 pre-existing skips / 0 failures, exit 0**, `<evidence-dir>/search-map-search-gate-final.log`. Included S1–S18/eight F2/R1, 33 anchor tests and ten added lifecycle tests. Focus analyzer: zero diagnostics. Reader executed only inside `_scheduleRead`, no external loadPastSearches.run; retry tests used requestPastSearchesRefresh. detailedStackTraces retained original frames plus upstream chains; lifecycle tests saved/restored false for sentinel identity, integration checked decorated chains. Foundation unchanged; Search gate closed before GeoMap edits.

### Internal Search corrections and GeoMap gate 3

Internal read-only audit found debounce cancellation without remembered-text reset on close and missing popup hint. Deterministic reopen-during-debounce/hint regressions fixed both: Anchor **34/34 pass**, two-file analyzer zero diagnostics. This internal audit did not replace independent code review.

`flutter test --no-pub test/ui/geo_map/view_models test/utils/restartable_command_test.dart --reporter expanded`: **98 passed / 0 failures, exit 0**, `<evidence-dir>/search-map-geo-vm-gate-final.log`. Included 25 new marker tests, semantic/foundation suites, atomic bootstrap, membership/filter/snapshots/empty, physical+queued A→B→A, eight source/empty outcomes, current/stale runtime/assertion/retry/disposal/reentry. Initial unknown fixtures were correctly excluded and corrected to known categories; an existing semantic test adopted shared virtual child-marker teardown with assertions unchanged.

Procedural deviation: parallel assignment produced a screen draft after Search but before VM3.5 completed. It was not treated as integrated/validated then; isolated VM gate completed before UI validation. No functional/scope deviation.

### UI gate 4

Internal stacking finding moved marker overlay above sheet/search bar so retry remained hit-testable in full-sheet Explore/Search/Post. Mode/controller/URI, GeoMapBottomSheet, Weather and selection/Nearby unchanged. Screen+test analyzer zero diagnostics; screen **63/63 passed**, including four owner-key cases and Save/Back/barrier/drag, stale callbacks, statuses/retry. New widget fixtures initially observed Category instead of real getByCurrentYear/getAll and were corrected at the actual GeoMapUseCase boundary without query changes.

`flutter test --no-pub test/ui/geo_map test/routing test/ui/category/widgets/category_content_and_type_selection_test.dart test/ui/weather test/data/repositories/search_repository_impl_test.dart --reporter expanded`: **534 passed / 1 pre-existing skip / 0 failures, exit 0**, `<evidence-dir>/search-map-ui-routing-gate-final.log`. Extra terminal-reentry/Post/order marker cases: `geo_map_markers_test.dart` **27/27 passed**. A /map route needed testOwnerUI to drain zero-turn reader/writer timers at actual final unmount; harness invocation only changed, route assertions preserved. Route retest **51 passed / 1 existing skip**.

Missing ObjectBox runtime was supplied by copying available primary-checkout dylib into ignored `lib/libobjectbox.dylib`, verified SHA-256 **1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751**. Source/dependency/version/schema unchanged. Formatting **18 Dart files** left zero residual changes.

### Analyzer B0/B1 and manifest

`dart analyze --format machine`: B0 **87 INFO/0 WARNING/0 ERROR**, B1 **66 INFO/0 WARNING/0 ERROR**, both **exit 0**, empty stderr. Exactly **21** targets removed (9 Search,12 GeoMap), no new/non-target multiplicity changes. Compared path/code/column/length/message/source context; existing fake_repositories.dart legacy dartdocs moved **653→656** and **1159→1165**, neither new nor suppressed/remigrated. Historical files: `<evidence-dir>/search-map-apply-B0.txt`, `<evidence-dir>/search-map-apply-B1.txt`, `<evidence-dir>/search-map-analyzer-comparison.json`. `flutter analyze` was **NOT RUN** in this apply; 66 INFO remained for later migrations.

Manifest: **24 files** (6 production, 12 tests/support, 6 artifacts), empty index. Tracked diff + ls-files untracked verified it. Hashes of **18 Dart files** recorded at full-suite start in `<evidence-dir>/search-map-validated-source-hashes.json`; no new ignore/generated/dependency/lock/config/CI/backend/schema/repository/foundation/other-change/canonical edits. Five external checkouts retained initial HEAD/branch/digest/status/untracked.

### Full suite and local closeout

`flutter test --no-pub --reporter expanded`: **2705 passed / 6 pre-existing skips / 0 failures, exit 0**, `<evidence-dir>/search-map-full-suite.log`. All 18 Dart hashes stayed identical during/after run; included consumers/new regressions/real ObjectBox tests. Individual suite counts describe separate actual runs and are not summed as unique tests. Intermediate failures above remain recorded.

The three internal findings were corrected with regressions (same-text debounce reopen, popup hint, overlay retry stacking); independent review was still a separate next gate. PR remained open/Draft/nonmerged at `1f3753b10c18061c6655cb32d078bf93aff1b05e` during local closeout, without commit/push/PR update/merge/sync/archive. HEAD/branch/index and other five checkouts matched preflight; ignored dylib excluded. Planning metadata/proposal/retrieval delta preserved; implementation updated design/tasks and concurrency delta only for R1.

Intentional limits remained session-only ordering, resource retention for nonterminating work, no process-kill queue durability, bounded uncertain-write reconciliation, fail-loud assertions and **66 INFO**. Only procedural deviation was early screen draft. Full historical implementation manifest:

```text
lib/ui/explore/widgets/explore_screen.dart
lib/ui/geo_map/view_models/geo_map_view_model.dart
lib/ui/geo_map/widgets/geo_map_screen.dart
lib/ui/search/view_models/search_view_model.dart
lib/ui/search/widgets/components/app_search_anchor.dart
lib/ui/search/widgets/search_result_screen.dart
openspec/changes/migrate-search-map-commands/.openspec.yaml
openspec/changes/migrate-search-map-commands/design.md
openspec/changes/migrate-search-map-commands/proposal.md
openspec/changes/migrate-search-map-commands/specs/command-execution-concurrency/spec.md
openspec/changes/migrate-search-map-commands/specs/local-content-retrieval/spec.md
openspec/changes/migrate-search-map-commands/tasks.md
test/routing/geo_map_route_test.dart
test/support/fake_repositories.dart
test/support/geo_map_marker_harness.dart
test/support/search_history_harness.dart
test/ui/geo_map/view_models/geo_map_markers_test.dart
test/ui/geo_map/view_models/geo_map_view_model_test.dart
test/ui/geo_map/widgets/geo_map_screen_test.dart
test/ui/search/view_models/search_history_characterization_test.dart
test/ui/search/view_models/search_history_lifecycle_test.dart
test/ui/search/view_models/search_history_test.dart
test/ui/search/view_models/search_view_model_test.dart
test/ui/search/widgets/components/app_search_anchor_test.dart
```

Final formatting of 18 Dart files left no changes; diff/new-file whitespace/newlines, manifest/hash and strict OpenSpec passed. **27/27** checked only after these gates. Historical verdict **READY FOR INDEPENDENT CODE REVIEW** did not authorize publication.

## Published checkpoint and current cumulative status

Later independent review/publication followed. Git verifies checkpoint 4 [`da7c426fb799a26094f043319b47e63b98728f92`](https://github.com/xmattjus/moliseis/commit/da7c426fb799a26094f043319b47e63b98728f92), parent `1f3753b10c18061c6655cb32d078bf93aff1b05e`. Documentation-only [`f48a08946c9ac40146104a0157556243ad433c92`](https://github.com/xmattjus/moliseis/commit/f48a08946c9ac40146104a0157556243ad433c92) directly followed and corrected publication status; it changed proposal/tasks, not production. That Search/GeoMap correction remains preserved here.

Historical exact-SHA workflow evidence: [checkpoint-4 run 39961582029](https://github.com/xmattjus/moliseis/actions/runs/39961582029) and [f48a089 reconciliation run 39964646512](https://github.com/xmattjus/moliseis/actions/runs/39964646512) both completed with failure. These persistent links replace no local raw-log evidence.

Both commits are in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12). At checkpoint 4 the cumulative state was **4/7 implemented and published** and analyzer retained 66 INFO. Current cumulative state is **seven published migrations**; final zero-diagnostic evidence belongs to later checkpoints/current validation. Historical Actions workflow conclusions before checkpoint 7 were failure; local direct-Dart exit 0 did not establish green Flutter-analyze CI. No fresh execution or accessible raw historical temporary log is asserted by translating this record. Persistent commits preserve sources/artifacts, not ephemeral log contents. Canonical sync, archive, legacy compatibility deletion and merge remain separate authorization gates; PR remains Draft.
