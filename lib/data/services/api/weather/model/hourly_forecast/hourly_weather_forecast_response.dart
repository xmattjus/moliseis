import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/weather/model/base_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data_units.dart';

part 'generated/hourly_weather_forecast_response.mapper.dart';

@immutable
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods: GenerateMethods.decode | GenerateMethods.stringify,
)
class HourlyWeatherForecastResponse extends BaseWeatherForecastResponse
    with HourlyWeatherForecastResponseMappable {
  const HourlyWeatherForecastResponse({
    required super.latitude,
    required super.longitude,
    required super.generationTimeMs,
    required super.utcOffsetSeconds,
    required super.timezone,
    required super.timezoneAbbreviation,
    required super.elevation,
    required this.hourlyUnits,
    required this.data,
  });

  final HourlyWeatherForecastDataUnits hourlyUnits;
  final HourlyWeatherForecastData data;
}
