# Verified baseline and estimated simplification

## Measurement definitions

Refs are full SHAs in metrics.json. Physical LOC uses Python `len(text.splitlines())`, including blanks/comments; class names use declaration regex. Listener/scheduling counts are **syntactic call sites**, not runtime subscriptions, closures or complexity scores. For example editor's three addListener sites execute eleven times (33 registrations). The raw machine baseline is metrics.json. No simplified production code exists in this planning run; every proposed after-value is an estimate.

Reproduce per-file LOC with `git show <base>:<file>` and `git show <head>:<file>` and count splitlines. Reproduce class/call sites with the explicit patterns in metrics.json/method and searches for `.addListener(` / `scheduleMicrotask(`. Added classes mean set difference of class declarations, not every helper function. Input record/typedefs are catalogued below separately.

## Physical LOC and introduced classes

| File (under lib/) | main LOC | PR LOC | Added classes | Listener sites | Microtask sites |
|---|---:|---:|---|---:|---:|
| ui/admin/auth/view_models/admin_auth_view_model.dart | 165 | 343 | — | 4 | 2 |
| ui/admin/submissions/view_models/admin_submission_editor_view_model.dart | 973 | 1550 | _EditorLane, _EditorExecution | 3 | 3 |
| ui/admin/submissions/view_models/admin_submissions_view_model.dart | 151 | 544 | _AdminExecution | 3 | 4 |
| ui/category/view_models/category_view_model.dart | 152 | 221 | — | 2 | 2 |
| ui/content_submission/view_models/content_submission_view_model.dart | 1038 | 1500 | _SessionRequest, _RemoveRequest, _SubmitRequest | 3 | 3 |
| ui/event/view_models/event_view_model.dart | 248 | 364 | EventDayRequest | 3 | 2 |
| ui/explore/view_models/explore_view_model.dart | 37 | 87 | — | 1 | 2 |
| ui/explore/view_models/suggestion_view_model.dart | 44 | 88 | — | 1 | 2 |
| ui/favourite/view_models/favourite_view_model.dart | 266 | 341 | — | 3 | 2 |
| ui/geo_map/view_models/geo_map_view_model.dart | 487 | 592 | GeoMapMarkerRequest, GeoMapMarkerOutcome | 3 | 1 |
| ui/post/view_models/post_view_model.dart | 88 | 138 | — | 1 | 2 |
| ui/search/view_models/search_view_model.dart | 188 | 407 | _HistoryMutation, _HistoryWriter | 4 | 3 |
| ui/settings/view_models/settings_view_model.dart | 44 | 101 | — | 1 | 2 |
| ui/settings/view_models/theme_view_model.dart | 76 | 135 | — | 1 | 2 |
| ui/sync/view_models/sync_view_model.dart | 52 | 104 | — | 2 | 2 |
| utils/command.dart | 159 | 159 | — | 0 | 0 |
| utils/restartable_command.dart | 216 | 216 | — | 2 | 3 |
| utils/result_command.dart | 57 | 57 | — | 0 | 0 |

Fifteen VMs: **4,009→6,515 (+2,506)**. Shared utilities: **432→432**; combined **4,441→6,947**. Eleven new class declarations occur in the VMs (2 Editor, 1 dashboard, 3 Content, 1 Event, 2 Map, 2 Search). These are not eleven unnecessary classes: Content request classes and Event/Map immutable request/outcome classes retain concrete contracts. CategoryLoadRequest and other typedef/records are not counted as classes.

Main consumer LOC (same physical-line method):

| Consumer | main | PR |
|---|---:|---:|
| lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart | 973 | 1226 |
| lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart | 347 | 436 |
| lib/ui/content_submission/widgets/content_submission_screen.dart | 515 | 714 |
| lib/ui/content_submission/widgets/content_submission_progress_screen.dart | 178 | 246 |
| lib/ui/search/widgets/components/app_search_anchor.dart | 376 | 463 |
| lib/ui/category/widgets/category_content_and_type_selection.dart | 247 | 251 |

## Semantic coordination inventory

This inventory counts named owner fields **by their role**, excluding dependency references, command handles, stored domain collections and ordinary editable values. It intentionally includes cached command snapshots and semantic authority revisions because those are coordination state. Names make counts auditable; template-local fields and lexical closure flags are counted separately, not multiplied into owner totals.

