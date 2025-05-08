import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/utils/result.dart';

abstract class PlaceRepository {
  Future<Place> getPlaceFromAttractionId(int id);

  Future<Result<void>> synchronize();
}
