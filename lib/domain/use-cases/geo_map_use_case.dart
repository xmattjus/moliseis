import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Provides content for the Geo Map by querying repositories directly.
///
/// This use case depends on event and place repositories, not GeoMapRepository.
class GeoMapUseCase {
  const GeoMapUseCase({
    required EventRepository eventRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _placeRepository = placeRepository;

  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

  /// Returns events for the current year mapped to content models.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<Event>>> getAllEvents() async =>
      _eventRepository.getByCurrentYear();

  /// Returns places mapped to content models using the given [sort].
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<Place>>> getAllPlaces([
    ContentSort sort = ContentSort.byName,
  ]) async => _placeRepository.getAll(sort: sort);

  /// Returns one event by [id], mapped to a content model.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<ContentBase>> getEventById(int id) async =>
      _eventRepository.getById(id);

  /// Returns one place by [id], mapped to a content model.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<ContentBase>> getPlaceById(int id) async =>
      _placeRepository.getById(id);

  /// Returns nearby events for the given coordinates.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<ContentBase>>> getNearEventsByCoords(
    double latitude,
    double longitude,
  ) async => _eventRepository.getByCoordinates([latitude, longitude]);

  /// Returns nearby places for the given coordinates.
  ///
  /// Repository failures are propagated as `Result.error`.
  Future<Result<List<ContentBase>>> getNearPlacesByCoords(
    double latitude,
    double longitude,
  ) async => _placeRepository.getByCoordinates([latitude, longitude]);
}
