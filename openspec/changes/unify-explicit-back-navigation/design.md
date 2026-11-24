# Design

## Baseline and scope

Planning baseline is `70f7cef7ec4e92363e43e67d96c71ae0ecb6da8d`. The
locked environment uses Flutter 3.47.5 (framework `6a19cca564`), Dart
3.13.4, GoRouter 18.0.2 and material_ui 1.5.0. The earlier real-router and
widget baseline reported 1,015 passes and one existing skip. NAV-01 remains
the upstream inactive-branch system Back gate. Platform gesture checks on
physical devices belong to implementation verification.

Use source-qualified actions, the original router host, and native Material
Back presentation. Scope the ordinary policy to app-owned Back. The protected
malformed Admin route retains a blocking departure-boundary decision as
described below. A global router wrapper is outside the selected design.

## Ordinary decision and local authority

The app has one root Navigator and four retained branch Navigators in
`StatefulShellRoute.indexedStack`. Gallery, Settings, Login and Admin
are root-owned. Category, Post and Search can have declarative predecessors
inside a branch even after a direct link. Dialogs and popups can cover the
root shell while a branch page remains locally current. A restored stack
supplies its own route and predecessor identities.

Bind the action to the displayed Route, its Navigator and its semantic page.
At activation require a mounted, active, current source and an owner matching
the selected Navigator. Check the committed configuration, the root shell
page's current status where applicable, and the committed active branch
Navigator key. Reuse shell visibility and branch pop-scope inputs for their
existing responsibilities. The committed branch key is the live selector:
a real branch-switch probe found the old Navigator still showing two pages
after the committed key changed and before a frame. The previous inherited
visibility value or the old branch's local `isCurrent` is insufficient.
Check native gesture state and the source's `popDisposition` during preflight.

Reuse existing keyed owner boundaries for Category, Post and Search.
Error surfaces whose URI changes in place and any Gallery presentation
whose route data can be replaced must issue a new binding on semantic
replacement. A previously issued action remains retired after A → B → A.
Equivalent refresh and theme/locale rebuild keep the binding. Temporary
popup or branch coverage suspends eligibility for the same retained page;
when it returns, its still-valid action can act. Disposal or replacement
ends the old action's lifetime.

Use `GoRouter.pop()` when its live deepest eligible Navigator is the verified
owner and the page permits a pop. Structural `NavigatorState.canPop()` and
`Route.popDisposition` answer different questions. Treat an explicit veto
or a bubble against an existing ancestor as an ineligible pop. A first page
can naturally bubble without a predecessor; if that is the verified source,
and no policy veto applies, request `goNamed(RouteNames.home)`. Canonical
Explore root is a no-op. Use the canonical named route to replace the stack
and select Explore root even when its branch retains a detail. No exception,
veto or failed preflight sends a second action.

A real Search Post probe found that direct Navigator pop committed the
predecessor but left the detail in route information. Immediate refresh
reopened Post before reporting. GoRouter pop updates the provider through
`restore` when the removal changes configuration synchronously. It
preserved the exact Search Route and its query `q`. Keep this public path
rather than reproducing the synchronization. `maybePop` answers whether the
request was handled and can report a veto as handled.

### Local imperative reconciliation

A commit precedes the Navigator's Page-to-match update. Where standard Back
can own an imperative match, remember the relevant match observed with the
source Page settings. Bind the observation through the public
`ModalRoute.settingsOf` dependency and update it when the actual Page for
that presentation changes. Arbitrary rebuilds must not stamp a stale Page
with a newer committed match. Compare the live imperative entry against the
bound entry. GoRouter 18.0.2 equality includes both its match list and its
completer, in addition to the normal match fields. Equal wrappers that keep
the mapping/result must remain eligible. A Page key alone would also accept
a replaced completer. Until the Page dependency reflects the changed entry,
leave the stack and both results alone. The user can tap after reconciliation.
No observer or forced frame is needed.

In a controlled widget probe, the refresh changed the committed imperative
match before `ModalRoute.settingsOf` changed. The guard rejected pre-frame
pop, then a normal Navigator rebuild kept the Route, published the new Page,
and accepted Back. A separate real Gallery probe reproduced the unguarded
failure: the result from the old entry completed and the new committed entry
survived. After the next build Gallery was visible again on a different
Route with the same Page key. A normal reconciled pop then revealed the
same Post Route. Verify the binding in the actual hosts as permanent tests.
This local check qualifies explicit controls and does not replace
Navigator or system Back handling.

