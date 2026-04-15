import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class WeatherViewModel extends ChangeNotifier {
  final CachedWeatherApiClient _weatherApiClient;
  final WmoWeatherDescriptionMapper _weatherDescriptionMapper;
  final WmoWeatherIconMapper _weatherCodeIconMapper;

  late Command1<CurrentWeatherForecastData, LatLng> loadCurrentForecast;
  late Command1<HourlyWeatherForecastData, LatLng> loadHourlyForecast;
  late Command1<DailyWeatherForecastData, LatLng> loadDailyForecast;

  WeatherViewModel({
    required CachedWeatherApiClient weatherApiClient,
    required WmoWeatherDescriptionMapper weatherDescriptionMapper,
    required WmoWeatherIconMapper weatherCodeIconMapper,
  }) : _weatherApiClient = weatherApiClient,
       _weatherDescriptionMapper = weatherDescriptionMapper,
       _weatherCodeIconMapper = weatherCodeIconMapper {
    loadCurrentForecast = Command1(_loadCurrentWeatherForecast);
    loadHourlyForecast = Command1(_loadHourlyWeatherForecast);
    loadDailyForecast = Command1(_loadDailyWeatherForecast);
  }

  var _currentTemperatureCelsius = '--.-';
  IconData _currentWeatherCodeIcon = Symbols.question_mark;
  var _currentWeatherDescription = 'Meteo sconosciuto';
  var _isDay = false;

  HourlyWeatherForecastData? _hourlyForecastData;
  DailyWeatherForecastData? _dailyForecastData;

  String get currentTemperatureCelsius => _currentTemperatureCelsius;
  IconData get currentWeatherCodeIcon => _currentWeatherCodeIcon;
  String get currentWeatherDescription => _currentWeatherDescription;
  bool get isDay => _isDay;

  /// The loaded hourly forecast data, or `null` if no successful load has
  /// completed yet (i.e. before [loadHourlyForecast] succeeds).
  HourlyWeatherForecastData? get getHourlyForecastData => _hourlyForecastData;

  /// The loaded daily forecast data, or `null` if no successful load has
  /// completed yet (i.e. before [loadDailyForecast] succeeds).
  DailyWeatherForecastData? get getDailyForecastData => _dailyForecastData;

  /// Fetches current weather for [coordinates] and updates the current
  /// conditions state. Returns the raw [Result] so callers can surface errors.
  Future<Result<CurrentWeatherForecastData>> _loadCurrentWeatherForecast(
    LatLng coordinates,
  ) async {
    final result = await _weatherApiClient.getCurrentWeatherByCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    );

    final data = result.getOrNull();
    if (data != null) {
      _currentTemperatureCelsius = data.temperature.toStringAsFixed(1);
      _currentWeatherDescription = _weatherDescriptionMapper.descriptionForCode(
        data.weatherCode,
      );
      _currentWeatherCodeIcon = _weatherCodeIconMapper.iconForCode(
        data.weatherCode,
        data.isDay == 1,
      );
      _isDay = data.isDay == 1;
    }

    return result;
  }

  /// Fetches hourly forecast for [coordinates] and stores it in
  /// [getHourlyForecastData]. Returns the raw [Result] so callers can surface
  /// errors.
  Future<Result<HourlyWeatherForecastData>> _loadHourlyWeatherForecast(
    LatLng coordinates,
  ) async {
    final result = await _weatherApiClient.getHourlyWeatherByCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    );

    final data = result.getOrNull();
    if (data != null) _hourlyForecastData = data;

    return result;
  }

  /// Fetches daily forecast for [coordinates] and stores it in
  /// [getDailyForecastData]. Returns the raw [Result] so callers can surface
  /// errors.
  Future<Result<DailyWeatherForecastData>> _loadDailyWeatherForecast(
    LatLng coordinates,
  ) async {
    final result = await _weatherApiClient.getDailyWeatherByCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    );

    final data = result.getOrNull();
    if (data != null) _dailyForecastData = data;

    return result;
  }
}
