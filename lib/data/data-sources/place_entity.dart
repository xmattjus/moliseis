import 'package:json_annotation/json_annotation.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:objectbox/objectbox.dart';

part 'place_entity.g.dart';

@Entity()
@JsonSerializable()
class PlaceEntity {
  PlaceEntity({
    required this.remoteId,
    required this.name,
    this.description,
    this.coordinates = const [0, 0],
    this.category = ContentCategory.unknown,
    this.cityToOneId,
    required this.createdAt,
    required this.modifiedAt,
    required this.city,
    required this.media,
    this.isSaved = false,
  });

  factory PlaceEntity.fromJson(Map<String, dynamic> json) =>
      _$PlaceEntityFromJson(json);

  Map<String, dynamic> toJson() => _$PlaceEntityToJson(this);

  @JsonKey(name: 'id')
  @Id(assignable: true)
  final int remoteId;

  @Index()
  final String name;

  final String? description;

  /// Latitude x Longitude
  @HnswIndex(dimensions: 2, distanceType: VectorDistanceType.geo)
  @Property(type: PropertyType.floatVector)
  final List<double> coordinates;

  @Transient()
  ContentCategory category;

  @JsonKey(name: 'city_id')
  final int? cityToOneId;

  @Property(type: PropertyType.dateNano)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @Property(type: PropertyType.dateNano)
  @JsonKey(name: 'modified_at')
  final DateTime modifiedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  int? get dbType {
    assertStableContentCategoryEnumValues();
    return category.index;
  }

  set dbType(int? value) {
    assertStableContentCategoryEnumValues();
    if (value == null) {
      category = ContentCategory.unknown;
    } else {
      category = value >= 0 && value < ContentCategory.values.length
          ? ContentCategory.values[value]
          : ContentCategory.unknown;
    }
  }

  @CityRelToOneConverter()
  final ToOne<CityEntity> city;

  @Backlink('place')
  @MediaRelToManyConverter()
  final ToMany<MediaEntity> media;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isSaved;

  @override
  bool operator ==(Object other) =>
      other is PlaceEntity &&
      other.remoteId == remoteId &&
      other.name == name &&
      other.description == description &&
      // listEquals(other.coordinates, coordinates) &&
      other.category == category &&
      other.cityToOneId == cityToOneId &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.modifiedAt.isAtSameMomentAs(modifiedAt) &&
      other.isSaved == isSaved;

  @override
  int get hashCode => Object.hash(
    remoteId,
    name,
    description,
    // Object.hashAll(coordinates),
    category,
    cityToOneId,
    createdAt,
    modifiedAt,
    isSaved,
  );

  PlaceEntity copyWith({
    String? name,
    String? description,
    List<double>? coordinates,
    ContentCategory? category,
    int? Function()? cityToOneId,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isSaved,
  }) {
    // https://stackoverflow.com/a/71591609
    final newCityToOneId = cityToOneId != null
        ? cityToOneId()
        : this.cityToOneId;

    final copy = PlaceEntity(
      remoteId: remoteId,
      name: name ?? this.name,
      description: description ?? this.description,
      coordinates: coordinates ?? this.coordinates,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      cityToOneId: newCityToOneId,
      city: city,
      media: media,
      isSaved: isSaved ?? this.isSaved,
    );

    copy.city.targetId = newCityToOneId;

    return copy;
  }
}

class PlaceRelToOneConverter
    implements JsonConverter<ToOne<PlaceEntity>, Map<String, dynamic>?> {
  const PlaceRelToOneConverter();

  @override
  ToOne<PlaceEntity> fromJson(Map<String, dynamic>? json) => ToOne<PlaceEntity>(
    target: json == null ? null : PlaceEntity.fromJson(json),
  );

  @override
  Map<String, dynamic>? toJson(ToOne<PlaceEntity> rel) => rel.target?.toJson();
}

class PlaceRelToManyConverter
    implements JsonConverter<ToMany<PlaceEntity>, List<Map<String, dynamic>>?> {
  const PlaceRelToManyConverter();

  @override
  ToMany<PlaceEntity> fromJson(List<Map<String, dynamic>>? json) =>
      ToMany<PlaceEntity>(
        items: json?.map<PlaceEntity>(PlaceEntity.fromJson).toList(),
      );

  @override
  List<Map<String, dynamic>>? toJson(ToMany<PlaceEntity> rel) =>
      rel.map((obj) => obj.toJson()).toList();
}
