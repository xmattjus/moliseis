import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('CategoryViewModel', () {
    group('_load via filtered path (CategoryUseCase)', () {
      test('populates content when both places and events succeed', () async {
        final place1 = _place(remoteId: 1, name: 'Castle');
        final event1 = _event(remoteId: 2, name: 'Festival');
        final vm = buildViewModel(
          placesByCategoryResult: Result.success([place1]),
          eventsByCategoryResult: Result.success([event1]),
        );

        await vm.load.execute();

        expect(vm.load.completed, isTrue);
        expect(vm.content, hasLength(2));
      });

      test(
        'early-returns and skips event fetch when place fetch fails',
        () async {
          final eventRepo = _FakeEventRepository();
          final placeRepo = _FakePlaceRepository(
            getByCategoriesResult: Result.error(
              _TestException('places failed'),
            ),
          );
          final vm = CategoryViewModel(
            categoryUseCase: CategoryUseCase(
              eventRepository: eventRepo,
              placeRepository: placeRepo,
            ),
            exploreGetByIdUseCase: ExploreUseCase(
              eventRepository: eventRepo,
              placeRepository: placeRepo,
            ),
            settingsRepository: _FakeSettingsRepository(),
          );

          await vm.load.execute();

          expect(vm.load.error, isTrue);
          expect(vm.content, isEmpty);
          // Event repository must not have been queried for categories.
          expect(eventRepo.getByCategoriesCallCount, 0);
        },
      );

      test(
        'surfaces error when event fetch fails after successful place fetch',
        () async {
          final vm = buildViewModel(
            placesByCategoryResult: const Result.success(<Place>[]),
            eventsByCategoryResult: Result.error(
              _TestException('events failed'),
            ),
          );

          await vm.load.execute();

          expect(vm.load.error, isTrue);
        },
      );
    });

    group('setSelectedCategories', () {
      test('is a no-op when categories are unchanged', () async {
        final eventRepo = _FakeEventRepository();
        final placeRepo = _FakePlaceRepository();
        final vm = CategoryViewModel(
          categoryUseCase: CategoryUseCase(
            eventRepository: eventRepo,
            placeRepository: placeRepo,
          ),
          exploreGetByIdUseCase: ExploreUseCase(
            eventRepository: eventRepo,
            placeRepository: placeRepo,
          ),
          settingsRepository: _FakeSettingsRepository(),
        );

        // Set categories once, then set again with the same value.
        await vm.setSelectedCategories.execute({ContentCategory.history});
        final callsAfterFirst = eventRepo.getByCategoriesCallCount;
        await vm.setSelectedCategories.execute({ContentCategory.history});

        expect(
          eventRepo.getByCategoriesCallCount,
          callsAfterFirst,
          reason: 'second call with same categories must not trigger a load',
        );
      });
    });

    group('setSelectedTypes', () {
      test(
        'loads only places when only ContentType.place is selected',
        () async {
          final place1 = _place(remoteId: 2, name: 'Castle');
          final vm = buildViewModel(
            placesByCategoryResult: Result.success([place1]),
            eventsByCategoryResult: const Result.success(<Event>[]),
          );

          // setSelectedTypes internally triggers load; no extra execute needed.
          await vm.setSelectedTypes.execute({ContentType.place});

          expect(vm.content.every((c) => c is Place), isTrue);
        },
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

/// Builds a [CategoryViewModel] wired to fakes.
///
/// By default [selectedCategories] is empty, routing [_load] through
/// [CategoryUseCase] (filtered path) rather than [ExploreUseCase] (all path).
CategoryViewModel buildViewModel({
  Result<List<Event>>? eventsByCategoryResult,
  Result<List<Place>>? placesByCategoryResult,
  Result<List<Event>>? allEventsResult,
  Result<List<Place>>? allPlacesResult,
}) {
  final eventRepo = _FakeEventRepository(
    getByCategoriesResult:
        eventsByCategoryResult ?? const Result.success(<Event>[]),
    getByCurrentYearResult: allEventsResult ?? const Result.success(<Event>[]),
  );
  final placeRepo = _FakePlaceRepository(
    getByCategoriesResult:
        placesByCategoryResult ?? const Result.success(<Place>[]),
    getAllResult: allPlacesResult ?? const Result.success(<Place>[]),
  );

  return CategoryViewModel(
    categoryUseCase: CategoryUseCase(
      eventRepository: eventRepo,
      placeRepository: placeRepo,
    ),
    exploreGetByIdUseCase: ExploreUseCase(
      eventRepository: eventRepo,
      placeRepository: placeRepo,
    ),
    settingsRepository: _FakeSettingsRepository(),
  );
}

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

final class _FakeEventRepository extends EventRepository {
  _FakeEventRepository({
    this.getByCategoriesResult = const Result.success(<Event>[]),
    this.getByCurrentYearResult = const Result.success(<Event>[]),
  });

  final Result<List<Event>> getByCategoriesResult;
  final Result<List<Event>> getByCurrentYearResult;
  int getByCategoriesCallCount = 0;

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    getByCategoriesCallCount++;
    return getByCategoriesResult;
  }

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      getByCurrentYearResult;

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<Event>> getById(int id) async =>
      Result.error(_TestException('not configured'));

  @override
  Future<Result<List<int>>> getNextEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

final class _FakePlaceRepository extends PlaceRepository {
  _FakePlaceRepository({
    this.getByCategoriesResult = const Result.success(<Place>[]),
    this.getAllResult = const Result.success(<Place>[]),
  });

  final Result<List<Place>> getByCategoriesResult;
  final Result<List<Place>> getAllResult;

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => getByCategoriesResult;

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async => getAllResult;

  @override
  Future<Result<List<Place>>> getByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<Place>[]);

  @override
  Future<Result<Place>> getById(int id) async =>
      Result.error(_TestException('not configured'));

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

final class _FakeSettingsRepository implements SettingsRepository {
  @override
  ContentSort get contentSort => ContentSort.byName;

  @override
  bool get crashReporting => false;

  @override
  ThemeBrightness get themeBrightness => ThemeBrightness.system;

  @override
  ThemeType get themeType => ThemeType.system;

  @override
  DateTime? get lastSyncedAt => null;

  @override
  Future<Result<void>> initialize() async => const Result.success(null);

  @override
  Future<Result<void>> setCrashReporting(bool enable) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setThemeType(ThemeType type) async =>
      const Result.success(null);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

City _testCity() => City(
  remoteId: 0,
  name: 'Molise',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
);

Event _event({required int remoteId, required String name}) {
  final now = DateTime.utc(2026, 4, 7);
  return Event(
    remoteId: remoteId,
    name: name,
    description: 'Description',
    startDate: now,
    coordinates: const LatLng(41.9, 14.7),
    category: ContentCategory.history,
    createdAt: now,
    modifiedAt: now,
    city: _testCity(),
    media: const [],
    isSaved: false,
  );
}

Place _place({required int remoteId, required String name}) {
  final now = DateTime.utc(2026, 4, 7);
  return Place(
    remoteId: remoteId,
    name: name,
    description: 'Description',
    coordinates: const LatLng(41.9, 14.7),
    category: ContentCategory.nature,
    createdAt: now,
    modifiedAt: now,
    city: _testCity(),
    media: const [],
    isSaved: false,
  );
}

// ---------------------------------------------------------------------------
// Test exception
// ---------------------------------------------------------------------------

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
