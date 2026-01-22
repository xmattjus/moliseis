import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'daily_weather_forecast_data.g.dart';

/// Represents daily weather forecast data from the Open-Meteo API.
///
/// Contains aggregated weather predictions for each day including temperature
/// ranges and precipitation probability to support multi-day forecast views.
@immutable
@JsonSerializable(createToJson: false)
class DailyWeatherForecastData {
  final List<String> time;
  @JsonKey(name: 'weather_code')
  final List<int> weatherCode;
  @JsonKey(name: 'temperature_2m_max')
  final List<double> temperature2mMax;
  @JsonKey(name: 'temperature_2m_min')
  final List<double> temperature2mMin;
  @JsonKey(name: 'precipitation_probability_max')
  final List<int> precipitationProbabilityMax;

  const DailyWeatherForecastData({
    required this.time,
    required this.weatherCode,
    required this.temperature2mMax,
    required this.temperature2mMin,
    required this.precipitationProbabilityMax,
  });

  factory DailyWeatherForecastData.fromJson(Map<String, dynamic> json) =>
      _$DailyWeatherForecastDataFromJson(json);
}
