---
name: molise-is-test-support-reuse
description: >
  Test harnesses, fixtures, fakes, mocks, builders, matchers, pump helpers,
  servers, stores, and setup/teardown reuse for Molise IS. Use BEFORE writing
  or editing any Dart unit test, Flutter widget test, integration test,
  repository test, or other file under test/; requires first loading
  dart-add-unit-test plus flutter-add-widget-test or
  flutter-add-integration-test when applicable, then searching, reusing, or
  carefully extending test/support/ instead of creating duplicate local test
  helpers.
---

# Reuse Test Support Before Writing Tests

Use this skill for every new or modified test in this repository. Its goal is
to keep test code small and consistent by making `test/support/` the single
home for reusable test infrastructure.

## Mandatory companion-skill gate

Before writing or editing test code, load the applicable skills with the
`skill` tool:

1. Load `dart-add-unit-test` for every Dart or Flutter test change.
2. Also load `flutter-add-widget-test` when the test uses `testWidgets`,
   `WidgetTester`, finders, pumping, gestures, or widget rendering.
3. Also load `flutter-add-integration-test` for an integration test or a
   cross-screen user flow.
4. Also load `molise-is-objectbox-test-store` for ObjectBox repository, local
   data-source, persistence, relation, or transaction tests.
5. Load `dart-generate-test-mocks` only when generated Mockito mocks are
   genuinely required and no existing fake or test-support implementation can
   satisfy the test.

**Do not start writing test code until the applicable skills are loaded.**

## Non-negotiable rules

1. Search `test/support/` before defining any test harness, fixture, fake,
   mock, stub, builder, matcher, pump helper, fake server, temporary store, or
   setup/teardown helper.
2. Read the real declaration and current call sites before using or modifying
   a support symbol. Never infer an API from its name.
3. Reuse an existing support helper when it can express the scenario through
   its current parameters, mutable result fields, callbacks, completers,
   counters, or captured arguments.
4. Existing support code is **not immutable**. Extend it carefully when one
   small, coherent capability will serve the new test without changing
   existing behavior.
5. If a new named helper is necessary, put it in an appropriate existing file
   or a focused new `.dart` file under `test/support/`. Do not put a new named
   reusable helper in a local `*_test.dart` file.
6. If another test already contains the needed local helper, do not copy it.
   Promote the helper to `test/support/` and update the original and new users
   when that work is within the implementation scope.
7. Tiny values and one-off closures may remain inline inside a test. Do not
   turn them into local named factories merely to shorten the test body.
8. Existing private, test-specific helpers are not permission to create more.
   Leave unrelated ones alone, but never copy them into another test file.

## Required pre-write workflow

Follow these steps in order. Do not skip directly to creating a helper.

### 1. State the exact need

Identify the behavior, not a guessed implementation name. Examples:

- "a configurable `EventRepository.getById` result";
- "a valid ObjectBox `MediaEntity` with a place relation";
- "a router that exposes branch navigator keys";
- "a pending upload that the test completes later".

### 2. Inventory current support

List `test/support/**/*.dart`, then search it for:

- the production interface or dependency type;
- the method under test;
- relevant nouns such as `Fake`, `Mock`, `Fixture`, `Harness`, `make`,
  `test`, `pump`, `Server`, `Store`, and `Environment`.

Search all of `test/` too. This detects a helper that still lives locally and
must be promoted rather than copied.

### 3. Read declarations and representative users

Before editing, record these facts in the implementation notes or working
context:

```text
Required behavior:
Support files inspected:
Existing candidate and exact API:
Representative current users:
Decision: reuse / extend / add focused support file
```

If any line is unknown, investigate further. Do not invent a constructor
argument, function, fixture field, default value, or lifecycle method.

### 4. Choose the smallest valid action

Use this order of preference:

1. Import and configure an existing support symbol.
2. Compose two existing support symbols directly in the test.
3. Add one backward-compatible capability to the closest support symbol.
4. Add a focused helper to an existing support file.
5. Add a focused new file under `test/support/` when no existing file owns the
   concern.

Never choose "copy a similar local helper".

### 5. Verify affected consumers

- Run the edited test file when support was only reused.
- When shared support changed, find every importer or symbol user and run all
  materially affected tests.
- Format changed Dart files and run the repository-appropriate static
  analysis.
- Run broader tests when the helper is widely shared or its default behavior
  changed.

## Current `test/support/` map

This map is a search index, not a substitute for reading current code. The
repository may evolve after this skill is written.

| File | Reuse before creating |
| --- | --- |
| `fixtures.dart` | `testCity`, `makeEvent`, `makePlace`, ObjectBox `make*Entity` factories, and `newCityRelation` |
| `fake_repositories.dart` | Shared repository fakes, controllable async repositories, `FakeTransactionCoordinator`, and `TestException` |
| `fake_image_picker.dart` | Callback-driven `FakeImagePicker` |
| `fake_cache_manager.dart` | Fail-fast `FakeCacheManager` for image and gallery tests |
| `mock_logger.dart` | Recording `MockLogger` and its event-inspection methods |
| `mock_supabase.dart` | `MockSupabaseEnvironment`, response/error stubs, and `setUpMockSupabase` |
| `mock_objectbox.dart` | Narrow mocked ObjectBox store and box types |
| `objectbox_test_store.dart` | Real temporary `TestObjectBoxEnvironment` and `TestObjectBox` wrapper |
| `fake_cloudinary_server.dart` | Loopback Cloudinary server, request recording, queued responses, errors, and controlled slow uploads |
| `predictive_back.dart` | Android predictive-back start, update, commit, and cancel helpers |
| `route_ownership_fixture.dart` | Production-route ownership fixture with providers and navigator keys |
| `target_topology_fixture.dart` | Shell topology, restoration, navigator ownership, and gallery route fixture |

