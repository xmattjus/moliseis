import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';

part 'generated/combined_weather_forecast_response.mapper.dart';

/// Unified response model for combined weather forecast API calls.
///
/// Contains current, hourly, and daily forecast data from a single Open-Meteo
/// API request. This reduces network overhead and API quota usage by fetching
/// all weather data at once instead of making separate requests for each
/// forecast type.
@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class CombinedWeatherForecastResponse extends BaseWeatherForecastResponse
    with CombinedWeatherForecastResponseMappable {
  const CombinedWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final CurrentWeatherForecastData current;
  final HourlyWeatherForecastData hourly;
  final DailyWeatherForecastData daily;
}
