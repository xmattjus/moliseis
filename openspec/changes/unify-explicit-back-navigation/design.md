# Design

## Context

Planning baseline is commit `70f7cef7ec4e92363e43e67d96c71ae0ecb6da8d`,
the same revision cited in the initial investigation. The worktree was made
from the synchronized local main. Locked dependencies resolved offline with
Flutter 3.47.5 (framework `6a19cca564`), Dart 3.13.4, `go_router` 18.0.2,
`material_ui` 1.5.0, `cupertino_ui` 1.1.1, `material_symbols_icons`
4.2960.0, `provider` 6.1.5+1, and `flutter_quill` 11.6.0. OpenSpec 2.1.0
found the local `spec-driven` root. Two other changes were active at baseline.

### Baseline evidence

| Evidence | Observed result and limit |
| --- | --- |
| Baseline branch, lockfile and active changes | Local HEAD, local main and remote main remain at the planning commit. Three active changes include this proposal. Current strict validation matches the previous canonical baseline of 28 specs with 17 existing failures. |
| `flutter test --no-pub --reporter expanded` over routing and the focused Settings, Admin Login, Admin submissions, Search, Gallery, GeoMap and Content Submission widget suites | 1,015 passed, one skipped and zero failed. NAV-01 remains the existing inactive-branch system Back upstream skip. |
| Pinned GoRouter with synchronous Allow/Block, controlled policy futures, repeated Home and immediate refresh | The provider requested Home synchronously while the committed config and Navigator stayed on the source. After microtasks the delegate could commit a redirect before a frame changed the Navigator or reported the URI. Matched refusal reported source after a frame. Unmatched refusal could leave the requested URI, and refresh could replay it. Fresh retry was independently accepted. Two same-URI requests and a refresh each entered parsing, while a later request superseded all three completions before delegate entry. |
| Public Flutter RouterConfig probe with original GoRouter parser, provider and delegate | Stamped parser/delegate forwarding observed an unchanged rejection despite a stale provider and a pending delegate onExit until refusal returned. It observed latest parse supersession. An additional controlled probe fed the surviving unmatched URI through the original parser on refresh of retired input. Home was not replayed, a Sync redirect still committed, and a fresh Home request was accepted. In a separate controlled synthetic case, two already-started asynchronous exit setters completed in reverse order and the older setter committed last. Forwarding is observation of the boundary and cannot cancel that work. |
| Actual buildAppRouter, Search Post with q, owner Navigator pop versus GoRouter pop, immediate refresh before the next frame | Both committed the parent synchronously. The owner Navigator left the detail URI in the provider, so refresh reopened Post. GoRouter synchronized the provider and retained the exact Search route and original q. A later Back from that Search page legitimately removed one more level. |
| Actual buildAppRouter, pushed Login above Settings and real Sync refresh | GoRouter pop preserved the active Settings route before refresh and completed the Login push once. Sync preserved Settings as `from`. During a pending Home request from Settings, Sync instead redirected with Home as `from`. |
| Actual buildAppRouter, root Gallery above Post, then refresh and a new push | The unavailable Gallery push completed once and the exact Post Route and State survived closure and the subsequent Settings push. Existing valid Gallery regressions stayed green. In a separate stack, a post-reporting refresh reconstructed a surviving imperative Settings match and stranded its original push Future while retaining the Route. This is a GoRouter 18.0.2 restoration/refresh limitation distinct from the explicit pop gap. |
| Actual buildAppRouter, malformed Admin ID | Direct malformed detail popped to Dashboard. Pushed malformed detail above Dashboard reproduced duplicate imperative completion with leading plus text. One allowed pop above a dirty editor retained the same dirty editor State and did not prompt exit. Dirty source replacement prompted before the error could be presented. After auth revocation and disposal, the captured error callback could dereference a deactivated ancestor. The current refresh-overlay Dashboard callback safely rejected a stale sign-out activation. |
| Additional real-router review probes, independently of platform gestures | After a refresh reconstructed an imperative Settings match, an immediate pre-frame pop completed the old result without removing the current match. After an imperative malformed Admin pop committed, a system Back before the next build hit the old page and raised the same duplicate-completion error. Both probes separate committed state from the Navigator page-to-match mapping. |
| Actual malformed Admin declarative pop before reporting | Delegate reached Dashboard while provider still held malformed URI. Immediate refresh reopened the error. A separate one-shot delegate observation restored the committed Dashboard through public GoRouter API and refresh no longer reopened it. A focused Dart zone probe distinguished the deferred page-pop hook from unrelated declarative onExit. |
| Presentation | The earlier double-pop and covered/inactive-source probes still motivate the binding. The Search Page key was stable through a query A → B → A. Native Back in the package used the correct glyph on Android, iOS and macOS, matched direction, supported a theme icon override and localized tooltip. Mobile unconstrained target measured 48 × 48, desktop default 40 × 40 and the original padded AppBar hit target 40 × 40. |

