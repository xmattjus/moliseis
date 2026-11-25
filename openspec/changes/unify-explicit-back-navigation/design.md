# Design

## Context

The original planning baseline was `70f7cef7ec4e92363e43e67d96c71ae0ecb6da8d`.
This simplification uses reviewed head `e22aa534831b709a029a1eb163df2836b9263e93`
and main/merge base `69ee22bf23bcd7292871652272755369bfa4d071`. The resolved
versions are Flutter 3.47.5 (`6a19cca564`), Dart 3.13.4, GoRouter 18.0.2,
material_ui 1.5.0 and OpenSpec 2.1.0. The qualification below relies on
behavior verified against those versions.

The real app's standalone Login Back calls direct Navigator pop. A tap on
the visible control reproduced the last-page assertion and left the
committed configuration empty, both on direct entry and after a
Dashboard sign-out event through the production redirect. The second
probe used controlled auth events and did not exercise server expiry. Keep the current redirect and the
pushed Login-to-Dashboard replacement flow.

## Native presentation

Use `material_ui.BackButton` in the shared control. Keep the themed
platform glyph, directionality, `ActionIconTheme` customization, localized
tooltip and semantics ("Indietro" in Italian, "Back" in English),
caller-provided background and padding, desktop density and existing
leading visibility. A supplied callback fully handles activation and
can run without GoRouter.

Keep a centered face and verify the real hit and semantic geometry locally.
Earlier widget probing achieved 48 × 48 logical pixels with a centered
40 × 40 face in a 56 × 56 host through a loose, centered child layout.
Tight child constraints can expand the face. Check edge taps and adjacent
controls in affected hosts. Preserve reachability where host constraints
are tighter. AppBar and SearchBar keep ownership of their layouts.

## Ordinary departure

Use the physical Route and owning Navigator of the originating control.
The control must still belong to the current eligible route in the committed
stack when it acts. Reuse the existing route and keyed widget boundaries.
The root shell must be current for a branch control to act. A popup can
cover the shell while the branch remains locally current. Read the
committed active branch key because inherited visibility can lag a branch
change until the next frame. A committed covering or replacement page
can also outrun the Navigator. Qualify the displayed source against the
committed destination for that owner before dispatch.

In the pinned delegate, GoRouter pop walks the committed shell chain while
the enclosing modal routes are current and selects the deepest structurally
poppable Navigator. `GoRouter.canPop()` answers whether there is poppable
history, without proving ownership. Use the selected owner and actual
predecessor together with route disposition. Internal local-history handling
does not count as removal of the originating page. Leave an active native
Back gesture to its existing owner. A veto or a failed ownership check
leaves the stack alone. The first verified page may naturally bubble and
request named Explore where allowed. Canonical Explore root itself is a
no-op. A navigation decision dispatches at most once, subject to the
existing router admission and redirects.

Use `GoRouter.pop()` for ordinary page removal. It synchronizes route
information when the configuration changes synchronously. A prior Search
Post probe showed that direct Navigator pop can leave the provider on the
old page, which a refresh can reopen. Deferred feature exits and system or
gesture Back use their existing paths and keep their current limitations.

### Reconciling an ordinary push

Flutter cancels active pointers on navigation history changes and suppresses
input and focus on transitioning modal routes. A router commit before
Navigator reconciliation can occur while the old page is still current
and its input is still valid. In baseline probes a real press/release on
pushed Settings or Gallery spanning an auth refresh completed the old
result. Focused Enter activation reproduced the same Gallery outcome. The live entry survived, and the screen reappeared on a recreated
Route. Settings already calls `GoRouter.pop()`, so adopting that API alone
does not cover this interleaving. Gallery's presentation tracking preserved
slideshow admission, while the requested departure failed.

