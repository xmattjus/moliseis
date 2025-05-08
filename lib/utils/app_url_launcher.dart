import 'package:url_launcher/url_launcher.dart';

class AppUrlLauncher {
  final String _mapTilerUrl = 'https://www.maptiler.com/copyright/';

  final String _openStreetMapUrl = 'https://www.openstreetmap.org/copyright';

  final String _googleMapsUrl = 'https://www.google.com/maps/search/?api=1';

  Future<bool> _launch(String url) async {
    Uri? uri;
    var result = false;

    try {
      uri = Uri.parse(url);
    } catch (err) {
      throw 'Could not parse a valid URI, $err';
    }

    try {
      if (await canLaunchUrl(uri)) {
        result = true;
        await launchUrl(uri);
      } else {
        throw 'Could not launch $uri';
      }
    } catch (err) {
      throw '$err';
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
