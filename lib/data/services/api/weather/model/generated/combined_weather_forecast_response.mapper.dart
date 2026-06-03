// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../combined_weather_forecast_response.dart';

class CombinedWeatherForecastResponseMapper
    extends ClassMapperBase<CombinedWeatherForecastResponse> {
  CombinedWeatherForecastResponseMapper._();

  static CombinedWeatherForecastResponseMapper? _instance;
  static CombinedWeatherForecastResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = CombinedWeatherForecastResponseMapper._(),
      );
      BaseWeatherForecastResponseMapper.ensureInitialized();
      CurrentWeatherForecastDataMapper.ensureInitialized();
      HourlyWeatherForecastDataMapper.ensureInitialized();
      DailyWeatherForecastDataMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CombinedWeatherForecastResponse';

  static double _$latitude(CombinedWeatherForecastResponse v) => v.latitude;
  static const Field<CombinedWeatherForecastResponse, double> _f$latitude =
      Field('latitude', _$latitude);
  static double _$longitude(CombinedWeatherForecastResponse v) => v.longitude;
  static const Field<CombinedWeatherForecastResponse, double> _f$longitude =
      Field('longitude', _$longitude);
  static double _$generationTimeMs(CombinedWeatherForecastResponse v) =>
      v.generationTimeMs;
  static const Field<CombinedWeatherForecastResponse, double>
  _f$generationTimeMs = Field(
    'generationTimeMs',
    _$generationTimeMs,
    key: r'generationtime_ms',
  );
  static int _$utcOffsetSeconds(CombinedWeatherForecastResponse v) =>
      v.utcOffsetSeconds;
  static const Field<CombinedWeatherForecastResponse, int> _f$utcOffsetSeconds =
      Field('utcOffsetSeconds', _$utcOffsetSeconds, key: r'utc_offset_seconds');
  static String _$timezone(CombinedWeatherForecastResponse v) => v.timezone;
  static const Field<CombinedWeatherForecastResponse, String> _f$timezone =
      Field('timezone', _$timezone);
  static String _$timezoneAbbreviation(CombinedWeatherForecastResponse v) =>
      v.timezoneAbbreviation;
  static const Field<CombinedWeatherForecastResponse, String>
  _f$timezoneAbbreviation = Field(
    'timezoneAbbreviation',
    _$timezoneAbbreviation,
    key: r'timezone_abbreviation',
  );
  static int _$elevation(CombinedWeatherForecastResponse v) => v.elevation;
  static const Field<CombinedWeatherForecastResponse, int> _f$elevation = Field(
    'elevation',
    _$elevation,
  );
  static CurrentWeatherForecastData _$current(
    CombinedWeatherForecastResponse v,
  ) => v.current;
  static const Field<
    CombinedWeatherForecastResponse,
    CurrentWeatherForecastData
  >
  _f$current = Field('current', _$current);
  static HourlyWeatherForecastData _$hourly(
    CombinedWeatherForecastResponse v,
  ) => v.hourly;
  static const Field<CombinedWeatherForecastResponse, HourlyWeatherForecastData>
  _f$hourly = Field('hourly', _$hourly);
  static DailyWeatherForecastData _$daily(CombinedWeatherForecastResponse v) =>
      v.daily;
  static const Field<CombinedWeatherForecastResponse, DailyWeatherForecastData>
  _f$daily = Field('daily', _$daily);

  @override
  final MappableFields<CombinedWeatherForecastResponse> fields = const {
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #generationTimeMs: _f$generationTimeMs,
    #utcOffsetSeconds: _f$utcOffsetSeconds,
    #timezone: _f$timezone,
    #timezoneAbbreviation: _f$timezoneAbbreviation,
    #elevation: _f$elevation,
    #current: _f$current,
    #hourly: _f$hourly,
    #daily: _f$daily,
  };

  static CombinedWeatherForecastResponse _instantiate(DecodingData data) {
    return CombinedWeatherForecastResponse(
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      generationTimeMs: data.dec(_f$generationTimeMs),
      utcOffsetSeconds: data.dec(_f$utcOffsetSeconds),
      timezone: data.dec(_f$timezone),
      timezoneAbbreviation: data.dec(_f$timezoneAbbreviation),
      elevation: data.dec(_f$elevation),
      current: data.dec(_f$current),
      hourly: data.dec(_f$hourly),
      daily: data.dec(_f$daily),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CombinedWeatherForecastResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CombinedWeatherForecastResponse>(map);
  }

  static CombinedWeatherForecastResponse fromJson(String json) {
    return ensureInitialized().decodeJson<CombinedWeatherForecastResponse>(
      json,
    );
  }
}

mixin CombinedWeatherForecastResponseMappable {
  @override
  String toString() {
    return CombinedWeatherForecastResponseMapper.ensureInitialized()
        .stringifyValue(this as CombinedWeatherForecastResponse);
  }
}

