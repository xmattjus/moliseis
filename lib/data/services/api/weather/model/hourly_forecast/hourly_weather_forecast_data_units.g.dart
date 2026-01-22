// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hourly_weather_forecast_data_units.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HourlyWeatherForecastDataUnits _$HourlyWeatherForecastDataUnitsFromJson(
  Map<String, dynamic> json,
) => HourlyWeatherForecastDataUnits(
  time: json['time'] as String,
  temperature2m: json['temperature_2m'] as String,
  relativeHumidity2m: json['relative_humidity_2m'] as String,
  apparentTemperature: json['apparent_temperature'] as String,
  precipitation: json['precipitation'] as String,
  precipitationProbability: json['precipitation_probability'] as String,
  weatherCode: json['weather_code'] as String,
);
