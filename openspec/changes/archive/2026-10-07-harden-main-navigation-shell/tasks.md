## 1. Re-verify Main and the Navigation Baseline

- [x] 1.1 From implementation HEAD, record `git status --short`, Flutter/Dart
      and resolved `go_router`; re-read production `router.dart`,
      `core_routes.dart`, `scaffold_shell.dart`, Post/Category/Search layouts,
      `route_ownership_fixture.dart`, `target_topology_fixture.dart`,
      `predictive_back.dart` and all routing tests named in `design.md`. Stop
      and update OpenSpec before source edits if route ownership/topology or
      shell responsibilities have materially changed.
- [x] 1.2 Confirm the coordinated
      `retire-legacy-go-router-routes` state: if it is not implemented yet,
      keep this change's tests on canonical routes and avoid reintroducing
      legacy assumptions; if it is already implemented, sync fixtures to that
      canonical surface before adding new navigation regressions.
- [x] 1.3 Run
      `openspec validate "harden-main-navigation-shell" --strict --no-interactive`
      and require a valid result before implementation.
- [x] 1.4 Run the focused baseline:
      `geo_map_route_test.dart`, `back_navigation_integration_test.dart`,
      `gallery_route_test.dart`, `route_ownership_test.dart`,
      `restoration_behavior_test.dart`, Content Submission routing/restoration
      suites. Record NAV-01 separately because it is intentionally skipped
      pending upstream behavior.

## 2. Make Main Navigation Structural to the Shell

- [x] 2.1 Remove `showNavigation` from `ScaffoldShell`, its constructor,
      production shell builder and production-mirroring fixtures/tests.
      Render the responsive navigation component whenever the
      `StatefulShellRoute` is present; do not replace the boolean with route
      path/name/metadata policy.
- [x] 2.2 Preserve selected destination from
      `StatefulNavigationShell.currentIndex` and leave
      `_onDestinationSelected` / `goBranch(initialLocation: active)` semantics
      unchanged.
- [x] 2.3 Update fixture construction minimally for the new
      `ScaffoldShell` contract. Keep `ShellRouteVisibility` and
      `BranchDetailPopScope` unchanged unless a failing regression proves an
      independent bug; chrome visibility must not become Back eligibility.
- [x] 2.4 Add compact (390), medium (700), expanded (1000) and large (1300)
      production-router regressions proving main navigation is present and the
      correct section selected on shell roots,
      Category, direct Post, Category Post, Search Results, Search Post and Map
      with/without canonical selection. Verify the actual WindowSizeClass,
      medium horizontal/fixed-width bar and expanded collapsed vs large
      extended rail.

## 3. Preserve Gallery and Branch Navigation Semantics

- [x] 3.1 Keep Gallery as the existing root-owned opaque route. Prove Gallery
      opened from representative shell destinations covers the full screen
      while the retained shell remains mounted beneath it with persistent
      chrome; do not move Gallery into a branch.
- [x] 3.2 Preserve existing Gallery predictive cancel/commit, AppBar Back,
      programmatic pop, drag dismiss and restoration suites. Add only the
      assertions needed to prove reveal returns to unchanged persistent shell
      geometry; do not duplicate Gallery coverage already present.
- [x] 3.3 Through the visible production navigation chrome, prove switching
      from a representative detail to another branch and back restores the
      same originating route plus State/ViewModel identity.
- [x] 3.4 Through the visible production navigation chrome, prove active
      `Esplora` reselect from
      `/home/category/nature/posts/1?type=event` resets to `/home`, and active
      `Esplora` reselect from `/home/search_results?q=molise` resets to
      `/home`. Assert the branch stack is reset rather than merely the URI
      being rewritten.

## 4. Harden Predictive Back on Real Branch Details

- [x] 4.1 Add Android predictive commit coverage on the production-equivalent
      route ownership fixture for direct Post -> section root,
      Category/Post -> Category, and Search/Post -> Search Results preserving
      `q`. For every case assert exactly one visible route is popped and the
      expected branch page count and parent path remain. For Search also
      assert canonical `q`; do not constrain `type` on a parent URI.
- [x] 4.2 Add one predictive cancel regression on Category/Post: capture URI,
      Explore Navigator page count, `PostScreen State` and `PostViewModel`;
      drive start -> update(non-zero) -> cancel; require every captured value
      to remain unchanged and no exception.
- [ ] 4.3 If useful and non-duplicative, table-drive Category-only predictive
      commit -> section root. Do not create exhaustive update/cancel matrices
      already proven by Gallery. Optional case omitted: the required real
      Post parent matrix already proves single-level removal.
- [x] 4.4 Keep existing hidden-branch predictive proofs green; do not weaken
      `BranchDetailPopScope` expectations merely because chrome is now
      persistent.

## 5. Add the go_router 18.0.2 Shell Semantics Regression

- [x] 5.1 Add an app-level widget regression using
      `tester.ensureSemantics()` that proves compact and medium
      `ResponsiveNavigationBar` Semantics and active routed content Semantics
      coexist on a shell root and after navigation to a nested shell
      destination. Use user-facing labels/roles where practical rather than
      implementation-private widget structure.
- [x] 5.2 Add the corresponding expanded-window proof for
      initially collapsed `AppNavigationRail` at 1000 px, including a
      child-route transition; keep 1300 px as a separate large/extended-rail
      regression. Require the correct selected section and active routed
      content to remain present in
      the Semantics tree.
- [x] 5.3 Include Search Results in at least one semantics transition because
      it changes from chrome-hidden to chrome-visible in this change.
- [x] 5.4 Do not copy the upstream `go_router` builder test wholesale; this
      test exists to pin the Molise Is shell composition against the 18.0.2
      ModalBarrier/Semantics regression.

