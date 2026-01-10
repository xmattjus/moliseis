import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'hourly.g.dart';

@Immutable()
@JsonSerializable(createToJson: false)
class Hourly {
  final List<String> time;
  @JsonKey(name: 'temperature_2m')
  final List<double> temperature2m;
  @JsonKey(name: 'relative_humidity_2m')
  final List<int> relativeHumidity2m;
  @JsonKey(name: 'apparent_temperature')
  final List<int> apparentTemperature;
  final List<double> precipitation;
  @JsonKey(name: 'precipitation_probability')
  final List<int> precipitationProbability;
  @JsonKey(name: 'weather_code')
  final List<int> weatherCode;

  const Hourly({
    required this.time,
    required this.temperature2m,
    required this.relativeHumidity2m,
    required this.apparentTemperature,
    required this.precipitation,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  factory Hourly.fromJson(Map<String, dynamic> json) => _$HourlyFromJson(json);
}
