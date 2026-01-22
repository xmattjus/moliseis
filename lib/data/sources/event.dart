import 'package:json_annotation/json_annotation.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:objectbox/objectbox.dart';

part 'event.g.dart';

@JsonSerializable()
@Entity()
class Event {
  Event({
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
    ensureStableEnumValues();
    return category.index;
  }

  set dbType(int? value) {
    ensureStableEnumValues();
    if (value == null) {
      category = ContentCategory.unknown;
    } else {
      category = value >= 0 && value < ContentCategory.values.length
          ? ContentCategory.values[value]
          : ContentCategory.unknown;
    }
  }

  @CityRelToOneConverter()
  final ToOne<City> city;

  @Backlink('event')
  @MediaRelToManyConverter()
  final ToMany<Media> media;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isSaved;

  @override
  bool operator ==(Object other) =>
      other is Event &&
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

  Event copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<double>? coordinates,
    ContentCategory? category,
    int? Function()? cityToOneId,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isSaved = false,
  }) {
    // https://stackoverflow.com/a/71591609
    final newCityToOneId = cityToOneId != null
        ? cityToOneId()
        : this.cityToOneId;

    final copy = Event(
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

  @override
  String toString() =>
      'remoteId: $remoteId, name: $name, description: $description, '
      'startDate: $startDate, endDate: $endDate, coordinates: $coordinates, '
      'category: $category, cityToOneId: $cityToOneId, createdAt: $createdAt, '
      'modifiedAt: $modifiedAt, city: ${city.target?.remoteId}, '
      'media: TBD, isSaved: $isSaved';

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

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
    implements JsonConverter<ToOne<Event>, Map<String, dynamic>?> {
  const EventRelToOneConverter();

  @override
  ToOne<Event> fromJson(Map<String, dynamic>? json) =>
      ToOne<Event>(target: json == null ? null : Event.fromJson(json));

  @override
  Map<String, dynamic>? toJson(ToOne<Event> rel) => rel.target?.toJson();
}

class EventRelToManyConverter
    implements JsonConverter<ToMany<Event>, List<Map<String, dynamic>>?> {
  const EventRelToManyConverter();

  @override
  ToMany<Event> fromJson(List<Map<String, dynamic>>? json) =>
      ToMany<Event>(items: json?.map<Event>((e) => Event.fromJson(e)).toList());

  @override
  List<Map<String, dynamic>>? toJson(ToMany<Event> rel) =>
      rel.map((Event obj) => obj.toJson()).toList();
}
