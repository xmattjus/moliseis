import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUrlLauncher {
  final _log = Logger('AppUrlLauncher');

  final _mapTilerUrl = 'https://www.maptiler.com/copyright/';
  final _openStreetMapUrl = 'https://www.openstreetmap.org/copyright';
  final _googleMapsUrl = 'https://www.google.com/maps/search/?api=1';
  final _privacyPolicy =
      'https://sites.google.com/view/molise-is-privacy-policy/';
  final _termsOfService =
      'https://sites.google.com/view/molise-is-terms-of-service/';

  Future<bool> _launch(String url) async {
    // Whether [url] could be handled or not.
    var result = false;

    try {
      final uri = Uri.parse(url);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          result = true;
        } else {
          _log.severe('Could not handle $uri');
        }
      } on Exception catch (error) {
        _log.severe(error);
      }
    } on Exception catch (error) {
      // Logs any parsing error.
      _log.severe(error);
    }

    return result;
  }

  Future<bool> generic(String url) => _launch(url);

  /// Opens the MapTiler copyright web page with the default web browser app.
  Future<bool> mapTilerWebsite() => _launch(_mapTilerUrl);

  /// Opens the OpenStreetMap copyright web page with the default web browser
  /// app.
  Future<bool> openStreetMapWebsite() => _launch(_openStreetMapUrl);

  /// Opens the requested attraction in a Google Maps window.
  Future<bool> googleMaps(String attractionName, String? placeName) {
    return _launch(
      '$_googleMapsUrl&query=$attractionName, $placeName, Molise, Italia',
    );
  }

  /// Opens the app Privacy Policy web page.
  Future<bool> privacyPolicy() => _launch(_privacyPolicy);

  /// Opens the app Terms of Service web page.
  Future<bool> termsOfService() => _launch(_termsOfService);
}