### Fallback and Dashboard

`goNamed` synchronously submits route information. The Flutter Router then
parses it. GoRouter can continue from its global `onEnter` asynchronously
even after synchronous Allow or Block, followed by redirects and a delegate
setter. The delegate may await an outgoing route's `onExit`. Configuration
commit, Navigator build and route-information reporting are separate
milestones. The Flutter Router can discard a superseded parser result, but
cannot cancel an already-running dependency setter. Dispatch produces no
completion receipt. Provider divergence can also survive a rejection.

A real Settings probe dispatched Home twice, refreshed the same input and
submitted Login before the queued parsing completed. Login committed while
the Settings Route was still current in its Navigator. This is a newer
navigation intent, not a reason to retain an application request lock.
Repeated same-source ordinary Home requests have the same named destination.
After a source ceases to be committed/live it cannot pop or fallback. Normal
dispatch and reattempt from a still-eligible ordinary source do not infer
pending/denied state from the provider or replay requests.

The Admin global `onEnter` can veto while `_pending` or `_moderationClose`
is occupied for the still-authorized visit. `unregister` removes the visit,
releases the reservation and retires its dialog, but the invocation can
remain occupied until the policy completes. An already-stale or unauthorized
visit is handled by the existing policy. In the real router a controlled
saved-session lookup denied navigation to Settings while the ordinary
source could not become current. Sign-out allowed Settings before the
lookup finished, and Back to Home committed while that lookup was still
unresolved. Source review also found moderation admission tied to the
editor exit and its exact visit, with an existing cleanup path. These facts
do not constitute proof for every possible interleaving. They give no
observed app trigger that requires tracking ordinary fallback refusal or
repairing a rejected external input. The unmatched refusal/refresh replay
previously shown by an arbitrary global blocking fixture is a dependency
characterization, not the authority model for ordinary app sources.

Keep both Dashboard AppBars on `_backCallback`, `_capture`, `_live`,
the existing account/visit/generation checks, and `_backRequested`.
Run shared preflight before consuming `_backRequested`. Once an action is
admitted keep the existing revocation and dispatch the selected terminal
action. Preserve recovery ownership and logout. No production fallback
denial from a live standalone Dashboard was established, so the plan does
not add a generic latch reset, change existing recovery, or install a route
listener for it. Read real auth/Sync redirects as router outcomes.

## Protected malformed Admin error — decision gate

A malformed ID uses the same GoRoute as the editor. It may have no registered
editor activation. Its explicit controls need one source-bound action that
goes only to the actual predecessor with `AdminSubmissionExitPolicy.exit`.
A lower dirty editor is its own owner. A page pop must preserve it, and a
declaration that also removes it must evaluate its separate exit decision.

Prior real-router probes found leading/text and system Back can enqueue
multiple exits for one malformed page, including a second system Back after
commit but before reconciliation. GoRouter awaits `onExit` in a microtask,
then completes the captured imperative match and removes it. It calls the
same hook during declaration, in reverse order through the outgoing stack.
An allowed declaration does not complete the popped match's imperative
result. These are two different call sites but the public hook does not carry
origin or the captured match.

An additional controlled GoRouter probe queued a declaration and a page pop
in the same turn. The two callbacks received the same context, equal
GoRouterState, identical committed configuration and identical provider
request object. Keeping the declaration pending, rejecting the page pop and
then admitting the declaration evaluated the lower editor hook and committed
the new destination before the original page rebuilt. A separate held-vote
probe showed that resetting a local latch at the next frame allowed a second
evaluation while the first was still pending. The fixtures isolate the
dependency contract. They do not claim that the app's malformed vote has the
same artificial delay. Page key and URI are also stable across a refreshed
imperative mapping. A local guard using only these inputs cannot grant both
duplicate-pop exclusion and independent declarative exit. The missing
evidence is a supported origin distinction, or a demonstrated app
invariant that removes the ambiguity without changing a native gesture or a
protected exit contract.

Keep malformed Admin blocked for implementation until that decision is
made. The options for review are a narrowly authorized origin seam for this
route, with no parser envelope or ordinary request receipts, or a separately
approved routing/policy change that removes the need for a deferred page
pop at this particular error. A fallback to key-only admission would veto
valid declarations or allow duplicate completion. Returning true to two
compatible-looking calls can approve two pops. Broad `PopScope` interception
changes native eligibility and does not intercept every ordinary router pop.
Dart Zone markers and host forwarding are removed from the selected
ordinary design; any separate origin seam needs its own proof and explicit
approval. Do not start the guarded Admin implementation from a speculative seam.

