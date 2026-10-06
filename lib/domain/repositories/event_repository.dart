import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/domain/core/event_time.dart';
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
  /// Returns all non-deleted events that overlap the current Europe/Rome
  /// calendar year.
  Future<Result<List<Event>>> getByCurrentYear();

  /// Returns all events that overlap the provided Rome calendar [date].
  Future<Result<List<Event>>> getByDate(EventCalendarDate date);

  /// Returns all events that overlap the inclusive date range.
  ///
  /// Events with a null end date should be treated as single-day events.
  Future<Result<List<Event>>> getByDateRange(
    EventCalendarDate start,
    EventCalendarDate end,
  );

  /// Returns all events belonging to any of the given [categories].
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  });

  /// Returns all events near the given [coordinates].
  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates);

  /// Returns the event with the given [id].
  Future<Result<Event>> getById(int id);

  /// Returns all non-deleted events active at the supplied [snapshotUtc].
  ///
  /// Ranged bounds are inclusive. Null-end events remain within their Rome
  /// civil start day and must already have started. Results are ordered by
  /// start, then identity, without a cap or an all-day classification branch.
  Future<Result<List<Event>>> getOngoingEvents(DateTime snapshotUtc);

  /// Returns up to six non-deleted events starting after [snapshotUtc].
  ///
  /// Starts are ordered ascending and bounded by the inclusive final
  /// microsecond of the Rome civil day thirty days after the snapshot's day.
  /// Home supplies the same snapshot to this and [getOngoingEvents]; neither
  /// discovery operation samples a separate clock.
  Future<Result<List<Event>>> getNextEvents(DateTime snapshotUtc);

  /// Returns the IDs of all events marked as favourites.
  Future<Result<List<int>>> getFavouriteEventIds();

  /// Marks or unmarks the event identified by [id] as a favourite.
  ///
  /// Pass [save] as `true` to add the event to favourites, or `false` to
  /// remove it.
  Future<Result<void>> setFavouriteEvent(int id, bool save);
}
