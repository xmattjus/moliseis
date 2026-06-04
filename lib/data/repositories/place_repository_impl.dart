import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/data-sources/place_supabase_table.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceRepositoryImpl extends BaseSyncRepository<PlaceDto, PlaceEntity>
    implements PlaceRepository {
  PlaceRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required PlaceSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _table = supabaseTable,
       _box = objectBoxI.store.box<PlaceEntity>(),
       super(logger);

  final Supabase _supabase;
  final PlaceSupabaseTable _table;
  final Box<PlaceEntity> _box;

  @override
  String get entityName => 'place';

  @override
  Future<List<PlaceDto>> fetchRemote() async {
    final response = await _supabase.client.from(_table.tableName).select();

    return response.map<PlaceDto>(PlaceDtoMapper.fromMap).toList();
  }

  @override
  PlaceEntity? getLocalById(int id) => _box.get(id);

  @override
  void put(PlaceEntity entity) => _box.put(entity);

  @override
  void putMany(List<PlaceEntity> entities) => _box.putMany(entities);

  @override
  PlaceEntity createEntity(PlaceDto dto) => dto.toEntity();

  @override
  PlaceEntity mergeEntity(PlaceDto dto, PlaceEntity existing) =>
      dto.mergeInto(existing);

  @override
  PlaceEntity markEntityDeleted(PlaceEntity existing) {
    return existing.copyWith(
      isDeleted: true,
    );
  }

  Condition<PlaceEntity> get _isNotDeleted =>
      PlaceEntity_.isDeleted.equals(false);

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    Query<PlaceEntity>? query;

    try {
      final builder = _box.query(_isNotDeleted);

      query = builder.build();

      final entities = await query.findAsync();

      final models = entities.map<Place>((entity) => entity.toModel());

      final mappedResults = List<Place>.of(models)
        ..sort(
          (a, b) => switch (sort) {
            ContentSort.byName => a.name.compareTo(b.name),
            ContentSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
          },
        );

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('place', method: 'getAll'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    Query<PlaceEntity>? query;

    try {
      final condition = PlaceEntity_.dbType
          .oneOf(categories.map((e) => e.index).toList())
          .and(_isNotDeleted);

      final builder = _box.query(condition);

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
      logger.log(
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
      final condition = PlaceEntity_.coordinates
          .nearestNeighborsF32(coordinates, 300)
          .and(_isNotDeleted);

      query = _box.query(condition).build();

      // Code readability benefits from separate statements over cascades.
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
      logger.log(
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
    Query<PlaceEntity>? query;

    logger.log(
      const EntityLoadStarted('place', method: 'getById'),
      extra: {'id': id},
    );

    try {
      final condition = PlaceEntity_.remoteId.equals(id).and(_isNotDeleted);

      final builder = _box.query(condition);

      query = builder.build();

      final result = await query.findUniqueAsync();

      if (result != null) {
        return Result.success(result.toModel());
      } else {
        return Result.error(Exception('Place with id: $id not found'));
      }
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('place', method: 'getById'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async {
    Query<PlaceEntity>? query;

    try {
      final condition = PlaceEntity_.coordinates
          .nearestNeighborsF32(coordinates, 3)
          .and(_isNotDeleted);

      query = _box.query(condition).build();

      final resultsWithScores = await query.findIdsWithScoresAsync();

      return Result.success(
        resultsWithScores.map<int>((element) => element.id).toList(),
      );
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('place', method: 'getIdsByCoordinates'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async {
    try {
      final query = _box
          .query(_isNotDeleted)
          .order(PlaceEntity_.createdAt, flags: Order.descending);

      final builder = query.build()..limit = 6;

      final places = await builder.findIdsAsync();

      builder.close();

      return Result.success(places);
    } on Exception catch (exception, stackTrace) {
      logger.log(
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
      final condition = PlaceEntity_.isSaved.equals(true).and(_isNotDeleted);

      query = _box.query(condition).build();

      final places = query.findIds().toList();

      return Result.success(places);
    } on Exception catch (exception, stackTrace) {
      logger.log(
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
      final condition = PlaceEntity_.remoteId
          .equals(remoteId)
          .and(_isNotDeleted);

      final builder = _box.query(condition);

      final query = builder.build();

      final result = await query.findUniqueAsync();

      query.close();

      if (result == null) {
        throw Exception('Place with remote ID: $remoteId not found.');
      }

      final copy = result.copyWith(isSaved: save);

      _box.put(copy);

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      logger.log(
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
      final query = _box.query(_isNotDeleted);

      final builder = query.build();

      final places = builder.findIds()..shuffle();

      final result = places.take(5).toList();

      builder.close();

      return Result.success(result);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('place', method: 'getSuggestedPlaceIds'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }
}
