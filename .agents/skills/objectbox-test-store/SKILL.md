---
name: objectbox-test-store
description: Use a real temporary ObjectBox store in tests instead of fakes. Prefer this when rewriting repository or data-source tests that currently mock Box, Store, QueryBuilder, or ObjectBox behavior.
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

## What to avoid

- Do not fake `Box`, `QueryBuilder`, `Query`, or `Store` unless the test is only
  about a pure unit boundary and ObjectBox behavior is irrelevant.
- Do not keep custom in-memory maps that pretend to be ObjectBox.
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

## Repository-specific notes

- The local test helper lives in `test/support/objectbox_test_store.dart`.
- Use that helper instead of duplicating temp-store setup in each test file.
- Keep the test store local to the test process; do not reuse it across unrelated
  test suites.