Probes were temporary widget tests. They establish dependency and existing
app behavior, plus feasibility of the public forwarding and restore seams.
They do not establish correctness of future production code. Physical Android
and iOS gesture behavior remains to be checked during implementation.

### Topology and ownership

- `lib/routing/router.dart` registers the root Navigator and four branch
  Navigators. The indexed-stack `StatefulShellRoute` contributes one
  `appShellPage` on the root, with Explore, Favourites, Events and Map
  Navigators inside. There is no additional intermediate Navigator shared by
  all four branches. Inactive Navigator trees can stay mounted and offstage.
- Settings, Admin Login, Admin Dashboard/editor/save progress, Content
  Submission/form progress, Gallery, Sync and debug Logging are root-owned.
  Editor and both progress paths have their own declarative ancestry. Admin
  Login is a standalone matching root even though its path starts with
  `/admin`. Settings, Login and Gallery can be pushed over an actual route
  stack. The auth flow can replace a pushed Login with Dashboard over the same
  Settings route. A direct `go` to an independent root replaces the shell.
- `core_routes.dart` keeps Category and Post on their matching section
  Navigator. Explore also owns Search Results and its Post child. Direct
  Category/Post/Search links reconstruct ancestors. Back follows those
  matches including `q`. A section-root return preserves the existing
  handling of inherited query keys. Gallery is a root overlay when pushed and a standalone
  root page when matched directly. Error UI may be an unmatched root, a
  matched branch validation error, or a matched malformed Admin Editor.
- Dialogs, menus, search views, the map location picker and some sheets are
  pageless routes or feature-local overlays. A root popup can hide a locally
  current branch page. AppBar can also imply a native Back or full-screen
  dialog Close from route configuration. GeoMap's bottom sheet is local
  presentation state and has no independent application predecessor.
- Flutter/router restoration scopes reconstruct declarative matches and
  Navigator state where configured (`router`, `appShell`, branch-specific
  IDs and `appShellPage`). Use the restored live owner and actual stack at
  activation. Do not publish or restore captured callbacks. Existing picker
  restoration and session admission are feature-owned.

## Goals / Non-Goals

Use one small route-facing decision callable from icons or text actions.
Bind it to the screen that issued it and keep actual route, request and
admission effects observable in tests. Use the existing callback boundary for
local policies. The app host observes one ingress and the latest completed
Navigator build. The malformed Admin adapter owns a temporary commit listener.
GoRouter continues to own the navigation stack, route selection, reporting,
restoration and platform Back dispatch. No extra dependency or state-management
layer is needed.

## Decisions

### 1. Use the resolved native Back presentation

In `material_ui/lib/src/action_buttons.dart`, `BackButton` accepts
`style` and `onPressed`. It renders a package `IconButton` with the
`BackButtonIcon` and the package `MaterialLocalizations.backButtonTooltip`.
The unoverridden native action is `Navigator.maybePop`. The icon checks
`ActionIconTheme.of(context)` and first honors `backButtonIconBuilder`. It
otherwise uses `ThemeData.platform` for the Android arrow and the
iOS/macOS rounded chevron. Web has its own arrow default. The default glyphs
set `matchTextDirection`. Custom icon builders own their directionality.
Android's duplicate semantics label uses the real framework
`defaultTargetPlatform` as required by that native implementation.

The current wrapper imports `dart:io`, chooses Material Symbols with
`Platform.isIOS`, adds left-only iOS compensation and hardcodes
`Indietro`. Replace this with the package `BackButton`, retaining the
existing signature, outer padding and surface/color override. Pass only
the background override through `IconButton.styleFrom`, leaving AppBar and
SearchBar icon style resolution to the package. Branch on a supplied
`onPressed` before looking up routing dependencies or acquiring Back authority.
An existing native control needing the standard action can use the native
button directly with the shared callback. Native controls already invoking
feature-specific actions need no wrapper to acquire native presentation.

`BaseThemeData` and `AppThemeData` use Material 3, app surface/AppBar
colors and the existing Android/iOS transition themes. `main.dart` installs
the package's material localization delegates for English and Italian plus
the Flutter Cupertino delegate needed by Quill. Italian remains `Indietro`
under the Italian locale. In English test hosts the native label is `Back`.
Keep existing CTA text. Use the native tooltip once.

