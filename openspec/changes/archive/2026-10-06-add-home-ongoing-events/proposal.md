## Why

Home does not distinguish events that have already started and are still active from future events. The current “Prossimi eventi” query starts at Europe/Rome midnight and also includes starts that have already passed today: adding the section without correcting that contract would produce overlapping classifications.

## What Changes

- Introduce `EventRepository.getOngoingEvents(DateTime snapshotUtc)` returning ordered `Event` collections directly, with membership at the UTC snapshot supplied by the caller: inclusive ranged events; null-end events limited to the Rome civil day of their start, after their start; soft-deleted events excluded.
- Apply the same persisted bounds to timed and `allDay` events, without reinterpreting the flag.
- Make `getNextEvents(DateTime snapshotUtc)` strictly future relative to the same supplied snapshot, preserving ordering, the limit of 6 and the inclusive end of its Rome day +30.
- Expose read-only `ongoing` and `next` state through `loadOngoing` and `loadNext` in `EventViewModel`, following the existing Command/Result and direct-retrieval pattern; both commands accept the explicit UTC snapshot and publish one final collection after success.
- Make `refreshHomeDiscovery()` own exactly one clock capture per discovery pass and supply that snapshot to both queries, guaranteeing temporal disjointness for the pass even if time advances during the first discovery query. Initialize both loads in the Home route and reclassify when returning to Home retained by the shell; preserve the existing sync flow.
- Integrate a distinct section named “Eventi in corso” according to the developer-supplied implementation in `ExploreScreen`. The developer owns its visual choices; the design gate was satisfied on 6 October 2026.
- Add deterministic repository, ViewModel and navigation/refresh tests, including an advancing clock and delayed first discovery query to verify the shared snapshot; no timers or polling.

## Capabilities

### New Capabilities

- `home-ongoing-events`: ongoing membership, separation from upcoming for each shared-snapshot discovery pass, application state, bootstrap and reclassification in supported Home paths, with a visual gate.

### Modified Capabilities

- `event-temporal-integrity`: update “Upcoming events remain start-date-based” to require starts strictly after the caller-supplied UTC snapshot shared with ongoing in a Home discovery pass, preserving the inclusive civil upper bound.
- `local-content-retrieval`: extend direct model retrieval and one-UI-facing-Command guarantees to ongoing-event Home discovery, keeping both ongoing and upcoming free of ID-first/per-item resolution plumbing.

## Impact

- `lib/domain/repositories/event_repository.dart`, `lib/data/repositories/event_repository_impl.dart`.
- `lib/ui/event/view_models/event_view_model.dart`, `lib/routing/router.dart`, `lib/ui/explore/widgets/explore_screen.dart`.
- `test/data/repositories/event_repository_impl_test.dart`, `test/ui/event/view_models/event_view_model_test.dart`, `test/support/fake_repositories.dart`; existing/new functional Home tests identified in the design.
- OpenSpec delta for `local-content-retrieval` so ongoing discovery formally inherits the direct-retrieval and UI-facing Command contract already established for upcoming discovery.
- Reuse of `EventTimePolicy`, ObjectBox dateNano and existing DI. `ObjectBoxConditions` remains unchanged: no second ongoing consumer justifies a shared helper.
- No changes to Supabase, migrations, schema/DTO/generators, calendar, search, provider/importer or dependencies. No new use case, temporal-status framework, effectiveEnd or half-open interval.
