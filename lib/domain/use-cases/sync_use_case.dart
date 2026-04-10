import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Orchestrates synchronization of all local repositories with the backend.
///
/// Repositories are synced sequentially in dependency order: cities first,
/// then places, events, and media. Synchronization short-circuits on the first
/// error. On success, the last-synced timestamp is persisted via
/// [SettingsRepository].
class SyncUseCase {
  SyncUseCase({
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

  /// Synchronizes all repositories in sequence, short-circuiting on the first
  /// error.
  ///
  /// On success, records the current timestamp as the last successful sync
  /// time. Returns [Result.error] if any repository fails.
  Future<Result<void>> sync() async {
    for (final repo in [
      _cityRepository,
      _placeRepository,
      _eventRepository,
      _mediaRepository,
    ]) {
      final result = await repo.synchronize();

      if (result.isError) {
        return result;
      }
    }

    await _settingsRepository.setModifiedAt(DateTime.now());

    return const Result.success(null);
  }

  /// Whether synchronization is needed or not based on the last successful
  /// sync time.
  ///
  /// Synchronization is needed if more than 3 days have passed since the last
  /// successful synchronization, or if there was never a successful
  /// synchronization.
  bool get isSyncRequired {
    final lastSyncedAt = _settingsRepository.modifiedAt;

    if (lastSyncedAt != null) {
      final nextScheduledSync = lastSyncedAt.add(const Duration(days: 3));

      if (DateTime.now().isBefore(nextScheduledSync)) {
        return false;
      }
    }

    return true;
  }

  /// The timestamp of the last successful synchronization, or null if the app
  /// has never been synced.
  DateTime? get lastSyncedAt => _settingsRepository.modifiedAt;
}
