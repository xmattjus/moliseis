## 1. Re-verify the Compatibility Boundary

- [x] 1.1 From implementation HEAD, record `git status --short`, current
      Flutter/Dart and resolved `go_router` versions, then re-read
      `router.dart`, `core_routes.dart`, `route_paths.dart`,
      `route_parameters.dart`, `route_parameter_redirect_test.dart`,
      `route_parameters_test.dart`, `route_ownership_fixture.dart`,
      restoration tests and Sync redirect tests. Stop and update OpenSpec
      before source edits if the compatibility surface differs materially from
      this design.
- [x] 1.2 Search production and tests for
      `_redirectLegacyCategoryIndex`, `categorySlugFromLegacyIndex`,
      `_redirectLegacyPostType`, `isEvent`,
      `redirectLegacySearchResults`, `homeSearchResultsLegacy`,
      `homeSearchResultsLegacyPost`, `_searchResultsSegment`,
      `_redirectLegacyMapKey` and the legacy Map `key` assumptions; classify
      every hit as compatibility-only or current canonical behavior.
- [x] 1.3 Run
      `openspec validate "retire-legacy-go-router-routes" --strict --no-interactive`
      and require a valid result before implementation.
- [x] 1.4 Run the focused routing baseline covering route parameters,
      ownership, restoration and Sync. Record existing skips/failures
      separately; do not fix unrelated navigation behavior in this change.

## 2. Retire Category and Post Compatibility

- [x] 2.1 Remove `_redirectLegacyCategoryIndex` from `categoryRoute`, delete
      `RouteParameters.categorySlugFromLegacyIndex`, and remove legacy-index
      constants/lists that become unused. Preserve current slug parsing and
      `all`.
- [x] 2.2 Replace numeric-Category redirect tests with regression coverage
      proving canonical slugs work and numeric/invalid slugs reach the normal
      route error path without a compatibility rewrite.
- [x] 2.3 Remove `_redirectLegacyPostType` from every `postRoute`. Require
      explicit canonical `type=event|place` through the existing parser/error
      path; remove the implicit missing-type -> `place` behavior and
      `isEvent` conversion.
- [x] 2.4 Replace Post legacy-success tests with explicit event/place success,
      missing/invalid type error, invalid-id error, and one proof that an
      otherwise canonical URL is not given special migration semantics merely
      because an unknown stale `isEvent` query key is present.

## 3. Retire Search and Map Compatibility

- [x] 3.1 Remove `homeSearchResultsLegacy`,
      `homeSearchResultsLegacyPost`, their Explore `GoRoute`s,
      `redirectLegacySearchResults`, and `_searchResultsSegment` if unused.
      Keep only `search_results?q=...` plus its canonical nested Post route.
- [x] 3.2 Update production-mirroring fixtures so they no longer register
      shadow legacy Search routes. Preserve current branch ownership and
      canonical Search/Post ancestry.
- [x] 3.3 Replace path-embedded Search redirect regressions with tests proving
      arbitrary encodable `q` values round-trip canonically, Search Post
      preserves `q`/id/`type`, and old path-embedded Search locations are no
      longer redirected/matched as compatibility routes.
- [x] 3.4 Remove `_redirectLegacyMapKey` and the Map legacy redirect hook.
      Preserve `/map` and canonical `contentId` + `type` selection.
- [x] 3.5 Replace the old-key redirect test with coverage proving the former
      `key` has no app-owned selection/canonicalization semantics. Do not add a
      replacement cleanup redirect.

## 4. Prove Current Canonical Entry and Restoration

- [x] 4.1 Exercise direct current-format entry for representative Category,
      direct Post, Category Post, Search Results/Search Post and selected Map;
      assert the expected branch and destination are reconstructed without any
      retired parser.
- [x] 4.2 Run the existing restoration suite and verify current shell/branch
      and Gallery restoration remains valid without compatibility helpers.
      Do not broaden this task into new shell hardening; query-state
      strengthening belongs to `harden-main-navigation-shell`.
- [x] 4.3 Run Sync redirect tests, including return to a current canonical
      detail URI, and verify `from` validation no longer relies on any retired
      route representation.

## 5. Objective Verification

- [x] 5.1 Run the focused route parameter/ownership/restoration/Sync suites and
      require zero new failures. Preserve unrelated existing skips.
- [x] 5.2 Run `dart format` on every touched authored Dart file and targeted
      `flutter analyze --no-pub` on touched production/test/support files;
      require zero new targeted diagnostics.
- [x] 5.3 Run repository-wide `flutter test --no-pub` and
      `flutter analyze --no-pub`; require all tests to pass except explicitly
      pre-existing skips and no new/worsened diagnostics attributable to this
      change.
- [x] 5.4 Search the full repository for every retired compatibility symbol and
      route constant. Require zero production/test-support references whose
      sole purpose is legacy migration; inspect any remaining literal
      `isEvent`/`key` occurrence and document why it is unrelated.
- [x] 5.5 Run `git diff --check`, `git status --short`, review the complete
      implementation diff, and confirm there is no shell chrome/topology,
      ViewModel/repository, backend, persistence, dependency, generated-code
      or unrelated refactor.
- [x] 5.6 Re-read proposal/design/spec/tasks against the implementation and run
      `openspec validate "retire-legacy-go-router-routes" --strict --no-interactive`;
      require a valid result before handoff.
