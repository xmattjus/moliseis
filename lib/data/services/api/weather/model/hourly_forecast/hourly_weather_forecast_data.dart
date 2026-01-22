import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'hourly_weather_forecast_data.g.dart';

@immutable
@JsonSerializable(createToJson: false)
class HourlyWeatherForecastData {
  final List<String> time;
  @JsonKey(name: 'temperature_2m')
  final List<double> temperature2m;
  @JsonKey(name: 'relative_humidity_2m')
  final List<int>? relativeHumidity2m;
  @JsonKey(name: 'apparent_temperature')
  final List<double>? apparentTemperature;
  final List<double>? precipitation;
  @JsonKey(name: 'precipitation_probability')
  final List<int> precipitationProbability;
  @JsonKey(name: 'weather_code')
  final List<int> weatherCode;
  @JsonKey(name: 'is_day')
  final List<int>? isDay;

  const HourlyWeatherForecastData({
    required this.time,
    required this.temperature2m,
    this.relativeHumidity2m,
    this.apparentTemperature,
    this.precipitation,
    required this.precipitationProbability,
    required this.weatherCode,
    this.isDay,
  });

  factory HourlyWeatherForecastData.fromJson(Map<String, dynamic> json) =>
      _$HourlyWeatherForecastDataFromJson(json);
}
