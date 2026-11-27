# Design

## Context

Planning on 27 November 2026 used investigation baseline
`8c0e61ea42d98641bbb57d829627171bd1a3d279`. Local HEAD, local main,
cached origin/main and GitHub main matched it. The intervening commit range
was empty. The originating worktree contained only two untracked inputs,
`admin-navigation-authorization-investigation.md` and
`admin_authorization_investigation.dart`. Both were copied and checksum-verified
before creating a clean, isolated planning branch at the baseline. The
originals remain available for the implementation comparison. The 38 opt-in
characterizations passed again on the baseline. Their assertions include
the defective behavior. The original investigation's 507 Flutter and 88
autonomous Edge Function test results are historical evidence.

| Resolved environment | Version |
| --- | --- |
| Flutter stable / Dart | 3.47.5 / 3.13.4 |
| Flutter framework / engine | `6a19cca56475dbfba1478ee68d7bd0c2ef891da1` / `af7e796e161ae0bb1ff0758c71a7105418bd9ded` |
| GoRouter / command_it | 18.0.2 (`^18.0.2`) / 9.5.2 |
| material_ui / cupertino_ui | 1.5.0 / 1.1.1 |
| supabase_flutter / supabase / gotrue / supabase_common | 2.18.0 / 2.16.2 / 2.27.2 / 0.1.2 |
| functions_client / postgrest / realtime_client / storage_client | 2.7.1 / 2.9.1 / 2.13.0 / 2.8.1 |
| sentry_supabase / Edge Function supabase-js | 10.0.0-rc.2 / 2.112.3 |

The authoritative change inventory had no overlapping active change. The
original worktree's apparent `improve-admin-submission-editor-workflow`
entry contained only ignored Finder metadata. The archived
[Dashboard navigation and refresh](../archive/2026-11-11-harden-admin-dashboard-navigation-and-refresh/proposal.md),
[Admin dirty exit](../archive/2026-10-29-harden-admin-dirty-exit/proposal.md),
[explicit Back](../archive/2026-11-27-unify-explicit-back-navigation/proposal.md) and
[main navigation shell](../archive/2026-10-07-harden-main-navigation-shell/proposal.md)
provide the relevant behavior and lifecycle history. The
[deferred-exit record](../../../docs/navigation/harden-deferred-route-exits.md)
is independent. Existing canonical routing, shell, explicit Back, content
sync, draft persistence, staged assets, save idempotency, picker
restoration and external moderation contracts are compatibility checks.

## Baseline source findings

- **F1 and F4, retained history.** The router listens to auth through the
  merged refresh listenable. Its redirect first applies Sync and otherwise
  tests the requested matched location and current Admin boolean. During
  the frame gap the provider can still hold a push request with its captured
  base even though the delegate committed the cover. The parser processes
  the top-level guard and redirects before interpreting the push. Login
  can therefore be installed above the captured Admin base. Back exposes
  the same Dashboard or diagnostic. Existing and new Editor and Save
  Progress history also belong to the protected subtree. The reproduced
  editor paths showed unavailable presentation and rejected old
  operations. The control with the cover already installed followed a
  different reconciliation path.
- **F2 and F3, Dashboard ownership.** The Dashboard Provider is created
  within the route and starts its first list read in `create`. The screen's
  auth listener resets visit, recovery and feedback bookkeeping but
  neither revokes the ViewModel nor gates its entire protected content.
  The ViewModel checks disposal at command dispatch. Retained filter,
  retry, editor and reactivation callbacks rely on widget/Provider owner
  identity, which survives A-to-B. Some continuations already capture
  stronger route and account context. The repository invokes the Edge
  Function via the shared Supabase client, whose HTTP wrapper can resolve
  current credentials at request dispatch. The probes measured synthetic
  repository admission, cached data and local outcomes. The moderation
  dataset is shared among authorized administrators.
- **Queued auth observations.** Resolved GoTrue has asynchronous and
  synchronous auth streams. The current owner subscribes asynchronously
  and ignores each event payload in favor of rereading `currentUser`.
  A queued interruption can therefore be collapsed into a same-account
  reread. Login/logout completion rereads remain necessary to preserve
  actual-session and attempt correlation. An authority observation must
  preserve any delivered evidence of interruption without granting a
  stale event's session.