| Principal owner | main fields | PR fields | Explicit field inventory / provenance |
|---|---:|---:|---|
| Admin editor | 3 | 11 | main: _disposed,_previewGeneration,_hydrationRevision. PR adds _nextExecution,_draftRevision,_editorRevision,_savedExecutionId,_savedDraftRevision,_candidateRevision,_notifyDepth,_superDisposeQueued. Eleven lane holders are additional resource containers, not included in the 11. |
| Dashboard | 5 | 20 | main: _disposed,_unignoredPendingId,_refreshingAfterUnIgnore,_loadRequest,_ignoredLoadRequest. PR: three *Snapshot; _submissionRead,_ignoredRead,_mutation; _removePublic,_removePrivate,_released; _disposed,_postCommit,_nextExecution,_unignoredPendingId; seven _editor* fields listed in D2. |
| Search | 1 | 8 | main: _disposed. PR owner: _disposed,_history,_detached,_requested,_attempted,_physicalRead,_readerTurnQueued,_readerReleased. Separate writer state listed below; _historyReader is a command handle excluded here. |
| Content Submission | 9 | 21 | main: _disposed,_persistedDraftState,_initializationFuture,_lifecycleTail,_stagedStateAvailable,_stagedReconciliationError,_recoveryEligibleClientSubmissionId,_submissionFinalizationPending,_activeSubmissionClientSubmissionId. PR adds _initializationTicket, five request slots, _runningForwarders and five cached snapshots. _draftLoadError and _loadState are presentation/domain failure state, excluded consistently. |
| AdminAuth | 2 | 11 | main: _disposed. PR: _disposed,_loginSnapshot,_logoutSnapshot,_publicObservers,_observers,_active,_credentials,_actionSettled,_barrierQueued,_released plus _subscription. Subscription existed on main and is included consistently: **2→11**. |
| GeoMap | 3 | 6 | main: _disposed,_mode,_nearbyTerminal. PR adds _markerRequest,_markerTerminal,_markerStatus. Existing semantic _mode remains necessary. |
| Event | 7 | 9 | main: _loadedDate,_loadedDateRevision,_yearlyRevision,_disposed,_homeRefreshPending,_homeRefresh,_commandWaits. PR adds _currentDayRequest,_homeCompletion. Request fields date/revision/candidate/cacheable are separate immutable input, not owner fields. |
| Category | 0 | 1 | PR _disposed; immutable combined filter request and read/sort commands add no local epoch/scheduler field. |

No cross-owner total of semantic coordination state is used as a target.

Template/local protocol inventory at PR:

- `_EditorLane`: 8 declarations (command, snapshot, current, executionId, removePublic, removePrivate, released, settlements), eleven stable instances. `_EditorExecution`: 10 (id, candidateRevision, contextRevision, action, publish, started, actionSettled, settled, queued, revision) per admitted work. Semantic input revisions are retained in request captures; physical witnesses are removed by S03.
- `_AdminExecution`: 12 (id, command, read, token, completion, terminal, started, actionSettled, settled, queued, revision, normalTerminal). R03 removes 3; S01 removes separate editor batching, not the mutation receipt protocol.
- `_HistoryWriter`: 13 excluding command/repository: onChanged,_pending,_base,projection,_known,_uncertain,_detached,_released,_turnQueued,aborted,epoch,_active,_drain. Getters are not counted as stored fields. `_HistoryMutation` adds query/add/settled (3); settled is its per-obligation coordinator.
- Ordinary cleanup closures: queued,invalidated,released plus listener/callback capture in each implementation. They are lexical state, not owner fields. No reduction claimed under N01.

## Custom queues, schedulers and barriers

| Feature | main → PR protocols | Planned change |
|---|---|---|
| Dashboard | ordinary refresh wait references → receipt settlement barrier + editor revision drain + post-unIgnore phase | remove only editor drain; retain safe mutation phase and settlement |
| Search | independent legacy add/remove → ordered writer/drain + optimistic projection + revision-aware reader, with per-role post-turn bridges | one write-only Future tail + small completion callback; independent ordinary read admission, no read demand scheduler/projection |
| Editor | legacy per-command exclusion/context generation → generic eleven-lane receipts + revision-rescheduled settlement | fixed commands/captured inputs + one local post-turn completion per command; no revision barrier |
| Content Submission | lifecycle persistence tail already on main → same tail + five safe-release closures/forwarding | KEEP, no new queue/removal |
| Event | Home coalescing/waits already on main → same Home protocol adapted to new commands + waiter completion | KEEP; do not attribute original scheduler to migration |
| Auth | ordinary login/logout → shared gate + settlement callback + session correlation | KEEP |
| Category/simple/Post/Sync | ordinary feature actions → same observable actions + safe-release closures | KEEP |

These are named mechanisms, not a misleading total of every `await`/Completer. Editor has 33 permanent registrations (3×11) today; proposed 11 (1×11), a **design estimate until implementation**, plus ordinary VM/UI subscriptions that stay. Content has five results + five running forwarding registrations; no saving is claimed. Physical diagnostic probe references: 30 lines in 3 editor test files. Foundation child counter references in modified feature tests: 12 lines across 4 files; keep those unless a retained behavior oracle truly replaces them.

