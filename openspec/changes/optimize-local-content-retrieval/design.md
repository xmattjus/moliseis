## Context

Audit baseline: `xmattjus/moliseis`, `main` at `8ccc3fd675ca0d8490dab3801e4a44fc3fd646e5`. See `proposal.md` for motivation.

The backend schema stores published places and events as complete entities and the Flutter sync repositories materialize them into ObjectBox. The ID-first behavior addressed here occurs only after local synchronization and is not imposed by the remote schema.

### Current Explore flow

`ExploreViewModel` currently initializes:

```text
load
  -> PlaceRepository.getLatestPlaceIds()
  -> _latestIds
  -> loadLatest.execute()
  -> for each ID: ExploreUseCase.getById()
  -> _latest
```

`latestIds` has no production consumer outside the ViewModel. `ExploreScreen` listens to `loadLatest`, not to the preceding `load`.

`SkeletonContentSliverGrid` no longer accepts or derives a placeholder count from `latestIds`; it renders a generic skeleton grid. The original reason for loading IDs first therefore no longer exists.

The current split also masks discovery errors: `getLatestPlaceIds()` belongs to `load`, while the UI's error branch observes `loadLatest`. `loadLatest` itself ignores failed individual lookups and returns success, so an ID-query failure is not represented by the Command the UI observes.

`ExploreViewModel` also contains `loadNear`, `_near` and `PlaceRepository.getIdsByCoordinates()`. At the audited HEAD no non-commented runtime invocation of `ExploreViewModel.loadNear` or consumption of `ExploreViewModel.near` was found. The application has separate, active nearby-content flows through `PostViewModel`, `GeoMapViewModel` and the direct `getByCoordinates()` repository APIs.

Important semantic difference: `PlaceRepositoryImpl.getByCoordinates()` and `getIdsByCoordinates()` are not currently equivalent. The former queries a larger nearest-neighbor candidate set, applies a limit and excludes identical coordinates; the latter requests three nearest IDs without the same filtering. Therefore do not mechanically replace one with the other. If execution-HEAD search still proves the Explore-specific ID flow unused, delete that dead flow instead of inventing a replacement.

### Current Event flow

`EventViewModel` currently has:

```text
loadNextIds
  -> EventRepository.getNextEventIds()
  -> _nextIds
  -> loadNext.execute()
  -> for each ID: EventRepository.getById()
  -> _next
```

Home observes `loadNext`, while routing starts `loadNextIds`.

As with Explore, an ID-discovery error belongs to a Command that the rendered section does not observe. `loadNext` itself silently omits failed item lookup and returns success, making its current error UI effectively unable to represent the primary discovery failure. Its retry also re-resolves the current `_nextIds` rather than repeating discovery.

The open `add-home-ongoing-events` plan currently expands this same ID-first pattern to ongoing events. That plan must not be implemented against this obsolete baseline.

### Current Search flow

`SearchViewModel._search()` currently performs:

```text
SearchRepository.getPlaceIdsByQuery()
SearchRepository.getEventIdsByQuery()
          ↓
place IDs -> ExploreGetByIdUseCase.getById()
event IDs -> EventRepository.getById()
          ↓
final mixed ContentBase list
```

This causes one discovery path plus N additional lookups and makes `SearchViewModel` depend directly on `SearchRepository`, `EventRepository` and `ExploreGetByIdUseCase`, although `SearchRepositoryImpl` already owns the name/category/city discovery rules.

The direct replacement must preserve effective current behavior, not merely reproduce the raw ID query. In particular, place search queries do not uniformly enforce soft deletion themselves today; the subsequent `PlaceRepository.getById()` does. Once that second lookup disappears, `SearchRepositoryImpl` must enforce equivalent soft-delete filtering on every place result path before returning domain models.

`Result.zip2` awaits place discovery first and returns its error without starting event discovery on failure. Both current search methods mutate the shared parameterized `_cityQuery`; parallelizing the two phases would change short-circuit behavior and risk shared-query interference.

Event search already relies on the canonical annual-visibility rule and its city traversal mirrors that rule; that behavior must remain unchanged.

