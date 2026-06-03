// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../hourly_weather_forecast_data.dart';

class HourlyWeatherForecastDataMapper
    extends ClassMapperBase<HourlyWeatherForecastData> {
  HourlyWeatherForecastDataMapper._();

  static HourlyWeatherForecastDataMapper? _instance;
  static HourlyWeatherForecastDataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = HourlyWeatherForecastDataMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'HourlyWeatherForecastData';

  static List<String> _$time(HourlyWeatherForecastData v) => v.time;
  static const Field<HourlyWeatherForecastData, List<String>> _f$time = Field(
    'time',
    _$time,
  );
  static List<double> _$temperature2m(HourlyWeatherForecastData v) =>
      v.temperature2m;
  static const Field<HourlyWeatherForecastData, List<double>> _f$temperature2m =
      Field('temperature2m', _$temperature2m, key: r'temperature_2m');
  static List<int> _$precipitationProbability(HourlyWeatherForecastData v) =>
      v.precipitationProbability;
  static const Field<HourlyWeatherForecastData, List<int>>
  _f$precipitationProbability = Field(
    'precipitationProbability',
    _$precipitationProbability,
    key: r'precipitation_probability',
  );
  static List<int> _$weatherCode(HourlyWeatherForecastData v) => v.weatherCode;
  static const Field<HourlyWeatherForecastData, List<int>> _f$weatherCode =
      Field('weatherCode', _$weatherCode, key: r'weather_code');
  static List<int>? _$isDay(HourlyWeatherForecastData v) => v.isDay;
  static const Field<HourlyWeatherForecastData, List<int>> _f$isDay = Field(
    'isDay',
    _$isDay,
    key: r'is_day',
    opt: true,
  );

  @override
  final MappableFields<HourlyWeatherForecastData> fields = const {
    #time: _f$time,
    #temperature2m: _f$temperature2m,
    #precipitationProbability: _f$precipitationProbability,
    #weatherCode: _f$weatherCode,
    #isDay: _f$isDay,
  };

  static HourlyWeatherForecastData _instantiate(DecodingData data) {
    return HourlyWeatherForecastData(
      time: data.dec(_f$time),
      temperature2m: data.dec(_f$temperature2m),
      precipitationProbability: data.dec(_f$precipitationProbability),
      weatherCode: data.dec(_f$weatherCode),
      isDay: data.dec(_f$isDay),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HourlyWeatherForecastData fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HourlyWeatherForecastData>(map);
  }

  static HourlyWeatherForecastData fromJson(String json) {
    return ensureInitialized().decodeJson<HourlyWeatherForecastData>(json);
  }
}

mixin HourlyWeatherForecastDataMappable {
  @override
  String toString() {
    return HourlyWeatherForecastDataMapper.ensureInitialized().stringifyValue(
      this as HourlyWeatherForecastData,
    );
  }
}

