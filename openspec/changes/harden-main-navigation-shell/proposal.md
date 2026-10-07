## Why

The earlier navigation hardening moved Post, Category and Search detail
destinations into their owning `StatefulShellRoute` branch Navigators so branch
state survives cross-section navigation. `ScaffoldShell.showNavigation` still
preserves the older UX by hiding main navigation on every non-root shell
destination, creating a presentation rule that no longer matches the actual
route ownership.

The desired product model is simpler: if a destination belongs to the
stateful shell, the app's main navigation chrome remains present. Gallery stays
a root-owned opaque full-screen route and therefore covers the shell naturally.

A focused audit of `main` on `go_router` 18.0.2 also found several worthwhile
regression gaps. Existing coverage is already strong for Gallery, hidden
branches and Content Submission, but it does not directly prove the 18.0.2
shell-chrome semantics fix in the Molise Is composition; predictive Back on
real multi-level Category/Search/Post branch stacks is thinner than normal
Back; active-tab reselect is not exercised from real detail destinations; and
restoration does not fully pin canonical query state such as Map
`contentId/type`.

## What Changes

- Remove `showNavigation` and make responsive main navigation structural to
  every `StatefulShellRoute` destination.
- Show the navigation bar/rail on Category, Post and Search Results as well as
  branch roots and Map.
- Keep Gallery root-owned, opaque and full-screen with unchanged payload,
  restoration and dismiss semantics.
- Preserve `ShellRouteVisibility`, `BranchDetailPopScope`, branch retention,
  cross-tab restoration and active-tab reset behavior.
- Add compact-layout reachability gates for Post, Category and Search Results
  under the existing `extendBody: true`; change screen padding only when a
  focused test proves actual overlap.
- Add an app-level Semantics regression for the `go_router` 18.0.2
  `ShellRoute`/`StatefulShellRoute` chrome fix in compact and expanded layouts.
- Add predictive-back commit coverage on real direct Post, Category/Post and
  Search/Post stacks plus one predictive cancel identity/state proof.
- Exercise active-tab reselect and cross-tab return through the real persistent
  navigation chrome from detail/Search destinations.
- Strengthen restoration to retain canonical Map query selection and one
  Search/Post stack with `q`/`type`.
- Re-run the existing NAV-01 inactive-branch upstream gate against 18.0.2,
  keeping it skipped/annotated if the upstream defect still reproduces and
  adding no local workaround.
- Keep an explicit manual iOS edge-swipe smoke gate for real shell details
  unless the current Flutter widget harness proves that gesture reliably.

## Capabilities

### New Capabilities

- `main-navigation-shell`: Defines persistent shell chrome, Navigator/Back
  ownership, responsive reachability, Semantics exposure, predictive-back and
  restoration invariants for shell-owned navigation.

### Modified Capabilities

- None.

## Impact

- Production routing/UI:
  - `lib/routing/router.dart`
  - `lib/ui/core/ui/scaffold_shell.dart`
- Potential screen-local layout changes only if focused overlap tests fail:
  - `lib/ui/post/widgets/post_screen.dart`
  - `lib/ui/category/widgets/category_screen.dart`
  - `lib/ui/search/widgets/search_result_screen.dart`
- Test/support:
  - `test/routing/geo_map_route_test.dart`
  - `test/routing/back_navigation_integration_test.dart`
  - `test/routing/route_ownership_test.dart`
  - `test/routing/restoration_behavior_test.dart`
  - `test/routing/sync_redirect_test.dart` only as a source of existing
    production-router restoration-harness patterns/support if reuse or a
    minimal test-only extraction is needed
  - `test/support/route_ownership_fixture.dart`
  - `test/support/target_topology_fixture.dart` only for synthetic topology
    and URI-retention proofs; do not add fake Map selection/Search parsers to
    make it satisfy production-restoration requirements
  - existing `test/support/predictive_back.dart`
  - minimal test-only support extracted/reused from an existing
    production-router restoration harness when needed to prove real Map
    selection and Search/Post ancestry after process restoration
- No ViewModel/repository/backend/persistence/dependency/generated-code change
  is intended.
