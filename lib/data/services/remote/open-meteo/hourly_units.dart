import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'hourly_units.g.dart';

@Immutable()
@JsonSerializable(createToJson: false)
class HourlyUnits {
  final String time;
  @JsonKey(name: 'temperature_2m')
  final String temperature2m;
  @JsonKey(name: 'relative_humidity_2m')
  final String relativeHumidity2m;
  @JsonKey(name: 'apparent_temperature')
  final String apparentTemperature;
  @JsonKey(name: 'precipitation_probability')
  final String precipitationProbability;
  @JsonKey(name: 'weather_code')
  final String weatherCode;

  const HourlyUnits({
    required this.time,
    required this.temperature2m,
    required this.relativeHumidity2m,
    required this.apparentTemperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  factory HourlyUnits.fromJson(Map<String, dynamic> json) =>
      _$HourlyUnitsFromJson(json);
}
