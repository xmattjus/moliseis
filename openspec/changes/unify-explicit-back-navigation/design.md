# Design

## Baselines and evidence

The original planning baseline is `70f7cef7ec4e92363e43e67d96c71ae0ecb6da8d`.
Remediation examined main at `69ee22bf23bcd7292871652272755369bfa4d071`
and the aligned draft head `5e42047459553e4c5c690777fee76ada4810c013`.
The resolved toolchain is Flutter 3.47.5 (framework `6a19cca564`), Dart
3.13.4, GoRouter 18.0.2, material_ui 1.5.0 and OpenSpec 2.1.0.
Dependency behavior below describes those versions.

PR #51 moved the slideshow pause to Gallery presentation ownership. PR #52
synchronized and archived [image rendering](../archive/2026-11-25-optimize-image-rendering-and-empty-view/design.md)
and the [Admin workspace redesign](../archive/2026-11-25-redesign-admin-submission-editor/design.md).
The [Gallery remediation record](../../../docs/performance/image-rendering-implementation.md#gallery-presentation-lifecycle-2026-11-25)
and `test/routing/post_gallery_lifecycle_test.dart` carry its evidence.
The original planning experiments characterized direct Navigator pop,
branch switches, stale imperative Gallery pop and the Admin route split.
Remediation reran focused baseline regressions and probed the unmodified
router for unmatched errors, covered editor exits, Dashboard admission,
Gallery refresh/replacement and historical Admin restoration. A native
widget composition and a URI round trip were tested separately. These
checks bound the plan. The new behavior still requires implementation
regressions.

## Explicit Back qualification

The shared decision selects one terminal action from a verified source.
It can pop the originating Route, request named Explore root for an
eligible standalone source, or do nothing. A custom callback bypasses this
decision. Dashboard may reuse the terminal decision after its own checks.
Protected editor, submission, progress, Search Anchor, GeoMap, picker and
logout actions retain their own decisions, results and visibility. Shell
roots, Sync, Logging/Talker and Close/Dismiss keep their existing controls.

Qualify the originating Flutter Route and owning Navigator at activation.
Check the actual current presented source against the committed route
configuration. A root page or popup can cover the shell even when a branch
page remains locally current. Use the committed active branch Navigator key
and actual current root shell route when qualifying branches. An inherited
branch visibility value can lag a branch switch until the next frame.
Keep the shell and branch pop-scope behavior for platform Back.

Structural `NavigatorState.canPop()` tests local history or internal pop
handling without consulting disposition. `GoRouter.canPop()` can see root
or committed shell history and alone cannot qualify the source. In the
pinned delegate, `pop()` walks the committed shell chain while its enclosing
modal routes are current, then chooses the deepest structurally poppable
Navigator. Dispatch only when that selection targets the verified owner
and can remove the originating page. An internally handled local-history
pop is not route departure. Require a permitted disposition and no active
native Back gesture on the source. A veto or a bubble against existing
history leaves the stack alone. Failed qualification never turns an
existing predecessor into a standalone fallback.

An eligible genuine first page with no predecessor may naturally bubble.
Only an ordinary source that permits fallback may then request
`goNamed(RouteNames.home)`. This replaces the stack and selects the
canonical Explore root even when Explore retains a detail. Explore root
itself is a no-op. Admission and redirects still run. A denied action
causes no second dispatch. Independent subsequent activations of an
otherwise eligible ordinary source can act. Ordinary controls do not
derive pending or refusal state from provider divergence or consume a
departure latch. Dashboard's feature authority is separate.

### Installed Page and imperative match

A committed configuration can change before the Navigator updates a
retained Route's Page settings and GoRouter's Page-to-match mapping.
Same key and same displayed content can still point to a different
imperative completer. Use the actual installed Page observation
(`ModalRoute.settingsOf`) where the ordinary action may pop imperative
history. Pair the Page with the entry that produced it. The observation can
use the Page's construction input where delayed mounting or a child
rebuild would otherwise infer the match from newer committed state.
Reading a live match on each build or at first observation of an
unproven Page does not establish the pairing. Use public routing and
Flutter APIs at the affected Page boundary and keep the comparison
local. If the pairing cannot be proved, make no request. Purely declarative
sources need only the current owner and relevant committed presentation
identity.

For regular matched pages, the generating state supplies the match key.
A Page-local association must distinguish a live entry from one replaced
under that key. In 18.0.2 imperative match equality includes the wrapped
match list and completer. An equivalent wrapper with the same effective
mapping and uncompleted result may remain eligible. For an unreconciled
new entry, refuse the old Page without consuming either result. Once Navigator
installs the corresponding Page, a valid activation can act. An ordinary
rebuild must be unable to stamp old settings with a newer match, including
when a control first mounts or becomes visible during that window.

Use public `GoRouter.pop()` for a qualified ordinary pop. Prior Search Post
work showed that a direct Navigator pop can leave the removed Post in
the provider and reopen it on immediate refresh. In 18.0.2 it
synchronizes route information via `restore` when removal changes the
configuration synchronously. This preserves a subsequent refresh of the
survivor. Deferred `onExit` is a separate path. System Back and native
gestures use the existing Navigator and platform behavior, including
predictive cancellation. The pinned provider may still report obsolete
route information before native removal is reported. The codec can also
replace in-process results after restoration or refresh. The plan leaves
those general limitations in place.

### Presentation identity

Authority follows a visit to a displayed semantic presentation and its
physical Route. If the committed source no longer matches the installed presentation,
the old control is ineligible even while still onscreen. When the installed semantics
change, retire the old binding permanently, including when the same value
later returns. Temporary coverage suspends ordinary eligibility. A
reconciled equivalent refresh, theme or locale change, or temporary cover
and reveal of the same presentation preserves its ordinary binding. A
retired or recreated physical Route requires a fresh action even if the
Page key stays the same.

| Surface | Identity and ownership |
| --- | --- |
| Category | Existing slug-keyed owner within the originating branch. |
| Post | Existing parsed ID and content type owner, tied to its canonical match and branch. Parent/search parameters still qualify ancestry and preserve the exact predecessor. |
| Search Results | Existing query-keyed owner. Search Anchor remains a local close. |
| Settings and Login | Fixed surface and originating Route, with imperative entry qualification when pushed. Rebuilds and form or settings state do not create new route identities. |
| Ordinary Route Error | Originating route and the displayed diagnostic tuple already used for log deduplication (URI text, error runtime type and safely rendered reason). Semantic change within a reused Page retires the action. |
| Gallery and Gallery Unavailable | Physical Route and locally observed Page plus result mapping. The valid presentation uses the serialized immutable opening snapshot, including ordered media fields and initial page. Reparsed equal data or a user swipe does not retire it. Valid and unavailable are distinct presentations. |
| Dashboard | Existing owner, account, visit, route generation and presentation authority. Its own revocations apply even where ordinary coverage would only suspend eligibility. |
| Dedicated and historical Admin diagnostics | Same diagnostic identity rule with the route-supplied protected policy. The historical entry remains a matched editor-route diagnostic with its existing exit hook. |

Use existing key boundaries and local screen state when they already retire
old actions. Avoid semantic snapshots of unrelated application state.

### Ordinary route errors

A matched validation error uses the actual GoRoute and owning Navigator,
including branch ancestry and branch pop scope where applicable. The
diagnostic text is for display and logging. The route supplies any
protected Back policy explicitly. Both leading and text use one bound
action. Keep the existing diagnostic reason and log deduplication.

The app's GoRouter `errorBuilder` also handles unmatched errors. The pinned
builder creates a standalone root error Page from an error configuration
with no matched entries. It builds a pushed unmatched error from the
imperative entry's inner error match list and maps the resulting root Page
to that outer entry. The default Page key is derived from the error URI
and differs from the pushed entry key. `GoRouterState.of` cannot establish
standalone ownership because this Page is absent from the state registry.

The error builder supplies the exact error object from the configuration
that generated the displayed diagnostic. This gives a local association
alongside the installed Page and root Route. For a standalone source,
verify it against the currently committed standalone error configuration
by the originating error and URI, and require the actual first root Page
and absent predecessor. For an imperative source, verify the selected
root Page against the committed top imperative error entry through its
inner error object and URI and the installed Page-to-entry association.
A replacement error with equivalent text is eligible after reconciliation
of that Page, while equivalent presentation identity can preserve the
action. Do not infer the association from URI or error text alone. The
pinned builder passes the exact inner error object through, and refresh
decoding constructs a new error and result. If inspecting the error Page
at construction is needed, use the existing error builder boundary or
public `errorPageBuilder` with the same platform-appropriate transition and
restoration behavior. No normal matched-route requirement applies to a
standalone unmatched error.

The real router probe verified standalone Explore fallback and pushed
unmatched Back to the exact Settings Route. It observed the old error
object and installed Page before build, then a new error object and Page
on the same Route, and only the live result completed by explicit pop
with immediate refresh. Same-URI duplicate error Pages in a synthetic
stack are outside the original URI-keyed builder's demonstrated support,
and must never authorize a pop by URI alone.

### Gallery lifecycle

The shipped slideshow opens a new root presentation with
`GalleryPreviewScreen.show`, which snapshots media and initial index,
and pushes a new entry. Refresh/restoration decodes the existing values
and can preserve the Flutter Route while recreating both the data object
and imperative result. A stale native or unqualified pop can instead
recreate the physical Route with the same Page key. Qualifying an explicit
Back action protects the live imperative entry. Physical completion and
slideshow admission belong to the existing `GalleryPresentation`
contract, including opening refusal, supersession, coverage, early and
stranded results, and same-key Route recreation. Preserve its Page
construction, replacement observation, reservation, release and autoplay
checks.

A synthetic `GoRouter.replace` probe reused the same Route and installed a
different media payload. The app has no Gallery replacement caller, and
external entry has no mechanism to provide a new valid media extra.
Ordinary rebuild, swipe, refresh and supported restoration therefore do not
replace the opening snapshot. If a different installed valid payload is
encountered, an old action cannot authorize it. Retire departure authority
on that semantic change. Providing in-place resynchronization of the
Gallery index, controller or restoration bucket for arbitrary extra
replacement is outside this plan and the supported opening contract.

### Dashboard refusal and retry

Both AppBars use `_backCallback`, `_capture`, `_live`, `_backRequested`
and `_revokePresentation`. Preserve account, visit, route generation,
recovery and lookup ownership. Run shared preflight before consuming the
latch or revoking local presentation authority. Once admitted, retain the
Dashboard's one-action policy for that generation.

A real foreign-session lookup held by the active editor blocked a request
to reach standalone Dashboard. The editor retained its activation.
After the lookup settled, a declaration reached the standalone Dashboard
and the actual Back control went to Explore without a recovery write.
This does not exercise a refused fallback from a live Dashboard. Source
inspection places the outstanding lookup or moderation authority at the
editor visit. Unregister can leave an invocation occupied after releasing
the reservation, and sign-out or stale authority follows the existing
admission cleanup path. No user-accessible sequence was established in
which that occupancy refuses fallback from an already valid standalone
Dashboard. Preserve its latch and existing reset conditions, including
the scope of its feature-owned retry. A failed shared preflight consumes
nothing. A later ordinary action does not imply a Dashboard reset after
dispatch, and provider divergence is insufficient evidence of refusal.

## Protected malformed Admin diagnostics

Keep the named editor route and use its local redirect for IDs the
`RouteParameters.submissionId()` codec rejects. Create a dedicated
protected sibling under Dashboard (for example,
`/admin/submission-error/:id`) without editor registration or deferred
editor `onExit`. Valid positive IDs, including supported noncanonical
representations and valid IDs with unavailable records, retain the editor
path. Specific New and Save Progress routes and names remain authoritative.
Direct use of the dedicated path with a valid ID or reserved token
returns to Dashboard subject to existing admission and auth. It cannot
forward into an editor.

Global `onEnter` evaluates the normalized incoming URI before top-level
and local redirects. Keep authorization, stale-owner and occupied-operation
checks first. Classify the editor destination once in that admission
evaluation using the codec and the existing route shape. Carry New,
valid existing ID, malformed ID or non-editor through the relevant
same-owner, hint lookup and identity checks. Preserve existing New
behavior, including legitimate session handoff. Malformed destinations
have no editor identity and must not start foreign-session lookup,
recovery or activation. Leave Sync precedence and auth re-evaluation
during redirects intact. The pinned parser wraps the redirected
destination with the original push intent and result, preserving its
actual base. Declarative entry retains Dashboard ancestry.

Carry the decoded ID as one URI segment and preserve the input's
normalized query and fragment. Determine the original editor diagnostic
URI by reversing only the normalized path transformation. Preserve an
encoded slash as part of the ID, literal percent encoding without a
second decode, repeated query keys in order, empty values and the
fragment. Avoid the single-value `queryParameters` map for transport.
The contract starts at the Dart/GoRouter-normalized URI, after parser
normalization such as leading and trailing slash treatment. Raw input
spelling, percent-escape case or already-normalized representations
cannot be recovered. Distinguish zero, negative and overflow from
accepted forms such as leading zeros, plus signs and positive hex.
Reserved names must continue to resolve to their specific routes when
they are matched there.

The diagnostic's leading and text actions use one qualified
predecessor-only departure. Popping the dedicated diagnostic removes just
that Page, including over an editor whose activation or decision is still
owned by the editor. With no deferred hook, an eligible explicit pop
commits and synchronizes immediately. Requests captured from the old Page
cannot remove its successor. Concurrent platform requests already inside
`maybePop` recheck the captured top after the asynchronous check. A new
platform request made against the newly exposed predecessor is independent.

A declaration that removes an editor still consults its actual exit
policy. An unrelated covering diagnostic can cause `_presented` to veto
even a clean editor. Neither route may simulate the other's removal.
A concrete allowed declaration is replacing a dedicated diagnostic above
Dashboard with Settings, with no editor in that stack. Another is the
declaration from a current clean idle editor after the diagnostic has
been popped. The baseline probe confirmed clean and dirty covered vetoes,
the uncovered clean exit, and a permitted declaration from a legacy
diagnostic above Dashboard with its result still pending. Keep these
boundaries when splitting the route. Declarative removal manufactures no
imperative result.
Authorization revocation uses its existing security exit even with
covered dirty state. Keep `_pending`, `_moderationClose`, unregister,
reservation, recovery and pending lookup ownership intact. An operation
owned by another retained visit must not be consumed or released by
closing the diagnostic.

### Historical restoration and auth boundary

The pinned codec recursively finds saved imperative locations without
replaying the local redirect. A serialized malformed push from the old
router can therefore restore to the original editor builder. Keep its
defensive diagnostic with no editor activation, a route-supplied
predecessor-only action and the original protected exit hook, including
its pending-owner checks. The dedicated route's synchronous completion,
immediate-refresh and overlapping Back guarantees apply to its own
route. Historical entries retain deferred-exit and native reporting
limitations. Apply the same explicit source qualification before
dispatch, without a migration, result repair or new overlap protocol for
historical state.

The synthetic legacy push over public Settings survived sign-out refresh
and reconstructed its result because restoration re-evaluated the public
base. The probe found no activation or private record fetch, and direct
unauthorized malformed entry redirected to Login. Typed application
producers provide IDs from actual submissions, editor authority or save
recovery. No released producer was found that pushes a malformed ID from
an external URI. Direct external entry is declarative. Keep authenticated
Admin direct entry and revocation on protected bases in the test matrix.
The diagnostic is built from the requested URI and error, and renders
generic error UI without editor state. General imperative-auth restoration
repair is outside scope.

## Native presentation and acceptance

Use the pinned `material_ui.BackButton`. Its action icon honors
`ActionIconTheme`, the effective themed platform and directionality.
Its localized tooltip and accessibility behavior come from the fork's
Material implementation. Pass the complete caller override even without
GoRouter. Preserve optional background and padding, centered visual face,
desktop density and existing leading visibility. On mobile, aim for an
effective 48 × 48 logical hit and semantic target with a centered native
face (typically 40 × 40) where constraints permit. Adjust only the local
default spacing or style. A temporary native-button probe in a 56 × 56 slot verified a
centered 40 × 40 face, 48 × 48 semantic bounds, tappable edges and an
independent adjacent control using a loose, centered layout inside the
slot. Tight child constraints can enlarge the face even with a requested
40 × 40 size. Check the actual geometry in each affected host and preserve
the previous reachable area under tighter constraints.
AppBar and SearchBar continue to own their layout.

Use the permanent Gallery lifecycle regressions as compatibility gates
for the future implementation. Keep NAV-01 for upstream inactive-branch
system/predictive Back. Widget gesture simulation and physical Android
predictive/iOS edge-swipe verification are separate. Preserve the
[existing iOS release gates](../../../docs/performance/image-rendering-implementation.md#ios-release-gates)
for genuine VoiceOver Nearby Retry activation and physical Profile
memory, scrolling and raster acceptance, including the existing
release-owner residual-risk decision.

Use the existing Router host and Navigator topology. The shared decision
needs no coordinator, global registry, RouterConfig or RouterDelegate
wrapper, new observers, generic lock or acknowledgment protocol, manual
result completion, forced frames, polling or dependency changes.
