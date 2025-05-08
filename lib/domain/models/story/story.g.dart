// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Story _$StoryFromJson(Map<String, dynamic> json) => Story(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  author: json['author'] as String,
  shortDescription: json['short_description'] as String,
  sources: (json['sources'] as List<dynamic>).map((e) => e as String).toList(),
  backlinkId: (json['attraction_id'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  attraction: const _AttractionRelToOneConverter().fromJson(
    json['attraction'] as Map<String, dynamic>?,
  ),
);

Map<String, dynamic> _$StoryToJson(Story instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'author': instance.author,
  'short_description': instance.shortDescription,
  'sources': instance.sources,
  'attraction_id': instance.backlinkId,
  'created_at': instance.createdAt.toIso8601String(),
  'modified_at': instance.modifiedAt.toIso8601String(),
  'attraction': const _AttractionRelToOneConverter().toJson(
    instance.attraction,
  ),
};
