// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Place _$PlaceFromJson(Map<String, dynamic> json) => Place(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  attractions: const _AttractionRelToManyConverter().fromJson(
    json['attractions'] as List<Map<String, dynamic>>?,
  ),
);

Map<String, dynamic> _$PlaceToJson(Place instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'created_at': instance.createdAt.toIso8601String(),
  'modified_at': instance.modifiedAt.toIso8601String(),
  'attractions': const _AttractionRelToManyConverter().toJson(
    instance.attractions,
  ),
};
