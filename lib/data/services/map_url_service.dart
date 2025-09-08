import 'package:logging/logging.dart';
import 'package:moliseis/data/services/external_url_service.dart';
import 'package:moliseis/utils/result.dart';

/// Service responsible for handling map-related external URL launches,
/// including attribution pages and location searches.
class MapUrlService {
  MapUrlService({required ExternalUrlService externalUrlService})
    : _externalUrlService = externalUrlService;

  final _log = Logger('MapUrlService');
  final ExternalUrlService _externalUrlService;

  // Map service URLs
  static const _mapTilerUrl = 'https://www.maptiler.com/copyright/';
  static const _openStreetMapUrl = 'https://www.openstreetmap.org/copyright';
  static const _googleMapsBaseUrl = 'https://www.google.com/maps/search/?api=1';

  /// Opens the MapTiler copyright web page with the default web browser app.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> openMapTilerAttribution() {
    _log.info('Opening MapTiler attribution page');
    return _externalUrlService.launchGenericUrl(_mapTilerUrl);
  }

  /// Opens the OpenStreetMap copyright web page with the default web browser
  /// app.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> openOpenStreetMapAttribution() {
    _log.info('Opening OpenStreetMap attribution page');
    return _externalUrlService.launchGenericUrl(_openStreetMapUrl);
  }

  /// Opens the requested content in a Google Maps window.
  ///
  /// [contentName] The name of the location or content to search for.
  /// [cityName] The optional city name to include in the search.
  ///
  /// Returns a [Result] containing success or failure information.
  Future<Result<void>> searchInGoogleMaps(
    String contentName,
    String? cityName,
  ) {
    final query = cityName != null
        ? '$contentName, $cityName, Molise, Italia'
        : '$contentName, Molise, Italia';

    final searchUrl = '$_googleMapsBaseUrl&query=$query';

    _log.info('Opening Google Maps search for: $query');
    return _externalUrlService.launchGenericUrl(searchUrl);
  }
}