`IconButton` merges the supplied style with the ambient component style on
the Material 3 path. Its standard face has a 40 logical pixel minimum,
and a padded native target requests 48 on mobile when the parent permits it.
The desktop theme defaults to shrink-wrap. A parent can constrain either
dimension, as the AppBar probe demonstrates. Preserve the measured existing
AppBar and SearchBar geometry, maintain target reachability and avoid
shrinking any existing hit target. Assert the native minimum where unconstrained
under the mobile theme. The inherited 40-pixel padded AppBar case is a baseline
limit. No app-wide density or toolbar resizing is proposed. Test transparent
Gallery/Search/GeoMap backgrounds, surface defaults, directional zero/custom
outer padding and constrained leading slots. A manual composition from
`IconButton` and `BackButtonIcon` would duplicate tooltip and action
presentation with no styling advantage under this locked version.

### 2. Dispatch ordinary Back through GoRouter

Use `lib/routing/back_navigation.dart` for the production decision and its
source-qualified dispatch. One callable can serve an icon and a text action.
A default control binds its originating presentation. A supplied override
branches before any lookup of GoRouter or the shared boundary. Keep the
decision small enough for unit tests using live eligibility, local predecessor
availability, exit disposition and canonical Home. Route mutations and their
observable outcomes are exercised with the actual router.

Use `GoRouter.pop()` for ordinary managed-page returns. Immediately before
dispatch require the exact mounted, current source route and matching committed
leaf, and require that the host has published the current match list to the
Navigator tree. Resolve the owning Navigator from the source. For a root page, require
that Navigator to be the router root and the source to be its current route.
For a branch page, require the current shell match's Navigator key to name
that same Navigator, and require its enclosing shell ModalRoute to be current
on the root. This mirrors the relevant selection conditions of the resolved
delegate without replacing its dispatch. A root popup or page fails the
live shell check. A popup on the owning Navigator fails the source-current
check. Compare the effective GoRouter match and screen identity for semantic
authority. Use exact configuration identity separately to verify that the
Navigator is using the committed match mapping. Reuse the existing `ShellRouteVisibility` and `BranchDetailPopScope`
as the app's visibility and disposition boundary. The visibility snapshot
supplements live match and route checks during the interval before rebuild.

Once the source is qualified, sample `NavigatorState.canPop()` on that
Navigator and consult the source's `popDisposition`. Reject a scope veto,
unexpected bubble on a structurally poppable path, or ongoing native
gesture. The normal standard pages use no legacy scoped `willPop` and have
no outgoing `GoRoute.onExit`. The owner check, disposition read and
`GoRouter.pop` dispatch stay in the same synchronous activation. Use the
actual predecessor, including any retained imperative page. A provided
callback continues to own any special result, gesture allowance, or exit.
Do not enroll guarded routes in the ordinary synchronous pop path.

`GoRouter.pop` first delegates to the selected Navigator and then calls
`restore(currentConfiguration)` if page removal synchronously changed
the match list. That aligned provider state prevents an immediate refresh
from reparsing the removed location. Direct `NavigatorState.pop` reaches
the same page callback but lacks that alignment. Real Search Post evidence
shows the direct-pop candidate can reopen a detail before reporting.
`GoRouter.canPop` is neither source admission nor target proof.
`maybePop` introduces a local await and its handled bool includes a veto
or deferred exit. A source-qualified direct Navigator pop plus manual
ordinary restore duplicates the supported API. All three alternatives
were rejected for the ordinary path.

With no structural predecessor, request `goNamed(RouteNames.home)` only
from an eligible standalone root or direct unmatched error. Check for
a disposition veto even on a standalone route, and make canonical Explore
root a no-op. The eligible standalone roots have no outgoing asynchronous
exit. Branch-root controls are outside scope. Named Home uses the actual
route, entry policy and redirects. It selects Explore root when a shell
can be reused and builds a fresh shell if it no longer exists. An
unqualified `goBranch` can restore a retained detail and a push adds
history to the source being discarded.

### 3. Observe routing completion at the public host boundary

The resolved `goNamed` synchronously writes RouteInformation and notifies
the Flutter Router. It returns void. Flutter begins a parse transaction
and GoRouter calls the app's global `adminExit.onEnter`. Even an immediate
`Allow` or `Block.stop()` goes through an async continuation in
`handleTopOnEnter`. An allowed result leads to matching, Sync then auth
redirects, and the navigation-type match operation. Flutter delivers the
latest parsed result to the delegate. For a declarative departure the
delegate checks outgoing `onExit` hooks, may await their answers, and
then commits and notifies. Navigator pages reconcile on rebuild. Flutter
reports route information separately after the frame. An unmatched
configuration can produce no report, leaving its provider at a rejected
destination. A refresh can reparse that very input even after rejection.

There is no public per-call completion for `goNamed`. The provider
contains requested or reported information. Delegate notifications miss
unchanged outcomes. `Allow.then` is scheduled by the parser and does not
cover delegate exit or commit. `Block.then` changes hard-stop semantics.
The existing admin recovery acknowledgement measures policy admission
only. Awaiting an internal parser debug future, testing URI divergence,
and waiting a frame or elapsed interval cannot implement the required
pending, refusal and retry behavior.

