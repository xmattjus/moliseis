import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:objectbox/objectbox.dart';

/// Conversion extensions from [CityDto] to [CityEntity].
extension CityDtoExtensions on CityDto {
  CityEntity toEntity() => CityEntity(
    remoteId: id,
    name: name,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    places: ToMany<PlaceEntity>(),
    events: ToMany<EventEntity>(),
  );

  CityEntity mergeInto(CityEntity existing) => existing.copyWith(
    name: name,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );
}
