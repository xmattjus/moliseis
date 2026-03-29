import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'hourly_weather_forecast_data.g.dart';

@immutable
@JsonSerializable(createToJson: false)
class HourlyWeatherForecastData {
  final List<String> time;
  @JsonKey(name: 'temperature_2m')
  final List<double> temperature2m;
  @JsonKey(name: 'weather_code')
  final List<int> weatherCode;
  @JsonKey(name: 'precipitation_probability')
  final List<int> precipitationProbability;
  @JsonKey(name: 'is_day')
  final List<int>? isDay;

  const HourlyWeatherForecastData({
    required this.time,
    required this.temperature2m,
    required this.precipitationProbability,
    required this.weatherCode,
    this.isDay,
  });

  factory HourlyWeatherForecastData.fromJson(Map<String, dynamic> json) =>
      _$HourlyWeatherForecastDataFromJson(json);
}
