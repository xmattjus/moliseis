## 1. Baseline and contract audit

- [x] 1.1 Record execution HEAD, `git status --short` and relevant pre-existing dirty files before editing. Compare production paths with this design and document material drift rather than overwriting unrelated work. Verification: execution baseline and dirty-file evidence are recorded.
- [x] 1.2 Load the repository's relevant Flutter unit-test, test-support reuse, ObjectBox repository and code-review skills before implementation. Verification: applicable instructions have been read before affected edits.
- [x] 1.3 Re-run code search for all targeted ID-first APIs/state: `getLatestPlaceIds`, `latestIds`, `getIdsByCoordinates`, `ExploreViewModel.loadNear` / `.near`, `getNextEventIds`, `nextIds`, `getPlaceIdsByQuery`, `getEventIdsByQuery`, `loadRelatedResultsIds`, `loadRelatedResults`, `getRelatedResults`. Verification: distinguish active runtime consumers from tests/comments/OpenSpec documentation.
- [x] 1.4 Capture focused baseline behavior/tests for latest places, upcoming events and search before contract changes. Verification: membership, ordering, limits, soft-delete behavior, empty/error behavior and current UI Command ownership are explicitly understood.
- [x] 1.5 Reconfirm backend/DTO/ObjectBox boundaries. Verification: published places/events are already synchronized as complete local entities and no backend/schema/generated-model change is required.

## 2. Latest places and Explore simplification

- [x] 2.1 Add/adapt repository tests first for direct latest-place retrieval: non-deleted only, `createdAt` descending, maximum six, domain-model mapping and successful empty result. Verification: focused repository regressions cover each preserved contract.
- [x] 2.2 Replace `PlaceRepository.getLatestPlaceIds()` with direct model retrieval (`getLatest()` preferred unless execution-head naming evidence justifies another clear name). Update `PlaceRepositoryImpl` to use the existing predicate/order/limit and `findAsync()`/mapping with correct query cleanup/logging. Verification: direct repository tests pass and no per-item lookup is used.
- [x] 2.3 Refactor `ExploreViewModel` latest loading so `loadLatest` invokes the repository directly, starts directly on construction and publishes `_latest` in one final state update. Verification: constructor bootstrap and successful state publication are covered by focused tests.
- [x] 2.4 Remove `load`, `_load`, `_latestIds` and `latestIds` if no execution-head consumer remains. Update Home route/fixtures/tests accordingly. Verification: targeted production/test search finds no stale references and affected fixtures compile.
- [x] 2.5 Verify repository failure is exposed by `loadLatest.error` and retry re-executes repository discovery; successful empty retrieval is distinct from failure. Verification: focused error/retry/empty tests pass.
- [x] 2.6 Audit `ExploreViewModel.loadNear`/`near` and `getIdsByCoordinates`. If runtime use remains absent, remove the dead ViewModel flow and ID repository API plus fake/test plumbing. Do not replace it with the semantically different active `getByCoordinates()` merely to retain API shape. Verification: recorded runtime search supports deletion and active coordinate query diff is unchanged.
- [x] 2.7 If the preceding work leaves no `ExploreViewModel` use of `ExploreUseCase`, remove that constructor dependency and update the Home provider. Verification: `ExploreUseCase` itself remains for its other consumers and affected construction compiles.
- [x] 2.8 Run focused place-repository and Explore ViewModel/widget tests. Review diff for no change to active Post/Map coordinate retrieval. Verification: focused suites pass and nearby contract is preserved.

## 3. Upcoming events direct retrieval

