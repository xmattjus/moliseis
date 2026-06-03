// Tests seed multiple entities of the same type consecutively; the explicit
// multi-statement form is preferred for readability over cascade notation.
// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/data-sources/place_supabase_table.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
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
      placeBox.put(_createPlace(remoteId: 1, name: 'A'));
      placeBox.put(_createPlace(remoteId: 2, name: 'B'));

      final result = await repository.getAll();

      expect(result, isA<Success<List<Place>>>());
      expect((result as Success<List<Place>>).value, hasLength(2));
    });

    test('sorts by name ascending when sort is byName', () async {
      placeBox.put(_createPlace(remoteId: 1, name: 'Zeta'));
      placeBox.put(_createPlace(remoteId: 2, name: 'Alpha'));

      final result = await repository.getAll(sort: ContentSort.byName);

      expect(result, isA<Success<List<Place>>>());
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, equals(['Alpha', 'Zeta']));
    });

    test('sorts by modifiedAt descending when sort is byDate', () async {
      placeBox.put(
        _createPlace(
          remoteId: 1,
          name: 'Older',
          modifiedAt: DateTime(2025, 1, 1),
        ),
      );
      placeBox.put(
        _createPlace(
          remoteId: 2,
          name: 'Newer',
          modifiedAt: DateTime(2026, 6, 1),
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
          _createPlace(
            remoteId: 1,
            name: 'Zeta',
            modifiedAt: DateTime(2026, 6, 1),
          ),
        );
        placeBox.put(
          _createPlace(
            remoteId: 2,
            name: 'Alpha',
            modifiedAt: DateTime(2025, 1, 1),
          ),
        );

        // First call sorts by name — expects [Alpha, Zeta].
        final byNameResult = await repository.getAll(sort: ContentSort.byName);
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
      placeBox.put(_createPlace(remoteId: 42, name: 'Campobasso'));

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

    test('returns places matching the requested category', () async {
      placeBox.put(
        _createPlace(remoteId: 1, name: 'A', category: ContentCategory.nature),
      );
      placeBox.put(
        _createPlace(remoteId: 2, name: 'B', category: ContentCategory.history),
      );

      final result = await repository.getByCategories({ContentCategory.nature});

      expect(result, isA<Success<List<Place>>>());
      final ids = (result as Success<List<Place>>).value.map((p) => p.remoteId);
      expect(ids, contains(1));
      expect(ids, isNot(contains(2)));
    });

    test(
      'returns places matching any of multiple requested categories',
      () async {
        placeBox.put(
          _createPlace(
            remoteId: 1,
            name: 'A',
            category: ContentCategory.nature,
          ),
        );
        placeBox.put(
          _createPlace(
            remoteId: 2,
            name: 'B',
            category: ContentCategory.history,
          ),
        );
        placeBox.put(
          _createPlace(remoteId: 3, name: 'C', category: ContentCategory.food),
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
      'returns empty list when no places match the requested category',
      () async {
        placeBox.put(
          _createPlace(
            remoteId: 1,
            name: 'A',
            category: ContentCategory.nature,
          ),
        );

        final result = await repository.getByCategories({ContentCategory.food});

        expect(result, isA<Success<List<Place>>>());
        expect((result as Success<List<Place>>).value, isEmpty);
      },
    );

    test('sorts by name ascending when sort is byName', () async {
      placeBox.put(
        _createPlace(
          remoteId: 1,
          name: 'Zeta',
          category: ContentCategory.nature,
        ),
      );
      placeBox.put(
        _createPlace(
          remoteId: 2,
          name: 'Alpha',
          category: ContentCategory.nature,
        ),
      );
      placeBox.put(
        _createPlace(
          remoteId: 3,
          name: 'Middle',
          category: ContentCategory.nature,
        ),
      );

      final result = await repository.getByCategories(
        {ContentCategory.nature},
        sort: ContentSort.byName,
      );

      expect(result, isA<Success<List<Place>>>());
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, equals(['Alpha', 'Middle', 'Zeta']));
    });

    test('sorts by modifiedAt descending when sort is byDate', () async {
      placeBox.put(
        _createPlace(
          remoteId: 1,
          name: 'Older',
          category: ContentCategory.nature,
          modifiedAt: DateTime(2025, 1, 1),
        ),
      );
      placeBox.put(
        _createPlace(
          remoteId: 2,
          name: 'Newer',
          category: ContentCategory.nature,
          modifiedAt: DateTime(2026, 6, 1),
        ),
      );
      placeBox.put(
        _createPlace(
          remoteId: 3,
          name: 'Middle',
          category: ContentCategory.nature,
          modifiedAt: DateTime(2025, 12, 1),
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
      placeBox.put(_createPlace(remoteId: 1, isSaved: true));
      placeBox.put(_createPlace(remoteId: 2, isSaved: false));

      final result = await repository.getFavouritePlaceIds();

      expect(result, isA<Success<List<int>>>());
      final ids = (result as Success<List<int>>).value;
      expect(ids, contains(1));
      expect(ids, isNot(contains(2)));
    });

    test(
      'getFavouritePlaceIds returns empty list when no places are saved',
      () async {
        placeBox.put(_createPlace(remoteId: 1, isSaved: false));

        final result = await repository.getFavouritePlaceIds();

        expect(result, isA<Success<List<int>>>());
        expect((result as Success<List<int>>).value, isEmpty);
      },
    );

    test('setFavouritePlace saves a place', () async {
      placeBox.put(_createPlace(remoteId: 1, isSaved: false));

      final result = await repository.setFavouritePlace(1, true);

      expect(result, isA<Success<void>>());
      expect(placeBox.get(1)?.isSaved, isTrue);
    });

    test('setFavouritePlace unsaves a place', () async {
      placeBox.put(_createPlace(remoteId: 1, isSaved: true));

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
          _createPlace(
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
  // getSuggestedPlaceIds
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - getSuggestedPlaceIds', () {
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

    test('returns at most 5 place IDs from the store', () async {
      for (var i = 1; i <= 8; i++) {
        placeBox.put(_createPlace(remoteId: i, name: 'Place $i'));
      }

      final result = await repository.getSuggestedPlaceIds();

      expect(result, isA<Success<List<int>>>());
      final ids = (result as Success<List<int>>).value;
      expect(ids.length, lessThanOrEqualTo(5));
      // All returned IDs belong to the seeded set.
      expect(ids, everyElement(inInclusiveRange(1, 8)));
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getSuggestedPlaceIds();

      expect(result, isA<Success<List<int>>>());
      expect((result as Success<List<int>>).value, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // synchronize — error path
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - synchronize error handling', () {
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
        supabaseTable: PlaceSupabaseTable(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      );
    });

    tearDown(() async {
      await objectBoxEnvironment.dispose();
    });

    test('returns Error when Supabase throws an exception', () async {
      final result = await repository.synchronize();

      expect(result, isA<Error<void>>());
      verify(
        () => mockLogger.log(const RepositorySyncStarted('place')),
      ).called(1);
      verify(
        () => mockLogger.log(
          const RepositorySyncFailed('place'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // synchronize — success path
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - synchronize success path', () {
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
        supabaseTable: PlaceSupabaseTable(),
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
          'coordinates': [0, 0],
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final result = await repository.synchronize();

      expect(result, isA<Success<void>>());
      expect(placeBox.get(1)?.name, equals('Campobasso'));
      verify(
        () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
      ).called(1);
    });

    test('skips a place that already matches the local copy', () async {
      placeBox.put(
        _createPlace(
          remoteId: 1,
          name: 'Campobasso',
          createdAt: DateTime(2024, 1, 1),
          modifiedAt: DateTime(2024, 1, 1),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso',
          'description': '',
          'coordinates': [0, 0],
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);

      final result = await repository.synchronize();

      expect(result, isA<Success<void>>());
      expect(placeBox.get(1)?.name, equals('Campobasso'));
      verifyNever(
        () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
      );
      verifyNever(
        () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
      );
    });

    test('updates an existing place when remote data differs', () async {
      placeBox.put(
        _createPlace(
          remoteId: 1,
          name: 'Campobasso',
          modifiedAt: DateTime(2024, 1, 1),
        ),
      );

      supabaseEnv.stubSelectResponse([
        {
          'id': 1,
          'name': 'Campobasso Aggiornato',
          'description': '',
          'coordinates': [0, 0],
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2025-06-01T00:00:00.000',
        },
      ]);

      final result = await repository.synchronize();

      expect(result, isA<Success<void>>());
      expect(placeBox.get(1)?.name, equals('Campobasso Aggiornato'));
      verify(
        () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
      ).called(1);
    });

    test('invalidates the in-memory cache after a successful sync', () async {
      // Populate the cache via getAll().
      placeBox.put(_createPlace(remoteId: 1, name: 'Old'));
      await repository.getAll();

      // Sync adds a new place from remote.
      supabaseEnv.stubSelectResponse([
        {
          'id': 2,
          'name': 'New Place',
          'description': '',
          'coordinates': [0, 0],
          'category': 'unknown',
          'created_at': '2024-01-01T00:00:00.000',
          'modified_at': '2024-01-01T00:00:00.000',
        },
      ]);
      await repository.synchronize();

      // A subsequent getAll() must reflect the new place, not the stale cache.
      final result = await repository.getAll();
      final names = (result as Success<List<Place>>).value
          .map((p) => p.name)
          .toList();
      expect(names, contains('New Place'));
    });

    test('returns Error when Supabase query fails', () async {
      supabaseEnv.stubSelectError(
        const PostgrestException(
          message: 'relation "places_v2" does not exist',
        ),
      );

      final result = await repository.synchronize();

      expect(result, isA<Error<void>>());
      verify(
        () => mockLogger.log(
          const RepositorySyncFailed('place'),
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

PlaceRepositoryImpl _makeRepository(TestObjectBoxEnvironment env) =>
    PlaceRepositoryImpl(
      logger: MockLogger(),
      supabaseI: MockSupabase(),
      supabaseTable: PlaceSupabaseTable(),
      objectBoxI: TestObjectBox(env.store),
    );

PlaceEntity _createPlace({
  required int remoteId,
  String name = 'Test Place',
  ContentCategory category = ContentCategory.unknown,
  bool isSaved = false,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return PlaceEntity(
    remoteId: remoteId,
    name: name,
    description: 'Franco',
    category: category,
    isSaved: isSaved,
    createdAt: createdAt ?? now,
    modifiedAt: modifiedAt ?? now,
    city: ToOne<CityEntity>(),
    media: ToMany<MediaEntity>(),
  );
}
