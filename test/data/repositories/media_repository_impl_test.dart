// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/media_supabase_table.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/objectbox_test_store.dart';

void main() {
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
        logger: Talker(),
        supabaseI: _FakeSupabase(),
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
      media.event.targetId = event.remoteId;
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
      media.event.targetId = event2.remoteId;
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
      media1.event.targetId = event.remoteId;
      media2.event.targetId = event.remoteId;
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
        logger: Talker(),
        supabaseI: _FakeSupabase(),
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
      media.place.targetId = place.remoteId;
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
      media.place.targetId = place2.remoteId;
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
      media1.place.targetId = place.remoteId;
      media2.place.targetId = place.remoteId;
      mediaBox.put(media1);
      mediaBox.put(media2);

      final result = await repository.getByPlaceId(1);

      expect(result, isA<Success<List<Media>>>());
      final ids = (result as Success<List<Media>>).value.map((m) => m.remoteId);
      expect(ids, containsAll([20, 21]));
    });
  });

  // ---------------------------------------------------------------------------
  // synchronize error handling
  // ---------------------------------------------------------------------------

  group('MediaRepositoryImpl - synchronize error handling', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late MediaRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      repository = MediaRepositoryImpl(
        logger: Talker(),
        supabaseI: _ThrowingSupabase(),
        supabaseTable: MediaSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns Error when Supabase throws an exception', () async {
      final result = await repository.synchronize();

      expect(result, isA<Error<void>>());
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EventEntity _createEvent({required int remoteId}) {
  final now = DateTime(2026, 1, 1);
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
  final now = DateTime(2026, 1, 1);
  return PlaceEntity(
    remoteId: remoteId,
    name: 'Place $remoteId',
    createdAt: now,
    modifiedAt: now,
    city: ToOne<CityEntity>(),
    media: ToMany(),
  );
}

MediaEntity _createMedia({
  required int remoteId,
  int? eventId,
  int? placeId,
  String url = 'https://example.com/1.jpg',
}) {
  final now = DateTime(2026, 1, 1);
  return MediaEntity(
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
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _ThrowingSupabase implements Supabase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('Supabase unavailable');
}

final class _FakeSupabase implements Supabase {
  List<Map<String, dynamic>> response = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #client) {
      return _FakeSupabaseClient(response);
    }
    return super.noSuchMethod(invocation);
  }
}

// Not implementing SupabaseClient — see city_repository_impl_test.dart comment.
final class _FakeSupabaseClient {
  _FakeSupabaseClient(this._response);

  final List<Map<String, dynamic>> _response;

  _FakeQueryBuilder from(String table) => _FakeQueryBuilder(_response);
}

final class _FakeQueryBuilder {
  _FakeQueryBuilder(this._response);

  final List<Map<String, dynamic>> _response;

  Future<List<Map<String, dynamic>>> select([String columns = '*']) =>
      Future.value(_response);
}
