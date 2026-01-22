/// Represents a cached weather forecast entry with expiration tracking.
///
/// Weather API responses are cached to reduce network requests and API quota
/// usage. Each entry tracks the fetch timestamp to enable intelligent cache
/// invalidation based on data freshness requirements.
class WeatherForecastDataCacheEntry<T> {
  final T data;
  final DateTime fetchedAt;
  final String locationKey;

  WeatherForecastDataCacheEntry({
    required this.data,
    required this.fetchedAt,
    required this.locationKey,
  });

  /// Determines if this cached entry has exceeded its maximum age threshold.
  ///
  /// Cache expiration prevents serving stale weather data that may no longer
  /// reflect current conditions. This method enables the cache layer to
  /// automatically refresh data when it becomes unreliable.
  bool isExpired(Duration maxAge) {
    final now = DateTime.now().toUtc();
    final fetchedUtc = fetchedAt.toUtc();
    return now.difference(fetchedUtc) > maxAge;
  }
}
