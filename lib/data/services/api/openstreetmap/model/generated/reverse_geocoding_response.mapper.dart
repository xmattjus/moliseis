// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../reverse_geocoding_response.dart';

class ReverseGeocodingResponseMapper
    extends ClassMapperBase<ReverseGeocodingResponse> {
  ReverseGeocodingResponseMapper._();

  static ReverseGeocodingResponseMapper? _instance;
  static ReverseGeocodingResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ReverseGeocodingResponseMapper._(),
      );
      GeocodingAddressMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ReverseGeocodingResponse';

  static int _$placeId(ReverseGeocodingResponse v) => v.placeId;
  static const Field<ReverseGeocodingResponse, int> _f$placeId = Field(
    'placeId',
    _$placeId,
    key: r'place_id',
  );
  static String _$licence(ReverseGeocodingResponse v) => v.licence;
  static const Field<ReverseGeocodingResponse, String> _f$licence = Field(
    'licence',
    _$licence,
  );
  static String _$osmType(ReverseGeocodingResponse v) => v.osmType;
  static const Field<ReverseGeocodingResponse, String> _f$osmType = Field(
    'osmType',
    _$osmType,
    key: r'osm_type',
  );
  static int _$osmId(ReverseGeocodingResponse v) => v.osmId;
  static const Field<ReverseGeocodingResponse, int> _f$osmId = Field(
    'osmId',
    _$osmId,
    key: r'osm_id',
  );
  static String _$lat(ReverseGeocodingResponse v) => v.lat;
  static const Field<ReverseGeocodingResponse, String> _f$lat = Field(
    'lat',
    _$lat,
  );
  static String _$lon(ReverseGeocodingResponse v) => v.lon;
  static const Field<ReverseGeocodingResponse, String> _f$lon = Field(
    'lon',
    _$lon,
  );
  static String _$category(ReverseGeocodingResponse v) => v.category;
  static const Field<ReverseGeocodingResponse, String> _f$category = Field(
    'category',
    _$category,
  );
  static String _$type(ReverseGeocodingResponse v) => v.type;
  static const Field<ReverseGeocodingResponse, String> _f$type = Field(
    'type',
    _$type,
  );
  static int _$placeRank(ReverseGeocodingResponse v) => v.placeRank;
  static const Field<ReverseGeocodingResponse, int> _f$placeRank = Field(
    'placeRank',
    _$placeRank,
    key: r'place_rank',
  );
  static double _$importance(ReverseGeocodingResponse v) => v.importance;
  static const Field<ReverseGeocodingResponse, double> _f$importance = Field(
    'importance',
    _$importance,
  );
  static String _$addressType(ReverseGeocodingResponse v) => v.addressType;
  static const Field<ReverseGeocodingResponse, String> _f$addressType = Field(
    'addressType',
    _$addressType,
    key: r'addresstype',
  );
  static String _$name(ReverseGeocodingResponse v) => v.name;
  static const Field<ReverseGeocodingResponse, String> _f$name = Field(
    'name',
    _$name,
  );
  static String _$displayName(ReverseGeocodingResponse v) => v.displayName;
  static const Field<ReverseGeocodingResponse, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    key: r'display_name',
  );
  static GeocodingAddress _$geocodingAddress(ReverseGeocodingResponse v) =>
      v.geocodingAddress;
  static const Field<ReverseGeocodingResponse, GeocodingAddress>
  _f$geocodingAddress = Field(
    'geocodingAddress',
    _$geocodingAddress,
    key: r'address',
  );
  static List<String> _$boundingBox(ReverseGeocodingResponse v) =>
      v.boundingBox;
  static const Field<ReverseGeocodingResponse, List<String>> _f$boundingBox =
      Field('boundingBox', _$boundingBox, key: r'boundingbox');

  @override
  final MappableFields<ReverseGeocodingResponse> fields = const {
    #placeId: _f$placeId,
    #licence: _f$licence,
    #osmType: _f$osmType,
    #osmId: _f$osmId,
    #lat: _f$lat,
    #lon: _f$lon,
    #category: _f$category,
    #type: _f$type,
    #placeRank: _f$placeRank,
    #importance: _f$importance,
    #addressType: _f$addressType,
    #name: _f$name,
    #displayName: _f$displayName,
    #geocodingAddress: _f$geocodingAddress,
    #boundingBox: _f$boundingBox,
  };

  static ReverseGeocodingResponse _instantiate(DecodingData data) {
    return ReverseGeocodingResponse(
      placeId: data.dec(_f$placeId),
      licence: data.dec(_f$licence),
      osmType: data.dec(_f$osmType),
      osmId: data.dec(_f$osmId),
      lat: data.dec(_f$lat),
      lon: data.dec(_f$lon),
      category: data.dec(_f$category),
      type: data.dec(_f$type),
      placeRank: data.dec(_f$placeRank),
      importance: data.dec(_f$importance),
      addressType: data.dec(_f$addressType),
      name: data.dec(_f$name),
      displayName: data.dec(_f$displayName),
      geocodingAddress: data.dec(_f$geocodingAddress),
      boundingBox: data.dec(_f$boundingBox),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ReverseGeocodingResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ReverseGeocodingResponse>(map);
  }

  static ReverseGeocodingResponse fromJson(String json) {
    return ensureInitialized().decodeJson<ReverseGeocodingResponse>(json);
  }
}

mixin ReverseGeocodingResponseMappable {
  @override
  String toString() {
    return ReverseGeocodingResponseMapper.ensureInitialized().stringifyValue(
      this as ReverseGeocodingResponse,
    );
  }
}

