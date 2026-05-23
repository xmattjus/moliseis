import 'package:moliseis/utils/result.dart';

/// Defines an asynchronous synchronization contract.
mixin Synchronizable {
  /// Synchronizes local data with the remote source.
  ///
  /// Returns [Result.success] when synchronization completes without error,
  /// or [Result.error] on the first failure encountered.
  Future<Result<void>> synchronize();
}
