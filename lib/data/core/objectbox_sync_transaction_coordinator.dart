import 'dart:core' as core;
import 'dart:core';

import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

class ObjectBoxSyncTransactionCoordinator
    implements SyncTransactionCoordinator {
  ObjectBoxSyncTransactionCoordinator(this._store, {required Logger logger})
    : _logger = logger;

  final Store _store;
  final Logger _logger;

  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    try {
      var result = const Result<void>.success(null);
      _store.runInTransaction(TxMode.write, () {
        result = fn();
        if (result.isError) throw _SyncRollback(result);
      });
      return result;
    } on _SyncRollback catch (rollback) {
      return rollback.result;
    } on Exception catch (exception, stackTrace) {
      _report(exception, stackTrace);
      return Result.error(exception);
      // ObjectBox raises recoverable Errors; Result requires Exception.
      // ignore: avoid_catching_errors
    } on core.Error catch (error, stackTrace) {
      _report(error, stackTrace);
      return Result.error(Exception('Content sync transaction failed.'));
    }
  }

  void _report(Object error, StackTrace stackTrace) {
    _logger.log(
      SyncFailure(
        owner: SyncFailureOwner.commit,
        category: syncFailureCategory(error) == SyncFailureCategory.connectivity
            ? SyncFailureCategory.connectivity
            : SyncFailureCategory.storage,
      ),
      error: error,
      stackTrace: stackTrace,
    );
  }
}

// A callback Result failure forces rollback but retains its existing owner.
final class _SyncRollback implements Exception {
  const _SyncRollback(this.result);

  final Result<void> result;
}
