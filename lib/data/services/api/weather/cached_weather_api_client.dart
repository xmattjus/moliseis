import 'package:flutter/foundation.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/location_key.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';

/// Wraps a weather API client with intelligent caching to reduce network
/// traffic and API quota consumption.
///
/// Weather conditions change infrequently, so caching responses for short
/// periods (2 hours) significantly reduces unnecessary API calls. Separate
/// caches for current, hourly, and daily forecasts prevent cache pollution and
/// optimize memory usage based on query frequency. A single API call fetches
/// all forecast types at once, and results are cached individually for later
/// reuse.
class CachedWeatherApiClient {
  final WeatherApiClient _weatherApiClient;
  final LruCache<
    String,
    WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
  >
  _currentWeatherCache;
  final LruCache<
    String,
    WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
  >
  _hourlyWeatherCache;
  final LruCache<
    String,
    WeatherForecastDataCacheEntry<DailyWeatherForecastData>
  >
  _dailyWeatherCache;

  static const _cacheDuration = Duration(hours: 2);

  const CachedWeatherApiClient({
    required WeatherApiClient weatherApiClient,
    required LruCache<
      String,
      WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
    >
    currentWeatherCache,
    required LruCache<
      String,
      WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
    >
    hourlyWeatherCache,
    required LruCache<
      String,
      WeatherForecastDataCacheEntry<DailyWeatherForecastData>
    >
    dailyWeatherCache,
  }) : _weatherApiClient = weatherApiClient,
       _currentWeatherCache = currentWeatherCache,
       _hourlyWeatherCache = hourlyWeatherCache,
       _dailyWeatherCache = dailyWeatherCache;

  /// Fetches combined weather data and caches all three forecast types.
  ///
  /// A single API call retrieves current, hourly, and daily forecasts to
  /// minimize network requests. Each forecast type is cached separately for
  /// independent retrieval later.
  Future<Result<CombinedWeatherForecastResponse>> _fetchAndCacheAll(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = LocationKey.from(latitude, longitude);
    final result = await _weatherApiClient.getCombinedWeatherForecast(
      latitude,
      longitude,
    );

    if (result is Success<CombinedWeatherForecastResponse>) {
      final fetchedAt = DateTime.now().toUtc();

      // Cache current weather.
      _currentWeatherCache.put(
        cacheKey,
        WeatherForecastDataCacheEntry(
          data: result.value.currentData,
          fetchedAt: fetchedAt,
          locationKey: cacheKey,
        ),
      );

      // Cache hourly weather.
      _hourlyWeatherCache.put(
        cacheKey,
        WeatherForecastDataCacheEntry(
          data: result.value.hourlyData,
          fetchedAt: fetchedAt,
          locationKey: cacheKey,
        ),
      );

      // Cache daily weather.
      _dailyWeatherCache.put(
        cacheKey,
        WeatherForecastDataCacheEntry(
          data: result.value.dailyData,
          fetchedAt: fetchedAt,
          locationKey: cacheKey,
        ),
      );

      debugPrint('Cache added for key: $cacheKey');
    }

    return result;
  }

  /// Retrieves current weather for coordinates, serving from cache when
  /// available.
  ///
  /// Checks the cache first to avoid network requests for recently queried
  /// locations. Stale entries are automatically evicted to ensure data
  /// freshness. If cache miss occurs, fetches all forecast types at once and
  /// caches them for future requests.
  Future<Result<CurrentWeatherForecastData>> getCurrentWeatherByCoordinates(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = LocationKey.from(latitude, longitude);
    final cachedEntry = _currentWeatherCache.get(cacheKey);

    if (cachedEntry != null) {
      if (!cachedEntry.isExpired(_cacheDuration)) {
        debugPrint('Cache hit for current weather key: $cacheKey');
        return Result.success(cachedEntry.data);
      } else {
        // Remove stale data.
        _currentWeatherCache.remove(cacheKey);
        debugPrint(
          'Cache stale for key: $cacheKey added at '
          '${cachedEntry.fetchedAt.toUtc()}',
        );
      }
    }

    // Fetch all forecasts from API if not cached.
    final result = await _fetchAndCacheAll(latitude, longitude);

    if (result is Success<CombinedWeatherForecastResponse>) {
      return Result.success(result.value.currentData);
    } else {
      return Result.error(Exception('Failed to fetch current weather data.'));
    }
  }

  /// Retrieves hourly weather for coordinates, serving from cache when
  /// available.
  ///
  /// Checks the cache first to avoid network requests for recently queried
  /// locations. Stale entries are automatically evicted to ensure data
  /// freshness. If cache miss occurs, fetches all forecast types at once and
  /// caches them for future requests.
  Future<Result<HourlyWeatherForecastData>> getHourlyWeatherByCoordinates(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = LocationKey.from(latitude, longitude);
    final cachedEntry = _hourlyWeatherCache.get(cacheKey);

    if (cachedEntry != null) {
      if (!cachedEntry.isExpired(_cacheDuration)) {
        debugPrint('Cache hit for hourly weather key: $cacheKey');
        return Result.success(cachedEntry.data);
      } else {
        // Remove stale data.
        _hourlyWeatherCache.remove(cacheKey);
        debugPrint(
          'Cache stale for key: $cacheKey added at '
          '${cachedEntry.fetchedAt.toUtc()}',
        );
      }
    }

    // Fetch all forecasts from API if not cached.
    final result = await _fetchAndCacheAll(latitude, longitude);

    if (result is Success<CombinedWeatherForecastResponse>) {
      return Result.success(result.value.hourlyData);
    } else {
      return Result.error(Exception('Failed to fetch hourly weather data.'));
    }
  }

  /// Retrieves daily weather for coordinates, serving from cache when
  /// available.
  ///
  /// Checks the cache first to avoid network requests for recently queried
  /// locations. Stale entries are automatically evicted to ensure data
  /// freshness. If cache miss occurs, fetches all forecast types at once and
  /// caches them for future requests.
  Future<Result<DailyWeatherForecastData>> getDailyWeatherByCoordinates(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = LocationKey.from(latitude, longitude);
    final cachedEntry = _dailyWeatherCache.get(cacheKey);

    if (cachedEntry != null) {
      if (!cachedEntry.isExpired(_cacheDuration)) {
        debugPrint('Cache hit for daily weather key: $cacheKey');
        return Result.success(cachedEntry.data);
      } else {
        // Remove stale data.
        _dailyWeatherCache.remove(cacheKey);
        debugPrint(
          'Cache stale for key: $cacheKey added at '
          '${cachedEntry.fetchedAt.toUtc()}',
        );
      }
    }

    // Fetch all forecasts from API if not cached.
    final result = await _fetchAndCacheAll(latitude, longitude);

    if (result is Success<CombinedWeatherForecastResponse>) {
      return Result.success(result.value.dailyData);
    } else {
      return Result.error(Exception('Failed to fetch daily weather data.'));
    }
  }
}
