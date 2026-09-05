## Context

See `proposal.md` for motivation and `specs/content-submission-navigation-lifecycle/spec.md` for required behavior. Repository reality was revalidated from a clean `main` checkout at `b69c81c` (`refactor!: simplify staged asset lifecycle`) before this change was scaffolded. The focused ViewModel, form, progress, and restoration baseline passes 139 tests. Repository-wide `flutter analyze` remains non-zero with the same 189 pre-existing diagnostics recorded by the predecessor plans; in planned production files these include two existing positional-boolean infos in `ContentSubmissionViewModel`, two required-parameter-order infos in the progress screen, and two experimental `SentryMask` warnings in the form.

Subplans 1 and 2 are implemented and complete. `ContentSubmissionViewModel` already owns a stable `clientSubmissionId`, immutable `_checkpointedDraft`, derived `hasUnsavedChanges`, awaitable `checkpointDraft()`, memoized initialization, `_PersistedDraftState`, one private lifecycle queue, durable staged assets, retry-safe staged upload sources, and persistence-first `clear`. Asset picking already checkpoints inside the ViewModel before invoking `ImagePicker`; that ownership remains unchanged. The root Provider creates this ViewModel once for the application, so route removal does not dispose or reset its state.

The current form route has no exit policy. Its Terms and Privacy handlers launch through `UrlLaunchService` without checkpointing. Its submit handler validates, starts `submit.execute()` unawaited, and independently pushes the child progress route, so Command re-entry protection does not prevent duplicate pushes. The progress screen correctly uses `PopScope(canPop: !submit.running)` for system and predictive back, but currently owns completed-session cleanup in three navigation paths and clears even failed work when `Torna alla home` is used.

The project resolves `go_router` 17.3.0. Its installed source defines `GoRoute.onExit` as `FutureOr<bool> Function(BuildContext, GoRouterState)`, calls it when a route is removed by pop or a new route configuration such as `go`, and evaluates exiting matches from child to parent. The pop path schedules each asynchronous callback independently and calls `_completeRouteMatch` for each invocation that resolves true; concurrent pop attempts therefore must not share one affirmative Future. An `onExit` on the existing parent form route still covers removal of that form by AppBar/system back and programmatic replacement while allowing a pop of only the progress child without invoking the parent policy. The same route-local ownership gate can reject removal while a form checkpoint boundary is pending, so a form `PopScope` is not required even for transient coordination.

Supabase migrations, submission RPCs/Edge Functions, RLS, remote payloads, and Cloudinary behavior do not participate in these local route decisions. No backend or generated-code change is required.

## Goals / Non-Goals

**Goals:**

- Put one guarded-exit decision on the existing form route and one successful-retirement decision in the existing ViewModel.
- Reuse the predecessor checkpoint, lifecycle queue, clear Command, staged-session cleanup, generic snackbar, and submit Command rather than creating parallel infrastructure.
- Make every UI-controlled external/submit transition await its persistence boundary, remain safe across widget unmount, and be mutually exclusive with a competing parent-form removal.
- Keep progress navigation declarative: it renders operation state and navigates, but does not decide whether a draft should be persisted or destroyed.
- Keep the production delta below the 250-line complexity threshold through localized additions and deletion of current progress cleanup coordination.

**Non-Goals:**

- Do not add navigation coordinators, lifecycle/session managers, undo/history, a state machine, a use case, repository/service interfaces, packages, or another state-management mechanism.
- Do not make durable staged-asset additions/removals reversible when field edits are discarded.
- Do not change `Command`, repository protocols, ObjectBox models/generated output, ImagePicker ownership, remote validation, upload ordering/retry, Supabase, Cloudinary, or Admin.
- Do not solve the backend-acknowledgement ambiguity caused by process death before the client can observe/record a successful response; remote idempotency is outside this subplan.
- Do not claim that completing Subplan 3 makes Content Submission release-ready.

## Decisions

### 1. Put the only form-removal policy in `GoRoute.onExit` and give one invocation ownership

