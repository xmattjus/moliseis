import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

class FavouriteGetIdsUseCase {
  FavouriteGetIdsUseCase({
    required EventRepository eventRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _placeRepository = placeRepository;

  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

  Future<Result<List<int>>> getFavouriteEventIds() =>
      _eventRepository.getFavouriteEventIds();

  Future<Result<List<int>>> getFavouritePlaceIds() =>
      _placeRepository.getFavouritePlaceIds();

  Future<Result<Event>> getEventById(int id) async =>
      _eventRepository.getById(id);

  Future<Result<Place>> getPlaceById(int id) async =>
      _placeRepository.getById(id);

  Future<Result<void>> setFavouriteEvent(int id, bool save) =>
      _eventRepository.setFavouriteEvent(id, save);

  Future<Result<void>> setFavouritePlace(int id, bool save) =>
      _placeRepository.setFavouritePlace(id, save);
}
