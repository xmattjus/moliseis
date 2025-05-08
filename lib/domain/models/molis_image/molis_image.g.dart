// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'molis_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MolisImage _$MolisImageFromJson(Map<String, dynamic> json) => MolisImage(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  author: json['author'] as String,
  license: json['license'] as String,
  licenseUrl: json['license_url'] as String,
  url: json['url'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  modifiedAt: DateTime.parse(json['modified_at'] as String),
  backlinkId: (json['attraction_id'] as num).toInt(),
  attraction: const _AttractionRelToOneConverter().fromJson(
    json['attraction'] as Map<String, dynamic>?,
  ),
);

Map<String, dynamic> _$MolisImageToJson(MolisImage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'author': instance.author,
      'license': instance.license,
      'license_url': instance.licenseUrl,
      'url': instance.url,
      'width': instance.width,
      'height': instance.height,
      'created_at': instance.createdAt.toIso8601String(),
      'modified_at': instance.modifiedAt.toIso8601String(),
      'attraction_id': instance.backlinkId,
      'attraction': const _AttractionRelToOneConverter().toJson(
        instance.attraction,
      ),
    };
