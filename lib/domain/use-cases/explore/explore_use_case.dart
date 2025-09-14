import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/domain/models/core/content_sort.dart';
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/domain/models/place/place_content.dart';
import 'package:moliseis/utils/result.dart';

class ExploreUseCase {
  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

  ExploreUseCase({
    required EventRepository eventRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
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

  Future<Result<PlaceContent>> getById(int id) async {
    final result = await _placeRepository.getById(id);

    switch (result) {
      case Success<Place>():
        return Result.success(PlaceContent.fromPlace(result.value));
      case Error<Place>():
        return Result.error(result.error);
    }
  }
}
