import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Provides content for the Geo Map by querying repositories directly.
///
/// This use case depends on event and place repositories, not GeoMapRepository.
class GeoMapUseCase {
  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

  const GeoMapUseCase({
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

  /// Returns one event by [id], mapped to a content model.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<ContentBase>> getEventById(int id) async {
    return (await _eventRepository.getById(id)).map(EventContent.fromEvent);
  }

  /// Returns one place by [id], mapped to a content model.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<ContentBase>> getPlaceById(int id) async {
    return (await _placeRepository.getById(id)).map(PlaceContent.fromPlace);
  }

  /// Returns nearby events for the given coordinates.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<ContentBase>>> getNearEventsByCoords(
    double latitude,
    double longitude,
  ) async {
    return (await _eventRepository.getByCoordinates([latitude, longitude])).map(
      (events) => events
          .map<ContentBase>(EventContent.fromEvent)
          .toList(growable: false),
    );
  }

  /// Returns nearby places for the given coordinates.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<ContentBase>>> getNearPlacesByCoords(
    double latitude,
    double longitude,
  ) async {
    return (await _placeRepository.getByCoordinates([latitude, longitude])).map(
      (places) => places
          .map<ContentBase>(PlaceContent.fromPlace)
          .toList(growable: false),
    );
  }
}
