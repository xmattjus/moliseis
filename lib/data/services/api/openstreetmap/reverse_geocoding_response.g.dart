// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reverse_geocoding_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReverseGeocodingResponse _$ReverseGeocodingResponseFromJson(
  Map<String, dynamic> json,
) => ReverseGeocodingResponse(
  placeId: (json['place_id'] as num).toInt(),
  licence: json['licence'] as String,
  osmType: json['osm_type'] as String,
  osmId: (json['osm_id'] as num).toInt(),
  lat: json['lat'] as String,
  lon: json['lon'] as String,
  category: json['category'] as String,
  type: json['type'] as String,
  placeRank: (json['place_rank'] as num).toInt(),
  importance: (json['importance'] as num).toDouble(),
  addressType: json['addresstype'] as String,
  name: json['name'] as String,
  displayName: json['display_name'] as String,
  geocodingAddress: GeocodingAddress.fromJson(
    json['address'] as Map<String, dynamic>,
  ),
  boundingBox: (json['boundingbox'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);
