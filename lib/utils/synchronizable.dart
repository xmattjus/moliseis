import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/utils/result.dart';

/// Defines an asynchronous synchronization contract.
///
/// ### Type contract
///
/// Although [prepareSync] returns `List<SyncDto>` and [commitSync] accepts
/// `List<SyncDto>`, the **runtime type** of each element is always the
/// repository-specific DTO subtype (e.g. `CityDto`, `PlaceDto`).
///
/// Callers **must** pass the list returned by [prepareSync] directly to the
/// **same** repository's [commitSync].  Swapping DTOs between repositories
/// (e.g. passing a `CityDto` list to a `PlaceRepository`) will be caught as a
/// runtime type error by implementations that guard against it.
mixin Synchronizable {
  /// Fetches remote DTOs without writing to the local database.
  ///
  /// This is the first phase of a two-phase sync. It performs network I/O
  /// and returns the fetched DTOs wrapped in a [Result]. Call [commitSync]
  /// with the returned DTOs to write them to the local database.
  ///
  /// The returned list's element runtime type matches the repository's
  /// concrete DTO subtype. See the [Synchronizable] class-level docs for
  /// the full type contract.
  Future<Result<List<SyncDto>>> prepareSync();

  /// Writes the given remote [dtos] to the local database.
  ///
  /// This is the second phase of a two-phase sync. It performs merge + write
  /// logic and must run inside a write transaction provided by the caller.
  ///
  /// Returns `Result.success(null)` when all DTOs are committed, or
  /// `Result.error` if the commit fails. Implementations must not throw;
  /// errors should be wrapped in `Result.error` instead.
  ///
  /// The [dtos] list must have been obtained from this same repository's
  /// [prepareSync] — its element runtime type must match the repository's
  /// concrete DTO subtype. See the [Synchronizable] class-level docs for
  /// the full type contract.
  Result<void> commitSync(List<SyncDto> dtos);
}
