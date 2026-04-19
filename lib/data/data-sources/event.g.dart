// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  remoteId: (json['id'] as num).toInt(),
  name: json['name'] as String?,
  description: json['description'] as String?,
  startDate: json['start_date'] == null
      ? null
      : DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
  coordinates:
      (json['coordinates'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
      const [0, 0],
  category:
      $enumDecodeNullable(_$ContentCategoryEnumMap, json['category']) ??
      ContentCategory.unknown,
  cityToOneId: (json['city_id'] as num?)?.toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  city: const CityRelToOneConverter().fromJson(
    json['city'] as Map<String, dynamic>?,
  ),
  media: const MediaRelToManyConverter().fromJson(json['media'] as List?),
);

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
  'id': instance.remoteId,
  'name': instance.name,
  'description': instance.description,
  'start_date': instance.startDate?.toIso8601String(),
  'end_date': instance.endDate?.toIso8601String(),
  'coordinates': instance.coordinates,
  'category': _$ContentCategoryEnumMap[instance.category]!,
  'city_id': instance.cityToOneId,
  'created_at': instance.createdAt.toIso8601String(),
  'modified_at': instance.modifiedAt.toIso8601String(),
  'city': const CityRelToOneConverter().toJson(instance.city),
  'media': const MediaRelToManyConverter().toJson(instance.media),
};

const _$ContentCategoryEnumMap = {
  ContentCategory.unknown: 'unknown',
  ContentCategory.nature: 'nature',
  ContentCategory.history: 'history',
  ContentCategory.folklore: 'folklore',
  ContentCategory.food: 'food',
  ContentCategory.allure: 'allure',
  ContentCategory.experience: 'experience',
};
