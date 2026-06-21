import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class EventEntity implements SyncEntity {
  EventEntity({
    required this.remoteId,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.coordinates = const [0, 0],
    required this.contentCategoryIndex,
    this.cityToOneId,
    required this.createdAt,
    required this.modifiedAt,
    required this.city,
    required this.media,
    this.isSaved = false,
    this.isDeleted = false,
  }) {
    assertValidContentCategoryIndex(contentCategoryIndex);
  }

  @override
  @Id(assignable: true)
  final int remoteId;

  @Index()
  final String name;

  final String? description;

  @Property(type: PropertyType.dateNano)
  final DateTime? startDate;

  @Property(type: PropertyType.dateNano)
  final DateTime? endDate;

  /// Latitude x Longitude
  @HnswIndex(dimensions: 2, distanceType: VectorDistanceType.geo)
  @Property(type: PropertyType.floatVector)
  final List<double> coordinates;

  /// Index into [ContentCategory.values]. Must satisfy
  /// `0 <= contentCategoryIndex < ContentCategory.values.length`.
  final int contentCategoryIndex;

  final int? cityToOneId;

  @Property(type: PropertyType.dateNano)
  final DateTime createdAt;

  @override
  @Property(type: PropertyType.dateNano)
  final DateTime modifiedAt;

  @override
  final bool isDeleted;

  final ToOne<CityEntity> city;

  @Backlink('event')
  final ToMany<MediaEntity> media;

  final bool isSaved;

  EventEntity copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<double>? coordinates,
    int? contentCategoryIndex,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isDeleted,
    bool? isSaved,
  }) => EventEntity(
    remoteId: remoteId,
    name: name ?? this.name,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    coordinates: coordinates ?? this.coordinates,
    contentCategoryIndex: contentCategoryIndex ?? this.contentCategoryIndex,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    city: city,
    media: media,
    isSaved: isSaved ?? this.isSaved,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  /// Creates a copy of this [EventEntity] with [cityToOneId] set to [cityId].
  EventEntity updateRelationId(int? cityId) => EventEntity(
    remoteId: remoteId,
    name: name,
    description: description,
    startDate: startDate,
    endDate: endDate,
    coordinates: coordinates,
    contentCategoryIndex: contentCategoryIndex,
    cityToOneId: cityId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    city: city,
    media: media,
    isSaved: isSaved,
    isDeleted: isDeleted,
  );
}
