// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  group('SearchRepositoryImpl - getEventIdsByQuery', () {
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
          makeEventEntity(
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
          makeEventEntity(
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
            makeEventEntity(
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
          final city = makeCityEntity(remoteId: 10, name: 'Campobasso');
          cityBox.put(city);

          final event = makeEventEntity(
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
          final city = makeCityEntity(remoteId: 12, name: 'Bojano');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 6,
            name: 'Giornata speciale',
            startDate: DateTime(now.year, 5, 15),
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
    // Soft-delete exclusion
    // -------------------------------------------------------------------------

    group('soft-delete exclusion', () {
      test(
        'excludes soft-deleted current-year event whose name matches query',
        () async {
          final now = DateTime.now();
          eventBox.put(
            makeEventEntity(
              remoteId: 200,
              name: 'Sagra fantasma',
              startDate: DateTime(now.year, 8),
              endDate: DateTime(now.year, 8, 5),
              isDeleted: true,
            ),
          );

          final result = await repository.getEventIdsByQuery('fantasma');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(200)));
        },
      );

      test(
        'excludes soft-deleted current-year event whose category matches query',
        () async {
          final now = DateTime.now();
          eventBox.put(
            makeEventEntity(
              remoteId: 201,
              name: 'Escursione cancellata',
              startDate: DateTime(now.year, 6),
              endDate: DateTime(now.year, 6, 10),
              contentCategoryIndex: 1, // ContentCategory.nature
              isDeleted: true,
            ),
          );

          final result = await repository.getEventIdsByQuery('natura');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(201)));
        },
      );

      test(
        'excludes soft-deleted current-year event linked to a matching city',
        () async {
          final now = DateTime.now();
          final city = makeCityEntity(remoteId: 30, name: 'Termoli');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 202,
            name: 'Evento fantasma',
            startDate: DateTime(now.year, 9),
            endDate: DateTime(now.year, 9, 5),
            cityId: city.remoteId,
            isDeleted: true,
          );
          eventBox.put(event);

          final result = await repository.getEventIdsByQuery('Termoli');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(202)));
        },
      );

      test(
        'excludes single-day event from a future year linked to a matching '
        'city',
        () async {
          final city = makeCityEntity(remoteId: 31, name: 'Larino');
          cityBox.put(city);

          final event = makeEventEntity(
            remoteId: 203,
            name: 'Futura giornata',
            startDate: DateTime(2099, 5, 15),
            cityId: city.remoteId,
          );
          eventBox.put(event);

          final result = await repository.getEventIdsByQuery('Larino');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(203)));
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
          final city = makeCityEntity(remoteId: 20, name: 'Venafro');
          cityBox.put(city);

          // The event name also contains "venafro" so it would be picked up by
          // both the name query and the city query.
          final event = makeEventEntity(
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

    // -------------------------------------------------------------------------
    // Category match (non-zero contentCategoryIndex)
    // -------------------------------------------------------------------------

    group('category match', () {
      test(
        'includes current-year event whose category label matches query',
        () async {
          final now = DateTime.now();
          eventBox.put(
            makeEventEntity(
              remoteId: 100,
              name: 'Escursione guidata',
              startDate: DateTime(now.year, 6),
              endDate: DateTime(now.year, 6, 10),
              contentCategoryIndex: 1, // ContentCategory.nature
            ),
          );

          final result = await repository.getEventIdsByQuery('natura');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, contains(100));
        },
      );

      test(
        'excludes event with non-matching category when querying by '
        'category label',
        () async {
          final now = DateTime.now();
          eventBox.put(
            makeEventEntity(
              remoteId: 101,
              name: 'Mostra storica',
              startDate: DateTime(now.year, 6),
              endDate: DateTime(now.year, 6, 10),
              contentCategoryIndex: 2, // ContentCategory.history
            ),
          );

          final result = await repository.getEventIdsByQuery('natura');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, isNot(contains(101)));
        },
      );

      test(
        'includes current-year event with food category when querying '
        '"cibo"',
        () async {
          final now = DateTime.now();
          eventBox.put(
            makeEventEntity(
              remoteId: 102,
              name: 'Degustazione vini',
              startDate: DateTime(now.year, 9),
              endDate: DateTime(now.year, 9, 5),
              contentCategoryIndex: 4, // ContentCategory.food
            ),
          );

          final result = await repository.getEventIdsByQuery('cibo');

          expect(result, isA<Success<List<int>>>());
          final ids = (result as Success<List<int>>).value;
          expect(ids, contains(102));
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // getPlaceIdsByQuery
  // -------------------------------------------------------------------------

  group('SearchRepositoryImpl - getPlaceIdsByQuery', () {
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

        final result = await repository.getPlaceIdsByQuery('natura');

        expect(result, isA<Success<List<int>>>());
        final ids = (result as Success<List<int>>).value;
        expect(ids, contains(200));
      },
    );

    test(
      'includes place whose name matches query',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 201,
            name: 'Castello di Campobasso',
          ),
        );

        final result = await repository.getPlaceIdsByQuery('Castello');

        expect(result, isA<Success<List<int>>>());
        final ids = (result as Success<List<int>>).value;
        expect(ids, contains(201));
      },
    );

    test(
      'deduplicates place when both name and category match',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 202,
            name: 'Cibo di strada',
            contentCategoryIndex: 4, // ContentCategory.food
          ),
        );

        final result = await repository.getPlaceIdsByQuery('cibo');

        expect(result, isA<Success<List<int>>>());
        final ids = (result as Success<List<int>>).value;
        expect(ids.where((id) => id == 202), hasLength(1));
      },
    );

    test('returns empty list when store is empty', () async {
      final result = await repository.getPlaceIdsByQuery('anything');

      expect(result, isA<Success<List<int>>>());
      expect((result as Success<List<int>>).value, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // getRelatedResults
  // -------------------------------------------------------------------------

  group('SearchRepositoryImpl - getRelatedResults', () {
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
      'returns places with the most frequent non-zero category '
      'from the previous search',
      () async {
        // Two places share the same category (nature).
        placeBox.put(
          makePlaceEntity(
            remoteId: 300,
            name: 'Unique name alpha',
            contentCategoryIndex: 1, // ContentCategory.nature
          ),
        );

        placeBox.put(
          makePlaceEntity(
            remoteId: 301,
            name: 'Natura viva',
            contentCategoryIndex: 1, // ContentCategory.nature
          ),
        );

        // A third place with a different category.
        placeBox.put(
          makePlaceEntity(
            remoteId: 302,
            name: 'Museo storico',
            contentCategoryIndex: 2, // ContentCategory.history
          ),
        );

        // Search by name (not category) so `_categorySearched` is false,
        // and only one nature place is returned.
        final searchResult = await repository.getPlaceIdsByQuery(
          'Unique name alpha',
        );
        expect(searchResult, isA<Success<List<int>>>());
        expect(
          (searchResult as Success<List<int>>).value,
          contains(300),
        );

        // The related results should return the other nature place (301)
        // that was not in the original search but shares the most frequent
        // category (nature).
        final result = await repository.getRelatedResults('anything');

        expect(result, isA<Success<List<int>>>());
        final ids = (result as Success<List<int>>).value;
        expect(ids, contains(301));
        expect(ids, isNot(contains(300)));
        expect(ids, isNot(contains(302)));
      },
    );

    test(
      'returns empty list when the previous search was category-based',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 310,
            name: 'Some place',
            contentCategoryIndex: 1,
          ),
        );

        // A category-based search sets `_categorySearched = true`.
        await repository.getPlaceIdsByQuery('natura');

        final result = await repository.getRelatedResults('anything');

        expect(result, isA<Success<List<int>>>());
        expect((result as Success<List<int>>).value, isEmpty);
      },
    );
  });
}
