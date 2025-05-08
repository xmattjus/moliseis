// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paragraph.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Paragraph _$ParagraphFromJson(Map<String, dynamic> json) => Paragraph(
  id: (json['id'] as num).toInt(),
  heading: json['heading'] as String,
  subheading: json['subheading'] as String,
  body: json['body'] as String,
  backlinkId: (json['story_id'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  story: const _StoryRelToOneConverter().fromJson(
    json['story'] as Map<String, dynamic>?,
  ),
);

Map<String, dynamic> _$ParagraphToJson(Paragraph instance) => <String, dynamic>{
  'id': instance.id,
  'heading': instance.heading,
  'subheading': instance.subheading,
  'body': instance.body,
  'story_id': instance.backlinkId,
  'created_at': instance.createdAt.toIso8601String(),
  'modified_at': instance.modifiedAt.toIso8601String(),
  'story': const _StoryRelToOneConverter().toJson(instance.story),
};
