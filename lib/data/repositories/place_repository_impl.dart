import 'package:collection/collection.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/data-sources/place_supabase_table.dart';
import 'package:moliseis/data/mappers/place_entity_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  PlaceRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required PlaceSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _logger = logger,
       _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _placeBox = objectBoxI.store.box<PlaceEntity>();

  final Logger _logger;

  final Supabase _supabase;
  final PlaceSupabaseTable _supabaseTable;
  final Box<PlaceEntity> _placeBox;

  List<Place>? _cache;

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    try {
      if (_cache == null) {
        final entities = await _placeBox.getAllAsync();
        _cache = entities.map<Place>((entity) => entity.toModel()).toList();
      }

      final mappedResults = List<Place>.of(_cache!)
        ..sort(
          (a, b) => switch (sort) {
            ContentSort.byName => a.name.compareTo(b.name),
            ContentSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
          },
        );

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getAll'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    Query<PlaceEntity>? query;

    try {
      final condition = PlaceEntity_.dbType.oneOf(
        categories.map((e) => e.index).toList(),
      );
      final builder = _placeBox.query(condition);
      query = builder.build();
      final results = await query.findAsync();

      final mappedResults = results
          .map<Place>((entity) => entity.toModel())
          .toList();

      // Code readability benefits from separate statements over cascades.
      // ignore: cascade_invocations
      mappedResults.sort(
        (a, b) => switch (sort) {
          ContentSort.byName => a.name.compareTo(b.name),
          ContentSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
        },
      );

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getByCategories'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Place>>> getByCoordinates(List<double> coordinates) async {
    Query<PlaceEntity>? query;

    try {
      query = _placeBox
          .query(PlaceEntity_.coordinates.nearestNeighborsF32(coordinates, 300))
          .build();
      // Duplication of receiver favors code readability.
      // ignore: cascade_invocations
      query.limit = 3;
      final resultsWithScores = await query.findWithScoresAsync();
      final results = resultsWithScores
          .map<PlaceEntity>((element) => element.object)
          .where(
            (place) =>
                place.coordinates.first != coordinates.first ||
                place.coordinates.last != coordinates.last,
          )
          .toList();

      final mappedResults = results
          .map<Place>((entity) => entity.toModel())
          .toList();

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getByCoordinates'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<Place>> getById(int id) async {
    final result = await _placeBox.getAsync(id);

    if (result != null) {
      return Result.success(result.toModel());
    } else {
      return Result.error(Exception('Place not found: $id'));
    }
  }

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async {
    try {
      final query = _placeBox
          .query(PlaceEntity_.coordinates.nearestNeighborsF32(coordinates, 3))
          .build();
      final resultsWithScores = await query.findIdsWithScoresAsync();
      query.close();

      return Result.success(
        resultsWithScores.map<int>((element) => element.id).toList(),
      );
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getIdsByCoordinates'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  @override
  Future<Result<void>> synchronize() async {
    _logger.log(const RepositorySyncStarted('place'));

    // Resets the list of cached places before synchronizing.
    _cache = null;

    try {
      final places = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<PlaceEntity>.unmodifiable(
        places.map<PlaceEntity>(PlaceEntity.fromJson),
      );

      final local = Set<PlaceEntity>.unmodifiable(_placeBox.getAll());

      final placesToPut = remote.difference(local);

      for (final place in placesToPut) {
        final existingPlace = local.firstWhereOrNull(
          (test) => test.remoteId == place.remoteId,
        );

        if (existingPlace == null) {
          place.city.targetId = place.cityToOneId;

          _placeBox.put(place);

          _logger.log(EntityInsertSuccess('place', place.remoteId));
        } else {
          if (existingPlace != place) {
            final copy = existingPlace.copyWith(
              name: place.name,
              description: place.description,
              coordinates: place.coordinates,
              category: place.category,
              cityToOneId: () => place.cityToOneId,
              createdAt: place.createdAt,
              modifiedAt: place.modifiedAt,
            );

            _placeBox.put(copy);

            _logger.log(
              EntityUpdateSuccess('place', place.remoteId),
            );
          }
        }
      }

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const RepositorySyncFailed('place'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async {
    try {
      final query = _placeBox.query().order(
        PlaceEntity_.createdAt,
        flags: Order.descending,
      );
      final builder = query.build()..limit = 6;
      final places = await builder.findIdsAsync();
      builder.close();
      return Result.success(places);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getLatestPlaceIds'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async {
    Query<PlaceEntity>? query;

    try {
      query = _placeBox.query(PlaceEntity_.isSaved.equals(true)).build();
      // Casts the query results to a growable list with toList().
      final places = query.findIds().toList();
      return Result.success(places);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getFavouritePlaceIds'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<void>> setFavouritePlace(int remoteId, bool save) async {
    try {
      final place = await _placeBox.getAsync(remoteId);

      if (place == null) {
        throw Exception('Place with remote ID: $remoteId not found.');
      }

      final copy = place.copyWith(isSaved: save);

      _placeBox.put(copy);

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        EntityUpdateFailed('place', remoteId, method: 'setFavouritePlace'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async {
    try {
      final query = _placeBox.query();
      final builder = query.build();
      final places = builder.findIds()..shuffle();
      final result = places.take(5).toList();
      builder.close();
      return Result.success(result);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const EntityLoadFailed('place', method: 'getSuggestedPlaceIds'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }
}
