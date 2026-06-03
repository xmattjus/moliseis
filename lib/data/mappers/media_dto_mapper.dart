import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:objectbox/objectbox.dart';

/// Conversion extensions from [MediaDto] to [MediaEntity].
extension MediaDtoExtensions on MediaDto {
  MediaEntity toEntity() {
    final eventRelationId = switch (eventId) {
      Assign<int>(value: final id) => id,
      _ => null,
    };

    final placeRelationId = switch (placeId) {
      Assign<int>(value: final id) => id,
      _ => null,
    };

    final entity = MediaEntity(
      remoteId: id,
      title: title,
      author: author,
      license: license,
      licenseUrl: licenseUrl,
      url: url,
      width: width,
      height: height,
      eventToOneId: eventRelationId,
      placeToOneId: placeRelationId,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      place: ToOne<PlaceEntity>(),
      event: ToOne<EventEntity>(),
      isDeleted: deletedAt != null,
    );

    entity.event.targetId = eventRelationId;
    entity.place.targetId = placeRelationId;

    return entity;
  }

  MediaEntity mergeInto(MediaEntity existing) {
    final eventRelationId = switch (eventId) {
      Keep<int>() => existing.eventToOneId,
      Clear<int>() => null,
      Assign<int>(value: final id) => id,
    };

    final placeRelationId = switch (placeId) {
      Keep<int>() => existing.placeToOneId,
      Clear<int>() => null,
      Assign<int>(value: final id) => id,
    };

    if ((eventRelationId != null && placeRelationId == null) ||
        (eventRelationId == null && placeRelationId != null)) {
      throw Exception('Only one between eventId and placeId must be set.');
    }

    final copy = existing
        .copyWith(
          title: title,
          author: author,
          license: license,
          licenseUrl: licenseUrl,
          url: url,
          width: width,
          height: height,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          isDeleted: deletedAt != null,
        )
        .updateRelationIds(eventRelationId, placeRelationId);

    copy.event.targetId = eventRelationId;
    copy.place.targetId = placeRelationId;

    return copy;
  }
}
