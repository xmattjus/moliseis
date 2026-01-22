import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'hourly_weather_forecast_data_units.g.dart';

@immutable
@JsonSerializable(createToJson: false)
class HourlyWeatherForecastDataUnits {
  final String time;
  @JsonKey(name: 'temperature_2m')
  final String temperature2m;
  @JsonKey(name: 'relative_humidity_2m')
  final String relativeHumidity2m;
  @JsonKey(name: 'apparent_temperature')
  final String apparentTemperature;
  final String precipitation;
  @JsonKey(name: 'precipitation_probability')
  final String precipitationProbability;
  @JsonKey(name: 'weather_code')
  final String weatherCode;

  const HourlyWeatherForecastDataUnits({
    required this.time,
    required this.temperature2m,
    required this.relativeHumidity2m,
    required this.apparentTemperature,
    required this.precipitation,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  factory HourlyWeatherForecastDataUnits.fromJson(Map<String, dynamic> json) =>
      _$HourlyWeatherForecastDataUnitsFromJson(json);
}
