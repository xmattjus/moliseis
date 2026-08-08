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
    this.descriptionDelta,
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

  static const _unset = Object();

  @override
  @Id(assignable: true)
  final int remoteId;

  @Index()
  final String name;

  final String? description;
  final List<Map<String, dynamic>>? descriptionDelta;

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
    Object? descriptionDelta = _unset,
    List<double>? coordinates,
    int? contentCategoryIndex,
    Object? cityToOneId = _unset,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isDeleted,
    bool? isSaved,
  }) => PlaceEntity(
    remoteId: remoteId,
    name: name ?? this.name,
    description: description ?? this.description,
    descriptionDelta: identical(descriptionDelta, _unset)
        ? this.descriptionDelta
        : descriptionDelta as List<Map<String, dynamic>>?,
    coordinates: coordinates ?? this.coordinates,
    contentCategoryIndex: contentCategoryIndex ?? this.contentCategoryIndex,
    cityToOneId: identical(cityToOneId, _unset)
        ? this.cityToOneId
        : cityToOneId as int?,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    city: city,
    media: media,
    isDeleted: isDeleted ?? this.isDeleted,
    isSaved: isSaved ?? this.isSaved,
  );
}
