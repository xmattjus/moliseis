import 'package:moliseis/domain/repositories/repository_base.dart';
import 'package:moliseis/utils/result.dart';

abstract class CityRepository extends RepositoryBase {
  @override
  Future<Result<void>> synchronize();
}
