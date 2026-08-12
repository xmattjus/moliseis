// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fixtures.dart';
import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  setUpAll(setUpMockSupabase);

  // ---------------------------------------------------------------------------
  // getAll
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - getAll', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = _makeRepository(objectBoxEnvironment);
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getAll();

      expect(result, isA<Success<List<Place>>>());
      expect((result as Success<List<Place>>).value, isEmpty);
    });

    test('returns all places from the store', () async {
      placeBox.put(makePlaceEntity(remoteId: 1, name: 'A'));
      placeBox.put(makePlaceEntity(remoteId: 2, name: 'B'));

      final result = await repository.getAll();

      expect(result, isA<Success<List<Place>>>());
      expect((result as Success<List<Place>>).value, hasLength(2));
    });

    test('sorts by name ascending when sort is byName', () async {
      placeBox.put(makePlaceEntity(remoteId: 1, name: 'Zeta'));
      placeBox.put(makePlaceEntity(remoteId: 2, name: 'Alpha'));

      final result = await repository.getAll();

      expect(result, isA<Success<List<Place>>>());
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, equals(['Alpha', 'Zeta']));
    });

    test('sorts by modifiedAt descending when sort is byDate', () async {
      placeBox.put(
        makePlaceEntity(
          remoteId: 1,
          name: 'Older',
          modifiedAt: DateTime(2025),
        ),
      );
      placeBox.put(
        makePlaceEntity(
          remoteId: 2,
          name: 'Newer',
          modifiedAt: DateTime(2026, 6),
        ),
      );

      final result = await repository.getAll(sort: ContentSort.byDate);

      expect(result, isA<Success<List<Place>>>());
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names.first, equals('Newer'));
    });

    test(
      'consecutive calls with different sorts return independently sorted '
      'results on the same repository instance',
      () async {
        // Zeta is newer; Alpha is older.
        placeBox.put(
          makePlaceEntity(
            remoteId: 1,
            name: 'Zeta',
            modifiedAt: DateTime(2026, 6),
          ),
        );
        placeBox.put(
          makePlaceEntity(
            remoteId: 2,
            name: 'Alpha',
            modifiedAt: DateTime(2025),
          ),
        );

        // First call sorts by name — expects [Alpha, Zeta].
        final byNameResult = await repository.getAll();
        expect(
          (byNameResult as Success<List<Place>>).value.map((p) => p.name),
          equals(['Alpha', 'Zeta']),
        );

        // Second call on the same instance sorts by date — must not be
        // contaminated by the first call's sort. Expects [Zeta, Alpha].
        final byDateResult = await repository.getAll(sort: ContentSort.byDate);
        expect(
          (byDateResult as Success<List<Place>>).value.map((p) => p.name).first,
          equals('Zeta'),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getById
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - getById', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = _makeRepository(objectBoxEnvironment);
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns the place when it exists in the store', () async {
      placeBox.put(makePlaceEntity(remoteId: 42, name: 'Campobasso'));

      final result = await repository.getById(42);

      expect(result, isA<Success<Place>>());
      expect((result as Success<Place>).value.remoteId, equals(42));
    });

    test('returns Error when place is not found', () async {
      final result = await repository.getById(999);

      expect(result, isA<Error<Place>>());
      expect((result as Error<Place>).error, isA<Exception>());
    });
  });

  // ---------------------------------------------------------------------------
  // getByCategories
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - getByCategories', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = _makeRepository(objectBoxEnvironment);
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'returns places matching the requested ContentCategory',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 1,
            name: 'A',
            contentCategoryIndex: ContentCategory.nature.index,
          ),
        );
        placeBox.put(
          makePlaceEntity(
            remoteId: 2,
            name: 'B',
            contentCategoryIndex: ContentCategory.history.index,
          ),
        );

        final result = await repository.getByCategories({
          ContentCategory.nature,
        });

        expect(result, isA<Success<List<Place>>>());
        final ids = (result as Success<List<Place>>).value.map(
          (p) => p.remoteId,
        );
        expect(ids, contains(1));
        expect(ids, isNot(contains(2)));
      },
    );

    test(
      'returns places matching any of multiple requested categories',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 1,
            name: 'A',
            contentCategoryIndex: ContentCategory.nature.index,
          ),
        );
        placeBox.put(
          makePlaceEntity(
            remoteId: 2,
            name: 'B',
            contentCategoryIndex: ContentCategory.history.index,
          ),
        );
        placeBox.put(
          makePlaceEntity(
            remoteId: 3,
            name: 'C',
            contentCategoryIndex: ContentCategory.food.index,
          ),
        );

        final result = await repository.getByCategories({
          ContentCategory.nature,
          ContentCategory.history,
        });

        expect(result, isA<Success<List<Place>>>());
        final ids = (result as Success<List<Place>>).value.map(
          (p) => p.remoteId,
        );
        expect(ids, containsAll([1, 2]));
        expect(ids, isNot(contains(3)));
      },
    );

    test(
      'returns empty list when no places match the requested ContentCategory',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 1,
            name: 'A',
            contentCategoryIndex: ContentCategory.nature.index,
          ),
        );

        final result = await repository.getByCategories({ContentCategory.food});

        expect(result, isA<Success<List<Place>>>());
        expect((result as Success<List<Place>>).value, isEmpty);
      },
    );

    test('sorts by name ascending when sort is byName', () async {
      placeBox.put(
        makePlaceEntity(
          remoteId: 1,
          name: 'Zeta',
          contentCategoryIndex: ContentCategory.nature.index,
        ),
      );
      placeBox.put(
        makePlaceEntity(
          remoteId: 2,
          name: 'Alpha',
          contentCategoryIndex: ContentCategory.nature.index,
        ),
      );
      placeBox.put(
        makePlaceEntity(
          remoteId: 3,
          name: 'Middle',
          contentCategoryIndex: ContentCategory.nature.index,
        ),
      );

      final result = await repository.getByCategories(
        {ContentCategory.nature},
      );

      expect(result, isA<Success<List<Place>>>());
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, equals(['Alpha', 'Middle', 'Zeta']));
    });

    test('sorts by modifiedAt descending when sort is byDate', () async {
      placeBox.put(
        makePlaceEntity(
          remoteId: 1,
          name: 'Older',
          contentCategoryIndex: ContentCategory.nature.index,
          modifiedAt: DateTime(2025),
        ),
      );
      placeBox.put(
        makePlaceEntity(
          remoteId: 2,
          name: 'Newer',
          contentCategoryIndex: ContentCategory.nature.index,
          modifiedAt: DateTime(2026, 6),
        ),
      );
      placeBox.put(
        makePlaceEntity(
          remoteId: 3,
          name: 'Middle',
          contentCategoryIndex: ContentCategory.nature.index,
          modifiedAt: DateTime(2025, 12),
        ),
      );

      final result = await repository.getByCategories(
        {ContentCategory.nature},
        sort: ContentSort.byDate,
      );

      expect(result, isA<Success<List<Place>>>());
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, equals(['Newer', 'Middle', 'Older']));
    });
  });

  // ---------------------------------------------------------------------------
  // getFavouritePlaceIds / setFavouritePlace
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - favourites', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = _makeRepository(objectBoxEnvironment);
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('getFavouritePlaceIds returns only saved place IDs', () async {
      placeBox.put(makePlaceEntity(remoteId: 1, isSaved: true));
      placeBox.put(makePlaceEntity(remoteId: 2));

      final result = await repository.getFavouritePlaceIds();

      expect(result, isA<Success<List<int>>>());
      final ids = (result as Success<List<int>>).value;
      expect(ids, contains(1));
      expect(ids, isNot(contains(2)));
    });

    test(
      'getFavouritePlaceIds returns empty list when no places are saved',
      () async {
        placeBox.put(makePlaceEntity(remoteId: 1));

        final result = await repository.getFavouritePlaceIds();

        expect(result, isA<Success<List<int>>>());
        expect((result as Success<List<int>>).value, isEmpty);
      },
    );

    test('setFavouritePlace saves a place', () async {
      placeBox.put(makePlaceEntity(remoteId: 1));

      final result = await repository.setFavouritePlace(1, true);

      expect(result, isA<Success<void>>());
      expect(placeBox.get(1)?.isSaved, isTrue);
    });

    test('setFavouritePlace unsaves a place', () async {
      placeBox.put(makePlaceEntity(remoteId: 1, isSaved: true));

      final result = await repository.setFavouritePlace(1, false);

      expect(result, isA<Success<void>>());
      expect(placeBox.get(1)?.isSaved, isFalse);
    });

    test(
      'setFavouritePlace returns Error when the place does not exist',
      () async {
        final result = await repository.setFavouritePlace(999, true);

        expect(result, isA<Error<void>>());
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getLatestPlaceIds
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - getLatestPlaceIds', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = _makeRepository(objectBoxEnvironment);
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns at most 6 IDs ordered by most recently created', () async {
      for (var i = 1; i <= 10; i++) {
        placeBox.put(
          makePlaceEntity(
            remoteId: i,
            name: 'Place $i',
            createdAt: DateTime(2026, 1, i),
          ),
        );
      }

      final result = await repository.getLatestPlaceIds();

      expect(result, isA<Success<List<int>>>());
      final ids = (result as Success<List<int>>).value;
      // Returns exactly 6 items (the cap).
      expect(ids.length, lessThanOrEqualTo(6));
      // The 6 most recent places are IDs 10..5 (createdAt Jan 10..5).
      expect(ids, containsAll([10, 9, 8, 7, 6, 5]));
      expect(ids, isNot(contains(4)));
      expect(ids, isNot(contains(3)));
      // Ordered descending by createdAt.
      expect(ids, equals([10, 9, 8, 7, 6, 5]));
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getLatestPlaceIds();

      expect(result, isA<Success<List<int>>>());
      expect((result as Success<List<int>>).value, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getSuggestions
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - getSuggestions', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<CityEntity> cityBox;
    late Box<MediaEntity> mediaBox;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      cityBox = objectBoxEnvironment.store.box<CityEntity>();
      mediaBox = objectBoxEnvironment.store.box<MediaEntity>();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = _makeRepository(objectBoxEnvironment);
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'returns a unique capped subset of non-deleted places',
      () async {
        final eligibleIds = <int>{};

        for (var i = 1; i <= 8; i++) {
          eligibleIds.add(i);
          placeBox.put(makePlaceEntity(remoteId: i, name: 'Place $i'));
        }

        placeBox.put(
          makePlaceEntity(
            remoteId: 99,
            name: 'Deleted place',
            isDeleted: true,
          ),
        );

        final result = await repository.getSuggestions();

        expect(result, isA<Success<List<Place>>>());
        final places = (result as Success<List<Place>>).value;
        final ids = places.map((place) => place.remoteId).toList();

        // Suggestions are intentionally shuffled, so assert their contract
        // rather than a particular order or membership of the five-item sample.
        expect(places, hasLength(5));
        expect(ids.toSet(), hasLength(ids.length));
        expect(ids, everyElement(isIn(eligibleIds)));
        expect(ids, isNot(contains(99)));
      },
    );

    test(
      'returns every eligible place when fewer than five are available',
      () async {
        placeBox.put(makePlaceEntity(remoteId: 1, name: 'First'));
        placeBox.put(makePlaceEntity(remoteId: 2, name: 'Second'));
        placeBox.put(makePlaceEntity(remoteId: 3, name: 'Third'));

        final result = await repository.getSuggestions();

        expect(result, isA<Success<List<Place>>>());
        final ids = (result as Success<List<Place>>).value
            .map((place) => place.remoteId)
            .toSet();
        expect(ids, equals(<int>{1, 2, 3}));
      },
    );

    test('excludes soft-deleted places', () async {
      placeBox.put(makePlaceEntity(remoteId: 1, name: 'Visible'));
      placeBox.put(
        makePlaceEntity(
          remoteId: 2,
          name: 'Deleted',
          isDeleted: true,
        ),
      );

      final result = await repository.getSuggestions();

      expect(result, isA<Success<List<Place>>>());
      final places = (result as Success<List<Place>>).value;
      expect(places.map((place) => place.remoteId), equals(<int>[1]));
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getSuggestions();

      expect(result, isA<Success<List<Place>>>());
      expect((result as Success<List<Place>>).value, isEmpty);
    });

    test('maps persisted place, city, and non-deleted media fields', () async {
      final city = makeCityEntity(remoteId: 10, name: 'Termoli');
      cityBox.put(city);

      final place = makePlaceEntity(
        remoteId: 1,
        name: 'Castello Svevo',
        description: 'A historic castle.',
        coordinates: const <double>[41.999, 14.993],
        cityId: city.remoteId,
        contentCategoryIndex: ContentCategory.history.index,
        isSaved: true,
      );
      placeBox.put(place);

      mediaBox.put(
        makeMediaEntity(
          remoteId: 100,
          url: 'https://cdn.example.com/castello.jpg',
          width: 1280,
          height: 720,
          placeId: place.remoteId,
        ),
      );
      mediaBox.put(
        makeMediaEntity(
          remoteId: 101,
          url: 'https://cdn.example.com/deleted.jpg',
          width: 1280,
          height: 720,
          placeId: place.remoteId,
          isDeleted: true,
        ),
      );

      final result = await repository.getSuggestions();

      expect(result, isA<Success<List<Place>>>());
      final mappedPlace = (result as Success<List<Place>>).value.single;
      expect(mappedPlace.remoteId, place.remoteId);
      expect(mappedPlace.name, place.name);
      expect(mappedPlace.description, place.description);
      expect(mappedPlace.category, ContentCategory.history);
      // ObjectBox persists vector coordinates as float32 values.
      expect(mappedPlace.coordinates.latitude, closeTo(41.999, 0.000001));
      expect(mappedPlace.coordinates.longitude, closeTo(14.993, 0.000001));
      expect(mappedPlace.isSaved, isTrue);
      expect(mappedPlace.city?.remoteId, city.remoteId);
      expect(mappedPlace.city?.name, city.name);
      expect(mappedPlace.media, hasLength(1));
      expect(mappedPlace.media.single.remoteId, 100);
      expect(
        mappedPlace.media.single.url,
        'https://cdn.example.com/castello.jpg',
      );
      expect(mappedPlace.media.single.areaName, place.name);
      expect(mappedPlace.media.single.cityName, city.name);
    });
  });

  // ---------------------------------------------------------------------------
  // prepareSync — error path
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - prepareSync error handling', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late PlaceRepositoryImpl repository;
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment()..stubUnavailable();
      repository = PlaceRepositoryImpl(
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

      expect(result, isA<Error<List<PlaceDto>>>());
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      final event = failedCall!.event as RepositorySyncFailed;
      expect(event.repositoryName, 'place');
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // commitSync — success path
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - commitSync', () {
    late MockLogger mockLogger;
    late MockSupabaseEnvironment supabaseEnv;
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      mockLogger = MockLogger();
      supabaseEnv = MockSupabaseEnvironment();
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = PlaceRepositoryImpl(
        logger: mockLogger,
        supabaseI: supabaseEnv.mockSupabase,
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('inserts a new place that is absent from the local store', () async {
      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso',
          'description': '',
          'latitude': 0,
          'longitude': 0,
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<PlaceDto>>).value;
      repository.commitSync(dtos);

      expect(placeBox.get(1)?.name, equals('Campobasso'));
      expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
    });

    test('skips a place that already matches the local copy', () async {
      placeBox.put(
        makePlaceEntity(
          remoteId: 1,
          name: 'Campobasso',
          createdAt: DateTime(2024),
          modifiedAt: DateTime(2024),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso',
          'description': '',
          'latitude': 0,
          'longitude': 0,
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<PlaceDto>>).value;
      repository.commitSync(dtos);

      expect(placeBox.get(1)?.name, equals('Campobasso'));
      expect(mockLogger.containsEvent<EntityInsertSuccess>(), isFalse);
      expect(mockLogger.containsEvent<EntityUpdateSuccess>(), isFalse);
    });

    test('updates an existing place when remote data differs', () async {
      placeBox.put(
        makePlaceEntity(
          remoteId: 1,
          name: 'Campobasso',
          modifiedAt: DateTime(2024),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso Aggiornato',
          'description': '',
          'latitude': 0,
          'longitude': 0,
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2025-06-01T00:00:00.000',
        },
      ]);

      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<PlaceDto>>).value;
      repository.commitSync(dtos);

      expect(placeBox.get(1)?.name, equals('Campobasso Aggiornato'));
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    test(
      'persists and clears description Delta from newer remote data',
      () async {
        final descriptionDelta = <Map<String, dynamic>>[
          {'insert': 'Rich place description\n'},
        ];
        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso',
            'description': 'Rich place description',
            'description_delta': descriptionDelta,
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'created_at': '2024-01-01T00:00:00.000',
            'modified_at': '2024-01-02T00:00:00.000',
          },
        ]);

        final initialResult = await repository.prepareSync();
        repository.commitSync((initialResult as Success<List<PlaceDto>>).value);

        expect(placeBox.get(1)?.descriptionDelta, descriptionDelta);

        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso',
            'description': 'Legacy place description',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'created_at': '2024-01-01T00:00:00.000',
            'modified_at': '2024-01-03T00:00:00.000',
          },
        ]);

        final clearingResult = await repository.prepareSync();
        repository.commitSync(
          (clearingResult as Success<List<PlaceDto>>).value,
        );

        expect(placeBox.get(1)?.descriptionDelta, isNull);
      },
    );

    test('invalidates the in-memory cache after a successful sync', () async {
      // Populate the cache via getAll().
      placeBox.put(makePlaceEntity(remoteId: 1, name: 'Old'));
      await repository.getAll();

      // Sync adds a new place from remote.
      supabaseEnv.stubSelectResponse([
        {
          'id': 2,
          'name': 'New Place',
          'description': '',
          'latitude': 0,
          'longitude': 0,
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);
      final prepareResult = await repository.prepareSync();
      final dtos = (prepareResult as Success<List<PlaceDto>>).value;
      repository.commitSync(dtos);

      // A subsequent getAll() must reflect the new place, not the stale cache.
      final result = await repository.getAll();
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, contains('New Place'));
    });

    test(
      'persists assigned and cleared city relations from complete rows',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 1,
            cityId: 7,
            modifiedAt: DateTime.utc(2024),
          ),
        );
        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso',
            'description': '',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'city_id': 99,
            'created_at': '2024-01-01T00:00:00.000Z',
            'modified_at': '2025-01-01T00:00:00.000Z',
          },
        ]);

        final assignedDtos =
            ((await repository.prepareSync()) as Success<List<PlaceDto>>).value;
        final assignedResult = repository.commitSync(assignedDtos);

        expect(assignedResult, isA<Success<void>>());
        expect(placeBox.get(1)?.cityToOneId, 99);
        expect(placeBox.get(1)?.city.targetId, 99);

        supabaseEnv.stubSelectResponse([
          {
            'id': 1,
            'name': 'Campobasso',
            'description': '',
            'latitude': 0,
            'longitude': 0,
            'category': 'unknown',
            'city_id': null,
            'created_at': '2024-01-01T00:00:00.000Z',
            'modified_at': '2026-01-01T00:00:00.000Z',
          },
        ]);

        final clearedDtos =
            ((await repository.prepareSync()) as Success<List<PlaceDto>>).value;
        final clearedResult = repository.commitSync(clearedDtos);

        expect(clearedResult, isA<Success<void>>());
        expect(placeBox.get(1)?.cityToOneId, isNull);
        expect(placeBox.get(1)?.city.targetId, 0);
      },
    );

    test('prepareSync returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(
          message: 'relation places does not exist',
        ),
      );

      final result = await repository.prepareSync();

      expect(result, isA<Error<List<PlaceDto>>>());
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      final event = failedCall!.event as RepositorySyncFailed;
      expect(event.repositoryName, 'place');
      expect(failedCall.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });

  group('PlaceRepositoryImpl - relation scalar preservation', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late Box<PlaceEntity> placeBox;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      placeBox = objectBoxEnvironment.store.box<PlaceEntity>();
      repository = PlaceRepositoryImpl(
        logger: MockLogger(),
        supabaseI: MockSupabase(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test(
      'preserves city relations through favourite copies and Keep merges',
      () async {
        placeBox.put(
          makePlaceEntity(
            remoteId: 1,
            cityId: 7,
            modifiedAt: DateTime.utc(2024),
          ),
        );

        final favouriteResult = await repository.setFavouritePlace(1, true);

        expect(favouriteResult, isA<Success<void>>());
        expect(placeBox.get(1)?.cityToOneId, 7);
        expect(placeBox.get(1)?.city.targetId, 7);

        final mergeResult = repository.commitSync([
          _relationTestPlaceDto(modifiedAt: DateTime.utc(2027)),
        ]);

        expect(mergeResult, isA<Success<void>>());
        expect(placeBox.get(1)?.cityToOneId, 7);
        expect(placeBox.get(1)?.city.targetId, 7);
      },
    );

    test('preserves city relations through soft deletion and a Keep merge', () {
      placeBox.put(
        makePlaceEntity(
          remoteId: 1,
          cityId: 7,
          modifiedAt: DateTime.utc(2024),
        ),
      );

      final deleteResult = repository.commitSync([
        _relationTestPlaceDto(
          modifiedAt: DateTime.utc(2025),
          deletedAt: DateTime.utc(2025),
        ),
      ]);

      expect(deleteResult, isA<Success<void>>());
      expect(placeBox.get(1)?.cityToOneId, 7);
      expect(placeBox.get(1)?.city.targetId, 7);

      final restoreResult = repository.commitSync([
        _relationTestPlaceDto(modifiedAt: DateTime.utc(2027)),
      ]);

      expect(restoreResult, isA<Success<void>>());
      expect(placeBox.get(1)?.isDeleted, isFalse);
      expect(placeBox.get(1)?.cityToOneId, 7);
      expect(placeBox.get(1)?.city.targetId, 7);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PlaceRepositoryImpl _makeRepository(TestObjectBoxEnvironment env) =>
    PlaceRepositoryImpl(
      logger: MockLogger(),
      supabaseI: MockSupabase(),
      objectBoxI: TestObjectBox(env.store),
    );

PlaceDto _relationTestPlaceDto({
  RelationUpdate<int> cityId = const Keep<int>(),
  required DateTime modifiedAt,
  DateTime? deletedAt,
}) => PlaceDto(
  id: 1,
  name: 'Place',
  description: '',
  latitude: 0,
  longitude: 0,
  category: ContentCategory.unknown,
  cityId: cityId,
  createdAt: DateTime.utc(2024),
  modifiedAt: modifiedAt,
  deletedAt: deletedAt,
);
