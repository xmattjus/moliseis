// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hourly_weather_forecast_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HourlyWeatherForecastData _$HourlyWeatherForecastDataFromJson(
  Map<String, dynamic> json,
) => HourlyWeatherForecastData(
  time: (json['time'] as List<dynamic>).map((e) => e as String).toList(),
  temperature2m: (json['temperature_2m'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
  relativeHumidity2m: (json['relative_humidity_2m'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  apparentTemperature: (json['apparent_temperature'] as List<dynamic>?)
      ?.map((e) => (e as num).toDouble())
      .toList(),
  precipitation: (json['precipitation'] as List<dynamic>?)
      ?.map((e) => (e as num).toDouble())
      .toList(),
  precipitationProbability: (json['precipitation_probability'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  weatherCode: (json['weather_code'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  isDay: (json['is_day'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);