Add `onExit` to the existing named Content Submission parent route in `lib/routing/router.dart`. Resolve the application-scoped `ContentSubmissionViewModel` from the callback context. Before either the clean fast path or dirty decision, synchronously try to acquire the route-local transition token from Decision 3. Return `false` immediately when another form boundary or exit invocation already owns it. The invocation that acquires ownership returns `true` for a clean form, or otherwise shows one Material confirmation whose three explicit outcomes are represented by one small private enum:

- `Salva ed esci`: await `checkpointDraft()`; return true only on `Success`.
- `Esci senza salvare`: await the ViewModel checkpoint-restore operation from Decision 2; return true only on `Success`.
- `Annulla`, dialog dismissal, or system back on the dialog: return false without mutation.

On either operation error, keep the route, preserve the operation's failure contract, and invoke `showSnackBarGenericError` after confirming the callback context remains mounted. Do not call `clear` from this flow.

Never return another invocation's Future. Every overlapping `onExit` fails acquisition and returns its own `false`, so only the owner can produce one affirmative completion. The owner releases immediately after cancellation, an operation error, or an unexpected caught exception. If it returns `true`, retain ownership through go_router's consumption of that affirmative result and schedule identity-checked release after the route-removal frame; this closes the interval in which checkpoint/restore has made the ViewModel clean but a second stale pop could otherwise return true before go_router removes the match. The identity check prevents delayed cleanup from releasing a later owner's token. This applies to clean and dirty exits, prevents an overlapping pop from removing an underlying route, and lets a later route instance acquire normally after completion. The child progress route remains nested exactly as it is; popping that child does not remove the parent match and therefore does not trigger this guard.

On Flutter 3.41.9, a dirty iOS form adds one narrowly scoped `PopScope(canPop: false)` so Cupertino's `popGestureEnabled` rejects the native edge swipe before its transition begins. This is a platform-specific gesture disposition only: it owns no persistence policy, dialog, restore, clear, or route decision. A transient explicit-AppBar-Back allowance opens just long enough for the normal `GoRoute.onExit` attempt, then closes after a denied pop; Android remains outside this scope and retains its existing system/predictive route policy. The form AppBar derives a secondary `● Modifiche non salvate` line directly from `hasUnsavedChanges` inside the existing standard toolbar without changing any AppBar dimensions or Back control.

Alternative considered: put exit orchestration in a navigation service/coordinator. Rejected because one route and one dialog need the behavior.

### 2. Restore only the existing checkpoint snapshot in the ViewModel

Add one direct `Future<Result<void>>` lifecycle method to `ContentSubmissionViewModel`, named for restoring/discarding uncheckpointed changes. Like `checkpointDraft()`, it is not a Command because the route callback must await and inspect the `Result` directly and supplies its own dialog/error UX.

The operation awaits shared initialization and enters the existing `_serialize` boundary. If persisted-draft ownership is `unknown`, return the retained draft-load error and change nothing because no trustworthy durable checkpoint can be claimed. Otherwise, if dirty, assign `_state = _checkpointedDraft`, clear only transient event-time validation state, and notify active listeners; if already equal, return success as a no-op. It must not call any repository, replace `_checkpointedDraft`, rotate `clientSubmissionId`, mutate `_assets`, or invoke `clear`/`clearSession`.

This is sufficient because Subplan 1 already retains the exact immutable checkpoint snapshot and Subplan 2 intentionally persists staged assets through separate immediately durable operations. Re-reading the draft repository would add I/O and a second restoration path without improving correctness.

Alternative considered: use `clear`. Rejected because it deletes the persisted draft, retires the session identity, and removes staged assets—the opposite of `Esci senza salvare`.

Alternative considered: add undo/history or persist asset membership inside the draft. Rejected because only one checkpoint revert is required and staged assets are not ordinary field edits.

### 3. Mutually exclude form-owned boundaries and route removal with one route-local token

In `buildAppRouter`, retain one nullable `Object` ownership token and two small closures: acquire creates/stores a fresh token only when none is active, and release clears only the identical token supplied by its owner. Pass those required closures directly to `ContentSubmissionScreen`; they are a narrow contract between the two existing participants, not a new coordinator, service, class, Command, or generalized lock. Both `onExit` and each form-owned boundary acquire synchronously before their first async gap. Thus the first owner excludes the other direction, stale delayed release cannot clear a newer owner, and no duplicate checkpoint/restore orchestration is needed.

