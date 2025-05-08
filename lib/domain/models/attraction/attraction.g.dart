// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attraction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attraction _$AttractionFromJson(Map<String, dynamic> json) => Attraction(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  summary: json['summary'] as String,
  description: json['description'] as String,
  history: json['history'] as String,
  images: const _MolisImageRelToManyConverter().fromJson(
    json['images'] as List<Map<String, dynamic>>?,
  ),
  coordinates:
      (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
  type:
      $enumDecodeNullable(_$AttractionTypeEnumMap, json['type']) ??
      AttractionType.unknown,
  sources: (json['sources'] as List<dynamic>).map((e) => e as String).toList(),
  backlinkId: (json['place_id'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  place: const _PlaceRelToOneConverter().fromJson(
    json['place'] as Map<String, dynamic>?,
  ),
);

Map<String, dynamic> _$AttractionToJson(Attraction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'summary': instance.summary,
      'description': instance.description,
      'history': instance.history,
      'images': const _MolisImageRelToManyConverter().toJson(instance.images),
      'coordinates': instance.coordinates,
      'sources': instance.sources,
      'place_id': instance.backlinkId,
      'created_at': instance.createdAt.toIso8601String(),
      'modified_at': instance.modifiedAt.toIso8601String(),
      'type': _$AttractionTypeEnumMap[instance.type]!,
      'place': const _PlaceRelToOneConverter().toJson(instance.place),
    };

const _$AttractionTypeEnumMap = {
  AttractionType.unknown: 'unknown',
  AttractionType.nature: 'nature',
  AttractionType.history: 'history',
  AttractionType.folklore: 'folklore',
  AttractionType.food: 'food',
  AttractionType.allure: 'allure',
  AttractionType.experience: 'experience',
};
