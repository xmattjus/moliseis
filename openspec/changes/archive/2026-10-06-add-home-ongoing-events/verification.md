# Feature completion verification

Completion review: **6 October 2026**.

- Original execution base: `a35487852f9e45b9c7d4ff4541e4a5f04b329b9a` (`main`).
- Published implementation commit: `3494922d47b877dc016eb6feb64f22e647696d6d` (`main`).
- Verification scope: the final checks below ran on the integrated local working
  tree, including intentional changes not yet pushed, notably `go_router 18.0.2`
  and the related UI redesign and test updates. These results do not claim that
  the published implementation commit was verified in isolation. The local
  changes are preserved work, not failures or blockers of this feature.

Status: **IMPLEMENTATION COMPLETE — 32/32 tasks verified**.
The developer supplied the ongoing-section UI in `ExploreScreen` and requested
review and completion of the plan. The UI gate is closed. The implementation
was subsequently committed and published as recorded above. Canonical spec
synchronization and archival are covered by the separate finalization below.

## Supplied UI and review

The delivered design is recorded in `design.md`. Ongoing appears after the
submission CTA and before upcoming. The existing content grid owns responsive
rendering and empty presentation; the developer's section code owns title,
padding, skeleton and error presentation. The View consumes the repository's
ordered ongoing collection and Command state without dates, synthetic ends,
filters, sorting, deduplication or a new limit. Both retry paths enter
`refreshHomeDiscovery()` and ongoing cards use the existing Home event-detail
route. Independent code review found **no material correctness issue**.

An inherited behavior was observed: the existing skeleton delegate has no
child count, so downstream sections are not built in the viewport while the
first temporal skeleton is pending. The widget test checks ongoing loading
first, then upcoming loading after ongoing completes. The developer's selected
component behavior was preserved; no visual redesign was introduced.

## Completion edits and preserved work

The UI completion pass changed only the Explore widget tests and the change's
proposal/design/tasks/verification documents. The developer's `ExploreScreen`
implementation was preserved byte-for-byte, as were the dependencies and all
other captured working-tree files. `go_router` remains **18.0.2**.

Seven widget tests now cover titles, independent collections derived from a
fixed supplied snapshot, no duplicate event identity, empty success, both error
and coordinated retry paths, sequential loading states, and an actual ongoing
card tap through the production detail router. Existing support was reused;
no additional fake or harness was created.

## Final verification

| Command | Result |
| --- | --- |
| `flutter test test/ui/explore/widgets/explore_screen_test.dart` | PASS: 7 tests |
| `flutter test test/data/repositories/event_repository_impl_test.dart test/ui/event/view_models/event_view_model_test.dart test/domain/core/event_time_test.dart test/routing/home_event_discovery_test.dart test/routing/sync_redirect_test.dart test/routing/events_route_test.dart` | PASS: 146 tests |
| `flutter test` | PASS: 1,849 passed, 3 skipped, no failures |
| `flutter analyze` | Exit 1: 170 existing diagnostics, 4 warnings and 166 infos; no new feature diagnostics |
| Focused Explore widget-test Dart analysis | PASS: no issues found |
| `openspec validate add-home-ongoing-events --strict --no-interactive` | PASS |
| `git diff --check` | PASS |
| `git status --short` | Executed; existing staged/unstaged edits preserved |

The first combined test invocation encountered a shared native-assets build
conflict while Flutter test commands overlapped. Serial re-execution passed
without any SDK, dependency or native-asset configuration change.

The six map-test failures documented in the earlier technical pass no longer
occur: the developer's updated map tests were already present at the beginning
of this completion pass and were preserved. These tests were not changed by
the completion work. Analysis retains the earlier 170 existing diagnostics;
the full analyzer result is not represented as a clean PASS.

The complete Definition of Done has been reviewed. Tasks 6.1–6.3 and 7.5 are
now checked, with all prior technical contracts still covered. No technical
or UI-design question remains open. The separate finalization request authorizes
canonical synchronization and archival after strict validation.

