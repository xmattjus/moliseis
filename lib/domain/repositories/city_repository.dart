import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

/// Domain interface for city data access.
abstract class CityRepository implements Synchronizable {
  @override
  Future<Result<void>> synchronize();
}