Current result ordering is all deduplicated place matches, then all deduplicated event matches. Within each type, first-match order from the existing name/city/category aggregation is retained. The optimization must not silently introduce a new relevance algorithm or sorting policy.

### Dormant related-search flow

`SearchViewModel` still contains:

```text
loadRelatedResultsIds
 -> SearchRepository.getRelatedResults() -> IDs
 -> loadRelatedResults
 -> N ExploreGetByIdUseCase.getById()
```

But the production `SearchResultScreen` has both the trigger and `SearchResultRelatedSliverList` integration commented out, and `search_result_related_sliver_list.dart` itself is wrapped in a TODO/comment block.

This is not an active feature. If execution-HEAD audit confirms no non-commented runtime consumer, delete the dormant related-search flow and its repository state/helpers/tests rather than converting it to another direct API. Future related-search work can design its real contract when the feature is actually resumed.

### Command and lifecycle baseline

This change deliberately retains `lib/utils/command.dart` and the current Command semantics.

Existing `_disposed`, generation, retry and async-lifecycle hardening outside code made unnecessary solely by deleting an ID-first stage is not a cleanup target. `command_it`, `RestartableCommand`, cancellation and latest-wins semantics belong to a subsequent change.

The purpose here is to reduce the number of asynchronous stages before changing the concurrency model.

### Planning audit and dirty-tree evidence

Planning inspection on 2026-10-05 confirmed branch `main` and the exact baseline HEAD above. The inspected repository queries, ViewModels, Home listeners/retries, route bootstrap and commented related widget match this draft. Existing regression suites include `test/data/repositories/{place,event,search}_repository_impl_test.dart`, `test/ui/event/view_models/event_view_model_test.dart`, and `test/ui/search/view_models/search_view_model_test.dart`. This planning pass did not execute Flutter tests or establish performance measurements; execution must still perform the focused baseline gates.

Pre-existing modified files at planning time, outside this change, are:

- `lib/ui/content_submission/widgets/content_submission_fields.dart`
- `lib/ui/core/themes/app_color_schemes_theme_extension.dart`
- `lib/ui/core/themes/text_styles.dart`
- `lib/ui/geo_map/widgets/geo_map_modal_post.dart`
- `lib/ui/post/widgets/components/post_media_slideshow.dart`
- `lib/ui/post/widgets/components/post_section_header.dart`
- `lib/ui/post/widgets/components/post_section_slideshow.dart`
- `lib/ui/post/widgets/post_screen.dart`
- `lib/ui/weather/widgets/weather_forecast_button.dart`
- `pubspec.lock`
- `pubspec.yaml`

Preserve these changes and re-record execution-time status. Package dirtiness is not permission to alter dependencies as part of this change.

## Goals / Non-Goals

### Goals

- Eliminate active local ID-first → per-item lookup chains where the caller ultimately needs the same complete domain models.
- Make repository boundaries return the final ordered/filtered model collection required by the ViewModel.
- Reduce each targeted ViewModel list load to one logical repository operation and one Command.
- Remove intermediate ID state/Commands/APIs that exist only to support those chains.
- Remove related dead ID-first code when its lack of runtime consumers is proven.
- Preserve active product membership, ordering, limits, UI states and navigation.
- Make existing UI-facing Commands own their discovery errors directly.
- Establish a simpler baseline for later Command/concurrency hardening.
- Reconcile the open ongoing-events plan with that baseline.

### Non-Goals

- No `command_it`, `stream_transform`, `RestartableCommand` or replacement of the current Command pattern.
- No new cancellation, superseding, restartable or sequential concurrency policy.
- No general cleanup of existing `_disposed`, generation-token or lifecycle protections.
- No change to event temporal membership or the current upcoming window in production.
- No implementation of “Eventi in corso”.
- No new search relevance, ranking, pagination, fuzzy matching or related-search feature.
- No changes to Post or Map nearby-content contracts except shared repository/fake compilation adjustments forced by removed unused methods.
- No Supabase/schema/backend/sync changes.
- No ObjectBox schema or generated-code changes.
- No new dependency.
- No speculative repository abstraction or generic query framework.
- No performance microbenchmark requirement.

## Decisions

### 1. Repository discovery returns the final model type

