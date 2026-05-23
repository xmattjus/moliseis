import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Provides post-detail and nearby content data for post screens.
///
/// The use case maps repository entities while preserving repository errors.
class PostUseCase {
  const PostUseCase({
    required EventRepository eventRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _placeRepository = placeRepository;

  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

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