Read the selected file before use. For example, the two router fixtures and
the real versus mocked ObjectBox helpers are intentionally different and are
not interchangeable.

## Placement rules for new support code

- Put domain model and persistence entity factories in `fixtures.dart` when
  they fit its current dependency boundary.
- Put domain repository fakes and their coherent behavior variants in
  `fake_repositories.dart`.
- Keep plugin-, protocol-, platform-, or package-specific infrastructure in a
  focused support file so broad support files do not acquire unrelated heavy
  dependencies.
- Put reusable widget wrapping or pumping behavior in a focused support file,
  not in the first widget test that needs it.
- Put a matcher in a focused `test/support/` file when it will be reused or
  encodes a stable project invariant.
- Do not create a generic dumping ground such as `test_utils.dart`.
- Import the narrow support file directly; do not create a barrel solely to
  save import lines.

## Editing shared support safely

Before changing an existing shared helper:

1. Read its complete implementation.
2. Find every constructor call, field mutation, method call, and assertion that
   depends on it.
3. Preserve existing defaults and success/error semantics unless the task
   explicitly requires a behavior change.
4. Prefer additive optional parameters, callbacks, result fields, or methods
   over breaking constructor or public API changes.
5. Add counters or captured arguments only when a test actually asserts on
   them. Do not add speculative instrumentation.
6. Preserve fail-fast behavior for unsupported operations. Do not replace an
   intentional error with silent success merely to make a new test pass.
7. Preserve test isolation. Do not add mutable global state or share a fake
   instance across unrelated tests.
8. Preserve lifecycle ownership. Register teardown for stores, servers,
   routers, cache managers, controllers, streams, and other disposable
   resources.
9. Run existing consumer tests after the edit, not only the newly added test.

## Layer and behavior constraints

- Use `testCity`, `makeEvent`, and `makePlace` for generic valid domain/UI
  models. Override fields explicitly when those fields are part of the
  assertion.
- Use `makeCityEntity`, `makeEventEntity`, `makePlaceEntity`, and
  `makeMediaEntity` for data-layer/ObjectBox entities. Do not replace them with
  domain model fixtures.
- Use explicit `Result.success(...)` and `Result.error(...)` configuration.
  Do not add convenience wrappers that hide which result a fake returns.
- Configure ID-based repository methods with ID-keyed results. The key must
  equal the ID passed by the code under test.
- Use controllable repositories, callbacks, or completers already in support
  for loading, race, cancellation, and out-of-order completion tests.
- Use a real temporary ObjectBox store when persistence semantics matter and
  mocked boxes only for a narrow interaction boundary.
- Use `MockLogger` as a recording fake through its inspection methods; do not
  wrap it in another mocking layer.
- Use route fixtures according to their documented ownership/topology scope;
  do not reconstruct a partial app router locally.
- Keep production network, filesystem, plugin, and database behavior out of
  unit/widget tests unless the existing support fixture intentionally provides
  a local integration boundary.

## DO

- **DO** load `dart-add-unit-test` and every applicable Flutter test skill
  before writing test code.
- **DO** search and read `test/support/` before adding any helper.
- **DO** import and configure existing fakes and fixtures instead of
  reimplementing their interfaces.
- **DO** extend shared support additively when a generally useful capability is
  missing.
- **DO** place every necessary new named harness, fixture, fake, mock, builder,
  matcher, pump helper, server, store, or setup helper under `test/support/`.
- **DO** promote rather than copy a local helper when a second test needs it.
- **DO** keep setup explicit enough that the behavior under test remains clear.
- **DO** inspect all users and run affected tests when shared support changes.
- **DO** use deterministic fixture values and explicit teardown.

## DON'T

- **DON'T** add `_FakeX`, `_MockX`, `_TestHarness`, `_Fixture`, `_makeX`,
  `_buildX`, `_pumpX`, or another `_TestException` to a local test file.
- **DON'T** copy/paste a helper from another `*_test.dart` file.
- **DON'T** hallucinate that a support class has a constructor parameter,
  method, counter, or callback without reading its current declaration.
- **DON'T** trust snippets in old plans over current repository code.
- **DON'T** treat existing support as immutable and work around it with a
  duplicate local implementation.
- **DON'T** change shared defaults casually or weaken intentional failure
  behavior.
- **DON'T** add speculative counters, callbacks, generalized abstractions, or
  package dependencies for possible future tests.
- **DON'T** mix domain fixtures, persistence entities, data-source doubles,
  repository fakes, and UI harnesses merely because their names are similar.
- **DON'T** create a broad utility file that hides unrelated dependencies and
  responsibilities.
- **DON'T** perform unrelated test deduplication during a narrowly scoped task;
  reuse support and keep the requested diff focused.

## Example: reuse instead of duplicate

Bad:

```dart
final class _FakeEventRepository extends EventRepository {
  // Another partial copy of the repository interface.
}

Event _makeEvent() => Event(/* repeated defaults */);
```

Good:

```dart
import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';

final event = makeEvent(remoteId: 42);
final repository = FakeEventRepository(
  getByIdResults: {42: Result.success(event)},
);
```

Adapt the relative import depth and read the current signatures before using
this pattern.

## Historical context

Read these plans when investigating why support exists or when considering a
deduplication change:

- `docs/plans/consolidate-test-fake-repositories.md`
- `docs/plans/test-deduplication-opportunities.md`

They document previous consolidation decisions and useful anti-duplication
examples. They are historical guidance, not an API reference. Current
`test/support/` code and current usages are the source of truth.
