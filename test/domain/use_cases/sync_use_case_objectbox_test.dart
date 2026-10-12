import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/objectbox_sync_transaction_coordinator.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';
import '../../support/sync_integration_test_support.dart';

void main() {
  setUpAll(setUpMockSupabase);
  final oldMarker = DateTime.utc(2026, 10, 10, 10);
  final oldCompletion = DateTime.utc(2026, 10, 10, 11);
  final serverCursor = DateTime.utc(2026, 10, 12, 12);
  final remoteMarker = serverCursor.add(const Duration(hours: 1));
  final completion = DateTime.utc(2026, 10, 12, 14);
  late TestObjectBoxEnvironment env;
  late SettingsRepositoryImpl settings;
  late FailNextSettingsSave source;
  late FailingWriteMediaRepository mediaRepository;
  late MockLogger logger;
  late SyncUseCase useCase;

  setUp(() async {
    env = await TestObjectBoxEnvironment.create();
    env.store.box<AppSettings>().put(
      AppSettings(lastSyncedAt: oldCompletion, contentSyncCursorAt: oldMarker),
    );
    env.store.box<CityEntity>().put(
      makeCityEntity(remoteId: 1, name: 'Old city', modifiedAt: oldMarker),
    );
    env.store.box<PlaceEntity>().put(
      makePlaceEntity(
        remoteId: 1,
        name: 'Old place',
        cityId: 1,
        modifiedAt: oldMarker,
        isSaved: true,
      ),
    );
    env.store.box<EventEntity>().put(
      makeEventEntity(
        remoteId: 1,
        name: 'Old event',
        cityId: 1,
        modifiedAt: oldMarker,
      ).copyWith(isSaved: true),
    );
    env.store.box<MediaEntity>().put(
      makeMediaEntity(title: 'Old media', eventId: 1, modifiedAt: oldMarker),
    );
    source = FailNextSettingsSave(SettingsLocalDataSource(env.store));
    settings = SettingsRepositoryImpl(source);
    await settings.initialize();
    logger = MockLogger();
    final common = <String, dynamic>{
      'created_at': DateTime.utc(2026).toIso8601String(),
      'modified_at': remoteMarker.toIso8601String(),
      'deleted_at': null,
    };
    final cities = MockSupabaseEnvironment()
      ..stubSelectResponse([
        for (final id in [1, 2]) {...common, 'id': id, 'name': 'New city $id'},
      ]);
    final places = MockSupabaseEnvironment()
      ..stubSelectResponse([
        for (final id in [1, 2])
          {
            ...common,
            'id': id,
            'name': 'New place $id',
            'description': 'Place text',
            'latitude': 41.0,
            'longitude': 14.0,
            'category': 'unknown',
            'city_id': id,
          },
      ]);
    final events = MockSupabaseEnvironment()
      ..stubSelectResponse([
        for (final id in [1, 2])
          {
            ...common,
            'id': id,
            'name': 'New event $id',
            'description': 'Event text',
            'start_date': DateTime.utc(2026, 10, 15).toIso8601String(),
            'latitude': 41.0,
            'longitude': 14.0,
            'category': 'unknown',
            'city_id': id,
          },
      ]);
    final media = MockSupabaseEnvironment()
      ..stubSelectResponse([
        for (final id in [1, 2])
          {
            ...common,
            'id': id,
            'description': 'New media $id',
            'url': 'https://cdn.example.com/new$id.jpg',
            'width': 900,
            'height': 700,
            'event_id': id,
            'place_id': null,
          },
      ]);
    final objectBox = TestObjectBox(env.store);
    mediaRepository = FailingWriteMediaRepository(
      logger: logger,
      supabaseI: media.mockSupabase,
      objectBoxI: objectBox,
    );
    useCase = SyncUseCase(
      cityRepository: CityRepositoryImpl(
        logger: logger,
        supabaseI: cities.mockSupabase,
        objectBoxI: objectBox,
      ),
      placeRepository: PlaceRepositoryImpl(
        logger: logger,
        supabaseI: places.mockSupabase,
        objectBoxI: objectBox,
      ),
      eventRepository: EventRepositoryImpl(
        logger: logger,
        supabaseI: events.mockSupabase,
        objectBoxI: objectBox,
      ),
      mediaRepository: mediaRepository,
      settingsRepository: settings,
      transactionCoordinator: ObjectBoxSyncTransactionCoordinator(env.store),
      cursorSource: FakeSyncCursorSource(result: Result.success(serverCursor)),
      now: () => completion,
    );
  });

  tearDown(() => env.dispose());

  test(
    'late media failure rolls back staged changes in all four real boxes',
    () async {
      var observedStaging = false;
      mediaRepository
        ..failAfterWrite = true
        ..afterWrite = () {
          observedStaging = true;
          expect(env.store.box<CityEntity>().get(1)!.name, 'New city 1');
          expect(env.store.box<PlaceEntity>().get(1)!.name, 'New place 1');
          expect(env.store.box<EventEntity>().get(1)!.name, 'New event 1');
          expect(env.store.box<MediaEntity>().get(1)!.title, 'New media 1');
          expect(env.store.box<CityEntity>().get(2), isNotNull);
          expect(env.store.box<PlaceEntity>().get(2), isNotNull);
          expect(env.store.box<EventEntity>().get(2), isNotNull);
          expect(env.store.box<MediaEntity>().get(2), isNotNull);
        };
      final result = await useCase.sync();
      expect(result, isA<Error<void>>());
      expect(observedStaging, isTrue);
      expect(env.store.box<CityEntity>().get(1)!.name, 'Old city');
      expect(env.store.box<PlaceEntity>().get(1)!.name, 'Old place');
      expect(env.store.box<EventEntity>().get(1)!.name, 'Old event');
      expect(env.store.box<MediaEntity>().get(1)!.title, 'Old media');
      expect(env.store.box<CityEntity>().get(2), isNull);
      expect(env.store.box<PlaceEntity>().get(2), isNull);
      expect(env.store.box<EventEntity>().get(2), isNull);
      expect(env.store.box<MediaEntity>().get(2), isNull);
      expect(env.store.box<EventEntity>().get(1)!.isSaved, isTrue);
      expect(env.store.box<PlaceEntity>().get(1)!.isSaved, isTrue);
      expect(source.saves, 0);
      expect(settings.contentSyncCursorAt?.toUtc(), oldMarker);
      expect(settings.lastSyncedAt?.toUtc(), oldCompletion);
      final disk = env.store.box<AppSettings>().get(1)!;
      expect(disk.contentSyncCursorAt?.toUtc(), oldMarker);
      expect(disk.lastSyncedAt?.toUtc(), oldCompletion);
    },
  );

  test(
    'settings failure retains old authority; retry replays idempotently',
    () async {
      source.failNextSave = true;
      expect(await useCase.sync(), isA<Error<void>>());
      expect(source.saves, 1);
      expect(settings.contentSyncCursorAt?.toUtc(), oldMarker);
      expect(settings.lastSyncedAt?.toUtc(), oldCompletion);
      final oldDisk = env.store.box<AppSettings>().get(1)!;
      expect(oldDisk.contentSyncCursorAt?.toUtc(), oldMarker);
      expect(oldDisk.lastSyncedAt?.toUtc(), oldCompletion);
      expect(env.store.box<CityEntity>().get(1)!.name, 'New city 1');
      expect(env.store.box<PlaceEntity>().get(1)!.name, 'New place 1');
      expect(env.store.box<EventEntity>().get(1)!.name, 'New event 1');
      expect(env.store.box<MediaEntity>().get(1)!.title, 'New media 1');
      expect(
        env.store.box<EventEntity>().get(1)!.modifiedAt.toUtc(),
        remoteMarker,
      );
      expect(env.store.box<EventEntity>().get(1)!.isSaved, isTrue);
      expect(env.store.box<PlaceEntity>().get(1)!.isSaved, isTrue);
      logger.reset();
      var replayWroteMedia = false;
      mediaRepository.afterWrite = () => replayWroteMedia = true;
      expect(await useCase.sync(), isA<Success<void>>());
      expect(source.saves, 2);
      expect(replayWroteMedia, isFalse);
      expect(logger.eventsOfType<EntityUpdateSuccess>(), isEmpty);
      expect(logger.eventsOfType<EntityInsertSuccess>(), isEmpty);
      expect(logger.eventsOfType<EntityDeleteSuccess>(), isEmpty);
      expect(env.store.box<CityEntity>().count(), 2);
      expect(env.store.box<PlaceEntity>().count(), 2);
      expect(env.store.box<EventEntity>().count(), 2);
      expect(env.store.box<MediaEntity>().count(), 2);
      expect(env.store.box<EventEntity>().get(1)!.city.targetId, 1);
      expect(env.store.box<PlaceEntity>().get(1)!.city.targetId, 1);
      expect(env.store.box<MediaEntity>().get(1)!.event.targetId, 1);
      expect(env.store.box<EventEntity>().get(1)!.isSaved, isTrue);
      expect(env.store.box<PlaceEntity>().get(1)!.isSaved, isTrue);
      expect(settings.contentSyncCursorAt?.toUtc(), serverCursor);
      expect(settings.lastSyncedAt?.toUtc(), completion);
      final disk = env.store.box<AppSettings>().get(1)!;
      expect(disk.contentSyncCursorAt?.toUtc(), serverCursor);
      expect(disk.lastSyncedAt?.toUtc(), completion);
    },
  );
}
