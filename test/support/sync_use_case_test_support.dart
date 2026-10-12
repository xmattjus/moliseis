import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'fake_repositories.dart';

SyncUseCaseDeps buildSyncUseCase({
  required FakeSettingsRepository settings,
  Result<List<CityDto>> cityResult = const Result.success([]),
  Result<List<EventDto>> eventResult = const Result.success([]),
  Result<List<MediaDto>> mediaResult = const Result.success([]),
  Result<List<PlaceDto>> placeResult = const Result.success([]),
  SyncTransactionCoordinator? transactionCoordinator,
  FakeSyncCursorSource? cursorSource,
  DateTime Function()? now,
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
    cursorSource: cursorSource ?? FakeSyncCursorSource(),
    now: now,
    transactionCoordinator:
        transactionCoordinator ?? FakeTransactionCoordinator(),
  );

  return SyncUseCaseDeps(
    useCase: useCase,
    cityRepo: cityRepo,
    eventRepo: eventRepo,
    mediaRepo: mediaRepo,
    placeRepo: placeRepo,
    settings: settings,
  );
}

// ---------------------------------------------------------------------------
// DTO factories
// ---------------------------------------------------------------------------

CityDto syncCityDto(int id) => CityDto(
  id: id,
  name: 'Test City $id',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

PlaceDto syncPlaceDto(int id) => PlaceDto(
  id: id,
  name: 'Test Place $id',
  description: '',
  latitude: 0,
  longitude: 0,
  category: ContentCategory.nature,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

EventDto syncEventDto(int id) => EventDto(
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

MediaDto syncMediaDto(int id) => MediaDto(
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

final class SyncUseCaseDeps {
  SyncUseCaseDeps({
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

final class FailingSyncTransactionCoordinator
    implements SyncTransactionCoordinator {
  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    return Result.error(TestException('commit failed'));
  }
}

final class RecordingSyncTransactionCoordinator
    implements SyncTransactionCoordinator {
  RecordingSyncTransactionCoordinator(this._calls);

  final List<VoidCall> _calls;

  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    _calls.add(VoidCall());
    return fn();
  }
}