Refactor the existing inline Terms, Privacy, and submit callbacks into small private State methods in `ContentSubmissionScreen`. Retain one local boolean boundary flag for rejecting repeated callbacks and absorbing form pointer interaction. Set and release it through mounted-safe `setState`, and wrap the existing returned `CustomScrollView` once with `AbsorbPointer(absorbing: boundaryPending)` so all field, checkbox, asset, external-link, submit, and AppBar pointer interactions in that form subtree are gated together. The route token—not `AbsorbPointer`—coordinates operating-system, predictive, and programmatic navigation. This single local flag and one route token are preferable to separate submit-push, Terms, Privacy, and form-lock states or per-control callback branches.

For Terms and Privacy, synchronously acquire the route token and return without work if an exit or another boundary already owns it. Capture the ViewModel and injected `UrlLaunchService` operation before the first await. If the draft is dirty, await `checkpointDraft()` while interaction is absorbed; launch only after success and while still mounted. A clean form may launch without creating an otherwise unnecessary empty persisted draft. On checkpoint error, do not call the launcher and show the existing generic snackbar. Preserve the same snackbar when the launcher returns false. Use the project guard → capture → await → `if (!mounted) return` pattern; release the token in `finally` regardless of mount state, and release the local flag only through mounted-safe state updates. Do not add any checkpoint around `addAsset` or move URL launching into the ViewModel.

For submit, perform both existing form validations and event-time validation before lifecycle work, then synchronously acquire the route token; if acquisition fails because an exit/boundary owns it, start nothing. Once acquired, set the local flag, await `checkpointDraft()` (which physically writes an absent current identity and no-ops only for a known durable equal snapshot), and on error release both ownership layers, remain on the form, and show the generic snackbar. After success and a mounted check, start `submit.execute()` before calling `pushNamed` for the existing progress child. `go_router` 17.3.0 synchronously records/notifies the push request before returning its route-completion Future, so release the route token immediately after that call: progress then owns pop availability, and later progress Home navigation can reach the parent `onExit`. Do not await the push completion Future: a later `goNamed(Home)` configuration replacement can remove an imperative match without completing that Future. Instead keep the local `AbsorbPointer` through the current frame and release it in a mounted post-frame callback after the progress push has been handed to the router; the progress route then obscures the form and owns back availability. If push invocation throws synchronously, release both layers immediately and do not attempt a second push.

The synchronous route-token acquisition closes both gaps that `Command` and a mounted check cannot: a second form action cannot begin another checkpoint/push, and system/predictive/programmatic removal cannot start a competing exit while the boundary owns the token. Conversely, once `onExit` owns the token, a form callback cannot checkpoint and later launch/submit merely because its State remains mounted behind the pending dialog. Absorbing edits still ensures the user-visible snapshot cannot change between checkpoint and handoff. No extra Command, `PopScope`, or navigation-policy owner is added.

Alternative considered: rely on `submit.running` or disable only the button. Rejected because submit does not become running until after the checkpoint and neither option alone prevents a second progress push.

Alternative considered: let mounted checks resolve the exit race. Rejected because a form State can remain mounted while `onExit` owns a pending dialog or persistence decision, allowing a late external launch or submit without explicit ownership.

Alternative considered: add a navigation coordinator or change generic `Command.execute()` to return a start token. Rejected as broad infrastructure for one screen transition.

### 4. Make the submit lifecycle own successful local finalization

Retain `Command0<void> submit` and the existing `Command0<void> clear`; do not add a new public Command or result hierarchy. Add one private transient `_submissionFinalizationPending` boolean and a read-only getter used by the progress UI. This state records an irreversible fact that Command's four generic states cannot express: the backend has confirmed this submission, but persistence-first local retirement has not yet succeeded.

On a normal `_submit()` call, preserve existing validation, staged uploads, and final remote upload. If the remote result is an error, return it with the finalization flag false. If it is success, set the flag true synchronously before awaiting any cleanup, `await clear.execute()`, and only then inspect `clear.result` (the Command publishes its terminal Result after its async action completes):

