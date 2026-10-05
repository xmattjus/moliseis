// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/controllable_search_repository.dart';
import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  final fixedNowUtc = DateTime.utc(2026, 3, 15, 12);

  group('SearchRepositoryImpl - direct event matches', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<CityEntity> cityBox;
    late Box<EventEntity> eventBox;
    late SearchRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      cityBox = objectBoxEnvironment.store.box<CityEntity>();
      eventBox = objectBoxEnvironment.store.box<EventEntity>();
      repository = SearchRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    // -------------------------------------------------------------------------
    // Direct name match
    // -------------------------------------------------------------------------

    group('direct event name match', () {
      test('uses annual overlap consistently for direct, category, and city '
          'event searches in both Rome years', () async {
        final city = makeCityEntity(remoteId: 60, name: 'Campobasso');
        cityBox.put(city);
        eventBox.put(
          makeEventEntity(
            remoteId: 60,
            name: 'Cross-year nature festival',
            startDate: DateTime.utc(2026, 12, 30, 23),
            endDate: DateTime.utc(2027, 1, 1, 22, 59, 59, 999, 999),
            cityId: city.remoteId,
            contentCategoryIndex: 1, // ContentCategory.nature
          ),
        );
        eventBox.put(
          makeEventEntity(
            remoteId: 61,
            name: 'Cross-year nature hidden festival',
            startDate: DateTime.utc(2026, 12, 30, 23),
            endDate: DateTime.utc(2027, 1, 1, 22, 59, 59, 999, 999),
            cityId: city.remoteId,
            contentCategoryIndex: 1, // ContentCategory.nature
            isDeleted: true,
          ),
        );

        for (final nowUtc in [DateTime.utc(2026, 6), DateTime.utc(2027, 6)]) {
          final yearlyRepository = SearchRepositoryImpl(
            logger: MockLogger(),
            objectBoxI: TestObjectBox(objectBoxEnvironment.store),
            nowUtc: () => nowUtc,
          );

          expect(
            (await yearlyRepository.getResultsByQuery(
              'Cross-year',
            )).getOrNull()?.map((item) => item.remoteId),
            contains(60),
          );
          expect(
            (await yearlyRepository.getResultsByQuery(
              'Cross-year',
            )).getOrNull()?.map((item) => item.remoteId),
            isNot(contains(61)),
          );
          expect(
            (await yearlyRepository.getResultsByQuery(
              'natura',
            )).getOrNull()?.map((item) => item.remoteId),
            contains(60),
          );
          expect(
            (await yearlyRepository.getResultsByQuery(
              'natura',
            )).getOrNull()?.map((item) => item.remoteId),
            isNot(contains(61)),
          );
          expect(
            (await yearlyRepository.getResultsByQuery(
              'Campobasso',
            )).getOrNull()?.map((item) => item.remoteId),
            contains(60),
          );
          expect(
            (await yearlyRepository.getResultsByQuery(
              'Campobasso',
            )).getOrNull()?.map((item) => item.remoteId),
            isNot(contains(61)),
          );
        }
      });

      test('uses Rome year bounds for direct and city event paths', () async {
        final city = makeCityEntity(remoteId: 50, name: 'Termoli');
        cityBox.put(city);
        eventBox.putMany([
          makeEventEntity(
            remoteId: 50,
            name: 'Rome year event',
            startDate: DateTime.utc(2026, 12, 31, 23),
            cityId: city.remoteId,
          ),
          makeEventEntity(
            remoteId: 52,
            name: 'Nature event',
            startDate: DateTime.utc(2026, 12, 31, 23),
            contentCategoryIndex: 1,
          ),
          makeEventEntity(
            remoteId: 53,
            name: 'Past nature event',
            startDate: DateTime.utc(2026, 12, 31, 22, 59),
            contentCategoryIndex: 1,
          ),
          makeEventEntity(
            remoteId: 51,
            name: 'Past event',
            startDate: DateTime.utc(2026, 12, 31, 21),
            cityId: city.remoteId,
          ),
        ]);
        final romeRepository = SearchRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: TestObjectBox(objectBoxEnvironment.store),
          nowUtc: () => DateTime.utc(2026, 12, 31, 23, 30),
        );

        final direct = await romeRepository.getResultsByQuery('Rome year');
        final cityResult = await romeRepository.getResultsByQuery('Termoli');
        final category = await romeRepository.getResultsByQuery('natura');

        expect(direct.getOrNull()?.map((item) => item.remoteId), contains(50));
        expect(
          cityResult.getOrNull()?.map((item) => item.remoteId),
          contains(50),
        );
        expect(
          cityResult.getOrNull()?.map((item) => item.remoteId),
          isNot(contains(51)),
        );
        expect(
          category.getOrNull()?.map((item) => item.remoteId),
          contains(52),
        );
        expect(
          category.getOrNull()?.map((item) => item.remoteId),
          isNot(contains(53)),
        );
      });

      test('includes current-year event whose name matches query', () async {
        final now = fixedNowUtc;
        eventBox.put(
          makeEventEntity(
            remoteId: 1,
            name: 'Sagra del tartufo',
            startDate: DateTime.utc(now.year, 8),
            endDate: DateTime.utc(now.year, 8, 5),
          ),
        );

        final result = await repository.getResultsByQuery('tartufo');

        expect(result, isA<Success<List<ContentBase>>>());
        final ids = (result as Success<List<ContentBase>>).value.map(
          (item) => item.remoteId,
        );
        expect(ids, contains(1));
      });

      test('excludes event from a past year even when name matches', () async {
        eventBox.put(
          makeEventEntity(
            remoteId: 2,
            name: 'Sagra storica',
            startDate: DateTime(2020, 6),
            endDate: DateTime(2020, 6, 10),
          ),
        );

        final result = await repository.getResultsByQuery('sagra');

        expect(result, isA<Success<List<ContentBase>>>());
        final ids = (result as Success<List<ContentBase>>).value.map(
          (item) => item.remoteId,
        );
        expect(ids, isNot(contains(2)));
      });

      test(
        'excludes event from a future year even when name matches',
        () async {
          eventBox.put(
            makeEventEntity(
              remoteId: 3,
              name: 'Festival futuro',
              startDate: DateTime(2099, 6),
              endDate: DateTime(2099, 6, 10),
            ),
          );

          final result = await repository.getResultsByQuery('futuro');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
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
          final now = fixedNowUtc;
          final city = makeCityEntity(remoteId: 10, name: 'Campobasso');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 4,
            name: 'Non matching name',
            startDate: DateTime.utc(now.year, 9),
            endDate: DateTime.utc(now.year, 9, 5),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getResultsByQuery('Campobasso');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, contains(4));
        },
      );

      test(
        'excludes multi-day event from past year linked to a matching city',
        () async {
          final city = makeCityEntity(remoteId: 11, name: 'Isernia');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 5,
            name: 'Old festival',
            startDate: DateTime(2020, 7),
            endDate: DateTime(2020, 7, 10),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getResultsByQuery('Isernia');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, isNot(contains(5)));
        },
      );

      test(
        'includes single-day event (null endDate) linked to a matching city',
        () async {
          final now = fixedNowUtc;
          final city = makeCityEntity(remoteId: 12, name: 'Bojano');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 6,
            name: 'Giornata speciale',
            startDate: DateTime.utc(now.year, 5, 15),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getResultsByQuery('Bojano');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, contains(6));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Soft-delete exclusion
    // -------------------------------------------------------------------------

    group('soft-delete exclusion', () {
      test(
        'excludes soft-deleted current-year event whose name matches query',
        () async {
          final now = fixedNowUtc;
          eventBox.put(
            makeEventEntity(
              remoteId: 200,
              name: 'Sagra fantasma',
              startDate: DateTime.utc(now.year, 8),
              endDate: DateTime.utc(now.year, 8, 5),
              isDeleted: true,
            ),
          );

          final result = await repository.getResultsByQuery('fantasma');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, isNot(contains(200)));
        },
      );

      test(
        'excludes soft-deleted current-year event whose category matches query',
        () async {
          final now = fixedNowUtc;
          eventBox.put(
            makeEventEntity(
              remoteId: 201,
              name: 'Escursione cancellata',
              startDate: DateTime.utc(now.year, 6),
              endDate: DateTime.utc(now.year, 6, 10),
              contentCategoryIndex: 1, // ContentCategory.nature
              isDeleted: true,
            ),
          );

          final result = await repository.getResultsByQuery('natura');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, isNot(contains(201)));
        },
      );

      test(
        'excludes soft-deleted current-year event linked to a matching city',
        () async {
          final now = fixedNowUtc;
          final city = makeCityEntity(remoteId: 30, name: 'Termoli');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 202,
            name: 'Evento fantasma',
            startDate: DateTime.utc(now.year, 9),
            endDate: DateTime.utc(now.year, 9, 5),
            cityId: city.remoteId,
            isDeleted: true,
          );
          eventBox.put(event);

          final result = await repository.getResultsByQuery('Termoli');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, isNot(contains(202)));
        },
      );

      test('excludes single-day event from a future year linked to a matching '
          'city', () async {
        final city = makeCityEntity(remoteId: 31, name: 'Larino');
        cityBox.put(city);

        final event = makeEventEntity(
          remoteId: 203,
          name: 'Futura giornata',
          startDate: DateTime(2099, 5, 15),
          cityId: city.remoteId,
        );
        eventBox.put(event);

        final result = await repository.getResultsByQuery('Larino');

        expect(result, isA<Success<List<ContentBase>>>());
        final ids = (result as Success<List<ContentBase>>).value.map(
          (item) => item.remoteId,
        );
        expect(ids, isNot(contains(203)));
      });
    });

    // -------------------------------------------------------------------------
    // Deduplication
    // -------------------------------------------------------------------------

    group('deduplication', () {
      test(
        'returns each event only once when it matches both name and city',
        () async {
          final now = fixedNowUtc;
          final city = makeCityEntity(remoteId: 20, name: 'Venafro');
          cityBox.put(city);

          // The event name also contains "venafro" so it would be picked up by
          // both the name query and the city query.
          final event = makeEventEntity(
            remoteId: 7,
            name: 'Festa di Venafro',
            startDate: DateTime.utc(now.year, 10),
            endDate: DateTime.utc(now.year, 10, 3),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getResultsByQuery('Venafro');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids.where((id) => id == 7), hasLength(1));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Empty store
    // -------------------------------------------------------------------------

    test('returns empty list when store is empty', () async {
      final result = await repository.getResultsByQuery('anything');

      expect(result, isA<Success<List<ContentBase>>>());
      expect((result as Success<List<ContentBase>>).value, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Category match (non-zero contentCategoryIndex)
    // -------------------------------------------------------------------------

    group('category match', () {
      test(
        'includes current-year event whose category label matches query',
        () async {
          final now = fixedNowUtc;
          eventBox.put(
            makeEventEntity(
              remoteId: 100,
              name: 'Escursione guidata',
              startDate: DateTime.utc(now.year, 6),
              endDate: DateTime.utc(now.year, 6, 10),
              contentCategoryIndex: 1, // ContentCategory.nature
            ),
          );

          final result = await repository.getResultsByQuery('natura');

          expect(result, isA<Success<List<ContentBase>>>());
          final ids = (result as Success<List<ContentBase>>).value.map(
            (item) => item.remoteId,
          );
          expect(ids, contains(100));
        },
      );

      test('excludes event with non-matching category when querying by '
          'category label', () async {
        final now = fixedNowUtc;
        eventBox.put(
          makeEventEntity(
            remoteId: 101,
            name: 'Mostra storica',
            startDate: DateTime.utc(now.year, 6),
            endDate: DateTime.utc(now.year, 6, 10),
            contentCategoryIndex: 2, // ContentCategory.history
          ),
        );

        final result = await repository.getResultsByQuery('natura');

        expect(result, isA<Success<List<ContentBase>>>());
        final ids = (result as Success<List<ContentBase>>).value.map(
          (item) => item.remoteId,
        );
        expect(ids, isNot(contains(101)));
      });

      test('includes current-year event with food category when querying '
          '"cibo"', () async {
        final now = fixedNowUtc;
        eventBox.put(
          makeEventEntity(
            remoteId: 102,
            name: 'Degustazione vini',
            startDate: DateTime.utc(now.year, 9),
            endDate: DateTime.utc(now.year, 9, 5),
            contentCategoryIndex: 4, // ContentCategory.food
          ),
        );

        final result = await repository.getResultsByQuery('cibo');

        expect(result, isA<Success<List<ContentBase>>>());
        final ids = (result as Success<List<ContentBase>>).value.map(
          (item) => item.remoteId,
        );
        expect(ids, contains(102));
      });
    });
  });

  // -------------------------------------------------------------------------
  // getResultsByQuery
  // -------------------------------------------------------------------------

  group('SearchRepositoryImpl - direct place matches', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late SearchRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = SearchRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'includes place whose category label matches query (non-zero index)',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 200,
            name: 'Parco nazionale',
            contentCategoryIndex: 1, // ContentCategory.nature
          ),
        );

        final result = await repository.getResultsByQuery('natura');

        expect(result, isA<Success<List<ContentBase>>>());
        final ids = (result as Success<List<ContentBase>>).value.map(
          (item) => item.remoteId,
        );
        expect(ids, contains(200));
      },
    );

    test('includes place whose name matches query', () async {
      placeBox.put(
        makePlaceEntity(remoteId: 201, name: 'Castello di Campobasso'),
      );

      final result = await repository.getResultsByQuery('Castello');

      expect(result, isA<Success<List<ContentBase>>>());
      final ids = (result as Success<List<ContentBase>>).value.map(
        (item) => item.remoteId,
      );
      expect(ids, contains(201));
    });

    test('deduplicates place when both name and category match', () async {
      placeBox.put(
        makePlaceEntity(
          remoteId: 202,
          name: 'Cibo di strada',
          contentCategoryIndex: 4, // ContentCategory.food
        ),
      );

      final result = await repository.getResultsByQuery('cibo');

      expect(result, isA<Success<List<ContentBase>>>());
      final ids = (result as Success<List<ContentBase>>).value.map(
        (item) => item.remoteId,
      );
      expect(ids.where((id) => id == 202), hasLength(1));
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getResultsByQuery('anything');

      expect(result, isA<Success<List<ContentBase>>>());
      expect((result as Success<List<ContentBase>>).value, isEmpty);
    });
  });

  group('SearchRepositoryImpl - direct mixed discovery contracts', () {
    late TestObjectBoxEnvironment environment;
    late Box<CityEntity> cities;
    late Box<PlaceEntity> places;
    late Box<EventEntity> events;
    late SearchRepositoryImpl repository;

    setUp(() async {
      environment = await TestObjectBoxEnvironment.create();
      cities = environment.store.box<CityEntity>();
      places = environment.store.box<PlaceEntity>();
      events = environment.store.box<EventEntity>();
      repository = SearchRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(environment.store),
        nowUtc: () => fixedNowUtc,
      );
    });

    tearDown(() async {
      await environment.dispose();
    });

    for (final path in ['name', 'city', 'category']) {
      test('excludes deleted places on the $path matching path', () async {
        cities.put(makeCityEntity(remoteId: 1, name: 'Natura'));
        places.putMany([
          makePlaceEntity(
            remoteId: 1,
            name: path == 'name' ? 'Natura visible' : 'Visible',
            cityId: path == 'city' ? 1 : null,
            contentCategoryIndex: path == 'category' ? 1 : 0,
          ),
          makePlaceEntity(
            remoteId: 2,
            name: path == 'name' ? 'Natura deleted' : 'Deleted',
            cityId: path == 'city' ? 1 : null,
            contentCategoryIndex: path == 'category' ? 1 : 0,
            isDeleted: true,
          ),
        ]);

        final result = await repository.getResultsByQuery('natura');

        expect(result, isA<Success<List<ContentBase>>>());
        expect(result.getOrNull()!.map((item) => item.remoteId), [1]);
        expect(result.getOrNull()!.single, isA<Place>());
      });
    }

    test('keeps name/city/category first-match order, type grouping and '
        'equal numeric IDs without cross-type deduplication', () async {
      cities.put(makeCityEntity(remoteId: 1, name: 'Natura'));
      // Numeric order deliberately differs from match-path order.
      places.putMany([
        makePlaceEntity(
          remoteId: 30,
          name: 'Natura name',
          cityId: 1,
          contentCategoryIndex: 1,
        ),
        makePlaceEntity(remoteId: 20, name: 'City match', cityId: 1),
        makePlaceEntity(
          remoteId: 10,
          name: 'Category match',
          contentCategoryIndex: 1,
        ),
      ]);
      events.putMany([
        makeEventEntity(
          remoteId: 30,
          name: 'Natura name',
          cityId: 1,
          contentCategoryIndex: 1,
          startDate: fixedNowUtc,
        ),
        makeEventEntity(
          remoteId: 20,
          name: 'City match',
          cityId: 1,
          startDate: fixedNowUtc,
        ),
        makeEventEntity(
          remoteId: 10,
          name: 'Category match',
          contentCategoryIndex: 1,
          startDate: fixedNowUtc,
        ),
      ]);

      final result = await repository.getResultsByQuery('natura');
      final values = (result as Success<List<ContentBase>>).value;

      expect(values.map((item) => item.remoteId), [30, 20, 10, 30, 20, 10]);
      expect(values.take(3), everyElement(isA<Place>()));
      expect(values.skip(3), everyElement(isA<Event>()));
    });

    test('maps final place and event fields and lazy city relations', () async {
      cities.put(makeCityEntity(remoteId: 1, name: 'Campobasso'));
      places.put(
        makePlaceEntity(
          remoteId: 2,
          name: 'Shared place',
          description: 'Place description',
          contentCategoryIndex: 1,
          coordinates: [41.56, 14.66],
          cityId: 1,
          isSaved: true,
        ),
      );
      final endDate = fixedNowUtc.add(const Duration(days: 1));
      events.put(
        makeEventEntity(
          remoteId: 3,
          name: 'Shared event',
          description: 'Event description',
          contentCategoryIndex: 4,
          coordinates: [41.56, 14.66],
          cityId: 1,
          startDate: fixedNowUtc,
          endDate: endDate,
          allDay: true,
        ),
      );

      final result = await repository.getResultsByQuery('Shared');
      final values = (result as Success<List<ContentBase>>).value;
      final place = values[0] as Place;
      final event = values[1] as Event;

      expect(place.remoteId, 2);
      expect(place.name, 'Shared place');
      expect(place.description, 'Place description');
      expect(place.category, ContentCategory.nature);
      expect(place.city!.name, 'Campobasso');
      // ObjectBox stores indexed coordinates as Float32.
      expect(place.coordinates.latitude, closeTo(41.56, 0.00001));
      expect(place.coordinates.longitude, closeTo(14.66, 0.00001));
      expect(place.isSaved, isTrue);
      expect(event.remoteId, 3);
      expect(event.name, 'Shared event');
      expect(event.description, 'Event description');
      expect(event.category, ContentCategory.food);
      expect(event.city!.name, 'Campobasso');
      expect(event.startDate, fixedNowUtc);
      expect(event.endDate, endDate);
      expect(event.allDay, isTrue);
    });

    test('place failure short-circuits before event execution and preserves '
        'the original error', () async {
      final placeError = Exception('Place discovery failed');
      final controlled = ControllableSearchRepository(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(environment.store),
      );
      controlled.placePhase = (_) async => Result.error(placeError);
      controlled.eventPhase = (_) async => Result.success([makeEvent()]);

      final result = await controlled.getResultsByQuery('query');

      expect(result, isA<Error<List<ContentBase>>>());
      expect((result as Error<List<ContentBase>>).error, same(placeError));
      expect(controlled.placePhaseCalls, 1);
      expect(controlled.eventPhaseCalls, 0);
    });

    test('event discovery waits for successful place discovery', () async {
      final pendingPlace = Completer<Result<List<Place>>>();
      final expectedPlace = makePlace();
      final expectedEvent = makeEvent();
      final controlled = ControllableSearchRepository(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(environment.store),
      );
      controlled.placePhase = (_) => pendingPlace.future;
      controlled.eventPhase = (_) async => Result.success([expectedEvent]);

      final operation = controlled.getResultsByQuery('query');
      await Future<void>.delayed(Duration.zero);
      expect(controlled.placePhaseCalls, 1);
      expect(controlled.eventPhaseCalls, 0);
      pendingPlace.complete(Result.success([expectedPlace]));
      final result = await operation;

      expect(controlled.eventPhaseCalls, 1);
      expect(result.getOrNull(), [same(expectedPlace), same(expectedEvent)]);
    });

    test('event phase error fails the whole operation without place-only '
        'partial success', () async {
      final eventError = Exception('Event materialization failed');
      final controlled = ControllableSearchRepository(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(environment.store),
      );
      controlled.placePhase = (_) async => Result.success([makePlace()]);
      controlled.eventPhase = (_) async => Result.error(eventError);

      final result = await controlled.getResultsByQuery('query');

      expect(result, isA<Error<List<ContentBase>>>());
      expect(result.getOrNull(), isNull);
      expect((result as Error<List<ContentBase>>).error, same(eventError));
      expect(controlled.eventPhaseCalls, 1);
    });

    test('unexpected programming errors propagate instead of becoming '
        'recoverable errors', () async {
      final programmingError = StateError('Corrupt persisted entity');
      final controlled = ControllableSearchRepository(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(environment.store),
      );
      controlled.placePhase = (_) async => throw programmingError;

      await expectLater(
        controlled.getResultsByQuery('query'),
        throwsA(same(programmingError)),
      );
      expect(controlled.eventPhaseCalls, 0);
    });
  });
}
