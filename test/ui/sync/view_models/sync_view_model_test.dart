import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/data/sources/place.dart';
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
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  // Builds a SyncUseCase with configurable synchronize() results and settings.
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

  group('SyncViewModel constructor', () {
    test('does not auto-execute when isSyncRequired is false', () {
      // modifiedAt 1 day ago → isSyncRequired = false
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final viewModel = SyncViewModel(syncUseCase: buildUseCase(settings: settings));

      expect(viewModel.sync.running, isFalse);
      expect(viewModel.sync.completed, isFalse);
      expect(viewModel.sync.error, isFalse);
    });

    test('auto-executes and completes when isSyncRequired is true', () async {
      // modifiedAt null → isSyncRequired = true → constructor triggers execute
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final viewModel = SyncViewModel(syncUseCase: buildUseCase(settings: settings));

      await pumpEventQueue();

      expect(viewModel.sync.completed, isTrue);
      expect(settings.setModifiedAtCalled, isTrue);
    });
  });

  group('SyncViewModel.sync success', () {
    test('completed is true and fatalError is false after successful sync',
        () async {
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final viewModel = SyncViewModel(syncUseCase: buildUseCase(settings: settings));

      await pumpEventQueue();

      expect(viewModel.sync.completed, isTrue);
      expect(viewModel.fatalError, isFalse);
    });
  });

  group('SyncViewModel.sync error', () {
    test('sets fatalError when error occurs with no prior successful sync',
        () async {
      // modifiedAt null → isSyncRequired = true and no prior sync data
      final error = _TestException('sync failed');
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(
          cityResult: Result.error(error),
          settings: settings,
        ),
      );

      await pumpEventQueue();

      expect(viewModel.sync.error, isTrue);
      expect(viewModel.fatalError, isTrue);
    });

    test('does not set fatalError when error occurs with a prior successful sync',
        () async {
      // modifiedAt 1 day ago → isSyncRequired = false, so force=true is needed
      final error = _TestException('sync failed');
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(
          cityResult: Result.error(error),
          settings: settings,
        ),
      );

      await viewModel.sync.execute(true);

      expect(viewModel.sync.error, isTrue);
      expect(viewModel.fatalError, isFalse);
    });
  });

  group('SyncViewModel.sync force flag', () {
    test('force=true syncs even when isSyncRequired is false', () async {
      // modifiedAt 1 day ago → isSyncRequired = false → no auto-execute
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final viewModel = SyncViewModel(syncUseCase: buildUseCase(settings: settings));

      await viewModel.sync.execute(true);

      expect(viewModel.sync.completed, isTrue);
      // setModifiedAt is only called when the underlying sync() actually runs
      expect(settings.setModifiedAtCalled, isTrue);
    });

    test('force=false skips sync and returns success when isSyncRequired is false',
        () async {
      // modifiedAt 1 day ago → isSyncRequired = false → no auto-execute
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final viewModel = SyncViewModel(syncUseCase: buildUseCase(settings: settings));

      await viewModel.sync.execute(false);

      expect(viewModel.sync.completed, isTrue);
      // No actual network sync occurred
      expect(settings.setModifiedAtCalled, isFalse);
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
  DateTime? get modifiedAt => _modifiedAt;

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
