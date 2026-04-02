import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/data/sources/place.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/use-cases/explore/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map/geo_map_use_case.dart';
import 'package:moliseis/domain/use-cases/post/post_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:objectbox/objectbox.dart';

void main() {
  // Fakes below intentionally return safe defaults for methods outside each
  // focused assertion to keep tests deterministic and lightweight.
  group('ExploreUseCase', () {
    test('getAllEvents maps success values to EventContent', () async {
      final event = _event(remoteId: 10, name: 'Event Name');
      final eventRepository = _FakeEventRepository(
        getByCurrentYearResult: Result.success([event]),
      );
      final placeRepository = _FakePlaceRepository();
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllEvents();

      expect(result.isSuccess, isTrue);
      final content = result.getOrNull()!;
      expect(content, hasLength(1));
      expect(content.first, isA<EventContent>());
      expect(content.first.remoteId, 10);
      expect(content.first.name, 'Event Name');
    });

    test('getAllEvents propagates repository errors', () async {
      final error = _TestException('events failed');
      final eventRepository = _FakeEventRepository(
        getByCurrentYearResult: Result.error(error),
      );
      final placeRepository = _FakePlaceRepository();
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllEvents();

      expect(result.isError, isTrue);
      expect((result as Error<List<EventContent>>).error, same(error));
    });

    test('getAllPlaces maps success values and forwards sort', () async {
      final place = _place(remoteId: 20, name: 'Place Name');
      final eventRepository = _FakeEventRepository();
      final placeRepository = _FakePlaceRepository(
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
      expect(content.first, isA<PlaceContent>());
      expect(content.first.remoteId, 20);
      expect(placeRepository.lastGetAllSort, ContentSort.byDate);
    });

    test('getAllPlaces propagates repository errors', () async {
      final error = _TestException('places failed');
      final eventRepository = _FakeEventRepository();
      final placeRepository = _FakePlaceRepository(
        getAllResult: Result.error(error),
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllPlaces();

      expect(result.isError, isTrue);
      expect((result as Error<List<PlaceContent>>).error, same(error));
      expect(placeRepository.lastGetAllSort, ContentSort.byName);
    });

    test('getById maps success values to PlaceContent', () async {
      final eventRepository = _FakeEventRepository();
      final placeRepository = _FakePlaceRepository(
        getByIdResult: Result.success(_place(remoteId: 21, name: 'Place 21')),
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getById(21);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isA<PlaceContent>());
      expect(result.getOrNull()!.remoteId, 21);
    });

    test('getById propagates repository errors', () async {
      final error = _TestException('getById failed');
      final eventRepository = _FakeEventRepository();
      final placeRepository = _FakePlaceRepository(
        getByIdResult: Result.error(error),
      );
      final useCase = ExploreUseCase(
        eventRepository: eventRepository,
        placeRepository: placeRepository,
      );

      final result = await useCase.getById(21);

      expect(result.isError, isTrue);
      expect((result as Error<PlaceContent>).error, same(error));
    });
  });

  group('GeoMapUseCase', () {
    test('getAllEvents maps success values to EventContent', () async {
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(
          getByCurrentYearResult: Result.success([
            _event(remoteId: 11, name: 'Event 11'),
          ]),
        ),
        placeRepository: _FakePlaceRepository(),
      );

      final result = await useCase.getAllEvents();

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(1));
      expect(result.getOrNull()!.first, isA<EventContent>());
    });

    test('getAllEvents propagates repository errors', () async {
      final error = _TestException('events failed');
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(
          getByCurrentYearResult: Result.error(error),
        ),
        placeRepository: _FakePlaceRepository(),
      );

      final result = await useCase.getAllEvents();

      expect(result.isError, isTrue);
      expect((result as Error<List<EventContent>>).error, same(error));
    });

    test('getAllPlaces maps success values and forwards sort', () async {
      final placeRepository = _FakePlaceRepository(
        getAllResult: Result.success([_place(remoteId: 12, name: 'Place 12')]),
      );
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(),
        placeRepository: placeRepository,
      );

      final result = await useCase.getAllPlaces(ContentSort.byDate);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(1));
      expect(result.getOrNull()!.first, isA<PlaceContent>());
      expect(placeRepository.lastGetAllSort, ContentSort.byDate);
    });

    test('getAllPlaces propagates repository errors', () async {
      final error = _TestException('places failed');
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(),
        placeRepository: _FakePlaceRepository(
          getAllResult: Result.error(error),
        ),
      );

      final result = await useCase.getAllPlaces();

      expect(result.isError, isTrue);
      expect((result as Error<List<PlaceContent>>).error, same(error));
    });

    test('maps getById methods to content models', () async {
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(
          getByIdResult: Result.success(_event(remoteId: 1, name: 'Event 1')),
        ),
        placeRepository: _FakePlaceRepository(
          getByIdResult: Result.success(_place(remoteId: 2, name: 'Place 2')),
        ),
      );

      final eventResult = await useCase.getEventById(1);
      final placeResult = await useCase.getPlaceById(2);

      expect(eventResult.getOrNull(), isA<EventContent>());
      expect(placeResult.getOrNull(), isA<PlaceContent>());
    });

    test('propagates getById errors', () async {
      final eventError = _TestException('event id failed');
      final placeError = _TestException('place id failed');
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(
          getByIdResult: Result.error(eventError),
        ),
        placeRepository: _FakePlaceRepository(
          getByIdResult: Result.error(placeError),
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
      final eventRepository = _FakeEventRepository(
        getByCoordinatesResult: Result.success([
          _event(remoteId: 3, name: 'Near Event'),
        ]),
      );
      final placeRepository = _FakePlaceRepository(
        getByCoordinatesResult: Result.success([
          _place(remoteId: 4, name: 'Near Place'),
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
      expect(nearEvents.getOrNull()!.first, isA<EventContent>());
      expect(nearPlaces.getOrNull()!.first, isA<PlaceContent>());
    });

    test('nearby methods propagate repository errors', () async {
      final eventError = _TestException('near events failed');
      final placeError = _TestException('near places failed');
      final useCase = GeoMapUseCase(
        eventRepository: _FakeEventRepository(
          getByCoordinatesResult: Result.error(eventError),
        ),
        placeRepository: _FakePlaceRepository(
          getByCoordinatesResult: Result.error(placeError),
        ),
      );

      final nearEvents = await useCase.getNearEventsByCoords(41.0, 14.0);
      final nearPlaces = await useCase.getNearPlacesByCoords(41.0, 14.0);

      expect(nearEvents.isError, isTrue);
      expect((nearEvents as Error<List<ContentBase>>).error, same(eventError));
      expect(nearPlaces.isError, isTrue);
      expect((nearPlaces as Error<List<ContentBase>>).error, same(placeError));
    });
  });

  group('PostUseCase', () {
    test('getEventById and getPlaceById map success values', () async {
      final useCase = PostUseCase(
        eventRepository: _FakeEventRepository(
          getByIdResult: Result.success(_event(remoteId: 30, name: 'Event 30')),
        ),
        placeRepository: _FakePlaceRepository(
          getByIdResult: Result.success(_place(remoteId: 31, name: 'Place 31')),
        ),
      );

      final eventResult = await useCase.getEventById(30);
      final placeResult = await useCase.getPlaceById(31);

      expect(eventResult.getOrNull(), isA<EventContent>());
      expect(placeResult.getOrNull(), isA<PlaceContent>());
    });

    test('getEventById and getPlaceById propagate repository errors', () async {
      final eventError = _TestException('event failed');
      final placeError = _TestException('place failed');
      final useCase = PostUseCase(
        eventRepository: _FakeEventRepository(
          getByIdResult: Result.error(eventError),
        ),
        placeRepository: _FakePlaceRepository(
          getByIdResult: Result.error(placeError),
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
      final eventRepository = _FakeEventRepository(
        getByCoordinatesResult: Result.success([
          _event(remoteId: 32, name: 'Near Event 32'),
        ]),
      );
      final placeRepository = _FakePlaceRepository(
        getByCoordinatesResult: Result.success([
          _place(remoteId: 33, name: 'Near Place 33'),
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
      expect(nearEvents.getOrNull()!.first, isA<EventContent>());
      expect(nearPlaces.getOrNull()!.first, isA<PlaceContent>());
    });

    test('nearby methods propagate repository errors', () async {
      final eventError = _TestException('near events failed');
      final placeError = _TestException('near places failed');
      final useCase = PostUseCase(
        eventRepository: _FakeEventRepository(
          getByCoordinatesResult: Result.error(eventError),
        ),
        placeRepository: _FakePlaceRepository(
          getByCoordinatesResult: Result.error(placeError),
        ),
      );

      final nearEvents = await useCase.getNearEventsByCoords(41.0, 14.0);
      final nearPlaces = await useCase.getNearPlacesByCoords(41.0, 14.0);

      expect(nearEvents.isError, isTrue);
      expect((nearEvents as Error<List<ContentBase>>).error, same(eventError));
      expect(nearPlaces.isError, isTrue);
      expect((nearPlaces as Error<List<ContentBase>>).error, same(placeError));
    });
  });
}

final class _FakeEventRepository extends EventRepository {
  _FakeEventRepository({
    this.getByCurrentYearResult = const Result.success(<Event>[]),
    this.getByCoordinatesResult = const Result.success(<Event>[]),
    Result<Event>? getByIdResult,
  }) : _getByIdResult =
           getByIdResult ?? Result.error(_TestException('Not configured.'));

  final Result<List<Event>> getByCurrentYearResult;
  final Result<List<Event>> getByCoordinatesResult;
  final Result<Event> _getByIdResult;

  List<double>? lastCoordinates;

  @override
  Future<Result<List<Event>>> getByCurrentYear() async =>
      getByCurrentYearResult;

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async =>
      const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Event>[]);

  @override
  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates) async {
    lastCoordinates = coordinates;
    return getByCoordinatesResult;
  }

  @override
  Future<Result<Event>> getById(int id) async => _getByIdResult;

  @override
  Future<Result<List<int>>> getNextEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

final class _FakePlaceRepository extends PlaceRepository {
  _FakePlaceRepository({
    this.getAllResult = const Result.success(<Place>[]),
    this.getByCoordinatesResult = const Result.success(<Place>[]),
    Result<Place>? getByIdResult,
  }) : _getByIdResult =
           getByIdResult ?? Result.error(_TestException('Not configured.'));

  final Result<List<Place>> getAllResult;
  final Result<List<Place>> getByCoordinatesResult;
  final Result<Place> _getByIdResult;

  ContentSort? lastGetAllSort;
  List<double>? lastCoordinates;

  @override
  Future<Result<List<Place>>> getAll({
    ContentSort sort = ContentSort.byName,
  }) async {
    lastGetAllSort = sort;
    return getAllResult;
  }

  @override
  Future<Result<List<Place>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async => const Result.success(<Place>[]);

  @override
  Future<Result<List<Place>>> getByCoordinates(List<double> coordinates) async {
    lastCoordinates = coordinates;
    return getByCoordinatesResult;
  }

  @override
  Future<Result<Place>> getById(int id) async => _getByIdResult;

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getIdsByCoordinates(
    List<double> coordinates,
  ) async => const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getLatestPlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getSuggestedPlaceIds() async =>
      const Result.success(<int>[]);

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async =>
      const Result.success(null);

  @override
  Future<Result<void>> synchronize() async => const Result.success(null);
}

Event _event({required int remoteId, required String name}) {
  final now = DateTime.utc(2026, 4, 2);

  return Event(
    remoteId: remoteId,
    name: name,
    description: 'Description',
    startDate: now,
    coordinates: const [41.9, 14.7],
    category: ContentCategory.history,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<City>(),
    media: ToMany<Media>(),
  );
}

Place _place({required int remoteId, required String name}) {
  final now = DateTime.utc(2026, 4, 2);

  return Place(
    remoteId: remoteId,
    name: name,
    description: 'Description',
    coordinates: const [41.9, 14.7],
    category: ContentCategory.nature,
    createdAt: now,
    modifiedAt: now,
    city: ToOne<City>(),
    media: ToMany<Media>(),
  );
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
