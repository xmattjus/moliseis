import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';

part 'current_weather_forecast_response.g.dart';

@immutable
@JsonSerializable(createToJson: false, explicitToJson: true)
class CurrentWeatherForecastResponse extends BaseWeatherForecastResponse {
  @JsonKey(name: 'current')
  final CurrentWeatherForecastData data;

  const CurrentWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.data,
  });

  factory CurrentWeatherForecastResponse.fromJson(Map<String, dynamic> json) =>
      _$CurrentWeatherForecastResponseFromJson(json);
}
