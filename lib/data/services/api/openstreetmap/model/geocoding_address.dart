// Names follow poorly formatted json response keys.
// ignore_for_file: non_constant_identifier_names

import 'package:dart_mappable/dart_mappable.dart';

part 'generated/geocoding_address.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class GeocodingAddress with GeocodingAddressMappable {
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

  final String? amenity;
  final String? road;
  final String? neighbourhood;
  final String? hamlet;
  final String? village;
  final String? town;
  final String county;
  @MappableField(key: 'ISO3166-2-lvl6')
  final String iso3166_2_lvl6;
  final String state;
  @MappableField(key: 'ISO3166-2-lvl4')
  final String iso3166_2_lvl4;
  final String? postcode;
  final String country;
  final String countryCode;
}
