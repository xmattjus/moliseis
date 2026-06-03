import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/services/api/openstreetmap/model/geocoding_address.dart';

part 'generated/reverse_geocoding_response.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class ReverseGeocodingResponse with ReverseGeocodingResponseMappable {
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

  final int placeId;
  final String licence;
  final String osmType;
  final int osmId;
  final String lat;
  final String lon;
  final String category;
  final String type;
  final int placeRank;
  final double importance;
  @MappableField(key: 'addresstype')
  final String addressType;
  final String name;
  final String displayName;
  @MappableField(key: 'address')
  final GeocodingAddress geocodingAddress;
  @MappableField(key: 'boundingbox')
  final List<String> boundingBox;
}