- [x] 3.1 Add/adapt repository tests first proving direct upcoming `Event` retrieval preserves the execution-head temporal predicate, soft-delete filter, start ordering and limit six. Reuse existing temporal fixtures rather than duplicating the full temporal matrix. Verification: regressions cover the production predicate, not the future ongoing-plan predicate.
- [x] 3.2 Replace `EventRepository.getNextEventIds()` with direct `getNextEvents()` returning `Result<List<Event>>`, without introducing a snapshot parameter or strictly-future behavior in this change. Verification: interface diff has direct return type and unchanged temporal inputs.
- [x] 3.3 Update `EventRepositoryImpl` to retrieve/map matching entities directly using the unchanged production query conditions/order/limit and standard logging/finally behavior. Verification: direct repository tests pass and query cleanup remains correct.
- [x] 3.4 Collapse `EventViewModel` next loading into `loadNext -> repository -> _next`; remove `_nextIds`, `nextIds`, `loadNextIds` and `_loadNextIds`. Verification: ViewModel tests prove direct discovery and atomic state publication.
- [x] 3.5 Update Home route bootstrap to execute `loadNext` directly. Verification: Home/routing fixtures exercise the direct bootstrap and compile.
- [x] 3.6 Add/adapt ViewModel/widget tests proving success publishes repository order; successful empty clears prior next state where appropriate; discovery error appears on `loadNext`; retry performs discovery again; there is no per-ID `getById` resolution for upcoming list loading. Verification: all focused cases pass.
- [x] 3.7 Run focused event repository/ViewModel/Home tests and compare results against baseline. Verification: suites pass and no temporal semantics from `add-home-ongoing-events` have leaked into production early.

## 4. Active search direct retrieval

- [x] 4.1 Before implementation, extend repository regressions around current effective search behavior: place name/category/associated city; deduplication across multiple matching paths; soft-deleted place excluded on every path; event name/category/city; canonical current-year overlap/soft-delete behavior; result ordering; place/event numeric ID collision does not cross-deduplicate. Include a focused sequential short-circuit regression: place phase returns `Result.error(placeError)`, event-phase query execution count remains zero, overall operation returns the same error. Where an existing seam supports deterministic delay, also prove no event discovery starts while the place phase is pending. Verification: tests cover every listed contract; reuse existing support or a narrow test seam without restoring public ID APIs, and source inspection rules out `Future.wait`/parallel phase execution over `_cityQuery`.
- [x] 4.2 Replace public `getPlaceIdsByQuery` and `getEventIdsByQuery` with one `SearchRepository.getResultsByQuery(String)` returning `Result<List<ContentBase>>`. Verification: domain contract exposes final mixed models and active consumers compile after adaptation.
- [x] 4.3 Refactor `SearchRepositoryImpl` to materialize direct domain results while preserving existing query predicates and aggregation order. Move the effective place soft-delete filtering supplied by the old downstream `getById` into the repository's place search paths. Await successful place discovery before starting event discovery, returning the first phase error unchanged; do not parallelize phases over shared parameterized queries. Verification: name/category/city soft-delete and ordering regressions pass.
- [x] 4.4 Preserve one current-time capture for the event part of a search as appropriate to the existing annual-visibility contract; do not redesign temporal search semantics. Verification: deterministic annual visibility tests and query inspection confirm unchanged behavior.
- [x] 4.5 Refactor `SearchViewModel.loadResults` and `loadSuggestions` to call the direct repository API and perform a single final collection replacement. Preserve query-length validation, current Command implementation and the `_disposed` guard immediately after awaiting direct retrieval, before state replacement or ViewModel notification. Verification: valid/short query, pending, successful replacement and post-dispose direct completion tests pass for both results and suggestions.
- [x] 4.6 Remove `EventRepository` and `ExploreGetByIdUseCase` from `SearchViewModel` construction if execution-head search confirms they have no remaining use; update `router.dart`, `core_routes.dart`, widget fixtures and tests. Verification: no remaining dependency use and affected constructors compile.
- [x] 4.7 Add ViewModel tests proving repository errors surface through the executed search/suggestion Command and no per-item entity-resolution dependency remains. Replace obsolete per-ID skip-failure tests with recoverable direct query/materialization error regressions that publish no partial results. Replace the pending-place-ID disposal regression for both `loadResults` and `loadSuggestions`: pending `getResultsByQuery`, dispose, complete successful non-empty results, then assert no `_results`/`_suggestions` assignment, no ViewModel `notifyListeners()` and no late mutation; Command settlement remains permitted. Do not assert repository-phase cancellation on disposal. Verification: focused error and lifecycle regressions pass, including unchanged visible collection contents, no late state assignment and no late ViewModel notification; do not compare getter wrapper identity because each getter creates a new `UnmodifiableListView`.
- [x] 4.8 Run focused `search_repository_impl_test.dart`, SearchViewModel and search widget/routing suites. Verification: all focused suites pass.

## 5. Dormant related-search cleanup

