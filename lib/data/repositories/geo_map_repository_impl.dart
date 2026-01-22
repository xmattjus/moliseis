import 'package:moliseis/data/services/api/openstreetmap/openstreetmap_client.dart';
import 'package:moliseis/domain/repositories/geo_map_repository.dart';
import 'package:moliseis/utils/result.dart';

class GeoMapRepositoryImpl implements GeoMapRepository {
  final OpenStreetMapClient _openStreetMapClient;

  const GeoMapRepositoryImpl({required OpenStreetMapClient openStreetMapClient})
    : _openStreetMapClient = openStreetMapClient;

  @override
  Future<Result<String?>> getStreetAddreFromCoords(
    double latitude,
    double longitude,
  ) {
    return _openStreetMapClient.getAddressFromCoordinates(latitude, longitude);
  }
}
