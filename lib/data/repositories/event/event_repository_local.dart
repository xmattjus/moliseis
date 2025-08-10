import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_sort.dart';
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/domain/models/event/event_supabase_table.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/messages.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventRepositoryLocal implements EventRepository {
  EventRepositoryLocal({
    required Supabase supabaseI,
    required EventSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _eventBox = objectBoxI.store.box<Event>();

  final Supabase _supabase;
  final EventSupabaseTable _supabaseTable;
  final Box<Event> _eventBox;

  final _log = Logger('EventRepositoryLocal');

  List<Event>? _cache;

  @override
  Future<Result<List<Event>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    try {
      final results = _cache ??= await _eventBox.getAllAsync();

      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while getting all events.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    Query<Event>? query;

    try {
      final condition = Event_.dbType.oneOf(
        categories.map((e) => e.index).toList(),
      );
      final builder = _eventBox.query(condition);
      query = builder.build();
      final results = await query.findAsync();

      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
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
    Query<Event>? query;

    try {
      query = _eventBox
          .query(Event_.coordinates.nearestNeighborsF32(coordinates, 200))
          .build();
      query.limit = 2;
      final resultsWithScores = await query.findWithScoresAsync();
      query.close();
      final results = resultsWithScores
          .map<Event>((element) => element.object)
          .where(
            (event) =>
                event.coordinates.first != coordinates.first ||
                event.coordinates.last != coordinates.last,
          )
          .toList();
      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while loading events by coordinates.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async {
    Query<Event>? query;
    try {
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = DateTime(date.year, date.month, date.day + 1);

      final builder = _eventBox
          .query(
            Event_.startDate
                .greaterOrEqualDate(startDate)
                .and(Event_.startDate.lessThanDate(endDate)),
          )
          .order(Event_.startDate, flags: Order.unsigned);
      query = builder.build();
      final results = query.find();

      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while getting events for date: $date.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<Event>> getById(int id) async {
    try {
      final result = _eventBox.get(id);

      if (result != null) {
        return Result.success(result);
      } else {
        return Result.error(Exception('Event is null'));
      }
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while getting event with remote ID: $id.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<List<int>>> getNextEventIds() async {
    Query<Event>? query;

    try {
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);

      final builder = _eventBox
          .query(Event_.startDate.greaterOrEqualDate(startOfToday))
          .order(Event_.startDate, flags: Order.unsigned);
      query = builder.build()..limit = 6;
      final results = query.findIds();
      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
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
    Query<Event>? query;

    try {
      query = _eventBox.query(Event_.isSaved.equals(true)).build();
      // Casts the query results to a growable list with toList().
      final events = query.findIds().toList();
      return Result.success(events);
    } on Exception catch (error, stackTrace) {
      _log.severe(
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
      _log.severe(
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

      final remote = Set<Event>.unmodifiable(
        events.map<Event>((element) => Event.fromJson(element)),
      );

      final local = Set<Event>.unmodifiable(_eventBox.getAll());

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
      _log.severe(Messages.repositoryUpdateException, error, stackTrace);
      return Result.error(error);
    }
  }
}
