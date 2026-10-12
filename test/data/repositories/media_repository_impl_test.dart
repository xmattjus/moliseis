// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/mock_objectbox.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(setUpMockSupabase);

  test('Media remote nulls persist through lifecycle and replay', () async {
    final environment = await TestObjectBoxEnvironment.create();
    addTearDown(environment.dispose);
    final remote = MockSupabaseEnvironment();
    final repository = MediaRepositoryImpl(
      logger: MockLogger(),
      supabaseI: remote.mockSupabase,
      objectBoxI: TestObjectBox(environment.store),
    );
    final box = environment.store.box<MediaEntity>();
    var previousDeleted = false;
    box.put(
      makeMediaEntity(
        title: 'Old',
        author: 'Old',
        license: 'Old',
        licenseUrl: 'Old',
        eventId: 7,
        modifiedAt: DateTime.utc(2024),
        isDeleted: previousDeleted,
      ),
    );
    for (final state in [
      (2025, false),
      (2026, true),
      (2027, true),
      (2028, false),
    ]) {
      // A non-null local value demonstrates each lifecycle merge clears it.
      box.put(
        box
            .get(1)!
            .copyWith(
              title: 'Old',
              author: 'Old',
              license: 'Old',
              licenseUrl: 'Old',
            ),
      );
      final marker = DateTime.utc(state.$1);
      remote.stubSelectResponse([
        {
          'id': 1,
          'description': null,
          'author': null,
          'license': null,
          'license_url': null,
          'url': 'https://example.com/new.jpg',
          'width': 900,
          'height': 600,
          'event_id': 7,
          'place_id': null,
          'created_at': '2024-01-01T00:00:00Z',
          'modified_at': marker.toIso8601String(),
          'deleted_at': state.$2 ? marker.toIso8601String() : null,
        },
      ]);
      final prepared = (await repository.prepareSync()).getOrNull()!;
      expect(repository.commitSync(prepared), isA<Success<void>>());
      final stored = box.get(1)!;
      expect(stored.remoteId, 1);
      expect(stored.modifiedAt.toUtc(), marker);
      expect(stored.isDeleted, state.$2);
      expect(stored.title, isNull);
      expect(stored.author, isNull);
      expect(stored.license, isNull);
      expect(stored.licenseUrl, isNull);
      expect(stored.eventToOneId, 7);
      expect(stored.event.targetId, 7);
      expect(repository.commitSync(prepared), isA<Success<void>>());
      final replay = box.get(1)!;
      expect(replay.modifiedAt.toUtc(), marker);
      expect(replay.isDeleted, state.$2);
      previousDeleted = state.$2;
    }
    expect(previousDeleted, isFalse);
  });

  test(
    'Media prepare rejects a later page without local publication',
    () async {
      final environment = await TestObjectBoxEnvironment.create();
      addTearDown(environment.dispose);
      final remote = MockSupabaseEnvironment()
        ..stubSelectPages(
          [
            [
              {
                'id': 1,
                'url': 'https://example.com/image.jpg',
                'width': 10,
                'height': 10,
                'event_id': 7,
                'place_id': null,
                'created_at': '2026-01-01T00:00:00Z',
                'modified_at': '2026-01-01T00:00:00Z',
              },
            ],
          ],
          errorPage: 1,
          error: const PostgrestException(message: 'later page failed'),
        );
      final repository = MediaRepositoryImpl(
        logger: MockLogger(),
        supabaseI: remote.mockSupabase,
        objectBoxI: TestObjectBox(environment.store),
      );
      final result = await repository.prepareSync(
        modifiedAtOrAfter: DateTime.utc(2026),
      );
      expect(result, isA<Error<List<MediaDto>>>());
      expect(environment.store.box<MediaEntity>().count(), 0);
      expect(remote.requests, hasLength(2));
      expect(
        remote.requests.every((uri) => uri.path.endsWith('/media')),
        isTrue,
      );
      expect(remote.requests.last.queryParameters['id'], 'gt.1');
      expect(
        remote.requests.last.queryParameters['modified_at'],
        'gte.2026-01-01T00:00:00.000Z',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // getByEventId
  // ---------------------------------------------------------------------------

  group('MediaRepositoryImpl - getByEventId', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<EventEntity> eventBox;
    late Box<MediaEntity> mediaBox;
    late MediaRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      mediaBox = objectBoxEnvironment.store.box<MediaEntity>();
      repository = MediaRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns media linked to the given event ID', () async {
      final event = makeEventEntity(remoteId: 1);
      eventBox.put(event);

      final media = makeMediaEntity(remoteId: 10, eventId: event.remoteId);
      mediaBox.put(media);

      final result = await repository.getByEventId(1);

      expect(result, isA<Success<List<Media>>>());
      final items = (result as Success<List<Media>>).value;
      expect(items, hasLength(1));
      expect(items.first.remoteId, equals(10));
    });

    test('excludes media linked to a different event', () async {
      final event1 = makeEventEntity(remoteId: 1);
      final event2 = makeEventEntity(remoteId: 2);
      eventBox.put(event1);
      eventBox.put(event2);

      final media = makeMediaEntity(remoteId: 10, eventId: event2.remoteId);
      mediaBox.put(media);

      final result = await repository.getByEventId(1);

      expect(result, isA<Success<List<Media>>>());
      expect((result as Success<List<Media>>).value, isEmpty);
    });

    test(
      'returns empty list when no media exists for the given event',
      () async {
        final result = await repository.getByEventId(999);

        expect(result, isA<Success<List<Media>>>());
        expect((result as Success<List<Media>>).value, isEmpty);
      },
    );

    test('returns all media linked to the same event', () async {
      final event = makeEventEntity(remoteId: 1);
      eventBox.put(event);

      final media1 = makeMediaEntity(remoteId: 10, eventId: event.remoteId);
      final media2 = makeMediaEntity(remoteId: 11, eventId: event.remoteId);
      mediaBox.put(media1);
      mediaBox.put(media2);

      final result = await repository.getByEventId(1);

      expect(result, isA<Success<List<Media>>>());
      final ids = (result as Success<List<Media>>).value.map((m) => m.remoteId);
      expect(ids, containsAll([10, 11]));
    });
  });

  // ---------------------------------------------------------------------------
  // getByPlaceId
  // ---------------------------------------------------------------------------

  group('MediaRepositoryImpl - getByPlaceId', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late Box<MediaEntity> mediaBox;
    late MediaRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      mediaBox = objectBoxEnvironment.store.box<MediaEntity>();
      repository = MediaRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns media linked to the given place ID', () async {
      final place = makePlaceEntity(remoteId: 1);
      placeBox.put(place);

      final media = makeMediaEntity(remoteId: 20, placeId: place.remoteId);
      mediaBox.put(media);

      final result = await repository.getByPlaceId(1);

      expect(result, isA<Success<List<Media>>>());
      final items = (result as Success<List<Media>>).value;
      expect(items, hasLength(1));
      expect(items.first.remoteId, equals(20));
    });

    test('excludes media linked to a different place', () async {
      final place1 = makePlaceEntity(remoteId: 1);
      final place2 = makePlaceEntity(remoteId: 2);
      placeBox.put(place1);
      placeBox.put(place2);

      final media = makeMediaEntity(remoteId: 20, placeId: place2.remoteId);
      mediaBox.put(media);

      final result = await repository.getByPlaceId(1);

      expect(result, isA<Success<List<Media>>>());
      expect((result as Success<List<Media>>).value, isEmpty);
    });

    test(
      'returns empty list when no media exists for the given place',
      () async {
        final result = await repository.getByPlaceId(999);

        expect(result, isA<Success<List<Media>>>());
        expect((result as Success<List<Media>>).value, isEmpty);
      },
    );

    test('returns all media linked to the same place', () async {
      final place = makePlaceEntity(remoteId: 1);
      placeBox.put(place);

      final media1 = makeMediaEntity(remoteId: 20, placeId: place.remoteId);
      final media2 = makeMediaEntity(remoteId: 21, placeId: place.remoteId);
      mediaBox.put(media1);
      mediaBox.put(media2);

      final result = await repository.getByPlaceId(1);

      expect(result, isA<Success<List<Media>>>());
      final ids = (result as Success<List<Media>>).value.map((m) => m.remoteId);
      expect(ids, containsAll([20, 21]));
    });
  });

  // ---------------------------------------------------------------------------
  // prepareSync — error path
  // ---------------------------------------------------------------------------

  group('MediaRepositoryImpl - prepareSync error handling', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late MediaRepositoryImpl repository;
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment()..stubUnavailable();
      repository = MediaRepositoryImpl(
        logger: mockLogger,
        supabaseI: supabaseEnv.mockSupabase,
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns Error when Supabase throws an exception', () async {
      final result = await repository.prepareSync();

      expect(result, isA<Error<List<MediaDto>>>());
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      final event = failedCall!.event as RepositorySyncFailed;
      expect(event.repositoryName, 'media');
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // commitSync — success path
  // ---------------------------------------------------------------------------

  group('MediaRepositoryImpl - commitSync', () {
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<MediaEntity> mediaBox;
    late MediaRepositoryImpl repository;

    setUp(() async {
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment();
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      mediaBox = objectBoxEnvironment.store.box<MediaEntity>();
      repository = MediaRepositoryImpl(
        logger: mockLogger,
        supabaseI: supabaseEnv.mockSupabase,
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'inserts a new media item that is absent from the local store',
      () async {
        supabaseEnv.stubSelectResponse([
          {
            'id': 10,
            'url': 'https://example.com/img.jpg',
            'width': 800,
            'height': 600,
            'description': 'Backend description',
            'event_id': 7,
            'place_id': null,
            'created_at': '2024-01-01T00:00:00.000Z',
            'modified_at': '2024-01-01T00:00:00.000Z',
          },
        ]);

        final prepareResult = await repository.prepareSync();
        final dtos = (prepareResult as Success<List<MediaDto>>).value;
        final commitResult = repository.commitSync(dtos);

        final entity = mediaBox.get(10)!;
        expect(commitResult, isA<Success<void>>());
        expect(entity.url, equals('https://example.com/img.jpg'));
        expect(entity.title, 'Backend description');
        expect(entity.eventToOneId, 7);
        expect(entity.placeToOneId, isNull);
        expect(entity.event.targetId, 7);
        expect(entity.place.targetId, 0);
        expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
      },
    );

    test('wires an event relation when inserting new media', () async {
      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/img.jpg',
          'width': 800,
          'height': 600,
          'event_id': 7,
          'place_id': null,
          'created_at': '2024-01-01T00:00:00.000Z',
          'modified_at': '2024-01-01T00:00:00.000Z',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      final commitResult = repository.commitSync(dtos);

      final entity = mediaBox.get(10)!;
      expect(commitResult, isA<Success<void>>());
      expect(entity.eventToOneId, 7);
      expect(entity.placeToOneId, isNull);
      expect(entity.event.targetId, equals(7));
      expect(entity.place.targetId, 0);
    });

    test('wires a place relation when inserting new media', () async {
      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/img.jpg',
          'width': 800,
          'height': 600,
          'event_id': null,
          'place_id': 5,
          'created_at': '2024-01-01T00:00:00.000Z',
          'modified_at': '2024-01-01T00:00:00.000Z',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      final commitResult = repository.commitSync(dtos);

      final entity = mediaBox.get(10)!;
      expect(commitResult, isA<Success<void>>());
      expect(entity.eventToOneId, isNull);
      expect(entity.placeToOneId, 5);
      expect(entity.event.targetId, 0);
      expect(entity.place.targetId, 5);
    });

    test('skips a media item that already matches the local copy', () async {
      mediaBox.put(
        makeMediaEntity(
          remoteId: 10,
          url: 'https://example.com/img.jpg',
          eventId: 7,
          modifiedAt: DateTime.utc(2026),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/img.jpg',
          'width': 800,
          'height': 600,
          'event_id': 7,
          'place_id': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'modified_at': '2026-01-01T00:00:00.000Z',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      final commitResult = repository.commitSync(dtos);

      final entity = mediaBox.get(10)!;
      expect(commitResult, isA<Success<void>>());
      expect(entity.url, equals('https://example.com/img.jpg'));
      expect(entity.eventToOneId, 7);
      expect(entity.placeToOneId, isNull);
      expect(entity.event.targetId, 7);
      expect(entity.place.targetId, 0);
      expect(mockLogger.containsEvent<EntityInsertSuccess>(), isFalse);
      expect(mockLogger.containsEvent<EntityUpdateSuccess>(), isFalse);
    });

    test('updates existing media when remote data differs', () async {
      mediaBox.put(
        makeMediaEntity(
          remoteId: 10,
          url: 'https://example.com/old.jpg',
          eventId: 1,
          modifiedAt: DateTime.utc(2024),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/new.jpg',
          'width': 1920,
          'height': 1080,
          'event_id': 1,
          'place_id': null,
          'created_at': '2024-01-01T00:00:00.000Z',
          'modified_at': '2027-06-01T00:00:00.000Z',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      final commitResult = repository.commitSync(dtos);

      final entity = mediaBox.get(10)!;
      expect(commitResult, isA<Success<void>>());
      expect(entity.url, equals('https://example.com/new.jpg'));
      expect(entity.eventToOneId, 1);
      expect(entity.placeToOneId, isNull);
      expect(entity.event.targetId, 1);
      expect(entity.place.targetId, 0);
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    test('prepareSync returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(message: 'relation "media" does not exist'),
      );

      final result = await repository.prepareSync();

      expect(result, isA<Error<List<MediaDto>>>());
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      final event = failedCall!.event as RepositorySyncFailed;
      expect(event.repositoryName, 'media');
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });

  group('MediaRepositoryImpl - relation scalar preservation', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<MediaEntity> mediaBox;
    late MediaRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      mediaBox = objectBoxEnvironment.store.box<MediaEntity>();
      repository = MediaRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'preserves parent relations through soft deletion and a Keep merge',
      () {
        mediaBox.put(
          makeMediaEntity(eventId: 7, modifiedAt: DateTime.utc(2024)),
        );

        final deleteResult = repository.commitSync([
          _relationTestMediaDto(
            modifiedAt: DateTime.utc(2025),
            deletedAt: DateTime.utc(2025),
          ),
        ]);

        expect(deleteResult, isA<Success<void>>());
        expect(mediaBox.get(1)?.eventToOneId, 7);
        expect(mediaBox.get(1)?.placeToOneId, isNull);
        expect(mediaBox.get(1)?.event.targetId, 7);
        expect(mediaBox.get(1)?.place.targetId, 0);

        expect(mediaBox.get(1)?.isDeleted, isTrue);
        expect(mediaBox.get(1)?.modifiedAt.toUtc(), DateTime.utc(2025));
        final newerDeleted = _relationTestMediaDto(
          modifiedAt: DateTime.utc(2026),
          deletedAt: DateTime.utc(2026),
        );
        expect(repository.commitSync([newerDeleted]), isA<Success<void>>());
        expect(mediaBox.get(1)?.modifiedAt.toUtc(), DateTime.utc(2026));
        expect(mediaBox.get(1)?.isDeleted, isTrue);

        final restoreResult = repository.commitSync([
          _relationTestMediaDto(modifiedAt: DateTime.utc(2027)),
        ]);

        expect(restoreResult, isA<Success<void>>());
        expect(mediaBox.get(1)?.isDeleted, isFalse);
        expect(mediaBox.get(1)?.modifiedAt.toUtc(), DateTime.utc(2027));
        repository.commitSync([newerDeleted]);
        expect(mediaBox.get(1)?.isDeleted, isFalse);
        expect(mediaBox.get(1)?.modifiedAt.toUtc(), DateTime.utc(2027));
        expect(mediaBox.get(1)?.eventToOneId, 7);
        expect(mediaBox.get(1)?.placeToOneId, isNull);
        expect(mediaBox.get(1)?.event.targetId, 7);
        expect(mediaBox.get(1)?.place.targetId, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getByEventId / getByPlaceId — error path
  // ---------------------------------------------------------------------------

  group('MediaRepositoryImpl - query error propagation', () {
    late MockLogger mockLogger;
    late MediaRepositoryImpl repository;

    setUp(() {
      mockLogger = MockLogger();
      final mockBox = MockEntityBox<MediaEntity>();
      when(() => mockBox.query(any())).thenThrow(Exception('query failed'));

      final mockStore = MockObjectBoxStore<MediaEntity>(mockBox);

      repository = MediaRepositoryImpl(
        logger: mockLogger,
        supabaseI: MockSupabase(),
        objectBoxI: MockObjectBox(mockStore),
      );
    });

    test('getByEventId returns Error when query throws', () async {
      final result = await repository.getByEventId(1);

      expect(result, isA<Error<List<Media>>>());
      final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>();
      expect(failedCall, isNotNull);
      expect(
        failedCall!.event,
        const EntityLoadFailed('media', method: 'getByEventId'),
      );
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });

    test('getByPlaceId returns Error when query throws', () async {
      final result = await repository.getByPlaceId(1);

      expect(result, isA<Error<List<Media>>>());
      final failedCall = mockLogger.firstCallOfType<EntityLoadFailed>();
      expect(failedCall, isNotNull);
      expect(
        failedCall!.event,
        const EntityLoadFailed('media', method: 'getByPlaceId'),
      );
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });
}

MediaDto _relationTestMediaDto({
  required DateTime modifiedAt,
  RelationUpdate<int> eventId = const Keep<int>(),
  RelationUpdate<int> placeId = const Keep<int>(),
  DateTime? deletedAt,
}) => MediaDto(
  id: 1,
  url: 'https://example.com/media.jpg',
  width: 800,
  height: 600,
  eventId: eventId,
  placeId: placeId,
  createdAt: DateTime.utc(2024),
  modifiedAt: modifiedAt,
  deletedAt: deletedAt,
);
