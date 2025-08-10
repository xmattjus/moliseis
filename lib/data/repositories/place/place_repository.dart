import 'package:moliseis/data/repositories/core/repository_base.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_sort.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/utils/result.dart';

abstract class PlaceRepository extends RepositoryBase {
  Future<Result<List<Place>>> getAll({ContentSort sort = ContentSort.byName});

  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  });

  Future<Result<List<Place>>> getByCoordinates(List<double> coordinates);

  Future<Result<Place>> getById(int id);

  Future<Result<List<int>>> getFavouritePlaceIds();

  Future<Result<List<int>>> getIdsByCoordinates(List<double> coordinates);

  Future<Result<List<int>>> getLatestPlaceIds();

  Future<Result<List<int>>> getSuggestedPlaceIds();

  Future<Result<void>> setFavouritePlace(int id, bool save);

  @override
  Future<Result<void>> synchronize();
}
