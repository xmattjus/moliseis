import 'package:moliseis/data/repositories/core/repository_base.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_sort.dart';
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/utils/result.dart';

abstract class EventRepository extends RepositoryBase {
  Future<Result<List<Event>>> getByCurrentYear();

  Future<Result<List<Event>>> getByDate(DateTime date);

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
