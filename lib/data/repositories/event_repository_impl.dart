import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/data/core/object_box_conditions.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/event_supabase_table.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventRepositoryImpl extends BaseSyncRepository<EventDto, EventEntity>
    implements EventRepository {
  EventRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required EventSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _table = supabaseTable,
       _box = objectBoxI.store.box<EventEntity>(),
       super(logger);

  final Supabase _supabase;
  final EventSupabaseTable _table;
  final Box<EventEntity> _box;

  @override
  String get entityName => 'event';

  @override
  Future<List<EventDto>> fetchRemote() async {
    final response = await _supabase.client.from(_table.tableName).select();

    return response.map<EventDto>(EventDtoMapper.fromMap).toList();
  }

  @override
  EventEntity? getLocalById(int id) => _box.get(id);

  @override
  void put(EventEntity entity) => _box.put(entity);

  @override
  void putMany(List<EventEntity> entities) => _box.putMany(entities);

  @override
  EventEntity createEntity(EventDto dto) => dto.toEntity();

  @override
  EventEntity mergeEntity(EventDto dto, EventEntity existing) =>
      dto.mergeInto(existing);

  @override
  EventEntity markEntityDeleted(EventEntity existing) {
    return existing.copyWith(
      isDeleted: true,
    );
  }

  Condition<EventEntity> get _isNotDeleted =>
      EventEntity_.isDeleted.equals(false);

  @override
  Future<Result<List<Event>>> getByCurrentYear() async {
    Query<EventEntity>? query;

    try {
      final condition = ObjectBoxConditions.eventStartsEndsCurrentYear.and(
        _isNotDeleted,
      );

      final builder = _box
          .query(condition)
          .order(EventEntity_.startDate, flags: Order.unsigned);

      query = builder.build();

      final results = await query.findAsync();

      final mappedResults = results
          .map<Event>((entity) => entity.toModel())
          .toList();

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getByCurrentYear'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    Query<EventEntity>? query;

    try {
      final condition = EventEntity_.contentCategoryIndex
          .oneOf(categories.map((e) => e.index).toList())
          .andAll([
            ObjectBoxConditions.eventStartsEndsCurrentYear,
            _isNotDeleted,
          ]);

      query = _box.query(condition).build();

      final results = await query.findAsync();

      final mappedResults = results
          .map<Event>((entity) => entity.toModel())
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
        const EntityLoadFailed('event', method: 'getByCategories'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates) async {
    Query<EventEntity>? query;

    try {
      final condition = EventEntity_.coordinates
          .nearestNeighborsF32(coordinates, 200)
          .andAll([
            ObjectBoxConditions.eventStartsEndsCurrentYear,
            _isNotDeleted,
          ]);

      query = _box.query(condition).build()..limit = 2;

      final resultsWithScores = await query.findWithScoresAsync();
      final results = resultsWithScores
          .map<EventEntity>((element) => element.object)
          .where(
            (event) =>
                event.coordinates.first != coordinates.first ||
                event.coordinates.last != coordinates.last,
          )
          .toList();

      final mappedResults = results
          .map<Event>((entity) => entity.toModel())
          .toList();

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getByCoordinates'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  // TODO(xmattjus): remove the try / catch block here since callers also wrap this function in a try / catch block.
  Future<Result<List<Event>>> _getByDateRange({
    required DateTime start,
    DateTime? end,
  }) async {
    Query<EventEntity>? query;

    // Normalizes the start and end dates to include the entire day.
    final startDate = start.startOfDay;
    final endDate = end != null
        ? DateTime(end.year, end.month, end.day).endOfDay
        : DateTime(start.year, start.month, start.day).endOfDay;

    try {
      // TODO(xmattjus): small modifications to ObjectBoxConditions.eventStartsEndCurrentYear could unlock usage in situations like below.
      final multiDayCondition = EventEntity_.startDate
          .lessOrEqualDate(endDate)
          .andAll([
            EventEntity_.endDate.greaterOrEqualDate(startDate),
            _isNotDeleted,
          ]);

      final singleDayCondition = EventEntity_.endDate.isNull().andAll([
        EventEntity_.startDate.betweenDate(startDate, endDate),
        _isNotDeleted,
      ]);

      final builder = _box
          .query(multiDayCondition.or(singleDayCondition))
          .order(EventEntity_.startDate, flags: Order.unsigned);

      query = builder.build();

      final results = await query.findAsync();

      final mappedResults = results
          .map<Event>((entity) => entity.toModel())
          .toList();

      return Result.success(mappedResults);
    } on Exception catch (_) {
      // Allow Result pattern violation here because the callers also wrap
      // this function in a try / catch block.
      // See getByDate, getByDateRange.
      rethrow;
    } finally {
      query?.close();
    }
  }

  /// Loads events that overlap a specific calendar day.
  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async {
    try {
      logger.log(
        EntityLoadStarted(
          'event',
          method: 'getByDate',
          extra: {
            'startDate': date.toIso8601String(),
          },
        ),
      );

      return await _getByDateRange(start: date);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getByDate'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  /// Loads events that overlap the inclusive [start]-[end] date range.
  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      logger.log(
        EntityLoadStarted(
          'event',
          method: 'getByDateRange',
          extra: {
            'startDate': start.toIso8601String(),
            'endDate': end.toIso8601String(),
          },
        ),
      );

      return await _getByDateRange(start: start, end: end);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getByDateRange'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  @override
  Future<Result<Event>> getById(int id) async {
    Query<EventEntity>? query;

    logger.log(
      const EntityLoadStarted('event', method: 'getById'),
      extra: {'id': id},
    );

    try {
      final condition = EventEntity_.remoteId.equals(id).and(_isNotDeleted);

      final builder = _box
          .query(condition)
          .order(EventEntity_.startDate, flags: Order.unsigned);

      query = builder.build();

      final result = await query.findUniqueAsync();

      if (result != null) {
        return Result.success(result.toModel());
      } else {
        return Result.error(Exception('Event with id: $id not found'));
      }
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getById'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<int>>> getNextEventIds() async {
    Query<EventEntity>? query;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextMonth = DateTime(now.year, now.month, now.day + 30).endOfDay;

    try {
      final condition = EventEntity_.startDate.greaterOrEqualDate(today).andAll(
        [
          EventEntity_.startDate.lessOrEqualDate(nextMonth),
          _isNotDeleted,
        ],
      );

      final builder = _box
          .query(condition)
          .order(EventEntity_.startDate, flags: Order.unsigned);

      query = builder.build()..limit = 6;

      final results = query.findIds();

      return Result.success(results);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getNextEventIds'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async {
    Query<EventEntity>? query;

    try {
      final condition = EventEntity_.isSaved.equals(true).and(_isNotDeleted);

      query = _box.query(condition).build();

      final events = query.findIds().toList();

      return Result.success(events);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('event', method: 'getFavouriteEventIds'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<void>> setFavouriteEvent(int remoteId, bool save) async {
    try {
      final condition = EventEntity_.remoteId
          .equals(remoteId)
          .and(_isNotDeleted);

      final builder = _box.query(condition);

      final query = builder.build();

      final result = await query.findUniqueAsync();

      query.close();

      if (result == null) {
        throw Exception('Event with remote ID: $remoteId not found.');
      }

      final copy = result.copyWith(isSaved: save);

      _box.put(copy);

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        EntityUpdateFailed('event', remoteId, method: 'setFavouriteEvent'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }
}
