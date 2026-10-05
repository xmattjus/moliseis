import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/utils/result.dart';

/// Controls discovery phases while retaining the production composition.
///
/// Inject a real temporary ObjectBox store; no query/store behavior is faked.
class ControllableSearchRepository extends SearchRepositoryImpl {
  ControllableSearchRepository({
    required super.logger,
    required super.objectBoxI,
    super.nowUtc,
  });

  Future<Result<List<Place>>> Function(String text)? placePhase;
  Future<Result<List<Event>>> Function(String text)? eventPhase;

  int placePhaseCalls = 0;
  int eventPhaseCalls = 0;

  @override
  Future<Result<List<Place>>> searchPlaces(String text) {
    placePhaseCalls++;
    return placePhase?.call(text) ?? super.searchPlaces(text);
  }

  @override
  Future<Result<List<Event>>> searchEvents(String text) {
    eventPhaseCalls++;
    return eventPhase?.call(text) ?? super.searchEvents(text);
  }
}
