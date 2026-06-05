import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/utils/result.dart';

/// Defines an asynchronous two-phase synchronization contract.
///
/// Phase 1: [prepareSync] fetches remote DTOs without writing locally.
/// Phase 2: [commitSync] writes the fetched DTOs to the local database.
mixin Synchronizable<T extends SyncDto> {
  /// Fetches remote DTOs without writing to the local database.
  ///
  /// Returns the fetched DTOs wrapped in a [Result]. Call [commitSync]
  /// with the returned DTOs to write them to the local database.
  Future<Result<List<T>>> prepareSync();

  /// Writes the given remote [dtos] to the local database.
  ///
  /// Returns `Result.success(null)` when all DTOs are committed, or
  /// `Result.error` if the commit fails.
  Result<void> commitSync(List<T> dtos);
}
