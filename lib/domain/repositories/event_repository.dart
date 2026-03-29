import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/repositories/repository_base.dart';
import 'package:moliseis/utils/result.dart';

abstract class EventRepository extends RepositoryBase {
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

  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  });

  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates);

  Future<Result<Event>> getById(int id);

  Future<Result<List<int>>> getNextEventIds();

  Future<Result<List<int>>> getFavouriteEventIds();

  Future<Result<void>> setFavouriteEvent(int id, bool save);

  @override
  Future<Result<void>> synchronize();
}
