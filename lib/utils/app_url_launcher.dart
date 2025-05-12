import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUrlLauncher {
  final _mapTilerUrl = 'https://www.maptiler.com/copyright/';
  final _openStreetMapUrl = 'https://www.openstreetmap.org/copyright';
  final _googleMapsUrl = 'https://www.google.com/maps/search/?api=1';
  final _logger = Logger('AppUrlLauncher');

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
          _logger.severe('Could not handle $uri');
        }
      } on Exception catch (error) {
        _logger.severe(error);
      }
    } on Exception catch (error) {
      // Logs any parsing error.
      _logger.severe(error);
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
}