- Clear success has already removed the persisted draft, invoked existing staged-session cleanup, reset the form through the existing clear listener, and rotated once to a fresh clean identity. Set the flag false and return submit success.
- Clear error preserves the completed session under the existing persistence-first contract. Keep the flag true and return that error so progress can render a terminal recovery state.

At the start of later `_submit()` executions, check the flag before validation or any upload work. When true, execute only the same clear/finalization branch. Thus `Riprova` after a local finalization failure never rebuilds or resends the remote submission, while repeated failed clear attempts remain retryable and one successful clear performs the only state rotation. Existing clear logging supplies diagnostics; no new error subsystem is needed.

Calling one existing Command from the owning ViewModel action is deliberate: `ContentSubmissionScreen` already listens to `clear` to hide/reset its retained form subtree, and `clear.execute()` preserves that behavior while exposing its final `Result` through `clear.result`. After Decision 5 removes all progress-owned clear calls, no production caller competes with this sequence.

Alternative considered: keep cleanup in Back/Home/New buttons. Rejected because success could remain stale indefinitely, each button duplicates policy, system back races cleanup after pop, and failure Home currently destroys recoverable work.

Alternative considered: treat clear failure exactly like a normal remote submit failure. Rejected unless the confirmed-success flag is retained and rendered distinctly, because ordinary Retry could resend the same submission.

Alternative considered: add a persistent finalization marker to the ObjectBox draft. Rejected for this subplan because it expands the domain/storage schema and generated code, cannot be guaranteed when the same local store is failing, and still cannot resolve process death between backend commit and client response. The transient marker closes the actionable in-process cleanup-failure path without pretending to provide backend idempotency.

### 5. Reduce the progress screen to state presentation and navigation

Keep the current progress route and `PopScope`, but remove `_clearFuture`, `_clearOnce`, post-pop cleanup, and `_clearState`. Build behavior from `submit` plus the ViewModel finalization-pending getter:

- **Running** (including the awaited clear after remote success): retain spinner, `canPop: false`, empty AppBar leading, no actions, and no duplicate submission.
- **Idle/restored**: retain Back and `Torna al modulo`; each pops only progress and preserves work.
- **Remote error with no confirmed success**: retain Back, `Riprova`, and `Torna alla home`. Back pops only progress. Retry executes the existing submit Command for the same session. Home calls `goNamed(home)` directly; this performs no clear and parent-route removal remains subject to Decision 1 if state somehow became dirty.
- **Local finalization error**: render explicit copy distinguishing remote success from local retirement failure, block pop/system/predictive back, hide Home and new-submission navigation, and expose only `Riprova`. Retry calls the same submit Command, whose ViewModel branch performs local clear only.
- **Completed**: local finalization is already complete. Back and `Nuovo suggerimento` pop only progress; Home directly navigates home. Every action is navigation-only and exposes no completed session because the ViewModel has already rotated.

The existing progress `PopScope` remains the only widget-level pop policy, scoped to progress ownership. Its `canPop` expression expands minimally to include local-finalization-pending. No form-level `PopScope` is introduced.

Alternative considered: expose a dedicated finalization Command to the progress widget. Rejected because it makes the widget choose persistence policy and adds a second command/action state when the submit lifecycle can resume itself safely.

### 6. Test observable contracts with existing fakes and navigation helpers

Extend `test/ui/content_submission/view_models/content_submission_view_model_test.dart` for checkpoint restoration, unknown-state failure, preserved persisted/staged ownership, remote-success finalization, clear failure followed by finalization-only retry, one remote upload, and one successful identity rotation. Reuse `FakeContentSubmissionDraftRepository`, `FakeContentSubmissionStagedAssetRepository`, `ControllableSubmissionRepository`, and their current gates/counters.

Extend `content_submission_screen_test.dart` for validation/checkpoint/launch ordering, checkpoint failures, single pre-picker checkpoint ownership, route-token acquisition/release, single-flight rapid submit, and mounted-safe unmount while a checkpoint is pending. Supply a real `UrlLaunchService` composed with one focused shared recording `ExternalUrlService` fake under `test/support/`; do not copy the private fake from `url_launch_service_test.dart` or create another local test harness.

