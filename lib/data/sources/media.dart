import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:objectbox/objectbox.dart';

part 'media.g.dart';

@immutable
@Entity()
@JsonSerializable()
class Media {
  const Media({
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
  final ToOne<Place> place;

  @EventRelToOneConverter()
  final ToOne<Event> event;

  @override
  bool operator ==(Object other) =>
      other is Media &&
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

  Media copyWith({
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

    final copy = Media(
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

  @override
  String toString() =>
      'remotedId: $remoteId, title: $title, author: $author, '
      'license: $license, licenseUrl: $licenseUrl, url: $url, width: $width, '
      'height: $height, placeToOneId: $placeToOneId, eventToOneId: $eventToOneId '
      'createdAt: $createdAt, modifiedAt: $modifiedAt';

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);

  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

class MediaRelToManyConverter
    implements JsonConverter<ToMany<Media>, List<dynamic>?> {
  const MediaRelToManyConverter();

  @override
  ToMany<Media> fromJson(List<dynamic>? json) => ToMany<Media>(items: []);

  @override
  List<Map<String, dynamic>>? toJson(ToMany<Media> rel) =>
      rel.map((Media obj) => obj.toJson()).toList();
}
