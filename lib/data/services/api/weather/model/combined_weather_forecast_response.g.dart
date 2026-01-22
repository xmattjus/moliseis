// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'combined_weather_forecast_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CombinedWeatherForecastResponse _$CombinedWeatherForecastResponseFromJson(
  Map<String, dynamic> json,
) => CombinedWeatherForecastResponse(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  generationTimeMs: (json['generationtime_ms'] as num).toDouble(),
  utcOffsetSeconds: (json['utc_offset_seconds'] as num).toInt(),
  timezone: json['timezone'] as String,
  timezoneAbbreviation: json['timezone_abbreviation'] as String,
  elevation: (json['elevation'] as num).toInt(),
  currentData: CurrentWeatherForecastData.fromJson(
    json['current'] as Map<String, dynamic>,
  ),
  hourlyData: HourlyWeatherForecastData.fromJson(
    json['hourly'] as Map<String, dynamic>,
  ),
  dailyData: DailyWeatherForecastData.fromJson(
    json['daily'] as Map<String, dynamic>,
  ),
);
