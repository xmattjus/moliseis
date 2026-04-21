// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/data-sources/place_supabase_table.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/objectbox_test_store.dart';

void main() {
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
      'does not mutate cached order on consecutive calls with different sorts',
      () async {
        placeBox.put(_createPlace(remoteId: 1, name: 'Zeta'));
        placeBox.put(_createPlace(remoteId: 2, name: 'Alpha'));

        // First call sorts by name.
        await repository.getAll(sort: ContentSort.byName);

        // Second call with different sort should return a fresh sort, not a
        // re-sort of the already-sorted result.
        placeBox.put(
          _createPlace(
            remoteId: 1,
            name: 'Zeta',
            modifiedAt: DateTime(2025, 1, 1),
          ),
        );
        placeBox.put(
          _createPlace(
            remoteId: 2,
            name: 'Alpha',
            modifiedAt: DateTime(2026, 6, 1),
          ),
        );

        // Create a fresh repository (no cache) to get a clean byDate sort.
        final freshRepo = _makeRepository(objectBoxEnvironment);
        final result = await freshRepo.getAll(sort: ContentSort.byDate);

        expect(result, isA<Success<List<Place>>>());
        final names = (result as Success<List<Place>>).value
            .map((p) => p.name)
            .toList();
        expect(names.first, equals('Alpha'));
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

    test(
      'returns Error with PlaceNullException when place is not found',
      () async {
        final result = await repository.getById(999);

        expect(result, isA<Error<Place>>());
        expect((result as Error<Place>).error, isA<PlaceNullException>());
      },
    );
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

    test('returns at most 6 IDs', () async {
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
      expect((result as Success<List<int>>).value.length, lessThanOrEqualTo(6));
    });

    test('returns empty list when store is empty', () async {
      final result = await repository.getLatestPlaceIds();

      expect(result, isA<Success<List<int>>>());
      expect((result as Success<List<int>>).value, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // synchronize error handling
  // ---------------------------------------------------------------------------

  group('PlaceRepositoryImpl - synchronize error handling', () {
    late TestObjectBoxEnvironment objectBoxEnvironment;
    late PlaceRepositoryImpl repository;

    setUp(() async {
      objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      repository = PlaceRepositoryImpl(
        logger: Talker(),
        supabaseI: _ThrowingSupabase(),
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
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PlaceRepositoryImpl _makeRepository(TestObjectBoxEnvironment env) =>
    PlaceRepositoryImpl(
      logger: Talker(),
      supabaseI: _FakeSupabase(),
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
    category: category,
    isSaved: isSaved,
    createdAt: createdAt ?? now,
    modifiedAt: modifiedAt ?? now,
    city: ToOne<CityEntity>(),
    media: ToMany<MediaEntity>(),
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
