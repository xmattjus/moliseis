import 'package:json_annotation/json_annotation.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:objectbox/objectbox.dart';

part 'media_entity.g.dart';

@Entity()
@JsonSerializable()
class MediaEntity {
  const MediaEntity({
    required this.remoteId,
    this.title,
    this.author,
    this.license,
    this.licenseUrl,
    required this.url,
    required this.width,
    required this.height,
    this.placeToOneId,
    this.eventToOneId,
    required this.createdAt,
    required this.modifiedAt,
    required this.place,
    required this.event,
  });

  @JsonKey(name: 'id')
  @Id(assignable: true)
  final int remoteId;

  final String? title;

  final String? author;

  final String? license;

  @JsonKey(name: 'license_url')
  final String? licenseUrl;

  final String url;

  final int width;

  final int height;

  @JsonKey(name: 'place_id')
  final int? placeToOneId;

  @JsonKey(name: 'event_id')
  final int? eventToOneId;

  @Property(type: PropertyType.dateNano)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @Property(type: PropertyType.dateNano)
  @JsonKey(name: 'modified_at')
  final DateTime modifiedAt;

  @PlaceRelToOneConverter()
  final ToOne<PlaceEntity> place;

  @EventRelToOneConverter()
  final ToOne<EventEntity> event;

  @override
  bool operator ==(Object other) =>
      other is MediaEntity &&
      other.remoteId == remoteId &&
      other.title == title &&
      other.author == author &&
      other.license == license &&
      other.licenseUrl == licenseUrl &&
      other.url == url &&
      other.width == width &&
      other.height == height &&
      other.placeToOneId == placeToOneId &&
      other.eventToOneId == eventToOneId &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.modifiedAt.isAtSameMomentAs(modifiedAt);

  @override
  int get hashCode => Object.hash(
    remoteId,
    title,
    author,
    license,
    licenseUrl,
    url,
    width,
    height,
    placeToOneId,
    eventToOneId,
    createdAt,
    modifiedAt,
  );

  MediaEntity copyWith({
    String? title,
    String? author,
    String? license,
    String? licenseUrl,
    String? url,
    int? width,
    int? height,
    int? Function()? placeToOneId,
    int? Function()? eventToOneId,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    // https://stackoverflow.com/a/71591609
    final newPlaceToOneId = placeToOneId != null
        ? placeToOneId()
        : this.placeToOneId;

    final newEventToOneId = eventToOneId != null
        ? eventToOneId()
        : this.eventToOneId;

    final copy = MediaEntity(
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
      placeToOneId: newPlaceToOneId,
      eventToOneId: newEventToOneId,
      place: place,
      event: event,
    );

    copy.place.targetId = newPlaceToOneId;

    copy.event.targetId = newEventToOneId;

    return copy;
  }

  factory MediaEntity.fromJson(Map<String, dynamic> json) =>
      _$MediaEntityFromJson(json);

  Map<String, dynamic> toJson() => _$MediaEntityToJson(this);
}

class MediaRelToManyConverter
    implements JsonConverter<ToMany<MediaEntity>, List<dynamic>?> {
  const MediaRelToManyConverter();

  @override
  // Media is always loaded via ObjectBox backlinks, never from embedded JSON.
  ToMany<MediaEntity> fromJson(List<dynamic>? json) =>
      ToMany<MediaEntity>(items: []);

  @override
  List<Map<String, dynamic>>? toJson(ToMany<MediaEntity> rel) =>
      rel.map((MediaEntity obj) => obj.toJson()).toList();
}
