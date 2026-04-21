import 'package:moliseis/data/core/object_box_conditions.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/event_supabase_table.dart';
import 'package:moliseis/data/mappers/event_entity_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/messages.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl({
    required Talker logger,
    required Supabase supabaseI,
    required EventSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _log = logger,
       _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _eventBox = objectBoxI.store.box<EventEntity>();

  final Talker _log;

  final Supabase _supabase;
  final EventSupabaseTable _supabaseTable;
  final Box<EventEntity> _eventBox;

  List<Event>? _cache;

  @override
  Future<Result<List<Event>>> getByCurrentYear() async {
    // Do not query the database again if the events are already cached.
    if (_cache != null) {
      return Result.success(List.unmodifiable(_cache!));
    }

    Query<EventEntity>? query;

    try {
      final builder = _eventBox
          .query(ObjectBoxConditions.eventStartsEndsCurrentYear)
          .order(EventEntity_.startDate, flags: Order.unsigned);
      query = builder.build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Event>((EventEntity entity) => entity.toModel())
          .toList();
      _cache = mappedResults;
      return Result.success(mappedResults);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting all events.',
        error,
        stackTrace,
      );

      return Result.error(error);
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
      final condition = EventEntity_.dbType
          .oneOf(categories.map((e) => e.index).toList())
          .and(ObjectBoxConditions.eventStartsEndsCurrentYear);
      query = _eventBox.query(condition).build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Event>((EventEntity entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting events by categories: $categories.',
        error,
        stackTrace,
      );
      return Result.error(error);
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
          .and(ObjectBoxConditions.eventStartsEndsCurrentYear);
      query = _eventBox.query(condition).build();
      query.limit = 2;
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
          .map<Event>((EventEntity entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while loading events by coordinates.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

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

    _log.info('Getting events for date range: $startDate to $endDate.');

    try {
      final Condition<EventEntity> multiDayCondition = EventEntity_.startDate
          .lessOrEqualDate(endDate)
          .and(EventEntity_.endDate.greaterOrEqualDate(startDate));

      final Condition<EventEntity> singleDayCondition = EventEntity_.endDate
          .isNull()
          .and(EventEntity_.startDate.betweenDate(startDate, endDate));

      final builder = _eventBox
          .query(multiDayCondition.or(singleDayCondition))
          .order(EventEntity_.startDate, flags: Order.unsigned);

      query = builder.build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Event>((EventEntity entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting events for date range: $startDate to $endDate.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  /// Loads events that overlap a specific calendar day.
  @override
  Future<Result<List<Event>>> getByDate(DateTime date) =>
      _getByDateRange(start: date);

  /// Loads events that overlap the inclusive [start]-[end] date range.
  @override
  Future<Result<List<Event>>> getByDateRange(DateTime start, DateTime end) =>
      _getByDateRange(start: start, end: end);

  @override
  Future<Result<Event>> getById(int id) async {
    _log.info('Getting event with remote ID: $id.');

    try {
      final result = _eventBox.get(id);

      if (result != null) {
        return Result.success(result.toModel());
      } else {
        return Result.error(Exception('Event is null'));
      }
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting event with remote ID: $id.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getNextEventIds() async {
    Query<EventEntity>? query;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextMonth = DateTime(now.year, now.month, now.day + 30).endOfDay;

      final builder = _eventBox
          .query(
            EventEntity_.startDate
                .greaterOrEqualDate(today)
                .and(EventEntity_.startDate.lessOrEqualDate(nextMonth)),
          )
          .order(EventEntity_.startDate, flags: Order.unsigned);
      query = builder.build()..limit = 6;
      final results = query.findIds();
      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting next events.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async {
    Query<EventEntity>? query;

    try {
      query = _eventBox.query(EventEntity_.isSaved.equals(true)).build();
      // Casts the query results to a growable list with toList().
      final events = query.findIds().toList();
      return Result.success(events);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting favourite events.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<void>> setFavouriteEvent(int remoteId, bool save) async {
    try {
      final event = await _eventBox.getAsync(remoteId);

      if (event == null) {
        throw Exception('Event with remote ID: $remoteId not found.');
      }

      final copy = event.copyWith(isSaved: save);

      _eventBox.put(copy);

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while setting favourite for event with remote ID: $remoteId.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> synchronize() async {
    _log.info(Messages.repositoryUpdate);

    // Resets the list of cached events before synchronizing.
    _cache = null;

    try {
      final events = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<EventEntity>.unmodifiable(
        events.map<EventEntity>((element) => EventEntity.fromJson(element)),
      );

      final local = Set<EventEntity>.unmodifiable(_eventBox.getAll());

      final eventsToPut = remote.difference(local);

      for (final event in eventsToPut) {
        final existingEvent = local.where(
          (test) => test.remoteId == event.remoteId,
        );

        if (existingEvent.isEmpty) {
          _log.info(Messages.objectInsert('event', event.remoteId));

          event.city.targetId = event.cityToOneId;

          _eventBox.put(event);
        } else if (existingEvent.length == 1) {
          if (existingEvent.first != event) {
            _log.info(
              Messages.objectUpdate('event', existingEvent.first.remoteId),
            );

            final copy = existingEvent.first.copyWith(
              name: event.name,
              description: event.description,
              startDate: event.startDate,
              endDate: event.endDate,
              coordinates: event.coordinates,
              category: event.category,
              cityToOneId: () => event.cityToOneId,
              createdAt: event.createdAt,
              modifiedAt: event.modifiedAt,
            );

            _eventBox.put(copy);
          }
        }
      }

      removeLeftovers(_eventBox, remote);

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.error(Messages.repositoryUpdateException, error, stackTrace);
      return Result.error(error);
    }
  }
}
