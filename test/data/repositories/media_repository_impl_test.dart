// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/media_supabase_table.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart' as app_objectbox;
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(() {
    setUpMockLogger();
    setUpMockSupabase();
  });

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
        supabaseTable: MediaSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns media linked to the given event ID', () async {
      final event = _createEvent(remoteId: 1);
      eventBox.put(event);

      final media = _createMedia(remoteId: 10, eventId: event.remoteId);
      mediaBox.put(media);

      final result = await repository.getByEventId(1);

      expect(result, isA<Success<List<Media>>>());
      final items = (result as Success<List<Media>>).value;
      expect(items, hasLength(1));
      expect(items.first.remoteId, equals(10));
    });

    test('excludes media linked to a different event', () async {
      final event1 = _createEvent(remoteId: 1);
      final event2 = _createEvent(remoteId: 2);
      eventBox.put(event1);
      eventBox.put(event2);

      final media = _createMedia(remoteId: 10, eventId: event2.remoteId);
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
      final event = _createEvent(remoteId: 1);
      eventBox.put(event);

      final media1 = _createMedia(remoteId: 10, eventId: event.remoteId);
      final media2 = _createMedia(remoteId: 11, eventId: event.remoteId);
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
        supabaseTable: MediaSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns media linked to the given place ID', () async {
      final place = _createPlace(remoteId: 1);
      placeBox.put(place);

      final media = _createMedia(remoteId: 20, placeId: place.remoteId);
      mediaBox.put(media);

      final result = await repository.getByPlaceId(1);

      expect(result, isA<Success<List<Media>>>());
      final items = (result as Success<List<Media>>).value;
      expect(items, hasLength(1));
      expect(items.first.remoteId, equals(20));
    });

    test('excludes media linked to a different place', () async {
      final place1 = _createPlace(remoteId: 1);
      final place2 = _createPlace(remoteId: 2);
      placeBox.put(place1);
      placeBox.put(place2);

      final media = _createMedia(remoteId: 20, placeId: place2.remoteId);
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
      final place = _createPlace(remoteId: 1);
      placeBox.put(place);

      final media1 = _createMedia(remoteId: 20, placeId: place.remoteId);
      final media2 = _createMedia(remoteId: 21, placeId: place.remoteId);
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
        supabaseTable: MediaSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns Error when Supabase throws an exception', () async {
      final result = await repository.prepareSync();

      expect(result, isA<Error<List<MediaDto>>>());
      verify(
        () => mockLogger.log(
          const RepositorySyncFailed('media'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
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
        supabaseTable: MediaSupabaseTable(),
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
        verify(
          () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
        ).called(1);
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
        _createMedia(
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
      verifyNever(
        () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
      );
      verifyNever(
        () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
      );
    });

    test('updates existing media when remote data differs', () async {
      mediaBox.put(
        _createMedia(
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
      verify(
        () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
      ).called(1);
    });

    test('prepareSync returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(
          message: 'relation "media" does not exist',
        ),
      );

      final result = await repository.prepareSync();

      expect(result, isA<Error<List<MediaDto>>>());
      verify(
        () => mockLogger.log(
          const RepositorySyncFailed('media'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
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
      final mockBox = _MockMediaEntityBox();
      when(() => mockBox.query(any())).thenThrow(Exception('query failed'));

      final mockStore = _MockStore(mockBox);

      repository = MediaRepositoryImpl(
        logger: mockLogger,
        supabaseI: MockSupabase(),
        supabaseTable: MediaSupabaseTable(),
        objectBoxI: _MockObjectBox(mockStore),
      );
    });

    test('getByEventId returns Error when query throws', () async {
      final result = await repository.getByEventId(1);

      expect(result, isA<Error<List<Media>>>());
      verify(
        () => mockLogger.log(
          const EntityLoadFailed('media', method: 'getByEventId'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('getByPlaceId returns Error when query throws', () async {
      final result = await repository.getByPlaceId(1);

      expect(result, isA<Error<List<Media>>>());
      verify(
        () => mockLogger.log(
          const EntityLoadFailed('media', method: 'getByPlaceId'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EventEntity _createEvent({required int remoteId}) {
  final now = DateTime(2026);
  return EventEntity(
    remoteId: remoteId,
    startDate: now,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<CityEntity>(),
    media: ToMany(),
  );
}

PlaceEntity _createPlace({required int remoteId}) {
  final now = DateTime(2026);
  return PlaceEntity(
    remoteId: remoteId,
    name: 'Place $remoteId',
    createdAt: now,
    modifiedAt: now,
    city: ToOne<CityEntity>(),
    media: ToMany(),
  );
}

// Sets both the JSON-serialization field (`eventToOneId`/`placeToOneId`) and
// the ObjectBox relation ID (`event.targetId`/`place.targetId`). Both are
// required: the former is the plain Dart field used in JSON; the latter is
// what ObjectBox uses to build the in-store relation for `.link()` queries.
MediaEntity _createMedia({
  required int remoteId,
  int? eventId,
  int? placeId,
  String url = 'https://example.com/1.jpg',
}) {
  final now = DateTime(2026);
  final entity = MediaEntity(
    remoteId: remoteId,
    url: url,
    width: 800,
    height: 600,
    eventToOneId: eventId,
    placeToOneId: placeId,
    createdAt: now,
    modifiedAt: now,
    place: ToOne<PlaceEntity>(),
    event: ToOne<EventEntity>(),
  );
  if (eventId != null) entity.event.targetId = eventId;
  if (placeId != null) entity.place.targetId = placeId;
  return entity;
}

final class _MockStore extends Mock implements Store {
  _MockStore(this._mockBox);

  final Box<MediaEntity> _mockBox;

  @override
  Box<T> box<T>() {
    if (T == MediaEntity) return _mockBox as Box<T>;
    throw StateError(
      '_MockStore only supports Box<MediaEntity>, got Box<$T>',
    );
  }
}

final class _MockMediaEntityBox extends Mock implements Box<MediaEntity> {}

final class _MockObjectBox implements app_objectbox.ObjectBox {
  _MockObjectBox(this._mockStore);

  final Store _mockStore;

  @override
  Store get store => _mockStore;

  @override
  set store(Store value) {
    throw UnsupportedError('_MockObjectBox store is immutable.');
  }
}