When the consumer wants a list of `Place`, `Event` or `ContentBase`, the owning repository SHALL return those domain models directly.

The targeted shape becomes:

```text
ViewModel Command -> repository query -> List<DomainModel> -> single state commit
```

instead of:

```text
ViewModel Command A -> List<int> -> intermediate state
  -> ViewModel Command B -> N getById() -> List<DomainModel>
```

One discovery query for latest/upcoming removes the explicit ID query → N `getById` chain. Domain mapping still accesses lazy ObjectBox city/media relations and may cause additional reads. Search retains multiple internal match queries behind one logical repository operation. No single-disk-read claim or measured performance improvement is made.

Per-item `getById` remains valid for actual detail/single-entity use cases and is not deprecated globally. Retaining the two-stage chain would preserve unnecessary operations and mask error ownership.

### 2. Latest places become one repository query and one Command

Replace the ID-only latest API with a direct model API. Preferred contract:

```dart
Future<Result<List<Place>>> getLatest();
```

If execution-head repository naming reveals a material conflict, Codex may choose an equally clear repository-consistent name such as `getLatestPlaces`, but must document the reason rather than preserve `getLatestPlaceIds`.

`PlaceRepositoryImpl` SHALL preserve the existing latest-place query semantics:

- `isDeleted == false`;
- order by `createdAt` descending;
- limit 6;
- map query entities directly to `Place`;
- normal `Result`/logging/query cleanup behavior.

`ExploreViewModel` SHALL expose only the UI-facing `loadLatest` Command for this flow. Constructor bootstrap starts that Command directly.

Remove, when no execution-head consumer remains: `load`, `_load()`, `_latestIds`, `latestIds`, `getLatestPlaceIds()`.

`loadLatest` SHALL own the repository `Result`. Repository discovery failure therefore becomes `loadLatest.error`, matching the error state already observed by `ExploreScreen`. Do not preserve the previous accidental masking through a separate upstream Command.

On successful retrieval, `_latest` is replaced as one synchronous commit after the repository Future completes. Successful empty retrieval clears prior state. A repository error does not masquerade as a successful empty result.

### 3. Dead Explore-near ID flow is removed rather than migrated

Before editing it, perform execution-HEAD search for `ExploreViewModel.loadNear`, `ExploreViewModel.near`, and `PlaceRepository.getIdsByCoordinates`. Ignore comments/tests when determining runtime use.

If the audited result remains as at `8ccc3fd...` — no runtime consumer outside the ViewModel — remove `ExploreViewModel.loadNear`, `_loadNear`, `_near`, `near`, `PlaceRepository.getIdsByCoordinates`, `PlaceRepositoryImpl.getIdsByCoordinates`, and their fake/test plumbing.

Do not redirect this dead path to `PlaceRepository.getByCoordinates()` merely to preserve an unused API, because the two existing coordinate queries have different semantics. `PlaceRepository.getByCoordinates()` itself remains unchanged because it is actively consumed by Post/Map flows.

If a new execution-HEAD runtime consumer exists, stop this deletion subtask, document the consumer and preserve its exact semantics with a direct-model query rather than guessing that `getByCoordinates()` is equivalent.

### 4. ExploreViewModel drops entity-resolution dependency only where proven unused

Once latest and any surviving near flow no longer use per-ID resolution, remove `ExploreUseCase` / `ExploreGetByIdUseCase` from the `ExploreViewModel` constructor if execution-head search confirms no remaining use in that ViewModel. Update the Home route/provider construction accordingly.

Do not delete `ExploreUseCase` globally: it has other active consumers such as category/detail-related code and remains outside this cleanup.

### 5. Upcoming events become direct Event retrieval without temporal change

Replace `Future<Result<List<int>>> getNextEventIds();` with a direct-model API for the current production temporal semantics, preferred:

```dart
Future<Result<List<Event>>> getNextEvents();
```

The optimization SHALL preserve exactly the production query semantics present at execution HEAD:

- Current Europe/Rome lower/upper bounds as defined before `add-home-ongoing-events`. At the audited baseline these are start >= Rome midnight today and start <= the inclusive end of Rome day +30, both converted to UTC.
- Soft-delete exclusion.
- Start ascending ordering (existing `Order.unsigned`).
- Limit 6.
- No interval-based reinterpretation.
- No snapshot argument introduced by this optimization.

