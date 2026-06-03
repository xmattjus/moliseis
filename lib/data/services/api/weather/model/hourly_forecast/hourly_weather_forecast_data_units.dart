import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';

part 'generated/hourly_weather_forecast_data_units.mapper.dart';

@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class HourlyWeatherForecastDataUnits
    with HourlyWeatherForecastDataUnitsMappable {
  const HourlyWeatherForecastDataUnits({
    required this.time,
    required this.temperature2m,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final String time;
  final String temperature2m;
  final String precipitationProbability;
  final String weatherCode;
}
