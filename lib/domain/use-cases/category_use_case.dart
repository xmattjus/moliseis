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
    return (await _eventRepository.getByCategories(
      categories,
    )).map((events) => events.map(EventContent.fromEvent).toList());
  }

  Future<Result<List<PlaceContent>>> getPlacesByCategories(
    Set<ContentCategory> categories,
  ) async {
    return (await _placeRepository.getByCategories(
      categories,
    )).map((places) => places.map(PlaceContent.fromPlace).toList());
  }
}
