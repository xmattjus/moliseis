import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';

class CategoryUseCase {
  final EventRepository _eventRepository;
  final PlaceRepository _placeRepository;

  CategoryUseCase({
    required EventRepository eventRepository,
    required PlaceRepository placeRepository,
  }) : _eventRepository = eventRepository,
       _placeRepository = placeRepository;

  Future<Result<List<EventContent>>> getEventsByCategories(
    Set<ContentCategory> categories,
  ) async {
    final list = <EventContent>[];

    final result = await _eventRepository.getByCategories(categories);

    switch (result) {
      case Success<List<Event>>():
        for (final event in result.value) {
          list.add(EventContent.fromEvent(event));
        }
      case Error<List<Event>>():
    }

    return Result.success(list);
  }

  Future<Result<List<PlaceContent>>> getPlacesByCategories(
    Set<ContentCategory> categories,
  ) async {
    final list = <PlaceContent>[];

    final result = await _placeRepository.getByCategories(categories);

    switch (result) {
      case Success<List<Place>>():
        for (final place in result.value) {
          list.add(PlaceContent.fromPlace(place));
        }
      case Error<List<Place>>():
    }

    return Result.success(list);
  }
}
