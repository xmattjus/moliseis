// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../base_weather_forecast_response.dart';

class BaseWeatherForecastResponseMapper
    extends ClassMapperBase<BaseWeatherForecastResponse> {
  BaseWeatherForecastResponseMapper._();

  static BaseWeatherForecastResponseMapper? _instance;
  static BaseWeatherForecastResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = BaseWeatherForecastResponseMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'BaseWeatherForecastResponse';

  static double _$latitude(BaseWeatherForecastResponse v) => v.latitude;
  static const Field<BaseWeatherForecastResponse, double> _f$latitude = Field(
    'latitude',
    _$latitude,
  );
  static double _$longitude(BaseWeatherForecastResponse v) => v.longitude;
  static const Field<BaseWeatherForecastResponse, double> _f$longitude = Field(
    'longitude',
    _$longitude,
  );
  static double _$generationTimeMs(BaseWeatherForecastResponse v) =>
      v.generationTimeMs;
  static const Field<BaseWeatherForecastResponse, double> _f$generationTimeMs =
      Field('generationTimeMs', _$generationTimeMs, key: r'generationtime_ms');
  static int _$utcOffsetSeconds(BaseWeatherForecastResponse v) =>
      v.utcOffsetSeconds;
  static const Field<BaseWeatherForecastResponse, int> _f$utcOffsetSeconds =
      Field('utcOffsetSeconds', _$utcOffsetSeconds, key: r'utc_offset_seconds');
  static String _$timezone(BaseWeatherForecastResponse v) => v.timezone;
  static const Field<BaseWeatherForecastResponse, String> _f$timezone = Field(
    'timezone',
    _$timezone,
  );
  static String _$timezoneAbbreviation(BaseWeatherForecastResponse v) =>
      v.timezoneAbbreviation;
  static const Field<BaseWeatherForecastResponse, String>
  _f$timezoneAbbreviation = Field(
    'timezoneAbbreviation',
    _$timezoneAbbreviation,
    key: r'timezone_abbreviation',
  );
  static int _$elevation(BaseWeatherForecastResponse v) => v.elevation;
  static const Field<BaseWeatherForecastResponse, int> _f$elevation = Field(
    'elevation',
    _$elevation,
  );

  @override
  final MappableFields<BaseWeatherForecastResponse> fields = const {
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #generationTimeMs: _f$generationTimeMs,
    #utcOffsetSeconds: _f$utcOffsetSeconds,
    #timezone: _f$timezone,
    #timezoneAbbreviation: _f$timezoneAbbreviation,
    #elevation: _f$elevation,
  };

  static BaseWeatherForecastResponse _instantiate(DecodingData data) {
    return BaseWeatherForecastResponse(
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      generationTimeMs: data.dec(_f$generationTimeMs),
      utcOffsetSeconds: data.dec(_f$utcOffsetSeconds),
      timezone: data.dec(_f$timezone),
      timezoneAbbreviation: data.dec(_f$timezoneAbbreviation),
      elevation: data.dec(_f$elevation),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BaseWeatherForecastResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BaseWeatherForecastResponse>(map);
  }

  static BaseWeatherForecastResponse fromJson(String json) {
    return ensureInitialized().decodeJson<BaseWeatherForecastResponse>(json);
  }
}

mixin BaseWeatherForecastResponseMappable {
  @override
  String toString() {
    return BaseWeatherForecastResponseMapper.ensureInitialized().stringifyValue(
      this as BaseWeatherForecastResponse,
    );
  }
}

