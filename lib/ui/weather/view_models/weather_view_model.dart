import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// The content identity and coordinates shared by all forecast lanes.
typedef WeatherTarget = ({
  int id,
  ContentType type,
  double latitude,
  double longitude,
});

class WeatherViewModel extends ChangeNotifier {
  WeatherViewModel({
    required CachedWeatherApiClient weatherApiClient,
    required WmoWeatherDescriptionMapper weatherDescriptionMapper,
    required WmoWeatherIconMapper weatherCodeIconMapper,
  }) : _weatherApiClient = weatherApiClient,
       _weatherDescriptionMapper = weatherDescriptionMapper,
       _weatherCodeIconMapper = weatherCodeIconMapper {
    loadCurrentForecast = RestartableCommand(
      _loadCurrentWeatherForecast,
      debugName: 'weather.current',
    );
    loadHourlyForecast = RestartableCommand(
      _loadHourlyWeatherForecast,
      debugName: 'weather.hourly',
    );
    loadDailyForecast = RestartableCommand(
      _loadDailyWeatherForecast,
      debugName: 'weather.daily',
    );
    loadCurrentForecast.results.addListener(_commitCurrent);
    loadHourlyForecast.results.addListener(_commitHourly);
    loadDailyForecast.results.addListener(_commitDaily);
  }

  final CachedWeatherApiClient _weatherApiClient;
  final WmoWeatherDescriptionMapper _weatherDescriptionMapper;
  final WmoWeatherIconMapper _weatherCodeIconMapper;
  bool _disposed = false;

  WeatherTarget? _currentTarget;
  WeatherTarget? get currentTarget => _currentTarget;
  bool get isDisposed => _disposed;

  /// Binds all lanes synchronously; only the containing screen writes this.
  void setTarget(WeatherTarget? target) {
    if (_disposed || _currentTarget == target) return;
    _currentTarget = target;
    _currentTemperatureCelsius = '--.-';
    _currentWeatherCodeIcon = Symbols.question_mark;
    _currentWeatherDescription = 'Meteo sconosciuto';
    _isDay = false;
    _hourlyForecastData = null;
    _dailyForecastData = null;
    loadCurrentForecast.invalidate();
    if (_disposed || _currentTarget != target) return;
    loadHourlyForecast.invalidate();
    if (_disposed || _currentTarget != target) return;
    loadDailyForecast.invalidate();
  }

  bool _accepts(WeatherTarget target) => !_disposed && _currentTarget == target;

  void requestCurrent(WeatherTarget target, {bool retry = false}) {
    if (!_accepts(target) || loadCurrentForecast.isRunningSync.value) return;
    final snapshot = loadCurrentForecast.results.value;
    if (!retry && snapshot.paramData == target && !snapshot.idle) return;
    loadCurrentForecast.run(target);
  }

  void requestHourly(WeatherTarget target, {bool retry = false}) {
    if (!_accepts(target) || loadHourlyForecast.isRunningSync.value) return;
    final snapshot = loadHourlyForecast.results.value;
    if (!retry && snapshot.paramData == target && !snapshot.idle) return;
    loadHourlyForecast.run(target);
  }

  void requestDaily(WeatherTarget target, {bool retry = false}) {
    if (!_accepts(target) || loadDailyForecast.isRunningSync.value) return;
    final snapshot = loadDailyForecast.results.value;
    if (!retry && snapshot.paramData == target && !snapshot.idle) return;
    loadDailyForecast.run(target);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    loadCurrentForecast.results.removeListener(_commitCurrent);
    loadHourlyForecast.results.removeListener(_commitHourly);
    loadDailyForecast.results.removeListener(_commitDaily);
    loadCurrentForecast.dispose();
    loadHourlyForecast.dispose();
    loadDailyForecast.dispose();
    super.dispose();
  }

  late final RestartableCommand<WeatherTarget, CurrentWeatherForecastData>
  loadCurrentForecast;
  late final RestartableCommand<WeatherTarget, HourlyWeatherForecastData>
  loadHourlyForecast;
  late final RestartableCommand<WeatherTarget, DailyWeatherForecastData>
  loadDailyForecast;

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

  void _commitCurrent() {
    final snapshot = loadCurrentForecast.results.value;
    if (_disposed ||
        snapshot.paramData != _currentTarget ||
        !snapshot.completed ||
        loadCurrentForecast.isRunningSync.value) {
      return;
    }
    final data = snapshot.data!.getOrNull()!;
    _currentTemperatureCelsius = data.temperature2m.toStringAsFixed(1);
    _currentWeatherDescription = _weatherDescriptionMapper.descriptionForCode(
      data.weatherCode,
    );
    _currentWeatherCodeIcon = _weatherCodeIconMapper.iconForCode(
      data.weatherCode,
      data.isDay == 1,
    );
    _isDay = data.isDay == 1;
  }

  void _commitHourly() {
    final snapshot = loadHourlyForecast.results.value;
    if (_disposed ||
        snapshot.paramData != _currentTarget ||
        !snapshot.completed ||
        loadHourlyForecast.isRunningSync.value) {
      return;
    }
    _hourlyForecastData = snapshot.data!.getOrNull();
  }

  void _commitDaily() {
    final snapshot = loadDailyForecast.results.value;
    if (_disposed ||
        snapshot.paramData != _currentTarget ||
        !snapshot.completed ||
        loadDailyForecast.isRunningSync.value) {
      return;
    }
    _dailyForecastData = snapshot.data!.getOrNull();
  }

  Future<Result<CurrentWeatherForecastData>> _loadCurrentWeatherForecast(
    WeatherTarget target,
  ) => _weatherApiClient.getCurrentWeatherByCoordinates(
    target.latitude,
    target.longitude,
  );

  Future<Result<HourlyWeatherForecastData>> _loadHourlyWeatherForecast(
    WeatherTarget target,
  ) => _weatherApiClient.getHourlyWeatherByCoordinates(
    target.latitude,
    target.longitude,
  );

  Future<Result<DailyWeatherForecastData>> _loadDailyWeatherForecast(
    WeatherTarget target,
  ) => _weatherApiClient.getDailyWeatherByCoordinates(
    target.latitude,
    target.longitude,
  );
}
