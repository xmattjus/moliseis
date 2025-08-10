import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:moliseis/utils/result.dart';

class OpenStreetMapClient {
  OpenStreetMapClient();

  final _log = Logger('OpenStreetMapClient');

  Future<Result<String?>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=jsonv2&"
        "lat=$latitude&lon=$longitude",
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'com.benitomatteobercini.moliseis/1.0',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final address = jsonData['display_name'] as String?;
        return Result.success(address);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'An exception occurred while getting address from coordinates.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }
}
