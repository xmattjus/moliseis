---
name: molise-is-objectbox-test-store
description: Use when writing or modifying ObjectBox repository, local data-source, or data-layer tests. Uses a real temporary ObjectBox store instead of Box, Store, QueryBuilder, or ObjectBox fakes and keeps persistence fixtures independent from UI codecs such as Flutter Quill.
---

# ObjectBox Test Store

Use this skill when a test needs ObjectBox behavior that should match the real
library, especially for repository and local data-source rewrites.

## Core approach

1. Create a temporary store with `openStore(directory: directory.path)`.
2. Wrap it in a small helper that owns both the `Directory` and `Store`.
3. Dispose the helper in `tearDown` so the store is closed before deleting the
   directory.
4. Seed real entities through real boxes with `store.box<T>().put(...)`.
5. Query through the production code under test; do not recreate ObjectBox query
   logic with hand-written fakes.

## Recommended test helper pattern

Use a helper like `TestObjectBoxEnvironment`:

- `create()` opens the temp store.
- `close()` closes the store once.
- `dispose()` closes the store and deletes the temp directory.

If production code expects the app `ObjectBox` wrapper, add a thin test wrapper
that exposes the real `Store`.

## Keep persistence fixtures layer-local

ObjectBox repository and data-source tests should construct fixtures directly
in the serialized shape owned by the data layer. Do not depend on a UI codec or
widget library merely to produce values for persistence tests.

For rich-text Delta fields, use raw canonical Delta fixtures such as
`List<Map<String, dynamic>>` instead of constructing them through a UI codec or
Flutter Quill. This keeps the test focused on the ObjectBox persistence
contract, reduces dependencies, and prevents UI changes from breaking
unrelated data-layer tests.

Test codec-to-Delta conversion separately in the codec's own UI or utility test
suite. An end-to-end test may intentionally cover both layers, but it should be
classified and located as an integration test rather than as an ObjectBox
repository unit test.

## What to avoid

- Do not fake `Box`, `QueryBuilder`, `Query`, or `Store` unless the test is only
  about a pure unit boundary and ObjectBox behavior is irrelevant.
- Do not keep custom in-memory maps that pretend to be ObjectBox.
- Do not import UI codecs or widget libraries only to construct persistence
  fixtures; use raw data-layer values instead.
- Do not use `catch (Object)` or `catch (Error)` to simulate closed-store
  behavior.
- Do not hide programming errors by broadly swallowing non-Exception failures.

## Closed-store failure tests

If you need to verify error handling for a closed store:

- Close the real temp store explicitly in the test.
- Assert that the production code responds with the expected error result.
- Prefer an explicit `Store.isClosed()` guard in production code when the API
  supports it.
- Keep ordinary `Exception` handling for real database failures separate from
  closed-store handling.

## Good fit examples

- Rewriting a repository test that currently uses fake query chains.
- Rewriting a local data-source test that currently uses a fake storage map.
- Verifying date-range, relationship, or id-based ObjectBox behavior against the
  real database engine.
- Writing or modifying an ObjectBox repository test that persists structured
  JSON or rich-text Delta data.

## Repository-specific notes

- The local test helper lives in `test/support/objectbox_test_store.dart`.
- Use that helper instead of duplicating temp-store setup in each test file.
- Keep the test store local to the test process; do not reuse it across unrelated
  test suites.
