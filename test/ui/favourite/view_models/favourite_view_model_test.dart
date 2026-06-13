import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('FavouriteViewModel', () {
    group('load', () {
      test('populates both lists on full success', () async {
        final event1 = makeEvent();
        final place1 = makePlace(remoteId: 10);
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouriteEventIdsResult: const Result.success([1]),
            favouritePlaceIdsResult: const Result.success([10]),
            eventResults: {1: Result.success(event1)},
            placeResults: {10: Result.success(place1)},
          ),
        );

        expect(vm.load.completed, isTrue);
        expect(vm.favouriteEventIds, equals([1]));
        expect(vm.favouriteEvents, hasLength(1));
        expect(vm.favouriteEvents.first.remoteId, equals(1));
        expect(vm.favouritePlaceIds, equals([10]));
        expect(vm.favouritePlaces, hasLength(1));
        expect(vm.favouritePlaces.first.remoteId, equals(10));
      });

      test(
        'leaves place list empty and surfaces error when places fetch fails',
        () async {
          final vm = await _buildLoaded(
            _FakeFavouriteGetIdsUseCase(
              favouritePlaceIdsResult: Result.error(
                TestException('places failed'),
              ),
              // Events are still fetched even when places fail.
              favouriteEventIdsResult: const Result.success([1]),
              eventResults: {1: Result.success(makeEvent())},
            ),
          );

          expect(vm.load.error, isTrue);
          expect(vm.load.result, isA<Error<void>>());
          expect(vm.favouritePlaceIds, isEmpty);
          expect(vm.favouritePlaces, isEmpty);
          expect(vm.favouriteEventIds, equals([1]));
          expect(vm.favouriteEvents, hasLength(1));
        },
      );

      test(
        'leaves event list empty and surfaces error when events fetch fails',
        () async {
          final vm = await _buildLoaded(
            _FakeFavouriteGetIdsUseCase(
              favouritePlaceIdsResult: const Result.success([10]),
              placeResults: {10: Result.success(makePlace(remoteId: 10))},
              favouriteEventIdsResult: Result.error(
                TestException('events failed'),
              ),
            ),
          );

          expect(vm.load.error, isTrue);
          expect(vm.load.result, isA<Error<void>>());
          expect(vm.favouriteEventIds, isEmpty);
          expect(vm.favouriteEvents, isEmpty);
          expect(vm.favouritePlaceIds, equals([10]));
          expect(vm.favouritePlaces, hasLength(1));
        },
      );

      test('returns places error when both fetches fail', () async {
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouritePlaceIdsResult: Result.error(
              TestException('places failed'),
            ),
            favouriteEventIdsResult: Result.error(
              TestException('events failed'),
            ),
          ),
        );

        expect(vm.load.error, isTrue);
        expect(vm.favouritePlaceIds, isEmpty);
        expect(vm.favouriteEventIds, isEmpty);
      });

      test(
        'leaves content list empty when getById fails (id is kept)',
        () async {
          final vm = await _buildLoaded(
            _FakeFavouriteGetIdsUseCase(
              favouriteEventIdsResult: const Result.success([1]),
              // getEventById fails → content not added, but ID is still in the
              // list.
              eventResults: {1: Result.error(TestException('not found'))},
            ),
          );

          expect(vm.load.completed, isTrue);
          expect(vm.favouriteEventIds, equals([1]));
          expect(vm.favouriteEvents, isEmpty);
        },
      );
    });

    group('addEvent', () {
      test('adds id optimistically then fetches content on success', () async {
        final event1 = makeEvent();
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            eventResults: {1: Result.success(event1)},
          ),
        );

        await vm.addEvent.execute(1);

        expect(vm.addEvent.completed, isTrue);
        expect(vm.favouriteEventIds, contains(1));
        expect(vm.favouriteEvents, hasLength(1));
        expect(vm.favouriteEvents.first.remoteId, equals(1));
      });

      test('rolls back id when persist fails', () async {
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            setEventResult: Result.error(TestException('write failed')),
          ),
        );

        await vm.addEvent.execute(1);

        expect(vm.addEvent.error, isTrue);
        expect(vm.favouriteEventIds, isEmpty);
        expect(vm.favouriteEvents, isEmpty);
      });
    });

    group('addPlace', () {
      test('adds id optimistically then fetches content on success', () async {
        final place1 = makePlace(remoteId: 10);
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            placeResults: {10: Result.success(place1)},
          ),
        );

        await vm.addPlace.execute(10);

        expect(vm.addPlace.completed, isTrue);
        expect(vm.favouritePlaceIds, contains(10));
        expect(vm.favouritePlaces, hasLength(1));
        expect(vm.favouritePlaces.first.remoteId, equals(10));
      });

      test('rolls back id when persist fails', () async {
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            setPlaceResult: Result.error(TestException('write failed')),
          ),
        );

        await vm.addPlace.execute(10);

        expect(vm.addPlace.error, isTrue);
        expect(vm.favouritePlaceIds, isEmpty);
        expect(vm.favouritePlaces, isEmpty);
      });
    });

    group('removeEvent', () {
      test('removes id and content on success', () async {
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouriteEventIdsResult: const Result.success([1]),
            eventResults: {1: Result.success(makeEvent())},
          ),
        );

        await vm.removeEvent.execute(1);

        expect(vm.removeEvent.completed, isTrue);
        expect(vm.favouriteEventIds, isEmpty);
        expect(vm.favouriteEvents, isEmpty);
      });

      test('restores id and content when persist fails', () async {
        final event1 = makeEvent();
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouriteEventIdsResult: const Result.success([1]),
            eventResults: {1: Result.success(event1)},
            setEventResult: Result.error(TestException('delete failed')),
          ),
        );

        await vm.removeEvent.execute(1);

        expect(vm.removeEvent.error, isTrue);
        expect(vm.favouriteEventIds, contains(1));
        expect(vm.favouriteEvents, hasLength(1));
        expect(vm.favouriteEvents.first.remoteId, equals(1));
      });
    });

    group('removePlace', () {
      test('removes id and content on success', () async {
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouritePlaceIdsResult: const Result.success([10]),
            placeResults: {10: Result.success(makePlace(remoteId: 10))},
          ),
        );

        await vm.removePlace.execute(10);

        expect(vm.removePlace.completed, isTrue);
        expect(vm.favouritePlaceIds, isEmpty);
        expect(vm.favouritePlaces, isEmpty);
      });

      test('restores id and content when persist fails', () async {
        final place1 = makePlace(remoteId: 10);
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouritePlaceIdsResult: const Result.success([10]),
            placeResults: {10: Result.success(place1)},
            setPlaceResult: Result.error(TestException('delete failed')),
          ),
        );

        await vm.removePlace.execute(10);

        expect(vm.removePlace.error, isTrue);
        expect(vm.favouritePlaceIds, contains(10));
        expect(vm.favouritePlaces, hasLength(1));
        expect(vm.favouritePlaces.first.remoteId, equals(10));
      });
    });

    group('isFavourite', () {
      test('returns true for a loaded event', () async {
        final event1 = makeEvent();
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouriteEventIdsResult: const Result.success([1]),
            eventResults: {1: Result.success(event1)},
          ),
        );

        expect(vm.isFavourite(event1), isTrue);
      });

      test('returns true for a loaded place', () async {
        final place1 = makePlace(remoteId: 10);
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouritePlaceIdsResult: const Result.success([10]),
            placeResults: {10: Result.success(place1)},
          ),
        );

        expect(vm.isFavourite(place1), isTrue);
      });

      test('returns false for an event not in the list', () async {
        final event1 = makeEvent();
        final event2 = makeEvent(remoteId: 2);
        final vm = await _buildLoaded(
          _FakeFavouriteGetIdsUseCase(
            favouriteEventIdsResult: const Result.success([1]),
            eventResults: {1: Result.success(event1)},
          ),
        );

        expect(vm.isFavourite(event2), isFalse);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helpers
// ---------------------------------------------------------------------------

Future<FavouriteViewModel> _buildLoaded(
  _FakeFavouriteGetIdsUseCase useCase,
) async {
  final vm = FavouriteViewModel(favouriteGetIdsUseCase: useCase);
  await pumpEventQueue();
  return vm;
}

// ---------------------------------------------------------------------------
// Fake use case
// ---------------------------------------------------------------------------

final class _FakeFavouriteGetIdsUseCase implements FavouriteGetIdsUseCase {
  _FakeFavouriteGetIdsUseCase({
    Result<List<int>>? favouriteEventIdsResult,
    Result<List<int>>? favouritePlaceIdsResult,
    Map<int, Result<Event>> eventResults = const {},
    Map<int, Result<Place>> placeResults = const {},
    Result<void>? setEventResult,
    Result<void>? setPlaceResult,
  }) : _favouriteEventIdsResult =
           favouriteEventIdsResult ?? const Result.success([]),
       _favouritePlaceIdsResult =
           favouritePlaceIdsResult ?? const Result.success([]),
       _eventResults = eventResults,
       _placeResults = placeResults,
       _setEventResult = setEventResult ?? const Result.success(null),
       _setPlaceResult = setPlaceResult ?? const Result.success(null);

  final Result<List<int>> _favouriteEventIdsResult;
  final Result<List<int>> _favouritePlaceIdsResult;
  final Map<int, Result<Event>> _eventResults;
  final Map<int, Result<Place>> _placeResults;
  final Result<void> _setEventResult;
  final Result<void> _setPlaceResult;

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async =>
      _favouriteEventIdsResult;

  @override
  Future<Result<List<int>>> getFavouritePlaceIds() async =>
      _favouritePlaceIdsResult;

  @override
  Future<Result<Event>> getEventById(int id) async =>
      _eventResults[id] ??
      Result.error(TestException('event $id not configured'));

  @override
  Future<Result<Place>> getPlaceById(int id) async =>
      _placeResults[id] ??
      Result.error(TestException('place $id not configured'));

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async =>
      _setEventResult;

  @override
  Future<Result<void>> setFavouritePlace(int id, bool save) async =>
      _setPlaceResult;
}