- [x] 5.1 Reconfirm there is no non-commented runtime consumer of related search at execution HEAD. Verification: record consumer search distinguishing active code from TODO/comments/tests.
- [x] 5.2 If still dormant, delete related-search Commands/state/getters from `SearchViewModel`. Verification: no active consumer or stale ViewModel members remain.
- [x] 5.3 Remove `SearchRepository.getRelatedResults` and implementation-only related state/helpers (`_lastPlaceResultIds`, `_categorySearched`, `_getRelatedResults`) that no active search behavior needs after the direct-results refactor. Verification: active search tests pass without this machinery.
- [x] 5.4 Remove related fake/completer/counter tests that test only the dormant feature. Verification: no orphaned support fields remain and active tests still compile.
- [x] 5.5 Delete the fully commented/TODO related-results widget and stale commented imports/invocations if unchanged. Verification: repository search shows no stale widget integration.
- [x] 5.6 If a real runtime consumer is discovered instead, do not delete; document the delta and convert that path to direct model retrieval without designing new related-search UX. Verification: not applicable; execution audit found no runtime consumer and the deletion branch in 5.2–5.5 was applied.

## 6. Dead API and documentation cleanup

- [x] 6.1 Search again for the removed ID-first names and remove stale production/test references. Verification: remaining ID-returning repository methods have genuine identity consumers such as favourites.
- [x] 6.2 Update `test/support/fake_repositories.dart` additively/cleanly for the new direct return types; remove obsolete result fields/counters only when no test consumer remains. Verification: support usage search and affected tests pass.
- [x] 6.3 Update route/test-local SearchRepository implementations to satisfy the new interface without creating additional fake repository classes. Verification: routing/test-local implementations compile and existing support is reused.
- [x] 6.4 Audit `.agents/skills/molise-is-result-pattern/SKILL.md` and other project guidance for examples that teach the removed IDs→N `getById` pattern. Replace/remove stale examples while preserving the Result-pattern guidance itself. Verification: examples agree with new contracts and retain Result guidance.
- [x] 6.5 Search comments/OpenSpec/backlog references for claims that exact ID counts drive current shimmer UI. Remove/update only documentation made false by this optimization. Verification: no stale current-contract claims remain; historical context is distinguished.

## 7. Functional and architectural regression gate

- [x] 7.1 Verify `SkeletonContentSliverGrid` and relevant loading UI do not depend on result-ID counts and require no design change. Verification: UI inspection and relevant widget tests agree.
- [x] 7.2 Verify targeted active ViewModels no longer contain a discovery-ID state used solely to resolve the same entities. Verification: targeted source search has no such surviving stage.
- [x] 7.3 Verify targeted repository discovery flows do not perform caller-side per-item `getById` resolution after list discovery. Verification: execution-path review finds direct model retrieval only.
- [x] 7.4 Verify list state publication occurs only after the direct repository result is available; no visible incremental append loop has been introduced. Verification: pending/success tests and source inspection agree.
- [x] 7.5 Verify the current Command implementation and concurrency/lifecycle strategy are unchanged; no `command_it`, new package or general hardening is present. Verification: scoped diff leaves `lib/utils/command.dart` and dependencies unchanged by this task, and preserves existing guards.
- [x] 7.6 Run all focused repository/ViewModel/widget/routing tests touched by sections 2–6. Verification: focused suites pass.
- [x] 7.7 Run full `flutter test`. Verification: full suite passes; record actual command output.
- [x] 7.8 Run `flutter analyze`, comparing any pre-existing diagnostics and requiring no new change-attributable errors/warnings. Verification: record diagnostics and comparison evidence.
- [x] 7.9 Run formatting only on intentionally modified Dart files and `git diff --check`. Verification: intended files are formatted and whitespace check passes.

## 8. Reconcile add-home-ongoing-events

