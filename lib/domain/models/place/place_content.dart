import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/place/place.dart';

@immutable
class PlaceContent extends ContentBase {
  const PlaceContent({
    required super.category,
    required super.city,
    required super.coordinates,
    required super.createdAt,
    required super.description,
    required super.media,
    required super.modifiedAt,
    required super.name,
    required super.remoteId,
    required super.isSaved,
  });

  factory PlaceContent.fromPlace(Place place) => PlaceContent(
    category: place.category,
    city: place.city,
    coordinates: place.coordinates,
    createdAt: place.createdAt,
    description: place.description ?? '',
    media: place.media,
    modifiedAt: place.modifiedAt,
    name: place.name,
    remoteId: place.remoteId,
    isSaved: place.isSaved,
  );
}