Add one app-instance composition boundary in
`lib/routing/app_route_request_boundary.dart` and install its stable
`RouterConfig` at the existing app host in `lib/main.dart`. Keep
`buildAppRouter`, GoRouter ingress, provider, route graph, back
dispatcher and actual delegate authoritative. Use public Flutter APIs
to forward parser and delegate methods with a small envelope containing
the parsed `RouteMatchList` and an ephemeral ingress token. The parser
carries that token from ingress until Flutter passes the envelope to the
matching initial, new or restored delegate setter. Forward the original
parsed matches, each original setter and its completion. Forward build,
notifications, restoration encoding and `popRoute` to the original
objects. Preserve synchronous completions where the wrapped object supplies
them, including on restoration. Use the existing host lifetime for cleanup. Strip the envelope when restoring route information. Tokens
are memory-only. The original GoRouter remains available in the original
widget tree. Expose the latest ingress status, whether the current match
list has reached the Navigator tree, and optional Back-origin result to
Back consumers. Observe the delegated RouterDelegate build to capture the
exact configuration it used. Publish that projection after the build frame
only if its host is live and the committed configuration is still that
exact instance. Retain only the latest reference. This is an observation
of an actual build, never a timer or a substitute for the setter outcome.
A commit can precede that build, including an equivalent refresh whose new
imperative match has a different result completer. During that gap, the
old Page can still be mounted and current. Block explicit Back until the
Navigator mapping catches up. Equivalent refresh regains eligibility
without rotating semantic owner identity. No observers per control, additional
Navigator, routing policies, preserved stack copy or routing API for
ordinary destinations are needed.

| Stage | Action at the boundary |
| --- | --- |
| Dispatch and parsing | Ordinary fallback claims the next synchronous ingress of its `goNamed` call. Keep this temporary registration only around that call. If no ingress claims it, finish without departure and release any caller admission. A parser entry allocates one current parse token. The token is outstanding until the setter returns, the parse fails, the boundary is disposed or a newer ingress supersedes it. |
| Concurrent refresh | Refresh of the identical provider input starts a new physical parse and transfers the same still-outstanding Back receipt. Preserve the new Sync/auth evaluation. An independently issued request, including a new request with the same URI, supersedes the prior receipt. Flutter ignores an older parser result before delegate entry. |
| Pending external request | Reject an explicit Back activation while the latest ingress is unresolved. Do not retain or replay that activation. A setter completing with the same committed source clears the gate, even if the provider still shows the rejected target. A new activation on the current source then evaluates normally. |
| Completion | A committed departure is observable in the real delegate configuration when its setter completes. It includes permitted redirection. A settled request with the original presentation still committed is a non-departure, including refusal or a redirect to the same presentation. The distinction needed by Back is departure versus non-departure. The boundary need not infer a policy's reason. |
| Failure, replacement or disposal | Complete the owned receipt once, including on parser/setter error, supersession and host disposal. Preserve original exception handling. A superseded receipt cannot clear a newer token or issue another navigation. When system Back supersedes Flutter's pending parse, retire that receipt at dispatch. Observe the forwarded system operation until it returns or is superseded, preserving its call and result. |
| Reporting and rejected fallback replay | Normal distinct route information is forwarded unchanged. If a refresh still references the exact input of the most recently refused **explicit fallback**, re-evaluate the still-committed source instead of retrying Home. Use the original parser's public encoding for the surviving unguarded root configuration and its committed URI for an unmatched error, which has no encoding. Retain this one exception only while that same raw input is still in the provider and the same source is committed. A fresh Back or other navigation supplies new input and supersedes it. A refusal from an external actor never leaves a permanent Back lock and keeps the router's existing refresh policy. |

The boundary observes a lifecycle that already exists. It does not cancel
an underlying setter after it has entered a feature's async `onExit`.
The controlled overlapping-setter probe demonstrates that a stale
underlying setter can still commit in that general dependency case.
Standard Back admission excludes guarded sources and fallback can
start only without protected outgoing matches, so the explicit fallback
carries no such outgoing await. Existing protected features keep their
own guards. The boundary does not suppress or reroute those effects.
Forwarding the public pipeline is the smallest alternative that supplies
the missing refusal/supersession acknowledgement without narrowing
ordinary Back to a best-effort action or guessing at timings.

### 4. Keep presentation authority local

