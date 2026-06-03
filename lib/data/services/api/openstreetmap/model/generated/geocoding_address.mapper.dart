// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../geocoding_address.dart';

class GeocodingAddressMapper extends ClassMapperBase<GeocodingAddress> {
  GeocodingAddressMapper._();

  static GeocodingAddressMapper? _instance;
  static GeocodingAddressMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GeocodingAddressMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'GeocodingAddress';

  static String? _$amenity(GeocodingAddress v) => v.amenity;
  static const Field<GeocodingAddress, String> _f$amenity = Field(
    'amenity',
    _$amenity,
    opt: true,
  );
  static String? _$road(GeocodingAddress v) => v.road;
  static const Field<GeocodingAddress, String> _f$road = Field(
    'road',
    _$road,
    opt: true,
  );
  static String? _$neighbourhood(GeocodingAddress v) => v.neighbourhood;
  static const Field<GeocodingAddress, String> _f$neighbourhood = Field(
    'neighbourhood',
    _$neighbourhood,
    opt: true,
  );
  static String? _$hamlet(GeocodingAddress v) => v.hamlet;
  static const Field<GeocodingAddress, String> _f$hamlet = Field(
    'hamlet',
    _$hamlet,
    opt: true,
  );
  static String? _$village(GeocodingAddress v) => v.village;
  static const Field<GeocodingAddress, String> _f$village = Field(
    'village',
    _$village,
    opt: true,
  );
  static String? _$town(GeocodingAddress v) => v.town;
  static const Field<GeocodingAddress, String> _f$town = Field(
    'town',
    _$town,
    opt: true,
  );
  static String _$county(GeocodingAddress v) => v.county;
  static const Field<GeocodingAddress, String> _f$county = Field(
    'county',
    _$county,
  );
  static String _$iso3166_2_lvl6(GeocodingAddress v) => v.iso3166_2_lvl6;
  static const Field<GeocodingAddress, String> _f$iso3166_2_lvl6 = Field(
    'iso3166_2_lvl6',
    _$iso3166_2_lvl6,
    key: r'ISO3166-2-lvl6',
  );
  static String _$state(GeocodingAddress v) => v.state;
  static const Field<GeocodingAddress, String> _f$state = Field(
    'state',
    _$state,
  );
  static String _$iso3166_2_lvl4(GeocodingAddress v) => v.iso3166_2_lvl4;
  static const Field<GeocodingAddress, String> _f$iso3166_2_lvl4 = Field(
    'iso3166_2_lvl4',
    _$iso3166_2_lvl4,
    key: r'ISO3166-2-lvl4',
  );
  static String? _$postcode(GeocodingAddress v) => v.postcode;
  static const Field<GeocodingAddress, String> _f$postcode = Field(
    'postcode',
    _$postcode,
    opt: true,
  );
  static String _$country(GeocodingAddress v) => v.country;
  static const Field<GeocodingAddress, String> _f$country = Field(
    'country',
    _$country,
  );
  static String _$countryCode(GeocodingAddress v) => v.countryCode;
  static const Field<GeocodingAddress, String> _f$countryCode = Field(
    'countryCode',
    _$countryCode,
    key: r'country_code',
  );

  @override
  final MappableFields<GeocodingAddress> fields = const {
    #amenity: _f$amenity,
    #road: _f$road,
    #neighbourhood: _f$neighbourhood,
    #hamlet: _f$hamlet,
    #village: _f$village,
    #town: _f$town,
    #county: _f$county,
    #iso3166_2_lvl6: _f$iso3166_2_lvl6,
    #state: _f$state,
    #iso3166_2_lvl4: _f$iso3166_2_lvl4,
    #postcode: _f$postcode,
    #country: _f$country,
    #countryCode: _f$countryCode,
  };

  static GeocodingAddress _instantiate(DecodingData data) {
    return GeocodingAddress(
      amenity: data.dec(_f$amenity),
      road: data.dec(_f$road),
      neighbourhood: data.dec(_f$neighbourhood),
      hamlet: data.dec(_f$hamlet),
      village: data.dec(_f$village),
      town: data.dec(_f$town),
      county: data.dec(_f$county),
      iso3166_2_lvl6: data.dec(_f$iso3166_2_lvl6),
      state: data.dec(_f$state),
      iso3166_2_lvl4: data.dec(_f$iso3166_2_lvl4),
      postcode: data.dec(_f$postcode),
      country: data.dec(_f$country),
      countryCode: data.dec(_f$countryCode),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GeocodingAddress fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GeocodingAddress>(map);
  }

  static GeocodingAddress fromJson(String json) {
    return ensureInitialized().decodeJson<GeocodingAddress>(json);
  }
}

mixin GeocodingAddressMappable {
  @override
  String toString() {
    return GeocodingAddressMapper.ensureInitialized().stringifyValue(
      this as GeocodingAddress,
    );
  }
}

