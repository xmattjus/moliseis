## Context

Motivation in `proposal.md`. Audit of checkout `main`, HEAD `1743a285c7771cd61f2aab101f0bbe56d4aa9c18`, including the current dirty files, the attached backlog and canonical specifications. The shared-snapshot correction was reconciled against planning commit `d3a5cf0a61c48e44269909dde952956f70d786df` and the unchanged production discovery paths. Pre-existing changes to submission/theme/post/weather and pubspec are unrelated and must be preserved.

### Evidence and differences from the backlog

- `lib/domain/repositories/event_repository.dart`: upcoming discovery through `Future<Result<List<int>>> getNextEventIds()`; no existing ongoing discovery.
- `lib/data/repositories/event_repository_impl.dart`: injected `nowUtc` clock and `_currentUtc`; upcoming from Rome midnight to the inclusive end of Rome day +30, ascending start order `Order.unsigned`, limit 6, `findIds()`, query closed in `finally`, `EntityLoadFailed` logging. Ranged/calendar queries remain distinct.
- `lib/data/data-sources/event_entity.dart`: `remoteId` is already `@Id(assignable: true)`, so `findIds()` is compatible with `getById(remoteId)`; start/end are dateNano. The local ObjectBox 5.3.2 dependency provides `greaterThanDate`, with microseconds ×1000 conversion; no rounding or schema change is needed.
- `lib/data/core/object_box_conditions.dart` shares only annual visibility. No equivalent ongoing/current consumer emerges from repositories, use cases and UI; calendar and search answer day/year questions, not instant questions.
- `lib/domain/core/event_time.dart`: `currentCalendarDate` and `utcRangeForCalendarDate` fix Europe/Rome, without the device's local zone; the inclusive final microsecond and DST are already covered by `test/domain/core/event_time_test.dart`.
- `lib/ui/event/view_models/event_view_model.dart`: `UnmodifiableListView` state, constructor automatically starts `loadAll`; `loadNextIds` loads IDs and starts `loadNext` without awaiting it, sequential entity lookup, individual errors omitted. No dispose override. Do not indiscriminately copy the async risks.
- `lib/routing/router.dart`: Home is branch 0 of `StatefulShellRoute.indexedStack`; the route-scoped Provider creates EventViewModel and starts only `loadNextIds`. `lib/config/dependencies.dart` provides the repository, not a global EventViewModel. `ExploreViewModel` manages latest places and does not own Event discovery.
- `lib/ui/explore/widgets/explore_screen.dart`: the actual Home consumes `next`, observes `loadNext`; the Aggiorna menu and pull-to-refresh invoke the same forced sync. `_startSync` is void/unawaited: RefreshIndicator does not await sync. `SyncViewModel` and `_redirectForSync` navigate to `/sync?from=...` and then return to the valid URI (also after a non-fatal error). There is no direct post-sync ID reload. Replacing the shell can recreate providers; the plan tests the outcome without assuming they are retained.
- `lib/ui/core/ui/scaffold_shell.dart` retains tabs; Home remains mounted beneath details/tabs. No return hook recalculates IDs: this is the concrete staleness case to correct. `ShellRouteVisibility` alone does not distinguish Home from a detail in its branch.
- `test/routing/route_ownership_test.dart` uses `test/support/route_ownership_fixture.dart`, which replaces Home with a root stub: it is insufficient to prove production bootstrap. `test/routing/sync_redirect_test.dart` instead contains tests of the real router/app. Also reuse `test/support/events_harness.dart`, used by `test/routing/events_route_test.dart`, for Home tests if compatible.

### Specification compatibility

Canonical `event-temporal-integrity` currently allows starts in the inclusive window from midnight; the delta explicitly modifies the entire upcoming requirement, not annual/day overlap. Archives `2026-09-30-harden-event-temporal-semantics` and `2026-08-30-repair-event-time-review-findings` deliberately preserved that contract and deferred ongoing: this is the subsequent intentional change, not retroactive hardening of the archives. Archive `2026-10-01-add-event-all-day-semantics` and canonical `event-all-day-semantics` establish absent meaningful time and inclusive bounds: none of their requirements changes. The subsequent provenance change (`2026-10-03-add-external-event-provenance-moderation`) also concerns import identity, not membership. An explicit final date equal to the initial date is valid and produces a non-null end: do not reduce all single-day allDay events to the null-end case alone.

