import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/domain/use-cases/post/post_use_case.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class WeatherViewModel extends ChangeNotifier {
  final PostUseCase _postUseCase;
  final WmoWeatherDescriptionMapper _weatherDescriptionMapper;
  final WmoWeatherIconMapper _weatherCodeIconMapper;

  late Command1<void, LatLng> loadCurrentForecast;
  late Command1<void, LatLng> loadHourlyForecast;
  late Command1<void, LatLng> loadDailyForecast;

  WeatherViewModel({
    required PostUseCase postUseCase,
    required WmoWeatherDescriptionMapper weatherDescriptionMapper,
    required WmoWeatherIconMapper weatherCodeIconMapper,
  }) : _postUseCase = postUseCase,
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

  HourlyWeatherForecastData? get getHourlyForecastData => _hourlyForecastData;

  DailyWeatherForecastData? get getDailyForecastData => _dailyForecastData;

  Future<Result<void>> _loadCurrentWeatherForecast(LatLng coordinates) async {
    final result = await _postUseCase.getCurrentWeatherForecast(
      coordinates.latitude,
      coordinates.longitude,
    );

    if (result is Success<CurrentWeatherForecastData>) {
      _currentTemperatureCelsius = result.value.temperature.toStringAsFixed(1);
      _currentWeatherDescription = _weatherDescriptionMapper.descriptionForCode(
        result.value.weatherCode,
      );
      _currentWeatherCodeIcon = _weatherCodeIconMapper.iconForCode(
        result.value.weatherCode,
        result.value.isDay == 1,
      );
      _isDay = result.value.isDay == 1;
    }

    return const Result.success(null);
  }

  Future<Result<void>> _loadHourlyWeatherForecast(LatLng coordinates) async {
    final result = await _postUseCase.getHourlyWeatherForecast(
      coordinates.latitude,
      coordinates.longitude,
    );

    if (result is Success<HourlyWeatherForecastData>) {
      _hourlyForecastData = result.value;
    }

    return const Result.success(null);
  }

  Future<Result<void>> _loadDailyWeatherForecast(LatLng coordinates) async {
    final result = await _postUseCase.getDailyWeatherForecast(
      coordinates.latitude,
      coordinates.longitude,
    );

    if (result is Success<DailyWeatherForecastData>) {
      _dailyForecastData = result.value;
    }

    return const Result.success(null);
  }
}
