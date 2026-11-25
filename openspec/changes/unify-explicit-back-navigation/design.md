# Design

## Baseline and scope

Planning baseline is `70f7cef7ec4e92363e43e67d96c71ae0ecb6da8d`. The
locked environment uses Flutter 3.47.5 (framework `6a19cca564`), Dart
3.13.4, GoRouter 18.0.2 and material_ui 1.5.0. The earlier real-router and
widget baseline reported 1,015 passes and one existing skip. NAV-01 remains
the upstream inactive-branch system Back gate. Platform gesture checks on
physical devices belong to implementation verification.

Use source-qualified actions, the original router host, and native Material
Back presentation. Scope the ordinary policy to app-owned Back. A dedicated
malformed Admin error route removes the deferred editor exit from the error
path. A global router wrapper is outside the design.

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

## Separate the malformed Admin error from the editor

The current editor GoRoute renders the malformed error in its builder and
applies the editor's `onExit` to both screens. GoRouter schedules a page pop
through that hook even for an immediate decision, then completes and removes
the captured match. Two requests can obtain approval for that same match.
A declaration uses the same hook for each outgoing match, including any
editor underneath. The public hook receives equivalent inputs in both
paths. Keeping the shared route with a local latch would either allow two
pop approvals or suppress valid declarations. A frame can pass while an
exit vote is still pending.

Use the existing named editor route's local redirect to send a rejected
`RouteParameters.submissionId()` value to the dedicated sibling
`/admin/submission-error/:id` under Dashboard. Keep valid editor locations
and names, and keep the specific `new` and `save-progress` matches. A valid
positive identifier whose record is missing, unavailable, loading, or bound
to an inadmissible session stays on the editor route and retains its existing
behavior. Use the same identifier codec for matching decisions and preserve
its accepted noncanonical forms. A matching-regex split at the original URI
would have to duplicate decoded Dart number parsing, including overflow and
encoded input. The local redirect uses the authoritative codec directly.

Construct the destination with URI path segments, carrying the decoded
identifier as one encoded segment and retaining the query and fragment.
Reconstruct the original normalized editor URI for the error screen and
its existing diagnostic reason. The malformed location is the only URI
contract that changes. A direct use of the dedicated path with a valid or
reserved identifier returns to Dashboard. It cannot open an editor by
redirect and bypass editor admission.

GoRouter runs global `onEnter` against the incoming request before legacy
top-level and route-level redirects. Keep existing authority and occupied
operation checks in place. Make the editor-specific part of Admin
`onEnter` recognize only `new` or an ID accepted by
`RouteParameters.submissionId()` in the existing editor path. A malformed
target, including one with a session hint, has no editor identity and must
not start a hint lookup or recovery admission. The Sync redirect still
takes precedence, and top-level auth is re-evaluated after the local
redirect. The parser constructs its imperative match from the redirected
target using the original push intent and completer. Direct navigation
retains declarative Dashboard ancestry. A push retains its actual base.

The dedicated error has no editor owner or deferred exit hook. The existing
error-pop branch for a different Page key already allows return to the
retained editor even while that editor owns an exit reservation. The
no-visit veto when `_pending` survives unregister protects an invocation
owned by an earlier editor. Closing the diagnostic page consumes no
activation, reservation, checkpoint or recovery, and leaves the invocation
and the global admission check untouched. A declaration that also removes
an editor still evaluates the editor's original hook. A covered dirty editor
can veto the declaration. Auth revocation from an Admin stack still takes
its security path without prompting or simulating a pop result.

### Back and reconciliation

Give both error controls one predecessor-only override of the existing
explicit Back action. Bind it to the actual current root Route, displayed
error and reconciled match as for other imperative pages. If the source is
stale, covered, refreshed but not yet reconciled, or lacks an authorized
predecessor, the action leaves navigation alone. A later tap may act once
the source is eligible. No Home fallback, local exit lease or continuation
is needed.

With no `onExit` on the error, GoRouter's regular page-pop path completes
the live match and removes it synchronously. The explicit `GoRouter.pop()`
updates route information in the same call. The second saved control sees
the old source as retired. Concurrent system requests already in
`Navigator.maybePop()` recheck the snapshotted route after the asynchronous
check; a new system request after removal can legitimately act on the new
top. Keep the original delegate and native transition. No manual restore,
one-shot listener, RouterConfig wrapper or origin marker is required.

The real-router prototype preserved the exact Dashboard or dirty editor on
return, kept the editor's activation and dirty fields, and made no lookup
for a malformed session hint. A held lookup from a separate valid request
remained owned by the editor when the covering error returned. The probe
also exercised named and unnamed navigation, encoded slashes, repeated query
keys, declarative and imperative restoration, Sync return, sign-out with a covered dirty
editor, overlap in both explicit/system orders, predictive cancellation and
commit, and iOS edge swipe. A refresh with the same imperative Page key
replaced the match and its completer. Saved explicit Back did nothing before
build and current Back could act after the new Page settings were observed.

### Dependency and compatibility limits

The system delegate uses Navigator rather than `GoRouter.pop()`. Both the
baseline and route-split prototype could replay an imperative error on
refresh between a system-pop commit and route-information reporting. Native
Back against a pre-frame stale mapping can also complete an old imperative
result, as characterized separately for ordinary app routes. The explicit
action guards that window for its own dispatch. These general native
reporting and reconciliation behaviors are outside the change.

A synthetic malformed push over a public base also survived an auth refresh
in both routers because GoRouter restoration re-evaluates the base URI.
Normal Admin entry, direct error and pushes over the Admin stack still use
the existing auth redirect. The error is read-only and must not own or
restore any Admin activation. The repository's production callers of named
editor push provide typed submission IDs; malformed external entry uses
declarative navigation. No generic imperative-auth repair belongs to this
change.

GoRouter's codec decodes each saved imperative location with matching alone,
without replaying its per-route redirect. A synthetic state serialized by
the old router can therefore still reach the original builder with a
malformed imperative match. Keep its null-ID branch as a defensive,
predecessor-only diagnostic with no editor activation. The probe verified
that this historical payload renders safely. Current malformed requests
commit the dedicated route. A new saved imperative entry restores to that
route. Historical entries restored to the original editor route retain the
existing protected exit policy. Explicit Back can only return to the actual
predecessor when permitted. The concurrent Back and immediate-refresh
guarantees apply to the dedicated diagnostic route. The plan introduces no
stored-state migration or generic completer repair.

The canonical routing and editor capabilities keep their existing
contracts. The new diagnostic contract belongs to explicit Back. The
active Admin editor redesign owns editor presentation and shares no route
change. The Gallery slideshow follow-up remains with the image change.

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
| Malformed Admin in `router.dart` and Admin admission | Dedicated protected error route, local redirect and shared predecessor-only action. Valid editor hooks remain with the editor. |
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