| Event or hazard | Rule and evidence |
| --- | --- |
| Disposed, removed, replaced or different owner | Guard mounted before context lookup. Check the captured route, owning Navigator and committed leaf at activation. A retained old Element is insufficient. Once removed, the old callback loses authority permanently, including when the same URI returns in a new Route. |
| Branch or temporary overlay coverage | A covered/inactive source is temporarily ineligible. Its binding can become eligible again when the same route and semantic presentation are current. A popup, a pushed root page, or visiting and returning to a retained branch does not itself invalidate the source permanently. A normal widget rebuild or locale/theme change keeps the same presentation. |
| Same Page key with different content | A route-pattern key can survive a semantic change, as observed for query A → B → A. Compare the current committed semantic leaf to the rendered source at activation. Use the existing keyed Post, Category and Search owner subtrees. Where a consumer deliberately retains its Element across distinct displayed identities, rebind only its local Back owner by semantic key or one local generation. Route Error already handles displayed URI updates. Gallery ownership follows the displayed gallery data. A stale A cannot regain authority after a distinct B presentation was bound. Unrendered routing activity with the original route and semantic presentation ultimately intact does not create an artificial new visit. |
| Refresh and restored entries | Key by live route, owning branch, effective match and relevant data, not the provider URI or referential identity of a new match list. An equivalent refresh preserves presentational authority. A reconstructed restored Route gets a new binding. For direct unmatched errors use the displayed URI and live error match because `GoRouterState.of` is unavailable there. |
| Repeated invocation | The first ordinary pop changes the live target before another activation. The shared ingress gate covers pending fallback, including two different controls on the same error. The first successful pop or fallback must not suppress a later valid activation from its actual successor. |

Use no global visit generations, observer registry, arbitrary timers or
control-specific pending Future. Cover timing both before and after
build rather than inferring ownership from descendant widget finders.

### 5. Keep the two Admin entry points distinct

**Dashboard.** Both app bars retain `_backCallback`, `_capture`, `_live`,
`_backRequested` and their captured account, owner, visit, route generation
and presentation authority. First validate feature authority and perform
the shared, side-effect-free Back preflight. Only on admission claim its
existing latch and run `_revokePresentation` once. Recheck source, account,
visit and ingress before dispatch in case revocation synchronously triggered
new input. Use GoRouter pop or the shared Home request. A successful
departure retains existing route-driven cleanup. A refused, failed or
superseded request releases only its still-owned latch, and only a
still-current Dashboard may rebuild and capture a fresh callback under
its current presentation. Check the original route, account and visit
without authorizing the deliberately revoked presentation token. Keep
the existing route/auth reset paths.
The original revoked callback, recovery lookup and refresh overlay
authority cannot be revived. Do not roll back the presentation
generation. If a newer ingress remains pending, a fresh callback is
still temporarily ineligible. Keep logout and recovery admissions
separate.

**Malformed Admin ID.** Both Route Error controls share a protected,
pop-only callback supplied by the invalid-ID router branch. It is
outside standard Home fallback and does not use the ready editor
callback. The existing `AdminSubmissionExitPolicy.exit` still decides
exit, including the unavailable binding and distinct underlying editor
visit cases. An existing dirty editor can refuse a replacement before
a malformed screen appears. No long confirmation or true refusal of
the rendered malformed page was observed in the valid tested topologies.

The concrete failure is two scheduled exits on the same imperative match.
One scoped admission belongs to the active malformed page. Claim it
before calling the otherwise identical source-qualified `GoRouter.pop`.
The deferred GoRouter hook receives no request marker in its method
arguments. Carry the admitted token in a private Dart zone value for that
one dispatch. The probe verified propagation to the scheduled pop hook
and isolation from unrelated declarative exit. Only the malformed branch
of the existing route's `onExit` reads that token. The adapter checks exact
page match, route, current account and absence of competing new
navigation before evaluating the existing policy, and rechecks after
its Future resolves. Track independent intent separately from reparsing
the same provider input, as for ordinary fallback. Refusal,
exception, supersession and disposal release only that admission. Normal
declarative auth/Sync decisions and ready editor exits continue through
their existing policy. A positive result only marks approval. Mark it as
the last operation before returning true to GoRouter, after validating
that the exact source is still the current leaf and no independent
navigation has started. While it is outstanding both explicit controls refuse duplicate
dispatch. For the malformed route only, require the exit hook's entry to
still belong to the committed stack even for an untagged callback. A
platform Back in the commit-to-build gap can otherwise replay the stale
Page's onExit and complete its imperative Future twice. Keep rejecting
that retired entry through Navigator reconciliation, independently of
whether the explicit restore is still owed. A live untagged departure
uses the original policy, including declarative exits from a retained
malformed match. An independent ingress after approval retires the restore claim. A
refresh re-evaluating the same input is not independent and leaves that
claim intact. The restore then re-evaluates redirects from the surviving
configuration. Do not treat
GoRouter's deferred removal as cancellable after approval. The existing
malformed presentation has no forward push action. Do not add arbitration
for arbitrary external imperative pushes against an approved removal.

