// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_weather_forecast_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyWeatherForecastResponse _$DailyWeatherForecastResponseFromJson(
  Map<String, dynamic> json,
) => DailyWeatherForecastResponse(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  generationTimeMs: (json['generationtime_ms'] as num).toDouble(),
  utcOffsetSeconds: (json['utc_offset_seconds'] as num).toInt(),
  timezone: json['timezone'] as String,
  timezoneAbbreviation: json['timezone_abbreviation'] as String,
  elevation: (json['elevation'] as num).toInt(),
  data: DailyWeatherForecastData.fromJson(
    json['daily'] as Map<String, dynamic>,
  ),
);
