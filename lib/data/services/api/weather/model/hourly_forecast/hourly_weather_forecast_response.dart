import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data_units.dart';

part 'hourly_weather_forecast_response.g.dart';

@immutable
@JsonSerializable(createToJson: false, explicitToJson: true)
class HourlyWeatherForecastResponse extends BaseWeatherForecastResponse {
  @JsonKey(name: 'hourly_units')
  final HourlyWeatherForecastDataUnits units;
  final HourlyWeatherForecastData data;

  const HourlyWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.units,
    required this.data,
  });

  factory HourlyWeatherForecastResponse.fromJson(Map<String, dynamic> json) =>
      _$HourlyWeatherForecastResponseFromJson(json);
}
