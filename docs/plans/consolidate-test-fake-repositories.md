# Implementation Plan: Consolidate Test Fake Repositories

## Problem Statement

26 private fake classes are duplicated across 15+ test files. Each test file defines its own
`_FakeXxxRepository` with slight variations in which constructor parameters and call counters it
exposes. The worst offender is `_FakeEventRepository`, defined independently in 9 files. Adding a
new method to a repository interface requires updating every copy instead of a single shared fake.
The duplication also hides subtle inconsistencies: some fakes use `extends EventRepository` (to
inherit the `Synchronizable` mixin) while others use `implements EventRepository` (missing mixin
methods silently).

Beyond fakes, `_TestException` is copy-pasted 12 times and model fixtures (`_testCity()`,
`_makeEvent()`, `_makePlace()`) appear 6–8 times each with trivial date variations.

### Duplication heatmap

| Fake | Copies | Files |
|---|---|---|
| `_FakeEventRepository` | **9** | sync_use_case, mapped_use_cases, sync_vm, event_vm, events_calendar, post_screen, category_vm, search_vm, event_formatted_datetime |
| `_FakePlaceRepository` | **6** | sync_use_case, mapped_use_cases, sync_vm, category_vm, post_screen, event_formatted_datetime |
| `_FakeSettingsRepository` | **5** | sync_use_case, sync_vm, settings_vm, theme_vm, category_vm |
| `_FakeWeatherApiClient` | **4** | post_screen, weather_vm, forecast_days, forecast_hourly |
| `_FakeCityRepository` | **2** | sync_use_case, sync_vm |
| `_FakeMediaRepository` | **2** | sync_use_case, sync_vm |
| `_FakeSyncTransactionCoordinator` | **2** | sync_use_case, sync_vm |
| `_FakeImagePicker` | **2** | media_uploader, contribution_vm |
| `_FakeUserContributionRepository` | **2** | media_uploader, contribution_vm |
| `_TestException` | **12** | sync_use_case, mapped_use_cases, result_test, settings_impl, event_vm, category_vm, weather_vm, settings_vm, theme_vm, search_vm, favourite_vm, sync_vm |
| `_testCity()` fixture | **8** | event_vm, events_calendar, category_vm, search_vm, favourite_vm, integration_test, event_formatted_date_time, search_anchor_suggestion_list |

## Scope Decision

We consolidate fakes, fixtures, and utilities where duplication cost exceeds consolidation cost.

**In scope (10 shared classes + 1 shared utility + model fixtures, 3 files):**

| Shared class | Reason |
|---|---|
| `FakeCityRepository` | 2 copies, ~25 lines each |
| `FakeEventRepository` | 9 copies, ~50–80 lines each |
| `FakeMediaRepository` | 2 copies, ~25 lines each |
| `FakePlaceRepository` | 6 copies, ~60 lines each |
| `FakeSettingsRepository` | 5 copies, ~30–50 lines each |
| `FakeUserContributionRepository` | 2 copies, ~30 lines each |
| `FakeWeatherApiClient` | 4 copies of a single-method class; 3 copies are byte-for-byte identical |
| `FakeImagePicker` | 2 byte-for-byte identical copies; zero marginal ceremony since the shared file already exists |
| `FakeTransactionCoordinator` | 2 identical copies in files that are already being modified |
| `TestException` | 12 identical copies; universal applicability across test suite |
| Model fixtures | `testCity()`, `makeEvent()`, `makePlace()` — 6–8 copies each |

**Out of scope:**

| Fake | Reason |
|---|---|
| `_FakeSearchRepository` | Only 1 copy — no duplication to fix. YAGNI. |
| `_ThrowingTransactionCoordinator` | Single copy, test-specific behaviour variant |
| `_WrappingTransactionCoordinator` | Single copy, test-specific behaviour variant |
| `_FakeExploreGetByIdUseCase` | Use-case fake, not a repository; 1 copy |
| `_FakeFavouriteGetIdsUseCase` | Use-case fake, not a repository; 1 copy |

## Solution

Create **three** shared files in `test/support/`:

| File | Contents |
|---|---|
| `test/support/fake_repositories.dart` | All 9 shared fakes + `TestException` |
| `test/support/fixtures.dart` | `testCity()`, `makeEvent()`, `makePlace()` |
| `test/support/fake_image_picker.dart` | `FakeImagePicker` (separate file because it depends on `image_picker` and `cross_file` packages, keeping the main fakes file free of Flutter plugin dependencies) |

Each fake is configurable via constructor parameters (with sensible defaults) and exposes non-final
result fields so tests can reconfigure behaviour between `test()` blocks without creating new
instances. Call counters and argument-capture fields are present only where existing tests actually
query them.

### Design principles

1. **Three files, clear separation** — `fake_repositories.dart` for domain-layer fakes and the
   transaction coordinator; `fixtures.dart` for model factories; `fake_image_picker.dart` for the
   Flutter plugin fake. The repository file stays self-contained (~520 lines).
2. **Hand-written fakes only** — the codebase already uses hand-written fakes; we just centralise
   them. No mock library is needed since every method is overridden with concrete behaviour.
3. **`extends RepositoryClass`** for `Synchronizable` repos (City, Event, Media, Place) to inherit
   the mixin. **`implements Interface`** for Settings and UserContribution — the compiler enforces
   that all methods are implemented.
