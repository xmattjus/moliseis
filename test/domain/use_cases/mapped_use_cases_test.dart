import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';

void main() {
  // Fakes below intentionally return safe defaults for methods outside each
  // focused assertion to keep tests deterministic and lightweight.
  group('ExploreUseCase', () {
    test('getAllEvents maps success values to EventContent', () async {
      final event = makeEvent(remoteId: 10, name: 'Event Name');
      final eventRepository = FakeEventRepository(
        getByCurrentYearResult: Result.success([event]),
      );
      final placeRepository = FakePlaceRepository();
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllEvents();

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, hasLength(1));
      expect(content.first, isA<Event>());
      expect(content.first.remoteId, 10);
      expect(content.first.name, 'Event Name');
    });

    test('getAllEvents propagates repository errors', () async {
      final error = TestException('events failed');
      final eventRepository = FakeEventRepository(
        getByCurrentYearResult: Result.error(error),
      );
      final placeRepository = FakePlaceRepository();
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllEvents();

      expect(result.isError, isTrue);
      expect((result as Error<List<Event>>).error, same(error));
    });

    test('getAllPlaces maps success values and forwards sort', () async {
      final place = makePlace(remoteId: 20, name: 'Place Name');
      final eventRepository = FakeEventRepository();
      final placeRepository = FakePlaceRepository(
        getAllResult: Result.success([place]),
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllPlaces(ContentSort.byDate);

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, hasLength(1));
      expect(content.first, isA<Place>());
      expect(content.first.remoteId, 20);
      expect(placeRepository.lastGetAllSort, ContentSort.byDate);
    });

    test('getAllPlaces propagates repository errors', () async {
      final error = TestException('places failed');
      final eventRepository = FakeEventRepository();
      final placeRepository = FakePlaceRepository(
        getAllResult: Result.error(error),
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllPlaces();

      expect(result.isError, isTrue);
      expect((result as Error<List<Place>>).error, same(error));
      expect(placeRepository.lastGetAllSort, ContentSort.byName);
    });

    test('getById maps success values to PlaceContent', () async {
      final eventRepository = FakeEventRepository();
      final placeRepository = FakePlaceRepository(
        getByIdResults: {
          21: Result.success(makePlace(remoteId: 21, name: 'Place 21')),
        },
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getById(21);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isA<Place>());
      expect(result.getOrNull()!.remoteId, 21);
    });

    test('getById propagates repository errors', () async {
      final error = TestException('getById failed');
      final eventRepository = FakeEventRepository();
      final placeRepository = FakePlaceRepository(
        getByIdResults: {21: Result.error(error)},
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getById(21);

      expect(result.isError, isTrue);
      expect((result as Error<Place>).error, same(error));
    });
  });

  group('GeoMapUseCase', () {
    test('getAllEvents maps success values to EventContent', () async {
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(
          getByCurrentYearResult: Result.success([
            makeEvent(remoteId: 11, name: 'Event 11'),
          ]),
        ),
        placeRepository: FakePlaceRepository(),
      );

      final result = await useCase.getAllEvents();

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(1));
      expect(result.getOrNull()!.first, isA<Event>());
    });

    test('getAllEvents propagates repository errors', () async {
      final error = TestException('events failed');
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(
          getByCurrentYearResult: Result.error(error),
        ),
        placeRepository: FakePlaceRepository(),
      );

      final result = await useCase.getAllEvents();

      expect(result.isError, isTrue);
      expect((result as Error<List<Event>>).error, same(error));
    });

    test('getAllPlaces maps success values and forwards sort', () async {
      final placeRepository = FakePlaceRepository(
        getAllResult: Result.success([
          makePlace(remoteId: 12, name: 'Place 12'),
        ]),
      );
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllPlaces(ContentSort.byDate);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(1));
      expect(result.getOrNull()!.first, isA<Place>());
      expect(placeRepository.lastGetAllSort, ContentSort.byDate);
    });

    test('getAllPlaces propagates repository errors', () async {
      final error = TestException('places failed');
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(
          getAllResult: Result.error(error),
        ),
      );

      final result = await useCase.getAllPlaces();

      expect(result.isError, isTrue);
      expect((result as Error<List<Place>>).error, same(error));
    });

    test('maps getById methods to content models', () async {
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(
          getByIdResults: {
            1: Result.success(makeEvent(name: 'Event 1')),
          },
        ),
        placeRepository: FakePlaceRepository(
          getByIdResults: {
            2: Result.success(makePlace(remoteId: 2, name: 'Place 2')),
          },
        ),
      );

      final eventResult = await useCase.getEventById(1);
      final placeResult = await useCase.getPlaceById(2);

      expect(eventResult.getOrNull(), isA<Event>());
      expect(placeResult.getOrNull(), isA<Place>());
    });

    test('propagates getById errors', () async {
      final eventError = TestException('event id failed');
      final placeError = TestException('place id failed');
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(
          getByIdResults: {1: Result.error(eventError)},
        ),
        placeRepository: FakePlaceRepository(
          getByIdResults: {2: Result.error(placeError)},
        ),
      );

      final eventResult = await useCase.getEventById(1);
      final placeResult = await useCase.getPlaceById(2);

      expect(eventResult.isError, isTrue);
      expect((eventResult as Error<ContentBase>).error, same(eventError));
      expect(placeResult.isError, isTrue);
      expect((placeResult as Error<ContentBase>).error, same(placeError));
    });

    test('nearby methods forward coordinates and map values', () async {
      final eventRepository = FakeEventRepository(
        getByCoordinatesResult: Result.success([
          makeEvent(remoteId: 3, name: 'Near Event'),
        ]),
      );
      final placeRepository = FakePlaceRepository(
        getByCoordinatesResult: Result.success([
          makePlace(remoteId: 4, name: 'Near Place'),
        ]),
      );
      final useCase = GeoMapUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final nearEvents = await useCase.getNearEventsByCoords(41.9, 14.7);
      final nearPlaces = await useCase.getNearPlacesByCoords(41.9, 14.7);

      expect(eventRepository.lastCoordinates, [41.9, 14.7]);
      expect(placeRepository.lastCoordinates, [41.9, 14.7]);
      expect(nearEvents.getOrNull()!.first, isA<Event>());
      expect(nearPlaces.getOrNull()!.first, isA<Place>());
    });

    test('nearby methods propagate repository errors', () async {
      final eventError = TestException('near events failed');
      final placeError = TestException('near places failed');
      final useCase = GeoMapUseCase(
        eventRepository: FakeEventRepository(
          getByCoordinatesResult: Result.error(eventError),
        ),
        placeRepository: FakePlaceRepository(
          getByCoordinatesResult: Result.error(placeError),
        ),
      );

      final nearEvents = await useCase.getNearEventsByCoords(41, 14);
      final nearPlaces = await useCase.getNearPlacesByCoords(41, 14);

      expect(nearEvents.isError, isTrue);
      expect((nearEvents as Error<List<ContentBase>>).error, same(eventError));
      expect(nearPlaces.isError, isTrue);
      expect((nearPlaces as Error<List<ContentBase>>).error, same(placeError));
    });
  });

  group('PostUseCase', () {
    test('getEventById and getPlaceById map success values', () async {
      final useCase = PostUseCase(
        eventRepository: FakeEventRepository(
          getByIdResults: {
            30: Result.success(makeEvent(remoteId: 30, name: 'Event 30')),
          },
        ),
        placeRepository: FakePlaceRepository(
          getByIdResults: {
            31: Result.success(makePlace(remoteId: 31, name: 'Place 31')),
          },
        ),
      );

      final eventResult = await useCase.getEventById(30);
      final placeResult = await useCase.getPlaceById(31);

      expect(eventResult.getOrNull(), isA<Event>());
      expect(placeResult.getOrNull(), isA<Place>());
    });

    test('getEventById and getPlaceById propagate repository errors', () async {
      final eventError = TestException('event failed');
      final placeError = TestException('place failed');
      final useCase = PostUseCase(
        eventRepository: FakeEventRepository(
          getByIdResults: {1: Result.error(eventError)},
        ),
        placeRepository: FakePlaceRepository(
          getByIdResults: {2: Result.error(placeError)},
        ),
      );

      final eventResult = await useCase.getEventById(1);
      final placeResult = await useCase.getPlaceById(2);

      expect(eventResult.isError, isTrue);
      expect((eventResult as Error<ContentBase>).error, same(eventError));
      expect(placeResult.isError, isTrue);
      expect((placeResult as Error<ContentBase>).error, same(placeError));
    });

    test('nearby methods map success values and forward coordinates', () async {
      final eventRepository = FakeEventRepository(
        getByCoordinatesResult: Result.success([
          makeEvent(remoteId: 32, name: 'Near Event 32'),
        ]),
      );
      final placeRepository = FakePlaceRepository(
        getByCoordinatesResult: Result.success([
          makePlace(remoteId: 33, name: 'Near Place 33'),
        ]),
      );
      final useCase = PostUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final nearEvents = await useCase.getNearEventsByCoords(41.2, 14.1);
      final nearPlaces = await useCase.getNearPlacesByCoords(41.2, 14.1);

      expect(eventRepository.lastCoordinates, [41.2, 14.1]);
      expect(placeRepository.lastCoordinates, [41.2, 14.1]);
      expect(nearEvents.getOrNull()!.first, isA<Event>());
      expect(nearPlaces.getOrNull()!.first, isA<Place>());
    });

    test('nearby methods propagate repository errors', () async {
      final eventError = TestException('near events failed');
      final placeError = TestException('near places failed');
      final useCase = PostUseCase(
        eventRepository: FakeEventRepository(
          getByCoordinatesResult: Result.error(eventError),
        ),
        placeRepository: FakePlaceRepository(
          getByCoordinatesResult: Result.error(placeError),
        ),
      );

      final nearEvents = await useCase.getNearEventsByCoords(41, 14);
      final nearPlaces = await useCase.getNearPlacesByCoords(41, 14);

      expect(nearEvents.isError, isTrue);
      expect((nearEvents as Error<List<ContentBase>>).error, same(eventError));
      expect(nearPlaces.isError, isTrue);
      expect((nearPlaces as Error<List<ContentBase>>).error, same(placeError));
    });
  });

  group('CategoryUseCase', () {
    test('getEventsByCategories maps success values to EventContent', () async {
      final event = makeEvent(remoteId: 40, name: 'Category Event');
      final useCase = CategoryUseCase(
        eventRepository: FakeEventRepository(
          getByCategoriesResult: Result.success([event]),
        ),
        placeRepository: FakePlaceRepository(),
      );

      final result = await useCase.getEventsByCategories({
        ContentCategory.history,
      });

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, hasLength(1));
      expect(content.first, isA<Event>());
      expect(content.first.remoteId, 40);
      expect(content.first.name, 'Category Event');
    });

    test('getEventsByCategories propagates repository errors', () async {
      final error = TestException('events by category failed');
      final useCase = CategoryUseCase(
        eventRepository: FakeEventRepository(
          getByCategoriesResult: Result.error(error),
        ),
        placeRepository: FakePlaceRepository(),
      );

      final result = await useCase.getEventsByCategories({
        ContentCategory.history,
      });

      expect(result.isError, isTrue);
      expect((result as Error<List<Event>>).error, same(error));
    });

    test('getPlacesByCategories maps success values to PlaceContent', () async {
      final place = makePlace(remoteId: 41, name: 'Category Place');
      final useCase = CategoryUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(
          getByCategoriesResult: Result.success([place]),
        ),
      );

      final result = await useCase.getPlacesByCategories({
        ContentCategory.nature,
      });

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, hasLength(1));
      expect(content.first, isA<Place>());
      expect(content.first.remoteId, 41);
      expect(content.first.name, 'Category Place');
    });

    test('getPlacesByCategories propagates repository errors', () async {
      final error = TestException('places by category failed');
      final useCase = CategoryUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(
          getByCategoriesResult: Result.error(error),
        ),
      );

      final result = await useCase.getPlacesByCategories({
        ContentCategory.nature,
      });

      expect(result.isError, isTrue);
      expect((result as Error<List<Place>>).error, same(error));
    });
  });

  group('FavouriteGetIdsUseCase', () {
    test('getEventById maps success value to EventContent', () async {
      final event = makeEvent(remoteId: 50, name: 'Favourite Event');
      final useCase = FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(
          getByIdResults: {50: Result.success(event)},
        ),
        placeRepository: FakePlaceRepository(),
      );

      final result = await useCase.getEventById(50);

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, isA<Event>());
      expect(content.remoteId, 50);
      expect(content.name, 'Favourite Event');
    });

    test('getEventById propagates repository error', () async {
      final error = TestException('event not found');
      final useCase = FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(
          getByIdResults: {50: Result.error(error)},
        ),
        placeRepository: FakePlaceRepository(),
      );

      final result = await useCase.getEventById(50);

      expect(result.isError, isTrue);
      expect((result as Error<Event>).error, same(error));
    });

    test('getPlaceById maps success value to PlaceContent', () async {
      final place = makePlace(remoteId: 51, name: 'Favourite Place');
      final useCase = FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(
          getByIdResults: {51: Result.success(place)},
        ),
      );

      final result = await useCase.getPlaceById(51);

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, isA<Place>());
      expect(content.remoteId, 51);
      expect(content.name, 'Favourite Place');
    });

    test('getPlaceById propagates repository error', () async {
      final error = TestException('place not found');
      final useCase = FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: FakePlaceRepository(
          getByIdResults: {51: Result.error(error)},
        ),
      );

      final result = await useCase.getPlaceById(51);

      expect(result.isError, isTrue);
      expect((result as Error<Place>).error, same(error));
    });
  });
}
