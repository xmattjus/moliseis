import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/use-cases/explore_get_by_id_use_case.dart';
import 'package:moliseis/utils/result.dart';

/// Provides content for the Explore area by mapping repository entities.
///
/// The use case keeps repository errors visible to callers through `Result`.
class ExploreUseCase implements ExploreGetByIdUseCase {
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
  Future<Result<List<Event>>> getAllEvents() async =>
      await _eventRepository.getByCurrentYear();

  /// Returns places mapped to content models using the given [sort].
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<Place>>> getAllPlaces([
    ContentSort sort = ContentSort.byName,
  ]) async => await _placeRepository.getAll(sort: sort);

  /// Returns one place by [id], mapped to a content model.
  ///
  /// Repository failures are propagated as `Result.error`.
  @override
  Future<Result<Place>> getById(int id) async =>
      await _placeRepository.getById(id);
}
