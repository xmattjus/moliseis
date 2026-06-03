// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../current_weather_forecast_response.dart';

class CurrentWeatherForecastResponseMapper
    extends ClassMapperBase<CurrentWeatherForecastResponse> {
  CurrentWeatherForecastResponseMapper._();

  static CurrentWeatherForecastResponseMapper? _instance;
  static CurrentWeatherForecastResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = CurrentWeatherForecastResponseMapper._(),
      );
      BaseWeatherForecastResponseMapper.ensureInitialized();
      CurrentWeatherForecastDataMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CurrentWeatherForecastResponse';

  static double _$latitude(CurrentWeatherForecastResponse v) => v.latitude;
  static const Field<CurrentWeatherForecastResponse, double> _f$latitude =
      Field('latitude', _$latitude);
  static double _$longitude(CurrentWeatherForecastResponse v) => v.longitude;
  static const Field<CurrentWeatherForecastResponse, double> _f$longitude =
      Field('longitude', _$longitude);
  static double _$generationTimeMs(CurrentWeatherForecastResponse v) =>
      v.generationTimeMs;
  static const Field<CurrentWeatherForecastResponse, double>
  _f$generationTimeMs = Field(
    'generationTimeMs',
    _$generationTimeMs,
    key: r'generationtime_ms',
  );
  static int _$utcOffsetSeconds(CurrentWeatherForecastResponse v) =>
      v.utcOffsetSeconds;
  static const Field<CurrentWeatherForecastResponse, int> _f$utcOffsetSeconds =
      Field('utcOffsetSeconds', _$utcOffsetSeconds, key: r'utc_offset_seconds');
  static String _$timezone(CurrentWeatherForecastResponse v) => v.timezone;
  static const Field<CurrentWeatherForecastResponse, String> _f$timezone =
      Field('timezone', _$timezone);
  static String _$timezoneAbbreviation(CurrentWeatherForecastResponse v) =>
      v.timezoneAbbreviation;
  static const Field<CurrentWeatherForecastResponse, String>
  _f$timezoneAbbreviation = Field(
    'timezoneAbbreviation',
    _$timezoneAbbreviation,
    key: r'timezone_abbreviation',
  );
  static int _$elevation(CurrentWeatherForecastResponse v) => v.elevation;
  static const Field<CurrentWeatherForecastResponse, int> _f$elevation = Field(
    'elevation',
    _$elevation,
  );
  static CurrentWeatherForecastData _$data(CurrentWeatherForecastResponse v) =>
      v.data;
  static const Field<CurrentWeatherForecastResponse, CurrentWeatherForecastData>
  _f$data = Field('data', _$data, key: r'current');

  @override
  final MappableFields<CurrentWeatherForecastResponse> fields = const {
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #generationTimeMs: _f$generationTimeMs,
    #utcOffsetSeconds: _f$utcOffsetSeconds,
    #timezone: _f$timezone,
    #timezoneAbbreviation: _f$timezoneAbbreviation,
    #elevation: _f$elevation,
    #data: _f$data,
  };

  static CurrentWeatherForecastResponse _instantiate(DecodingData data) {
    return CurrentWeatherForecastResponse(
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      generationTimeMs: data.dec(_f$generationTimeMs),
      utcOffsetSeconds: data.dec(_f$utcOffsetSeconds),
      timezone: data.dec(_f$timezone),
      timezoneAbbreviation: data.dec(_f$timezoneAbbreviation),
      elevation: data.dec(_f$elevation),
      data: data.dec(_f$data),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CurrentWeatherForecastResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CurrentWeatherForecastResponse>(map);
  }

  static CurrentWeatherForecastResponse fromJson(String json) {
    return ensureInitialized().decodeJson<CurrentWeatherForecastResponse>(json);
  }
}

mixin CurrentWeatherForecastResponseMappable {
  @override
  String toString() {
    return CurrentWeatherForecastResponseMapper.ensureInitialized()
        .stringifyValue(this as CurrentWeatherForecastResponse);
  }
}

