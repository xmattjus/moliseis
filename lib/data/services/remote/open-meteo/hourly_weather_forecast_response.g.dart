// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hourly_weather_forecast_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HourlyWeatherForecastResponse _$HourlyWeatherForecastResponseFromJson(
  Map<String, dynamic> json,
) => HourlyWeatherForecastResponse(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  generationTimeMs: (json['generationtime_ms'] as num).toDouble(),
  utcOffsetSeconds: (json['utc_offset_seconds'] as num).toInt(),
  timezone: json['timezone'] as String,
  timezoneAbbreviation: json['timezone_abbreviation'] as String,
  elevation: (json['elevation'] as num).toInt(),
  hourlyUnits: HourlyUnits.fromJson(
    json['hourly_units'] as Map<String, dynamic>,
  ),
  hourly: Hourly.fromJson(json['hourly'] as Map<String, dynamic>),
);
