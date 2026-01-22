import 'package:logging/logging.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/data/sources/place_supabase_table.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/messages.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  PlaceRepositoryImpl({
    required Supabase supabaseI,
    required PlaceSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _placeBox = objectBoxI.store.box<Place>();

  final _log = Logger('PlaceRepositoryImpl');

  final Supabase _supabase;
  final PlaceSupabaseTable _supabaseTable;
  final Box<Place> _placeBox;

  List<Place>? _cache;

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    try {
      final places = _cache ??= await _placeBox.getAllAsync();

      places.sort(
        (a, b) => switch (sort) {
          ContentSort.byName => a.name.compareTo(b.name),
          ContentSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
        },
      );

      return Result.success(places);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading all the places.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    Query<Place>? query;

    try {
      final condition = Place_.dbType.oneOf(
        categories.map((e) => e.index).toList(),
      );
      final builder = _placeBox.query(condition);
      query = builder.build();
      final results = await query.findAsync();

      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading places by category.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Place>>> getByCoordinates(List<double> coordinates) async {
    Query<Place>? query;

    try {
      query = _placeBox
          .query(Place_.coordinates.nearestNeighborsF32(coordinates, 300))
          .build();
      query.limit = 3;
      final resultsWithScores = await query.findWithScoresAsync();
      query.close();
      final results = resultsWithScores
          .map<Place>((element) => element.object)
          .where(
            (place) =>
                place.coordinates.first != coordinates.first ||
                place.coordinates.last != coordinates.last,
          )
          .toList();
      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading places by coordinates.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<Place>> getById(int id) async {
    final place = await _placeBox.getAsync(id);

    if (place != null) {
      return Result.success(place);
    } else {
      return Result.error(PlaceNullException(id));
    }
  }

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async {
    final query = _placeBox
        .query(Place_.coordinates.nearestNeighborsF32(coordinates, 3))
        .build();
    final resultsWithScores = await query.findIdsWithScoresAsync();
    query.close();
    final results = resultsWithScores
        .map<int>((element) => element.id)
        .toList();

    return Result.success(results);
  }

  @override
  Future<Result<void>> synchronize() async {
    _log.info(Messages.repositoryUpdate);

    // Resets the list of cached places before synchronizing.
    _cache = null;

    try {
      final places = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<Place>.unmodifiable(
        places.map<Place>((element) => Place.fromJson(element)),
      );

      final local = Set<Place>.unmodifiable(_placeBox.getAll());

      final placesToPut = remote.difference(local);

      for (final place in placesToPut) {
        final existingPlace = local.where(
          (test) => test.remoteId == place.remoteId,
        );

        if (existingPlace.isEmpty) {
          _log.info(Messages.objectInsert('place', place.remoteId));

          place.city.targetId = place.cityToOneId;

          _placeBox.put(place);
        } else if (existingPlace.length == 1) {
          if (existingPlace.first != place) {
            _log.info(
              Messages.objectUpdate('place', existingPlace.first.remoteId),
            );

            final copy = existingPlace.first.copyWith(
              name: place.name,
              description: place.description,
              coordinates: place.coordinates,
              category: place.category,
              cityToOneId: () => place.cityToOneId,
              createdAt: place.createdAt,
              modifiedAt: place.modifiedAt,
            );

            _placeBox.put(copy);
          }
        }
      }

      removeLeftovers(_placeBox, remote);

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(Messages.repositoryUpdateException, error, stackTrace);

      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async {
    try {
      final query = _placeBox.query().order(
        Place_.createdAt,
        flags: Order.descending,
      );
      final builder = query.build()..limit = 6;
      final places = await builder.findIdsAsync();
      builder.close();
      return Result.success(places);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading latest places.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async {
    Query<Place>? query;

    try {
      query = _placeBox.query(Place_.isSaved.equals(true)).build();
      // Casts the query results to a growable list with toList().
      final places = query.findIds().toList();
      return Result.success(places);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading favourite places.',
        error,
        stackTrace,
      );
      return Result.error(error);
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
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while setting favourite for place with remote ID: $remoteId.',
        error,
        stackTrace,
      );

      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async {
    try {
      final query = _placeBox.query();
      final builder = query.build();
      final places = builder.findIds();
      places.shuffle();
      final result = places.sublist(0, 5);
      builder.close();
      return Result.success(result);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading suggested places.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }
}
