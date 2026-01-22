import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/domain/repositories/repository_base.dart';
import 'package:moliseis/utils/result.dart';

abstract class MediaRepository extends RepositoryBase {
  Future<Result<List<Media>>> getByEventId(int id);

  Future<Result<List<Media>>> getByPlaceId(int id);

  @override
  Future<Result<void>> synchronize();
}
