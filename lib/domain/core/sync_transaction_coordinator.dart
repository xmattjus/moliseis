import 'package:moliseis/utils/result.dart';

/// Defines a coordinator for write transactions.
///
/// Implementations execute [fn] inside a write transaction. Returns the
/// `Result` produced by [fn]. If [fn] returns `Result.error`, the transaction
/// is rolled back before returning the error.
abstract class SyncTransactionCoordinator {
  Result<void> runInWriteTransaction(Result<void> Function() fn);
}
