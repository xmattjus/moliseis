# Implementation Plan: Cache Manager Test Improvements

> **Execution model:** This plan is split into small, atomic, independently
> verifiable steps. Each step has a **Goal**, **Exact actions** (copy-pasteable
> code or precise edits), a **Verify** command, and a **Done when** criterion.
> Execute steps in order. Do not skip the `Verify` block — it is the only thing
> that confirms a step succeeded. Do not improvise code that differs from what
> is written here; the code has been checked against the resolved dependency
> versions listed in §0.

---

## 0. Problem Statement & Verified Facts

### Problem

Two review findings from the `cached_network_image_ce` migration:

1. **`DefaultCacheManagerExtensions.getSingleFile` has no test coverage.** The
   extension at `lib/utils/extensions/cache_manager_extensions.dart:7` has four
   code paths (happy path, `DownloadProgress` events silently skipped, stream
   closes without `FileInfo`, error propagation) that are untested.

2. **`_FailingCacheManager` in `app_network_image_test.dart` extends
   `DefaultCacheManager`** inline. It couples tests to a concrete class with
   real Hive/path_provider initialization. It is safe in practice (the
   constructor only stores factory references; `_ensureInitialized` is never
   reached because `getFileStream`/`getImageFile` are overridden), but it
   should be extracted into a reusable shared fake and disposed per test.

### Verified facts (do NOT re-derive these)

| Fact | Value | Source |
|------|-------|--------|
| Resolved `cached_network_image_ce` | **4.6.4** | `pubspec.lock` |
| Resolved `cached_network_image_platform_interface_ce` | 5.2.0 | `pubspec.lock` |
| Resolved `file` (transitive) | **7.0.1** | `pubspec.lock` |
| `cached_network_image_ce` constraint on `file` | `>=7.0.0 <8.0.0` | its `pubspec.yaml` |
| `DefaultCacheManager` constructor (4.6.4) | stores `http.Client.new` & `getTemporaryDirectory` as factory refs; **no I/O** | source lines 55–63 |
| `dispose()` (4.6.4, lines 513–540) | null-guarded `_initCompleter`; null+isOpen-guarded `_cacheBox`; try/caught `_hive.close()`. **Safe on uninitialized instance.** | source |
| `FileInfo.file` type | `package:file.File` | `file_response.dart:49` |
| Type compatibility | `abstract class File implements FileSystemEntity, io.File` — so `package:file.File` is a **subtype** of `dart:io.File`. `MemoryFile` transitively implements `dart:io.File`. The extension's `return response.file` is a valid upcast. | `file-7.0.1/lib/src/interface/file.dart:12` |
| `MemoryFileSystem` export | exported from `package:file/memory.dart`; no-arg constructor valid (POSIX default) | `file-7.0.1/lib/memory.dart`, `memory_file_system.dart:45` |
| `FileSource` enum casing | `FileSource { NA, Cache, Online }` — use `FileSource.Cache` | `file_response.dart:35` |
| Existing `dispose()` regression test | `test/config/dependencies_test.dart:29-32` creates a real `DefaultCacheManager()` and asserts `dispose()` completes | file |
| Relative import path from `test/ui/core/ui/media/` to `test/support/` | `../../../../support/` (4 levels up: `media`→`ui`→`core`→`ui`→`test`) | arithmetic |
| Existing `app_network_image_test.dart` import style | grouped: `dart:` → `package:` → relative. **Not alphabetical within groups.** | file lines 1–12 |
| `_FailingCacheManager` locations to replace | 4 instantiations: lines 108, 124, 138, 155 | file |

### What is NOT changing

- **Zero production code changes.** Only `pubspec.yaml`, two new test files, and
  one refactored test file.
- The `DefaultCacheManager` production type stays as-is (Option A, minimal).

---

## 1. File Inventory

| # | Path | Action |
|---|------|--------|
| 1 | `pubspec.yaml` | Edit: add `file` dev dependency |
| 2 | `test/support/fake_cache_manager.dart` | Create new |
| 3 | `test/utils/extensions/cache_manager_extensions_test.dart` | Create new (4 tests) |
| 4 | `test/ui/core/ui/media/app_network_image_test.dart` | Refactor: remove `_FailingCacheManager`, use shared fake |

