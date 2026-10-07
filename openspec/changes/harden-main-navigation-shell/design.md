## Context

This change is based on `main` at
`c7e062176c431a22ff2b823d65f9db94dca32600`, inspected on 2026-10-06.
The resolved runtime is Flutter 3.47.5 with `go_router` 18.0.2.

The application uses:

```text
StatefulShellRoute.indexedStack
|
+-- Explore
|   +-- Search Results
|   |   `-- Post
|   +-- Post
|   `-- Category
|       `-- Post
+-- Favourites
|   +-- Post
|   `-- Category
|       `-- Post
+-- Events
|   +-- Post
|   `-- Category
|       `-- Post
`-- Map
```

Gallery is a separate root-owned route and is normally pushed above the shell.

`ScaffoldShell` currently receives `showNavigation`. Production computes that
flag from an exact set of shell-root paths, so Post, Category and Search
Results hide both `ResponsiveNavigationBar` and `AppNavigationRail`.

Earlier hardening introduced `ShellRouteVisibility` and
`BranchDetailPopScope` to prevent retained inactive/covered branch details from
participating in app-owned Back/predictive-back behavior. Those are routing
correctness mechanisms and remain authoritative.

The coordinated `retire-legacy-go-router-routes` change removes historical URL
migration separately. This change assumes tests use canonical routes but does
not otherwise depend on the order in which the two source diffs are authored.

## Current test evidence

Existing tests already provide strong coverage for:

- root-owned Gallery push/pop, drag dismiss and restoration;
- predictive Gallery start/update/commit/cancel;
- hidden branch retention while Map is active;
- branch state retention across tab switches;
- active-tab reset at Map/root level;
- normal Back parentage for direct Post and Category Post;
- Post -> Map -> originating branch restoration;
- Content Submission system/predictive Back ownership.

The focused audit found these gaps:

1. no app-level `ensureSemantics()` regression proving shell chrome remains in
   the Semantics tree alongside active routed content, even though this is a
   specific `go_router` 18.0.2 fix;
2. real Category/Post and Search/Post branch stacks are not equivalently
   covered by predictive Back start/update/commit/cancel;
3. active-tab reselect is not proven from real detail/Search destinations
   through the navigation chrome that this change makes visible;
4. restoration visits selected Map state but only asserts `/map`, not retained
   `contentId/type`, and it does not pin one multi-level Search/Post query
   stack.

The existing `NAV-01` test for an inactive Post branch remains an upstream gate
for flutter/flutter#188018 / flutter/packages#11910. `go_router` 18.0.2 does
not advertise that fix; the test must be re-run rather than assumed.

## Goals / Non-Goals

### Goals

- Make main navigation a structural property of every shell-owned destination.
- Remove route-specific chrome visibility state instead of replacing it with a
  more elaborate policy.
- Preserve Gallery full-screen root ownership.
- Preserve branch state, declarative parentage and existing Back semantics.
- Verify final content remains reachable under persistent compact bottom
  navigation.
- Pin the Molise Is composition to the relevant `go_router` 18.0.2 shell
  Semantics behavior.
- Add exact-one-level predictive Back proofs on real branch details.
- Strengthen branch restoration/query-state proofs.
- Preserve the existing upstream NAV-01 boundary without local workaround.

### Non-Goals

- No Navigator topology redesign.
- No replacement of `StatefulShellRoute.indexedStack`.
- No route metadata/navigation state framework.
- No new app-specific predictive Back manager.
- No `go_router` fork/workaround/package update.
- No ViewModel ownership/lifecycle changes.
- No Gallery redesign.
- No `expressive_navigation_bar` migration.
- No global `extendBody` removal or broad screen layout redesign.
- No duplicate tests of `go_router` internals that Molise Is does not exercise.

## Decisions

### 1. Navigation chrome is structural to the shell

Remove `showNavigation` from:

- `ScaffoldShell`;
- the production shell page builder;
- production-mirroring fixtures/tests whose only purpose is to feed/assert it.

`ScaffoldShell` always renders:

- compact/medium: `ResponsiveNavigationBar`;
- expanded: `AppNavigationRail`.

The invariant is:

```text
destination owned by StatefulShellRoute
    -> main navigation present

opaque root-owned route above/outside shell
    -> shell navigation naturally covered/not constructed for that route
```

Do not replace `showNavigation` with a route-name/path whitelist, metadata flag,
inherited presentation state or equivalent abstraction.

`ShellRouteVisibility` remains separate: it controls whether a retained branch
detail is eligible to participate in Back, not whether shell chrome is painted.

### 2. Selected navigation destination still comes only from the shell

Keep `_onDestinationSelected` and:

```dart
navigationShell.goBranch(
  index,
  initialLocation: index == navigationShell.currentIndex,
);
```

Keep selected destination derived from
`StatefulNavigationShell.currentIndex`.

This intentionally means:

- cross-tab from Post/Category/Search preserves the origin branch stack;
- returning to that branch restores its retained destination/state;
- tapping the already active branch from a detail/Search destination resets it
  to its initial location;
