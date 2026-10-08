## Why

The router still carries four compatibility families introduced to restore
pre-2.3.0 locations: numeric Category indexes, Post `isEvent`/implicit
`place` migration, path-embedded Search queries, and the former random Map
`key`. Their own comments identify them as temporary compatibility code.

The public-release compatibility window has now passed by product decision.
Keeping these migrations no longer protects a supported route contract; it
instead expands router branching, production-mirroring fixtures, restoration
expectations and tests around URLs the current app no longer emits.

Retiring that compatibility surface now leaves one canonical representation
for Category, Post, Search and Map before the separate shell/navigation chrome
hardening is implemented.

## What Changes

- Remove numeric Category canonicalization and the legacy index-to-slug helper.
- Require canonical Post `type=event|place`; remove `isEvent` migration and the
  implicit missing-type -> `place` default.
- Remove both path-embedded Search compatibility routes and their redirect
  helper; current Search continues to use `q`.
- Remove Map's former random-`key` redirect/canonicalization; canonical selected
  content remains `contentId` + `type`.
- Remove comments, constants, helpers, fixtures and success-path tests that
  exist only for those retired formats.
- Replace legacy-success regressions with canonical-route and retirement/error
  regressions.
- Preserve current branch ancestry, canonical deep links, supported
  restoration and Sync return-to-detail behavior.
- Treat unknown stale query keys as semantically inert where the current parser
  naturally ignores them; do not add replacement cleanup redirects merely to
  erase obsolete keys.

## Capabilities

### New Capabilities

- `canonical-app-routing`: Defines the supported canonical Category, Post,
  Search and Map URI contracts after the pre-2.3.0 compatibility cutoff.

### Modified Capabilities

- None.

## Impact

- Production routing:
  - `lib/routing/router.dart`
  - `lib/routing/core_routes.dart`
  - `lib/routing/route_paths.dart`
  - `lib/routing/route_parameters.dart`
- Test/support code:
  - `test/routing/route_parameter_redirect_test.dart` (rename optional)
  - `test/routing/route_parameters_test.dart`
  - `test/support/route_ownership_fixture.dart`
  - any current canonical deep-link/restoration/Sync tests affected by the
    retired compatibility expectations
- No Navigator topology, ViewModel, repository, backend, persistence,
  dependency, generated-code or state-management change is intended.