An approved deferred pop needs synchronization after the match is
actually removed. The ordinary `GoRouter.pop` check cannot see it at
return. Use one removable listener scoped to the admitted protected pop
on the actual delegate. Require committed removal of the admitted top
entry with the expected predecessor. On that removal, detach the
listener and issue one public `router.restore` of the surviving
configuration while the exact departure still owns it. A veto,
unrelated commit or new independent request retires the restore claim. Release
the listener also on cancellation or disposal. The real-router probe
reproduced reopening after an immediate refresh in this deferred gap,
and a one-shot restore at commit prevented it. No global observer or
second editor policy is needed. No Home fallback is applicable to this
protected child.

### 6. Call-site inventory

Paths are repo-relative and line numbers refer to the planning baseline.
The search covered the entire production `lib` tree for custom and native
buttons, icons, text actions, `AppBar` and `SliverAppBar` leading behavior,
pop API variants and feature-local callbacks.

| Classification and location | Current action, authority, fallback and presentation | Existing evidence, proposed impact and regression risk |
| --- | --- | --- |
| New routing modules · `lib/routing/back_navigation.dart` and `lib/routing/app_route_request_boundary.dart` | Existing ordinary actions have no common source eligibility or request receipt. | Host the shared decision and public forwarding boundary. Verify exact outcomes across rejection, refresh, supersession, restoration and system forwarding. |
| Direct modification · `lib/main.dart:163,190` | The app holds a stable GoRouter and passes it directly to MaterialApp. | Install stable composed RouterConfig at the existing host. Preserve GoRouter ownership, disposal, provider, back dispatcher and reporting. |
| Direct modification · `lib/ui/core/ui/custom_back_button.dart:6` | Optional full override. Default nearest raw pop, surface with 8 outer padding, hardcoded platform/icon/tooltip. No fallback. | Gallery and Dashboard callback tests plus shared probe. Use native Material appearance and source-bound standard action. Repeated removal and loss of override are key risks. |
| Direct modification · `lib/ui/settings/widgets/settings_screen.dart:44` | Root Settings. Explicit custom router pop or Home with a surface background. No local Back veto. | Settings widget NAV-04 pushed/direct and Admin stack identity tests. Remove local duplicate, retain theme and Settings route. Do not touch consent dialog CTAs at 265/275. |
| Direct modification · `lib/ui/core/ui/route_error_screen.dart:67` | Root unmatched or matched invalid route, including branch errors and protected Admin malformed ID. Native Back and filled text share router pop/Home. Error URI may update in place. | Route-parameter and log-event tests. Shared bound action for ordinary surfaces and protected adapter for malformed Admin. Keep native styling, text and diagnostics. New Back must not revive old invalid URI authority. |
| Direct modification · `lib/ui/gallery/widgets/gallery_preview_screen.dart:169` | Unavailable root Gallery. Native implied leading when dismissible. Filled text tries nearest `maybePop`, then Home on false if mounted. | `gallery_route_test` invalid extra and root ownership. Bind the visible native leading and filled action to one standard callback, preserving the existing implied-leading visibility condition. Direct unavailable Gallery uses its filled action. Leave zoom, vertical drag, swipe, dismissal and overlay state alone. |
| Direct modification · `lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart:303,666,749,1034` | Root guarded Dashboard. Both app bars use the captured account/owner/visit and current route policy. Terminal router pop/Home. Surface. | Real-router Admin stack, repeated callback, revoked authority and refresh overlay tests. Share only the terminal decision. Retain refresh/recovery invalidation and logout semantics. |
| Direct modification · `lib/routing/router.dart:300,309` | Invalid Admin ID renders shared Route Error behind editor onExit, with no ready visit. Both existing buttons can submit the same imperative pop. | Install the narrow protected adapter and commit observer. Keep original exit policy and predecessor. Verify double completion, deferred provider alignment, dirty editor retention and revocation. |
| Indirect impact · `lib/ui/core/ui/scaffold_shell.dart:26,97,122`, `lib/routing/core_routes.dart:27,87` and `lib/routing/router.dart:386` | Existing shell coverage and branch inputs drive predictive eligibility, including malformed branch details. | Use current match, the branch Navigator's enclosing ModalRoute and existing disposition. Preserve the current visibility and predictive contract. Route ownership, branch retention and restoration tests cover the boundary. |
| Indirect impact · `lib/ui/admin/auth/widgets/admin_login_screen.dart:114` | Root Login, surface wrapper with raw pop and no fallback, auth-owned redirect/replacement separate. | Login widget and Admin real-router tests. Inherits safe Back and Home fallback while anonymous and standalone. Keep Settings and auth state for a pushed entry. |
| Indirect impact · `lib/ui/core/ui/custom_appbar.dart:52`, `lib/ui/post/widgets/post_screen.dart:113` | AppBar creates wrapper only for `showBackButton`. Post is branch-owned, surface, default pop, declarative section/Category/Search predecessor. | Route ownership, parameter, system Back and restoration. Keep app-bar system overlay style, actual parent and exact query. No new `CustomAppBar` option. |
| Indirect impact · `lib/ui/category/widgets/category_screen.dart:44,84` and `lib/ui/search/widgets/search_result_screen.dart:96` | Category uses a surface wrapper. The second SliverAppBar suppresses implied leading. Search Results uses zero directional padding and transparent background in SearchBar. Both are Explore/section branch details. | Route ownership and canonical redirects/restoration. Preserve canonical category slug, search `q`, SearchAnchor and branch-local predecessor. |
| Indirect impact · `lib/ui/gallery/widgets/_gallery_preview_modal_overlay_content.dart:81` | Transparent wrapped explicit Back on root Gallery. Recognized Gallery can be pushed over shell or matched alone with valid data. | Gallery routing and preview tests. Pop the exact root page when stacked, otherwise Home. Retain underlying branch State and overlay layout. |
| Presentation-only migration · `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:1264,1720` | Both ready-screen bars invoke `widget.onBack`. The editor route owns dirty exit, iOS explicit allowance, Escape, activation, sessions, blocked operations and Dashboard fallback. Surface. | Admin dirty-exit, editor admission, session target and editor widget tests. Native presentation flows through the wrapper and preserves all ready callbacks and feature CTAs. |
| Explicitly excluded · `lib/ui/admin/submissions/widgets/admin_submission_editor_route.dart:269,331` and `lib/routing/admin_submission_exit_policy.dart:383` | Opening/error AppBar implies native Back when dismissible. It invokes native maybe-pop and existing exit policy, even when an editor visit has not registered. Ready handler requires a current activation, absent in loading/error presentations. | `admin_route_test` loading Back/exit guard and dirty close. Leave implicit button in place. Sending it through the ready callback would alter pending-load or unavailable-editor behavior. Preserve retry and return-to-owner controls. |
| Explicitly excluded · `lib/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart:45,97,207` | Native visible only when terminal. Pops to the exact editor below, or returns to the active editor session or Dashboard according to activation. Text CTA uses the same feature callback. `PopScope` owns system handling. | Save Progress, admission and session tests. Already native. Keep attempt/session/editor identity, terminal visibility and owner selection. |
| Explicitly excluded · `lib/ui/content_submission/widgets/content_submission_screen.dart:155,385` and `content_submission_progress_screen.dart:72,145,160` in the same directory | Native Back uses submission-owned callback. Form hides leading without a predecessor. Progress hides Back while blocked and returns to the matching form. Home CTA is a separate successful terminal action. | Submission route, widget and restoration tests. Both already native. Preserve dirty-exit checks, checkpoints, restore, submission/finalization exclusions, external/pre-submit admission and iOS gesture allowances. Standalone form gains no new action. |
| Explicitly excluded · `lib/ui/search/widgets/components/app_search_anchor.dart:222,240` and `lib/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart:51` | Native popup Back calls admitted `SearchController.closeView(null)`. `viewOnClose` owns cleanup, session revocation and host notification. | Search Anchor tests include stale session/close behavior. Already native and independent of app routing. Preserve popup lifetime and any host callbacks. |
| Presentation-only migration · `lib/ui/geo_map/widgets/geo_map_modal_search_results.dart:68`, `geo_map_bottom_sheet.dart:147` and `geo_map_screen.dart:389,489,520` in the same directory | Transparent wrapper resolves local Back to the sheet dismissal callback and internal Explore mode with the live map center. Search popup host cleanup is separate. | GeoMap widget/routing tests. The wrapper's new visual path preserves callbacks wholesale. Never route to App Explore or revive old searches. |
| Presentation-only migration · `lib/ui/geo_map/widgets/geo_map_location_picker.dart:80,100` | Surface wrapper or Escape dismisses the current root dialog. Confirmation supplies a coordinate result, Back supplies null. | Admin location editor plus picker/GeoMap widget coverage. Preserve the existing dialog owner, mounted/current check, Escape and result. No router dependency. |
| Explicitly excluded · `lib/ui/explore/widgets/explore_screen.dart:128,160`, `lib/ui/favourite/widgets/favourite_screen.dart:25`, `lib/ui/event/widgets/events_screen.dart:115`, `lib/ui/geo_map/widgets/geo_map_screen.dart:426`, `lib/ui/core/ui/custom_appbar.dart:30` | Shell roots have no dismissible predecessor inside their own Navigator. Map uses zero-height `CustomAppBar.hidden()`, also an implied-leading surface in principle. | Branch root/restoration and geometry tests. Keep the root presentation and no new explicit Back. No blanket `automaticallyImplyLeading` change. |
| Explicitly excluded · `lib/ui/sync/widgets/sync_screen.dart:103` and `lib/ui/core/ui/logging_screen.dart:15` | Sync uses an ordinary AppBar on a redirect-owned standalone root. Debug Logging delegates AppBar behavior to TalkerScreen. | Sync redirect tests. Retain the existing Sync and third-party UI behavior. |
| Explicitly excluded · `lib/ui/category/widgets/category_content_and_type_selection.dart:182,208`, `lib/ui/weather/widgets/components/weather_forecast_modal.dart:58`, `lib/ui/core/ui/unsaved_changes_dialog.dart:43` and Admin/Submission/Settings modal results | Close, cancel, confirm and decision-result actions belong to their own modal or command. | Existing flow and modal tests. Preserve feature results and owner state. |

