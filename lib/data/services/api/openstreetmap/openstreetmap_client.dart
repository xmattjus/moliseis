import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:moliseis/data/services/api/openstreetmap/model/geocoding_address.dart';
import 'package:moliseis/data/services/api/openstreetmap/model/reverse_geocoding_response.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

/// Uses OpenStreetMap Nominatim service for reverse geocoding.
class OpenStreetMapClient {
  OpenStreetMapClient({required Logger logger, required http.Client httpClient})
    : _logger = logger,
      _httpClient = httpClient;

  final Logger _logger;
  final http.Client _httpClient;

  Future<Result<String?>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    _logger.log(
      ReverseGeocodingFetchStarted(latitude: latitude, longitude: longitude),
    );

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&'
        'lat=$latitude&lon=$longitude',
      );

      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: kDefaultNetworkTimeoutSeconds));

      if (response.statusCode == 200) {
        final jsonData = ReverseGeocodingResponseMapper.fromMap(
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
      _logger.log(const NetworkRequestTimeout());
      return Result.error(error);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        ReverseGeocodingFetchFailed(latitude: latitude, longitude: longitude),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
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
