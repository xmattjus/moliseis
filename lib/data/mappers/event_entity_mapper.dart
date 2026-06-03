import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/mappers/city_entity_mapper.dart';
import 'package:moliseis/data/mappers/media_entity_mapper.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/media.dart';

/// Conversion extensions from [EventEntity] to the [Event] domain model.
extension EventEntityExtensions on EventEntity {
  /// Maps an [EventEntity] to an [Event] domain model.
  Event toModel() => Event(
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
    name: name ?? 'Evento Senza Nome',
    remoteId: remoteId,
    // A null startDate is a data integrity error; use epoch as a sentinel so
    // the record is visibly wrong in the UI rather than silently showing today.
    startDate: startDate ?? DateTime(0),
    endDate: endDate,
    isSaved: isSaved,
  );
}
