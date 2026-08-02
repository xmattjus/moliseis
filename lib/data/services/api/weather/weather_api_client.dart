import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

/// Low-level HTTP client for fetching weather forecasts from Open-Meteo API.
///
/// This client handles network requests, timeout management, and error recovery
/// to provide reliable data access for the caching layer.
class WeatherApiClient {
  WeatherApiClient({required Logger logger, required http.Client httpClient})
    : _logger = logger,
      _httpClient = httpClient;

  final Logger _logger;
  final http.Client _httpClient;

  Uri _buildApiUri(
    double latitude,
    double longitude, {
    String timezone = 'Europe/Rome',
  }) {
    const daily =
        'weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max';

    const hourly =
        'temperature_2m,weather_code,precipitation_probability,'
        'is_day';

    const current = 'temperature_2m,is_day,weather_code,precipitation';

    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'daily': daily,
      'hourly': hourly,
      'current': current,
      'timezone': timezone,
    });
  }

  /// Fetches combined weather forecast (current, hourly, and daily) for a
  /// location with a single API call.
  ///
  /// Uses Open-Meteo's forecast endpoint to retrieve all weather data at once,
  /// reducing API quota consumption. Timezone defaults to Europe/Rome to
  /// provide locally-relevant time information. Network timeouts are enforced
  /// to prevent indefinite waiting and enable graceful fallback to cached data.
  Future<Result<CombinedWeatherForecastResponse>> getCombinedWeatherForecast(
    double latitude,
    double longitude, {
    String timezone = 'Europe/Rome',
  }) async {
    try {
      final uri = _buildApiUri(latitude, longitude, timezone: timezone);

      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: kDefaultNetworkTimeoutSeconds));

      if (response.statusCode == 200) {
        final jsonData = CombinedWeatherForecastResponseMapper.fromMap(
          jsonDecode(response.body) as Map<String, dynamic>,
        );

        return Result.success(jsonData);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on TimeoutException catch (error) {
      _logger.log(const NetworkRequestTimeout());
      return Result.error(error);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        WeatherForecastFetchFailed(latitude: latitude, longitude: longitude),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }
}