Implementation uses the same query predicate/order/limit but retrieves entities and maps them directly to `Event`.

`EventViewModel` reduces `loadNextIds`, `loadNext`, `_nextIds`, `_next` to `loadNext`, `_next`. `loadNext` directly invokes repository discovery and commits the returned list.

Remove `loadNextIds`, `_loadNextIds`, `_nextIds`, `nextIds`, `getNextEventIds()`, and affected fake/test plumbing. The Home route starts `loadNext` directly instead of `loadNextIds`.

The existing Home UI already observes `loadNext`; discovery failures SHALL therefore surface as `loadNext.error`, and retry SHALL repeat the actual upcoming query. Do not preserve the previous split where an ID-discovery failure could leave the UI observing an idle/successful entity Command.

This change SHALL NOT adopt the future strictly-after-now snapshot semantics from `add-home-ongoing-events`; that remains a separate semantic change.

### 6. SearchRepository owns complete active search discovery

Replace the separate public ID APIs `getPlaceIdsByQuery(String text)` and `getEventIdsByQuery(String text)` with one active search contract returning the final mixed domain list, preferred:

```dart
Future<Result<List<ContentBase>>> getResultsByQuery(String text);
```

The repository already owns the search rules and SHALL now also own materialization.

Place discovery SHALL complete successfully before event discovery starts, preserving the current `Result.zip2` sequential short-circuit semantics. The two phases SHALL NOT be parallelized or executed through `Future.wait`, because they share parameterized repository query state. A place-phase `Result.error` SHALL be returned as the overall error without starting the event phase. This preserves ordering of phase execution as well as output order; it does not add a new execution policy across simultaneous public searches.

The focused repository regression SHALL prove that a place-phase failure leaves event-phase query execution count at zero and preserves the original error in the overall `Result.error`. Verify actual phase/query execution using existing test support or a narrow test seam; do not reintroduce removed public ID APIs solely for counters.

The direct result preserves current effective behavior:

1. Resolve place matches by the existing name, associated-city and category paths.
2. Preserve first-match ordering while deduplicating a place matched through multiple paths.
3. Exclude soft-deleted places on every place path, including city-linked entities, because the removed downstream `PlaceRepository.getById()` previously supplied that effective filtering.
4. Resolve event matches by the existing name, associated-city and category paths.
5. Preserve the canonical current-year overlap/soft-delete rule from `event-temporal-integrity`.
6. Preserve first-match ordering while deduplicating an event matched through multiple paths.
7. Return all place results first, followed by all event results, matching the current ViewModel concatenation.
8. Do not deduplicate a place against an event merely because their numeric IDs are equal.
9. Map directly to domain models before returning.

Capture the event search's current time consistently with the current implementation; do not change its temporal contract. No new relevance score or sorting policy. Consolidation moves ownership and materialization, rather than replacing the existing aggregation with a query framework.

### 7. SearchViewModel becomes a consumer of SearchRepository only for search discovery

For search results/suggestions, remove direct entity resolution from `SearchViewModel`.

Preferred dependency after dormant-related cleanup: `SearchRepository`, rather than `SearchRepository`, `EventRepository`, `ExploreGetByIdUseCase`, if execution-head search confirms those extra dependencies have no remaining SearchViewModel use.

`loadResults` and `loadSuggestions` continue to use the current `Command1<void, String>` implementation and existing minimum-query-length rule. Both invoke the direct repository API and make one final collection replacement after successful completion.

Retain the `_disposed` guard immediately after awaiting `getResultsByQuery` and before any successful collection replacement or `notifyListeners()`:

```dart
final result = await _searchRepository.getResultsByQuery(query);
if (_disposed) return result.map((_) {});
// Commit successful results only after this guard.
```

Replace the old pending-place-ID disposal regression with equivalent direct-result regressions for both results and suggestions: start the Command, keep the direct repository Future pending, dispose the ViewModel, complete with a successful non-empty collection, then verify no assignment to `_results`/`_suggestions`, no ViewModel `notifyListeners()` and no late mutation. The Command may settle normally under current semantics. Keep assertions about ViewModel notification separate from Command notifications.

