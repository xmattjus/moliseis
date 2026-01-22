import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/geo_map_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

class GeoMapUseCase {
  final EventRepository _eventRepository;
  final GeoMapRepository _geoMapRepository;
  final PlaceRepository _placeRepository;

  const GeoMapUseCase({
    required EventRepository eventRepository,
    required GeoMapRepository geoMapRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _geoMapRepository = geoMapRepository,
       _placeRepository = placeRepository;

  Future<Result<List<EventContent>>> getAllEvents() async {
    final list = <EventContent>[];

    final result = await _eventRepository.getByCurrentYear();

    switch (result) {
      case Success<List<Event>>():
        for (final event in result.value) {
          list.add(EventContent.fromEvent(event));
        }
      case Error<List<Event>>():
    }

    return Result.success(list);
  }

  Future<Result<List<PlaceContent>>> getAllPlaces([
    ContentSort sort = ContentSort.byName,
  ]) async {
    final list = <PlaceContent>[];

    final result = await _placeRepository.getAll(sort: sort);

    switch (result) {
      case Success<List<Place>>():
        for (final place in result.value) {
          list.add(PlaceContent.fromPlace(place));
        }
      case Error<List<Place>>():
    }

    return Result.success(list);
  }

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
}