- main navigation does not become an alternate Back stack.

### 3. Gallery remains root-owned, opaque and full-screen

Do not move Gallery into a shell branch.

When pushed:

```text
Root Navigator
|
+-- shell page
|   `-- active shell destination with persistent chrome
`-- Gallery (opaque root page)
```

Gallery covers the shell. Predictive reveal therefore exposes a shell whose
geometry/chrome is already in the correct steady state.

Direct `/gallery` with invalid/missing serializable payload keeps the existing
unavailable fallback and does not construct a shell solely to provide chrome.

### 4. Preserve routing Back ownership

Do not change `ShellRouteVisibility` or `BranchDetailPopScope` merely because
chrome is now visible.

Required parentage remains:

```text
direct Post        -> section root
Category           -> section root
Category -> Post   -> Category
Search -> Post     -> Search Results
Gallery            -> exact shell destination beneath it
```

A branch switch to Map is not a Back operation. Hidden branch pages must remain
retained but ineligible to consume active-branch/system Back.

### 5. Prove real detail predictive Back, not only synthetic/Gallery paths

Use the existing Android predictive-back platform-channel helpers and
`TargetPlatform.android`.

Add predictive commit coverage using production route factories/ownership for
at least:

```text
/home/posts/1?type=event
  -> /home

/home/category/nature/posts/1?type=event
  -> /home/category/nature

/home/search_results/posts/1?q=molise&type=event
  -> /home/search_results?q=molise
```

A Category-only predictive commit may be table-driven with the same matrix if
it materially improves proof without duplication.

Each commit must pop exactly one visible route and preserve the expected parent
branch stack.

Add one high-value cancel case, preferably Category -> Post:

1. capture URI, branch page count, `PostScreen State` and `PostViewModel`;
2. start predictive Back;
3. update to a non-zero progress such as 0.5;
4. cancel;
5. assert URI/page count/State/ViewModel identity are unchanged and no
   exception was produced.

Do not duplicate Gallery's exhaustive predictive-update suite for every detail.

### 6. Exercise persistent navigation interactions from details

Once the bar/rail is visible on detail/Search routes, test the newly exposed
interaction directly through the production shell widget:

- from `/home/category/nature/posts/1?type=event`, tapping active `Esplora`
  resets Explore to `/home` and removes the detail stack according to existing
  `goBranch(initialLocation: true)` behavior;
- from `/home/search_results?q=molise`, tapping active `Esplora` resets to
  `/home`;
- from a representative Post, switching to another branch and then back to the
  origin restores the same route and state/ViewModel identity.

These tests must not substitute `router.go()` for the user interaction being
specified.

### 7. Guard compact layouts under `extendBody: true`

`ScaffoldShell` currently uses `extendBody: true`.

Before this change, Post, Category and Search Results do not display shell
bottom navigation. Their current tail layouts differ:

- Post has bottom safe-area padding;
- Category ends with a small fixed spacer;
- Search Results has no dedicated navigation-bottom padding.

Add focused compact tests proving the final meaningful/interactive content of
each screen can be brought above the app-owned bottom navigation and activated
where applicable.

Only if a screen fails the proof, apply the smallest screen-local inset/padding
correction following existing conventions.

Do not:

- globally disable `extendBody`;
- add a navigation-metrics architecture;
- duplicate shell geometry constants throughout screens;
- alter expanded rail geometry to solve a compact-only issue.

### 8. Pin `go_router` 18.0.2 shell Semantics behavior

`go_router` 18.0.2 includes a fix for shell chrome painted before routed
content being dropped from the Semantics tree by an active route's
`ModalBarrier`.

Molise Is must have an app-level regression because its concrete composition is
what users/accessibility services experience.

Use `tester.ensureSemantics()` and verify that main navigation Semantics and
active routed content coexist after initial build and after shell child-route
changes.

Cover:

- compact `ResponsiveNavigationBar`;
- expanded `AppNavigationRail`;
- at least one root-to-detail transition and Search Results;
- stable selected section.

Do not duplicate the entire upstream `go_router` builder test. The app test
only needs to prove the Molise Is shell composition exposes both chrome and
routed content.

### 9. Strengthen restoration/query-state coverage

Keep two distinct proofs. Do not treat the synthetic topology fixture as proof
that production Map selection or Search/Post reconstruction occurred.

#### 9.1 Synthetic shell URI-retention proof

The existing `restoration_behavior_test.dart` /
`TargetTopologyFixture` flow visits:

```text
/map?contentId=5&type=event
```

but later only asserts that restored Map has path `/map`.

Strengthen that existing synthetic test to prove only what the fixture actually
models: the shell route-match/URI state survives restoration. After
`restartAndRestore()` and return to Map, assert:

```text
contentId = 5
type = event
```

Do **not** claim from this test that a real Map content selection was rebuilt:
`TargetTopologyFixture` does not parse those values into a production
`GeoMapScreen` selection.

