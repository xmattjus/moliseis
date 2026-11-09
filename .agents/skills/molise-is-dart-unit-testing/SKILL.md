---
name: molise-is-dart-unit-testing
description: >-
  Use before creating, changing, or reviewing Dart and Flutter unit tests,
  ViewModel and repository tests, and regression tests in Molise Is.
  Follow existing test conventions, use shared fakes first, and use Mocktail
  only when a mock is genuinely needed.
---

# Dart and Flutter Unit Testing — Molise Is

## Scope and precedence

This project-specific skill replaces the generic `dart-add-unit-test`
workflow. Apply it to test creation, changes, and review under `test/`.
Follow `AGENTS.md` and any approved plan or test contract. For new or
modified test code, also apply
`.agents/skills/molise-is-test-support-reuse/SKILL.md`, which owns fixture,
fake, harness, helper placement and reuse rules. Its prescribed companion
skills for widget, integration and ObjectBox tests remain applicable.

The goal is small, deterministic tests of observable behavior. Do not
introduce additional frameworks, mocking packages, generated mocks or
test infrastructure merely because a generic example suggests doing so.

## Structuring tests

- Put unit and widget tests under `test/`, usually mirroring the related
  source path; use `*_test.dart` filenames. Preserve the feature's current
  directory conventions when these differ.
- Use `package:flutter_test/flutter_test.dart` in this Flutter project for
  `test`, `group`, `expect`, `setUp`, `tearDown` and `testWidgets` where needed.
  `package:test/test.dart` is appropriate for independent pure Dart packages,
  but do not add a second testing dependency to Molise Is for this reason.
- Group cases by behavior and name each test for the expected outcome.
  Prefer meaningful scenarios and boundary cases over mirroring methods
  mechanically.
- Keep each test independent. Reinitialize mutable fixtures in `setUp`,
  release owned resources in `tearDown` or `addTearDown`, and avoid
  global mutable state that leaks between cases.

## Writing tests

- Arrange the required state, execute one observable behavior, then
  assert the meaningful result and side effects.
- Cover success, expected failure, state transitions and edge cases
  proportionately to the change. For identity-sensitive async operations,
  test stale completion, replacement or disposal when the behavior is affected.
- Use `async` / `await` for asynchronous assertions; never leave a Future
  unobserved simply to make the test pass. Use controllable `Completer`s
  or shared helpers for deterministic race tests rather than arbitrary sleeps.
- Assert public contracts, `Result.success` / `Result.error` outcomes and
  visible state; do not overfit to private implementation details or
  verify every harmless collaborator call.
- Preserve existing `expect` / matcher conventions. Do not migrate tests to
  another assertion library as part of unrelated work.

## Dependency isolation and Mocktail

**First inspect `test/support/` and existing consumer tests.** Prefer a real
lightweight value, an existing fixture, a small deterministic fake, or an
existing configurable test double. Extend shared support when necessary
and in scope. Use a mock only when interaction verification or a complex
dependency boundary genuinely warrants it.

When a mock is necessary:

- Use the project's existing `mocktail` dependency (currently `^1.0.5`).
  Do not add Mockito, generated `*.mocks.dart` files or `build_runner`
  mocking steps.
- For a missing reusable mock, declare a focused `Mock implements Interface`
  in the appropriate `test/support/` file, following the project's
  test-support placement conventions.
- Stub with `when(() => mock.method(...)).thenReturn(value)` or
  `thenAnswer((_) async => value)` for asynchronous behavior; verify with
  `verify(() => mock.method(...)).called(n)`. Mocktail requires closures.
- Stub required non-nullable-return methods before invoking the subject:
  unconfigured Mocktail calls return `null` and can fail at runtime.
- Register a fallback with `registerFallbackValue` (usually in
  `setUpAll`) when `any()` / `captureAny()` matches a non-nullable argument
  type without a compatible pre-registered value. This includes standard
  library types such as `Uri` and custom types; common primitive fallback
  values are already provided.
- Prefer behavior assertions to brittle invocation counts. Avoid broad
  matcher configuration that accepts impossible calls.

Illustrative Mocktail syntax, **after choosing a suitable existing or
new shared test double**:

```dart
// A reusable test/support mock for a real interface, if needed:
// class MockGateway extends Mock implements Gateway {}

when(() => gateway.read()).thenAnswer((_) async => expected);

final actual = await subject.read();

expect(actual, expected);
verify(() => gateway.read()).called(1);
```

In actual tests, use the real production interface and the real APIs of
the shared test double; the snippet is not a substitute for inspecting them.

## Executing and verifying

1. Inspect the implementation and affected tests; look up relevant
   shared helpers before creating a new double.
2. Add or update the smallest tests needed for the behavioral change.
3. Run the targeted tests with `flutter test test/<path>_test.dart`.
   For widget tests use `flutter-add-widget-test` guidance when needed;
   for integration flows use `flutter-add-integration-test`.
4. Run formatter and the relevant analyzer on changed Dart code, following
   repository policy. Broaden tests when shared support or contracts change.
5. On failures, distinguish incorrect tests, production defects and
   pre-existing failures. Fix the cause rather than weakening assertions.
6. Report checks actually run and any unverified behavior.

## References

- Dart testing: https://dart.dev/tools/testing
- Flutter testing: https://docs.flutter.dev/testing/overview
- Mocktail `1.0.5`: https://pub.dev/packages/mocktail
