# Design

## Context — historical planning baseline

The planning sections distinguish **OBSERVED** source/checks, **INFERRED** timing risks and **PROPOSED** future implementation. They did not claim implementation/test completion at planning time. Implementation evidence and the later publication record follow separately.

### Baseline, provenance and isolation

**Observed 2026-10-23:** `xmattjus/moliseis` [PR #12](https://github.com/xmattjus/moliseis/pull/12) was open/Draft; head `codex/migrate-legacy-commands` = `f48a08946c9ac40146104a0157556243ad433c92`, base `main` = `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. The user authorized that baseline after the previous stop. `f48a0894` had sole parent `da7c426fb799a26094f043319b47e63b98728f92` (checkpoint 4); only change-4 proposal/tasks changed, 19 insertions/11 deletions. No source/test drift required reconciliation; migrations 1–4 were published, unsynchronized and unarchived.

New historical checkout is denoted `<worktree>`, branch `codex/plan-migrate-content-submission-commands`, initial/final planning HEAD `f48a08946c9ac40146104a0157556243ad433c92`. Branch/path were free before creation. Sandbox escalation allowed only required git worktree add metadata; other checkouts were neither checked out, reset nor rebased.

| Existing checkout role | HEAD | Branch | Initial state |
| --- | --- | --- | --- |
| Primary | ee60777 | main | clean |
| Detached auxiliary | ee60777 | detached | clean |
| Simple migration | 9d17d22 | migrate-simple-view-model-commands | clean |
| Category migration | e3d9d89 | codex/plan-migrate-category-view-model-commands | clean |
| Content migration | 1f3753b | codex/plan-migrate-content-view-model-commands | clean |
| Search/Map migration | f48a089 | codex/plan-migrate-search-map-commands | clean |

Six HEAD/branch/status snapshots included untracked/stage entries before creation. Main/cumulative branch and unrelated checkouts were not authorized to move.

### Sources and reproducible references

Paths are repository-relative; positions belong to the immutable baseline.

| Source | Evidence used |
| --- | --- |
| `AGENTS.md`, `.codex/agents/*.toml`, `openspec/config.yaml`, openspec-propose skill | Repository rules/read-only delegation/spec-driven schema; no extra context/rules or nested AGENTS. |
| `migrate-simple-view-model-commands/{proposal,design,tasks,specs/command-execution-concurrency/spec}.md` | Ordinary/progression/reporting/cleanup/consent; historical planning separate from apply appendices. |
| `migrate-category-view-model-commands/` (four artifacts and delta) | Snapshots/owners, restartable retrieval versus ordinary sort, dialogs/filters. |
| `migrate-content-view-model-commands/` (four artifacts and two deltas) | Event/Home/Post/Sync; no new post-disposal phases, current feedback/replacement. |
| `migrate-search-map-commands/` (four artifacts and two deltas) | Admission before action, separate Search writer obligations, latest-intent markers; f48a0894 publication reconciliation. |
| `openspec/specs/command-execution-concurrency/spec.md` plus deltas 1–4 in order | Effective cumulative contract: change 1 ordinary MODIFIED already qualifies completion-only canonical. |
| Canonical `content-submission-{draft-persistence,local-asset-staging,submit-orchestration,navigation-lifecycle,server-idempotency,edge-boundary-validation}/spec.md` | Snapshots, sole arbiter, initialization/staging/idempotency/conservative retry. |
| Entire `lib/ui/content_submission/view_models/content_submission_view_model.dart` | Constructor 99–103; fields 189–201; initialize 207–312; candidate 316–370; add 373–482; remove 485–529; checkpoint/restore/serialize 540–619; setters/temporal 621–730; submit 744–807; prepare 809–857; release/finalize/clear/retire 860–938; recovery 949–1038. |
| `lib/ui/content_submission/widgets/*.dart`, `lib/routing/router.dart:59–193`, `lib/config/dependencies.dart` | Consumers/form/controls/transition ownership/single Provider composition. |
| Existing Content Submission VM/widgets and `test/routing/content_submission_{route,restoration}_test.dart` | All five lanes, restoration, validation, races and UI. |
| `lib/utils/{command,result_command,restartable_command,command_configuration}.dart`; four corresponding test/utils suites; `test/ui/ordinary_view_model_lifecycle_test.dart` | Legacy/factory/snapshot/reporting/disposal limit, upstream behavior and ordinary cleanup/assertion fail-loud. |
| `lib/ui/explore/view_models/explore_view_model.dart:47–86`, Category/Favourite disposal | Concrete local deferred cleanup pattern without new foundation. |
| `lib/domain/models/{content_submission_draft,content_submission_staged_asset,content_submission,submission_asset}.dart`, corresponding repository/mapper/entity code | Deeply immutable draft, fixed ObjectBox ID, staged paths/immutable requests. |
| `supabase/functions/submit-content/{index,submission_store}.ts`, `supabase/migrations/20261001175539_add_event_all_day_semantics.sql`, associated repository/Cloudinary/Edge tests | Auth/validation/atomic RPC, first commit wins, replay acknowledgement/quota; no change needed. |

Initial explorers audited consumers/contracts/foundation read-only; architect addressed actual fixed-ID/disposal ownership ambiguity. Findings were verified against source/canonical, not treated as independent plan review. The later initial review produced F1–F3, followed by remediation and re-review.

### Historical B0 analyzer

Direct installed Flutter Dart SDK **3.13.4 stable macos_arm64** analyzed a fresh temporary Git archive. Only resolved package_config from change 4 was copied; its temporary moliseis.rootUri was resolved to the archive, other roots validated/absolutized without changing destinations. No pub get/upgrade/generation/secrets or other-checkout metadata/dependency writes. Lock/resolved source confirmed **command_it 9.5.2 / listen_it 6.0.0**; no generated output hand-edited.

Historical command, with workstation locations replaced by portable placeholders:

```text
cwd: <worktree>
<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <evidence-dir>/content-submission-planning-B0
```

Measured subprocess **exit 0**, **66 INFO / 0 WARNING / 0 ERROR**, empty stderr; every line LINT/`DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. No --fatal-infos/suppression/config changes. Direct-Dart exit was not a globally clean Flutter-analyze claim.

Historical temporary outputs `<evidence-dir>/content-submission-B0.{stdout,stderr,json}` had stdout SHA-256 `90809e0f3fc65a09568fd976ee9c3c228a1f00a31b0a6807a4b972ec97792c78`. Root-normalized full severity/type/code/path/line/column/length/message Counter comparison against earlier search-map-apply-B1.txt: **66 versus 66, missing=0, added=0**, including multiplicities. B0 was a fresh historical planning run; the earlier log was comparison only. Full durable ledger follows below. Temporary files are not tracked or established as currently accessible; reported results/hashes remain historical provenance, not a claim of present raw-log availability.

| Target | Line:column:length | Meaning |
| --- | --- | --- |
| ViewModel | 99:16:8 | addAsset constructor Command0 |
| ViewModel | 100:21:8 | removeAssetAt constructor Command1 |
| ViewModel | 101:14:8 | submit constructor Command0 |
| ViewModel | 102:13:8 | clear constructor Command0 |
| ViewModel | 103:26:8 | retrieveLostAssets constructor Command0 |
| ViewModel | 189:8:8 | addAsset field Command0 |
| ViewModel | 191:8:8 | removeAssetAt field Command1 |
| ViewModel | 192:8:8 | submit field Command0 |
| ViewModel | 195:8:8 | clear field Command0 |
| ViewModel | 201:8:8 | retrieveLostAssets field Command0 |
| ProgressScreen | 16:24:7 | dartdoc Command |
| ProgressScreen | 131:46:7 | color helper Command |
| ProgressScreen | 139:5:7 | text helper Command |
| ProgressScreen | 154:21:7 | icon helper Command |

These were **14 diagnostics**, not 14 Commands: five constructions, five declarations and four Progress references. Other **52** were AdminAuth 6, AdminSubmissionEditor VM 33, AdminSubmissions VM 9, AdminSubmissionEditor screen 1 and fake_repositories dartdocs 3.

### Five-Command baseline inventory

| Legacy command | Result/consumers | Observed invariant, inferred deferred-entry risk and proposed destination |
| --- | --- | --- |
| addAsset | Command0<AssetSelectionOutcome>; soft-rejection Success/hard Error; AssetList spinner/await-result warning | Checkpoint before picker with free picker gap; post-initialize capture alone misses pre-entry race. Bind session/ticket and observe own terminal snapshot. |
| removeAssetAt | Command1<void,int>; rendered item index/list listener/tests | Existing inline body captured index before await; deferred body could target replacement asset. Synchronously bind session/digest/original invalidity, no-param action. |
| submit | Command0<void>; form checkpoint/fire-and-push, progress/retry/canRetry/tests | Preparation after waits; separate lease/ack; no request-time snapshot guarantee and late post-disposal phases. Bind draft/issue/ordered membership/mode and use arbiter lease/domain-runtime snapshot. |
| clear | Command0<void>; running observed by Screen; tests, no production UI execute | Persistence-first retirement/lease check; stale deferred request must not clear a new ID. Bind target, reuse retirement, stale no-op/live guard. |
| retrieveLostAssets | Command0<void>; Screen post-frame/AssetList spinner/tests | Best-effort platform response read eligible ID too late. Bind initial eligible identity/ticket, early retrieval, guarded commit/distinct terminal. |

Form/event setters, initialize, checkpointDraft and restoreCheckpointDraft remain non-Command APIs. CTA only navigates to form. Date/description/checkbox/fields own no additional target Commands; same-named Admin owners are excluded.

## Goals / Non-Goals

Observe admission without payload/storage changes; bind intent before deferred entry; preserve local order/ownership, error kinds and consumer replacement/disposal with discriminating tests. No extra Command queue, Restartable mutation, framework/global coordinator/cross-owner serialization/schema/repository/Cloudinary/idempotency/ObjectBox/draft-codec/Admin migration, legacy deletion or new form/terms validation. No automatic retry/durable acknowledgement. Foundation/command_configuration unchanged.

## Decisions — approved planning contracts, later implemented

### D1 — Five ordinary lanes with synchronous public admission

Observed command_it 9.5.2 `lib/command_it.dart:312–408`: isRunningSync/loading results synchronous, action after Future.delayed(Duration.zero); busy run ignored. `runAsync:859–870` joins a completer, and `dispose:799–825` may settle it with current value after 50ms. Neither awaiting nor retained value proves a new request succeeded. results is synchronous/isRunning deferred; legacy body entered inline.

Private `_addAssetCommand`, `_removeAssetAtCommand`, `_submitCommand`, `_clearCommand`, `_retrieveLostAssetsCommand` use `ResultCommand<void,T>`/createResultCommandNoParam (T AssetSelectionOutcome for add, void otherwise). Remove resolves index into envelope, not action parameter. Constant nonsensitive debugName uses existing allowlisted `command` reporting context; no configuration extension.

Public API: bool requestAddAsset(), requestRemoveAssetAt(int index), requestSubmit(), requestClear(), requestRetrieveLostAssets(); read-only addAssetSnapshot/removeAssetAtSnapshot/submitSnapshot/clearSnapshot/retrieveLostAssetsSnapshot of `command_it.CommandResult<void, Result<T>?>`; synchronous isAddingAsset/isRemovingAsset/isSubmitting/isClearing/isRetrievingLostAssets from private isRunningSync.value; derived canRetrySubmissionImmediately. The existing VM ChangeNotifier alone exposes observation; no public run/execute/runAsync object. Use actual factory no-param type (void/void? equivalent).

First reject disposed/busy without slot/snapshot/I/O/feedback changes. Otherwise capture D2 target. Ready normal submit registers D2.F2 capture on existing `_serialize` and installs its handler synchronously before run/notifications, with no I/O/lease. Build immutable envelope with Object execution identity and handled Future, assign only its lane slot and run, returning true for admission only. Rejected duplicate registers nothing. Original invalid index is admitted as captured terminal Error and never becomes valid after restore. No rejected-request backlog or waiter framework.

Each lane holds at most one envelope. Action copies slot before first await; cleanup checks identical(slot,envelope) against later reentry. Before effects recheck owner/target after synchronous admission observers. Wrappers may identify initialization ticket without starting I/O/initialize before run.

Implementation-discovered reentry detail: forward running-start/results immediately, but defer only VM sync-running→false notification one microtask. Upstream writes false before value and again in finally; admission inside first idle callback otherwise lets old finally clear a new execution's busy. Microtask completes that stack before exposing idle to VM observers. Getters/admission still read original synchronous state; callbacks recheck disposal/current snapshots, with no queue/new arbiter/cache from old execution.

Rejected: execute→run with action-time snapshots; public runAsync join/false-success; restartable mutations; new façade/dependency.

### D2 — Request snapshots and identified initialization

Observed draft deep immutability (`freezeDescriptionDelta`) versus unmodifiable but live asset getter. Legacy removal captured session/digest before await; legacy prepare captured after initialize/arbiter. Recovery selected eligible identity after lost-data wait, risking attribution to later session.

Ready normal submit captures immutable draft/clientSubmissionId/issue synchronously plus D2.F2 ordered-membership Future; membership is not copied immediately. Remove captures session/digest or original range error; add/clear identity; recovery established eligible identity. XFile freezes record/path/digest reference, not file bytes/existence. Later same-session setters cannot change captured payload.

Loading requests identify one VM initialization ticket and capture provisional draft/issue. Initialization seals immutable outcome before notify/Future completion: restored uses load-result draft plus full reconciled assets/eligible identity; absent retains each request's provisional draft/issue and ticket orphan-reconciliation outcome; unknown/unavailable retains original error. Submit cannot recapture/recover implicitly. Add retains canonical same-identity pre-picker reconciliation retry under the same arbiter; unknown ownership still blocks adoption/orphan cleanup. Bootstrap assertion seals original private Object/StackTrace without secondary unhandled Future error, initialize rethrows and action stays fail-loud with no unresolved-ticket waiter.

Consume only the identified ticket, never arbitrary post-await state/assets. Ready gets assets only at D2.F2; Loading gets ticket list. Restored may legitimately reveal previously unknown persisted draft; absent invents no future assets. Arbiter validates current identity/ticket/staged availability; later rotation invalidates target. Direct pre-initialize add/submit/clear remain supported; originally invalid remove remains Error.

#### D2.F2 — Ordered membership separate from draft snapshot

Initial plan's immediate asset copy could exclude earlier registered X; legacy `_prepareSubmissionAttempt:809–855` copied after arbiter wait and could include later Y. Remediation deliberately includes earlier arbiter registrations and excludes later ones; it is an explicit semantic refinement, **not exact legacy equivalence**. Draft/issue/identity remain request-time.

Registration is synchronous `_serialize` installation of `_lifecycleTail` before first await (`605–609`), distinct from physical closure entry after previous. A prior tap still in deferred entry/initialize/picker with no commit registration is not an earlier staged mutation; guarantee concerns this local arbiter, not global tap/cross-owner ordering.

| Baseline phase | Before await | After await/before release and publication |
| --- | --- | --- |
| `_addAsset` pre-picker 377–409 | Initialize done; register arbiter/reconcile/save | Capture identity only after successful checkpoint; notify may occur before picker. |
| Picker 414–418 | Pre-picker boundary released | Returned selections register separate commit; no runtime asset during picker. |
| `_processAssetCandidate` 325–369 | Capacity, then length/hash/acquire awaits | Acquire success makes staged unavailable; resolve success adds record/restores availability. `_assets.add` precedes release; notify outside may follow capture. |
| `_removeAssetAt` 500–514 | Captured target, registered boundary/remove await | Persistent Success removes digest while live before release; notify follows outside. |
| Legacy prepare 809–857 | Registers after initialize | Reads draft/copies assets, checkpoints/claims; membership post-predecessor but not admission-bound. |
| `_submit` 744–807 | Awaits preparation | Captured sequential uploads/final request outside arbiter, release/finalize at defined boundaries. |
| `_serialize` 605–619 | Installs release Future synchronously | Awaits previous, executes action, finally releases; no own notify and failures do not break tail order. |

Ready protocol: (1) disposed/busy check, immediate draft/issue/identity, one `_serialize` capture registration and attached error handler before envelope/run; no checkpoint/lease/I/O. (2) Closure waits earlier registrations only; validates live/identity/staged state, copies `List<Asset>.unmodifiable(_assets)` inside the closure, or returns existing preparation error/revoked outcome. No notify/ownership/future-action wait, immediate release. (3) Immediate handler transports raw `(Object, StackTrace)` privately (ready/domain/revoked/runtime), without synthetic Result.error/premature reporting/unhandled unawaited Future. (4) Deferred action drains this exact Future even if disposed, preserving Command until settlement without new initialize/I/O. Runtime rethrows original via Error.throwWithStackTrace once; revoked publishes nothing. Ready+live then prepares under same arbiter with captured draft/issue/identity/sealed list; revalidate current identity/availability without recopy. (5) Later Y may commit before deferred preparation but cannot join payload. Later removal may cause normal upload-path failure; clear between capture/prepare rotates identity and produces stale Error with zero old checkpoint/upload/final request; owned preparation instead rejects clear.

Capture is one read-only entry on the existing tail, not another queue/mutex/writer/coordinator/revision log or HTTP/picker wait. Finalization-only registers no membership capture. Loading registers no closure waiting for unstarted initialization: live action initializes outside arbiter and uses ticket restored/absent list; every mutation initializes before registration. Bootstrap reconciliation is ticket work, not concurrent mutation. Post-ticket mutations do not change list; later rotation fails guard. Disposed pre-entry Loading starts no initialize/reservation.

Earlier acquire Error leaves available prior membership: add fails, independent submit may succeed. Acquire Success then resolve Error leaves staged unavailable/list cleared (`349–366`), so capture/preparation fail before upload/submit. Predecessor tail propagates release, not another lane's action error; raw failure remains its own runtime. Revalidate actual post-boundary availability, not mid-acquire state.

Rejected: immediate list (loses X), deferred prepare list (includes Y), whole preparation at request (premature lease/checkpoint), digest filtering of incomplete list, second queue/epoch. Standalone checkpointDraft()/restoreCheckpointDraft() stay Future<Result<void>> with capture **inside** arbiter, no retired-identity resurrection. Bootstrap retains deliberate non-assertion read/reconcile normalization and no duplicate reporting; assertions remain raw per D5.F1.

### D3 — `_serialize` is the sole local arbiter

Five independent single-flight lanes are not cross-lane exclusion. Order is arbiter registration, not all taps. Add initializes, serializes pre-picker identity/known-ownership/reconcile/checkpoint, picks outside and serializes guarded candidate commit; unchanged SHA-1 dedup, 10MB, maximum five, soft rejection and filename-free UI. Remove persists captured digest first under same session, then live-list update; missing/retired target is a no-op without selection feedback. Submit captures at F2, then validates identity/staged availability/existing eligibility, checkpoints exact captured draft and claims lease after post-await/notify owner checks, before arbiter release; uploads remain outside. Clear rejects active/pending owner, stale target no-ops; persistence-first live success cleans/rotates once. Successful clear under unknown persisted state permits orphan cleanup, not adoption. Recovery binds eligible identity/ticket before Android retrieval outside arbiter, possibly during initialize; commit requires same target/available staged/live owner and existing candidate processing. Non-Android retrieve=0.

Use try/finally release exactly once with original exceptions, removing generic Exception/Object→Result catches. Direct checkpoint/restore may throw unexpectedly; UI/router boundary D5 owns reporting. Capture transition token/release before await. Pre-ack matching lease release is private assignment under same arbiter, with no storage, even after disposal. Reject generic catches merely for completion, picker/HTTP inside arbiter, Search-style second FIFO or banning canonical same-session edits during submit.

### D4 — Submission preparation, ownership, acknowledgement and retry

Capture normal versus finalization-only mode/acknowledged ID at request and never reinterpret after await. Normal Ready alone captures F2. isSubmitting rejects duplicate lane. Before ack, only successful preparation installs active ID; earlier clear may rotate and invalidate, later clear must reject without I/O. Admission itself claims no lease because checkpoint can fail.

Sequential captured uploads stop at first Result.error; check live owner before each/remote request. Later removal may fail upload normally; no recapture/new assets. Same-identity edits/additions survive failure or retire together on success, without copying edit B into fresh identity. try/finally spans owned work and releases matching pre-ack lease for domain/malformed acknowledgement/raw/assertion, preserving original object/stack per D5.F1.

On live remote Success, record pending/acknowledged identity before first finalization await. Local failure thereafter retains ownership. `_finalizeSubmittedSession(expectedId)` validates pending/owner/current identity before destructive I/O and reuses retirement, not public clear Command. Only live local success rotates once and produces Success<void>(null). Existing staged-cleanup Result.error remains best-effort after successful draft clear; raw cleanup remains runtime/pending with idempotent local retry.

Retry is `!isSubmitting && submitSnapshot.hasFailure && submissionFinalizationPending` for current owner, covering domain/handled-runtime finalization failures without fabricated domain Error. Admission clears old presentation immediately; retry performs no prepare/checkpoint/upload/submit. Pre-ack failures have no immediate `Riprova`: return through validated form with same identity. Preserve legacy/hardened rollout without parsing messages/probes/hidden retries.

External contracts unchanged: draft UUID v4, local SHA-1 dedup/Cloudinary SHA-256 reuse, feature-owned staged paths, ObjectBox fixed draft ID, Edge auth/allowlist, atomic submit_content content/assets/quota RPC, user/identity-scoped first-payload replay and repository-validated positive acknowledgement. No Cloudinary deletion/rollback.

### D5 — Errors, terminal state and disposal

| Provenance | Outcome/reporting/retry |
| --- | --- |
| Repository Result.error, validation/range/stale-session | Original domain Error; no extra CommandExecutionFailed; no pre-ack immediate retry. |
| Expected direct picker/recovery PlatformException or candidate-read FileSystemException | Add original Error + feature log; recovery logged best-effort Success, no global runtime. |
| Unexpected StateError/TypeError/Exception/Object reaching action/arbiter | Original runtime/stack, configured global once; retry only with pending ack. |
| Finalization Result.error/raw after ack | Real domain/runtime kind; preserve pending/owner, local-finalize retry only. |
| AssertionError | Upstream fail-loud, no promised normal failure UI/retry; development diagnostics. |
| Initialization non-assertion read/reconcile normalization | Existing ready-unavailable/unknown quarantine, no duplicate global; assertion remains raw. |
| Direct checkpoint/restore Future raw outside Command | Throw to caller, no fabricated Result; UI/route FlutterError once, no submit/push/exit. |

#### D5.F1 — Catch audit and normalization ownership

Verified cause: `_removeAssetAt:522–530` had its own broad Exception→feature log/Error; changing only `_serialize` would leave F1. Classify provenance boundary, not Exception type.

| Actual baseline boundary | Required correction/preserved contract |
| --- | --- |
| `_initialize` 207–259 | Preserve deliberate Object quarantine for non-assertion read/reconcile and unknown/absent distinction; rethrow AssertionError before normalization, seal original private runtime ticket, settle waiters/finally. |
| `_reconcileStagedAssets` 265–312 | Preserve original reconcile/resolve Result errors and domain count/path validation. Inside initialize use bootstrap boundary; initialized pre-picker raw reaches Command, even repository FileSystemException. |
| `_addAsset` 373–483, broad catch 474–482 | Remove broad catch. Expected PlatformException only around picker; expected file failure only around direct reads. Raw checkpoint/acquire/resolve/logger/policy remains runtime. |
| `_processAssetCandidate` 316–370 | Capacity/size/dedup are dispositions. Catch FileSystemException only at direct XFile.length/openRead, retaining original stack/provenance; repository throws remain raw even same class/PlatformException. |
| `_removeAssetAt` 485–530, broad catch 522–530 | Remove catch without replacing with file/plugin catches: only repository Future<Result<void>> is called. Preserve Result.error; every contract throw remains original runtime. |
| Checkpoint/restore 540–603 | Preserve save Result.error and successful live checkpoint baseline only; raw propagates through arbiter to Command or direct caller boundary. |
| `_serialize` 605–619 | Remove Exception→Error/Object→wrapper; previous is infallible release Future; try/finally release once with no I/O/log/await, preserving Exception/Error/Object/AssertionError. |
| Submit 744–807 / prepare 809–858 | Preserve domain prepare/upload/submit error; raw stays runtime; matching lease release preserves primary. |
| `_releaseSubmissionOwnership` 860–867 | Same arbiter, matching private assignment, idempotent; no await/storage/logger/notify inside closure. |
| Finalize 869–892 / clear 894–912 / retire 914–938 | Draft clear Error blocks; staged-cleanup Results intentionally best-effort. Raw clear/reconcile/clearSession remains runtime; pre-ack release, post-ack ownership/pending retained. |
| Recovery 949–1038, retrieval 957–960 | Narrow Object→Success to expected PlatformException from retrieveLostData only; preserve response.exception log+Success 970–976 and empty no-op; unexpected plugin Exception/StateError remains runtime. |
| Recovery processing 993–1030, processed Error log 1015–1017 | Remove broad Object catch; expected staging Results/direct file failure stay best-effort/no UI, raw repository/helper/logger reports once, never fabricated Success. |
| Existing draft/staged repositories | Preserve infrastructure normalization/logging and acquire temporary cleanup protecting primary; do not copy broad repository catches into VM. |
| Existing submit repository/Cloudinary task | Preserve FunctionsFetchException/normalized FunctionException/format/transport boundaries, bounded reuse/retry and already-unawaited transaction.finish; no claim to fix telemetry-cleanup limits. |
| New Ready membership capture | Handler installed immediately, transports raw private pair without global/Result.error; action rethrows original once. |

Expected remove error already logs ContentSubmissionAssetRemovalFailed in `ContentSubmissionStagedAssetRepositoryImpl.remove:141–169`; VM adds neither that event nor global. Raw remove/other repository failures produce only CommandExecutionFailed at Command boundary. Direct picker/file failures retain ContentSubmissionAssetAddFailed or ContentSubmissionAssetRetrievalFailed with original pair, no global; soft size/capacity rejection stays successful generic warning without filenames.

Shared direct-read helper privately carries `(FileSystemException, StackTrace)` provenance; never catch whole candidate helper including repository awaits. Add logs once/returns original Error; recovery logs once/completes best-effort. Existing recovery context on repository Results may remain, without duplicate direct-file events/global reporting. This is feature-local data, not new repository/error framework.

Raw failures preserve original Object/stack via rethrow or Error.throwWithStackTrace, never Exception(error)/toString/new stack/Result.error. command_it detailedStackTraces may decorate: sentinel tests locally save/disable/restore it; real-configuration test retains original frames. Global receives original Object once without sensitive parameters.

Primary/cleanup precedence: tail release completer completes once without fallible work. Record primary success/domain/raw/assertion before awaiting matching lease release. On successful release preserve primary. Secondary release failure with existing primary failure reports separately through constant-context FlutterError, never replaces original Command outcome or adds duplicate primary CommandExecutionFailed. Without primary failure, cleanup throw becomes execution runtime. Even secondary reporter failure cannot mask primary; final primary delivery happens in finally. Primary assertion rethrows; secondary assertion remains visible in development diagnostic channel. No I/O retry/early disposal/lease cancellation.

E1/E2 extend existing staged fake removeResult/pendingRemove (`test/support/fake_repositories.dart:1238–1324`) with controlled direct `Exception('unexpected remove')`/stack, not a parallel fake. Live E1: unexpectedError identical, domainError null, sentinel frames retained/global=1/no duplicate AssetRemovalFailed, unchanged A/path/digest, later independent checkpoint enters. E2: physically pending remove→dispose→Exception beyond virtual 50ms: same private original/report, no public snapshot/notify, unchanged asset and cleanup once. New public work after disposal is prohibited; arbiter availability is proved live in E1. Original Result.error removal test at VM 1956–1975 stays distinct/global=0. E4 original bootstrap assertion/stack stays fail-loud, no synthetic terminal/downstream I/O or stranded ticket. E3 proves primary raw/assertion unchanged after release and subsequent independent clear; static secondary-path review avoids invented fallible-storage seam.

Screen `_submit`/`_openExternalLink` and router onExit await direct Futures outside Commands: catch at that narrow UI boundary, FlutterError.reportError original once/constant nonsensitive context, rethrow assertions. No later submit/launch/push/exit; generic feedback only while mounted/current owner/session; release captured token in finally. Existing router Object catch needed reporting; Screen finally-only needed boundary handling after arbiter broad catches were removed. Direct non-UI callers receive/own the raw throw with no duplicate VM reporting.

Disposal is idempotent: mark/revoke forwarding before teardown, guard after every await/notify and before length/hash/acquire/resolve/remove/checkpoint/upload/final request/clear/cleanup. Revocation prevents new phases, not already-started I/O cancellation. Internal neutral revoked outcomes never imply public success.

| Revocation moment | Allowed private settlement | Prohibited next phase |
| --- | --- | --- |
| Before action entry | Terminal/cleanup only | Initialize or any action I/O. |
| Draft load/reconcile/checkpoint pending | Already-started I/O | Next phase/commit/notify. |
| Picker/candidate/remove pending | Private outcome | New hash/acquire/resolve/list update. |
| Upload pending | Current outcome, private pre-ack lease release | Next upload/final request. |
| Final request pending | Outcome/valid private ack | New finalize/clear/cleanup/public success. |
| Draft clear pending | Its settlement | New staged cleanup/rotation/notify. |
| Staged cleanup pending | Its settlement | Rotation/notify. |

This deliberately hardens legacy submit/retirement that could continue phases after disposal. Orchestration delta qualifies finalization with live owner; navigation cannot publish dead-owner success. Late acknowledgement is neither persisted nor transferred to B, but actual remote success is not denied/rolled back. A new owner may restore persisted draft/assets idle; explicit later submission uses existing idempotency/rollout, without cross-process HTTP exactly-once promise. Already-started clear may leave no draft; next initialization reconciles orphans.

Ordinary cleanup reuses Explore/Category/Favourite: retain pending private Command, revoke public VM forwarding, queued/invalidated/released listener on sync-running, microtask+event barrier, recheck idle/reentry, detach/dispose once outside dispatch/reporting/finally. Include never-run/idle/terminal-observer cases; defer super.dispose outside notifier dispatch. No real test timers. Keeping Command live through settlement avoids upstream post-50ms late-throw bug; assertion cleanup follows sync-running fall, not an unguaranteed normal terminal.

Public presentation caches start neutral, update before live VM notify, observe sync-running descent for retry/canPop and freeze on disposal. No private Command results/listenable exposure; detach forwarding before ChangeNotifier teardown while private cleanup listeners remain until settlement. D1 defers idle forwarding for verified reentry safety.

**Cross-owner limit:** arbiter is per VM; clearDraft deletes unconditional fixed ID 1. Already-started old save/clear can interfere with replacement writes. Gates stop new phases after disposal, not cross-owner serialization/CAS. Fixing storage coordination is outside scope; rebinding does not solve it.

### D6 — Consumers, progress, routes and replacement

Baseline AssetList 36–44,91–132 created merged listener once and awaited execute/read result; item callbacks used index. Replace with existing VM observation/rebind, request methods and warning only for its own accepted current terminal. Item/AddAssetButton retain component/Image.file boundaries. Screen 44–81 lacked didUpdateWidget: detach A/attach B, invalidate callbacks and reset both Form keys even equal client ID; one current-owner recovery bootstrap. Screen 133–183 retains validate/token/checkpoint then accepted requestSubmit before push, guarding mounted/owner/session after await **and synchronous admission**. Screen 204–215 observes projected clearSnapshot/running from admission, no deferred false-ready. Progress 45–120,131–160 uses Result-aware neutral/running/domain/runtime/completed plus VM pending/current owner; retry 92–96 requests captured finalization-only with current guards. Router 109–193 preserves routes/tokens, verifies context mounted/current Provider owner/session after dialog/await before save/restore/feedback/true, finally releasing captured token. Provider composition/initialize ownership unchanged. VM canRetry 146–154 follows D4. Tests use bool admission + explicit entry/terminal, not retained value.

Production UI has no clear.execute consumer: `Esci senza salvare` uses **restoreCheckpointDraft**, not clear. Fields/date/description/checkbox/CTA/temporal methods acquire no new Commands.

#### D6.F3 — Removal callback before admission

Keep minimal `requestRemoveAssetAt(int index)`; D2 protects post-request but cannot reinterpret stale rendered A as current B. AssetList itemBuilder captures final renderedOwner/renderedClientSubmissionId/renderedDigest/renderedIndex **outside** closure. Invocation synchronously: `if (!mounted) return;` before State/widget/context; require identical widget owner and same captured session; bounds-check captured owner's current list and digest at captured index; only then requestRemoveAssetAt. No intervening await/notify permits async gap. Failed guard returns with no request/slot/snapshot/running/feedback/repository change; do not search A elsewhere or dispatch against new owner. Equal client IDs do not bypass owner identity. After admission VM targets original digest or no-ops if reordered.

Ordinary rebuild with same owner/session/position/digest preserves valid callback; no build epoch/invalidation of every closure. Tests retain actual old onRemove before obtaining [B] and invoke it, rather than tapping rebuilt widget. Replacement/rotation has zero calls to both repositories; retained valid callback removes once after persistent Success. No new public digest/session API needed in one synchronous isolate; View validates represented target, VM owns arbitration/persistence/publication.

Add feedback installs VM listener before admission, local selection marker and running→own-terminal recognition consumed once. Busy guard precedes marker so ignored tap cannot replace original. Require mounted/current owner/captured or ticket-sealed session before snackbar, including reentry in same notify stack. No runAsync+retained value. Filename privacy unchanged.

Screen didUpdateWidget uses local callback generation and operation-owned boundary pending: old finally releases captured token without clearing B pending. Post-frame/iOS allowance captures owner/generation and checks mounted before State access. New form never replays A edits/reset even same identity. Router checks Provider even before widget rebind; stale dialog decision fails closed false and releases token, never removing B route. Preserve Save/Discard/Cancel, iOS/predictive/central exit, no cleanup from Back/Home/new suggestion.

Progress uses isSubmitting || snapshot.isRunning to cover pre-entry/terminal-before-sync-idle; terminal controls success/error, never retained value. New admission supersedes old UI before push. canPop requires no running/pending; hide Home/other exits then. Live success resets underlying form to fresh session once; navigation never clears twice. Process-restored new owner remains idle, returns to form and never auto-resumes.

### D7 — Cumulative compatibility 1–4

OpenSpec 1 supplies independent ordinary single-flight, permitted optimistic/progressive guarded commits and no post-disposal new phases; no blanket completion-only/invented rollback. Category supplies snapshot/owner/session binding without restartable asset/submission mutations. Content supplies current feedback/admission without Home coordinator/factories. Search supplies pre-action intent binding and physical/UI lifecycle distinction, but **its surviving writer obligations and second FIFO do not transfer to Submission**. F2 uses existing tail, F1 preserves real error kind and F3 only adds consumer validation before VM guard.

Read unsynchronized canonical plus deltas 1–4 in order. Feature additions and full MODIFIED Durable submission attempt, Finalization-only retry, Immediate retry availability (orchestration) and Confirmed remote success (navigation) preserve every pre-existing scenario. No general ordinary/Search exception rewrite or canonical write.

## Historical regression matrix and oracles

At planning time these were **future tests**, with explicit Completer/virtual-clock gates, no infinite/wall-clock sleeps. New races must fail without their guard/snapshot for expected payload/identity/I/O/report reasons. Extend existing suites without weakening assertions. Baseline VM groups: remove 1763+, disposal 2060+, recovery 2272+, submit 3378+, ownership/race 3979+, clear 4526+; existing snapshot Cloudinary-gap tests 3740+, screen transition 453–523, VM ownership 3979–4183, route retirement 427–521. These were source evidence, not new executed results. Same-State replacement was explicit robustness, not claimed proven production regression with app-scoped Provider/restoration rebuilding tree.

| ID | Controlled order and discriminating oracle |
| --- | --- |
| A1 | Two same-lane requests before entry: true/false, one action/I/O, original slot; all 5 lanes. |
| A2 | Admission→result observer disposes pre-entry: initialize/picker/repository=0, cleanup=1. |
| A3 | Submit A→edit B before timer: checkpoint/payload A, B dirty on failure; captured issue cannot overwrite later valid B. |
| A4 | Request A loading→restored R→clear C before entry: no C adoption/remote for stale target. |
| A5 | Loading absent request A→edit B while waiting: payload A/B dirty after failure, load/reconcile once. |
| A6 | Loading restored/edit during reconcile: ticket load draft/ordered assets, not arbitrary edits. |
| A7 | Invalid remove index→valid restored list: original Error, remove=0. |
| A8 | Captured remove A→list reorders/removal: remove A or no-op, never replacement occupant. |
| L1 | Pre-picker save pending→queued clear: save A precedes clear A, no late old save, one arbiter. |
| L2 | Picker A pending→clear A→B→picker return: no hash/acquire/warning or B mutation. |
| L3 | Acquire A inside boundary→clear: acquire/resolve before clear, clean B. |
| L4 | Normal add/recovery same digest/capacity: local order/dedup/maximum five/10MB/staged paths. |
| L5 | Recovery before/after init/clear (three permutations): only ticket eligible identity; absent/unknown/B acquire=0. |
| L6 | Arbiter Object/StateError→second mutation: original stack/global=1, release permits second. |
| L7 | Standalone checkpoint/restore versus clear: no retired-identity save, dirty/checkpoint invariants. |
| S1 | Captured A save pending→B→prepare: save/remote A, owner claimed before release, B dirty on failure. |
| S2 | Clear before prepare A: clear once, submit Error/remote=0, B unchanged. |
| S3 | Prepare entered→queued clear: clear Error, clearDraft/cleanup=0, owner A retained. |
| S4 | Upload/final request pending→external clear: Error/no I/O; pre-ack failure releases lease so later clear possible. |
| S5 | Upload A1 pending→same-session edit/remove/add: captured membership, edits survive failure/retire with success. |
| S6 | First upload Result.error/raw/assertion: no next upload/final request, matching lease release/correct reporting. |
| S7 | Checkpoint domain/raw failure: remote=0, original error/stack, no stranded lease. |
| S8 | Final domain/malformed/raw: no finalize, same ID/assets, global raw only, later clear possible. |
| S9 | Ack→repeated draft-clear Error→retry success: remote=1, uploads=N once, checkpoint=1 or known-durable skip, retry clear-only/rotate=1. |
| S10 | Ack→raw finalize: runtime/global=1, pending retained, local retry/no resend. |
| S11 | Ack A with mismatched identity/owner: clear/cleanup/rotation=0, pending retained; defensive probe distinct below. |
| S12 | Ack→cleanup Result.error: existing best-effort, no duplicate retirement/backend retry. |
| P1 | Accepted submit→push pre-entry: immediate running, no Back/Home/interrupted-idle. |
| P2 | Retry admitted pre-entry: old error hidden/retry disabled; duplicate no extra clear. |
| P3 | Neutral/Success<void>(null)/domain/runtime/pending: distinct states/correct retry/back, null never inferred success. |
| P4 | Validation/temporal/checkpoint failure: request/push=0, unchanged feedback. |
| P5 | Submit/external boundary versus AppBar/system/predictive/go: token winner excludes overlap; finally releases on failure/cancel. |
| P6 | Process restoration to progress: idle, no auto-submit/clear/retry; Back retains draft ID/staged assets. |
| P7 | Success under form→Back/New/Home: fresh clean/empty, no stale onChanged, clear/rotate once. |
| P8 | Direct raw checkpoint/restore in submit/link/onExit live/replaced/disposed: original FlutterError once, no submit/launch/push/exit, token release/no stale feedback; assertion fail-loud. |
| B1 | Retained State A→B same/different ID: detach A/listen B, reset keys, A notifications ineffective. |
| B2 | A picker warning pending→B→A terminal: A snackbar=0/no B effect. |
| B3 | Post-frame recovery A→replacement/unmount: A retrieve=0, B bootstrap=1 only mounted; no post-unmount widget access. |
| B4 | A checkpoint/dialog pending→Provider B before rebind: no old submit/launch/exit or B mutation; token released. |
| B5 | A finally after B boundary starts: cannot clear B pending/generation. |
| D1 | Every D5 revocation window: only started phase settles, no next phase/public feedback/notify. |
| D2 | Late Success/domain/StateError/ArgumentError/Object beyond virtual 50ms: original raw global=1/domain=0/each lane cleanup=1. |
| D3 | Terminal/VM observer disposes or admits during barrier: no duplicate disposal, invalidate cleanup if busy again. |
| D4 | Assertion after disposal: original zone assertion, no domain Error, private cleanup=1. |
| D5 | Late ack after dispose before clear: final request=1, clear/cleanup=0/no success/notify. |
| D6 | Dispose during physical clear: it settles, new cleanup/rotation/notify=0. |
| E1 | Live direct remove Exception: identical unexpectedError/stack, domainError null/global=1, asset unchanged; independent checkpoint enters. |
| E2 | Pending remove→dispose→Exception after 50ms: same private raw/report once, no public snapshot/notify, cleanup once. |
| E3 | Raw/assertion upload/final submit→lease release: primary/stack unchanged, no storage in matching release, later clear; review secondary precedence. |
| E4 | Loading action→bootstrap AssertionError: fail-loud original, no synthetic Error/downstream I/O; ticket/private cleanup settles once. |
| S13 | Earlier registered X commit pending→submit→X Success: P,Q,X, 3 uploads/1 submit D0/I; no incomplete capture. |
| S14 | Submit registers capture→later Y commit→deferred action: P,Q only, 2 uploads/1 submit D0/I; Y remains on failure/retires with success. |
| S15 | Earlier acquire X Error: P,Q, independent add Error, 2 uploads/1 submit D0/I. |
| S16 | Earlier acquire X Success/resolve Error: staged unavailable/submit domain failure; new checkpoint/upload/submit=0. |
| S17 | Pending X→submit capture→queued clear→X: clear I→J before prepare, submit Error/no remote/old checkpoint on J. |
| S18 | Pending X→Ready submit→dispose→X settles: only started acquire, new resolve/prepare/upload/submit=0, capture drained/no late notify. |
| S19 | Earlier pending remove P→submit→remove Success: Q only, 1 upload/1 submit D0/I; no resurrection. |
| S20 | Loading submit→ticket P,Q→post-ticket mutation: ticket membership/draft D2, no reserved arbiter wait for initialize/deadlock. |
| S21 | Earlier batch X committed→acquire Z Error: retain P,Q,X prefix/exclude Z, independent add Error/submit, 3 uploads/1 submit. |
| B6 | Retain onRemove(A,0)→[B]→invoke old closure: admission/remove=0, B/snapshots/running unchanged/no feedback. |
| B7 | Retain A callback→owner B (even equal ID): zero calls on both VM/repositories, no B effect. |
| B8 | Retain valid callback→normal rebuild→invoke: admission=1/remove=1 captured digest; persistent Success removes target only. |
| B9 | Old callback→same owner session I→J: J admission/repository/notify=0; replacement retained. |

### Complete F2 oracle details — S13–S21

Ready fixture: session **I**, valid request draft **D0**, ordered `[P,Q]`, distinct paths/successful fake uploads. D0 already durable except explicit S14 predecessor checkpoint H; editing to **D1** after admission must not alter remote payload. S13/S14/S15/S19/S21 use the same **Error(remoteRejected)** final request to inspect membership/identity after failure without retirement. Preparation checkpoint=0 when D0 known durable, no automatic retry, remote identity I. Dirty S13 variant checkpoints exactly D0 once before uploads, never D1.

S13 holds X acquire/resolve already in commit, admits submit, then releases: capture `[P,Q,X]`, uploads P→Q→X, Cloudinary=3/final=1, remote D0/I/local D1/I, add Success/submit original Error/global=0; X publishes before release, no missing X or D1 payload.

S14 admits capture before Y registration but forces Y commit before deferred prepare using existing virtual turns/gates, no production seam: capture `[P,Q]`, uploads P→Q, Cloudinary=2/submit=1 even if runtime `[P,Q,Y]`; remote D0/I, local D1/I+Y after failure. Success variant same payload/counts, one I→J clean retirement including Y with no transfer.

S15 earlier acquire Error(acquireFailure): `[P,Q]`, Cloudinary=2/submit=1, separate preserved add Error and remoteRejected/global=0; no X notification/imported add failure. S16 earlier acquire Success then resolve Error(resolveFailure): no payload, Cloudinary=0/submit=0/preparation checkpoint=0; same I/D1, unavailable incomplete list never adopted; independent add/submit errors/global=0, no invented restoration/destructive cleanup.

S17 tail X→capture→clear→prepare: capture may include X but remote/checkpoint-old-I=0; clear succeeds I→J once, submit stale domain/global=0, J clean unchanged. S18 starts acquire then submit/disposal, advances beyond virtual 50ms before Success: no payload/upload/submit/new resolve/prepare/checkpoint, only acquire may be durable. Public snapshots freeze (possibly running), no UI terminal/list change/notify/rotation/zone error; private capture/Command settles and cleanup once.

S19 remove P succeeds before capture: `[Q]`, Cloudinary=1/submit=1, remote D0/I/local D1/I, remove Success/submit remoteRejected/global=0, no double remove/reintroduction. S20 load/reconcile ticket restored `[P,Q]`/persisted **DR** seals before notify; post-ticket D1/Y excluded, Cloudinary=2/submit=1 DR/I. Absent variant empty ticket, no upload/submit=1 request D0/provisional I. Failure retains D1/I, load/reconcile once/no duplicate initialize/Ready capture. Pre-entry disposal starts initialize=0/no blocked capture. S21 batch publishes X before pending acquire Z Error, capture `[P,Q,X]`, Cloudinary=3/submit=1/Z uploads=0; preserve add Error(acquireFailureZ) independently from submit remoteRejected/global=0, D0/I remote/D1/I+X local; no X rollback/invented Z/add Success.

S14 discriminating timing: Y picker already open after pre-picker but no commit registered; prior tap alone is not earlier mutation. Existing checkpoint H saves D0 under arbiter; admit capture, return picker/register Y behind capture while submit deferred. pumpCommandTurns controls H release/microtasks: Y already queued precedes prepare registered only after capture consumption. Record fake Y acquire/resolve and first P upload to prove Y publication before prepare/remote. H saves D0 once; prepare recognizes durability and does not save again; post-request D1 is never checkpointed. Another variant admits new requestAddAsset Y after submit before actions; Y excluded regardless of commit timing. Do not pretend a new add pre-picker can bypass arbiter or rely on sleeps.

Counts mean fake uploadImageTask calls/one ContentSubmissionRepository.submit, not Cloudinary internal HTTP retries. Live Command forwarding may vary rebuild counts; assert authorized snapshot identity/content and absolute no post-revocation notify. Reuse `test/support/{fake_repositories,fake_image_picker,test_image_files,fixtures,command_test_support,ordinary_view_model_lifecycle_support,route_ownership_fixture,predictive_back}.dart`; extend missing hooks only, no legacy fake duplication. testOwnerUI/pumpCommandTurns handle virtual 50ms teardown; tests wait explicit entry/snapshot rather than starving zero-duration events. Load reuse/unit/widget/integration skills before applicable tests; ObjectBox skill only if data tests change (not planned).

## Historical planned manifest and analyzer gates

Allowed production: Content Submission VM and screen/progress_screen/asset_list; router only relevant owner/session/mounted callbacks. Tests: VM/widgets/route/restoration/ordinary lifecycle and necessary direct `test/integration/all_day_pipeline_test.dart` consumer identified at integrated gate. Reuse shared fake/image-picker/lifecycle/command/route support; new feature harness only after three concrete uncovered uses. Regression-only foundation four suites, repositories draft/staged/submission, Cloudinary, domain models/mappers. Existing eight artifacts: .openspec.yaml/proposal/design/tasks/four deltas. Excluded utils/foundation/legacy/repository/domain/entities/mappers/generated/config/dependencies/lock/Supabase/Admin/canonical/other changes. No build_runner/schema migration; a required excluded surface would stop execution for contradiction resolution.

B0/B1 require same SDK/resolution/argv/defaults/root mapping/archive procedure and full Counter including severity/type/code/relative path/column/length/message/source context/multiplicity; preserve B0 line positions and explicitly map moved identical references. B0 **66/0/0**, B1 **52 INFO/0 WARNING/0 ERROR**, exact 14 targets removed and all 52 non-targets (including three fake dartdocs) unchanged. A balanced total with missing/non-target/new identity fails. No ignores/exclusions/lint changes. Record raw exit/stderr separately; any flutter analyze run is separate and may exit nonzero on INFO.

## Appendix — full immutable B0 diagnostic ledger

Every row is severity INFO, type LINT, code DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE. Exact common message, replacing SYMBOL with row symbol:

```text
'SYMBOL' is deprecated and shouldn't be used. Legacy compatibility command. Do not use in new code. Use createResultCommand/createResultCommandNoParam for ordinary single-flight actions, or RestartableCommand when newer intent must supersede older work.
```

Position = line:column:length. Same-position/different-length rows are distinct identities. T=target/N=non-target; total 66, targets 14/non-targets 52. Rows/values are retained unchanged.

| Path | Position | Symbol | Count | Group |
| --- | --- | --- | --- | --- |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 23:13:37 | Command1 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 23:13:8 | Command1 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 24:14:14 | Command0 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 24:14:8 | Command0 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 39:8:8 | Command1 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 42:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 43:12:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 43:12:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 44:12:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 44:12:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 45:14:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 45:14:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 46:15:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 46:15:56 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 49:12:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 49:12:35 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 50:15:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 50:15:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 51:22:22 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 51:22:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 52:13:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 52:13:30 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 53:19:36 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 53:19:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 54:16:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 54:16:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 55:19:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 55:19:19 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 88:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 91:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 94:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 97:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 100:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 103:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 108:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 113:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 149:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 152:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 155:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 17:12:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 17:12:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 18:19:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 18:19:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 19:16:35 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 19:16:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 33:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 36:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 51:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart` | 99:35:7 | Command | 1 | N |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 99:16:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 100:21:8 | Command1 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 101:14:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 102:13:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 103:26:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 189:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 191:8:8 | Command1 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 192:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 195:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 201:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 16:24:7 | Command | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 131:46:7 | Command | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 139:5:7 | Command | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 154:21:7 | Command | 1 | T |
| `test/support/fake_repositories.dart` | 43:51:7 | Command | 1 | N |
| `test/support/fake_repositories.dart` | 656:17:7 | Command | 1 | N |
| `test/support/fake_repositories.dart` | 1165:13:7 | Command | 1 | N |

## Historical initial planning — before F1–F3 review

OpenSpec CLI **1.14.3**, `openspec validate migrate-content-submission-commands --strict`: **valid, exit 0**, no warning; **4/4 artifact groups complete** meant artifact presence, not implementation. **32 implementation tasks, 0 completed**; eight files/four existing capabilities/**62 normative scenarios**/**46 regression rows**. No test-result claim.

Checked capability/delta mapping, all canonical scenario titles in four MODIFIED requirements, WHEN/THEN, no placeholders/symlinks, paths confined to change, final newline/whitespace including all eight untracked. git diff --check **exit 0**, separate untracked check passed. B0/ledger comparison as above; **no Flutter tests/B1** in initial planning.

Final planning preflight reconfirmed open/Draft/head `f48a08946c9ac40146104a0157556243ad433c92`/base `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. [Actions run 39964646512](https://github.com/xmattjus/moliseis/actions/runs/39964646512) was completed/failure, Autonomous Flutter tests success and Flutter analyze failure; CodeRabbit status success. These were exact-head remote statuses, not fresh local tests or a diagnostic-count inference from job failure.

Dedicated branch/HEAD unchanged, tracked/index empty, only eight untracked change artifacts. Six other checkouts **6/6** matched HEAD/branch/status including untracked/stage entries; no source/test/config/dependency/canonical writes, commit/push/PR update/sync/archive/merge. Historical verdict **READY FOR INDEPENDENT PLAN REVIEW** was later superseded by F1–F3; nonterminating/cross-owner I/O/runtime-only ack/assertion/best-effort limits remained.

## Historical F1–F3 documentation remediation

Initial review found high/blocking F1/F2 and medium F3. This phase was documentation-only, no production/test edits, implementation or future-test pass claim. Reused baseline worktree/branch/HEAD and eight untracked artifacts, empty tracked/index; initial hashes acquired before changes, PR read-only same head/base, six other clean checkouts inventoried/preserved.

Changed five artifacts: design/tasks/concurrency/staging/orchestration deltas. .openspec.yaml/proposal/navigation delta stayed byte-identical. No new capability/artifact/public API required: existing immutable-request/sole-arbiter proposal already covered corrections. F2 fixed capture timing without claiming exact legacy equivalence; navigation remained compatible.

F1 (D5.F1, tasks 2.4/3.4/4.2/4.5/5.3, concurrency delta) exhaustively audited catches/provenance, raw remove, original stack/report/release/primary precedence, with E1–E4. F2 (D1–D4/D2.F2, tasks 2.2/4.1/4.5/5.1/5.3, orchestration/concurrency) bound Ready capture to request-registered tail, Loading to ticket and finalization-only to no capture, with S13–S21. F3 (D6.F3, tasks 6.1/6.6, staging delta) kept requestRemoveAssetAt and added rendering capture/current pre-admission guards with B6–B9.

Cross-check: five private ordinary Commands; no target reinterpretation/admission-success inference/second tail/runtime-domain conflation/resend after pending ack. Disposal forbids new phases/publication but drains private settlement. Canonical and previous deltas remain unsynchronized.

Strict **valid/exit 0/no warnings**; original **32 tasks all unchecked**, numbering unchanged. Matrix **63 unique IDs** = **46 original in same order + E1–E4/S13–S21/B6–B9 (17 new)**; detailed rows do not double-count. **79 normative scenarios** = 62 preserved titles +17; no canonical MODIFIED scenario lost. Capability/WHEN-THEN/symlink/placeholder/manifest/whitespace/newline/Git/digest checks passed, five-file diff only; all other checkouts/index/HEAD unchanged. Historical B0 **66 INFO/14 target**, future B1 **52**, no analyzer/Flutter rerun. Verdict **READY FOR INDEPENDENT PLAN RE-REVIEW** closed planning findings without authorizing implementation/publication.

## Implementation evidence — historical authorized local apply

The user later authorized implementation after two independent plan reviews, initially **without publication**. Planning/remediation statements above belong to their own phases. HEAD `f48a08946c9ac40146104a0157556243ad433c92`, branch `codex/plan-migrate-content-submission-commands`, empty index/tracked diff/eight approved untracked artifacts; PR open/Draft same baseline, six other checkouts unchanged.

All artifact/log filenames below identify historical temporary files under `<evidence-dir>/content-submission-apply-evidence/`, not tracked artifacts or proven currently accessible files. Persistent source checkpoints and this record preserve results/provenance, not the raw ephemeral contents. Historical commands use `<flutter-sdk>`/`<worktree>`/`<evidence-dir>` placeholders in place of workstation locations.

### Preflight and characterization

Direct Dart **3.13.4** on clean archive `<evidence-dir>/content-submission-apply-evidence/baseline`, resolved package_config without pub get: `<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <evidence-dir>/content-submission-apply-evidence/baseline`, cwd `<worktree>`, **exit 0**, empty stderr, **66 INFO/0 WARNING/0 ERROR**. Full ledger Counter missing=0/added=0, exact 14 targets/52 non-targets and positions; `B0.{stdout,stderr,json}`.

Baseline VM **132 pass/0 failure/0 skip/exit 0**; Content Submission widgets+route/restoration **134 pass/0 failure/0 skip/exit 0**. First VM attempt lacked ObjectBox native runtime; copied only ignored lib/libobjectbox.dylib from prior checkout and reran successfully. Flutter wrapper required authorized SDK-cache escalation, no tracked dependency changes.

Gate 1.4 before production edits: baseline A3 sent B not A; D5 cleared after disposal; E1 normalized raw remove/no global; S14 included later Y. **Four expected behavioral failures and S13 pass, exit 1** (`gate1-discriminating-baseline.log`). A7/S13 preserved already-correct legacy invariants, not falsely called RED. Isolated mutation copies broke each invariant: A7 waiting initialize before range validation failed completedBeforeRestoration; S13 omitted last membership and got P,Q not P,Q,X. Both **exit 1**, no compilation/harness failures (`gate1-{a7,s13}-mutation.log`), authorized source untouched. B1/B6 supplied consumer discriminators. Initial foundation/lifecycle **219 pass/3 actual skips/0 failures/exit 0** (`baseline-foundation.log`).

### Group 2 — Admission/ticket/membership

Private NoParam envelopes/request snapshots implemented D1/D2/F2; original invalid removal retained; `_serialize` finally released without raw conversion. `flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --name 'OpenSpec 5 gates (A|E|L|S)|initialization|initializ|unknown|quarantin|invalid early removal|removal queued behind|checkpoint ordered' --reporter expanded`: **42 pass/0 failure/0 skip/exit 0** (`group2-gate.json`, `group2-combined.log`). Included A1 all lanes/A2 drained turns/A3–A8/L6/L7/E1/E2 and 14 F2 S13–S21 tests with dirty D0/S14 success+failure/new Y/Loading restored+absent+dispose/partial prefix. Verified exact payload/order/counters/identity/original failures/no new resolve/post-disposal publication. E1/E2 had no duplicate ContentSubmissionAssetRemovalFailed; E2 global observer acquired private Command to verify physical disposal once without exposing API. Unobserved private notifier required group-5 probes for other lanes.

An overbroad preliminary filter included known group-5 D5 failure: **42 pass/1 expected failure**, not a green gate. Direct targeted analyzer exit 0 had only three pre-existing fake_repositories legacy INFO at B0 **43:51:7, 656:17:7, 1165:13:7**, no new diagnostic; diff check passed. Shared staged fake added pendingResolve/resolve count/defaults preserved; feature-local harness reused in more than three tests, no executable façade.

### Group 3 — Assets/clear/recovery and reopened retry gate

`flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --name 'ContentSubmissionViewModel (addAsset|removeAssetAt|retrieveLostAssets|clear|draft checkpoints|OpenSpec 5 gates (E|L))|in-flight staging|picker results after clear|checkpoint ordered|thrown staged commit' --reporter expanded`: **74 pass/0 failure/0 skip/exit 0** (`group3-gate.json`, `group3-vm.log`). L1–L7, limits/dedup/path/clear/recovery/E1/E2/E4 covered. Tests distinguished direct file failure from raw repository FileSystemException and expected PlatformException from unexpected plugin Exception. Prior best-effort recovery test now used expected PlatformException; separate raw test required reporting. E4 created initialize/Completer in same error zone (initial root-zone harness corrected), original assertion/stack/global=0/ticket settled/no downstream/synthetic domain. Targeted analyzer no issues/exit 0; whitespace valid; repositories/foundation/storage unchanged.

First full VM revealed omitted top-level `does not open the picker when staged reconciliation retry fails`: reconcile=1 instead of required 2. Gate 3.5 reopened; canonical staging “Hard reconciliation failure completes safely” **211–217**, D3/task 3.1 required pre-picker retry. Removed only add Loading early initializationError return; ticket identity stayed fixed, retry under same arbiter, unknown original error still blocks cleanup; submit ticket error/membership stays immutable. Group 4 work was uncertified until correction, no reset or progress past failed gate. Restored gate **80 pass/0 failure/0 skip/exit 0** (`group3-vm-after-retry-fix.log`, updated group3-gate.json), original reconcile=2 assertion intact.

First full VM run (`group4-vm-initial-failures.log`) was **170 pass/3 failures**: retry regression plus two legacy disposal assertions requiring approved no-new-cleanup and notify-from-revocation semantics. Failed runs remain failed evidence.

### Group 4 — Submission/finalization

Verified captured request draft/issue/identity and F2 membership, exact checkpoint/live guard before claim, sequential immutable remote payload, matching storage-free pre-ack release preserving domain/raw/assertion. Secondary cleanup precedence reviewed statically, including reporter failure, without artificial storage seam. Live ack pending/ownership precedes finalization; local domain/runtime retains pending/derived retry/captured local-only mode, no repeated checkpoint/upload/submit, identity guard/one rotation.

`flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --reporter expanded`: **173 pass/0 failure/0 skip/exit 0** (`group4-vm-full.log`, `group4-gate.json`), including S1–S21/E1–E4, E3 domain/Exception/StateError/Object/assertion and independent clear, S10 runtime pending/retry, duplicate-retry rejection and **2 uploads/1 remote/no repeated save**. Two disposal assertions adapted to D5 while preserving membership/identity/persistence counts; drain continuations after fake settlement before assertions.

`flutter test --no-pub test/data/repositories/content_submission_draft_repository_impl_test.dart test/data/repositories/content_submission_staged_asset_repository_impl_test.dart test/data/repositories/content_submission_repository_impl_test.dart test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart --reporter expanded`: **91 pass/0 failure/0 skip/exit 0** (`group4-data.log`). Unchanged wire/ack/replay/upload/repository/backend. Targeted analyzer **exit 0/no issues** (`group4-analyzer.log`), whitespace passed. Shared fake upload added optional controlled-throw stackTrace for E3, compatible defaults.

#### S11 isolated defensive fault injection

Valid public APIs cannot create post-ack mismatch while lease active: final draft identity/setters preserve ID/memoized initialize/denied clear/same-checkpoint restore/single-flight submit. Disposal separately covered D5. A temporary isolated baseline+current-Dart-diff copy `<evidence-dir>/content-submission-apply-evidence/S11-guard-probe` injected only after `_submissionFinalizationPending = true` and before `_finalizeSubmittedSession(draft.clientSubmissionId)`: (a) `_state = ContentSubmissionDraft(clientSubmissionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', name: 'Replacement')`; (b) `_activeSubmissionClientSubmissionId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'`. No domain mutability or authorized-worktree injection.

Temporary `S11 isolated identity mismatch fails closed after acknowledgement`, real fake/requestAndWait: remote=1 original ID/upload=0/clearDraft=0/staged cleanup=0/domain non-success/pending preserved/replacement state retained (original state for b); retry still remote=1/clear=0/pending. `flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --name 'S11 isolated' --reporter expanded`: each **1 pass/0 failure/0 skip/exit 0**, `S11-{state,owner}-green.log`. Removing only matching identity guard in isolated copy made each **exit 1**, expected clear=0/actual=1, `S11-{state,owner}-red.log`, no compilation errors. `S11-probe-test.txt` was temporary, not tracked/currently available proof. These probes are not counted among 173 persistent tests or claimed reachable via valid APIs; S3/S4/S9/D5 cover normal invariants.

#### A3 later-valid-edit issue correction

Before consumers, temporal A with captured issue followed by valid B before entry showed prepare republishing A issue onto B, poisoning later valid direct submit. Persistent `captured issue preserves a later valid temporal edit` was behavioral RED **exit 1**, expected issue null/actual missingStartDate (`A3-issue-red.log`). Reopened 4.1/4.5; minimal `_state == draft` guard restricted issue presentation, preserving A domain failure/no new validation. Same 63 scenario IDs. Full VM after fix **174 pass/0 failure/0 skip/exit 0** (`group5-vm-final.log`), B stays issue-null and next submit reaches repository once. D2 wording clarified existing canonical add retry, no new policy.

### Group 5 — Physical lifecycle and reentry correction

Audit every await/notify against D5; guard fresh initialize, queued restore/retirement after disposal and canRetry false when revoked. **75 new lifecycle tests** = 13 per five lanes +10 phase cases: pre-entry, late success/domain/raw/assertion beyond virtual 50ms, same-turn settlement/dispose in both orders, reentrant terminal observer, sync-idle readmission, idle/never-run. ObjectCreated SDK probe distinguished five direct results notifiers from derived objects; during pending four idle release/active stays live until settlement, each exactly once, no public Command API.

Additional phase gates: first of two uploads pending→no second/final request; post-ack cleanup pending→no rotation/frozen pending/snapshot/retry false; bootstrap reconcile/resolve→no next resolve/list publish; candidate length/hash/resolve in add/recovery→no next phase/new asset. `flutter test --no-pub test/ui/ordinary_view_model_lifecycle_test.dart --plain-name 'Content Submission private' --reporter expanded`: **75 pass/0 fail/0 skip/exit 0**. Four foundation suites +ordinary+Category lifecycle/Settings: **319 pass/0 fail/3 pre-existing skips/exit 0** (`group5-lifecycle-evidence.json`, `group5-foundation-lifecycle.log`). Three StateError upstream characterization skips unchanged. Targeted analyzer **exit 0/no issues** (`group5-analyzer.log`); no real timers/foundation/storage change; nonterminating/cross-owner limits retained.

Internal audit found upstream double sync-idle write: VM listener could admit second action during first false callback, then old finally reset busy. Prior case immediately disposed new owner and missed live second execution. Reopened 2.1/2.5/5.2/5.3; consumer gate uncertified until D1 local forwarding fix, no foundation/new queue. Five lanes × live second execution/disposed raw settlement were **10 behavioral failures/0 pass/exit 1** (`group5-reentrant-red.log`), second I/O physically pending but busy false, no compile errors. Same ten after microtask idle-forwarding fix: **10 pass/0 failure/0 skip/exit 0** (`group5-reentrant-green.log`): busy during second I/O/third admission false/intact slot; disposed beyond virtual 50ms original raw/stack/report=1/no stale publication/five notifiers release once. Existing D3 variants, no renumbering of 63/79; two lifecycle-file analyzer zero/exit 0.

Restored full VM **174 pass/0 failure/0 skip/exit 0** (`group5-reentrant-vm-full-retry.log`), aggregate **329 pass/0 failure/3 pre-existing skips/exit 0** (`group5-foundation-lifecycle-reentrant.log`); private lifecycle cases now **85 (75+10)**. Targeted analyzer no new diagnostics; reopened tasks reverified. First VM retry was blocked by SDK-cache access before tests, preserved separately; authorized escalation rerun passed.

### Group 6 — Consumers and routes

AssetList VM observation/own-admission warning/render-captured guarded target, retained-stale-callback B6–B9. Screen rebinds listeners/Form keys/generation even equal ID, isolates pending/finally and guards submit/link/iOS/post-frame recovery. Progress distinguishes neutral/running/success/domain/runtime/pending with local-only retry. Router diff only Content Submission, owner identity selector and Provider/session checks after dialog/await including pre-didUpdateWidget gap.

`flutter test --no-pub test/ui/content_submission/widgets test/routing/content_submission_route_test.dart test/routing/content_submission_restoration_test.dart --reporter expanded`: **164 pass/0 failure/0 skip/exit 0** (`group6-consumers-full.log`), P1–P8/B1–B9. Eight added router cases: Save/Discard after Provider replacement and direct checkpoint/restore fault × live/replacement/unmount; original object/stack/report=1/token release/no stale feedback. B3 initialized MaterialApp/public buildScope proved A mounted (skipOffstage:false), then replacement/unmount before post-frame flush: A retrieve=0/B=1 only live. Isolated removal of two recovery guards: **0 pass/2 failures/exit 1**, authorized source untouched (`group6-b3-mutation.log/json`), no production seam.

Preliminary B3 onstage-before-frame finder/URI-after-imperative-push oracles were fixture errors; corrected to actual mount/Screen presence without weakening I/O/owner/policy. Failed runs not called green. Targeted analyzer corrected to zero new diagnostics/no ignore/skip. testOwnerUI gained optional .value owner teardown callback, default unchanged; feature harness reused under widget virtual clock.

### Integrated gates 7.1–7.3

Initial B1 found expected 52 INFO plus **2 ERROR/exit 3**: legacy submit references `test/integration/all_day_pipeline_test.dart:74–75`, missing from nominal manifest. This direct Content Submission pipeline consumer required minimal existing requestAndWait/Result-aware snapshot adaptation, preserving wire/persistence/render asserts and original local-Supabase opt-in skip. No backend contract/new helper/infrastructure. Initial archive runner Python tarfile filter TypeError occurred before analyzer, fixed only temporary runner; separate `B1-initial.{stdout,stderr,json}` preserved failures.

Formatted original 16 Dart plus integrated consumer = **17 intentional files**, zero residual changes. Final B1 same SDK/flags/cwd/archive procedure: `<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine <evidence-dir>/content-submission-apply-evidence/final`: **52 INFO/0 WARNING/0 ERROR/exit 0**, empty stderr, `B1.{json,stdout,stderr}`. Full Counter + SequenceMatcher line mapping on identical source: **14 targets removed, missing non-target=0, added=0**, no multiplicity change. Only new non-target movement fake_repositories **1165→1169**; other 51 same line (`analyzer-comparison.json`). Intermediate unused import from upstream isSuccess corrected to Result-aware completed; failed initial/intermediate runs kept separate/no ignores/skips. **Flutter analyze NOT RUN** in this apply; direct Dart exit 0 did not make remaining 52 INFO globally clean.

`flutter test --no-pub --reporter json`, cwd `<worktree>`: **2,862 pass/0 failure/6 skip/exit 0**, historical runner duration **102.405ms**, empty stderr (`full-suite.{stdout,stderr,json}`). Counts from non-hidden testDone and done.success=true, not estimates. All 17 Dart files byte-identical to B1 with SHA256 recorded in temporary metadata. Six pre-existing skips: all_day_pipeline local Supabase opt-in; external_event_token_pipeline authenticated opt-in; three command_it_disposal_behavior upstream StateError A/B/E modes; NAV-01 upstream #188018 geo_map_route. No new skip/suppression. Targeted all-day compiled **0 pass/1 skip/exit 0**; infrastructure-dependent body **NOT RUN** without local stack. Compared with historical **2,705** pass, added **157** = VM +42/lifecycle +85/consumer-route +30; current full run was independently executed, not inferred by addition.

Coverage closed A1–A8/L1–L7/S1–S21/E1–E4 in VM/repository/Cloudinary; D1–D6/E2/E4 physical lifecycle; P1–P8/B1–B9 in 164 consumer tests. S11 valid-API impossibility versus isolated defensive injections remains explicit. **63 IDs (46+17)**, **79 normative scenarios**: concurrency 14/staging 15/navigation 20/orchestration 30; all **20** canonical scenarios of four MODIFIED requirements retained (`canonical-preservation.json`, historical temporary check).

### Actual historical implementation manifest

**16 tracked modified +9 untracked** (eight pre-existing artifacts +one harness), local/unstaged at that closeout: five production files/twelve test-support Dart. Complete manifest:

- `lib/routing/router.dart`
- `lib/ui/content_submission/view_models/content_submission_view_model.dart`
- `lib/ui/content_submission/widgets/content_submission_asset_list.dart`
- `lib/ui/content_submission/widgets/content_submission_progress_screen.dart`
- `lib/ui/content_submission/widgets/content_submission_screen.dart`
- `test/integration/all_day_pipeline_test.dart`
- `test/routing/content_submission_restoration_test.dart`
- `test/routing/content_submission_route_test.dart`
- `test/support/command_test_support.dart`
- `test/support/fake_repositories.dart`
- `test/support/ordinary_view_model_lifecycle_support.dart`
- `test/ui/content_submission/view_models/content_submission_view_model_test.dart`
- `test/ui/content_submission/widgets/content_submission_asset_list_test.dart`
- `test/ui/content_submission/widgets/content_submission_progress_screen_test.dart`
- `test/ui/content_submission/widgets/content_submission_screen_test.dart`
- `test/ui/ordinary_view_model_lifecycle_test.dart`
- `openspec/changes/migrate-content-submission-commands/.openspec.yaml`
- `openspec/changes/migrate-content-submission-commands/design.md`
- `openspec/changes/migrate-content-submission-commands/proposal.md`
- `openspec/changes/migrate-content-submission-commands/specs/command-execution-concurrency/spec.md`
- `openspec/changes/migrate-content-submission-commands/specs/content-submission-local-asset-staging/spec.md`
- `openspec/changes/migrate-content-submission-commands/specs/content-submission-navigation-lifecycle/spec.md`
- `openspec/changes/migrate-content-submission-commands/specs/content-submission-submit-orchestration/spec.md`
- `openspec/changes/migrate-content-submission-commands/tasks.md`
- `test/support/content_submission_command_harness.dart`

Relative to approved artifacts, only proposal/design/tasks and orchestration Edit-before-deferred-entry THEN changed to preserve later valid-edit presentation; .openspec.yaml/other three deltas byte-identical. No new capability/artifact/canonical write. Ignored `.dart_tool`/`lib/libobjectbox.dylib` runtime prepared only in authorized worktree/excluded from Git. Historical operational temporary evidence directory is not asserted accessible now; essential outcomes/reopened-gate reasons/limits are recorded above.

Final checks: eight original artifacts/four existing capabilities/**32 original tasks**/no new capability; **63 IDs/79 scenarios/all canonical MODIFIED titles** retained. Final **17 Dart formatter zero changes/exit 0**, whitespace/newline including nine untracked passed, no new ignore/skip/analyzer config. All-day direct consumer was the sole nominal-manifest addition, explained by B1 without changing backend/persistence.

### Historical local closeout

**32/32 verified tasks**. `openspec validate migrate-content-submission-commands --strict`: **valid, exit 0**. HEAD `f48a08946c9ac40146104a0157556243ad433c92`/branch unchanged, empty index/16 tracked changes/9 untracked; six other checkouts' HEAD/branch/index/status/untracked unchanged. PR then remained open/Draft at f48a0894/base main ee60777c; no update. Diff/whitespace/manifest and 17 validated Dart hashes reconfirmed, no commit/push/merge/sync/archive/destructive operation at that phase.

No material apply-gate blocker remained. Deliberate limits: already-started cross-owner I/O not cancelled/globally serialized; nonterminating Futures retain private resources; runtime-only acknowledgement lost on process kill; staged-cleanup Result.error best-effort; six pre-existing skips including two infrastructure-dependent integration bodies **NOT RUN**. S11 isolated probes were not persistent-suite results. No globally analyzer-clean or local-diff CI claim. Historical **READY FOR INDEPENDENT CODE REVIEW** meant local uncommitted implementation awaiting independent review/separate publication authorization.

## Published checkpoint and current cumulative status

Subsequent publication is verified from Git, rather than inferred from prior local prose: checkpoint 5 [`e80dfbaf472ef1cc15b220a48df966509a9ee8a1`](https://github.com/xmattjus/moliseis/commit/e80dfbaf472ef1cc15b220a48df966509a9ee8a1), sole parent `f48a08946c9ac40146104a0157556243ad433c92`, is published in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12). Its parent was the Search/GeoMap documentation reconciliation, itself child of checkpoint 4 `da7c426fb799a26094f043319b47e63b98728f92`. A later reconciliation may record an earlier commit's SHA; no self-referential creation-time claim is made.

The exact-checkpoint [Actions run 40078677728](https://github.com/xmattjus/moliseis/actions/runs/40078677728) completed with failure. This persistent remote record is distinct from historical successful local targeted/full tests.

The old **4/7 published / fifth local-uncommitted-unpublished** status belongs to local closeout only. The cumulative PR now contains **seven published migrations**. Checkpoint 5 retained **52 INFO**; later zero-diagnostic evidence must not be attributed retrospectively to it. Earlier Actions workflow conclusions remained failure through checkpoint 6; later checkpoint-7 success is separate evidence. Local historical targeted/full tests above, old exact-head CI, and newly executed reconciliation checks are distinct. No fresh analyzer/test run is claimed by translating this record.

PR remains Draft, merge unauthorized. Canonical synchronization/archival/legacy compatibility deletion require separate authorization; no such operation or new OpenSpec change is part of reconciliation. The legacy implementation remains intentionally retained.