### 7. Canonical boundaries

Use a new `explicit-back-navigation` capability for cross-feature explicit
interaction. `canonical-app-routing` owns slugs/parameters, `q` and canonical
restoration. `main-navigation-shell` owns branch identity, Gallery topology and
system/predictive Back, including unresolved NAV-01. Dashboard/Settings identity
and auth rules also remain in `command-execution-concurrency`. Preserve
`admin-submission-editor`, `content-submission-navigation-lifecycle`,
`geo-map-semantic-state` and `editor-picker-restoration`. Content Submission
already requires native Back visuals/semantics and stable AppBar geometry.

The active `redesign-admin-submission-editor` plan touches editor presentation
and owner preservation. It excludes Dashboard changes and continues to own its
layout. `optimize-image-rendering-and-empty-view` touches Gallery/Post media
and Error/Empty presentation indirectly. Preserve live Gallery pop results, slideshow suspension and error-action
reachability within the existing refresh behavior. The shared files do not
justify concurrent changes to one control from both plans. Review overlapping
hunks when implementing after either lands.

## Risks / Trade-offs

- App-host forwarding increases the compatibility surface when Flutter or
  GoRouter changes. Verify the forwarding contract independently of widget
  output. Preserve the original parser inputs and output except for a refresh
  that would replay this feature's refused fallback, and forward all reporting
  and system dispatch to the original participants.
