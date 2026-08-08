import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
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

  static const _unset = Object();

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
    Object? eventToOneId = _unset,
    Object? placeToOneId = _unset,
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
    eventToOneId: identical(eventToOneId, _unset)
        ? this.eventToOneId
        : eventToOneId as int?,
    placeToOneId: identical(placeToOneId, _unset)
        ? this.placeToOneId
        : placeToOneId as int?,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    place: place,
    event: event,
  );
}
