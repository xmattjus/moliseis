import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:objectbox/objectbox.dart';

part 'city.g.dart';

@immutable
@Entity()
@JsonSerializable()
class City {
  const City({
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
  final ToMany<Place> places;

  @Backlink('city')
  @EventRelToManyConverter()
  final ToMany<Event> events;

  @override
  bool operator ==(Object other) =>
      other is City &&
      other.remoteId == remoteId &&
      other.name == name &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.modifiedAt.isAtSameMomentAs(modifiedAt);

  @override
  int get hashCode => Object.hash(remoteId, name, createdAt, modifiedAt);

  City copyWith({String? name, DateTime? createdAt, DateTime? modifiedAt}) =>
      City(
        remoteId: remoteId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        places: places,
        events: events,
      );

  @override
  String toString() =>
      'City remoteId: $remoteId, name: $name, createdAt: $createdAt, '
      'modifiedAt: $modifiedAt, places (lenght): ${places.length}, '
      'events (lenght): ${events.length}';

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  Map<String, dynamic> toJson() => _$CityToJson(this);
}

class CityRelToOneConverter
    implements JsonConverter<ToOne<City>, Map<String, dynamic>?> {
  const CityRelToOneConverter();

  @override
  ToOne<City> fromJson(Map<String, dynamic>? json) =>
      ToOne<City>(target: json == null ? null : City.fromJson(json));

  @override
  Map<String, dynamic>? toJson(ToOne<City> rel) => rel.target?.toJson();
}
