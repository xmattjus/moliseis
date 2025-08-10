import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/utils/result.dart';

abstract class EventRepository {
  Future<Result<List<Event>>> getAll();

  Future<Result<void>> synchronize();
}
