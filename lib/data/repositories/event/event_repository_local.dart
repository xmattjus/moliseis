import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/domain/models/event/event_supabase_table.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventRepositoryLocal implements EventRepository {
  EventRepositoryLocal({
    required Supabase supabase,
    required EventSupabaseTable supabaseTable,
    required ObjectBox objectBox,
  }) : _supabase = supabase,
       _supabaseTable = supabaseTable,
       _eventBox = objectBox.store.box<Event>();

  final _log = Logger('EventRepositoryLocal');

  final Supabase _supabase;
  final EventSupabaseTable _supabaseTable;
  final Box<Event> _eventBox;

  @override
  Future<Result<List<Event>>> getAll() async {
    try {
      final events = await _eventBox.getAllAsync();

      return Result.success(events);
    } on Exception catch (error, stackTrace) {
      _log.severe('', error, stackTrace);

      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> synchronize() async {
    _log.info(LogEvents.repositoryUpdate);

    try {
      final attractions = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      // The set of events in the remote repository.
      final remote = Set<Event>.unmodifiable(
        attractions.map<Event>((element) => Event.fromJson(element)),
      );

      // The set of events in the local repository.
      var local = Set<Event>.unmodifiable(_eventBox.getAll());

      // Creates a set containing only new / different events that need to
      // be inserted / updated in the local repository.
      final eventsToPut = remote.difference(local);

      if (eventsToPut.isNotEmpty) {
        for (final event in eventsToPut) {
          final old = _eventBox.get(event.id);

          if (old == null) {
            _log.info('Inserting new event with id: ${event.id}');

            _eventBox.put(event);
          } else {
            if (old != event) {
              _log.info('updating event with id: ${event.id}');

              final updated = old.copyWith(
                title: event.title,
                description: event.description,
                startDate: event.startDate,
                endDate: event.endDate,
                modifiedAt: event.modifiedAt,
              );

              _eventBox.put(updated);
            }
          }
        }
      }

      //
      local = Set<Event>.unmodifiable(_eventBox.getAll());

      final danglingAttractions = local.difference(remote);

      final danglingIds = danglingAttractions.map((e) => e.id).toList();

      _eventBox.removeMany(danglingIds);

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe('', error, stackTrace);
      return Result.error(error);
    }
  }
}