4. **Mutable fields with constructor defaults** — constructor params set initial values; non-final
   fields let tests mutate behaviour between subtests within a `group()`.
5. **No convenience factories** — a factory that wraps values in `Result.success(...)` saves ~18
   characters per field but adds ~40 lines of factory code and creates two calling conventions.
   Accept the explicit `Result.success(...)` at call sites — it is consistent with the rest of the
   codebase.
6. **Counters and argument captures only where used** — `getByDateCallCount` and
   `getByCategoriesCallCount` on `FakeEventRepository`; `lastGetAllSort` and `lastCoordinates` on
   `FakePlaceRepository`; `lastCoordinates` on `FakeEventRepository`; `setModifiedAtCalled` on
   `FakeSettingsRepository`; `uploadCalled`/`uploadImageCalled` on
   `FakeUserContributionRepository`. No speculative counters on other methods.
7. **No new dependencies** — the shared fakes are plain Dart classes and don't depend on any mock
   library. `FakeImagePicker` depends on `image_picker` (already a project dependency).
8. **Consistent setter behaviour** — all `setXxx` methods in `FakeSettingsRepository` use the same
   conditional-update pattern: `if (result is Success<void>) field = newValue`. This includes
   `setContentSort`, which was inconsistent in some local fakes.

---

## Changes by File

### 1. **NEW** `test/support/fake_repositories.dart`

The entire file (~520 lines). All 9 fakes + `TestException` in one place.

