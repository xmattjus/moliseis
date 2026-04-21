import 'package:json_annotation/json_annotation.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:objectbox/objectbox.dart';

part 'city_entity.g.dart';

@Entity()
@JsonSerializable()
class CityEntity {
  const CityEntity({
    required this.remoteId,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.places,
    required this.events,
  });

  @JsonKey(name: 'id')
  @Id(assignable: true)
  final int remoteId;

  final String name;

  @Property(type: PropertyType.dateNano)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @Property(type: PropertyType.dateNano)
  @JsonKey(name: 'modified_at')
  final DateTime modifiedAt;

  @Backlink('city')
  @PlaceRelToManyConverter()
  final ToMany<PlaceEntity> places;

  @Backlink('city')
  @EventRelToManyConverter()
  final ToMany<EventEntity> events;

  @override
  bool operator ==(Object other) =>
      other is CityEntity &&
      other.remoteId == remoteId &&
      other.name == name &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.modifiedAt.isAtSameMomentAs(modifiedAt);

  @override
  int get hashCode => Object.hash(remoteId, name, createdAt, modifiedAt);

  CityEntity copyWith({
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) => CityEntity(
    remoteId: remoteId,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    places: places,
    events: events,
  );

  factory CityEntity.fromJson(Map<String, dynamic> json) =>
      _$CityEntityFromJson(json);

  Map<String, dynamic> toJson() => _$CityEntityToJson(this);
}

class CityRelToOneConverter
    implements JsonConverter<ToOne<CityEntity>, Map<String, dynamic>?> {
  const CityRelToOneConverter();

  @override
  ToOne<CityEntity> fromJson(Map<String, dynamic>? json) => ToOne<CityEntity>(
    target: json == null ? null : CityEntity.fromJson(json),
  );

  @override
  Map<String, dynamic>? toJson(ToOne<CityEntity> rel) => rel.target?.toJson();
}
