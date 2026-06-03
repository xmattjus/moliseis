import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/mappers/city_entity_mapper.dart';
import 'package:moliseis/data/mappers/media_entity_mapper.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/models/place.dart';

/// Conversion extensions from [PlaceEntity] to the [Place] domain model.
extension PlaceEntityExtensions on PlaceEntity {
  /// Maps a [PlaceEntity] to a [Place] domain model.
  Place toModel() => Place(
    category: category,
    city: city.target.toModel(),
    coordinates: LatLng(coordinates[0], coordinates[1]),
    createdAt: createdAt,
    description: description ?? '',
    media: media
        .where((entity) => !entity.isDeleted)
        .map<Media>((entity) => entity.toModel())
        .toList(growable: false),
    modifiedAt: modifiedAt,
    name: name,
    remoteId: remoteId,
    isSaved: isSaved,
  );
}
