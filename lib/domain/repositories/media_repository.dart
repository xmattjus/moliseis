import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

/// Domain interface for media data access.
///
/// [Synchronizable] is parameterized with [MediaDto] from the data layer so
/// the concrete DTO type flows through `prepareSync`/`commitSync` at
/// compile time. The `data/dtos` import is a deliberate outward
/// dependency: the `SyncDto` base contract is in the domain, but the
/// concrete subtypes stay in the data layer to keep serialization and
/// ObjectBox annotations out of domain code.
abstract class MediaRepository with Synchronizable<MediaDto> {
  /// Returns all media associated with the event identified by [id].
  Future<Result<List<Media>>> getByEventId(int id);

  /// Returns all media associated with the place identified by [id].
  Future<Result<List<Media>>> getByPlaceId(int id);
}
