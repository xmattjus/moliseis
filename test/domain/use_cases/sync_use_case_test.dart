import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
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
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  _SyncUseCaseDeps buildUseCase({
    required _FakeSettingsRepository settings,
    Result<List<SyncDto>> cityResult = const Result.success([]),
    Result<List<SyncDto>> eventResult = const Result.success([]),
    Result<List<SyncDto>> mediaResult = const Result.success([]),
    Result<List<SyncDto>> placeResult = const Result.success([]),
    SyncTransactionCoordinator? transactionCoordinator,
  }) {
    final cityRepo = _FakeCityRepository(prepareResult: cityResult);
    final eventRepo = _FakeEventRepository(prepareResult: eventResult);
    final mediaRepo = _FakeMediaRepository(prepareResult: mediaResult);
    final placeRepo = _FakePlaceRepository(prepareResult: placeResult);

    final useCase = SyncUseCase(
      cityRepository: cityRepo,
      eventRepository: eventRepo,
      mediaRepository: mediaRepo,
      placeRepository: placeRepo,
      settingsRepository: settings,
      transactionCoordinator:
          transactionCoordinator ?? _FakeTransactionCoordinator(),
    );

    return _SyncUseCaseDeps(
      useCase: useCase,
      cityRepo: cityRepo,
      eventRepo: eventRepo,
      mediaRepo: mediaRepo,
      placeRepo: placeRepo,
      settings: settings,
    );
  }

  group('SyncUseCase.sync', () {
    test(
      'calls commitSync on all repos when all prepareSync calls succeed',
      () async {
        final cityDtos = [_FakeSyncDto(1)];
        final placeDtos = [_FakeSyncDto(2)];
        final eventDtos = [_FakeSyncDto(3)];
        final mediaDtos = [_FakeSyncDto(4)];

        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          settings: settings,
          cityResult: Result.success(cityDtos),
          placeResult: Result.success(placeDtos),
          eventResult: Result.success(eventDtos),
          mediaResult: Result.success(mediaDtos),
        );

        final result = await deps.useCase.sync();

        expect(result.isSuccess, isTrue);
        expect(deps.settings.setModifiedAtCalled, isTrue);
        expect(deps.cityRepo.commitCalled, isTrue);
        expect(deps.cityRepo.committedDtos, equals(cityDtos));
        expect(deps.placeRepo.commitCalled, isTrue);
        expect(deps.placeRepo.committedDtos, equals(placeDtos));
        expect(deps.eventRepo.commitCalled, isTrue);
        expect(deps.eventRepo.committedDtos, equals(eventDtos));
        expect(deps.mediaRepo.commitCalled, isTrue);
        expect(deps.mediaRepo.committedDtos, equals(mediaDtos));
      },
    );

    test(
      'does not call commitSync on any repo when city prepareSync fails',
      () async {
        final error = _TestException('city sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          cityResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setModifiedAtCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'does not call commitSync on any repo when place prepareSync fails',
      () async {
        final error = _TestException('place sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          placeResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setModifiedAtCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'does not call commitSync on any repo when event prepareSync fails',
      () async {
        final error = _TestException('event sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          eventResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setModifiedAtCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'does not call commitSync on any repo when media prepareSync fails',
      () async {
        final error = _TestException('media sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          mediaResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setModifiedAtCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'wraps all commitSync calls inside runInWriteTransaction',
      () async {
        final cityDtos = [_FakeSyncDto(1)];
        final placeDtos = [_FakeSyncDto(2)];
        final eventDtos = [_FakeSyncDto(3)];
        final mediaDtos = [_FakeSyncDto(4)];

        final settings = _FakeSettingsRepository(modifiedAt: null);
        final wrappedCalls = <VoidCall>[];
        final coordinator = _WrappingTransactionCoordinator(wrappedCalls);

        final deps = buildUseCase(
          settings: settings,
          cityResult: Result.success(cityDtos),
          placeResult: Result.success(placeDtos),
          eventResult: Result.success(eventDtos),
          mediaResult: Result.success(mediaDtos),
          transactionCoordinator: coordinator,
        );

        await deps.useCase.sync();

        expect(wrappedCalls, hasLength(1));
        expect(deps.settings.setModifiedAtCalled, isTrue);
        expect(deps.cityRepo.commitCalled, isTrue);
        expect(deps.cityRepo.committedDtos, equals(cityDtos));
        expect(deps.placeRepo.commitCalled, isTrue);
        expect(deps.placeRepo.committedDtos, equals(placeDtos));
        expect(deps.eventRepo.commitCalled, isTrue);
        expect(deps.eventRepo.committedDtos, equals(eventDtos));
        expect(deps.mediaRepo.commitCalled, isTrue);
        expect(deps.mediaRepo.committedDtos, equals(mediaDtos));
      },
    );

    test(
      'does not call setModifiedAt when any prepareSync fails',
      () async {
        final error = _TestException('sync failed');
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          cityResult: Result.error(error),
          settings: settings,
        );

        await deps.useCase.sync();

        expect(deps.settings.setModifiedAtCalled, isFalse);
      },
    );

    test(
      'does not call setModifiedAt when commitSync returns error',
      () async {
        final settings = _FakeSettingsRepository(modifiedAt: null);
        final deps = buildUseCase(
          settings: settings,
          transactionCoordinator: _ThrowingTransactionCoordinator(),
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect(deps.settings.setModifiedAtCalled, isFalse);
      },
    );
  });

  group('SyncUseCase.isSyncRequired', () {
    test('returns true when modifiedAt is null (never synced)', () {
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.isSyncRequired, isTrue);
    });

    test('returns false when last sync was less than 3 days ago', () {
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.isSyncRequired, isFalse);
    });

    test('returns true when last sync was more than 3 days ago', () {
      final settings = _FakeSettingsRepository(
        modifiedAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.isSyncRequired, isTrue);
    });
  });

  group('SyncUseCase.lastSyncedAt', () {
    test('returns null when settings has no modifiedAt', () {
      final settings = _FakeSettingsRepository(modifiedAt: null);
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.lastSyncedAt, isNull);
    });

    test('returns the modifiedAt value from settings repository', () {
      final date = DateTime.now().subtract(const Duration(days: 1));
      final settings = _FakeSettingsRepository(modifiedAt: date);
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.lastSyncedAt, equals(date));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

final class _FakeSyncDto implements SyncDto {
  _FakeSyncDto(this.id);

  @override
  final int id;

  @override
  DateTime get modifiedAt => DateTime(2025);

  @override
  DateTime? get deletedAt => null;
}

final class _SyncUseCaseDeps {
  _SyncUseCaseDeps({
    required this.useCase,
    required this.cityRepo,
    required this.eventRepo,
    required this.mediaRepo,
    required this.placeRepo,
    required this.settings,
  });

  final SyncUseCase useCase;
  final _FakeCityRepository cityRepo;
  final _FakeEventRepository eventRepo;
  final _FakeMediaRepository mediaRepo;
  final _FakePlaceRepository placeRepo;
  final _FakeSettingsRepository settings;
}

final class VoidCall {
  VoidCall();
}

final class _FakeTransactionCoordinator implements SyncTransactionCoordinator {
  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) => fn();
}

final class _ThrowingTransactionCoordinator
    implements SyncTransactionCoordinator {
  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    return Result.error(_TestException('commit failed'));
  }
}

final class _WrappingTransactionCoordinator
    implements SyncTransactionCoordinator {
  _WrappingTransactionCoordinator(this._calls);

  final List<VoidCall> _calls;

  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    _calls.add(VoidCall());
    return fn();
  }
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _FakeCityRepository extends CityRepository {
  _FakeCityRepository({
    this.prepareResult = const Result.success([]),
  });

  final Result<List<SyncDto>> prepareResult;
  bool commitCalled = false;
  List<SyncDto>? committedDtos;

  @override
  Future<Result<List<SyncDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<SyncDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }
}

final class _FakeEventRepository extends EventRepository {
  _FakeEventRepository({
    this.prepareResult = const Result.success([]),
  });

  final Result<List<SyncDto>> prepareResult;
  bool commitCalled = false;
  List<SyncDto>? committedDtos;

  @override
  Future<Result<List<SyncDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<SyncDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

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
  _FakeMediaRepository({
    this.prepareResult = const Result.success([]),
  });

  final Result<List<SyncDto>> prepareResult;
  bool commitCalled = false;
  List<SyncDto>? committedDtos;

  @override
  Future<Result<List<SyncDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<SyncDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Media>>> getByEventId(int id) async =>
      const Result.success(<Media>[]);

  @override
  Future<Result<List<Media>>> getByPlaceId(int id) async =>
      const Result.success(<Media>[]);
}

final class _FakePlaceRepository extends PlaceRepository {
  _FakePlaceRepository({
    this.prepareResult = const Result.success([]),
  });

  final Result<List<SyncDto>> prepareResult;
  bool commitCalled = false;
  List<SyncDto>? committedDtos;

  @override
  Future<Result<List<SyncDto>>> prepareSync() async => prepareResult;

  @override
  Result<void> commitSync(List<SyncDto> dtos) {
    commitCalled = true;
    committedDtos = dtos;
    return const Result.success(null);
  }

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