- [x] 8.1 Re-audit the open change against the optimized production HEAD before editing its planning artifacts. Verification: baseline and any drift are recorded after optimization regression gates pass.
- [x] 8.2 Update its proposal from `getOngoingEventIds`/`getNextEventIds` to direct `getOngoingEvents`/`getNextEvents`. Verification: proposal describes final Event collections rather than an ID stage.
- [x] 8.3 Update its design so repository queries return mapped `Event` collections directly; preserve all settled temporal predicates, ordering, limits and shared-snapshot ownership. Verification: design matches optimized production baseline and settled temporal delta.
- [x] 8.4 Replace planned `ongoingIds`/`nextIds` plus resolver Commands with direct `loadOngoing`/`loadNext` `Command1<void, DateTime>` state flows. Verification: design/tasks contain no intermediate ID state or resolver Command.
- [x] 8.5 Simplify `refreshHomeDiscovery()` planning so each pass captures one UTC snapshot and awaits the two direct retrieval Commands. Preserve coalescing/pending-return semantics exactly; do not implement a new generic orchestrator. Verification: pass ownership, coalescing and pending-return requirements remain consistent across artifacts.
- [x] 8.6 Replace delayed-per-item-entity-resolution regressions with delayed-first-discovery-query regressions that still prove both calls receive the same snapshot across a clock boundary/Rome midnight. Verification: planned tests preserve both temporal proofs without item lookup stages.
- [x] 8.7 Update `home-ongoing-events` spec language from ID sets/per-ID partial resolution to direct ordered entity collections and direct repository error/empty semantics. Remove obsolete partial lookup scenarios. Verification: direct failure retains prior successful state, successful empty clears it, and no obsolete partial scenario remains.
- [x] 8.8 Re-check the `event-temporal-integrity` delta for terminology consistency without changing its settled temporal requirements. Verification: shared snapshot, strictly-future start and inclusive upper bound remain unchanged.
- [x] 8.9 Run `openspec validate add-home-ongoing-events --strict --no-interactive`. Verification: PASS and no ID-first architecture remains in that future plan.

## 9. OpenSpec final verification

- [x] 9.1 Run `openspec validate optimize-local-content-retrieval --strict --no-interactive`. Verification: PASS.
- [x] 9.2 Perform an adversarial review of the final production diff against `proposal.md`, `design.md` and the delta spec. Specifically search for hidden N+1 reintroduction, filtering drift, ordering drift and accidental concurrency changes. Verification: findings are recorded and material issues resolved.
- [x] 9.3 Re-run repository-wide search for all removed API/state names and explain any intentional survivor. Verification: no unexplained active or future-plan ID-first survivor remains.
- [x] 9.4 Run `git diff --check` and `git status --short`; ensure unrelated pre-existing work is preserved. Verification: whitespace check passes and final status preserves baseline dirty files.
- [x] 9.5 Record focused/full test and analyzer evidence. Do not claim performance measurements that were not executed. Verification: reported results are traceable to actual runs.
- [x] 9.6 Mark the change ready to archive only when production optimization is complete, `add-home-ongoing-events` has been reconciled and both OpenSpec strict validations pass. Verification: Definition of Done below is satisfied with execution evidence.

## Definition of Done

The change is complete only when all of the following are true:

- Latest-place Home loading uses one direct repository model query and one UI-facing Command.
- Upcoming-event Home loading uses one direct repository model query and one UI-facing Command under the pre-existing temporal semantics.
- Active search returns final mixed domain models from `SearchRepository` without ViewModel per-item resolution.
- Recoverable direct query/materialization failure fails the logical operation without partial publication; obsolete per-item missing-lookup omission tests are replaced.
- Effective search filtering, including place soft deletion previously provided by `getById`, is preserved.
- Active result ordering, deduplication and limits remain unchanged.
- Targeted intermediate ID state/Commands/APIs have no remaining active consumer and are removed.
- Dead Explore-near and related-search ID flows are removed if the execution-head audit still proves them dormant.
- Genuine identity-oriented repository APIs remain untouched.
- Successful collections are committed atomically after retrieval rather than incrementally across N awaits.
- Latest/upcoming discovery errors are exposed by the same Commands the UI observes and retries repeat actual discovery.
- For this change, current Command implementation and lifecycle/concurrency semantics remain unchanged. Search phases retain sequential place-first short-circuit behavior and direct completion after disposal cannot publish ViewModel state or notify listeners. These change-scoped constraints do not freeze future Command implementations in the canonical capability.
- No backend/schema/ObjectBox-model/package changes exist attributable to this change.
- Focused tests, full Flutter suite and analyzer meet the gates.
- `add-home-ongoing-events` is rewritten against direct event retrieval while preserving its shared-snapshot/temporal decisions.
- Both OpenSpec changes validate strictly.
