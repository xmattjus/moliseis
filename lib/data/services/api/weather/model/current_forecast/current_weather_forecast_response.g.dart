// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_weather_forecast_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurrentWeatherForecastResponse _$CurrentWeatherForecastResponseFromJson(
  Map<String, dynamic> json,
) => CurrentWeatherForecastResponse(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  generationTimeMs: (json['generationtime_ms'] as num).toDouble(),
  utcOffsetSeconds: (json['utc_offset_seconds'] as num).toInt(),
  timezone: json['timezone'] as String,
  timezoneAbbreviation: json['timezone_abbreviation'] as String,
  elevation: (json['elevation'] as num).toInt(),
  data: CurrentWeatherForecastData.fromJson(
    json['current'] as Map<String, dynamic>,
  ),
);
