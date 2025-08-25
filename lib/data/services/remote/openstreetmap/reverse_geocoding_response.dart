import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/remote/openstreetmap/geocoding_address.dart';

part 'reverse_geocoding_response.g.dart';

@Immutable()
@JsonSerializable(createToJson: false, explicitToJson: true)
class ReverseGeocodingResponse {
  @JsonKey(name: 'place_id')
  final int placeId;
  final String licence;
  @JsonKey(name: 'osm_type')
  final String osmType;
  @JsonKey(name: 'osm_id')
  final int osmId;
  final String lat;
  final String lon;
  final String category;
  final String type;
  @JsonKey(name: 'place_rank')
  final int placeRank;
  final double importance;
  @JsonKey(name: 'addresstype')
  final String addressType;
  final String name;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'address')
  final GeocodingAddress geocodingAddress;
  @JsonKey(name: 'boundingbox')
  final List<String> boundingBox;

  const ReverseGeocodingResponse({
    required this.placeId,
    required this.licence,
    required this.osmType,
    required this.osmId,
    required this.lat,
    required this.lon,
    required this.category,
    required this.type,
    required this.placeRank,
    required this.importance,
    required this.addressType,
    required this.name,
    required this.displayName,
    required this.geocodingAddress,
    required this.boundingBox,
  });

  factory ReverseGeocodingResponse.fromJson(Map<String, dynamic> json) =>
      _$ReverseGeocodingResponseFromJson(json);
}