```dart
import 'dart:io' show File;

import 'package:http/http.dart' as http;
import 'package:moliseis/data/data-sources/user_contribution.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/utils/result.dart';

import 'mock_logger.dart';

// ---------------------------------------------------------------------------
// TestException
// ---------------------------------------------------------------------------

/// Shared test exception used across the entire test suite.
///
/// Prefer this over defining a private `_TestException` per test file.
final class TestException implements Exception {
  TestException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// FakeTransactionCoordinator
// ---------------------------------------------------------------------------

/// A pass-through transaction coordinator that simply executes the function.
final class FakeTransactionCoordinator implements SyncTransactionCoordinator {
  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) => fn();
}

// ---------------------------------------------------------------------------
// FakeCityRepository
// ---------------------------------------------------------------------------

final class FakeCityRepository extends CityRepository {
  FakeCityRepository({
    this.prepareResult = const Result.success([]),
  });

  Result<List<CityDto>> prepareResult;
  bool commitCalled = false;
  List<CityDto>? committedDtos;

  @override
  Future<Result<List<CityDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<CityDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }
}

// ---------------------------------------------------------------------------
// FakeEventRepository
// ---------------------------------------------------------------------------

final class FakeEventRepository extends EventRepository {
  FakeEventRepository({
    this.prepareResult = const Result.success([]),
    this.getByCurrentYearResult = const Result.success([]),
    this.getByDateResult = const Result.success([]),
    this.getByDateRangeResult = const Result.success([]),
    this.getByCategoriesResult = const Result.success([]),
    this.getByCoordinatesResult = const Result.success([]),
    this.getNextEventIdsResult = const Result.success([]),
    this.getFavouriteEventIdsResult = const Result.success([]),
    this.getFavouritesResult = const Result.success([]),
    this.setFavouriteEventResult = const Result.success(null),
    Map<int, Result<Event>>? getByIdResults,
  }) : getByIdResults = getByIdResults ?? {};

  // Configurable results (non-final for mid-test reconfiguration)
  Result<List<EventDto>> prepareResult;
  Result<List<Event>> getByCurrentYearResult;
  Result<List<Event>> getByDateResult;
  Result<List<Event>> getByDateRangeResult;
  Result<List<Event>> getByCategoriesResult;
  Result<List<Event>> getByCoordinatesResult;
  Result<List<int>> getNextEventIdsResult;
  Result<List<int>> getFavouriteEventIdsResult;
  Result<Iterable<Event>> getFavouritesResult;
  Result<void> setFavouriteEventResult;
  Map<int, Result<Event>> getByIdResults;

  // Sync tracking
  bool commitCalled = false;
  List<EventDto>? committedDtos;

  // Call counters (only where existing tests query them)
  int getByDateCallCount = 0;
  int getByCategoriesCallCount = 0;

  // Argument captures (only where existing tests inspect them)
  List<double>? lastCoordinates;

  @override
  Future<Result<List<EventDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<EventDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      getByCurrentYearResult;

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async {
    getByDateCallCount++;
    return getByDateResult;
  }

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => getByDateRangeResult;

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    getByCategoriesCallCount++;
    return getByCategoriesResult;
  }

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async {
    lastCoordinates = coordinates;
    return getByCoordinatesResult;
  }

  @override
  Future<Result<Event>> getById(int id) async =>
      getByIdResults[id] ??
      Result.error(Exception('Event $id not configured'));

  @override
  Future<Result<List<int>>> getNextEventIds() async =>
      getNextEventIdsResult;

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      getFavouriteEventIdsResult;

  @override
  Future<Result<Iterable<Event>>> getFavourites() async =>
      getFavouritesResult;

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      setFavouriteEventResult;
}

// ---------------------------------------------------------------------------
// FakeMediaRepository
// ---------------------------------------------------------------------------

final class FakeMediaRepository extends MediaRepository {
  FakeMediaRepository({
    this.prepareResult = const Result.success([]),
    this.getByEventIdResult = const Result.success([]),
    this.getByPlaceIdResult = const Result.success([]),
  });

  Result<List<MediaDto>> prepareResult;
  Result<List<Media>> getByEventIdResult;
  Result<List<Media>> getByPlaceIdResult;

  bool commitCalled = false;
  List<MediaDto>? committedDtos;

  @override
  Future<Result<List<MediaDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<MediaDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Media>>> getByEventId(int id) async =>
      getByEventIdResult;

  @override
  Future<Result<List<Media>>> getByPlaceId(int id) async =>
      getByPlaceIdResult;
}

// ---------------------------------------------------------------------------
// FakePlaceRepository
// ---------------------------------------------------------------------------

final class FakePlaceRepository extends PlaceRepository {
  FakePlaceRepository({
    this.prepareResult = const Result.success([]),
    this.getAllResult = const Result.success([]),
    this.getByCategoriesResult = const Result.success([]),
    this.getByCoordinatesResult = const Result.success([]),
    this.getFavouritePlaceIdsResult = const Result.success([]),
    this.getFavouritesResult = const Result.success([]),
    this.getIdsByCoordinatesResult = const Result.success([]),
    this.getLatestPlaceIdsResult = const Result.success([]),
    this.getSuggestedPlaceIdsResult = const Result.success([]),
    this.setFavouritePlaceResult = const Result.success(null),
    Map<int, Result<Place>>? getByIdResults,
  }) : getByIdResults = getByIdResults ?? {};

  Result<List<PlaceDto>> prepareResult;
  Result<List<Place>> getAllResult;
  Result<List<Place>> getByCategoriesResult;
  Result<List<Place>> getByCoordinatesResult;
  Result<List<int>> getFavouritePlaceIdsResult;
  Result<Iterable<Place>> getFavouritesResult;
  Result<List<int>> getIdsByCoordinatesResult;
  Result<List<int>> getLatestPlaceIdsResult;
  Result<List<int>> getSuggestedPlaceIdsResult;
  Result<void> setFavouritePlaceResult;
  Map<int, Result<Place>> getByIdResults;

  bool commitCalled = false;
  List<PlaceDto>? committedDtos;

  // Argument captures (only where existing tests inspect them)
  ContentSort? lastGetAllSort;
  List<double>? lastCoordinates;

  @override
  Future<Result<List<PlaceDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<PlaceDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    lastGetAllSort = sort;
    return getAllResult;
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => getByCategoriesResult;

  @override
  Future<Result<List<Place>>> getByCoordinates(
    List<double> coordinates,
  ) async {
    lastCoordinates = coordinates;
    return getByCoordinatesResult;
  }

  @override
  Future<Result<Place>> getById(int id) async =>
      getByIdResults[id] ??
      Result.error(Exception('Place $id not configured'));

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async =>
      getFavouritePlaceIdsResult;

  @override
  Future<Result<Iterable<Place>>> getFavourites() async =>
      getFavouritesResult;

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async => getIdsByCoordinatesResult;

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async =>
      getLatestPlaceIdsResult;

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async =>
      getSuggestedPlaceIdsResult;

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async =>
      setFavouritePlaceResult;
}

// ---------------------------------------------------------------------------
// FakeSettingsRepository
// ---------------------------------------------------------------------------

final class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.crashReporting = false,
    this.contentSort = ContentSort.byName,
    this.lastSyncedAt,
    this.themeBrightness = ThemeBrightness.system,
    this.themeType = ThemeType.system,
    this.initializeResult = const Result.success(null),
    this.setCrashReportingResult = const Result.success(null),
    this.setContentSortResult = const Result.success(null),
    this.setModifiedAtResult = const Result.success(null),
    this.setThemeBrightnessResult = const Result.success(null),
    this.setThemeTypeResult = const Result.success(null),
  });

  // Getters (non-final for mid-test mutation)
  @override
  bool crashReporting;
  @override
  ContentSort contentSort;
  @override
  DateTime? lastSyncedAt;
  @override
  ThemeBrightness themeBrightness;
  @override
  ThemeType themeType;

  // Write results
  Result<void> initializeResult;
  Result<void> setCrashReportingResult;
  Result<void> setContentSortResult;
  Result<void> setModifiedAtResult;
  Result<void> setThemeBrightnessResult;
  Result<void> setThemeTypeResult;

  // Call tracking
  bool setModifiedAtCalled = false;

  @override
  Future<Result<void>> initialize() async => initializeResult;

  @override
  Future<Result<void>> setCrashReporting(bool enable) async {
    if (setCrashReportingResult is Success<void>) crashReporting = enable;
    return setCrashReportingResult;
  }

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async {
    if (setContentSortResult is Success<void>) contentSort = sort;
    return setContentSortResult;
  }

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async {
    setModifiedAtCalled = true;
    lastSyncedAt = dateTime;
    return setModifiedAtResult;
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async {
    if (setThemeBrightnessResult is Success<void>) themeBrightness = brightness;
    return setThemeBrightnessResult;
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) async {
    if (setThemeTypeResult is Success<void>) themeType = type;
    return setThemeTypeResult;
  }
}

// ---------------------------------------------------------------------------
// FakeUserContributionRepository
// ---------------------------------------------------------------------------

final class FakeUserContributionRepository
    implements UserContributionRepository {
  FakeUserContributionRepository({
    this.uploadResult = const Result.success(null),
    this.uploadImageResult = const Result.success(''),
  });

  Result<void> uploadResult;
  Result<String> uploadImageResult;

  bool uploadCalled = false;
  bool uploadImageCalled = false;

  @override
  Future<Result<void>> upload(UserContribution userContribution) async {
    uploadCalled = true;
    return uploadResult;
  }

  @override
  Future<Result<String>> uploadImage(File image) async {
    uploadImageCalled = true;
    return uploadImageResult;
  }
}

// ---------------------------------------------------------------------------
// FakeWeatherApiClient
// ---------------------------------------------------------------------------

final class FakeWeatherApiClient extends WeatherApiClient {
  FakeWeatherApiClient({this.result})
    : super(logger: MockLogger(), httpClient: http.Client());

  /// The result to return from [getCombinedWeatherForecast].
  ///
  /// When `null`, returns an error indicating the weather API is not needed
  /// in the current test — matching the `post_screen_test` variant.
  Result<CombinedWeatherForecastResponse>? result;

  @override
  Future<Result<CombinedWeatherForecastResponse>> getCombinedWeatherForecast(
    double latitude,
    double longitude, {
    String timezone = 'Europe/Rome',
  }) async =>
      result ?? Result.error(Exception('Weather not configured for this test'));
}
```