The repository now owns both phases, so disposal of its caller during a pending operation does not promise to prevent the repository-owned event phase from executing. Preserve the no-late-publication guarantee without introducing cancellation, a disposal callback into the repository, or a new concurrency primitive. The independent place-error short-circuit guarantee in Decision 6 remains mandatory.

A short/invalid query retains the current no-op semantics unless focused UI tests prove that clearing is already required by the existing contract; this optimization must not invent new query UX.

Repository error propagates through the same Command being executed. Do not publish partial place-only or event-only results if the overall repository operation returns `Result.error`.

The optimization does not implement latest-wins. Simultaneous `loadResults` / `loadSuggestions` behavior remains governed by the current Command/repository implementation and is reserved for later hardening.

### 8. Dormant related-search code is removed when the runtime audit remains empty

At the audited HEAD, related-search UI and triggers are commented out/TODO-only. Perform execution-head search before deletion.

If no non-commented runtime consumer exists, remove:

- `SearchViewModel.loadRelatedResults`, `loadRelatedResultsIds`, `_relatedResults`, `_relatedResultsIds`, `relatedResults`, `relatedResultIds`;
- `SearchRepository.getRelatedResults`;
- `SearchRepositoryImpl.getRelatedResults`, `_getRelatedResults`, `_lastPlaceResultIds`, `_categorySearched`;
- Related fake/counter/completer/test plumbing that exists solely for this dormant feature.

Delete the fully commented/TODO-only `search_result_related_sliver_list.dart` and remove stale commented imports/invocations from `search_result_screen.dart` if still unchanged at execution HEAD.

Do not replace this dormant flow with a new direct related-results API. Related content can receive a fresh contract when the feature is intentionally resumed.

If an execution-head runtime consumer exists, document it and keep the feature, converting its retrieval to direct models under the same repository-owned principle rather than deleting it.

### 9. Successful list publication is atomic at the ViewModel boundary

For all targeted active flows, construct or receive the complete result before replacing visible ViewModel state. Do not clear visible state and append visible items across awaited individual lookups.

Preferred pattern: await repository → `Result<List<T>>` → one synchronous state replacement.

This reduces transient partial state and creates the intended baseline for future restartable/latest-wins Commands.

Existing UI that primarily listens to the Command may continue doing so. Add `notifyListeners()` only where current non-Command consumers require it; do not add redundant notifications mechanically.

### 10. Error semantics follow the UI-facing Command

The same Command representing a user-visible logical load SHALL own the discovery Result:

- `loadLatest` owns latest-place repository errors;
- `loadNext` owns upcoming-event repository errors;
- `loadResults` / `loadSuggestions` own search repository errors.

Do not preserve accidental behavior caused by an upstream ID Command failing while the UI observes a downstream entity Command. Successful empty retrieval and failed retrieval remain distinct states.

Per-item missing lookup semantics are intentionally retired with the removed lookup stage. A recoverable failure of direct repository query/materialization SHALL fail the logical repository operation through `Result.error`; it SHALL NOT be converted into a partial success by skipping individual entities. Replace obsolete “silently skips when getById fails” tests with direct operation failure/no-partial-publication regressions. Preserve the existing boundary between expected recoverable `Exception` failures and unexpected programming `Error` propagation; this decision does not require blanket catching `StateError` or every thrown object.

Existing last-success retention behavior must be established from each active flow's UI/tests before implementation. Do not clear previously visible successful state on error unless that is already the effective intended contract.

### 11. ID-returning APIs remain when IDs are the actual domain need

This is not a ban on repository methods returning IDs. Do not remove APIs such as favourite-ID retrieval merely because their names contain `Ids` when callers genuinely require identity membership rather than immediate full entity materialization.

The removal criterion is: an ID-only discovery result exists solely so the same caller can immediately resolve every returned ID into the same domain entities.

### 12. No loading-placeholder count contract remains

`SkeletonContentSliverGrid` currently renders generic loading content and does not consume latest/upcoming ID counts.

The optimization SHALL NOT introduce a separate count query merely to reproduce the historical shimmer-count behavior. If a future design requires exact placeholder cardinality, it must justify that requirement independently instead of restoring N+1 retrieval.

