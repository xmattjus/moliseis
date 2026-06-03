import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/domain/models/city.dart';

/// Conversion extensions from [CityEntity] to the [City] domain model.
///
/// Declared on [CityEntity]? so callers can write `relation.target.toModel()`
/// without a prior null check.
extension CityEntityNullableExtensions on CityEntity? {
  /// Maps a [CityEntity] to a [City] domain model.
  City? toModel() => this != null
      ? City(
          remoteId: this!.remoteId,
          name: this!.name,
          createdAt: this!.createdAt,
          modifiedAt: this!.modifiedAt,
        )
      : null;
}