Design notes:

- **`FakePlaceRepository.getAll`** always captures `lastGetAllSort`. This is a side-effect-free
  capture that does not change return behaviour. It is the smallest change that makes
  `mapped_use_cases_test` assertions (`expect(repo.lastGetAllSort, ...)`) work without modification.
- **`FakeEventRepository.getByCoordinates`** and **`FakePlaceRepository.getByCoordinates`** both
  capture `lastCoordinates` for the same reason.
- **`FakeEventRepository.getByCategoriesCallCount`**: `category_view_model_test` asserts on this
  counter at lines 64, 103, and 107. `FakePlaceRepository` does **not** expose
  `getByCategoriesCallCount` — no test reads it on the place repository.
- **`setCrashReporting`, `setContentSort`, `setThemeBrightness`, `setThemeType`** all use the same
  conditional-update pattern (`if (result is Success<void>)`): state toggles on success, not on
  failure. This matches both the real implementation and the intent of all local fakes.
  `setContentSort` was inconsistent in some local fakes (did not update state); the shared version
  applies the same guard for uniformity.
- **`getById`** uses a `Map<int, Result<T>>` for per-ID results. Missing IDs return
  `Result.error(Exception('...'))` so tests get a clear failure rather than silent wrong values.
- **`FakeCityRepository`** has only `Synchronizable` methods — the real interface is empty beyond
  the mixin.
- **`FakeUserContributionRepository.upload`** returns `Result<void>`, not `Result<dynamic>`.
  The `media_uploader_test` local fake erroneously declared `Result<dynamic>`; this was a stale
  override that compiled due to Dart's covariance. The shared fake uses the correct interface type.
- **`FakeWeatherApiClient`** uses `result` as an optional field (nullable). When `null`, it returns
  an error — matching the `post_screen_test` pattern where weather is irrelevant. When non-null, it
  returns that result — matching the `weather_vm_test`/`forecast_*_test` pattern.
- **`FakeTransactionCoordinator`** is a simple pass-through. The `_ThrowingTransactionCoordinator`
  and `_WrappingTransactionCoordinator` variants remain local in `sync_use_case_test.dart` because
  they are one-off test-specific behaviours.
- **`TestException`** is public and top-level. Tests that previously defined
  `_TestException('message')` now use `TestException('message')` — identical API, no underscore.

### 1b. **NEW** `test/support/fixtures.dart`

Shared model factory functions (~60 lines). All parameters are optional with sensible defaults so
tests can override only what they care about.

```dart
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';

/// Default timestamp used by all fixtures.
///
/// Using a fixed value avoids flaky tests caused by `DateTime.now()` drift.
final _defaultDate = DateTime.utc(2026);

/// Creates a [City] with sensible defaults for testing.
City testCity({
  int remoteId = 0,
  String name = 'Molise',
  DateTime? createdAt,
  DateTime? modifiedAt,
}) => City(
  remoteId: remoteId,
  name: name,
  createdAt: createdAt ?? _defaultDate,
  modifiedAt: modifiedAt ?? _defaultDate,
);

/// Creates an [Event] with sensible defaults for testing.
///
/// Only `remoteId` varies frequently across tests; everything else has a
/// default that produces a valid, minimal object.
Event makeEvent({
  int remoteId = 1,
  String name = 'Event',
  String description = '',
  DateTime? startDate,
  DateTime? endDate,
  ContentCategory category = ContentCategory.unknown,
  LatLng coordinates = const LatLng(41.56, 14.66),
  City? city,
  bool isSaved = false,
}) => Event(
  remoteId: remoteId,
  name: name,
  description: description,
  startDate: startDate ?? _defaultDate,
  endDate: endDate,
  category: category,
  coordinates: coordinates,
  createdAt: _defaultDate,
  modifiedAt: _defaultDate,
  city: city ?? testCity(),
  media: const [],
  isSaved: isSaved,
);

/// Creates a [Place] with sensible defaults for testing.
Place makePlace({
  int remoteId = 1,
  String name = 'Place',
  String description = '',
  ContentCategory category = ContentCategory.unknown,
  LatLng coordinates = const LatLng(41.56, 14.66),
  City? city,
  bool isSaved = false,
}) => Place(
  remoteId: remoteId,
  name: name,
  description: description,
  category: category,
  coordinates: coordinates,
  createdAt: _defaultDate,
  modifiedAt: _defaultDate,
  city: city ?? testCity(),
  media: const [],
  isSaved: isSaved,
);
```

