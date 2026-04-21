import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

/// Domain interface for media data access.
abstract class MediaRepository implements Synchronizable {
  /// Returns all media associated with the event identified by [id].
  Future<Result<List<Media>>> getByEventId(int id);

  /// Returns all media associated with the place identified by [id].
  Future<Result<List<Media>>> getByPlaceId(int id);

  @override
  Future<Result<void>> synchronize();
}
