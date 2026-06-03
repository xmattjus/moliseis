import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';

part 'generated/daily_weather_forecast_response.mapper.dart';

/// Response model for daily weather forecast API calls.
///
/// Wraps the base response metadata with daily-specific forecast data.
@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class DailyWeatherForecastResponse extends BaseWeatherForecastResponse
    with DailyWeatherForecastResponseMappable {
  const DailyWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.data,
  });

  @MappableField(key: 'daily')
  final DailyWeatherForecastData data;
}
