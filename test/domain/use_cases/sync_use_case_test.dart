import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/fake_repositories.dart';

void main() {
  _SyncUseCaseDeps buildUseCase({
    required FakeSettingsRepository settings,
    Result<List<CityDto>> cityResult = const Result.success([]),
    Result<List<EventDto>> eventResult = const Result.success([]),
    Result<List<MediaDto>> mediaResult = const Result.success([]),
    Result<List<PlaceDto>> placeResult = const Result.success([]),
    SyncTransactionCoordinator? transactionCoordinator,
  }) {
    final cityRepo = FakeCityRepository(prepareResult: cityResult);
    final eventRepo = FakeEventRepository(prepareResult: eventResult);
    final mediaRepo = FakeMediaRepository(prepareResult: mediaResult);
    final placeRepo = FakePlaceRepository(prepareResult: placeResult);

    final useCase = SyncUseCase(
      cityRepository: cityRepo,
      eventRepository: eventRepo,
      mediaRepository: mediaRepo,
      placeRepository: placeRepo,
      settingsRepository: settings,
      transactionCoordinator:
          transactionCoordinator ?? FakeTransactionCoordinator(),
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
        final cityDtos = [_cityDto(1)];
        final placeDtos = [_placeDto(2)];
        final eventDtos = [_eventDto(3)];
        final mediaDtos = [_mediaDto(4)];

        final settings = FakeSettingsRepository();
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
        final error = TestException('city sync failed');
        final settings = FakeSettingsRepository();
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
        final error = TestException('place sync failed');
        final settings = FakeSettingsRepository();
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
        final error = TestException('event sync failed');
        final settings = FakeSettingsRepository();
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
        final error = TestException('media sync failed');
        final settings = FakeSettingsRepository();
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
        final cityDtos = [_cityDto(1)];
        final placeDtos = [_placeDto(2)];
        final eventDtos = [_eventDto(3)];
        final mediaDtos = [_mediaDto(4)];

        final settings = FakeSettingsRepository();
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
        final error = TestException('sync failed');
        final settings = FakeSettingsRepository();
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
        final settings = FakeSettingsRepository();
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
      final settings = FakeSettingsRepository();
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.isSyncRequired, isTrue);
    });

    test('returns false when last sync was less than 3 days ago', () {
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.isSyncRequired, isFalse);
    });

    test('returns true when last sync was more than 3 days ago', () {
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.isSyncRequired, isTrue);
    });
  });

  group('SyncUseCase.lastSyncedAt', () {
    test('returns null when settings has no modifiedAt', () {
      final settings = FakeSettingsRepository();
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.lastSyncedAt, isNull);
    });

    test('returns the modifiedAt value from settings repository', () {
      final date = DateTime.now().subtract(const Duration(days: 1));
      final settings = FakeSettingsRepository(lastSyncedAt: date);
      final deps = buildUseCase(settings: settings);

      expect(deps.useCase.lastSyncedAt, equals(date));
    });
  });
}

// ---------------------------------------------------------------------------
// DTO factories
// ---------------------------------------------------------------------------

CityDto _cityDto(int id) => CityDto(
  id: id,
  name: 'Test City $id',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

PlaceDto _placeDto(int id) => PlaceDto(
  id: id,
  name: 'Test Place $id',
  description: '',
  latitude: 0,
  longitude: 0,
  category: ContentCategory.nature,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

EventDto _eventDto(int id) => EventDto(
  id: id,
  name: 'Test Event $id',
  description: '',
  startDate: DateTime(2026),
  latitude: 0,
  longitude: 0,
  category: ContentCategory.nature,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

MediaDto _mediaDto(int id) => MediaDto(
  id: id,
  url: 'https://example.com/$id.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

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
  final FakeCityRepository cityRepo;
  final FakeEventRepository eventRepo;
  final FakeMediaRepository mediaRepo;
  final FakePlaceRepository placeRepo;
  final FakeSettingsRepository settings;
}

final class VoidCall {
  VoidCall();
}

final class _ThrowingTransactionCoordinator
    implements SyncTransactionCoordinator {
  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    return Result.error(TestException('commit failed'));
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
