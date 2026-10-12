import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/core/sync_cursor_source.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Safety window for request-scoped canonical writes becoming visible late.
///
/// This is an operational overlap, not a commit-order guarantee.
const syncOverlap = Duration(hours: 24);

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
    required SyncCursorSource cursorSource,
    DateTime Function()? now,
  }) : _cityRepository = cityRepository,
       _eventRepository = eventRepository,
       _mediaRepository = mediaRepository,
       _placeRepository = placeRepository,
       _settingsRepository = settingsRepository,
       _transactionCoordinator = transactionCoordinator,
       _cursorSource = cursorSource,
       _now = now ?? DateTime.now;

  final CityRepository _cityRepository;
  final EventRepository _eventRepository;
  final MediaRepository _mediaRepository;
  final PlaceRepository _placeRepository;
  final SettingsRepository _settingsRepository;
  final SyncTransactionCoordinator _transactionCoordinator;
  final SyncCursorSource _cursorSource;
  final DateTime Function() _now;

  /// Synchronizes all repositories using a two-phase protocol.
  ///
  /// **Phase 1** – Fetches remote DTOs from all 4 repositories concurrently.
  /// **Phase 2** – Commits all DTOs atomically inside a single write
  /// transaction.
  ///
  /// Saves the pre-fetch server cursor only after content commit, together with
  /// the completion time. A settings failure leaves committed content available
  /// for harmless replay from the previous cursor and returns [Result.error].
  Future<Result<void>> sync() async {
    final transaction = Sentry.startTransaction(
      'sync',
      'task',
      bindToScope: true,
    );

    var spanStatus = const SpanStatus.internalError();

    try {
      // Observe U before any fetch; it is not a transactional snapshot.
      final cursor = _settingsRepository.contentSyncCursorAt;
      final cursorResult = await _cursorSource.getCurrentCursor();
      final DateTime serverCursor;
      switch (cursorResult) {
        case Success(:final value):
          serverCursor = value.toUtc();
        case Error(:final error):
          return Result.error(error);
      }
      final lowerBound = cursor?.toUtc().subtract(syncOverlap);

      // Phase 1: fetch all remote data concurrently, even when U equals C.
      final (cityResult, placeResult, eventResult, mediaResult) = await (
        _cityRepository.prepareSync(modifiedAtOrAfter: lowerBound),
        _placeRepository.prepareSync(modifiedAtOrAfter: lowerBound),
        _eventRepository.prepareSync(modifiedAtOrAfter: lowerBound),
        _mediaRepository.prepareSync(modifiedAtOrAfter: lowerBound),
      ).wait;

      final List<CityDto> cityDtos;
      switch (cityResult) {
        case Success(:final value):
          cityDtos = value;
        case Error(:final error):
          spanStatus = const SpanStatus.internalError();
          return Result.error(error);
      }

      final List<PlaceDto> placeDtos;
      switch (placeResult) {
        case Success(:final value):
          placeDtos = value;
        case Error(:final error):
          spanStatus = const SpanStatus.internalError();
          return Result.error(error);
      }

      final List<EventDto> eventDtos;
      switch (eventResult) {
        case Success(:final value):
          eventDtos = value;
        case Error(:final error):
          spanStatus = const SpanStatus.internalError();
          return Result.error(error);
      }

      final List<MediaDto> mediaDtos;
      switch (mediaResult) {
        case Success(:final value):
          mediaDtos = value;
        case Error(:final error):
          spanStatus = const SpanStatus.internalError();
          return Result.error(error);
      }

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

      final settingsResult = await _settingsRepository.setSyncState(
        lastSyncedAt: _now(),
        contentSyncCursorAt: serverCursor,
      );
      if (settingsResult.isError) return settingsResult;
      spanStatus = const SpanStatus.ok();
      return const Result.success(null);
    } finally {
      await transaction.finish(status: spanStatus);
    }
  }

  /// Whether synchronization is needed or not based on the last successful
  /// sync time.
  ///
  /// An absent content cursor forces bootstrap immediately. Otherwise
  /// synchronization is needed if at least 3 days have passed since the last
  /// successful synchronization, or if there was never a successful
  /// synchronization.
  bool get isSyncRequired {
    if (_settingsRepository.contentSyncCursorAt == null) return true;
    final lastSyncedAt = _settingsRepository.lastSyncedAt;

    if (lastSyncedAt != null) {
      final nextScheduledSync = lastSyncedAt.add(const Duration(days: 3));

      if (_now().isBefore(nextScheduledSync)) {
        return false;
      }
    }

    return true;
  }

  /// The timestamp of the last successful synchronization, or null if the app
  /// has never been synced.
  DateTime? get lastSyncedAt => _settingsRepository.lastSyncedAt;
}
