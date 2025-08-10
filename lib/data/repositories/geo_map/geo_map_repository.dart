import 'package:moliseis/utils/result.dart';

abstract class GeoMapRepository {
  Future<Result<String?>> getStreetAddreFromCoords(
    double latitude,
    double longitude,
  );
}
