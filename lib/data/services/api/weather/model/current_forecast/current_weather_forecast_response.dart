import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';

part 'generated/current_weather_forecast_response.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class CurrentWeatherForecastResponse extends BaseWeatherForecastResponse
    with CurrentWeatherForecastResponseMappable {
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

  @MappableField(key: 'current')
  final CurrentWeatherForecastData data;
}