---

## 2. Execution Steps

### Step 1 — Add `file` dev dependency

**Goal:** Make `package:file/memory.dart` importable explicitly in tests.

**Exact actions:**

In `pubspec.yaml`, under `dev_dependencies:`, find the `# F` section and insert
`file: ^7.0.1` before `flutter_test:`. The section must look exactly like this:

```yaml
dev_dependencies:
  # A
  app_lints:
    path: packages/app_lints
  # B
  build_runner: ^2.15.0
  # C
  # D
  # E
  dart_mappable_builder: ^4.8.0
  envied_generator: ^1.3.5
  # F
  file: ^7.0.1
  flutter_test:
    sdk: flutter
  # G
```

**Verify:**
```bash
flutter pub get
```
**Done when:** `pub get` prints `Got dependencies!` (or equivalent success) with
no version-solve error. `file` is already resolved transitively at 7.0.1, so the
constraint `^7.0.1` (`>=7.0.1 <8.0.0`) intersects `>=7.0.0 <8.0.0` at 7.0.1 — no
resolution change.

---

### Step 2 — Create the shared fake

**Goal:** A reusable `DefaultCacheManager` test double that overrides the two
methods tests use (`getFileStream`, `getImageFile`), so no real I/O is triggered.

**Exact actions:**

Create the file `test/support/fake_cache_manager.dart` with **exactly** this
content:

```dart
import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show DefaultCacheManager, FileResponse;

/// A lightweight [DefaultCacheManager] test double.
///
/// [DefaultCacheManager] initialisation is lazy: the constructor only stores
/// factory references, and the real Hive/path_provider setup is only triggered
/// if a base-class method reaches `[_ensureInitialized]`. Because the methods
/// used by the current tests are overridden here, that never happens.
///
/// Methods not overridden here (`getFileFromCache`, `putFile`, `removeFile`,
/// `emptyCache`) fall through to the real implementation and will trigger
/// filesystem initialization. Override them in a subclass if your test needs
/// to call them.
class FakeDefaultCacheManager extends DefaultCacheManager {
  FakeDefaultCacheManager({this.streamFactory}) : super();

  /// Called by [getFileStream] and, transitively, by [getImageFile].
  ///
  /// Takes no parameters (URL/headers are not forwarded) to keep the API
  /// simple. Override [getFileStream] in a subclass if your test needs
  /// URL-specific behaviour.
  final Stream<FileResponse> Function()? streamFactory;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) =>
      streamFactory?.call() ?? const Stream.empty();

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) {
    assert(
      maxHeight == null && maxWidth == null,
      'FakeDefaultCacheManager does not support image resizing. '
      'Override getImageFile in a subclass if your test needs it.',
    );
    return getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    );
  }
}
```

**Verify:**
```bash
flutter analyze test/support/fake_cache_manager.dart
```
**Done when:** analyzer prints `No issues found!` for that file. If you see an
error about `DefaultCacheManager` or `FileResponse` not found, re-run
`flutter pub get` — the `show` combinator names are exported by
`package:cached_network_image_ce/cached_network_image.dart`.

---

### Step 3 — Create the extension test file with test 1 (happy path)

**Goal:** Start the extension test file with the simplest passing test.

**Exact actions:**

Create the file `test/utils/extensions/cache_manager_extensions_test.dart`
with **exactly** this content:

```dart
import 'package:cached_network_image_ce/cached_network_image.dart'
    show DownloadProgress, FileInfo, FileResponse, FileSource;
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/extensions/cache_manager_extensions.dart';

import '../../support/fake_cache_manager.dart';

void main() {
  group('DefaultCacheManagerExtensions.getSingleFile', () {
    FakeDefaultCacheManager? cacheManager;
    const testUrl = 'https://example.com/image.jpg';

    tearDown(() async {
      await cacheManager?.dispose();
      cacheManager = null;
    });

    test('returns file when FileInfo is emitted', () async {
      final fileSystem = MemoryFileSystem();
      final testFile = fileSystem.file('/test.jpg');

      cacheManager = FakeDefaultCacheManager(
        streamFactory: () => Stream.value(
          FileInfo(
            testFile,
            FileSource.Cache,
            DateTime.now().add(const Duration(days: 1)),
            testUrl,
          ),
        ),
      );

      final file = await cacheManager!.getSingleFile(testUrl);

      expect(file.path, '/test.jpg');
    });
  });
}
```