## Goals / Non-Goals

**Goals:** settle query, state, error, ordering, refresh and testing contracts before writing production code. Allow technical implementation and review before the visual gate.

**Non-Goals:** no new dependency, backend/migration, schema/DTO/generation, provider/importer, search, calendar, effectiveEnd, status framework or half-open conversion. No app-resume framework, polling, timer or updates while Home remains continuously open. Do not correct RefreshIndicator animation/duration in this change.

## Decisions

### 1. Ongoing query local to the repository

Add `Future<Result<List<int>>> getOngoingEventIds(DateTime snapshotUtc)` to the contract and implementation. The required argument is the discovery pass snapshot; there is no optional fallback to the repository clock. Inside the try, normalize it with `final nowUtc = snapshotUtc.toUtc()`, derive the day with `currentCalendarDate(nowUtc)` and its range with `utcRangeForCalendarDate`. Neither this method nor `getNextEventIds(DateTime snapshotUtc)` reads `_currentUtc`, `_nowUtc` or DateTime.now. The existing repository clock remains for annual/category/coordinate consumers outside this discovery pair.

Equivalent predicate, applied before retrieval:

```text
isDeleted == false AND startDate <= nowUtc AND
  ((endDate IS NOT NULL AND endDate >= nowUtc)
   OR (endDate IS NULL AND day.startUtc <= startDate <= day.endUtc))
```

Inclusive ranged events; null-end only within the same Rome day and after the start. No allDay branch. Use the existing dateNano conditions (`lessOrEqualDate`, `greaterOrEqualDate`, `betweenDate`, `isNull` (the end >= now comparison excludes null ends)) and `findIds()`. Ongoing order is start ascending, then remoteId ascending for equal starts, with no repository limit: return the entire current set. This is a data contract; it does not decide visible count, slicing or section order. Visual count/form remains up to the developer; do not add an arbitrary query cap.

Logging and Result follow `getNextEventIds`, including the correct method name and `query?.close()` in finally even on failure. Do not apply the annual filter: a ranged event started in previous years can still be active.

Settled choice: keep the predicate in the method. Extraction into ObjectBoxConditions has no second consumer and does not improve this single query enough to justify the new helper. The day-overlap alternative is rejected because it includes ended/future events today; effectiveEnd is rejected because it reinterprets null-end.

### 2. Strictly future upcoming with an unchanged window

Change the required contract to `Future<Result<List<int>>> getNextEventIds(DateTime snapshotUtc)`. Normalize the supplied snapshot with `final nowUtc = snapshotUtc.toUtc()` and also use it for the Rome day; replace only the lower predicate with `startDate.greaterThanDate(nowUtc)`. End: normalize `DateTime.utc(today.year, today.month, today.day + 30)` into EventCalendarDate and use its `utcRangeForCalendarDate(...).endUtc`. Preserve the inclusive upper bound, `Order.unsigned` on start, limit 6, `findIds()`, soft-delete and query closure. Do not define the window as 30×24 hours.

For each Home discovery pass, ongoing implies start <= snapshot and upcoming implies start > snapshot using the same explicit argument: empty intersection by construction, without deduplication. The coordinator owns that snapshot, not the queries or View. Capturing separate times in the two queries is rejected: sequential entity resolution can cross a start boundary and create a gap; reversing query order can create a duplicate. A required plain UTC DateTime is sufficient; do not introduce EventDiscoverySnapshot, a temporal framework or a database transaction for time capture. Completed successful passes classify against their captured instant, not the later completion time. This temporal guarantee does not promise atomicity against concurrent cache mutations, failed retrievals retaining older state or intermediate loading states; existing error behavior and snapshot staleness remain unchanged.

Update contract documentation. Adapt the three regressions in `Rome query boundaries`: with clock `2026-12-31T23:30Z`, starts at `23:00Z` have already passed, including the allDay event on 1 January. Updated expectations: the all-day cross-year case has no upcoming; the `[1,2]` case becomes `[2]`; the upper-bound test no longer requires ID 12 but continues to include 13/exclude 14. Add a separate December clock to continue proving future January within the window. Do not remove the associated annual/overlap coverage.

