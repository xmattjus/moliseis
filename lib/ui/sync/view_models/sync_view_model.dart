import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// Manages the synchronization state of the app repositories.
///
/// Automatically triggers a sync on construction when one is due, and exposes
/// the [sync] command for manual or forced synchronization.
class SyncViewModel extends ChangeNotifier {
  /// Creates a [SyncViewModel] and triggers an automatic sync if one is due.
  SyncViewModel({required SyncUseCase syncUseCase}) : _useCase = syncUseCase {
    sync = createResultCommand<bool, void>(
      _sync,
      debugName: 'sync_view_model.sync',
    );
    sync.results.addListener(_classifyOutcome);

    if (_useCase.isSyncRequired) {
      sync.run(false);
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
  late final ResultCommand<bool, void> sync;

  bool _disposed = false;

  Future<Result<void>> _sync(bool force) async {
    if (_disposed) return Result.error(Exception('Sync owner unavailable'));
    if (force || _useCase.isSyncRequired) return await _useCase.sync();
    return const Result.success(null);
  }

  void _classifyOutcome() {
    if (_disposed) return;
    final fatal =
        sync.results.value.hasFailure && _useCase.lastSyncedAt == null;
    if (_fatalError == fatal) return;
    _fatalError = fatal;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    sync.results.removeListener(_classifyOutcome);
    scheduleMicrotask(super.dispose);
    _releaseWhenSettled();
  }

  // Preserve private settlement and runtime reporting after owner revocation.
  // Teardown must run outside results/value/notifier dispatch.
  void _releaseWhenSettled() {
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
      scheduleMicrotask(() {
        unawaited(
          Future<void>(() {
            queued = false;
            if (released || sync.isRunningSync.value) return;
            if (invalidated) {
              requestCleanup();
              return;
            }
            sync.isRunningSync.removeListener(onRunningChanged);
            released = true;
            sync.dispose();
          }),
        );
      });
    }

    onRunningChanged = () {
      invalidated = true;
      if (!sync.isRunningSync.value) requestCleanup();
    };
    sync.isRunningSync.addListener(onRunningChanged);
    if (!sync.isRunningSync.value) requestCleanup();
  }
}