**Verify:**
```bash
flutter test test/utils/extensions/cache_manager_extensions_test.dart --plain-name 'returns file when FileInfo is emitted'
```
**Done when:** the test passes (`+1: All tests passed!`). If it fails with a type
error on `file.path`, confirm `file: ^7.0.1` is in `pubspec.yaml` and `pub get`
was run. If it fails to find `FakeDefaultCacheManager`, confirm the import path
is `../../support/fake_cache_manager.dart` (two levels up from
`test/utils/extensions/`).

---

### Step 4 — Add test 2 (progress events then FileInfo)

**Goal:** Cover the realistic production flow where `DownloadProgress` events
arrive before the final `FileInfo`, and verify the extension silently skips them.

**Exact actions:**

In `test/utils/extensions/cache_manager_extensions_test.dart`, inside the
`group(...)` block, **after** the first `test(...)` block and **before** the
closing `});` of the group, insert this test:

```dart
    test(
      'returns file when DownloadProgress events precede FileInfo',
      () async {
        final fileSystem = MemoryFileSystem();
        final testFile = fileSystem.file('/test.jpg');

        cacheManager = FakeDefaultCacheManager(
          streamFactory: () => Stream.fromIterable([
            DownloadProgress(testUrl, 1000, 100),
            DownloadProgress(testUrl, 1000, 500),
            DownloadProgress(testUrl, 1000, 1000),
            FileInfo(
              testFile,
              FileSource.Online,
              DateTime.now().add(const Duration(days: 1)),
              testUrl,
            ),
          ]),
        );

        final file = await cacheManager!.getSingleFile(testUrl);

        expect(file.path, '/test.jpg');
      },
    );
```

**Verify:**
```bash
flutter test test/utils/extensions/cache_manager_extensions_test.dart --plain-name 'returns file when DownloadProgress events precede FileInfo'
```
**Done when:** the test passes. This confirms `if (response is FileInfo)` skips
`DownloadProgress` events rather than throwing on them.

---

### Step 5 — Add test 3 (stream closes without FileInfo)

**Goal:** Cover the defensive fallback `throw Exception('Failed to get file from
cache: $url')` when the stream ends without ever emitting a `FileInfo`.

**Exact actions:**

In `test/utils/extensions/cache_manager_extensions_test.dart`, inside the
`group(...)` block, after the test added in Step 4, insert this test:

```dart
    test(
      'throws when stream closes without emitting FileInfo',
      () async {
        cacheManager = FakeDefaultCacheManager(
          streamFactory: () => Stream.fromIterable([
            DownloadProgress(testUrl, 1000, 100),
            DownloadProgress(testUrl, 1000, 500),
            DownloadProgress(testUrl, 1000, 1000),
          ]),
        );

        await expectLater(
          cacheManager!.getSingleFile(testUrl),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to get file from cache'),
            ),
          ),
        );
      },
    );
```

**Verify:**
```bash
flutter test test/utils/extensions/cache_manager_extensions_test.dart --plain-name 'throws when stream closes without emitting FileInfo'
```
**Done when:** the test passes. This is a defensive edge case — the real
`DefaultCacheManager._pushFileToStream` always ends with `FileInfo` or an error,
but the fallback in the extension must still be guarded against regressions.

---

### Step 6 — Add test 4 (error propagation)

**Goal:** Confirm that an error from `getFileStream` is rethrown, not swallowed
and replaced by the "no FileInfo" message.

**Exact actions:**

In `test/utils/extensions/cache_manager_extensions_test.dart`, inside the
`group(...)` block, after the test added in Step 5, insert this test:

```dart
    test('propagates error from stream', () async {
      cacheManager = FakeDefaultCacheManager(
        streamFactory: () => Stream.error(Exception('Network error')),
      );

      await expectLater(
        cacheManager!.getSingleFile(testUrl),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network error'),
          ),
        ),
      );
    });
```

