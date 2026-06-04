import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

class ObjectBoxSyncTransactionCoordinator
    implements SyncTransactionCoordinator {
  ObjectBoxSyncTransactionCoordinator(this._store);

  final Store _store;

  @override
  Result<void> runInWriteTransaction(Result<void> Function() fn) {
    try {
      var result = const Result<void>.success(null);
      _store.runInTransaction(TxMode.write, () {
        result = fn();
        if (result case Error<void>(:final error)) {
          throw error;
        }
      });
      return result;
    } on Exception catch (exception) {
      return Result.error(exception);
      // [Error]s are catched here because ObjectBox does throw them even if the
      // error is recoverable.
    } on Error<Object> catch (error, stackTrace) {
      return Result.error(Exception('$error, $stackTrace'));
    }
  }
}
