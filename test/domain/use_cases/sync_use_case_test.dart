import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/event.dart';
import 'package:moliseis/data/data-sources/media.dart';
import 'package:moliseis/data/data-sources/place.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  SyncUseCase buildUseCase({
    Result<void> cityResult = const Result.success(null),
    Result<void> eventResult = const Result.success(null),
    Result<void> mediaResult = const Result.success(null),
    Result<void> placeResult = const Result.success(null),
    required _FakeSettingsRepository settings,
  }) {
    return SyncUseCase(
      cityRepository: _FakeCityRepository(synchronizeResult: cityResult),
      eventRepository: _FakeEventRepository(synchronizeResult: eventResult),
      mediaRepository: _FakeMediaRepository(synchronizeResult: mediaResult),
      placeRepository: _FakePlaceRepository(synchronizeResult: placeResult),
      settingsRepository: settings,
    );
  }

  group('SyncUseCase.sync', () {
    test(
      'returns success and records setModifiedAt when all repos succeed',
      () async {
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final useCase = buildUseCase(settings: settings);

        final result = await useCase.sync();

        expect(result.isSuccess, isTrue);
        expect(settings.setModifiedAtCalled, isTrue);
      },
    );

    test(
      'returns error and skips setModifiedAt when city repository fails',
      () async {
        final error = _TestException('city sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final useCase = buildUseCase(
          cityResult: Result.error(error),
          settings: settings,
        );

        final result = await useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(settings.setModifiedAtCalled, isFalse);
      },
    );

    test(
      'returns error and skips setModifiedAt when place repository fails',
      () async {
        final error = _TestException('place sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final useCase = buildUseCase(
          placeResult: Result.error(error),
          settings: settings,
        );

        final result = await useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(settings.setModifiedAtCalled, isFalse);
      },
    );

    test(
      'returns error and skips setModifiedAt when event repository fails',
      () async {
        final error = _TestException('event sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final useCase = buildUseCase(
          eventResult: Result.error(error),
          settings: settings,
        );

        final result = await useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(settings.setModifiedAtCalled, isFalse);
      },
    );

    test(
      'returns error and skips setModifiedAt when media repository fails',
      () async {
        final error = _TestException('media sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final useCase = buildUseCase(
          mediaResult: Result.error(error),
          settings: settings,
        );

        final result = await useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(settings.setModifiedAtCalled, isFalse);
      },
    );
  });

  group('SyncUseCase.isSyncRequired', () {
    test('returns true when modifiedAt is null (never synced)', () {
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final useCase = buildUseCase(settings: settings);

      expect(useCase.isSyncRequired, isTrue);
    });

    test('returns false when last sync was less than 3 days ago', () {
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final useCase = buildUseCase(settings: settings);

      expect(useCase.isSyncRequired, isFalse);
    });

    test('returns true when last sync was more than 3 days ago', () {
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      final useCase = buildUseCase(settings: settings);

      expect(useCase.isSyncRequired, isTrue);
    });
  });

  group('SyncUseCase.lastSyncedAt', () {
    test('returns null when settings has no modifiedAt', () {
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final useCase = buildUseCase(settings: settings);

      expect(useCase.lastSyncedAt, isNull);
    });

    test('returns the modifiedAt value from settings repository', () {
      final date = DateTime.now().subtract(const Duration(days: 1));
      final settings = _FakeSettingsRepository(modifiedAt: date);
      final useCase = buildUseCase(settings: settings);

      expect(useCase.lastSyncedAt, equals(date));
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _FakeCityRepository extends CityRepository {
  _FakeCityRepository({this.synchronizeResult = const Result.success(null)});

  final Result<void> synchronizeResult;

  @override
  Future<Result<void>> synchronize() async => synchronizeResult;
}

final class _FakeEventRepository extends EventRepository {
  _FakeEventRepository({this.synchronizeResult = const Result.success(null)});

  final Result<void> synchronizeResult;

  @override
  Future<Result<void>> synchronize() async => synchronizeResult;

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Event>[]);

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
}

final class _FakeMediaRepository extends MediaRepository {
  _FakeMediaRepository({this.synchronizeResult = const Result.success(null)});

  final Result<void> synchronizeResult;

  @override
  Future<Result<void>> synchronize() async => synchronizeResult;

  @override
  Future<Result<List<Media>>> getByEventId(int id) async =>
      const Result.success(<Media>[]);

  @override
  Future<Result<List<Media>>> getByPlaceId(int id) async =>
      const Result.success(<Media>[]);
}

final class _FakePlaceRepository extends PlaceRepository {
  _FakePlaceRepository({this.synchronizeResult = const Result.success(null)});

  final Result<void> synchronizeResult;

  @override
  Future<Result<void>> synchronize() async => synchronizeResult;

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Place>[]);

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Place>[]);

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
}

final class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({required DateTime? modifiedAt})
    : _modifiedAt = modifiedAt;

  DateTime? _modifiedAt;
  bool setModifiedAtCalled = false;

  @override
  DateTime? get lastSyncedAt => _modifiedAt;

  @override
  bool get crashReporting => false;

  @override
  ContentSort get contentSort => ContentSort.byName;

  @override
  ThemeBrightness get themeBrightness => ThemeBrightness.system;

  @override
  ThemeType get themeType => ThemeType.system;

  @override
  Future<Result<void>> initialize() async => const Result.success(null);

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async {
    _modifiedAt = dateTime;
    setModifiedAtCalled = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setCrashReporting(bool enable) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setThemeType(ThemeType type) async =>
      const Result.success(null);
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
