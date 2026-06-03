// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../daily_weather_forecast_data.dart';

class DailyWeatherForecastDataMapper
    extends ClassMapperBase<DailyWeatherForecastData> {
  DailyWeatherForecastDataMapper._();

  static DailyWeatherForecastDataMapper? _instance;
  static DailyWeatherForecastDataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = DailyWeatherForecastDataMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'DailyWeatherForecastData';

  static List<String> _$time(DailyWeatherForecastData v) => v.time;
  static const Field<DailyWeatherForecastData, List<String>> _f$time = Field(
    'time',
    _$time,
  );
  static List<int> _$weatherCode(DailyWeatherForecastData v) => v.weatherCode;
  static const Field<DailyWeatherForecastData, List<int>> _f$weatherCode =
      Field('weatherCode', _$weatherCode, key: r'weather_code');
  static List<double> _$temperature2mMax(DailyWeatherForecastData v) =>
      v.temperature2mMax;
  static const Field<DailyWeatherForecastData, List<double>>
  _f$temperature2mMax = Field(
    'temperature2mMax',
    _$temperature2mMax,
    key: r'temperature_2m_max',
  );
  static List<double> _$temperature2mMin(DailyWeatherForecastData v) =>
      v.temperature2mMin;
  static const Field<DailyWeatherForecastData, List<double>>
  _f$temperature2mMin = Field(
    'temperature2mMin',
    _$temperature2mMin,
    key: r'temperature_2m_min',
  );
  static List<int> _$precipitationProbabilityMax(DailyWeatherForecastData v) =>
      v.precipitationProbabilityMax;
  static const Field<DailyWeatherForecastData, List<int>>
  _f$precipitationProbabilityMax = Field(
    'precipitationProbabilityMax',
    _$precipitationProbabilityMax,
    key: r'precipitation_probability_max',
  );

  @override
  final MappableFields<DailyWeatherForecastData> fields = const {
    #time: _f$time,
    #weatherCode: _f$weatherCode,
    #temperature2mMax: _f$temperature2mMax,
    #temperature2mMin: _f$temperature2mMin,
    #precipitationProbabilityMax: _f$precipitationProbabilityMax,
  };

  static DailyWeatherForecastData _instantiate(DecodingData data) {
    return DailyWeatherForecastData(
      time: data.dec(_f$time),
      weatherCode: data.dec(_f$weatherCode),
      temperature2mMax: data.dec(_f$temperature2mMax),
      temperature2mMin: data.dec(_f$temperature2mMin),
      precipitationProbabilityMax: data.dec(_f$precipitationProbabilityMax),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DailyWeatherForecastData fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DailyWeatherForecastData>(map);
  }

  static DailyWeatherForecastData fromJson(String json) {
    return ensureInitialized().decodeJson<DailyWeatherForecastData>(json);
  }
}

mixin DailyWeatherForecastDataMappable {
  @override
  String toString() {
    return DailyWeatherForecastDataMapper.ensureInitialized().stringifyValue(
      this as DailyWeatherForecastData,
    );
  }
}

