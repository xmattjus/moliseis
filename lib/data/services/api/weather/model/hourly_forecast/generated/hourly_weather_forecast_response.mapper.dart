// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../hourly_weather_forecast_response.dart';

class HourlyWeatherForecastResponseMapper
    extends ClassMapperBase<HourlyWeatherForecastResponse> {
  HourlyWeatherForecastResponseMapper._();

  static HourlyWeatherForecastResponseMapper? _instance;
  static HourlyWeatherForecastResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = HourlyWeatherForecastResponseMapper._(),
      );
      BaseWeatherForecastResponseMapper.ensureInitialized();
      HourlyWeatherForecastDataUnitsMapper.ensureInitialized();
      HourlyWeatherForecastDataMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HourlyWeatherForecastResponse';

  static double _$latitude(HourlyWeatherForecastResponse v) => v.latitude;
  static const Field<HourlyWeatherForecastResponse, double> _f$latitude = Field(
    'latitude',
    _$latitude,
  );
  static double _$longitude(HourlyWeatherForecastResponse v) => v.longitude;
  static const Field<HourlyWeatherForecastResponse, double> _f$longitude =
      Field('longitude', _$longitude);
  static double _$generationTimeMs(HourlyWeatherForecastResponse v) =>
      v.generationTimeMs;
  static const Field<HourlyWeatherForecastResponse, double>
  _f$generationTimeMs = Field(
    'generationTimeMs',
    _$generationTimeMs,
    key: r'generationtime_ms',
  );
  static int _$utcOffsetSeconds(HourlyWeatherForecastResponse v) =>
      v.utcOffsetSeconds;
  static const Field<HourlyWeatherForecastResponse, int> _f$utcOffsetSeconds =
      Field('utcOffsetSeconds', _$utcOffsetSeconds, key: r'utc_offset_seconds');
  static String _$timezone(HourlyWeatherForecastResponse v) => v.timezone;
  static const Field<HourlyWeatherForecastResponse, String> _f$timezone = Field(
    'timezone',
    _$timezone,
  );
  static String _$timezoneAbbreviation(HourlyWeatherForecastResponse v) =>
      v.timezoneAbbreviation;
  static const Field<HourlyWeatherForecastResponse, String>
  _f$timezoneAbbreviation = Field(
    'timezoneAbbreviation',
    _$timezoneAbbreviation,
    key: r'timezone_abbreviation',
  );
  static int _$elevation(HourlyWeatherForecastResponse v) => v.elevation;
  static const Field<HourlyWeatherForecastResponse, int> _f$elevation = Field(
    'elevation',
    _$elevation,
  );
  static HourlyWeatherForecastDataUnits _$hourlyUnits(
    HourlyWeatherForecastResponse v,
  ) => v.hourlyUnits;
  static const Field<
    HourlyWeatherForecastResponse,
    HourlyWeatherForecastDataUnits
  >
  _f$hourlyUnits = Field('hourlyUnits', _$hourlyUnits, key: r'hourly_units');
  static HourlyWeatherForecastData _$data(HourlyWeatherForecastResponse v) =>
      v.data;
  static const Field<HourlyWeatherForecastResponse, HourlyWeatherForecastData>
  _f$data = Field('data', _$data);

  @override
  final MappableFields<HourlyWeatherForecastResponse> fields = const {
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #generationTimeMs: _f$generationTimeMs,
    #utcOffsetSeconds: _f$utcOffsetSeconds,
    #timezone: _f$timezone,
    #timezoneAbbreviation: _f$timezoneAbbreviation,
    #elevation: _f$elevation,
    #hourlyUnits: _f$hourlyUnits,
    #data: _f$data,
  };

  static HourlyWeatherForecastResponse _instantiate(DecodingData data) {
    return HourlyWeatherForecastResponse(
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      generationTimeMs: data.dec(_f$generationTimeMs),
      utcOffsetSeconds: data.dec(_f$utcOffsetSeconds),
      timezone: data.dec(_f$timezone),
      timezoneAbbreviation: data.dec(_f$timezoneAbbreviation),
      elevation: data.dec(_f$elevation),
      hourlyUnits: data.dec(_f$hourlyUnits),
      data: data.dec(_f$data),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HourlyWeatherForecastResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HourlyWeatherForecastResponse>(map);
  }

  static HourlyWeatherForecastResponse fromJson(String json) {
    return ensureInitialized().decodeJson<HourlyWeatherForecastResponse>(json);
  }
}

mixin HourlyWeatherForecastResponseMappable {
  @override
  String toString() {
    return HourlyWeatherForecastResponseMapper.ensureInitialized()
        .stringifyValue(this as HourlyWeatherForecastResponse);
  }
}

