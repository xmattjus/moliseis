/// Utility class for generating consistent location keys from geographic coordinates.
///
/// Coordinates are intentionally rounded to 2 decimal places (~1.1km precision)
/// to enable effective caching of weather API responses. This reduces redundant
/// API calls for nearby locations while maintaining acceptable accuracy for
/// regional weather data.
class LocationKey {
  const LocationKey._();

  /// Generates a standardized location key from latitude and longitude.
  ///
  /// The coordinates are rounded to 2 decimal places to balance between precision and
  /// cache effectiveness. This ensures that users querying nearby locations retrieve
  /// cached results instead of triggering new API requests.
  static String from(double latitude, double longitude) {
    final lat = latitude.toStringAsFixed(2);
    final lon = longitude.toStringAsFixed(2);
    return '$lat,$lon';
  }
}
