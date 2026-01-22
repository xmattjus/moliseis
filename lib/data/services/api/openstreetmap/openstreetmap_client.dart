import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:moliseis/data/services/api/openstreetmap/geocoding_address.dart';
import 'package:moliseis/data/services/api/openstreetmap/reverse_geocoding_response.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/result.dart';

/// Uses OpenStreetMap Nominatim service for reverse geocoding.
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

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'com.benitomatteobercini.moliseis/2.0',
            },
          )
          .timeout(const Duration(seconds: kDefaultNetworkTimeoutSeconds));

      if (response.statusCode == 200) {
        final jsonData = ReverseGeocodingResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );

        final address = _formatAddressFromGeocodingData(
          jsonData.geocodingAddress,
        );

        return Result.success(address);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on TimeoutException catch (error) {
      _log.warning(const NetworkTimeoutException());
      return Result.error(error);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'An exception occurred while getting address from coordinates.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  String? _formatAddressFromGeocodingData(GeocodingAddress address) {
    var result = '';

    if (address.amenity != null) {
      result += '${address.amenity}, ';
    }

    if (address.road != null) {
      result += '${address.road}, ';
    }

    if (address.hamlet != null) {
      result += '${address.hamlet} ';
    } else if (address.village != null) {
      result += '${address.village} ';
    } else if (address.town != null) {
      result += '${address.town} ';
    }

    if (address.county.isNotEmpty) {
      result += '(${address.county})';
    }

    return result.isNotEmpty ? result : null;
  }
}