### 3. EventViewModel state and commands

Add `_ongoingIds`, `_ongoing` and UnmodifiableListView getters. Use `Command1<void, DateTime>` for `loadOngoingIds` and convert `loadNextIds` from Command0 to `Command1<void, DateTime>`; `_loadOngoingIds(DateTime snapshotUtc)` and `_loadNextIds(DateTime snapshotUtc)` forward that argument unchanged to their respective repository methods, without reading a clock. Keep `loadOngoing` and `loadNext` as Command0 entity resolvers. No forwarding use case or move into ExploreViewModel. Migrate existing next-ID command tests to `.execute(snapshotUtc)` and both shared fake repository implementations to the required argument, recording received snapshots for tests. All Home classification requests go through `refreshHomeDiscovery()`; an entity-only retry may continue resolving the current ID list without capturing a new time.

ID success: replace IDs (including an empty list), notify, execute the entity command. ID failure: retain the last valid state, do not start the entity command, return the repository's Result.error. Entity load: capture a copy of the IDs, resolve in order through `getById`, omit lookups with Result.error as next already does, publish the resulting list in a single replacement and notify; successful empty results clear previous state. Do not reclassify, sort or add items in the ViewModel. Completed `loadOngoing` also represents an empty/partial result; ID failure remains readable on `loadOngoingIds`. The View will observe both to distinguish loading/error without prescribing their presentation.

For ongoing and next, the ID command must await the entity command instead of leaving it in the background: a reload must not be considered finished before events are published. Preserve lookup errors and the next contract. Build entity lists locally, avoiding `_next.clear()` and visible appends during await. Direct command calls remain serialized by Command; the Home refresh described below is the sole refresh orchestrator, and must also await an ID command and/or entity command already in flight before starting the next load (one-shot listener removed on completion, not polling).

Add a `_disposed` flag to the ViewModel, set in dispose before super.dispose. After await, ongoing/next and the coordinator do not mutate/notify or start other commands if disposed. Also guard completion of the constructor's `_loadAll` with the same flag, because it can be pending when `/sync` unmounts Home. Do not rewrite the calendar/byDate cache or global Command. Do not dispose commands still running: Command notifies in its own finally; this feature does not introduce a general command cancellation/disposal policy.

### 4. Bootstrap and Home return: scoped hook, no framework

Add `Future<void> refreshHomeDiscovery()` to EventViewModel as local orchestration of the two ID commands, which continue to own state/Result. Keep a single in-flight Future and a pending boolean: each request marks pending; the loop consumes pending, waits for pre-existing ID/entity commands to finish, then captures exactly once `final snapshotUtc = _nowUtc().toUtc()` immediately before starting that pass. Execute `loadOngoingIds.execute(snapshotUtc)` and await its entity resolution, then execute `loadNextIds.execute(snapshotUtc)` and await its entity resolution. Neither the delay between queries nor an intervening return request changes that local snapshot. The loop repeats once if requested during the pass; every subsequent coalesced pass captures a new snapshot once when it actually starts, rather than reusing the previous pass's time or sampling when a pending request is enqueued. Concurrent calls share that Future; a request arriving during a fetch must not be lost due to the `Command.running` guard. If one query fails, execute the other anyway, without automatically retrying the same error. Stop the loop if disposed and remove/complete all one-shot waits still registered: their completion only signals the coordinator to exit, it does not cancel the repository fetch. Do not add a global Command or generalized state machine.

The Home Provider in `lib/routing/router.dart` starts `refreshHomeDiscovery()` instead of only `loadNextIds`; the constructor's annual load remains unchanged. No new provider in dependencies.dart.

