import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';

part 'generated/hourly_weather_forecast_data.mapper.dart';

@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class HourlyWeatherForecastData with HourlyWeatherForecastDataMappable {
  const HourlyWeatherForecastData({
    required this.time,
    required this.temperature2m,
    required this.precipitationProbability,
    required this.weatherCode,
    this.isDay,
  });

  final List<String> time;
  @MappableField(key: 'temperature_2m')
  final List<double> temperature2m;
  final List<int> weatherCode;
  final List<int> precipitationProbability;
  final List<int>? isDay;
}
