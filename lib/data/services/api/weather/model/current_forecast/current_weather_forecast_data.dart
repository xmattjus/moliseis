import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'current_weather_forecast_data.g.dart';

@immutable
@JsonSerializable(createToJson: false)
class CurrentWeatherForecastData {
  final DateTime time;
  final int interval;
  @JsonKey(name: 'temperature_2m')
  final double temperature;
  @JsonKey(name: 'is_day')
  final int isDay;
  @JsonKey(name: 'apparent_temperature')
  final double? apparentTemperature;
  @JsonKey(name: 'weather_code')
  final int weatherCode;
  final double? precipitation;

  const CurrentWeatherForecastData({
    required this.time,
    required this.interval,
    required this.temperature,
    required this.isDay,
    this.apparentTemperature,
    required this.weatherCode,
    this.precipitation,
  });

  factory CurrentWeatherForecastData.fromJson(Map<String, dynamic> json) =>
      _$CurrentWeatherForecastDataFromJson(json);
}
