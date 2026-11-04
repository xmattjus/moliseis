import 'dart:async';
import 'dart:core' as core;
import 'dart:core';

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
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/logging/run_traced_result.dart';
import 'package:moliseis/utils/result.dart';

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
    required Logger logger,
    required CityRepository cityRepository,
    required EventRepository eventRepository,
    required MediaRepository mediaRepository,
    required PlaceRepository placeRepository,
    required SettingsRepository settingsRepository,
    required SyncTransactionCoordinator transactionCoordinator,
    required SyncCursorSource cursorSource,
    DateTime Function()? now,
  }) : _logger = logger,
       _cityRepository = cityRepository,
       _eventRepository = eventRepository,
       _mediaRepository = mediaRepository,
       _placeRepository = placeRepository,
       _settingsRepository = settingsRepository,
       _transactionCoordinator = transactionCoordinator,
       _cursorSource = cursorSource,
       _now = now ?? DateTime.now;

  final Logger _logger;
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
  Future<Result<void>> sync() => runTracedResult('sync', _sync);

  Future<Result<void>> _sync() async {
    final clock = Stopwatch()..start();
    final cursor = _settingsRepository.contentSyncCursorAt;
    final mode = cursor == null ? SyncMode.bootstrap : SyncMode.delta;
    var phase = SyncPhase.cursor;
    var succeeded = false;
    SyncFailureCategory? category;
    int? cityFetched;
    int? placeFetched;
    int? eventFetched;
    int? mediaFetched;
    _logger.log(SyncStarted(mode));
    try {
      // Observe U before any fetch; it is not a transactional snapshot.
      final cursorResult = await _cursorSource.getCurrentCursor();
      final DateTime serverCursor;
      switch (cursorResult) {
        case Success(:final value):
          serverCursor = value.toUtc();
        case Error(:final error):
          category = syncFailureCategory(error);
          return Result.error(error);
      }
      final lowerBound = cursor?.toUtc().subtract(syncOverlap);
      phase = SyncPhase.prepare_city;
      final (
        Result<List<CityDto>>,
        Result<List<PlaceDto>>,
        Result<List<EventDto>>,
        Result<List<MediaDto>>,
      )
      prepared;
      try {
        prepared = await (
          _cityRepository.prepareSync(modifiedAtOrAfter: lowerBound),
          _placeRepository.prepareSync(modifiedAtOrAfter: lowerBound),
          _eventRepository.prepareSync(modifiedAtOrAfter: lowerBound),
          _mediaRepository.prepareSync(modifiedAtOrAfter: lowerBound),
        ).wait;
        // Positional join errors must retain each original throwable and stack.
        // ignore: avoid_catching_errors
      } on ParallelWaitError<
        (
          Result<List<CityDto>>?,
          Result<List<PlaceDto>>?,
          Result<List<EventDto>>?,
          Result<List<MediaDto>>?,
        ),
        (AsyncError?, AsyncError?, AsyncError?, AsyncError?)
      > catch (error) {
        final values = error.values;
        cityFetched = values.$1?.getOrNull()?.length;
        placeFetched = values.$2?.getOrNull()?.length;
        eventFetched = values.$3?.getOrNull()?.length;
        mediaFetched = values.$4?.getOrNull()?.length;
        final errors = error.errors;
        // Record.wait preserves positional provenance and the original stacks.
        for (final (failedPhase, failure) in [
          (SyncPhase.prepare_city, errors.$1),
          (SyncPhase.prepare_place, errors.$2),
          (SyncPhase.prepare_event, errors.$3),
          (SyncPhase.prepare_media, errors.$4),
        ]) {
          if (failure != null) {
            phase = failedPhase;
            core.Error.throwWithStackTrace(failure.error, failure.stackTrace);
          }
        }
        rethrow;
      }
      final (cityResult, placeResult, eventResult, mediaResult) = prepared;
      cityFetched = cityResult.getOrNull()?.length;
      placeFetched = placeResult.getOrNull()?.length;
      eventFetched = eventResult.getOrNull()?.length;
      mediaFetched = mediaResult.getOrNull()?.length;
      for (final (failedPhase, result) in [
        (SyncPhase.prepare_city, cityResult),
        (SyncPhase.prepare_place, placeResult),
        (SyncPhase.prepare_event, eventResult),
        (SyncPhase.prepare_media, mediaResult),
      ]) {
        if (result case Error(:final error)) {
          phase = failedPhase;
          category = syncFailureCategory(error);
          return Result.error(error);
        }
      }
      final cityDtos = (cityResult as Success<List<CityDto>>).value;
      final placeDtos = (placeResult as Success<List<PlaceDto>>).value;
      final eventDtos = (eventResult as Success<List<EventDto>>).value;
      final mediaDtos = (mediaResult as Success<List<MediaDto>>).value;
      phase = SyncPhase.commit;
      final commitResult = _transactionCoordinator.runInWriteTransaction(() {
        final cityCommit = _cityRepository.commitSync(cityDtos);
        if (cityCommit.isError) return cityCommit;
        final placeCommit = _placeRepository.commitSync(placeDtos);
        if (placeCommit.isError) return placeCommit;
        final eventCommit = _eventRepository.commitSync(eventDtos);
        if (eventCommit.isError) return eventCommit;
        return _mediaRepository.commitSync(mediaDtos);
      });
      if (commitResult case Error(:final error)) {
        category = syncFailureCategory(error);
        return commitResult;
      }
      _logger.log(const SyncContentCommitSucceeded());
      phase = SyncPhase.settings;
      final settingsResult = await _settingsRepository.setSyncState(
        lastSyncedAt: _now(),
        contentSyncCursorAt: serverCursor,
      );
      if (settingsResult case Error(:final error)) {
        category = syncFailureCategory(error);
        return settingsResult;
      }
      succeeded = true;
      return const Result.success(null);
    } catch (error) {
      category = syncFailureCategory(error);
      rethrow;
    } finally {
      clock.stop();
      _logger.log(
        SyncFinished(
          mode: mode,
          phase: phase,
          succeeded: succeeded,
          elapsedMs: clock.elapsedMilliseconds,
          cityFetched: cityFetched,
          placeFetched: placeFetched,
          eventFetched: eventFetched,
          mediaFetched: mediaFetched,
          category: category,
        ),
      );
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
