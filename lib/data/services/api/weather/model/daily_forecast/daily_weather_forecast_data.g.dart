// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_weather_forecast_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyWeatherForecastData _$DailyWeatherForecastDataFromJson(
  Map<String, dynamic> json,
) => DailyWeatherForecastData(
  time: (json['time'] as List<dynamic>).map((e) => e as String).toList(),
  weatherCode: (json['weather_code'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  temperature2mMax: (json['temperature_2m_max'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
  temperature2mMin: (json['temperature_2m_min'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
  precipitationProbabilityMax:
      (json['precipitation_probability_max'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
);
