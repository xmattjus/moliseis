import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';

part 'generated/daily_weather_forecast_data.mapper.dart';

/// Represents daily weather forecast data from the Open-Meteo API.
///
/// Contains aggregated weather predictions for each day including temperature
/// ranges and precipitation probability to support multi-day forecast views.
@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class DailyWeatherForecastData with DailyWeatherForecastDataMappable {
  const DailyWeatherForecastData({
    required this.time,
    required this.weatherCode,
    required this.temperature2mMax,
    required this.temperature2mMin,
    required this.precipitationProbabilityMax,
  });

  final List<String> time;
  final List<int> weatherCode;
  @MappableField(key: 'temperature_2m_max')
  final List<double> temperature2mMax;
  @MappableField(key: 'temperature_2m_min')
  final List<double> temperature2mMin;
  final List<int> precipitationProbabilityMax;
}
