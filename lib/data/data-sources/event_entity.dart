import 'package:json_annotation/json_annotation.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:objectbox/objectbox.dart';

part 'event_entity.g.dart';

@JsonSerializable()
@Entity()
class EventEntity {
  EventEntity({
    required this.remoteId,
    this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.coordinates = const [0, 0],
    this.category = ContentCategory.unknown,
    this.cityToOneId,
    required this.createdAt,
    required this.modifiedAt,
    required this.city,
    required this.media,
    this.isSaved = false,
  });

  factory EventEntity.fromJson(Map<String, dynamic> json) =>
      _$EventEntityFromJson(json);

  Map<String, dynamic> toJson() => _$EventEntityToJson(this);

  @JsonKey(name: 'id')
  @Id(assignable: true)
  final int remoteId;

  @Index()
  final String? name;

  final String? description;

  @JsonKey(name: 'start_date')
  @Property(type: PropertyType.dateNano)
  final DateTime? startDate;

  @JsonKey(name: 'end_date')
  @Property(type: PropertyType.dateNano)
  final DateTime? endDate;

  /// Latitude x Longitude
  @HnswIndex(dimensions: 2, distanceType: VectorDistanceType.geo)
  @Property(type: PropertyType.floatVector)
  final List<double> coordinates;

  @Transient()
  ContentCategory category;

  @JsonKey(name: 'city_id')
  final int? cityToOneId;

  @JsonKey(name: 'created_at')
  @Property(type: PropertyType.dateNano)
  final DateTime createdAt;

  @JsonKey(name: 'modified_at')
  @Property(type: PropertyType.dateNano)
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

  @Backlink('event')
  @MediaRelToManyConverter()
  final ToMany<MediaEntity> media;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isSaved;

  @override
  bool operator ==(Object other) =>
      other is EventEntity &&
      other.remoteId == remoteId &&
      other.name == name &&
      other.description == description &&
      // listEquals(other.coordinates, coordinates) &&
      other.category == category &&
      _bothNullOrSameMoment(startDate, other.startDate) &&
      _bothNullOrSameMoment(endDate, other.endDate) &&
      _bothNullOrSameMoment(createdAt, other.createdAt) &&
      _bothNullOrSameMoment(modifiedAt, other.modifiedAt) &&
      other.cityToOneId == cityToOneId &&
      other.isSaved == isSaved;

  @override
  int get hashCode => Object.hash(
    remoteId,
    name,
    description,
    // Object.hashAll(coordinates),
    category,
    startDate,
    endDate,
    cityToOneId,
    createdAt,
    modifiedAt,
    isSaved,
  );

  EventEntity copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
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

    final copy = EventEntity(
      remoteId: remoteId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      coordinates: coordinates ?? this.coordinates,
      category: category ?? this.category,
      cityToOneId: newCityToOneId,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      city: city,
      media: media,
      isSaved: isSaved ?? this.isSaved,
    );

    copy.city.targetId = newCityToOneId;

    return copy;
  }

  /// Whether both [dt] and [other] are null or occur at the same moment.
  bool _bothNullOrSameMoment(DateTime? dt, DateTime? other) {
    if (dt == null && other == null) return true;

    if (dt != null && other != null && dt.isAtSameMomentAs(other)) {
      return true;
    }

    return false;
  }
}

class EventRelToOneConverter
    implements JsonConverter<ToOne<EventEntity>, Map<String, dynamic>?> {
  const EventRelToOneConverter();

  @override
  ToOne<EventEntity> fromJson(Map<String, dynamic>? json) => ToOne<EventEntity>(
    target: json == null ? null : EventEntity.fromJson(json),
  );

  @override
  Map<String, dynamic>? toJson(ToOne<EventEntity> rel) => rel.target?.toJson();
}

class EventRelToManyConverter
    implements JsonConverter<ToMany<EventEntity>, List<Map<String, dynamic>>?> {
  const EventRelToManyConverter();

  @override
  ToMany<EventEntity> fromJson(List<Map<String, dynamic>>? json) =>
      ToMany<EventEntity>(
        items: json?.map<EventEntity>(EventEntity.fromJson).toList(),
      );

  @override
  List<Map<String, dynamic>>? toJson(ToMany<EventEntity> rel) =>
      rel.map((obj) => obj.toJson()).toList();
}