## Previous technical-pass evidence (historical)

The following records the earlier UI-gated state and its then-current failures;
it is superseded by the completion status and results above.

Original technical-pass execution base: `a35487852f9e45b9c7d4ff4541e4a5f04b329b9a` (`main`).

Status: **READY / TECHNICAL IMPLEMENTATION COMPLETE, UI DESIGN GATED**.
This is not completion or archival of the whole feature.

### Scope and working tree

The execution audit matched the current direct-retrieval code and the updated
planning artifacts. No material plan correction was needed. Initial staged
remediation and unstaged planning refinements were preserved. The existing
`openspec/changes/add-home-ongoing-events.zip` was left untouched.

All thirteen unrelated dirty paths captured before execution were verified
byte-for-byte at completion (including the intentional deletion). These cover
submission fields, theme files, map/post components, weather, `pubspec.yaml`
and `pubspec.lock`. Local `go_router` remains **18.0.2**. No dependency,
backend, schema, generator, importer, search or calendar change was made by
this implementation. At that historical technical pass, staging, commit, push,
spec synchronization and archival had not yet been performed. This is not the
current publication status: the implementation was later committed and pushed
as `3494922d47b877dc016eb6feb64f22e647696d6d`.

Production changes:

- `lib/domain/repositories/event_repository.dart`
- `lib/data/repositories/event_repository_impl.dart`
- `lib/ui/event/view_models/event_view_model.dart`
- `lib/routing/router.dart`
- `lib/ui/explore/widgets/explore_screen.dart`

Tests/support changed or added:

- `test/data/repositories/event_repository_impl_test.dart`
- `test/ui/event/view_models/event_view_model_test.dart`
- `test/routing/home_event_discovery_test.dart` (new)
- `test/routing/sync_redirect_test.dart`
- `test/ui/explore/widgets/explore_screen_test.dart`
- `test/support/fake_repositories.dart`
- `test/support/sync_harness.dart` (existing sync support promoted for reuse)

### Contract verification

Repository matrix 1–22 and additional contracts are covered with real ObjectBox
stores: inclusive start/end and zero-length ranges, Rome single-day null ends,
all-day single/multiple/explicit same-day bounds, previous-year intervals,
soft deletion, device-zone independence, final microsecond and midnight,
spring/autumn DST, civil +30 upper bound, ascending order/identity tie-break,
uncapped ongoing, six upcoming and empty intersection for one snapshot.
Both queries reject any attempt to read the repository clock in these tests.

ViewModel tests derive fake answers from received snapshots. The delayed first
query crosses the 11:00 start boundary and Rome midnight; one clock read governs
both classifications, and subsequent/coalesced passes acquire new snapshots.
Tests also verify direct read-only atomic publication, pending/error retention,
empty success, independent command errors, already-running command waits,
listener cleanup and discovery/annual disposal guards.

Production-router tests prove initial bootstrap without duplicate loading,
retained owners across tabs/detail/search/category/settings, unchanged URI and
rebuild, overlapping return, pending unmount and no SearchAnchor popup refresh.
Sync tests exercise the actual refresh menu and Android pull gesture, confirm
cache commit before Home reclassification, and retain non-fatal/fatal sync
behavior. Existing upcoming retry calls the coordinator; no View constructs a
snapshot, resolves discovery IDs or corrects temporal membership.

### Commands and results