Design notes:

- **`_defaultDate`** is a module-level final (not `const` because `DateTime.utc` is not const).
  Using a fixed date makes tests deterministic. Tests that need specific dates for assertions
  (e.g., `events_calendar_test` testing date ranges) will pass explicit `startDate`/`endDate`.
- **No `createdAt`/`modifiedAt` parameters exposed** — no existing test ever asserts on these
  fields in the fixture context. They're always set to `_defaultDate`. If needed later, they can
  be added without breaking existing call sites (optional params).
- **`city` defaults to `testCity()`** — avoids requiring a separate `testCity()` call at every
  fixture site.

### 1c. **NEW** `test/support/fake_image_picker.dart`

Separated from the main fakes file because it imports `image_picker` (Flutter plugin) and
`cross_file` packages, which would pollute the import list of `fake_repositories.dart`.

```dart
import 'package:image_picker/image_picker.dart';

/// Shared fake for [ImagePicker] that delegates to optional callbacks.
///
/// When callbacks are `null`, returns empty/default responses.
final class FakeImagePicker extends ImagePicker {
  FakeImagePicker({this.onPickMultipleMedia, this.onRetrieveLostData});

  final Future<List<XFile>> Function()? onPickMultipleMedia;
  final Future<LostDataResponse> Function()? onRetrieveLostData;

  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => onPickMultipleMedia != null ? await onPickMultipleMedia!() : [];

  @override
  Future<LostDataResponse> retrieveLostData() async =>
      onRetrieveLostData != null
      ? await onRetrieveLostData!()
      : LostDataResponse.empty();
}
```

### 2–16. Migrate test files

For each file below, perform these changes:

1. **Remove** the private `_FakeXxx` class(es) and `_TestException` listed in the columns.
2. **Add** the appropriate imports (adjust relative path per file location):
   - `import '../../support/fake_repositories.dart';` (for fakes + `TestException`)
   - `import '../../support/fixtures.dart';` (for model fixtures, where applicable)
   - `import '../../support/fake_image_picker.dart';` (for `FakeImagePicker`, where applicable)
3. **Replace** `_FakeXxxRepository(...)` constructor calls with `FakeXxxRepository(...)` using the
   call-site translation table below.
4. **Replace** `_TestException(...)` with `TestException(...)`.
5. **Replace** `_testCity()` / `_city()` with `testCity()`, `_makeEvent()` / `_event()` with
   `makeEvent()`, `_makePlace()` / `_place()` with `makePlace()`. Adjust named parameters to
   match the shared fixture signatures.
6. **Remove** the private fixture functions if fully replaced.

#### Call-site translation table

The shared fakes are constructor-parameter supersets of the local fakes, but some local fakes used
different parameter names. Every renamed parameter is listed here. Parameters not in this table map
directly by name.

| File | Old parameter name | New parameter name | Notes |
|---|---|---|---|
| `sync_use_case_test.dart` | `modifiedAt:` | `lastSyncedAt:` | `_FakeSettingsRepository` only |
| `sync_view_model_test.dart` | `modifiedAt:` | `lastSyncedAt:` | `_FakeSettingsRepository` only |
| `settings_view_model_test.dart` | `initialCrashReporting:` | `crashReporting:` | `_FakeSettingsRepository` only; `setCrashReportingResult:` is unchanged |
| `theme_view_model_test.dart` | `initialType:` | `themeType:` | `_FakeSettingsRepository` only |
| `theme_view_model_test.dart` | `initialBrightness:` | `themeBrightness:` | `_FakeSettingsRepository` only; `setThemeTypeResult:` and `setThemeBrightnessResult:` are unchanged |
| `post_screen_test.dart` | `event: e` | `getByIdResults: {e.remoteId: Result.success(e)}` | `_FakeEventRepository` only; see note below |
| `post_screen_test.dart` | `place: p` | `getByIdResults: {p.remoteId: Result.success(p)}` | `_FakePlaceRepository` only; see note below |
| `events_calendar_test.dart` | `currentYearEvents: list` | `getByCurrentYearResult: Result.success(list)` | `_FakeEventRepository` only |
| `events_calendar_test.dart` | `byDateEvents: list` | `getByDateResult: Result.success(list)` | `_FakeEventRepository` only; unused at call sites but included for completeness |
| `search_view_model_test.dart` | `eventResults:` | `getByIdResults:` | `_FakeEventRepository` only; same type (`Map<int, Result<Event>>`) |
| `weather_view_model_test.dart` | `result:` | `result:` | `_FakeWeatherApiClient`; name unchanged but now optional |
| `weather_forecast_days_list_test.dart` | `result:` | `result:` | Same as above |
| `weather_forecast_hourly_list_test.dart` | `result:` | `result:` | Same as above |
| `post_screen_test.dart` | (no params) | (no params) | `_FakeWeatherApiClient()`; maps to `FakeWeatherApiClient()` directly |

**`post_screen_test.dart` note:** The local fakes used a single required `event:` / `place:`
parameter and returned it for _all_ `getById` calls regardless of `id`. The shared fake uses a
map keyed by `id`. The two call sites in that file already know the specific `id` (they pass
`event.remoteId` / `place.remoteId` elsewhere), so `getByIdResults: {event.remoteId: Result.success(event)}`
is the exact translation. The extra verbosity (~25 characters) is accepted: it makes the intent
explicit and is consistent with every other `getById` use across the test suite.

