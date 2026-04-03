import 'package:moliseis/data/services/app_info_service.dart';
import 'package:moliseis/data/services/external_url_service.dart';
import 'package:moliseis/data/services/map_url_service.dart';
import 'package:moliseis/utils/result.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Unified service for launching URLs and opening app information pages.
///
/// A [Talker] logger is required so the composed services share the same
/// logging pipeline. Optional overrides are available for tests.
class UrlLaunchService {
  /// Creates a URL launching facade.
  ///
  /// Unspecified services are created with the provided [logger].
  factory UrlLaunchService({
    required Talker logger,
    ExternalUrlService? externalUrlService,
    AppInfoService? appInfoService,
    MapUrlService? mapUrlService,
  }) {
    final resolvedExternalUrlService =
        externalUrlService ?? ExternalUrlService(logger: logger);

    return UrlLaunchService._(
      externalUrlService: resolvedExternalUrlService,
      appInfoService:
          appInfoService ??
          AppInfoService(
            logger: logger,
            externalUrlService: resolvedExternalUrlService,
          ),
      mapUrlService:
          mapUrlService ??
          MapUrlService(
            logger: logger,
            externalUrlService: resolvedExternalUrlService,
          ),
    );
  }

  UrlLaunchService._({
    required ExternalUrlService externalUrlService,
    required AppInfoService appInfoService,
    required MapUrlService mapUrlService,
  }) : _externalUrlService = externalUrlService,
       _appInfoService = appInfoService,
       _mapUrlService = mapUrlService;

  final ExternalUrlService _externalUrlService;
  final AppInfoService _appInfoService;
  final MapUrlService _mapUrlService;

  /// Launches a generic URL.
  ///
  /// Returns true if the URL was successfully launched, false otherwise.
  Future<bool> launchGenericUrl(String url) async {
    final result = await _externalUrlService.launchGenericUrl(url);
    return switch (result) {
      Success() => true,
      Error() => false,
    };
  }

  /// Opens the MapTiler copyright web page.
  ///
  /// Returns true if the page was successfully opened, false otherwise.
  Future<bool> openMapTilerWebsite() async {
    final result = await _mapUrlService.openMapTilerAttribution();
    return switch (result) {
      Success() => true,
      Error() => false,
    };
  }

  /// Opens the OpenStreetMap copyright web page.
  ///
  /// Returns true if the page was successfully opened, false otherwise.
  Future<bool> openOpenStreetMapWebsite() async {
    final result = await _mapUrlService.openOpenStreetMapAttribution();
    return switch (result) {
      Success() => true,
      Error() => false,
    };
  }

  /// Opens the requested content in a Google Maps window.
  ///
  /// [contentName] The name of the location or content to search for.
  /// [cityName] The optional city name to include in the search.
  ///
  /// Returns true if Google Maps was successfully opened, false otherwise.
  Future<bool> openGoogleMaps(String contentName, String? cityName) async {
    final result = await _mapUrlService.searchInGoogleMaps(
      contentName,
      cityName,
    );
    return switch (result) {
      Success() => true,
      Error() => false,
    };
  }

  /// Opens the app Privacy Policy web page.
  ///
  /// Returns true if the page was successfully opened, false otherwise.
  Future<bool> openPrivacyPolicy() async {
    final result = await _appInfoService.openPrivacyPolicy();
    return switch (result) {
      Success() => true,
      Error() => false,
    };
  }

  /// Opens the app Terms of Service web page.
  ///
  /// Returns true if the page was successfully opened, false otherwise.
  Future<bool> openTermsOfService() async {
    final result = await _appInfoService.openTermsOfService();
    return switch (result) {
      Success() => true,
      Error() => false,
    };
  }
}