| Command | Result |
| --- | --- |
| `flutter test test/data/repositories/event_repository_impl_test.dart` | PASS: 74 tests |
| `flutter test test/ui/event/view_models/event_view_model_test.dart` | PASS: 26 tests |
| `flutter test test/domain/core/event_time_test.dart` | PASS: 14 tests |
| `flutter test test/routing/home_event_discovery_test.dart test/routing/sync_redirect_test.dart test/routing/events_route_test.dart` | PASS: 32 tests |
| Above routing gate plus `test/ui/explore/widgets/explore_screen_test.dart` | PASS: 33 tests, including actual pull gesture |
| `flutter test` | Exit 1: 1,837 passed, 3 skipped, 6 pre-existing failures below |
| `flutter analyze` | Exit 1: 170 pre-existing diagnostics (4 warnings, 166 infos); no new diagnostics |
| `openspec validate add-home-ongoing-events --strict --no-interactive` | PASS |
| `git diff --check` | PASS |
| `git status --short` | Executed; only intended change files added to the preserved initial dirty state |

Only intentionally changed Dart files were formatted. Focused ViewModel and
routing analyses have no issues. The repository interface retains its existing
positional-boolean lint on `setFavouriteEvent`; unrelated shared-fake infos were
preserved.

#### Pre-existing full-suite failures

All six failures are in `test/routing/route_ownership_test.dart`:

- `Apri mappa preserves /home/posts/1?type=event in its branch`
- `Apri mappa preserves /favourites/posts/1?type=event in its branch`
- `Apri mappa preserves /events/posts/1?type=event in its branch`
- `Apri mappa preserves /home/category/nature/posts/1?type=event in its branch`
- `Apri mappa preserves /home/search_results/posts/1?q=molise&type=event in its branch`
- `map predictive back preserves the hidden post route`

Each fails to find the existing `Apri mappa` action. They were reproduced by
running that file in a temporary copy of execution HEAD plus the captured
unrelated local changes, without this feature: **13 passed, 6 failed**.
No map/post code or those tests were modified to conceal these failures.

The same baseline was analyzed using the same package configuration. Comparing
normalized severity, diagnostic code, relative file and message multisets
produced exactly the same **170 diagnostics**, with no added keys.

### Adversarial review and remaining gate

Independent review found one ordering defect: unsigned start ordering placed
active pre-1970 intervals after recent ones. A real-store regression failed
before the fix and passes after ongoing start ordering was changed to signed
chronological order. Identity tie-break and existing upcoming ordering remain
unchanged. This implements the plan's start-ascending contract, without a plan
rewrite or new abstraction.

The existing unknown-route test also caught an empty GoRouter match-list state;
the Home visibility hook now checks for matches before reading the top state.
Final review has no unresolved material technical finding.

Tasks **1–5 and 7.1–7.4** are complete: **28/32**. Tasks **6.1–6.3** remain
open because no developer visual design was supplied. Task **7.5** remains open
because its whole-feature Definition of Done requires the approved visual
surface; its independent technical review has been performed. No new ongoing
visual surface, placement, card, count, skeleton, empty/error UI or CTA was
invented. At that stage, archival was gated on visual and whole-feature
verification. Those gates were subsequently satisfied as documented above.


## OpenSpec finalization — 6 October 2026

The final delta review found no material contradiction. All three capabilities
were synchronized into canonical specifications: `home-ongoing-events`,
`event-temporal-integrity` and `local-content-retrieval`. Existing unrelated
requirements and all retained scenarios were preserved. The developer UI gate
remains satisfied; the historical UI-gated status above is not the current state.

`openspec validate add-home-ongoing-events --strict --no-interactive` passed
before archival. `openspec validate --specs` passed for all 13 canonical specs.
The archive location is
`openspec/changes/archive/2026-10-06-add-home-ongoing-events/`.

This finalization changes only OpenSpec documents. No Flutter checks were
repeated, and no new Flutter verification result is claimed. All technical
results above retain their original integrated-local-working-tree scope.

Post-archive verification confirmed that each canonical requirement matches its
archived delta, unrelated canonical requirements are unchanged, and no active
copy remains. `git diff --check` passed and `git status --short` was executed.
All captured production, test, dependency and unrelated OpenSpec files were
verified unchanged by this finalization. No residual material finding emerged.
