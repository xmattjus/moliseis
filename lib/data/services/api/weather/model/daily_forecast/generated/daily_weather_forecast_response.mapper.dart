// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../daily_weather_forecast_response.dart';

class DailyWeatherForecastResponseMapper
    extends ClassMapperBase<DailyWeatherForecastResponse> {
  DailyWeatherForecastResponseMapper._();

  static DailyWeatherForecastResponseMapper? _instance;
  static DailyWeatherForecastResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = DailyWeatherForecastResponseMapper._(),
      );
      BaseWeatherForecastResponseMapper.ensureInitialized();
      DailyWeatherForecastDataMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DailyWeatherForecastResponse';

  static double _$latitude(DailyWeatherForecastResponse v) => v.latitude;
  static const Field<DailyWeatherForecastResponse, double> _f$latitude = Field(
    'latitude',
    _$latitude,
  );
  static double _$longitude(DailyWeatherForecastResponse v) => v.longitude;
  static const Field<DailyWeatherForecastResponse, double> _f$longitude = Field(
    'longitude',
    _$longitude,
  );
  static double _$generationTimeMs(DailyWeatherForecastResponse v) =>
      v.generationTimeMs;
  static const Field<DailyWeatherForecastResponse, double> _f$generationTimeMs =
      Field('generationTimeMs', _$generationTimeMs, key: r'generationtime_ms');
  static int _$utcOffsetSeconds(DailyWeatherForecastResponse v) =>
      v.utcOffsetSeconds;
  static const Field<DailyWeatherForecastResponse, int> _f$utcOffsetSeconds =
      Field('utcOffsetSeconds', _$utcOffsetSeconds, key: r'utc_offset_seconds');
  static String _$timezone(DailyWeatherForecastResponse v) => v.timezone;
  static const Field<DailyWeatherForecastResponse, String> _f$timezone = Field(
    'timezone',
    _$timezone,
  );
  static String _$timezoneAbbreviation(DailyWeatherForecastResponse v) =>
      v.timezoneAbbreviation;
  static const Field<DailyWeatherForecastResponse, String>
  _f$timezoneAbbreviation = Field(
    'timezoneAbbreviation',
    _$timezoneAbbreviation,
    key: r'timezone_abbreviation',
  );
  static int _$elevation(DailyWeatherForecastResponse v) => v.elevation;
  static const Field<DailyWeatherForecastResponse, int> _f$elevation = Field(
    'elevation',
    _$elevation,
  );
  static DailyWeatherForecastData _$data(DailyWeatherForecastResponse v) =>
      v.data;
  static const Field<DailyWeatherForecastResponse, DailyWeatherForecastData>
  _f$data = Field('data', _$data, key: r'daily');

  @override
  final MappableFields<DailyWeatherForecastResponse> fields = const {
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #generationTimeMs: _f$generationTimeMs,
    #utcOffsetSeconds: _f$utcOffsetSeconds,
    #timezone: _f$timezone,
    #timezoneAbbreviation: _f$timezoneAbbreviation,
    #elevation: _f$elevation,
    #data: _f$data,
  };

  static DailyWeatherForecastResponse _instantiate(DecodingData data) {
    return DailyWeatherForecastResponse(
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

  static DailyWeatherForecastResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DailyWeatherForecastResponse>(map);
  }

  static DailyWeatherForecastResponse fromJson(String json) {
    return ensureInitialized().decodeJson<DailyWeatherForecastResponse>(json);
  }
}

mixin DailyWeatherForecastResponseMappable {
  @override
  String toString() {
    return DailyWeatherForecastResponseMapper.ensureInitialized()
        .stringifyValue(this as DailyWeatherForecastResponse);
  }
}