### 13. Current Command implementation is frozen for this change

`lib/utils/command.dart` is not modified. Do not introduce `command_it`, restartable wrappers, cancellation, superseding, new execution modes or Command disposal semantics.

Do not remove existing lifecycle guards merely because fewer awaits remain. The Definition of Done is a simpler data flow under the current Command semantics.

### 14. Reconcile add-home-ongoing-events after the optimized baseline is green

`add-home-ongoing-events` is an open planning change and currently assumes ongoing IDs → per-ID entity resolution and next IDs → per-ID entity resolution.

After production optimization and its focused regression gates pass, update that change before it is implemented.

Required conceptual baseline becomes:

```dart
Future<Result<List<Event>>> getOngoingEvents(DateTime snapshotUtc);
Future<Result<List<Event>>> getNextEvents(DateTime snapshotUtc);
```

That change, not this optimization, introduces the explicit shared snapshot and strictly-future upcoming semantics.

Its EventViewModel design becomes `Command1<void, DateTime> loadOngoing`, `Command1<void, DateTime> loadNext`, `_ongoing`, `_next`, with no `ongoingIds`, `nextIds`, `loadOngoingIds`, `loadNextIds` or second entity-resolution Commands.

`refreshHomeDiscovery()` still captures one snapshot per pass and supplies the same value to both direct repository operations. The shared-snapshot guarantee remains necessary because the first complete repository query may be delayed before the second begins.

Replace plan/test language such as “delayed entity resolution crosses event start” with “delayed first discovery query crosses event start” while preserving the same temporal proof: both repository calls receive the pass snapshot even if wall-clock time advances between them.

Update its `home-ongoing-events` delta so:

- Repository retrieval returns ordered `Event` collections, not ID sets.
- Home receives direct read-only entity state.
- Direct retrieval failure retains prior successful state according to that plan's contract.
- Successful empty retrieval clears it.
- The obsolete partial per-ID lookup scenario is removed.
- No presentation-layer deduplication or temporal correction is introduced.

Update proposal, design, tasks and affected delta specs consistently, then run `openspec validate add-home-ongoing-events --strict --no-interactive`.

This reconciliation is part of completing `optimize-local-content-retrieval`; implementing the ongoing feature is not.

## Risks / Trade-offs

- Direct search accidentally exposes soft-deleted places → The old second-stage `getById` silently supplied this filtering. Add repository regressions for name/category/city place paths before removing that stage.
- Direct query changes order → Preserve existing query order/limit and first-match dedup order. Do not opportunistically sort search results.
- Latest/upcoming error UI changes → The old split masks primary discovery errors. Treat surfacing them on the already-observed UI Command as intentional correction, with focused widget/ViewModel tests.
- Dead code later proves to have a runtime consumer → Deletion tasks are audit-gated. If a real consumer appears at execution HEAD, document it and preserve semantics with direct retrieval.
- Upcoming semantics accidentally adopt ongoing-plan behavior early → Keep optimization tests pinned to the execution-head production temporal contract. Snapshot/strict-future changes occur only in `add-home-ongoing-events`.
- Search consolidation becomes a relevance refactor → Reject new scoring/sorting/query architecture. This change moves ownership/materialization only.
- Fewer awaits tempt removal of lifecycle guards → Do not remove hardening unless the relevant code itself disappears. Lifecycle/concurrency cleanup belongs to the later Command change.
- Repository API cleanup expands excessively → Remove only APIs and state whose consumers disappear as a direct consequence of this change.

## Migration Plan

No persisted-data migration and no compatibility bridge.

This is an internal source-level breaking change across domain repository interfaces. Update contracts, implementations, shared fakes and consumers atomically inside the same change.

No deprecated compatibility methods such as `getLatestPlaceIds()` delegating to a direct-model method: there is no external package consumer that justifies retaining duplicate APIs.

## Open Questions

No architectural question is intentionally left for implementation.

Codex must re-audit execution HEAD before applying the plan and may document factual drift. It must not independently choose a different concurrency architecture, preserve dead ID stages for convenience, or implement the separate ongoing-event feature.
