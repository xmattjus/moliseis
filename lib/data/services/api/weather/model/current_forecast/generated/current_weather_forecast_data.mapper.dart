// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../current_weather_forecast_data.dart';

class CurrentWeatherForecastDataMapper
    extends ClassMapperBase<CurrentWeatherForecastData> {
  CurrentWeatherForecastDataMapper._();

  static CurrentWeatherForecastDataMapper? _instance;
  static CurrentWeatherForecastDataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = CurrentWeatherForecastDataMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'CurrentWeatherForecastData';

  static DateTime _$time(CurrentWeatherForecastData v) => v.time;
  static const Field<CurrentWeatherForecastData, DateTime> _f$time = Field(
    'time',
    _$time,
  );
  static int _$interval(CurrentWeatherForecastData v) => v.interval;
  static const Field<CurrentWeatherForecastData, int> _f$interval = Field(
    'interval',
    _$interval,
  );
  static double _$temperature2m(CurrentWeatherForecastData v) =>
      v.temperature2m;
  static const Field<CurrentWeatherForecastData, double> _f$temperature2m =
      Field('temperature2m', _$temperature2m, key: r'temperature_2m');
  static int _$isDay(CurrentWeatherForecastData v) => v.isDay;
  static const Field<CurrentWeatherForecastData, int> _f$isDay = Field(
    'isDay',
    _$isDay,
    key: r'is_day',
  );
  static int _$weatherCode(CurrentWeatherForecastData v) => v.weatherCode;
  static const Field<CurrentWeatherForecastData, int> _f$weatherCode = Field(
    'weatherCode',
    _$weatherCode,
    key: r'weather_code',
  );
  static double? _$precipitation(CurrentWeatherForecastData v) =>
      v.precipitation;
  static const Field<CurrentWeatherForecastData, double> _f$precipitation =
      Field('precipitation', _$precipitation, opt: true);

  @override
  final MappableFields<CurrentWeatherForecastData> fields = const {
    #time: _f$time,
    #interval: _f$interval,
    #temperature2m: _f$temperature2m,
    #isDay: _f$isDay,
    #weatherCode: _f$weatherCode,
    #precipitation: _f$precipitation,
  };

  static CurrentWeatherForecastData _instantiate(DecodingData data) {
    return CurrentWeatherForecastData(
      time: data.dec(_f$time),
      interval: data.dec(_f$interval),
      temperature2m: data.dec(_f$temperature2m),
      isDay: data.dec(_f$isDay),
      weatherCode: data.dec(_f$weatherCode),
      precipitation: data.dec(_f$precipitation),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CurrentWeatherForecastData fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CurrentWeatherForecastData>(map);
  }

  static CurrentWeatherForecastData fromJson(String json) {
    return ensureInitialized().decodeJson<CurrentWeatherForecastData>(json);
  }
}

mixin CurrentWeatherForecastDataMappable {
  @override
  String toString() {
    return CurrentWeatherForecastDataMapper.ensureInitialized().stringifyValue(
      this as CurrentWeatherForecastData,
    );
  }
}

