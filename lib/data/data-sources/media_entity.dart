import 'package:moliseis/data/core/sync_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class MediaEntity implements SyncEntity {
  const MediaEntity({
    required this.remoteId,
    this.title,
    this.author,
    this.license,
    this.licenseUrl,
    required this.url,
    required this.width,
    required this.height,
    this.eventToOneId,
    this.placeToOneId,
    required this.createdAt,
    required this.modifiedAt,
    required this.place,
    required this.event,
    this.isDeleted = false,
  });

  @override
  @Id(assignable: true)
  final int remoteId;

  final String? title;

  final String? author;

  final String? license;

  final String? licenseUrl;

  final String url;

  final int width;

  final int height;

  final int? eventToOneId;

  final int? placeToOneId;

  @Property(type: PropertyType.dateNano)
  final DateTime createdAt;

  @override
  @Property(type: PropertyType.dateNano)
  final DateTime modifiedAt;

  @override
  final bool isDeleted;

  final ToOne<PlaceEntity> place;

  final ToOne<EventEntity> event;

  MediaEntity copyWith({
    String? title,
    String? author,
    String? license,
    String? licenseUrl,
    String? url,
    int? width,
    int? height,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isDeleted,
  }) => MediaEntity(
    remoteId: remoteId,
    title: title ?? this.title,
    author: author ?? this.author,
    license: license ?? this.license,
    licenseUrl: licenseUrl ?? this.licenseUrl,
    url: url ?? this.url,
    width: width ?? this.width,
    height: height ?? this.height,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    place: place,
    event: event,
  );

  /// Creates a copy of this [MediaEntity] with [eventToOneId] set to [eventId]
  /// and [placeToOneId] set to [placeId].
  MediaEntity updateRelationIds(int? eventId, int? placeId) => MediaEntity(
    remoteId: remoteId,
    title: title,
    author: author,
    license: license,
    licenseUrl: licenseUrl,
    url: url,
    width: width,
    height: height,
    eventToOneId: eventId,
    placeToOneId: placeId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    isDeleted: isDeleted,
    place: place,
    event: event,
  );
}