- **Pending editor activation.** The app-owned editor binds directly to
  auth, but its revocation listener compares a non-null active account
  assigned only after activation finishes. A direct replacement during a
  first pending activation can miss that branch. In particular,
  `AdminDraftSession.activateBySession` checks session generation after
  its account-qualified lookup and before activating the returned draft.
  Without timely revocation, an old lookup can reach that inner activation
  even though the outer ViewModel eventually rejects publication based on
  the current account. The route's auth listener also invokes activation
  again using live auth, while the State may still represent the old visit.
  This is a source-established missing boundary, with runtime effects
  dependent on completion order. Treat it as an Editor lifecycle and
  account-isolation risk until the controlled regression runs. The baseline probes focused on already
  activated editors. They establish no private-draft disclosure to B.

## Dependency assessment and decision checkpoint

[Pub.dev versions](https://pub.dev/packages/go_router/versions) list 18.1.4
as latest stable. Cached published source for both releases was compared,
including the complete library and changed upstream test inventory.
GoRouter 18.1.4 has identical package constraints to 18.0.2 apart from its
own version. Both require Dart ^3.12 and Flutter >=3.44 and accept the
locked Material and Cupertino versions via ^1.0.0. The app's pinned SDK,
locked UI dependencies and other direct runtime inputs match those
constraints. No resulting lockfile or full dependency resolution has
been tested in planning. Inspect the actual resolver output at upgrade.

| Release | Relevant changes and implications |
| --- | --- |
| 18.1.0 | Shell/branch clipping reaches nested Navigators. Default clipping stays hard-edge. |
| 18.1.1 | Redirect zone handling no longer reclassifies unrelated async errors. Shell page/Navigator identity and branch configuration/observers change, including retained, inactive and preloaded branches. |
| 18.1.2 | Shell semantics change around overlays and text field focus. Check Search, Gallery and protected semantics. |
| 18.1.3 | Nested regex parsing changes matching. Recheck canonical paths, malformed IDs and query handling. |
| 18.1.4 | Branch activity controls the wrapping PopScope vote. Inactive branches stay mounted and cease vetoing the active branch. Upstream tests exercise branch changes and retained state. |

Relevant sources are the [release changelog](https://pub.dev/packages/go_router/changelog),
[published revision](https://github.com/flutter/packages/tree/go_router-v18.1.4/packages/go_router),
[inactive branch issue](https://github.com/flutter/flutter/issues/188018)
and [related predictive Back work](https://github.com/flutter/packages/pull/11910).
Keep the GeoMap NAV-01 assertion and attempt it on the upgraded version.
Enable it only if the original assertion passes for the intended branch
reason. Native predictive Back and its cancellation remain device gates.

The provider, parser, delegate and router files are byte-identical between
published releases. The provider still notifies on refresh without rewriting
its request, the parser still appends redirected imperative matches to
captured bases and can reuse a decoded restoration base, and the delegate
still calls exit guards before installing a replacement configuration. Its
physical Back approval and push-result completion remain separate from
declarative removal. The builder's page/Navigator changes are relevant to
what is installed and when. Source inspection predicts that the Admin
history mechanism remains, but the original sequence must decide.
After rerunning on the dependency-only commit, classify F1–F4 and any
other behavior as unchanged, resolved upstream, behaviorally changed or
new. Record exact installed history and owner evidence. Omit any history
correction proven redundant. Dashboard ownership and authorization are
independent acceptance conditions. Deferred ordinary exits stay out of
scope.

### Observed dependency checkpoint

The dependency-only commit `d715bcb` resolves pub.dev stable 18.1.4. Only
GoRouter changed in the lockfile, resolved package graph and package
configuration. Flutter 3.47.5, Dart 3.13.4 and both UI packages stayed
at their baseline versions. The four core files remained byte-identical
and the builder differed.

The same affected suites passed on both releases with 1,633 successes
including all 38 original characterizations, and one ordinary NAV-01
skip. The opt-in probes assert the original defects as well as controls.

| Finding | Classification | Observed on both versions |
| --- | --- | --- |
| F1 | Unchanged | The uninstalled-cover order left A's Dashboard Route active under Login. System Back restored the original Dashboard and its loaded data. Ordinary loss and the installed-cover diagnostic control left Login at the root. |
| F2 | Unchanged | A stale Dashboard action reserved reactivation and dispatched the captured source ID. Fake success started both follow-up reads and published the pending ID on the retained owner. |
| F3 | Unchanged | A-to-B retained the original Dashboard and owner without a fresh read. An outstanding A read could publish to the retained owner. |
| F4 | Unchanged | Back resurfaced the same malformed diagnostic and retained Editor and Progress history in the cover cases. Existing Editor guards rejected the tested stale private actions. |

NAV-01 returned `true` for Map-root Back on 18.0.2, with the inactive
Post stack and State preserved. On 18.1.4 the original assertions all
held. The scratch run needed the existing explicit owner teardown helper
for deferred command timers. The upstream builder qualifies its wrapper
`PopScope` with active-branch state. The permanent test uses the same
assertions and that teardown helper. Physical-device predictive Back and
cancellation remain open. The Admin history and ownership fixes remain
required independently of NAV-01.

## Decisions

### Put continuity in the existing auth owner

Expose a narrow Admin authority identity from `AdminAuthViewModel`,
qualified by its owner and account. Replace it on observed loss,
replacement or stream error and issue a new one on authorized recovery.
Commit that change before notifying any listener. In production the router
resolves auth when the app creates its router, while Provider can
instantiate the editor on demand and bind its auth listener later. The
Dashboard registers its own listeners when mounted. Callers compare their
captured identity against the current value independently of those
registration positions and any synchronous reentrant notification. Profile
and token changes alone preserve identity. Use the existing SDK event
boundary to preserve rapid interruptions. Prefer keeping the async stream
and using ordered event evidence to retire continuity when a delivered
event conflicts with it. When that event is older than the live session,
withhold a new grant until a current authorized observation is available
so callbacks cannot borrow the replacement in a reentrant notification.
Test actual GoTrue event ordering, including login/logout reconciliation.
The resolved synchronous stream receives event data but SDK
`notifyException` adds errors only to the async stream, so a switch by
itself would lose fail-closed recovery. Keep this in
the existing owner and retain separate login/logout operation correlation.
This is an observed-client contract. A server role change becomes part of
it when it reaches the application.

### Reconcile protected history through the existing router

If the upgrade leaves a gap, distinguish an authority-driven reconciliation
from ordinary auth notifications and navigation. Inspect both the committed
match tree, including imperative descendants, and the actual installed
pages, with pending requests and restored state treated as inputs. Retire
previous-interval Admin bindings immediately. Prefer a qualified replacement
using supported GoRouter navigation APIs and preserve an unaffected public
branch or ancestry where the candidate proves it safe. The supported
`RouteMatchList.remove` and `GoRouter.restore` APIs are candidates for
restoring a proven clean prefix. Removal can truncate later matches, so
a valid public cover above retired Admin may need fresh navigation to its
public destination. Verify that restoring a clean base retains intended
Page identity and that any subsequent push uses the newly committed
base, rather than dispatching a push against stale configuration.
A fresh declarative landing is the bounded fallback when a public prefix
cannot be proved safe. A redirect string alone cannot change push
semantics. Direct Navigator pops while
GoRouter owns the match list can desynchronize the two, and unconditional
stack resets discard valid Settings and shell history.

For an active Admin surface, observed external loss goes to Login and
direct replacement goes to a fresh Dashboard. Existing admitted explicit
logout may already have left to Home. Keep unrelated public navigation
when possible and avoid routing to Admin simply because a role changed
while the user is on a public route. Sync keeps running and fatal-error
precedence. Preserve validated public return URIs, but resolve previous
Admin return intent to the currently eligible landing without old editor
arguments. If restored Admin history has no trustworthy continuity,
admit a fresh authorized destination through normal route and draft
validation. History metadata and session hints do not grant authority.

Bind each reconciliation and admission to its authority and route
ownership so a rapid transition or completion cannot restore a retired
base. Cover pending `onEnter` and `onExit`, installed transition frames,
pageless dialogs/overlays by exact identity, and public routes above Admin.
Only removal of obsolete authority bypasses dirty-exit or progress vetoes,
including A returning after an interruption. Preserve ordinary authorized
guard decisions and Back results. Some push futures can remain pending
after replacement. Retire caller presentation/continuations independently,
using the existing recovery admission acknowledgment as precedent.
Validate the supported router path before choosing a helper. Keep any
helper confined to this Admin boundary.

### Replace the Dashboard owner

Prefer permanently retiring the existing route-owned ViewModel and making
a new Provider owner only for a fresh eligible authority. This keeps the
existing three lanes and gives B independent state without maintaining
multiple live generations inside one owner. Use a stable captured
authority as part of binding and validate before the first read.
Guard the entire protected subtree separately from route disposal,
including semantics, focus, menus, dialogs and Snackbar ownership.
Withdraw previously public state immediately on revocation, including
cache and public snapshots, pending IDs, selection/refresh feedback and
recovery/navigation intent. Reusing a ViewModel with a generation tag
would require clearing every exposed value and qualifying every
continuation across owners.

Capture authority when rendering callbacks or creating continuations.
Validate it at callback invocation, ViewModel reservation, after any
synchronous notification that can reenter, and immediately at command
body repository entry. Check again before each follow-up phase and
publication. Use the corresponding visit, lane, selection or execution
identity where the existing workflow already requires it. Audit first
load, filter, manual and pull refresh, retries, ignored-source read and
reactivation, pending link, new/existing editor, recovery, dialog/menu,
logout/Back and editor return. Checking the current role at invocation
alone lets an old callback borrow B's authority.

Retire public state synchronously while retaining private settlement
observers. Command_it publishes running state and yields before calling
the handler. A reservation revoked before dispatch must therefore be
settled even when no repository starts. Preserve action-settled witnesses,
terminal revision checks and the deferred barrier outside upstream
notification/finally. Let already-started reads or mutations settle and
keep expected Result handling, original unexpected reporting and fail-loud
assertions. No follow-up ignored/submission refresh or outcome publication
can originate from revoked work. Physical completion can include a commit
under existing server authorization. Local retirement does not cancel
or roll back a submitted transaction.

### Protect the pending Editor boundary

Qualify route admission and pending activation by the captured authority
before the first await. Invalidate pending as well as established runtime
activation when that authority ends, before stale draft lookup or asset
reconciliation can install a context. Retain the existing session
generation checks, account-qualified lookup, activation token checks,
Save Progress attempt binding, durable write ownership, dirty-exit and
picker restoration. An obsolete route never reactivates against live B.
Prove B cannot see or claim A's draft and returning A must enter through a
fresh visit to recover durable draft and staged assets. The narrow pending
activation correction addresses the source gap. Existing editor command
and persistence architecture remains the basis.

## Implemented decisions

`AdminAuthViewModel` publishes an opaque, account-qualified interval before
notifying dependents. The GoTrue event snapshot can retire an interval even
when the live session has advanced. Grants require a matching live user
observation or a correlated successful SDK login. Stream failure retires the
interval. Same-account profile updates and refresh preserve it.

The Admin-specific GoRouter integration replaces route information using the
clean prefix from `RouteMatchList.remove`, a qualified provider push, or a
bounded declarative landing. It may restore the original eligible public
cover over a clean prefix. Its parser checks saved and pending bases before
installing their matches. Committed Admin configuration must carry that
parse's authority because the delegate can finish an already-approved exit
after Flutter discards its old parser transaction. A late obsolete commit
cannot admit private builders and triggers another bounded reconciliation.
The declarative Dashboard Page rotates with authority. Existing imperative
Pages retain their unique GoRouter keys. The exit policy releases old
reservations and removes its exact dialog; Progress bypasses its exit veto
when the committed configuration retires. Unrelated public auth events
leave navigation untouched.

GoRouter 18.1.4 compares the old and new route-match sequences and checks
the exiting suffix after the first difference. Removing an Admin match
beneath the public Content Submission form can therefore ask the same
form to exit. The reconciliation restore carries the exact source and
replacement configurations through the parser and delegate continuation.
The public exit policy accepts that callback only when the current
retiring source and the approved replacement contain the identical
imperative match for its Page key. The original form and any current
Progress Page retain their route and operation ownership. A genuine
public exit still owns its existing decision. If a public go has arrived
but has no exit decision yet, reconciliation removes Admin history first
and reissues that request from the committed safe configuration only
while its route information is still current.

A Dashboard owner binds before its first read, drops protected state on
revocation, rejects later execution boundaries, and lets physical work
settle privately. Both ordinary Dashboard errors use the application
ScaffoldMessenger. The Dashboard retires its visit's feedback signal.
An owned entry waits for its predecessor in Flutter's queue before it can
withdraw, suppresses retired content, and relinquishes removal authority
when it closes or the queue resets. Unrelated entries retain their order
and duration. The existing persistent recovery request keeps its selective
cancellation, ordinary-tail suspension and authoritative revalidation.
The Editor captures route
authority before activation, with the existing draft session checking the
captured authority at lookup and installation boundaries. Revocation clears
runtime state and preserves the account-qualified durable checkpoint and
assets.

The Settings and Gallery reconciliation tests now trigger an explicit
router refresh to preserve their stale Page and completer assertions.
Unrelated public Auth events no longer induce that reparse. The existing
replacement exit test waits for the new observed authority before making
its fresh Editor request and keeps its original reservation assertions.

## Autonomous verification

- The affected Flutter suites passed 2,577 tests. The complete suite passed
  4,519 tests with five existing skips and zero failures. The isolated
  checkout used the repository's existing ObjectBox native library and Rome
  timezone. Static analysis and formatting checks passed.
- The autonomous Deno suite passed 246 tests, including the Admin function
  and shared tooling. Strict OpenSpec validation passed for this change.
  Strict canonical-only validation reported the same 17 existing warning
  failures as the investigation baseline, with identical findings.
- A1 covers real queued GoTrue observations and refresh/error controls.
  H1–H4 assert installed Pages and Routes, pending commits, public ancestry,
  encoded restoration, Progress and dirty exits. D1–D3 cover retired UI,
  semantics, feedback, reservation, dispatch and private settlement. E1–E2
  cover pending draft isolation and existing durable recovery and Save paths.
- Temporary negative controls failed as expected when event payload evidence
  was discarded, Dashboard entry guards were removed, a pending Editor
  lookup was allowed to install under revoked authority, or a late route
  commit received the replacement account's authority. The variants ran
  outside the permanent diff.
- The [disposable runtime results](test-plan.md#observed-local-runtime-results)
  include actual gateway effects and the shared SDK request boundary.

### Independent review remediation

The affected Flutter suites passed 1,923 tests. The complete Flutter suite
passed 4,529 tests with five existing skips. NAV-01 passed with its original
assertions. Formatting, Flutter analysis and strict validation of this
change passed.

The reviewed routing implementation failed the dirty, pending operation
and existing exit-decision cases. The repaired path also passed a refresh
that reparsed the same reconciliation request. Temporary negative controls
showed that removing the retained-route qualification restores the original
routing failures. Removing same-turn dismissal protection or queue reset
invalidation allowed a stale retirement to remove the next Snackbar.
The backend and dependency inputs are unchanged from the verified
implementation. The local runtime evidence and open release gates still apply.

## Risks and verification boundaries

The [test plan](test-plan.md) defines the automated, local runtime and
physical-device checks. Timing-sensitive acceptance uses the actual
installed Navigator pages, not just a URI or pending push result.
Production observations on four RLS-enabled tables, ten examined RPC
grants and deployed Edge Function v15 are external investigation evidence.
Repository source configures JWT verification and requires a looked-up,
non-anonymous user with strict Admin metadata before the privileged store
is constructed. The disposable runtime gate measures effective responses
and synthetic side effects with old tokens. An unexpired token may remain
usable after logout according to the [Supabase sign-out contract](https://supabase.com/docs/guides/auth/signout).
Deployment-specific differences remain explicit. An established material
backend defect or an incompatible latest stable resolution requires a
separate owner decision. The owner also retains publication authority
after PR review, implementation verification and device evidence.
