import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';

part 'generated/base_weather_forecast_response.mapper.dart';

@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class BaseWeatherForecastResponse with BaseWeatherForecastResponseMappable {
  const BaseWeatherForecastResponse({
    required this.latitude,
    required this.longitude,
    required this.generationTimeMs,
    required this.utcOffsetSeconds,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.elevation,
  });

  final double latitude;
  final double longitude;
  @MappableField(key: 'generationtime_ms')
  final double generationTimeMs;
  final int utcOffsetSeconds;
  final String timezone;
  final String timezoneAbbreviation;
  final int elevation;
}
