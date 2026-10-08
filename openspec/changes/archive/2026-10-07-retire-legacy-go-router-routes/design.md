## Context

This change is based on `main` at
`c7e062176c431a22ff2b823d65f9db94dca32600`, inspected on 2026-10-06.

The application uses one `StatefulShellRoute.indexedStack` with Explore,
Favourites, Events and Map branches. Category/Post/Search detail ownership is
already branch-local and is not changed here.

The current router still implements these compatibility families:

1. `_redirectLegacyCategoryIndex` together with
   `RouteParameters.categorySlugFromLegacyIndex`.
2. `_redirectLegacyPostType`, including `isEvent` conversion and implicit
   missing-type -> `place`.
3. `redirectLegacySearchResults` together with
   `RoutePaths.homeSearchResultsLegacy` and
   `RoutePaths.homeSearchResultsLegacyPost`.
4. `_redirectLegacyMapKey`.

The compatibility comments identify these paths as historical support rather
than current canonical behavior.

## Goals / Non-Goals

### Goals

- Leave one current canonical URI contract for Category, Post, Search and Map.
- Delete compatibility-only code instead of preserving a shadow parser in test
  support.
- Keep canonical route ancestry, route ownership and current content identity
  unchanged.
- Keep current supported restoration and Sync return behavior independent of
  historical migrations.
- Make unsupported historical URLs fail/tolerate naturally through existing
  canonical parsing rather than through new replacement redirects.

### Non-Goals

- No change to `StatefulShellRoute` topology or branch ownership.
- No shell chrome change; that belongs to the coordinated
  `harden-main-navigation-shell` change.
- No route metadata abstraction.
- No package update.
- No new legacy compatibility layer under different names.
- No attempt to preserve pre-2.3.0 restoration after the intentional cutoff.
- No special rejection of arbitrary unknown query parameters unless existing
  canonical validation already rejects the route.

## Decisions

### 1. Category uses current slugs only

Remove `_redirectLegacyCategoryIndex` from `categoryRoute`.

Remove `RouteParameters.categorySlugFromLegacyIndex` and any list/constant
whose only consumer is that helper.

Supported Category path values remain:

```text
nature
history
folklore
food
allure
experience
all
```

A numeric path such as `/home/category/0` still structurally matches the
`:categorySlug` route, but canonical parsing does not recognize it and the
existing error presentation handles it. Do not add another numeric-specific
guard if `categoryFromSlug` already provides the required rejection.

### 2. Post requires explicit canonical type

Remove `_redirectLegacyPostType` from every `postRoute`.

Canonical Post input requires:

```text
/posts/:id?type=event
/posts/:id?type=place
```

Examples intentionally no longer migrated:

```text
/home/posts/1
/home/posts/1?isEvent=true
/home/posts/1?isEvent=false
```

Missing/malformed type and invalid IDs use the existing Post error path.

If a URL contains a valid canonical `type` plus an unknown stale `isEvent`
parameter, do not introduce a new redirect or rejection solely to clean it.
Once the migration is removed, `isEvent` has no app-owned routing semantics.

### 3. Search uses query parameter `q`

Remove:

- `RoutePaths.homeSearchResultsLegacy`
- `RoutePaths.homeSearchResultsLegacyPost`
- both legacy redirect-only `GoRoute`s from Explore
- `redirectLegacySearchResults`
- `_searchResultsSegment` if it becomes unused

Current Search remains:

```text
/home/search_results?q=<query>
/home/search_results/posts/:id?q=<query>&type=<event|place>
```

Arbitrary encodable query text must continue to round-trip through `q`.

Old path-embedded locations become ordinary unmatched/error routes; no fallback
route should be added.

### 4. Map has no random-key routing semantics

Remove `_redirectLegacyMapKey` and the Map route's legacy `redirect:` hook.

Current Map remains:

```text
/map
/map?contentId=<positive-id>&type=<event|place>
```

The old `key` query parameter gets no new meaning. If the current parser
naturally ignores unknown query keys, `/map?key=...` may remain at that URI but
must behave like an unselected Map. Do not add a cleanup redirect merely to
strip it.

### 5. Test support must follow production retirement

`RouteOwnershipFixture` intentionally mirrors the production route ownership.
It must not retain old Search routes, redirect helpers or other compatibility
branches after production removes them.

`TargetTopologyFixture` is a synthetic topology fixture rather than a literal
production route parser. Do not modify it solely for compatibility-code
symmetry unless an affected contract requires the change.

### 6. Replace legacy-success tests with current-contract tests

Retiring compatibility means old URLs are not required to redirect
successfully. Delete or rewrite tests whose only assertion is historical
migration.

Keep/strengthen tests for:

- canonical Category slugs;
- invalid Category slug/error behavior;
- canonical Post `type=event|place`;
- missing/invalid Post type error behavior;
- canonical Search `q` round-trip, including arbitrary encodable text;
- Search Post preserving `q`, id and `type`;
- former path-embedded Search no longer matching/redirecting;
- canonical Map default/selection behavior;
- former Map `key` having no selection semantics;
- unknown route/error behavior.

A test filename containing `redirect` may be renamed to reflect canonical
routing, but a rename is not required for correctness.

### 7. Current deep links, restoration and Sync remain canonical

This change removes historical entry formats, not current navigation.

Verify direct app entry into current Category/Post/Search Post/Map URIs still
reconstructs the intended branch/destination.

Verify existing supported restoration data does not depend on retired helpers.

Verify Sync's `from` validation/return flow still returns to valid current
detail URIs and does not require legacy canonicalization.

## Risks and Mitigations

### Risk: tests accidentally preserve hidden compatibility

Mitigation: final source search covers every retired symbol and legacy route
constant, including test/support code.

### Risk: retirement becomes stricter than intended

Mitigation: remove app-owned semantics only. Do not add new validation for
unknown query keys that existing canonical parsing already ignores.

### Risk: unsupported old links are mistaken for regressions

Mitigation: make the compatibility cutoff explicit in proposal/spec/tests.
Only current canonical links are acceptance criteria.

## Expected Production Diff

Expected production files:

- `lib/routing/router.dart`
- `lib/routing/core_routes.dart`
- `lib/routing/route_paths.dart`
- `lib/routing/route_parameters.dart`

Expected test/support updates:

- `test/routing/route_parameter_redirect_test.dart`
- `test/routing/route_parameters_test.dart`
- `test/support/route_ownership_fixture.dart`
- focused deep-link/restoration/Sync coverage if assertions need tightening

No UI screen, ViewModel, repository, Supabase, ObjectBox, dependency or
generated-file edit should be necessary.
