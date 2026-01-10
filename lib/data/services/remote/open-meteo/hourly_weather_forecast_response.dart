import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/remote/open-meteo/hourly.dart';
import 'package:moliseis/data/services/remote/open-meteo/hourly_units.dart';

part 'hourly_weather_forecast_response.g.dart';

@Immutable()
@JsonSerializable(createToJson: false, explicitToJson: true)
class HourlyWeatherForecastResponse {
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
  @JsonKey(name: 'hourly_units')
  final HourlyUnits hourlyUnits;
  final Hourly hourly;

  const HourlyWeatherForecastResponse({
    required this.latitude,
    required this.longitude,
    required this.generationTimeMs,
    required this.utcOffsetSeconds,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.elevation,
    required this.hourlyUnits,
    required this.hourly,
  });

  factory HourlyWeatherForecastResponse.fromJson(Map<String, dynamic> json) =>
      _$HourlyWeatherForecastResponseFromJson(json);
}
