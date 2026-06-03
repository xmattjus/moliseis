import 'package:dart_mappable/dart_mappable.dart';

part 'generated/current_weather_forecast_data.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class CurrentWeatherForecastData with CurrentWeatherForecastDataMappable {
  const CurrentWeatherForecastData({
    required this.time,
    required this.interval,
    required this.temperature2m,
    required this.isDay,
    required this.weatherCode,
    this.precipitation,
  });

  final DateTime time;
  final int interval;
  @MappableField(key: 'temperature_2m')
  final double temperature2m;
  final int isDay;
  final int weatherCode;
  final double? precipitation;
}
