// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/objectbox_test_store.dart';

void main() {
  group('SearchRepositoryImpl - getEventIdsByQuery', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<City> cityBox;
    late Box<Event> eventBox;
    late SearchRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      cityBox = objectBoxEnvironment.store.box<City>();
      eventBox = objectBoxEnvironment.store.box<Event>();
      repository = SearchRepositoryImpl(
        logger: Talker(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    // -------------------------------------------------------------------------
    // Direct name match
    // -------------------------------------------------------------------------

    group('direct event name match', () {
      test('includes current-year event whose name matches query', () async {
        final now = DateTime.now();
        eventBox.put(
          _createEvent(
            remoteId: 1,
            name: 'Sagra del tartufo',
            startDate: DateTime(now.year, 8),
            endDate: DateTime(now.year, 8, 5),
          ),
        );

        final result = await repository.getEventIdsByQuery('tartufo');

        expect(result, isA<Success<List<int>>>());
        final ids = (result as Success<List<int>>).value;
        expect(ids, contains(1));
      });

      test('excludes event from a past year even when name matches', () async {
        eventBox.put(
          _createEvent(
            remoteId: 2,
            name: 'Sagra storica',
            startDate: DateTime(2020, 6),
            endDate: DateTime(2020, 6, 10),
          ),
        );

        final result = await repository.getEventIdsByQuery('sagra');

        expect(result, isA<Success<List<int>>>());
        final ids = (result as Success<List<int>>).value;
        expect(ids, isNot(contains(2)));
      });

      test(
        'excludes event from a future year even when name matches',
        () async {
          eventBox.put(
            _createEvent(
              remoteId: 3,
              name: 'Festival futuro',
              startDate: DateTime(2099, 6),
              endDate: DateTime(2099, 6, 10),
            ),
          );

          final result = await repository.getEventIdsByQuery('futuro');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(3)));
        },
      );
    });

    // -------------------------------------------------------------------------
    // City-name match (in-memory year filter)
    // -------------------------------------------------------------------------

    group('city name match', () {
      test(
        'includes current-year multi-day event linked to a matching city',
        () async {
          final now = DateTime.now();
          final city = _createCity(remoteId: 10, name: 'Campobasso');
          cityBox.put(city);

          final event = _createEvent(
            remoteId: 4,
            name: 'Non matching name',
            startDate: DateTime(now.year, 9),
            endDate: DateTime(now.year, 9, 5),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getEventIdsByQuery('Campobasso');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, contains(4));
        },
      );

      test(
        'excludes multi-day event from past year linked to a matching city',
        () async {
          final city = _createCity(remoteId: 11, name: 'Isernia');
          cityBox.put(city);

          final event = _createEvent(
            remoteId: 5,
            name: 'Old festival',
            startDate: DateTime(2020, 7),
            endDate: DateTime(2020, 7, 10),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getEventIdsByQuery('Isernia');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(5)));
        },
      );

      test(
        'includes single-day event (null endDate) linked to a matching city',
        () async {
          final now = DateTime.now();
          final city = _createCity(remoteId: 12, name: 'Bojano');
          cityBox.put(city);

          final event = _createEvent(
            remoteId: 6,
            name: 'Giornata speciale',
            startDate: DateTime(now.year, 5, 15),
            endDate: null,
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getEventIdsByQuery('Bojano');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, contains(6));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Deduplication
    // -------------------------------------------------------------------------

    group('deduplication', () {
      test(
        'returns each event ID only once when it matches both name and city',
        () async {
          final now = DateTime.now();
          final city = _createCity(remoteId: 20, name: 'Venafro');
          cityBox.put(city);

          // The event name also contains "venafro" so it would be picked up by
          // both the name query and the city query.
          final event = _createEvent(
            remoteId: 7,
            name: 'Festa di Venafro',
            startDate: DateTime(now.year, 10),
            endDate: DateTime(now.year, 10, 3),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getEventIdsByQuery('Venafro');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids.where((id) => id == 7), hasLength(1));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Empty store
    // -------------------------------------------------------------------------

    test('returns empty list when store is empty', () async {
      final result = await repository.getEventIdsByQuery('anything');

      expect(result, isA<Success<List<int>>>());
      expect((result as Success<List<int>>).value, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Event _createEvent({
  required int remoteId,
  required String name,
  required DateTime startDate,
  required DateTime? endDate,
  int? cityId,
}) {
  final now = DateTime.now();
  final event = Event(
    remoteId: remoteId,
    name: name,
    startDate: startDate,
    endDate: endDate,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<City>(),
    media: ToMany(),
  );

  if (cityId != null) {
    event.city.targetId = cityId;
  }

  return event;
}

City _createCity({required int remoteId, required String name}) {
  final now = DateTime.now();
  return City(
    remoteId: remoteId,
    name: name,
    createdAt: now,
    modifiedAt: now,
    places: ToMany(),
    events: ToMany(),
  );
}