| # | File | Fakes removed | Fixtures removed | Migration notes |
|---|---|---|---|---|
| 2 | `test/domain/use_cases/sync_use_case_test.dart` | `_FakeCityRepository`, `_FakeEventRepository`, `_FakeMediaRepository`, `_FakePlaceRepository`, `_FakeSettingsRepository`, `_TestException` | — | `_ThrowingTransactionCoordinator` and `_WrappingTransactionCoordinator` stay local. `_FakeTransactionCoordinator` → `FakeTransactionCoordinator`. Rename `modifiedAt:` → `lastSyncedAt:` at all 13 `_FakeSettingsRepository` constructor call sites (lines 65, 93, 119, 145, 171, 201, 233, 248, 264, 271, 280, 291, 299). Replace `_TestException` → `TestException`. |
| 3 | `test/domain/use_cases/mapped_use_cases_test.dart` | `_FakeEventRepository`, `_FakePlaceRepository`, `_TestException` | `_city()`, `_event()`, `_place()` | The local fakes used a single `getByIdResult:` shorthand. The shared fake uses `Map<int, Result<T>>`. Each call site must use the **same integer the test later passes to the use case** as the map key. See the per-call-site table below. Replace `_city()` → `testCity()`, `_event(remoteId: N, name: S)` → `makeEvent(remoteId: N, name: S, category: ContentCategory.history)`, `_place(remoteId: N, name: S)` → `makePlace(remoteId: N, name: S, category: ContentCategory.nature)`. |
| 4 | `test/ui/sync/view_models/sync_view_model_test.dart` | `_FakeCityRepository`, `_FakeEventRepository`, `_FakeMediaRepository`, `_FakePlaceRepository`, `_FakeSettingsRepository`, `_FakeTransactionCoordinator`, `_TestException` | — | `_FakeTransactionCoordinator` → `FakeTransactionCoordinator`. Rename `modifiedAt:` → `lastSyncedAt:`. Replace `_TestException` → `TestException`. |
| 5 | `test/ui/event/view_models/event_view_model_test.dart` | `_FakeEventRepository`, `_TestException` | `_testCity()`, `_event()`, `_eventContent()` | Direct parameter map. Replace fixtures with `testCity()`/`makeEvent()`. Note: `_eventContent()` used `startDate`/`endDate` — translate to `makeEvent(startDate: ..., endDate: ...)`. |
| 6 | `test/ui/event/widgets/components/events_calendar_test.dart` | `_FakeEventRepository` | `_testCity()` | Rename `currentYearEvents: list` → `getByCurrentYearResult: Result.success(list)`. The local fake used `implements EventRepository`; the shared fake uses `extends EventRepository`. Both override all methods explicitly, so the switch is safe. Replace `_testCity()` → `testCity()`. Note: `_buildEvent()` and `_buildEventContent()` have per-test date logic — they stay local (they differ from `makeEvent` in that they require specific `startDate`/`endDate` args for calendar assertions). |
| 7 | `test/ui/post/widgets/post_screen_test.dart` | `_FakeEventRepository`, `_FakePlaceRepository`, `_FakeWeatherApiClient` | — | Translate `event: e` → `getByIdResults: {e.remoteId: Result.success(e)}` and `place: p` → `getByIdResults: {p.remoteId: Result.success(p)}`. `_FakeWeatherApiClient()` → `FakeWeatherApiClient()` (no params = error result by default). |
| 8 | `test/ui/category/view_models/category_view_model_test.dart` | `_FakeEventRepository`, `_FakePlaceRepository`, `_FakeSettingsRepository`, `_TestException` | `_testCity()`, `_event()`, `_place()` | Replace `_FakeSettingsRepository()` → `FakeSettingsRepository()`. Replace fixtures. |
| 9 | `test/ui/search/view_models/search_view_model_test.dart` | `_FakeEventRepository`, `_TestException` | `_testCity()`, `_makeEvent()`, `_makePlaceContent()` | Rename `eventResults:` → `getByIdResults:`. `_FakeSearchRepository` and `_FakeExploreGetByIdUseCase` stay local. Replace fixtures. |
| 10 | `test/ui/settings/view_models/settings_view_model_test.dart` | `_FakeSettingsRepository`, `_TestException` | — | Rename `initialCrashReporting:` → `crashReporting:`. `setCrashReportingResult:` is unchanged. State-toggling behaviour is preserved by the shared fake's `if (result is Success<void>)` guard. |
| 11 | `test/ui/settings/view_models/theme_view_model_test.dart` | `_FakeSettingsRepository`, `_TestException` | — | Rename `initialType:` → `themeType:` and `initialBrightness:` → `themeBrightness:`. `setThemeTypeResult:` and `setThemeBrightnessResult:` are unchanged. State-toggling behaviour is preserved. |
| 12 | `test/ui/core/ui/content/event_formatted_date_time_integration_test.dart` | `_FakeEventRepository`, `_FakePlaceRepository` | `_testCity()` | Local fakes had no constructor parameters; replace with `FakeEventRepository()` and `FakePlaceRepository()` directly. Replace `_testCity()` → `testCity()`. |
| 13 | `test/ui/user_contribution/view_models/user_contribution_view_model_test.dart` | `_FakeUserContributionRepository`, `_FakeImagePicker` | — | Replace with `FakeUserContributionRepository()` and `FakeImagePicker(...)`. Add import for `fake_image_picker.dart`. |
| 14 | `test/ui/user_contribution/widgets/user_contribution_media_uploader_test.dart` | `_FakeUserContributionRepository`, `_FakeImagePicker` | — | Replace with `FakeUserContributionRepository()` and `FakeImagePicker(...)`. The local fake had `upload` returning `Result<dynamic>` (incorrect); the shared fake uses correct `Result<void>`. |
| 15 | `test/ui/weather/view_models/weather_view_model_test.dart` | `_FakeWeatherApiClient`, `_TestException` | — | Replace `_FakeWeatherApiClient(result: x)` → `FakeWeatherApiClient(result: x)`. Replace `_TestException` → `TestException`. |
| 16 | `test/ui/weather/widgets/components/weather_forecast_days_list_test.dart` | `_FakeWeatherApiClient` | — | Replace `_FakeWeatherApiClient(result: x)` → `FakeWeatherApiClient(result: x)`. |
| 17 | `test/ui/weather/widgets/components/weather_forecast_hourly_list_test.dart` | `_FakeWeatherApiClient` | — | Replace `_FakeWeatherApiClient(result: x)` → `FakeWeatherApiClient(result: x)`. |
| 18 | `test/ui/favourite/view_models/favourite_view_model_test.dart` | `_TestException` | `_testCity()`, `_makeEvent()`, `_makePlace()` | Only fixture and exception removal — no fake repository changes. Replace all fixtures. |

