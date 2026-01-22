import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'base_weather_forecast_response.g.dart';

@immutable
@JsonSerializable(createToJson: false, explicitToJson: true)
class BaseWeatherForecastResponse {
  final double latitude;
  final double longitude;
  @JsonKey(name: 'generationtime_ms')
  final double generationTimeMs;
  @JsonKey(name: 'utc_offset_seconds')
  final int utcOffsetSeconds;
  final String timezone;
  @JsonKey(name: 'timezone_abbreviation')
  final String timezoneAbbreviation;
  final int elevation;

  const BaseWeatherForecastResponse({
    required this.latitude,
    required this.longitude,
    required this.generationTimeMs,
    required this.utcOffsetSeconds,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.elevation,
  });

  factory BaseWeatherForecastResponse.fromJson(Map<String, dynamic> json) =>
      _$BaseWeatherForecastResponseFromJson(json);
}
