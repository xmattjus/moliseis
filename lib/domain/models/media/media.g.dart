// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Media _$MediaFromJson(Map<String, dynamic> json) => Media(
  remoteId: (json['id'] as num).toInt(),
  title: json['title'] as String?,
  author: json['author'] as String?,
  license: json['license'] as String?,
  licenseUrl: json['license_url'] as String?,
  url: json['url'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  placeToOneId: (json['place_id'] as num?)?.toInt(),
  eventToOneId: (json['event_id'] as num?)?.toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  place: const PlaceRelToOneConverter().fromJson(
    json['place'] as Map<String, dynamic>?,
  ),
  event: const EventRelToOneConverter().fromJson(
    json['event'] as Map<String, dynamic>?,
  ),
);

Map<String, dynamic> _$MediaToJson(Media instance) => <String, dynamic>{
  'id': instance.remoteId,
  'title': instance.title,
  'author': instance.author,
  'license': instance.license,
  'license_url': instance.licenseUrl,
  'url': instance.url,
  'width': instance.width,
  'height': instance.height,
  'place_id': instance.placeToOneId,
  'event_id': instance.eventToOneId,
  'created_at': instance.createdAt.toIso8601String(),
  'modified_at': instance.modifiedAt.toIso8601String(),
  'place': const PlaceRelToOneConverter().toJson(instance.place),
  'event': const EventRelToOneConverter().toJson(instance.event),
};