## Estimated reductions, not measured after-state

| Increment | Estimated production LOC removed net | State expected to disappear |
|---|---:|---|
| R01/R02 marker duplication | 3–10 | 1 ticket per request, 1 stored status |
| R03 + S01 dashboard | 75–100 | 7 editor drain fields + 4 unused declarations (3 receipt, 1 owner); entire revision waiter/drain |
| S02 Search | 120–190 | 2 projection/helper classes replaced by a record; 13 writer-state fields and 7 reader/owner coordination slots replaced by tail/current waiter/failure/stopped flag and ordinary read state; exact after-count measured later |
| S03 + R04 editor | 100–230 | 2 physical protocol classes, revision/barrier witnesses, 4 debug getters, 22 of 33 permanent listener registrations; semantic captures/effect IDs retained |

Indicative combined range: **298–530 net production LOC**; ranges are judgment estimates grounded in currently identified blocks, not an acceptance threshold. R04 is included in S03. Test reduction is deliberately not predicted: keep mixed behavior cases and replace relaxed-policy tests, so useful new recovery tests can offset deleted topology assertions. No artificial percentage target. After implementation record actual same-method LOC, field inventory, subscriptions and removed oracles next to this baseline.

## Measured local implementation

The original tables and estimates above are the frozen planning baseline. The following values are measured from the uncommitted implementation using the same physical-line/class/call-site definitions; no implementation checkpoint has been committed or published. The published PR checkpoint remains unchanged. `metrics.json/post_implementation` contains the complete same-file measurements, including unchanged foundation and other ViewModels.

| File | PR LOC | Implemented LOC | Net reduction |
|---|---:|---:|---:|
| GeoMap ViewModel | 592 | 591 | 1 |
| Dashboard ViewModel | 544 | 443 | 101 |
| Search ViewModel | 407 | 241 | 166 |
| Admin Editor ViewModel | 1550 | 1505 | 45 |
| All fifteen migrated ViewModels | 6515 | 6202 | 313 |

The Search anchor grows by 29 lines for live popup presentation and read-only recovery. Net production reduction across all five touched files is **284 lines**. Main's fifteen-ViewModel baseline remains 4009 lines. Shared Command foundations are byte-identical. Four private classes disappear and no class is introduced. The 298–530 estimate was not an acceptance threshold; explicit typed Editor snapshots and effect IDs were retained for local readability instead of compressed into another generic state object.

### Measured coordination and observation changes

- GeoMap removes the per-request ticket and stored marker status; request identity and the owner terminal remain.
- Dashboard removes the seven named editor drain fields plus `_nextExecution` and the three unused execution fields. Its persistent reactivation receipt, authorization and post-commit refresh protocol remain.
- Search removes both history helper classes, per-mutation settled Completers, projections, uncertainty/epochs, detached-reader waits and retained read demands. Current stored history coordination is the disposed/stopped flags, two fixed Commands, two release flags, one write tail and at most one active waiter; the original failure and confirmed list are presentation state. A physically pending read does not hold the write tail. Reader and writer retain their small safe completion callbacks. Search listener call sites increase from four to five because confirmed read publication has its own listener; this is recorded rather than hidden by aggregate savings.
- Editor removes all per-execution started/actionSettled/settled/queued/revision witnesses, paired physical observation, settlement/disposal counters and four diagnostic getters. Current lifecycle bookkeeping is one reservation identity set (at most eleven entries), one permanent released identity set (at most eleven), a stable observer-detachment map and an assertion-stop flag. Eleven fixed typed Commands, typed public snapshots, logical effect IDs and semantic draft/context/candidate/preview/hydration revisions remain. Permanent Command listener registrations fall from **33 to 11** (three sites versus one, each bound to eleven fixed Commands).
- Eliminated named protocols are the Dashboard editor revision drain, Search projection/rebase/writer-drain coordination, Search read-demand scheduler and Editor revision-rescheduled settlement barrier. Local post-turn disposal/reporting boundaries and the write-only FIFO tail remain; this is not a claim that all asynchronous coordination disappeared.

### Behavioral regression coverage

Map changes only its redundant ticket-oriented test name. Dashboard revision-demand tests are replaced with busy refusal, sequential refresh and manual recovery while persistent reactivation cases remain. Every original Search case remains with narrowly adapted approved policy expectations; four rendered-history/independent-write cases are added. Editor removes physical topology assertions and assertion-reuse expectations, retaining the directed matrix, semantic captures, phase I/O, original failures, once-only effects and routing cases; E6/E11 and public stack-metadata assertions strengthen the directly affected contracts. No skip is added. Current executed results and negative controls are recorded once in `implementation-verification.md`.