For ordinary matched pushes, reuse GoRouter's existing association from
the installed Route's Page to `GoRouterState.of(context)`. First qualify
the intended live entry and its key/destination. The pinned fixed router
also exposes an inexpensive discriminator without a new association.
`ImperativeRouteMatch.buildState` passes its inner path-parameter map
through directly, and decoding a replacement result matches the location
into a fresh map, even for a parameterless path. Compare that installed
map reference with the live entry's map. This comparison distinguished an
old Page from its replacement in the Settings and Gallery probes. It is
a reconciliation check for ordinary matched imperative pops, with no
semantic interpretation of the map. Unchanged pushes need to remain
eligible. Check this assumption on dependency updates or if dynamic router
reconfiguration enters the supported path.

If that entry is still reconciling, leave the stack and results alone until
another activation on the reconciled source. The implementation regression
should cover rejection before reconciliation and success afterward on the
retained Route. In a separate Settings probe the references converged on
the same Route after build, an equivalent restore kept it usable, and a
later Back with immediate refresh closed it and completed only the live
result. No Page construction changes, local binding state,
result repair, pending protocol, global identity tracking or new Navigator
infrastructure are needed. Ordinary declarative pages use their existing
route and committed ownership information.

### Error controls

Both ordinary error controls use the same departure. A matched validation
error inherits its actual route and Navigator. For an unmatched error,
the router's existing builder supplies the error object of the Page it
renders. Qualify that displayed source against the actual current root
Route and the committed standalone error or top imperative error's inner
error. A standalone unmatched configuration can be empty of normal
matches. A pushed unmatched error must have its actual predecessor.
The previous real-router probe verified these shapes and the replaced
error object on refresh. Keep diagnostic logging and deduplication
independent of navigation ownership.

## Feature boundaries

- **Admin.** Keep the current route topology, ID validation, diagnostic,
  authorization, admission, recovery and editor exit policy. Give the
  existing malformed diagnostic a feature-owned predecessor-only action
  shared by its two controls. Use the existing protected pop path and
  preserve deferred `onExit`. It can evaluate removal of the diagnostic
  within its own route, without authorizing removal of a retained editor.
  A realistic producer of malformed imperative entries justifying a
  wider change was not established. Typed inputs alone do not prove
  positivity. Legacy restoration and deferred-exit concurrency remain
  existing router limitations.
- **Dashboard.** Delegate only the terminal decision after account, visit,
  generation and recovery checks. A failed preflight consumes no authority.
  Keep the one-action latch and its resets after admitted dispatch. Earlier
  real-router probing showed a held editor lookup preventing the Dashboard
  from becoming eligible. It did not establish refusal of a fallback from
  a live standalone Dashboard.
- **Gallery.** Keep the canonical `GalleryPresentation` owner for openings,
  rejection, coverage, replacement observation, reservation release and
  autoplay. An ordinary explicit departure qualifies the live Route and
  push. It has no slideshow lifecycle effects of its own. The permanent
  lifecycle tests cover early and stranded results independently of Back
  input. Supported calls open a new Gallery or restore its serialized data.
  No in-place media reconciliation is needed for unsupported replacement.
  [Gallery lifecycle evidence](../../../docs/performance/image-rendering-implementation.md#gallery-presentation-lifecycle-2026-11-25)
- **Other features.** Admin Editor, Save Progress, Content Submission, Search
  Anchor, GeoMap, pickers, Logout and Close/Dismiss retain their actions,
  results, visibility and ownership. Ordinary Category, Post and Search
  Results keep their existing keys and ancestry.

## Verification boundaries

Verify tap, keyboard and semantics activation through the shared control and
test router outcomes. A deterministic widget input interleaving can establish
a real ordering issue without measuring field frequency. Keep simulated
system Back and gesture tests separate from physical verification. NAV-01
remains open. Preserve the [iOS release gates](../../../docs/performance/image-rendering-implementation.md#ios-release-gates)
for genuine VoiceOver Nearby Retry activation and physical Profile memory,
scrolling and raster checks, including the existing release-owner decision
boundary. General router restoration and native route-reporting behavior
remain outside the change.
