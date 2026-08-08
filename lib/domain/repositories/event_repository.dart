import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

/// Domain interface for event data access.
///
/// [Synchronizable] is parameterized with [EventDto] from the data layer so
/// the concrete DTO type flows through `prepareSync`/`commitSync` at
/// compile time. The `data/dtos` import is a deliberate outward
/// dependency: the `SyncDto` base contract is in the domain, but the
/// concrete subtypes stay in the data layer to keep serialization and
/// ObjectBox annotations out of domain code.
abstract class EventRepository with Synchronizable<EventDto> {
  /// Returns all events occurring in the current calendar year.
  Future<Result<List<Event>>> getByCurrentYear();

  /// Returns all events that overlap the provided [date].
  ///
  /// Implementations should normalize [date] to the full day interval,
  /// from 00:00:00 to 23:59:59.999999.
  Future<Result<List<Event>>> getByDate(DateTime date);

  /// Returns all events that overlap the inclusive date range.
  ///
  /// Implementations should normalize [start] to 00:00:00 and [end] to
  /// 23:59:59.999999 before filtering.
  ///
  /// Events with a null end date should be treated as single-day events.
  Future<Result<List<Event>>> getByDateRange(DateTime start, DateTime end);

  /// Returns all events belonging to any of the given [categories].
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  });

  /// Returns all events near the given [coordinates].
  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates);

  /// Returns the event with the given [id].
  Future<Result<Event>> getById(int id);

  /// Returns the IDs of the upcoming events.
  Future<Result<List<int>>> getNextEventIds();

  /// Returns the IDs of all events marked as favourites.
  Future<Result<List<int>>> getFavouriteEventIds();

  /// Marks or unmarks the event identified by [id] as a favourite.
  ///
  /// Pass [save] as `true` to add the event to favourites, or `false` to
  /// remove it.
  Future<Result<void>> setFavouriteEvent(int id, bool save);
}
