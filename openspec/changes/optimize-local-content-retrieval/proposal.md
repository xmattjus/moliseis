## Why

Several local content-discovery flows first query ObjectBox for entity IDs and then immediately resolve those IDs one by one through `getById`. The pattern was originally useful for UI loading placeholders whose count matched the eventual content count, but the current loading surfaces no longer consume those ID counts.

The remaining ID-first flows therefore add repository work, asynchronous boundaries, intermediate ViewModel state and chained Commands without providing product value. For a six-item section, a discovery query followed by six individual lookups can require up to seven local retrieval operations where ObjectBox can return the already-filtered, ordered and limited domain content from one query.

The pattern also obscures error ownership. `ExploreViewModel` and `EventViewModel` expose UI-facing entity Commands while discovery failures occur in separate ID Commands, so existing UI error branches may never observe the actual repository failure and retry may resolve stale IDs instead of repeating discovery.

Before replacing the current Command implementation with `command_it` and concurrency-aware wrappers, the local retrieval flows should be simplified so one logical list load normally consists of one repository operation, one Command and one final ViewModel state commit.

## What Changes

- **BREAKING (internal source contracts):** Replace latest-place ID discovery followed by per-item lookup with direct `Place` retrieval from `PlaceRepository`.
- **BREAKING (internal source contracts):** Replace upcoming-event ID discovery followed by per-item lookup with direct `Event` retrieval from `EventRepository`, preserving the current temporal contract, ordering and result limit. This change does not implement the separately planned ongoing/upcoming temporal semantics.
- **BREAKING (internal source contracts):** Consolidate active search discovery so `SearchRepository` returns the final mixed place/event domain results directly rather than exposing place and event ID lists for the ViewModel to resolve.
- Move effective filtering currently supplied indirectly by subsequent `getById` calls into the owning direct repository query, including soft-delete filtering.
- Make the same Command observed by the UI own the repository discovery `Result`, so discovery errors are surfaced through that Command rather than being hidden behind an intermediate ID Command.
- Publish successful list results as a single final state replacement rather than incrementally mutating ViewModel collections across asynchronous per-item lookups.
- Remove intermediate ID state, ID-only Commands and ID-only repository APIs that have no remaining consumer.
- Remove dormant ID-first flows instead of migrating them when execution-HEAD audit confirms they have no non-commented runtime consumer, specifically the current `ExploreViewModel` near flow and the unimplemented related-search flow.
- Update shared fakes, tests, routing/DI construction and internal agent guidance affected by the contract changes.
- Reconcile the still-open `add-home-ongoing-events` OpenSpec change after the new production baseline is established so it plans direct event retrieval rather than recreating ID-first loading.

## Capabilities

### New Capabilities

- `local-content-retrieval`: targeted local list-discovery paths return their final domain models directly, preserving their existing membership/order/limit contracts without per-item ID resolution in the ViewModel.

### Modified Capabilities

None. Event temporal membership is intentionally unchanged by this optimization. The separate `add-home-ongoing-events` change remains responsible for modifying upcoming temporal semantics.

## Impact

Audit baseline: repository `xmattjus/moliseis`, branch `main`, HEAD `8ccc3fd675ca0d8490dab3801e4a44fc3fd646e5`.

Primary production surfaces:

- `lib/domain/repositories/place_repository.dart`
- `lib/data/repositories/place_repository_impl.dart`
- `lib/ui/explore/view_models/explore_view_model.dart`
- `lib/domain/repositories/event_repository.dart`
- `lib/data/repositories/event_repository_impl.dart`
- `lib/ui/event/view_models/event_view_model.dart`
- `lib/domain/repositories/search_repository.dart`
- `lib/data/repositories/search_repository_impl.dart`
- `lib/ui/search/view_models/search_view_model.dart`
- `lib/routing/router.dart`
- `lib/routing/core_routes.dart` where constructor dependencies change
- Dormant search/Explore files or members proven unused by execution-HEAD search

Test/support surfaces include repository tests, ViewModel tests, routing/widget fixtures and `test/support/fake_repositories.dart`.

Internal guidance that teaches removed ID-first patterns, including `.agents/skills/molise-is-result-pattern/SKILL.md`, must be reconciled if still present.

The open `openspec/changes/add-home-ongoing-events` artifacts must be updated after production optimization and before that change is implemented.

No Supabase table, migration, Edge Function, DTO, sync payload, ObjectBox schema, generated model, external importer or backend contract changes. `events` and `places` remain synchronized as complete entities; this change concerns how the already-populated local ObjectBox store is queried.

No new dependency, state-management solution, concurrency primitive or Command implementation.
