import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:objectbox/objectbox.dart';

/// Conversion extensions from [EventDto] to [EventEntity].
extension EventDtoExtensions on EventDto {
  EventEntity toEntity() {
    final cityRelationId = switch (cityId) {
      Assign<int>(value: final id) => id,
      _ => null,
    };

    final entity = EventEntity(
      remoteId: id,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      contentCategoryIndex: category.index,
      coordinates: [latitude, longitude],
      cityToOneId: cityRelationId,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      city: ToOne<CityEntity>(),
      media: ToMany<MediaEntity>(),
      isDeleted: deletedAt != null,
    );

    entity.city.targetId = cityRelationId;

    return entity;
  }

  EventEntity mergeInto(EventEntity existing) {
    final cityRelationId = switch (cityId) {
      Keep<int>() => existing.cityToOneId,
      Clear<int>() => null,
      Assign<int>(value: final id) => id,
    };

    final copy = existing
        .copyWith(
          name: name,
          description: description,
          startDate: startDate,
          endDate: endDate,
          coordinates: [latitude, longitude],
          contentCategoryIndex: category.index,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          isDeleted: deletedAt != null,
        )
        .updateRelationId(cityRelationId);

    copy.city.targetId = cityRelationId;

    return copy;
  }
}
