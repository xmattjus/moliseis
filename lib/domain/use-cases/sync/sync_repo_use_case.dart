import 'package:moliseis/data/repositories/city/city_repository.dart';
import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/data/repositories/media/media_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/utils/result.dart';

class SynchronizeRepositoriesUseCase {
  SynchronizeRepositoriesUseCase({
    required CityRepository cityRepository,
    required EventRepository eventRepository,
    required MediaRepository mediaRepository,
    required PlaceRepository placeRepository,
    required SettingsRepository settingsRepository,
  }) : _cityRepository = cityRepository,
       _eventRepository = eventRepository,
       _mediaRepository = mediaRepository,
       _placeRepository = placeRepository,
       _settingsRepository = settingsRepository;

  final CityRepository _cityRepository;
  final EventRepository _eventRepository;
  final MediaRepository _mediaRepository;
  final PlaceRepository _placeRepository;
  final SettingsRepository _settingsRepository;

  Future<Result<void>> start() async {
    // The number of synchronization tasks to execute.
    const syncTasks = 4;

    for (int i = 0; i < syncTasks; i++) {
      final result = switch (i) {
        0 => await _cityRepository.synchronize(),
        1 => await _placeRepository.synchronize(),
        2 => await _eventRepository.synchronize(),
        3 => await _mediaRepository.synchronize(),
        int() => UnimplementedError(),
      };
      if (result is Error) {
        return Result.error(result.error);
      }
    }

    _settingsRepository.setModifiedAt(DateTime.now());

    return const Result.success(null);
  }

  DateTime? get lastSuccessfullSynchronization =>
      _settingsRepository.modifiedAt;
}