Only in ExploreScreen State, register a listener on the existing `GoRouter.routerDelegate` in didChangeDependencies, removing it in dispose and replacing it if the router changes. Read `router.state.matchedLocation == RoutePaths.home` (current top route), not routeInformationProvider/browser URL: imperative pushes may not be reflected in the URL. `GoRouter.state`/delegate APIs verified against local go_router 18.0.2 source. Keep a wasHomeVisible boolean; bootstrap does not duplicate the first request. Only a false -> true transition starts VM refresh; unchanged-location/rebuild notifications do not cause refresh. This covers tabs, go to details/search/category, settings push and pop, and sync when the widget is retained. If Home is recreated, bootstrap is sufficient.

The callback captures router/VM references while mounted; schedule post-frame if notification occurs during build, with a mounted guard and a check that it is still on Home before executing. didUpdateWidget updates the VM reference if needed. No dates or deduplication in the View: the hook only signals return. Do not treat a popup dialog/SearchAnchor not navigated through GoRouter as a refresh request.

### 5. Sync/refresh and UI gate

Preserve `_startSync`, SyncViewModel, SyncUseCase and `_redirectForSync`: no parallel sync listener, which could duplicate fetches or precede commits. After manual menu/pull-to-refresh, return to Home must reload both classifications against the updated cache commit through bootstrap or the return hook. A non-fatal error also returns and reclassifies valid cache; a fatal first-sync remains on SyncScreen under the existing contract. Verify this with the production router.

Home consumes `eventViewModel.ongoing` and `next` without temporal comparisons, deduplication, synthetic ends or corrective reordering. The only mandatory new title is “Eventi in corso”. The visual surface and its rendering tests remain gated until the developer defines position, layout, components/cards, visible count, responsive behavior, spacing, styling, animations, skeletons, empty/error presentation and any CTAs. Do not implicitly clone the upcoming grid. Successful empty membership and an error are distinct functional states; their presentation is reserved for the design.

### 6. Tests and reuse

Before editing tests, load the unit/widget skills and `molise-is-test-support-reuse`; for repositories also `molise-is-objectbox-test-store`. For State/dispose callbacks use `molise-is-async-mounted-context-safety`. Reuse `TestObjectBoxEnvironment`, `TestObjectBox`, `makeEventEntity`, `MockLogger`, `MockSupabase`, `FakeEventRepository` and `ControllableEventRepository` in `test/support/fake_repositories.dart`. Both fakes must implement the new method (default empty success); add only necessary results/counters/completers, with defaults unchanged. Do not invent fake Box/Store/Query or a second local repository fake.

Mandatory repository matrix in `test/data/repositories/event_repository_impl_test.dart`, explicit fixed UTC snapshot argument and a single dataset where indicated:

| Case | Test |
| --- | --- |
| 1 | Ranged yesterday -> tomorrow included |
| 2 | Timed active today included |
| 3 | Start later today excluded from ongoing |
| 4 | End before now excluded from ongoing |
| 5 | Start == now included in ongoing |
| 6 | End == now included in ongoing, also including start == end == now |
| 7 | Null-end before now today included |
| 8 | Null-end future today excluded from ongoing |
| 9 | Null-end yesterday excluded |
| 10 | Soft-deleted otherwise ongoing excluded |
| 11 | AllDay single-day today, null end, included |
| 12 | AllDay multi-day containing now included; add explicit final date equal to start |
| 13 | UTC time in the previous day but current Rome day: correct null-end membership |
| 14 | Rome final microsecond, next midnight and first start of the new day: previous null-end expires without extension |
| 15 | DST 29 March 2026 and 25 October 2026: day from policy, not Duration(days:1); inclusive boundaries |
| 16 | Past start today excluded from upcoming even with a future end |
| 17 | Start == now excluded from upcoming |
| 18 | Start now +1 microsecond included in upcoming |
| 19 | Future today included in upcoming |
| 20 | December clock, future January start included in the +30 window |
| 21 | Exact endUtc of Rome day +30 included; +1 microsecond excluded |
| 22 | Soft-deleted future excluded from upcoming |
| Disjointness | Same store/dataset and explicit snapshot supplied to both queries: empty ID intersection, both sets non-empty |
| Query contracts | Ongoing start/remoteId order, more than 6 results without a cap; upcoming order/limit 6; active cross-year ranged event included; discovery queries never read the repository clock |

