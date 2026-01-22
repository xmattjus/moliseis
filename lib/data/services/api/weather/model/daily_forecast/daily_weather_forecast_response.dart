import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';

part 'daily_weather_forecast_response.g.dart';

/// Response model for daily weather forecast API calls.
///
/// Wraps the base response metadata with daily-specific forecast data.
@immutable
@JsonSerializable(createToJson: false, explicitToJson: true)
class DailyWeatherForecastResponse extends BaseWeatherForecastResponse {
  @JsonKey(name: 'daily')
  final DailyWeatherForecastData data;

  const DailyWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.data,
  });

  factory DailyWeatherForecastResponse.fromJson(Map<String, dynamic> json) =>
      _$DailyWeatherForecastResponseFromJson(json);
}
