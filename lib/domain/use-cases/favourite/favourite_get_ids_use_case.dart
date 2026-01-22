import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
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

  Future<Result<List<int>>> getFavouriteEventIds() async {
    final result = await _eventRepository.getFavouriteEventIds();

    return result;
  }

  Future<Result<List<int>>> getFavouritePlaceIds() async {
    final result = await _placeRepository.getFavouritePlaceIds();

    return result;
  }

  Future<Result<EventContent>> getEventById(int id) async {
    final result = await _eventRepository.getById(id);

    switch (result) {
      case Success<Event>():
        return Result.success(EventContent.fromEvent(result.value));
      case Error<Event>():
        return Result.error(result.error);
    }
  }

  Future<Result<PlaceContent>> getPlaceById(int id) async {
    final result = await _placeRepository.getById(id);

    switch (result) {
      case Success<Place>():
        return Result.success(PlaceContent.fromPlace(result.value));
      case Error<Place>():
        return Result.error(result.error);
    }
  }

  Future<Result<void>> setFavouriteEvent(int id, bool save) async {
    final result = await _eventRepository.setFavouriteEvent(id, save);

    return result;
  }

  Future<Result<void>> setFavouritePlace(int id, bool save) async {
    final result = await _placeRepository.setFavouritePlace(id, save);

    return result;
  }
}
