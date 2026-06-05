import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

/// Domain interface for place data access.
///
/// [Synchronizable] is parameterized with [PlaceDto] from the data layer so
/// the concrete DTO type flows through `prepareSync`/`commitSync` at
/// compile time. The `data/dtos` import is a deliberate outward
/// dependency: the `SyncDto` base contract is in the domain, but the
/// concrete subtypes stay in the data layer to keep serialization and
/// ObjectBox annotations out of domain code.
abstract class PlaceRepository with Synchronizable<PlaceDto> {
  /// Returns all places.
  Future<Result<List<Place>>> getAll({ContentSort sort = ContentSort.byName});

  /// Returns all places belonging to any of the given [categories].
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  });

  /// Returns all places near the given [coordinates].
  Future<Result<List<Place>>> getByCoordinates(List<double> coordinates);

  /// Returns the place with the given [id].
  Future<Result<Place>> getById(int id);

  /// Returns the IDs of all places marked as favourites.
  Future<Result<List<int>>> getFavouritePlaceIds();

  /// Returns the IDs of places near the given [coordinates].
  Future<Result<List<int>>> getIdsByCoordinates(List<double> coordinates);

  /// Returns the IDs of the most recently added places.
  Future<Result<List<int>>> getLatestPlaceIds();

  /// Returns the IDs of places suggested for the user.
  Future<Result<List<int>>> getSuggestedPlaceIds();

  /// Marks or unmarks the place identified by [id] as a favourite.
  ///
  /// Pass [save] as `true` to add the place to favourites, or `false` to
  /// remove it.
  Future<Result<void>> setFavouritePlace(int id, bool save);
}