**Verify:**
```bash
flutter test test/utils/extensions/cache_manager_extensions_test.dart
```
**Done when:** all 4 tests pass (`+4: All tests passed!`). Run the whole file
this time, not just one test, to confirm `tearDown` is safe across all four.

---

### Step 7 — Add the import to `app_network_image_test.dart`

**Goal:** Make `FakeDefaultCacheManager` available in the widget test file.

**Exact actions:**

In `test/ui/core/ui/media/app_network_image_test.dart`, the current relative
import block at the bottom of the imports is:

```dart
import '../../../../support/mock_logger.dart';
```

Add the fake import **immediately before** it, so the two relative imports read:

```dart
import '../../../../support/fake_cache_manager.dart';
import '../../../../support/mock_logger.dart';
```

The path is 4 levels up (`media`→`ui`→`core`→`ui`→`test`) then into `support/`.
Do not reorder any other imports — the file uses grouped (dart:→package:→
relative) style, not alphabetical.

**Verify:**
```bash
flutter analyze test/ui/core/ui/media/app_network_image_test.dart
```
**Done when:** the only analyzer message (if any) is `unused_import` for
`fake_cache_manager.dart` — that is expected and will disappear after Step 9
uses it. No "uri does not exist" or "undefined name" errors.

---

### Step 8 — Remove the `_FailingCacheManager` class

**Goal:** Delete the inline test double so only the shared fake remains.

**Exact actions:**

In `test/ui/core/ui/media/app_network_image_test.dart`, delete the entire
`_FailingCacheManager` class definition. It starts at the line:

```dart
class _FailingCacheManager extends DefaultCacheManager {
```

and ends at the matching closing `}` immediately before the `_buildTestApp`
function. That is, delete from `class _FailingCacheManager extends DefaultCacheManager {`
through the `}` that closes the `getImageFile` method's enclosing class (the
line right before `Widget _buildTestApp({`).

After deletion, the file's top section must read, in order:
1. The `dart:async` import
2. The `package:` imports
3. The `package:provider/provider.dart` import
4. The two relative imports (`fake_cache_manager.dart`, `mock_logger.dart`)
5. A blank line
6. `Widget _buildTestApp({`

