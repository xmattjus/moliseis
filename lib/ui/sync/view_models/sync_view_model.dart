import 'dart:async' show Future;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/use-cases/sync/sync_repo_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

/// Manages the synchronization state of the app repositories.
///
/// This ViewModel handles the synchronization of local repositories with the backend,
/// including automatic sync scheduling, error handling, and state management.
///
/// The sync operation is automatically triggered on startup if needed (based on
/// last successful sync time), and can be manually triggered with force option.
class SyncViewModel extends ChangeNotifier {
  /// Creates a new [SyncViewModel] instance.
  ///
  /// [syncRepoUseCase] is required for performing the actual synchronization.
  /// The constructor will automatically start sync if it's needed based on
  /// the last successful synchronization time.
  SyncViewModel({required SynchronizeRepositoriesUseCase syncRepoUseCase})
    : _useCase = syncRepoUseCase {
    sync = Command1(_sync);

    if (_syncNeeded()) {
      sync.execute(false);
    }
  }

  final SynchronizeRepositoriesUseCase _useCase;

  var _fatalError = false;

  /// Whether a fatal error occurred while synchronizing the repositories or not.
  ///
  /// A fatal error is one that occurs when there's no previous successful
  /// synchronization, meaning the app has no cached data to fall back on.
  bool get fatalError => _fatalError;

  /// Command for executing the synchronization operation.
  ///
  /// Takes a boolean parameter to indicate whether to force sync regardless
  /// of the last synchronization time.
  late Command1<void, bool> sync;

  /// Determines if synchronization is needed based on the last successful sync time.
  ///
  /// Sync is needed if more than 3 days have passed since the last successful
  /// synchronization, or if there was never a successful sync.
  ///
  /// Returns `true` if sync is needed, `false` otherwise.
  bool _syncNeeded() {
    final lastUpdate = _useCase.lastSuccessfullSynchronization;

    final nextScheduledUpdate =
        lastUpdate?.add(const Duration(days: 3)) ?? DateTime(2025);

    if (DateTime.now().isAfter(nextScheduledUpdate)) {
      return true;
    }

    return false;
  }

  /// Synchronizes the local app repositories with the backend.
  ///
  /// [force] - If `true`, forces synchronization regardless of the last sync time.
  ///           If `false`, only syncs if needed based on the schedule.
  ///
  /// Returns a [Result] indicating success or failure of the operation.
  ///
  /// In case of error, sets [fatalError] to `true` if this is the first
  /// synchronization attempt (no previous successful sync exists).
  Future<Result<void>> _sync(bool force) async {
    final lastUpdate = _useCase.lastSuccessfullSynchronization;

    if (force || _syncNeeded()) {
      final result = await _useCase.start();

      switch (result) {
        case Error<void>():
          _fatalError = lastUpdate == null;
        case Success<void>():
      }

      return result;
    }

    return const Result.success(null);
  }
}
