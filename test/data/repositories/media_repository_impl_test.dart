// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
            'created_at': '2024-01-01T00:00:00.000',
            'modified_at': '2024-01-01T00:00:00.000',
          },
        ]);

        final prepareResult = await repository.prepareSync();
        final dtos = (prepareResult as Success<List<MediaDto>>).value;
        repository.commitSync(dtos);

        expect(mediaBox.get(10)?.url, equals('https://example.com/img.jpg'));
        expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
      },
    );

    test('wires place and event relations when inserting new media', () async {
      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/img.jpg',
          'width': 800,
          'height': 600,
          'place_id': 5,
          'event_id': 7,
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      repository.commitSync(dtos);

      final entity = mediaBox.get(10)!;
      expect(entity.place.targetId, equals(5));
      expect(entity.event.targetId, equals(7));
    });

    test('skips a media item that already matches the local copy', () async {
      mediaBox.put(
        makeMediaEntity(
          remoteId: 10,
          url: 'https://example.com/img.jpg',
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/img.jpg',
          'width': 800,
          'height': 600,
          'created_at': '2026-01-01T00:00:00.000',
          'modified_at': '2026-01-01T00:00:00.000',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      repository.commitSync(dtos);

      expect(mediaBox.get(10)?.url, equals('https://example.com/img.jpg'));
      expect(mockLogger.containsEvent<EntityInsertSuccess>(), isFalse);
      expect(mockLogger.containsEvent<EntityUpdateSuccess>(), isFalse);
    });

    test('updates existing media when remote data differs', () async {
      mediaBox.put(
        makeMediaEntity(
          remoteId: 10,
          url: 'https://example.com/old.jpg',
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 10,
          'url': 'https://example.com/new.jpg',
          'width': 1920,
          'height': 1080,
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2027-06-01T00:00:00.000',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<MediaDto>>).value;
      repository.commitSync(dtos);

      expect(mediaBox.get(10)?.url, equals('https://example.com/new.jpg'));
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    test('prepareSync returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(
          message: 'relation "media" does not exist',
        ),
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