Add `test/routing/content_submission_route_test.dart` using `buildAppRouter`, rather than copying the production `onExit` callback into a test router. Follow the production-router harness pattern already present in `test/routing/geo_map_route_test.dart` and `test/routing/sync_redirect_test.dart`: own a non-due `SyncViewModel` and `ControllableAdminAuth` for router construction, provide one application-scoped `ContentSubmissionViewModel` plus the form's `UrlLaunchService`, navigate the router to the Content Submission location before the first pump so unrelated home-shell screens do not force a full application provider graph, and register disposal. Do not extract a generic router harness for this second specialized use. In addition to clean pop, the three dirty actions, save/restore errors, reopening after discard, and existing persisted-draft retention, use controllable draft-repository gates to cover two concurrent Back/pop attempts over a sentinel underlying route, concurrent programmatic removals, system/predictive Back during submit/Terms/Privacy checkpoints, and the inverse order where an owning exit prevents later form callbacks. Assert one dialog, one persistence operation, one intended removal/destination, no underlying pop, no late submit/push/launch, no Flutter/go_router exception, and normal later acquisition after cancel/failure/completion. Use `test/support/predictive_back.dart`. A device/simulator smoke check covers the real iOS edge-swipe interaction because synthetic widget drags do not reliably reproduce native interactive-pop availability and cancellation; the automated route-removal tests still prove the shared callback contract.

Refactor `content_submission_progress_screen_test.dart` away from button-owned clear assertions and cover running/predictive inhibition, idle return, remote failure Back/Retry/Home preservation, distinct finalization failure and retry, and navigation-only success actions. Keep `content_submission_restoration_test.dart` proving a recreated idle Command returns to the form without clear or retry and the pre-submit checkpointed draft remains recoverable.

Do not create a generic navigation-test framework. If exercising the real production router requires reusable provider setup, extend the closest existing route fixture additively only after inspecting all consumers.

### 7. Implementation footprint

**Production files expected to change:**

- `lib/routing/router.dart`
- `lib/ui/content_submission/view_models/content_submission_view_model.dart`
- `lib/ui/content_submission/widgets/content_submission_screen.dart`
- `lib/ui/content_submission/widgets/content_submission_progress_screen.dart`

**Production files expected to be created:** none.

**New classes/types expected:** one private route-dialog choice enum only. The route/screen ownership contract uses existing function and `Object` types rather than adding another type. No new production class, architectural layer, Command type, service, repository, use case, coordinator, or state machine.

**New persistent state expected:** none. One transient ViewModel boolean records confirmed-remote-success/pending-local-finalization; one form-local boolean guards pointer/single-flight behavior; and one router-local nullable identity token mutually excludes one active form boundary or exit invocation. The screen holds an acquired token only as an async method local and receives two required function callbacks from the route.

**Approximate production-code delta:** `100–300 LOC`, with progress cleanup deletion offsetting route/form/ViewModel additions. Tests and OpenSpec documentation are separate and are not included in this estimate. The former 250-line ceiling is exceeded only by the Flutter 3.41.9-required iOS route pop disposition, transient explicit-Back handoff, and accessible unchanged-height dirty-status composition needed to prevent an already-started native gesture from freezing on dialog cancellation. These remain localized to the existing form widget and add no production type, file, service, or navigation participant.

This is the smallest maintainable solution because every behavior lands on an existing owner: `GoRoute.onExit` owns form removal and the route-local ownership token, the ViewModel owns checkpoint restoration and successful-session policy, the form owns its external/submit event sequencing, the existing Commands own operation re-entry, and progress owns only presentation/pop availability. The two callbacks connect existing route and form lifetimes without introducing a fifth participant.

**Final review question:** “Could this hardening be implemented correctly with materially fewer production concepts or lines while remaining consistent with the existing Molise Is architecture?” **No.** The one route token is the minimum shared fact needed to prevent both multiple affirmative `onExit` completions and boundary-versus-exit overtaking; the form boolean separately drives widget rebuilding/absorption; and the ViewModel boolean prevents remote resend after confirmed-success cleanup failure. Removing or conflating them would reintroduce a race or require a larger coordinator. The selected design still deletes obsolete progress cleanup state rather than layering over it.

## Risks / Trade-offs