## 6. Prove Compact Content Reachability

- [x] 6.1 Add focused compact and medium tests with enough content to scroll
      Post, Category and Search Results to their final meaningful/interactive item
      while the bottom navigation is visible. Require the final item to be
      brought fully above the measured navigation and activated where
      applicable, including medium grid content with the bottom bar.
- [x] 6.2 If Post already passes, make no Post production layout change. If it
      fails, use the smallest existing-convention bottom inset/padding fix and
      pin it with the focused test.
- [x] 6.3 Apply the same fail-first rule independently to Category and Search
      Results. Do not globally disable `extendBody`, create a shell-metrics
      subsystem or change expanded rail geometry to fix compact overlap.
- [x] 6.4 Verify true expanded (1000 px, collapsed rail) and large (1300 px,
      extended rail) Post/Category/Search Results preserve content reachability
      without a bottom-bar padding workaround causing geometry regressions.

## 7. Strengthen Restoration and Canonical Query State

- [x] 7.1 Strengthen the existing
      `restoration_behavior_test.dart`/`TargetTopologyFixture` case that visits
      `/map?contentId=5&type=event`: after `restartAndRestore()` and return to
      Map, assert `contentId=5` and `type=event` are retained in the URI.
      Classify this strictly as a synthetic shell **URI-retention** proof;
      `TargetTopologyFixture` has no production Map selection parser and must
      not be extended with one merely to satisfy this task.
- [x] 7.2 Add/adapt the minimum restorable production-router (or
      production-route-factory-equivalent) harness with the real required
      restoration scopes/page ID and fake dependencies. Restore
      `/map?contentId=5&type=event` and verify both canonical query retention
      and real selection reconstruction through
      `GeoMapScreen.initialContentId`, `GeoMapScreen.initialContentType`, plus
      the expected selected content after repository resolution.
- [x] 7.3 Using that production/factory-equivalent restoration harness, restore
      `/home/search_results/posts/1?q=molise&type=event` and assert exact path,
      `q`, `type`, Explore/Search declarative ancestry, and the relevant branch
      stack. Then verify normal Back and the reliable Android predictive-Back
      path each pop to the exact parent path `/home/search_results`, preserving
      canonical `q=molise` without flattening/skipping the restored parent.
      Do not require `type` either to remain or to be removed after Back; its
      presence is required on the restored Post before Back.
- [x] 7.4 Reuse the production-router restoration pattern/support already
      present in `sync_redirect_test.dart` where practical. A minimal
      extraction into shared **test-only** support is allowed if needed to
      avoid duplication. Do not make `RouteOwnershipFixture` or
      `TargetTopologyFixture` simulate production restoration by adding fake
      parsers/selection behavior, and do not create parallel production router
      infrastructure solely for these proofs.

## 8. Re-run the Upstream NAV-01 Gate

- [x] 8.1 Temporarily execute the existing skipped NAV-01 regression against
      resolved `go_router` 18.0.2 without changing its expected behavior.
- [ ] 8.2 If it passes for the intended inactive-branch reason, remove the skip
      and retain the regression permanently. Not applicable: the unskipped
      18.0.2 probe still returns `handlePopRoute() == true` at Map root.
- [x] 8.3 If it still reproduces flutter/flutter#188018 /
      flutter/packages#11910, keep it skipped, update stale package-version
      wording/status, preserve the exact expected invariant, and add no local
      workaround/fork/topology mutation.
- [x] 8.4 Do not add additional skipped tests for the same upstream defect.

## 9. iOS Interactive Back Smoke Gate

- [x] 9.1 On iOS simulator/device, verify `Home -> Post -> edge swipe` removes
      exactly Post and leaves Explore chrome coherent.
- [x] 9.2 Verify `Home -> Category -> Post -> edge swipe` removes exactly Post
      and reveals Category; a second edge swipe removes Category to Home.
- [x] 9.3 Verify `Home -> Search Results -> Post -> edge swipe` removes exactly
      Post and reveals Search Results with Explore still selected.
- [x] 9.4 Record PASS/FAIL in implementation verification. Do not add a fragile
      timing-dependent Cupertino gesture widget test unless the harness can
      drive the native interaction deterministically.

IOS MANUAL GATE PASSED: the user confirmed on 2026-10-07 that all manual
checks in tasks 9.1–9.4 pass. This records the user's native smoke verification;
the agent did not execute the edge-swipe checks itself.

## 10. Objective Verification and Scope Audit

- [x] 10.1 Run all focused routing/restoration/Gallery/Content Submission
      suites affected by shared support changes. Require no new failures and
      preserve unrelated existing skips.
- [x] 10.2 Run `dart format` on touched authored Dart files and targeted
      `flutter analyze --no-pub` on every touched production/test/support file;
      require zero new targeted diagnostics.
- [x] 10.3 Run repository-wide `flutter test --no-pub` and
      `flutter analyze --no-pub`; require all tests to pass except explicitly
      justified upstream/pre-existing skips and no new/worsened diagnostics
      attributable to this change.
- [x] 10.4 Search the repository for `showNavigation`; require zero remaining
      app/test plumbing except historical archived documentation if present.
      Confirm no replacement route-specific chrome policy/metadata flag was
      introduced.
- [x] 10.5 Run `git diff --check`, `git status --short`, inspect the complete
      implementation diff and confirm there is no Navigator topology,
      ViewModel/repository/backend/persistence/dependency/generated-code,
      `expressive_navigation_bar`, broad layout or unrelated refactor.
- [x] 10.6 Re-read proposal/design/spec/tasks against the finalized
      implementation and run
      `openspec validate "harden-main-navigation-shell" --strict --no-interactive`;
      require a valid result before handoff.