First investigate whether the malformed route can use a public, route-local
origin boundary while retaining its matching, native gesture and Admin policy
contracts. If it cannot, seek a scope decision before adding a host interception
or changing the route contract. The broad host projection and request tracking
would still be unnecessary.

Any Admin solution needs to distinguish an approved pop from
actual removal, keep its vote claimed until decision, and reject a retired
mapping before reconciliation. The existing real-router probe showed that
the deferred pop can commit without provider alignment and immediately
refresh back into the error. A one-shot listener with public `restore` fixed
that probe. Keep it only for an exact, owned remove whose provider input
has not been replaced. Dispose on release, departure or supersession.
An approved operation past GoRouter's public boundary cannot be cancelled
by the app. A Navigator frame can establish a mapping update and cannot
settle an unfinished policy vote.

## Presentation and impact

Compose `material_ui.BackButton` in the shared control with the existing
`onPressed`, background and padding API. An override owns all effects even
without a GoRouter. Keep native platform glyph selection, action-icon theme
override, RTL, tooltip and accessibility semantics. Use the native Italian
“Indietro” and English “Back” labels.

The prior presentation probes measured a 40 × 40 target in a 56-slot with
8-pixel outer padding. Reduce default mobile spacing locally where the
layout allows it, retaining a centered 40 × 40 visual face and the native
glyph. Native tap-target sizing should reach 48 × 48 for hit testing and
semantics. Check all edges, avoid overlap and preserve explicit spacing,
surface or transparent backgrounds, and desktop density. Constrained hosts
retain at least the previous reachable area. The existing AppBar and
SearchBar layouts own their constraints.

| Surface | Planned responsibility |
| --- | --- |
| `lib/ui/core/ui/custom_back_button.dart` | Direct. Native style, default routing binding and full override. |
| `lib/routing/back_navigation.dart` | New. Small decision and local source qualification for standard actions. |
| `lib/ui/core/ui/custom_appbar.dart` | Indirect. Verify existing leading layout and visibility. |
| Settings, ordinary Route Error and Gallery Unavailable | Direct. Remove duplicated fallback. Companion text shares the same source binding. Preserve the existing leading eligibility and error diagnostics. |
| Gallery preview and overlay | Direct where explicit Back currently routes itself. Preserve gesture/dismissal ownership, transparent styling and other gallery actions. |
| Admin Login, Post, Category and Search Results | Indirect through shared Back. Preserve actual parent/entry, parameters and styled leading. |
| Admin Dashboard | Conditional terminal integration in both bars. Preserve feature authority and recovery. |
| Malformed Admin in `router.dart` | Protected decision gate. No shared Home fallback. |
| Shell and branch boundaries | Read existing ownership/disposition. No new Navigator, observer or global lifecycle. |
| Ready and opening Admin Editor, Save Progress, Content Submission and Progress | Feature-owned. Preserve visibility, checkpoints, dirty exit, outstanding work and exact return owner. |
| Search Anchor, GeoMap, Location Picker | Retain local close, cleanup, state and results. Only shared styling changes where already used. |
| Shell roots, Sync, Logging/Talker, logout, Close/Dismiss | Excluded. Preserve implicit leading behavior and existing non-Back actions. |

## Gallery result boundary

A real Gallery probe also showed the post-reporting limitation: refresh
retained the Gallery Route but replaced the imperative completer. After
reconciliation a real pop returned to the same Post with the original
Gallery Future still pending. The GoRouter codec serializes route data and
rebuilds matches, not process-local completers. Standard Back owns the
result for the *live popped match*. It neither completes a retired result
nor repairs an older Future. The pre-frame stale-pop guard and the stranded
original Future address different conditions.

`PostMediaSlideshow` currently resumes after awaiting
`GalleryPreviewScreen.show`. An early result can run the resume logic
while a Gallery is still present. A stranded result can prevent the
return continuation even when the retained Post is visible. The active
`optimize-image-rendering-and-empty-view` change owns a follow-up in its
Gallery design, image-presentation scenario and tasks 3.5–3.6.
Tie the pause to the actual owned Gallery coverage and retained Post
availability, preserving one open, readiness, user intent, disposal and
error propagation. Verify both result/visibility orders with the real
router. No dependency change or completer manipulation belongs here.