#### File #3 — `mapped_use_cases_test.dart`: `getByIdResult:` call-site translation

The local `_FakeEventRepository` and `_FakePlaceRepository` in this file had a `getByIdResult:` parameter (singular `Result<T>`) that was returned for **all** `getById` calls regardless of `id`. The shared fake uses `getByIdResults: Map<int, Result<T>>` and looks up by `id`, so each map key must match the integer the test passes to the use case.

Every use case passes `id` straight through to `repository.getById(id)`, so the key is always the same integer the test provides to the use case method:

| File line | Old | New |
|---|---|---|
| 103–104 | `_FakePlaceRepository(getByIdResult: Result.success(_place(remoteId: 21, ...)))` | `FakePlaceRepository(getByIdResults: {21: Result.success(makePlace(remoteId: 21, ...))})` |
| 121–122 | `_FakePlaceRepository(getByIdResult: Result.error(error))` | `FakePlaceRepository(getByIdResults: {21: Result.error(error)})` |
| 203–204 | `_FakeEventRepository(getByIdResult: Result.success(_event(remoteId: 1, ...)))` | `FakeEventRepository(getByIdResults: {1: Result.success(makeEvent(remoteId: 1, ...))})` |
| 206–207 | `_FakePlaceRepository(getByIdResult: Result.success(_place(remoteId: 2, ...)))` | `FakePlaceRepository(getByIdResults: {2: Result.success(makePlace(remoteId: 2, ...))})` |
| 222–223 | `_FakeEventRepository(getByIdResult: Result.error(eventError))` | `FakeEventRepository(getByIdResults: {1: Result.error(eventError)})` |
| 225–226 | `_FakePlaceRepository(getByIdResult: Result.error(placeError))` | `FakePlaceRepository(getByIdResults: {2: Result.error(placeError)})` |
| 289–290 | `_FakeEventRepository(getByIdResult: Result.success(_event(remoteId: 30, ...)))` | `FakeEventRepository(getByIdResults: {30: Result.success(makeEvent(remoteId: 30, ...))})` |
| 292–293 | `_FakePlaceRepository(getByIdResult: Result.success(_place(remoteId: 31, ...)))` | `FakePlaceRepository(getByIdResults: {31: Result.success(makePlace(remoteId: 31, ...))})` |
| 308–309 | `_FakeEventRepository(getByIdResult: Result.error(eventError))` | `FakeEventRepository(getByIdResults: {1: Result.error(eventError)})` |
| 311–312 | `_FakePlaceRepository(getByIdResult: Result.error(placeError))` | `FakePlaceRepository(getByIdResults: {2: Result.error(placeError)})` |
| 454–455 | `_FakeEventRepository(getByIdResult: Result.success(event))` where `event.remoteId == 50` | `FakeEventRepository(getByIdResults: {50: Result.success(event)})` |
| 472–473 | `_FakeEventRepository(getByIdResult: Result.error(error))` | `FakeEventRepository(getByIdResults: {50: Result.error(error)})` |
| 488–489 | `_FakePlaceRepository(getByIdResult: Result.success(place))` where `place.remoteId == 51` | `FakePlaceRepository(getByIdResults: {51: Result.success(place)})` |
| 506–507 | `_FakePlaceRepository(getByIdResult: Result.error(error))` | `FakePlaceRepository(getByIdResults: {51: Result.error(error)})` |

**Why the keys are safe:** Each test calls `useCase.getEventById(N)` or `useCase.getPlaceById(N)` with a concrete integer, and every use case forwards that integer directly to `repository.getById(N)`. The entity passed in `getByIdResult:` always has `remoteId == N`, so keying by the entity's `remoteId` is equivalent to keying by the call-site integer.

#### Fixture migration notes

