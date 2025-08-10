import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/data/repositories/geo_map/geo_map_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/domain/models/place/place_content.dart';
import 'package:moliseis/utils/result.dart';

class DetailUseCase {
  final EventRepository _eventRepository;
  final GeoMapRepository _geoMapRepository;
  final PlaceRepository _placeRepository;

  const DetailUseCase({
    required EventRepository eventRepository,
    required GeoMapRepository geoMapRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _geoMapRepository = geoMapRepository,
       _placeRepository = placeRepository;

  Future<Result<ContentBase>> getEventById(int id) async {
    final result = await _eventRepository.getById(id);

    switch (result) {
      case Success<Event>():
        return Result.success(EventContent.fromEvent(result.value));
      case Error<Event>():
        return Result.error(result.error);
    }
  }

  Future<Result<ContentBase>> getPlaceById(int id) async {
    final result = await _placeRepository.getById(id);

    switch (result) {
      case Success<Place>():
        return Result.success(PlaceContent.fromPlace(result.value));
      case Error<Place>():
        return Result.error(result.error);
    }
  }

  Future<Result<List<ContentBase>>> getNearEventsByCoords(
    double latitude,
    double longitude,
  ) async {
    final result = await _eventRepository.getByCoordinates([
      latitude,
      longitude,
    ]);

    switch (result) {
      case Success<List<Event>>():
        return Result.success(
          result.value.map((event) => EventContent.fromEvent(event)).toList(),
        );
      case Error<List<Event>>():
        return Result.error(result.error);
    }
  }

  Future<Result<List<ContentBase>>> getNearPlacesByCoords(
    double latitude,
    double longitude,
  ) async {
    final result = await _placeRepository.getByCoordinates([
      latitude,
      longitude,
    ]);

    switch (result) {
      case Success<List<Place>>():
        return Result.success(
          result.value.map((place) => PlaceContent.fromPlace(place)).toList(),
        );
      case Error<List<Place>>():
        return Result.error(result.error);
    }
  }

  Future<Result<String?>> getStreetAddressByCoords(
    double latitude,
    double longitude,
  ) async {
    final result = await _geoMapRepository.getStreetAddreFromCoords(
      latitude,
      longitude,
    );

    switch (result) {
      case Success<String?>():
        return Result.success(result.value);
      case Error<String?>():
        return Result.error(result.error);
    }
  }
}
