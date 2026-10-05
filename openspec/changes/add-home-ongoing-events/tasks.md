## 1. Repository ongoing semantics

- [ ] 1.1 Reconfirm HEAD and the diff of affected files only against the audit in design.md; load the test/unit, test-support-reuse and ObjectBox test-store skills. Verification: no material contradiction and no changes to unrelated work; document any delta before proceeding.
- [ ] 1.2 In `test/data/repositories/event_repository_impl_test.dart`, prepare a real store, shared fixtures and a deterministic UTC clock for ongoing matrix cases 1–10 in the design. Verification: tests describe exact start/end inclusion, single-day null-end and soft-delete, not simple day overlap.
- [ ] 1.3 Extend `lib/domain/repositories/event_repository.dart` with `getOngoingEventIds()` and contract documentation; update both `FakeEventRepository` and `ControllableEventRepository` in `test/support/fake_repositories.dart` with default empty success and necessary configuration/counters/completers. Verification: all implementers found through repository search compile without a new abstraction or local fake.
- [ ] 1.4 Implement the query in `lib/data/repositories/event_repository_impl.dart` as in decision 1: a single `_currentUtc`, local predicate, Rome null-end range, soft-delete, findIds, start ascending/remoteId ascending, no limit, Result/logging/finally. Verification: cases 1–10 pass with a real store and the clock is called once.
- [ ] 1.5 Add allDay cases 11–12 and an explicit final date equal to the initial date, an active ranged event started in a previous year, more than six ongoing events and equal-start events ordered by ID. Verification: `flutter test test/data/repositories/event_repository_impl_test.dart` passes and review confirms no branch on the flag, cap or annual filter.
- [ ] 1.6 Add cases 13–15: Rome day different from UTC, final microsecond and next midnight, spring/autumn DST, non-Rome local timezone restored after the test. Verification: bounds derived from EventTimePolicy and focused suite PASS; no rounding/synthetic end/Duration(days:1) for bounds.

## 2. Upcoming disjointness

- [ ] 2.1 Add upcoming cases 16–19 and 22 to the repository file: past start today with future end, start == now, now +1 microsecond, future today, soft-delete. Verification: explicit regression for the old lower bound, with a fixed clock.
- [ ] 2.2 Modify `getNextEventIds()` and documentation to use a single snapshot and `greaterThanDate(nowUtc)`, preserving the inclusive end of Rome day +30, start sorting and limit 6. Verification: new strictly future cases pass, no changes to calendar/search/annual queries.
- [ ] 2.3 Adapt the three currently obsolete expectations in `Rome query boundaries` as in design decision 2; reuse upper/cross-year tests and add an actual December clock for future January (cases 20–21), upper +1 microsecond and limit 6. Verification: full repository suite PASS while preserving annual/overlap tests, inclusive upper bound and calendar +30.
- [ ] 2.4 Add a test of empty ongoing/next intersection on the same store, dataset and clock, with both sets non-empty and start/end boundaries. Verification: empty intersection through retrieval, no client filter; a single clock reading per method.
- [ ] 2.5 Repository review gate: compare the contract and delta with `home-ongoing-events`/`event-temporal-integrity`. Verification: repository tests PASS and the diff introduces no ObjectBoxConditions helper, schema, generators, backend, half-open or effectiveEnd.

## 3. EventViewModel

- [ ] 3.1 In `lib/ui/event/view_models/event_view_model.dart`, add read-only `ongoingIds`/`ongoing` state and Command0 `loadOngoingIds`/`loadOngoing` according to decision 3. Verification in `test/ui/event/view_models/event_view_model_test.dart`: IDs success, error without lookup, preservation of last success, empty success clearing state, unmodifiable getters.
- [ ] 3.2 Resolve IDs in order through getById, omit Result.error lookups, build a local entity list and publish it on completion; await the entity command from its corresponding ID command for ongoing and next. Verification: partial lookup, single commit/notifications, order, ID command running until the last entity and next regressions PASS; no ViewModel reclassification/deduplication.
- [ ] 3.3 Add coalescing `refreshHomeDiscovery()` for the two ID commands as in decision 4; await pre-existing ID and entity commands before a new execution. Verification with completers: concurrent requests share completion, return during fetch causes a subsequent pass, refresh overlapping a direct ID/entity command already running does not finish early, ongoing error does not prevent next, no retry without a new request and no remaining one-shot listener.
- [ ] 3.4 Add a dispose flag scoped to new flows, next and constructor loadAll; after await, do not publish or start commands on the disposed VM. Verification: teardown with IDs/entity/yearly pending, no late notification/continuation, one-shot waits removed/completed on dispose, no rewrite of global Command or calendar cache.
- [ ] 3.5 ViewModel gate: run `flutter test test/ui/event/view_models/event_view_model_test.dart` and review command/error states. Verification: Provider/Command/Result preserved, additive shared fakes, no new use case/package/state management.

## 4. Home functional integration

- [ ] 4.1 In the Home Provider in `lib/routing/router.dart`, replace the next-only start with `refreshHomeDiscovery()`, without changing global DI or annual auto-load. Verification in new `test/routing/home_event_discovery_test.dart` with a real router and support from `test/support/events_harness.dart`: initial Home loads ongoing and next once and receives the same route-scoped VM.
- [ ] 4.2 Load `molise-is-async-mounted-context-safety` before modifying Explore State/callbacks; prepare functional consumption of getters/commands without creating a new visual surface yet. Verification: no date filter, deduplication, synthetic end, corrective order or visual choice in the diff.
- [ ] 4.3 Record the UI gate in section 6 as incomplete until the developer provides the design. Verification: no implicit choice of position, grid/cards/count or error/empty presentation in code/artifacts; technical tasks 5 remain executable independently of the gate.

