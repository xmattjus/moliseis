import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';

part 'combined_weather_forecast_response.g.dart';

/// Unified response model for combined weather forecast API calls.
///
/// Contains current, hourly, and daily forecast data from a single Open-Meteo
/// API request. This reduces network overhead and API quota usage by fetching
/// all weather data at once instead of making separate requests for each
/// forecast type.
@immutable
@JsonSerializable(createToJson: false, explicitToJson: true)
class CombinedWeatherForecastResponse extends BaseWeatherForecastResponse {
  @JsonKey(name: 'current')
  final CurrentWeatherForecastData currentData;
  @JsonKey(name: 'hourly')
  final HourlyWeatherForecastData hourlyData;
  @JsonKey(name: 'daily')
  final DailyWeatherForecastData dailyData;

  const CombinedWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.currentData,
    required this.hourlyData,
    required this.dailyData,
  });

  factory CombinedWeatherForecastResponse.fromJson(Map<String, dynamic> json) =>
      _$CombinedWeatherForecastResponseFromJson(json);
}