#### 9.2 Production/factory-equivalent restoration proof

Add the minimum restorable test harness that exercises the production router
(or the same production route factories and restoration scopes/page IDs) with
the required fake repositories/providers.

For selected Map restoration, start from:

```text
/map?contentId=5&type=event
```

then restart/restore and prove both:

- canonical URI identity remains `contentId=5&type=event`;
- the real Map route reconstructs the selection contract, including
  `GeoMapScreen.initialContentId`, `GeoMapScreen.initialContentType`, and the
  expected selected content once repository resolution completes.

For Search/Post, restore:

```text
/home/search_results/posts/1?q=molise&type=event
```

and assert:

- current path remains the Search Post path;
- `q=molise`;
- `type=event`;
- Explore/Search parent ancestry is reconstructed by the relevant real route
  definitions;
- normal Back and the reliable Android predictive-Back path return exactly to
  Search Results with `q=molise`, rather than flattening/skipping a level.

Reuse/adapt the existing production-router restoration pattern already present
in the Sync restoration tests where practical. A minimal extraction into
test-only support is allowed if it removes real duplication.

Do not:

- add fake Map selection or Search parsers to `TargetTopologyFixture`;
- make `RouteOwnershipFixture` pretend to be restorable when its current
  contract does not provide restoration scopes/page IDs;
- create a parallel production navigation architecture solely for testing.

### 10. Keep NAV-01 as an upstream gate

Re-run:

```text
NAV-01 [upstream #188018]
inactive Post branch must not consume Map root Back
```

with the resolved `go_router` 18.0.2.

If it now passes for the intended reason, remove the skip while preserving the
same expected behavior.

If it still fails with the known upstream defect:

- keep it skipped;
- update stale version wording/comments;
- retain flutter/flutter#188018 and flutter/packages#11910 references;
- preserve the exact expected inactive-branch behavior;
- do not add a local Navigator mutation, fork or workaround in this change.

Do not multiply skipped tests for the same upstream defect.

### 11. iOS edge-swipe remains an explicit smoke gate

The widget suite strongly covers Android predictive Back. For iOS, verify on a
real/simulator build:

```text
Home -> Post -> edge swipe
Home -> Category -> Post -> edge swipe
Home -> Search Results -> Post -> edge swipe
```

Each gesture must remove exactly one level and leave the shell chrome/selected
branch coherent.

Only automate this later if the current Flutter harness provides a stable,
non-fragile way to drive the native Cupertino interactive gesture. Do not add a
timing-sensitive synthetic test merely to claim coverage.

## Test Matrix

| Boundary | Required proof |
| --- | --- |
| shell root | bar/rail visible, correct branch selected |
| Category | bar/rail visible, parent Back exact |
| direct Post | bar/rail visible, predictive commit -> root |
| Category Post | predictive commit -> Category; cancel preserves identity |
| Search Results | bar/rail visible, Explore selected |
| Search Post | predictive commit -> Search preserving `q` |
| active-tab reselect | detail/Search -> branch root |
| cross-tab return | origin detail route + state/VM retained |
| Gallery | opaque root route covers shell; pop reveals stable chrome |
| compact tail | Post/Category/Search final content reachable above nav |
| expanded | rail visible without compact workaround |
| Semantics | navigation chrome + routed content exposed together |
| restoration Map | `contentId/type` retained |
| restoration Search Post | path + `q/type` + parentage retained |
| inactive branch NAV-01 | re-run upstream gate, no local workaround |
| iOS edge swipe | manual exact-one-level smoke |

## Expected Production Diff

Required production files:

- `lib/ui/core/ui/scaffold_shell.dart`
- `lib/routing/router.dart`

Potential production layout files only if focused overlap tests prove a
regression:

- `lib/ui/post/widgets/post_screen.dart`
- `lib/ui/category/widgets/category_screen.dart`
- `lib/ui/search/widgets/search_result_screen.dart`

Expected tests/support:

- `test/routing/geo_map_route_test.dart`
- `test/routing/back_navigation_integration_test.dart`
- `test/routing/route_ownership_test.dart`
- `test/routing/restoration_behavior_test.dart`
- `test/routing/sync_redirect_test.dart` only if existing local restoration
  support is reused/extracted
- `test/support/route_ownership_fixture.dart`
- existing `test/support/predictive_back.dart` reused unchanged unless a
  minimal deterministic helper is genuinely required
- minimal test-only production-router restoration support if the existing Sync
  harness cannot be reused in place without duplication

`TargetTopologyFixture` should be changed only where its synthetic topology
contract needs the new always-on production `ScaffoldShell` constructor and
for URI-retention assertions it already models. Do not extend it with fake Map
selection/Search parsing merely to satisfy production-restoration acceptance.

`RouteOwnershipFixture` remains appropriate for production Category/Post route
ownership and predictive-Back proofs, but it must not be treated as a
restoration harness unless its contract is deliberately changed with the real
required restoration scopes/page identity; prefer the existing production
router restoration pattern instead.
