// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_weather_forecast_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurrentWeatherForecastData _$CurrentWeatherForecastDataFromJson(
  Map<String, dynamic> json,
) => CurrentWeatherForecastData(
  time: DateTime.parse(json['time'] as String),
  interval: (json['interval'] as num).toInt(),
  temperature: (json['temperature_2m'] as num).toDouble(),
  isDay: (json['is_day'] as num).toInt(),
  apparentTemperature: (json['apparent_temperature'] as num?)?.toDouble(),
  weatherCode: (json['weather_code'] as num).toInt(),
  precipitation: (json['precipitation'] as num?)?.toDouble(),
);
