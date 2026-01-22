import 'package:moliseis/utils/result.dart';

abstract class RepositoryBase {
  Future<Result<void>> synchronize();

  const RepositoryBase();
}
