import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/domain/models/place/place.dart';

class PlaceViewModel {
  final PlaceRepository _placeRepository;

  PlaceViewModel({required PlaceRepository placeRepository})
    : _placeRepository = placeRepository;

  Future<Place> getPlaceFromAttractionId(int id) {
    return _placeRepository.getPlaceFromAttractionId(id);
  }
}
