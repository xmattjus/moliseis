import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Provides content for the Explore area by mapping repository entities.
///
/// The use case keeps repository errors visible to callers through `Result`.
class ExploreUseCase {
  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

  ExploreUseCase({
    required EventRepository eventRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _placeRepository = placeRepository;

  /// Returns events for the current year mapped to content models.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<EventContent>>> getAllEvents() async {
    final result = await _eventRepository.getByCurrentYear();

    return result.map((events) => events.map(EventContent.fromEvent).toList());
  }

  /// Returns places mapped to content models using the given [sort].
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<PlaceContent>>> getAllPlaces([
    ContentSort sort = ContentSort.byName,
  ]) async {
    final result = await _placeRepository.getAll(sort: sort);

    return result.map((places) => places.map(PlaceContent.fromPlace).toList());
  }

  /// Returns one place by [id], mapped to a content model.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<PlaceContent>> getById(int id) async {
    return (await _placeRepository.getById(id)).map(PlaceContent.fromPlace);
  }
}
