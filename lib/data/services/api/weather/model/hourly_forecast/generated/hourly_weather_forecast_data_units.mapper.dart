// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../hourly_weather_forecast_data_units.dart';

class HourlyWeatherForecastDataUnitsMapper
    extends ClassMapperBase<HourlyWeatherForecastDataUnits> {
  HourlyWeatherForecastDataUnitsMapper._();

  static HourlyWeatherForecastDataUnitsMapper? _instance;
  static HourlyWeatherForecastDataUnitsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = HourlyWeatherForecastDataUnitsMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'HourlyWeatherForecastDataUnits';

  static String _$time(HourlyWeatherForecastDataUnits v) => v.time;
  static const Field<HourlyWeatherForecastDataUnits, String> _f$time = Field(
    'time',
    _$time,
  );
  static String _$temperature2m(HourlyWeatherForecastDataUnits v) =>
      v.temperature2m;
  static const Field<HourlyWeatherForecastDataUnits, String> _f$temperature2m =
      Field('temperature2m', _$temperature2m);
  static String _$precipitationProbability(HourlyWeatherForecastDataUnits v) =>
      v.precipitationProbability;
  static const Field<HourlyWeatherForecastDataUnits, String>
  _f$precipitationProbability = Field(
    'precipitationProbability',
    _$precipitationProbability,
    key: r'precipitation_probability',
  );
  static String _$weatherCode(HourlyWeatherForecastDataUnits v) =>
      v.weatherCode;
  static const Field<HourlyWeatherForecastDataUnits, String> _f$weatherCode =
      Field('weatherCode', _$weatherCode, key: r'weather_code');

  @override
  final MappableFields<HourlyWeatherForecastDataUnits> fields = const {
    #time: _f$time,
    #temperature2m: _f$temperature2m,
    #precipitationProbability: _f$precipitationProbability,
    #weatherCode: _f$weatherCode,
  };

  static HourlyWeatherForecastDataUnits _instantiate(DecodingData data) {
    return HourlyWeatherForecastDataUnits(
      time: data.dec(_f$time),
      temperature2m: data.dec(_f$temperature2m),
      precipitationProbability: data.dec(_f$precipitationProbability),
      weatherCode: data.dec(_f$weatherCode),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HourlyWeatherForecastDataUnits fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HourlyWeatherForecastDataUnits>(map);
  }

  static HourlyWeatherForecastDataUnits fromJson(String json) {
    return ensureInitialized().decodeJson<HourlyWeatherForecastDataUnits>(json);
  }
}

mixin HourlyWeatherForecastDataUnitsMappable {
  @override
  String toString() {
    return HourlyWeatherForecastDataUnitsMapper.ensureInitialized()
        .stringifyValue(this as HourlyWeatherForecastDataUnits);
  }
}