Derive Rome bounds through the policy. Also run relevant cases with a package-global local timezone different from Rome and restore it; reuse the device-independence tests in the event_time suite without duplicating its entire normalizer. DateNano makes +1 microsecond meaningful: no production epsilon.

ViewModel tests in `test/ui/event/view_models/event_view_model_test.dart`: IDs success/error, preservation of last success, empty list that clears state, partial lookup in order, read-only state, notifications on commit, awaiting entities before ID completion, two closely spaced refreshes with completers and the latest result, refresh overlapping a direct ID/entity command already running (execute alone would be a no-op), ongoing error that does not prevent next, dispose with IDs/entity/yearly pending without notifications/continuations. Extend next regressions affected by awaiting and the required snapshot argument without touching unrelated calendar tests.

Mandatory advancing-clock regression: settle the constructor's annual load first, then count only discovery clock reads. Use a stable dataset with an already-active event A whose getById lookup is held by a completer, and an event B starting at `11:00:00Z`. Start a pass at `10:59:59.900Z`, let the ongoing query return A and suspend its entity resolution, advance the mutable injected clock to `11:00:00.200Z`, then release the lookup. Record the snapshots received by both fake repository methods: both must equal `10:59:59.900Z` and the discovery clock must have been read exactly once. Derive fake responses from each received snapshot (or reuse a real repository over a temporary store), not preconfigured constant lists: A is ongoing and B remains upcoming for that pass, with no overlap or missing B due to clock drift. Request a subsequent pass at the advanced time and verify one fresh shared snapshot, B ongoing and not upcoming. Also hold a first pass while enqueueing a coalesced return request, advance the clock again and verify the subsequent pass gets its own single shared snapshot; the first pass retains its original snapshot. Add a Rome-midnight variant so null-end day membership and upcoming-window day both remain derived from the captured pass day even if entity resolution finishes in the next Rome day. These tests supplement the fixed-snapshot repository matrix, rather than assuming production shares a fixed clock.

New `test/routing/home_event_discovery_test.dart`: real buildAppRouter/Provider harness, existing support reuse, verify bootstrap once, tab away/back with advanced clock or results, detail go/back and settings push/pop, no reload on rebuild/unchanged URI, overlapping returns during load, listener removal and pending unmount. Verify the production Home VM, not a root stub. New `test/ui/explore/widgets/explore_screen_test.dart` after the UI gate: distinct title, correct ongoing/next sources, no duplicate appearance for a fixed dataset, readable empty-success vs error state, event navigation through the existing route if the design includes opening. For sync, extend `test/routing/sync_redirect_test.dart` with menu and pull-to-refresh, new cache result before return and reclassification of both; do not change the redirect contract.

## Risks / Trade-offs

- [Home remains open across start/end/midnight] -> Intentional snapshot state; refresh or Home return reclassifies, no live guarantee.
- [The clock crosses start/end or Rome midnight between queries] -> One coordinator-owned snapshot per discovery pass, required query/ID-command arguments and advancing-clock/delayed-lookup tests; no temporal gap or overlap caused by separate clock readings. Concurrent cache mutations and failed retrievals retaining older state remain outside the successful-pass guarantee. Do not correct with UI deduplication.
- [Command ignores execute while running] -> Local coalescing orchestrator and entity awaiting; tests with closely spaced returns, no polling.
- [Provider unmounted by sync while a fetch is pending] -> Scoped dispose guards and tests; capture references before await/callback and mounted guard in State.
- [Existing tests encode the old lower bound] -> Update specific expectations while preserving annual/upper/cross-year tests.
- [High ongoing count] -> No arbitrary data cap; visual design reserved for the developer, no new pagination required now.

## Migration Plan

Implement in reviewable units: ongoing repository and tests; upcoming/delta regressions; ViewModel/fakes; bootstrap and hook/refresh with tests; visual surface only after developer design; final verification. No data migration or backend deployment. Source-only rollback of affected files, preserving data and unrelated work. Archive/sync canonical specs only when all tasks, including the UI gate and related tests, are complete.

## Open Questions

Only visual design deliberately reserved for the developer. No technical/temporal/ownership decision deferred to the implementer. Hooks and harnesses have concrete test gates; they do not require new architectural exploration.
