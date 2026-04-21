import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
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

  Future<Result<List<Event>>> getEventsByCategories(
    Set<ContentCategory> categories,
  ) async => await _eventRepository.getByCategories(categories);

  Future<Result<List<Place>>> getPlacesByCategories(
    Set<ContentCategory> categories,
  ) async => await _placeRepository.getByCategories(categories);
}
