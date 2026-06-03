import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:objectbox/objectbox.dart';

/// Conversion extensions from [PlaceDto] to [PlaceEntity].
extension PlaceDtoExtensions on PlaceDto {
  PlaceEntity toEntity() {
    final cityRelationId = switch (cityId) {
      Assign<int>(value: final id) => id,
      _ => null,
    };

    final entity = PlaceEntity(
      remoteId: id,
      name: name,
      description: description,
      coordinates: coordinates,
      category: category,
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

  PlaceEntity mergeInto(PlaceEntity existing) {
    final cityRelationId = switch (cityId) {
      Keep<int>() => existing.cityToOneId,
      Clear<int>() => null,
      Assign<int>(value: final id) => id,
    };

    final copy = existing
        .copyWith(
          name: name,
          description: description,
          coordinates: coordinates,
          category: category,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          isDeleted: deletedAt != null,
        )
        .updateRelationId(cityRelationId);

    copy.city.targetId = cityRelationId;

    return copy;
  }
}
