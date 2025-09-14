import 'package:moliseis/data/repositories/city/city_repository.dart';
import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/data/repositories/media/media_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/exceptions.dart';
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
    // A list of the repositories to synchronize with the backend.
    final repositoriesToSynchronize = [
      _cityRepository.synchronize(),
      _placeRepository.synchronize(),
      _eventRepository.synchronize(),
      _mediaRepository.synchronize(),
    ];

    for (int i = 0; i < repositoriesToSynchronize.length; i++) {
      final result = await repositoriesToSynchronize[i].timeout(
        const Duration(seconds: kDefaultNetworkTimeoutSeconds),
        onTimeout: () {
          return const Result.error(NetworkTimeoutException());
        },
      );

      if (result is Error) {
        return Result.error(result.error);
      }
    }

    // If all repositories synchronized successfully, update the last sync time.
    _settingsRepository.setModifiedAt(DateTime.now());

    return const Result.success(null);
  }

  DateTime? get lastSuccessfullSynchronization =>
      _settingsRepository.modifiedAt;
}
