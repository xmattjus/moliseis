// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

City _$CityFromJson(Map<String, dynamic> json) => City(
  remoteId: (json['id'] as num).toInt(),
  name: json['name'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  places: const PlaceRelToManyConverter().fromJson(
    json['places'] as List<Map<String, dynamic>>?,
  ),
  events: const EventRelToManyConverter().fromJson(
    json['events'] as List<Map<String, dynamic>>?,
  ),
);

Map<String, dynamic> _$CityToJson(City instance) => <String, dynamic>{
  'id': instance.remoteId,
  'name': instance.name,
  'created_at': instance.createdAt.toIso8601String(),
  'modified_at': instance.modifiedAt.toIso8601String(),
  'places': const PlaceRelToManyConverter().toJson(instance.places),
  'events': const EventRelToManyConverter().toJson(instance.events),
};