**Verify:**
```bash
flutter analyze test/ui/core/ui/media/app_network_image_test.dart
```
**Done when:** analyzer reports errors on the 4 lines that still reference
`_FailingCacheManager()` (lines that were 108, 124, 138, 155 — "undefined name
`_FailingCacheManager`"). These are expected and fixed in Steps 9–13. No other
errors.

---

### Step 9 — Add the group-level field and `tearDown`

**Goal:** Ensure every fake is disposed after each test, preventing Hive/resource
leaks across tests.

**Exact actions:**

In `test/ui/core/ui/media/app_network_image_test.dart`, find:

```dart
void main() {
  group('AppNetworkImage', () {
    testWidgets(
      'throws ProviderNotFoundException when DefaultCacheManager is missing',
```

Insert a nullable field and a `tearDown` **immediately after** the
`group('AppNetworkImage', () {` opening line and **before** the first
`testWidgets(...)`. The result must look like:

```dart
  group('AppNetworkImage', () {
    FakeDefaultCacheManager? cacheManager;

    tearDown(() async {
      await cacheManager?.dispose();
      cacheManager = null;
    });

    testWidgets(
      'throws ProviderNotFoundException when DefaultCacheManager is missing',
```

**Verify:**
```bash
flutter analyze test/ui/core/ui/media/app_network_image_test.dart
```
**Done when:** no new errors beyond the still-expected 4 `_FailingCacheManager`
references. The `cacheManager` field is declared but not yet assigned — that is
fine, Dart allows nullable fields to remain null.

---

### Step 10 — Replace instantiation 1 ("renders error view")

**Goal:** Switch the first `_FailingCacheManager()` to the shared fake using the
error-stream pattern that preserves the original async timing.

**Exact actions:**

Find the test `'renders error view when image fails to load'`. It currently
contains:

```dart
      await tester.pumpWidget(
        _buildTestApp(cacheManager: _FailingCacheManager()),
      );
```

Replace it with:

```dart
      cacheManager = FakeDefaultCacheManager(
        streamFactory: () {
          final controller = StreamController<FileResponse>();
          scheduleMicrotask(() {
            controller.addError(Exception('Test image load failure'));
            unawaited(controller.close());
          });
          return controller.stream;
        },
      );

      await tester.pumpWidget(
        _buildTestApp(cacheManager: cacheManager!),
      );
```

Note: `scheduleMicrotask`, `StreamController`, and `unawaited` come from
`dart:async`, which is already imported at the top of the file. `FileResponse`
is exported by `package:cached_network_image_ce/cached_network_image.dart`,
which is already imported (the existing file imports the whole library, not a
`show` combinator).

**Verify:**
```bash
flutter test test/ui/core/ui/media/app_network_image_test.dart --plain-name 'renders error view when image fails to load'
```
**Done when:** the test passes. It should find `EmptyView` and the
`image_not_supported` icon, exactly as before — the error-stream behaviour is
identical to the old `_FailingCacheManager`.

---

### Step 11 — Replace instantiation 2 ("errorBuilder logs")

**Goal:** Switch the second `_FailingCacheManager()`.

**Exact actions:**

Find the test `'errorBuilder logs ImageLoadFailed to Logger'`. Replace:

```dart
        _buildTestApp(
          cacheManager: _FailingCacheManager(),
          logger: logger,
        ),
```

with:

```dart
        _buildTestApp(
          cacheManager: cacheManager!,
          logger: logger,
        ),
```

Then, **before** the `await tester.pumpWidget(` call in that same test, insert
the same error-stream assignment used in Step 10:

```dart
      cacheManager = FakeDefaultCacheManager(
        streamFactory: () {
          final controller = StreamController<FileResponse>();
          scheduleMicrotask(() {
            controller.addError(Exception('Test image load failure'));
            unawaited(controller.close());
          });
          return controller.stream;
        },
      );
```

Place it right after the `final logger = MockLogger();` line so the test reads,
in order: create logger → create cacheManager → pumpWidget → pump → expect.

**Verify:**
```bash
flutter test test/ui/core/ui/media/app_network_image_test.dart --plain-name 'errorBuilder logs ImageLoadFailed to Logger'
```
**Done when:** the test passes, confirming `logger.containsEvent<ImageLoadFailed>()`
is true.

---

### Step 12 — Replace instantiation 3 ("normal constructor sets width/height")

**Goal:** Switch the third `_FailingCacheManager()`.

**Exact actions:**

Find the test `'normal constructor sets explicit width and height on Image'`.
Replace:

```dart
        _buildTestApp(
          cacheManager: _FailingCacheManager(),
          width: 300,
          height: 250,
        ),
```

with:

```dart
        _buildTestApp(
          cacheManager: cacheManager!,
          width: 300,
          height: 250,
        ),
```

Then, **before** the `await tester.pumpWidget(` call, insert the same
error-stream assignment used in Steps 10–11:

```dart
      cacheManager = FakeDefaultCacheManager(
        streamFactory: () {
          final controller = StreamController<FileResponse>();
          scheduleMicrotask(() {
            controller.addError(Exception('Test image load failure'));
            unawaited(controller.close());
          });
          return controller.stream;
        },
      );
```

**Verify:**
```bash
flutter test test/ui/core/ui/media/app_network_image_test.dart --plain-name 'normal constructor sets explicit width and height on Image'
```
**Done when:** the test passes. It checks `imageWidget.width == 300` and
`imageWidget.height == 250` — these are widget properties set at build time, so
they are correct whether or not the image ever loads.

---

### Step 13 — Replace instantiation 4 ("assert fails for non-finite dimensions")

**Goal:** Switch the fourth `_FailingCacheManager()`. This one does not need an
error stream: the assertion fires in `AppNetworkImage.build()` before
`CachedNetworkImageProvider` is ever constructed, so the cache manager is never
called.

**Exact actions:**

Find the test `'assert fails for non-finite dimensions'`. Replace:

```dart
        _buildTestApp(
          cacheManager: _FailingCacheManager(),
          width: double.nan,
        ),
```

with:

```dart
        _buildTestApp(
          cacheManager: cacheManager!,
          width: double.nan,
        ),
```

Then, **before** the `await tester.pumpWidget(` call, insert a default fake
(no `streamFactory` — returns an empty stream, which is fine because the
assertion throws first):

```dart
      cacheManager = FakeDefaultCacheManager();
```

**Verify:**
```bash
flutter test test/ui/core/ui/media/app_network_image_test.dart --plain-name 'assert fails for non-finite dimensions'
```
**Done when:** the test passes, confirming `tester.takeException()` is an
`AssertionError`.

---

### Step 14 — Run the full widget test file

**Goal:** Confirm all tests in the refactored file pass together, including the
two groups that do not use the cache manager.

**Verify:**
```bash
flutter test test/ui/core/ui/media/app_network_image_test.dart
```
**Done when:** all tests pass. The `ProviderNotFoundException` test does not
assign `cacheManager`, so `tearDown` runs `null?.dispose()` — a no-op, safe.
The `AppNetworkImage.fullResolution constructor` group does not pump widgets, so
it never touches the cache manager either.

---

### Step 15 — Run the affected tests together

**Goal:** Confirm the three files that exercise `DefaultCacheManager` disposal
behaviour all pass. `dependencies_test.dart` is included as a regression check:
it creates a real `DefaultCacheManager()` and asserts `dispose()` completes,
which is exactly the safety property the fake relies on.

**Verify:**
```bash
flutter test test/utils/extensions/cache_manager_extensions_test.dart test/ui/core/ui/media/app_network_image_test.dart test/config/dependencies_test.dart
```
**Done when:** all tests across the three files pass.

---

### Step 16 — Run the full test suite

**Goal:** Confirm no other test was broken by the `pubspec.yaml` change or the
new shared fake.

**Verify:**
```bash
flutter test
```
**Done when:** the full suite passes with the same count of tests as before this
change, plus 4 new extension tests.

---

### Step 17 — Run analysis and formatting

**Goal:** Confirm the codebase is clean and formatted per project convention.

**Verify:**
```bash
flutter analyze
dart format .
```
**Done when:**
- `flutter analyze` prints `No issues found!` (or only pre-existing issues
  unrelated to this change).
- `dart format .` reports the new and edited files as already formatted, or
  reformats them with no semantic change.

---

## 3. Rollback

If any step fails and cannot be fixed quickly, revert with a single commit:

```bash
git revert <commit-sha-of-this-change>
```

Because this change touches only `pubspec.yaml` and test files, a revert cannot
affect production behaviour.

---

## 4. Risk Assessment

- **Risk level:** Low
- **Direction:** Adding tests and test infrastructure; no production code changes
- **Breaking changes:** None
- **Key risks and mitigations:**
  - `FakeDefaultCacheManager` inherits un-overridden methods (`getFileFromCache`,
    `putFile`, `removeFile`, `emptyCache`) that could trigger real I/O if
    accidentally called → mitigated by the class dartdoc warning and the
    `maxHeight`/`maxWidth` assert in `getImageFile`.
  - `dispose()` on an uninitialized `DefaultCacheManager` → verified safe in
    4.6.4 source (null-guarded `_initCompleter`, null+isOpen-guarded `_cacheBox`,
    try/caught `_hive.close()`), and covered by existing
    `test/config/dependencies_test.dart:29-32`.
  - `package:file.File` vs `dart:io.File` type compatibility → `package:file.File
    implements io.File`, so `MemoryFile` is a valid `dart:io.File`; analyzer
    confirms zero errors on the production extension.
- **Rollback:** Single revert commit.

---

## 5. Metrics

- **Lines added:** ~120 (fake_cache_manager.dart + 4 extension tests)
- **Lines removed:** ~35 (inline `_FailingCacheManager` class)
- **Net:** ~85 lines added
- **Test coverage:** `getSingleFile` extension now has 4 test cases covering all
  code paths (happy path, progress-then-file, stream-close fallback, error
  propagation)
- **Production code:** Zero changes
