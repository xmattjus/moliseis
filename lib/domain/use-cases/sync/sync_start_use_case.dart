import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/utils/result.dart';

class SyncStartUseCase {
  SyncStartUseCase({
    required AttractionRepository attractionRepository,
    required GalleryRepository galleryRepository,
    required PlaceRepository placeRepository,
    required SettingsRepository settingsRepository,
  }) : _attractionRepository = attractionRepository,
       _galleryRepository = galleryRepository,
       _placeRepository = placeRepository,
       _settingsRepository = settingsRepository;

  final AttractionRepository _attractionRepository;
  final GalleryRepository _galleryRepository;
  final PlaceRepository _placeRepository;
  final SettingsRepository _settingsRepository;

  Future<Result<void>> start() async {
    final results = await Future(
      () async => [
        await _attractionRepository.synchronize(),
        await _galleryRepository.synchronize(),
        await _placeRepository.synchronize(),
      ],
    );

    for (final result in results) {
      switch (result) {
        case Error<void>():
          return Result.error(result.error);
        case Success<void>():
      }
    }

    _settingsRepository.setModifiedAt(DateTime.now());

    return const Result.success(null);
  }
}