- [An async `onExit` is re-entered by another back/go request] → Let only the invocation that acquires the route token run the decision; every overlap returns its own false, and affirmative ownership remains until after go_router consumes the removal. Test one dialog/persistence operation/removal and preservation of a sentinel underlying route.
- [System/predictive/programmatic exit races a form checkpoint boundary] → Require both route and form to acquire the same identity-checked route token synchronously; the loser performs no persistence or route-sensitive continuation, and deterministic gated tests exercise both ownership orders.
- [A progress Home replacement never completes the original imperative push Future] → Do not await that Future; release route ownership after the synchronous push request and release the form's pointer lock post-frame, then verify Home leaves no pending form ownership or late callback error.
- [A dirty snapshot changes while an external or submit checkpoint awaits] → Absorb form pointer interaction under the one form-local boundary flag and cross the boundary only after checkpoint success.
- [State accesses `widget`/`context` after unmount] → Capture ViewModel/service references before awaits, guard immediately after every async gap, use captured locals afterward, and add an unmount regression.
- [A confirmed remote success is resent after local clear failure] → Set finalization-pending before cleanup, branch before all upload work on retry, render the state distinctly, and block navigation until local finalization succeeds.
- [Process death occurs after backend commit but before the transient success marker/finalization completes] → The pre-submit checkpoint preserves the attempted draft, but this checkout has no remote idempotency/client-ID contract that can distinguish committed from uncommitted after restart. Do not claim this subplan solves that ambiguity or is release-ready; a future backend-aware hardening decision is required if product acceptance demands duplicate-proof crash recovery.
- [Successful clear rebuilds the retained form while progress is on top] → Continue invoking the existing clear Command so the existing form listener/loading/reset behavior remains authoritative; remove only progress-owned invocation sites.
- [Home on remote failure bypasses preservation] → Navigate directly without clear and let parent `onExit` handle any actual dirty state; assert persisted draft and staged ownership remain.
- [iOS widget tests give false confidence about native edge-swipe behavior] → Test route callback behavior automatically and require a focused simulator/device gesture smoke check rather than a brittle synthetic drag.
- [An async dirty-exit dialog starts after a Cupertino interactive pop] → Prevent only dirty iOS edge-swipe initiation through route pop disposition; retain the normal AppBar-triggered `onExit` policy and rerun the complete native iOS matrix.
- [Verification expands into pre-existing analyzer cleanup] → Before source edits, retain the complete output of `flutter analyze`; after implementation, compare diagnostic tuples (severity, code, path, line/column, and message), not only the total. Require no new or worsened diagnostics in touched/in-scope files and treat the measured 189 total only as a supplementary baseline rather than permission for a different set of 189 failures.
- [Production growth approaches 250 net lines] → Run `git diff --numstat -- lib/routing/router.dart lib/ui/content_submission/view_models/content_submission_view_model.dart lib/ui/content_submission/widgets/content_submission_screen.dart lib/ui/content_submission/widgets/content_submission_progress_screen.dart` and calculate production additions minus deletions, excluding tests/docs/generated output. Stop, remove duplicated route/widget/progress branching, and update this design with both gross and net figures plus block-by-block justification before proceeding above the net budget.

## Migration Plan

1. Revalidate the clean `b69c81c`-descended baseline and predecessor artifacts; stop if checkpoint, lifecycle queue, durable staged assets, route nesting, or clear semantics materially differ.
2. Add ViewModel checkpoint restoration and confirmed-success finalization behavior with focused unit tests before changing navigation callers.
3. Add the parent-route `onExit` policy and single-consumer route token with production-router concurrency tests, then pass its narrow acquire/release callbacks to form external/submit handlers alongside the one local boundary flag.
4. Remove progress-owned cleanup and update state/action tests, including finalization-only recovery and restored-idle behavior.
5. Run focused suites, full tests, baseline-aware analysis, formatting/diff checks, strict OpenSpec validation, iOS manual gesture validation, and an independent semantic review of route/persistence ownership.

There is no data migration, generated-code step, backend deployment, or dependency rollout. Rollback is source-only because no persistent schema changes are introduced; however, do not rollback only the ViewModel finalization change while retaining progress cleanup removal, or vice versa, because those two edits transfer one ownership contract and must move together.