## 5. Refresh and lifecycle

- [ ] 5.1 In `lib/ui/explore/widgets/explore_screen.dart`, register/remove the GoRouter.routerDelegate listener, read top `router.state.matchedLocation`, track false -> true Home and call only VM refresh; handle router/VM replacement, mounted and post-frame. Verification: listener removed on dispose, no duplicated bootstrap or reload on simple rebuild; no dependence on browser URL or ShellRouteVisibility alone.
- [ ] 5.2 Extend `test/routing/home_event_discovery_test.dart`: tab away/back with advanced results/clock, detail go/back, settings push/pop, unchanged URI/rebuild, return during fetch, unmount. Verification: both sets recalculated on retained Home, no lost request or ViewModel publication/notification or new load after dispose, and no forced provider recreation.
- [ ] 5.3 Extend `test/routing/sync_redirect_test.dart` with production Home, Aggiorna menu and pull-to-refresh, updated cache results before return; include non-fatal error and preserve fatal first-sync. Verification: bootstrap or hook reloads both on return, no fetch before commit, pre-existing redirect tests PASS; no change to SyncViewModel/SyncUseCase/redirect or RefreshIndicator duration.
- [ ] 5.4 Refresh gate: run `flutter test test/routing/home_event_discovery_test.dart test/routing/sync_redirect_test.dart test/routing/events_route_test.dart`. Verification: PASS and diff without timer/polling/clock notifier/app-resume framework or general lifecycle refactoring.

## 6. UI design gate and Home surface

- [ ] 6.1 **Developer GATE:** obtain the explicit UI design before the visual surface (position, layout, cards/components, visible count, responsive behavior, spacing/styling/animations, skeletons, empty/error, any CTAs). Verification: decisions delivered and referenced in the handoff without inventing them; if absent, stop only visual tasks and do not declare the feature complete.
- [ ] 6.2 Only after 6.1, implement the distinct “Eventi in corso” section in Home, fed by ongoing and IDs/entities command state; “Prossimi eventi” continues to use next. Verification: review against developer design, no classification/deduplication/corrective reordering in the View, empty success distinct from error without assuming a particular layout.
- [ ] 6.3 Create `test/ui/explore/widgets/explore_screen_test.dart` with shared harnesses/fixtures: title, distinct ongoing/next sources, no duplicate ID for a fixed snapshot, success/empty/error states and consistent navigation if required by the design. Verification: focused widget suite PASS without duplicating the repository temporal matrix.

## 7. Final verification and Definition of Done

- [ ] 7.1 Run `flutter test test/data/repositories/event_repository_impl_test.dart`, `flutter test test/ui/event/view_models/event_view_model_test.dart`, `flutter test test/domain/core/event_time_test.dart` and routing/widget tests modified/new in sections 5–6. Verification: all PASS with a deterministic clock; distinguish any pre-existing failures without claiming a PASS not obtained.
- [ ] 7.2 Run the full `flutter test` suite and `flutter analyze`; format only intentionally modified Dart files. Verification: no new error/warning attributable to the change; record results and concrete limitations, preserving pubspec/lock and other unrelated dirty files.
- [ ] 7.3 Re-examine production and final specs against execution HEAD, check every path and the 1–22/disjointness matrix. Verification: all rows have evidence, guardrails respected and no implicit technical decision left to the View.
- [ ] 7.4 Run `openspec validate add-home-ongoing-events --strict --no-interactive`, `git diff --check`, `git status --short`. Verification: strict and whitespace PASS, status/diff limited to intentional files in addition to preserved unrelated changes; no migration/schema/package/importer/search/calendar changes.
- [ ] 7.5 Compare final evidence with the DoD below and perform independent review of significant changes. Verification: all criteria satisfied, UI gate closed with delivered design, no unresolved material finding; sync/archive OpenSpec only upon a separate finalization request and with the feature actually completed.

## Definition of Done

The complete feature requires all these verified outcomes:

- Ranged event started before today and still active included; future today and ended today excluded from ongoing.
- Start == now and end == now ongoing, without rounding; single-day null-end, null-end yesterday excluded and not extended.
- AllDay single-day/multi-day and explicit same-day final date correct through timestamps, without a special-case flag.
- Soft-deleted excluded; ongoing without an arbitrary cap and with stable order; upcoming only strictly future starts, sorting/limit 6 and Rome +30 window preserved.
- Ongoing/upcoming disjoint at the same snapshot/dataset; UTC/Rome rollover, midnight and DST verified independently of the device zone.
- Repository query ownership; EventViewModel with Command/Result/read-only and existing lookups; no Home deduplication or temporal logic.
- Bootstrap, tab/detail/settings return and sync/pull-to-refresh return reclassify both; closely spaced requests and dispose safe in affected flows.
- “Eventi in corso” surface implemented according to developer design with functional tests; no invented visual decision.
- No new package/framework, timer/polling, migration/schema/DTO, effectiveEnd, half-open, calendar/search/importer changes or broad refactoring.
- Focused/full tests, analyze, strict OpenSpec and diff-check with recorded evidence; unrelated work preserved.

The plan can be READY FOR IMPLEMENTATION, UI DESIGN GATED even with 6.1 open. The feature implementation cannot be marked complete until 6.1–6.3 and final verifications are concluded.