Tests that use `_testCity()` / `_city()` with default values map directly to `testCity()`. Tests
that customise `name:` or `remoteId:` pass those through: `testCity(name: 'Custom')`.

Tests that use `_event(remoteId: N, name: S)` or `_makeEvent(N)` map to `makeEvent(remoteId: N, name: S)`.
The `category:` parameter defaults to `ContentCategory.unknown` in the shared fixture; tests in
`mapped_use_cases_test.dart` and `category_view_model_test.dart` used `ContentCategory.history` or
`ContentCategory.nature` — those must pass `category:` explicitly.

Tests that define their own **specialised** fixture with per-test date logic (e.g.,
`_buildEvent(remoteId:, startDate:, endDate:)` in `events_calendar_test.dart`) should keep
their local helper if the date parameterization is the _point_ of the test. Only replace fixtures
where the content is generic "give me any valid model instance".

#### `_TestException` migration notes

All 12 copies are byte-for-byte identical (differing only in the leading underscore). The
migration is mechanical: `_TestException` → `TestException` at all use sites. The file
`test/utils/result_test.dart` defines its own `_TestException` too — include it in migration.

### Remain local (no changes)

These stay as private test-local classes:

- `_ThrowingTransactionCoordinator`, `_WrappingTransactionCoordinator` — test-specific behaviour variants in `sync_use_case_test.dart`
- `_FakeSearchRepository` — only 1 copy, no duplication to fix
- `_FakeExploreGetByIdUseCase` — use-case fake, not a repository
- `_FakeFavouriteGetIdsUseCase` — use-case fake, not a repository; 1 copy only
- `_FakeSettingsLocalDataSource` — data-layer test double for `settings_repository_impl_test`
- `_FakeExternalUrlService`, `_FakeAppInfoService`, `_FakeMapUrlService` — service fakes in `url_launch_service_test`
- `FakeSyncDto`, `FakeSyncEntity`, `StubSyncRepository` — test infrastructure for `BaseSyncRepository` itself
- `FakeToOneRelation`, `FakeEntity` — plain test data in `relation_update_test.dart`
- `FakeTransport` — Sentry transport test double in `app_logger_test.dart`
- `MockSupabase`, `_StubHttpClient`, etc. — already shared in `test/support/mock_supabase.dart`
- `_MockStore`, `_MockEventEntityBox`, `_MockMediaEntityBox` — mocktail mocks for ObjectBox in data-layer tests
- `_buildEvent()`, `_buildEventContent()` in `events_calendar_test.dart` — per-test date logic that is the point of the test
- `_eventContent()` in `event_view_model_test.dart` — if it solely parameterizes `startDate`/`endDate` for date-range assertions, it maps to `makeEvent(startDate:, endDate:)`. Evaluate during implementation.

---

## Execution Order

1. Create `test/support/fake_repositories.dart`
2. Create `test/support/fixtures.dart`
3. Create `test/support/fake_image_picker.dart`
4. Migrate test files #2–#18 one file at a time, running `dart test <file>` after each
5. Run `dart analyze` — expect zero errors
6. Run full test suite — expect all green
7. Run `dart format` on all changed files

---

## Risk Assessment

- **Risk level:** Low
- **Direction:** Consolidating duplicate fakes, fixtures, and utilities into shared implementations — purely structural refactor
- **Breaking changes:** None — shared fakes implement the same interfaces with superset constructors
- **Key risks:**
  - 17 test files must be updated; constructor call sites must be mapped using the
    explicit translation tables above.
  - Files that wrap bare lists in `Result.success(...)` must be verified (e.g. `events_calendar_test`
    wraps bare `List<Event>` in the local fake; the shared fake expects `Result.success(list)` at
    the call site).
  - `_TestException` → `TestException` rename: the shared class is now public. This is fine —
    test files don't export their symbols. If a test accidentally imported another test file's
    private exception before, it would not have compiled anyway.
  - `FakeWeatherApiClient` calls `super(logger: MockLogger(), httpClient: http.Client())`. The
    `http.Client()` is never used (method is overridden), but it satisfies the constructor. If
    `WeatherApiClient`'s constructor changes, only the shared fake needs updating.
- **Rollback:** Single revert commit if anything goes wrong
- **No new dependencies:** The shared fakes are plain Dart classes. `FakeWeatherApiClient` uses
  `MockLogger` from the existing `test/support/mock_logger.dart`. `FakeImagePicker` uses the
  already-depended-upon `image_picker` package.

---

## Metrics

- **Lines removed:** ~1,350 (duplicate fake classes + `_TestException` copies + fixture functions)
- **Lines added:** ~600 (three shared files)
- **Net:** ~750 lines removed
- **New files:** 3
- **Test files modified:** 17
- **Maintenance burden eliminated:**
  - Adding a new method to `EventRepository` now requires updating 1 fake instead of 9
  - Adding a new method to `PlaceRepository` now requires updating 1 fake instead of 6
  - Adding a field to `City`/`Event`/`Place` models now requires updating 1 fixture instead of 6–8
  - `WeatherApiClient` changes require updating 1 fake instead of 4
  - `ImagePicker` API changes require updating 1 fake instead of 2
- **Consistency improved:**
  - All tests use the same `extends EventRepository` pattern — no more hidden `implements`/`extends` mismatches
  - All `setXxx` methods in `FakeSettingsRepository` use the same conditional-update guard
  - `TestException` has a single definition — no more wondering whether to define a new one
  - Model fixtures use consistent defaults across all test files
