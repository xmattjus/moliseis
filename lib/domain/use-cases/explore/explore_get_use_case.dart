import 'package:meta/meta.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/utils/result.dart';

@immutable
class AttractionUiState {
  const AttractionUiState({this.attraction, this.molisImage, this.place});
  final Attraction? attraction;
  final MolisImage? molisImage;
  final Place? place;
}

class ExploreGetUseCase {
  ExploreGetUseCase({
    required AttractionRepository attractionRepository,
    required GalleryRepository galleryRepository,
    required PlaceRepository placeRepository,
  }) : _attractionRepository = attractionRepository,
       _galleryRepository = galleryRepository,
       _placeRepository = placeRepository;

  final AttractionRepository _attractionRepository;
  final GalleryRepository _galleryRepository;
  final PlaceRepository _placeRepository;

  Future<Result<AttractionUiState>> getById(int id) async {
    final attractionResult = await _attractionRepository.getById(id);
    final imagesResult = await _galleryRepository.getImagesFromAttractionId(id);
    final placeResult = await _placeRepository.getPlaceFromAttractionId(id);

    Attraction? attraction;
    MolisImage? image;
    Place? place;

    switch (attractionResult) {
      case Success<Attraction>():
        attraction = attractionResult.value;
      case Error<Attraction>():
      // TODO: Handle this case.
    }

    switch (imagesResult) {
      case Success<List<MolisImage>>():
        image = imagesResult.value.first;
      case Error<List<MolisImage>>():
      // TODO: Handle this case.
    }

    switch (placeResult) {
      case Place():
        place = placeResult;
      // case Error<Place>():
      // TODO: Handle this case.
    }

    return Result.success(
      AttractionUiState(
        attraction: attraction,
        molisImage: image,
        place: place,
      ),
    );
  }
}
