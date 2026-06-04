import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Orchestrates synchronization of all local repositories with the backend.
///
/// Sync uses a two-phase approach:
/// 1. All repositories fetch remote data concurrently (Phase 1).
/// 2. All fetched DTOs are committed atomically inside a single write
///    transaction (Phase 2).
///
/// This ensures cross-repository atomicity: either all repos are written or
/// none are.
class SyncUseCase {
  SyncUseCase({
    required CityRepository cityRepository,
    required EventRepository eventRepository,
    required MediaRepository mediaRepository,
    required PlaceRepository placeRepository,
    required SettingsRepository settingsRepository,
    required SyncTransactionCoordinator transactionCoordinator,
  }) : _cityRepository = cityRepository,
       _eventRepository = eventRepository,
       _mediaRepository = mediaRepository,
       _placeRepository = placeRepository,
       _settingsRepository = settingsRepository,
       _transactionCoordinator = transactionCoordinator;

  final CityRepository _cityRepository;
  final EventRepository _eventRepository;
  final MediaRepository _mediaRepository;
  final PlaceRepository _placeRepository;
  final SettingsRepository _settingsRepository;
  final SyncTransactionCoordinator _transactionCoordinator;

  /// Synchronizes all repositories using a two-phase protocol.
  ///
  /// **Phase 1** – Fetches remote DTOs from all 4 repositories concurrently.
  /// **Phase 2** – Commits all DTOs atomically inside a single write
  /// transaction.
  ///
  /// On success, records the current timestamp as the last successful sync
  /// time. Returns [Result.error] if any phase fails.
  Future<Result<void>> sync() async {
    final transaction = Sentry.startTransaction(
      'sync',
      'task',
      bindToScope: true,
    );

    var spanStatus = const SpanStatus.internalError();

    try {
      // Phase 1: fetch all remote data concurrently
      final cityResult = _cityRepository.prepareSync();
      final placeResult = _placeRepository.prepareSync();
      final eventResult = _eventRepository.prepareSync();
      final mediaResult = _mediaRepository.prepareSync();

      final results = await Future.wait([
        cityResult,
        placeResult,
        eventResult,
        mediaResult,
      ]);

      for (final result in results) {
        switch (result) {
          case Error<List<SyncDto>>():
            spanStatus = const SpanStatus.internalError();
            return Result.error(result.error);
          case Success<List<SyncDto>>():
        }
      }

      final cityDtos = (results[0] as Success<List<SyncDto>>).value;
      final placeDtos = (results[1] as Success<List<SyncDto>>).value;
      final eventDtos = (results[2] as Success<List<SyncDto>>).value;
      final mediaDtos = (results[3] as Success<List<SyncDto>>).value;

      // Phase 2: commit all repos in a single write transaction,
      // short-circuiting on the first commit error
      final commitResult = _transactionCoordinator.runInWriteTransaction(() {
        final cityCommit = _cityRepository.commitSync(cityDtos);
        if (cityCommit.isError) return cityCommit;

        final placeCommit = _placeRepository.commitSync(placeDtos);
        if (placeCommit.isError) return placeCommit;

        final eventCommit = _eventRepository.commitSync(eventDtos);
        if (eventCommit.isError) return eventCommit;

        final mediaCommit = _mediaRepository.commitSync(mediaDtos);
        if (mediaCommit.isError) return mediaCommit;

        return const Result.success(null);
      });

      if (commitResult.isError) {
        spanStatus = const SpanStatus.internalError();
        return commitResult;
      }

      await _settingsRepository.setModifiedAt(DateTime.now());
      spanStatus = const SpanStatus.ok();
      return const Result.success(null);
    } finally {
      await transaction.finish(status: spanStatus);
    }
  }

  /// Whether synchronization is needed or not based on the last successful
  /// sync time.
  ///
  /// Synchronization is needed if more than 3 days have passed since the last
  /// successful synchronization, or if there was never a successful
  /// synchronization.
  bool get isSyncRequired {
    final lastSyncedAt = _settingsRepository.lastSyncedAt;

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
  DateTime? get lastSyncedAt => _settingsRepository.lastSyncedAt;
}
