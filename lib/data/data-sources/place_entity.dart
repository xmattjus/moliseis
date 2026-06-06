import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class PlaceEntity implements SyncEntity {
  PlaceEntity({
    required this.remoteId,
    required this.name,
    this.description,
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

  @Backlink('place')
  final ToMany<MediaEntity> media;

  final bool isSaved;

  PlaceEntity copyWith({
    String? name,
    String? description,
    List<double>? coordinates,
    int? contentCategoryIndex,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isDeleted,
    bool? isSaved,
  }) => PlaceEntity(
    remoteId: remoteId,
    name: name ?? this.name,
    description: description ?? this.description,
    coordinates: coordinates ?? this.coordinates,
    contentCategoryIndex: contentCategoryIndex ?? this.contentCategoryIndex,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    city: city,
    media: media,
    isDeleted: isDeleted ?? this.isDeleted,
    isSaved: isSaved ?? this.isSaved,
  );

  /// Creates a copy of this [PlaceEntity] with [cityToOneId] set to [cityId].
  PlaceEntity updateRelationId(int? cityId) => PlaceEntity(
    remoteId: remoteId,
    name: name,
    description: description,
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
