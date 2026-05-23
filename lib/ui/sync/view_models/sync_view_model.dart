import 'package:flutter/material.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

/// Manages the synchronization state of the app repositories.
///
/// Automatically triggers a sync on construction when one is due, and exposes
/// the [sync] command for manual or forced synchronization.
class SyncViewModel extends ChangeNotifier {
  /// Creates a [SyncViewModel] and triggers an automatic sync if one is due.
  SyncViewModel({required SyncUseCase syncUseCase}) : _useCase = syncUseCase {
    sync = Command1(_sync);

    if (_useCase.isSyncRequired) {
      sync.execute(false);
    }
  }

  final SyncUseCase _useCase;

  var _fatalError = false;

  /// Whether a fatal error occurred while synchronizing the repositories or
  /// not.
  ///
  /// A fatal error is one that occurs when there's no previous successful
  /// synchronization, meaning the app has no cached data to fall back on.
  bool get fatalError => _fatalError;

  /// Command for triggering synchronization.
  ///
  /// Pass `true` to force a sync regardless of schedule, or `false` to sync
  /// only when one is due.
  late Command1<void, bool> sync;

  Future<Result<void>> _sync(bool force) async {
    if (force || _useCase.isSyncRequired) {
      final result = await _useCase.sync();

      if (result.isError && _useCase.lastSyncedAt == null) {
        _fatalError = true;
        notifyListeners();
      }
      return result;
    }

    return const Result.success(null);
  }
}
