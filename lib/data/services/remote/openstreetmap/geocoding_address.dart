// ignore_for_file: non_constant_identifier_names

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'geocoding_address.g.dart';

@Immutable()
@JsonSerializable(createToJson: false)
class GeocodingAddress {
  final String? amenity;
  final String? road;
  final String? neighbourhood;
  final String? hamlet;
  final String? village;
  final String? town;
  final String county;
  @JsonKey(name: 'ISO3166-2-lvl6')
  final String iso3166_2_lvl6;
  final String state;
  @JsonKey(name: 'ISO3166-2-lvl4')
  final String iso3166_2_lvl4;
  final String? postcode;
  final String country;
  @JsonKey(name: 'country_code')
  final String countryCode;

  const GeocodingAddress({
    this.amenity,
    this.road,
    this.neighbourhood,
    this.hamlet,
    this.village,
    this.town,
    required this.county,
    required this.iso3166_2_lvl6,
    required this.state,
    required this.iso3166_2_lvl4,
    this.postcode,
    required this.country,
    required this.countryCode,
  });

  factory GeocodingAddress.fromJson(Map<String, dynamic> json) =>
      _$GeocodingAddressFromJson(json);
}