- Flutter invalidates old parser results before delegate entry. Existing
  async feature setters already entered may still settle independently.
  The ordinary path is limited to unguarded sources, and the protected
  malformed adapter rechecks its own deferred approval. A new guarded
  consumer needs explicit feature admission.
- Existing reporting followed by refresh can reconstruct imperative matches
  and strand a Future the app previously received for a surviving entry.
  The change preserves the actual Back target and completes its live result.
  Fixing decode or arbitrary refresh preservation across all routes is a
  separate dependency issue. The active Gallery plan still owns its existing
  presentation behavior and the result of directly popping its live match.
- Dashboard eligibility recovery must release only the original latch, with
  fresh controls for the current authorized presentation. An async receipt
  must not recreate a retired notification or revive a recovery attempt.
- Keep the AppBar constraint explicit. At 56 pixels with outer 8 padding,
  the existing center hit region measures 40 × 40 even under a mobile theme.
  Test the interactive render box and edge taps separately from the glyph.
  In an unconstrained padded mobile host expect the native 48 × 48 target.
  Preserve native desktop sizing, center alignment, backgrounds and the
  existing default/custom padding. The constrained baseline remains an
  accessibility limit and does not justify editing toolbar geometry here.

## Migration Plan

Add the app-host completion seam and its forwarding regressions first.
Then deliver the ordinary decision and presentation binding, connect the
controls and add the narrow Admin adapters. No persistence or deployment
migration is needed. A rollback restores the previous app-host wiring and
controls together.

### Verification strategy

Use real `buildAppRouter` with the app's composed host for acceptance.
Continue reusing route ownership, Sync, auth, Content Submission and editor
test support. Controlled dependency fixtures are appropriate when actual
ordinary production input does not expose a reproducible rejection. Use
selective microtask advancement and frame checks before settling transitions.
Assert attempt count, committed route, reported input, Navigator page count,
retained Route/State and live result completion independently.

Scope existing `find.byType(BackButton)`, `find.byType(CustomBackButton)`,
`IconButton` and localized tooltip queries to the originating surface.
Preserve captured callback re-invocations, absence assertions and local
feature ownership in the existing suites. Exercise platform Back separately
and retain the upstream NAV-01 skip and assertions. Report native device
checks separately from simulated gestures.

### Planning audit

The applicable repository skills cover Flutter UI, mounted/context safety,
test reuse and OpenSpec remediation. No active repository documentary-audit
skill or command was available. Manual review compared the proposal, design,
scenarios and tasks with the pinned sources and observed baseline, with
independent reads of routing lifecycle, pop dispatch and Admin ownership.
The repository has no new overlapping changes since the initial plan.
