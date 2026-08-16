import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('FavouriteViewModel load', () {
    test('populates both lists on full success', () async {
      final event = makeEvent();
      final place = makePlace(remoteId: 10);
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getFavouriteEventIdsResult: const Result.success([1]),
            getByIdResults: {1: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(
            getFavouritePlaceIdsResult: const Result.success([10]),
            getByIdResults: {10: Result.success(place)},
          ),
        ),
      );
      addTearDown(viewModel.dispose);

      await pumpEventQueue(times: 10);

      expect(viewModel.load.completed, isTrue);
      expect(viewModel.favouriteEventIds, equals([1]));
      expect(viewModel.favouriteEvents, equals([event]));
      expect(viewModel.favouritePlaceIds, equals([10]));
      expect(viewModel.favouritePlaces, equals([place]));
    });

    test('preserves successful events when the place ID read fails', () async {
      final event = makeEvent();
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getFavouriteEventIdsResult: const Result.success([1]),
            getByIdResults: {1: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(
            getFavouritePlaceIdsResult: Result.error(
              TestException('places failed'),
            ),
          ),
        ),
      );
      addTearDown(viewModel.dispose);

      await pumpEventQueue(times: 10);

      expect(viewModel.load.error, isTrue);
      expect(viewModel.favouritePlaceIds, isEmpty);
      expect(viewModel.favouriteEvents, equals([event]));
    });

    test('preserves successful places when the event ID read fails', () async {
      final place = makePlace(remoteId: 10);
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getFavouriteEventIdsResult: Result.error(
              TestException('events failed'),
            ),
          ),
          placeRepository: FakePlaceRepository(
            getFavouritePlaceIdsResult: const Result.success([10]),
            getByIdResults: {10: Result.success(place)},
          ),
        ),
      );
      addTearDown(viewModel.dispose);

      await pumpEventQueue(times: 10);

      expect(viewModel.load.error, isTrue);
      expect(viewModel.favouriteEventIds, isEmpty);
      expect(viewModel.favouritePlaces, equals([place]));
    });

    test('replaces collections when a load is retried', () async {
      final firstEvent = makeEvent();
      final firstPlace = makePlace(remoteId: 10);
      final secondEvent = makeEvent(remoteId: 2);
      final secondPlace = makePlace(remoteId: 20);
      final eventRepository = FakeEventRepository(
        getFavouriteEventIdsResult: const Result.success([1]),
        getByIdResults: {1: Result.success(firstEvent)},
      );
      final placeRepository = FakePlaceRepository(
        getFavouritePlaceIdsResult: const Result.success([10]),
        getByIdResults: {10: Result.success(firstPlace)},
      );
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: placeRepository,
        ),
      );
      addTearDown(viewModel.dispose);

      await pumpEventQueue(times: 10);
      eventRepository
        ..getFavouriteEventIdsResult = const Result.success([2])
        ..getByIdResults = {2: Result.success(secondEvent)};
      placeRepository
        ..getFavouritePlaceIdsResult = const Result.success([20])
        ..getByIdResults = {20: Result.success(secondPlace)};

      await viewModel.load.execute();

      expect(viewModel.load.completed, isTrue);
      expect(viewModel.favouriteEventIds, equals([2]));
      expect(viewModel.favouriteEvents, equals([secondEvent]));
      expect(viewModel.favouritePlaceIds, equals([20]));
      expect(viewModel.favouritePlaces, equals([secondPlace]));
    });

    test('keeps an ID when its full content cannot be fetched', () async {
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getFavouriteEventIdsResult: const Result.success([1]),
            getByIdResults: {
              1: Result.error(TestException('event not found')),
            },
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);

      await pumpEventQueue(times: 10);

      expect(viewModel.load.completed, isTrue);
      expect(viewModel.favouriteEventIds, equals([1]));
      expect(viewModel.favouriteEvents, isEmpty);
    });
  });

  group('FavouriteViewModel setFavourite', () {
    test('updates an event before its write completes', () async {
      final pendingWrite = Completer<Result<void>>();
      final event = makeEvent();
      final eventRepository = FakeEventRepository(
        setFavouriteEventHandler: (_, _) => pendingWrite.future,
      );
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue(times: 10);

      final result = viewModel.setFavourite(event, true);

      expect(viewModel.isFavourite(event), isTrue);
      expect(viewModel.isUpdating, isTrue);
      expect(viewModel.favouriteEvents, equals([event]));
      expect(
        eventRepository.setFavouriteEventCalls,
        equals([(id: 1, save: true)]),
      );

      pendingWrite.complete(const Result.success(null));

      expect(await result, isA<Success<void>>());
      expect(viewModel.isUpdating, isFalse);
    });

    test(
      'updates an existing favourite before its removal completes',
      () async {
        final pendingWrite = Completer<Result<void>>();
        final event = makeEvent(isSaved: true);
        final eventRepository = FakeEventRepository(
          getFavouriteEventIdsResult: const Result.success([1]),
          getByIdResults: {1: Result.success(event)},
          setFavouriteEventHandler: (_, _) => pendingWrite.future,
        );
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: eventRepository,
            placeRepository: FakePlaceRepository(),
          ),
        );
        addTearDown(viewModel.dispose);
        await pumpEventQueue(times: 10);

        final result = viewModel.setFavourite(event, false);

        expect(viewModel.isFavourite(event), isFalse);
        expect(viewModel.isUpdating, isTrue);
        expect(viewModel.favouriteEvents, isEmpty);
        expect(
          eventRepository.setFavouriteEventCalls,
          equals([(id: 1, save: false)]),
        );

        pendingWrite.complete(const Result.success(null));

        expect(await result, isA<Success<void>>());
        expect(viewModel.isUpdating, isFalse);
      },
    );

    test(
      'dispatches event and place writes to their matching use-case method',
      () async {
        final event = makeEvent();
        final place = makePlace(remoteId: 2);
        final eventRepository = FakeEventRepository();
        final placeRepository = FakePlaceRepository();
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: eventRepository,
            placeRepository: placeRepository,
          ),
        );
        addTearDown(viewModel.dispose);
        await pumpEventQueue(times: 10);

        await viewModel.setFavourite(event, true);
        await viewModel.setFavourite(place, true);

        expect(
          eventRepository.setFavouriteEventCalls,
          equals([(id: 1, save: true)]),
        );
        expect(
          placeRepository.setFavouritePlaceCalls,
          equals([(id: 2, save: true)]),
        );
      },
    );

    test('rolls back an add when persistence returns an error', () async {
      final event = makeEvent();
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            setFavouriteEventResult: Result.error(
              TestException('write failed'),
            ),
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue(times: 10);

      final result = await viewModel.setFavourite(event, true);

      expect(result, isA<Error<void>>());
      expect(viewModel.favouriteEventIds, isEmpty);
      expect(viewModel.favouriteEvents, isEmpty);
    });

    test('rolls back a place add when persistence returns an error', () async {
      final place = makePlace(remoteId: 10);
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: FakePlaceRepository(
            setFavouritePlaceResult: Result.error(
              TestException('write failed'),
            ),
          ),
        ),
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue(times: 10);

      final result = await viewModel.setFavourite(place, true);

      expect(result, isA<Error<void>>());
      expect(viewModel.favouritePlaceIds, isEmpty);
      expect(viewModel.favouritePlaces, isEmpty);
    });

    test('restores an unsuccessful removal at its original position', () async {
      final events = [
        makeEvent(),
        makeEvent(remoteId: 2),
        makeEvent(remoteId: 3),
      ];
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getFavouriteEventIdsResult: const Result.success([1, 2, 3]),
            getByIdResults: {
              for (final event in events) event.remoteId: Result.success(event),
            },
            setFavouriteEventResult: Result.error(
              TestException('delete failed'),
            ),
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue(times: 10);

      final result = await viewModel.setFavourite(events[1], false);

      expect(result, isA<Error<void>>());
      expect(viewModel.favouriteEventIds, equals([1, 2, 3]));
      expect(viewModel.favouriteEvents, equals(events));
    });

    test(
      'restores an unsuccessful place removal at its original position',
      () async {
        final places = [
          makePlace(remoteId: 10),
          makePlace(remoteId: 20),
          makePlace(remoteId: 30),
        ];
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: FakeEventRepository(),
            placeRepository: FakePlaceRepository(
              getFavouritePlaceIdsResult: const Result.success([10, 20, 30]),
              getByIdResults: {
                for (final place in places)
                  place.remoteId: Result.success(place),
              },
              setFavouritePlaceResult: Result.error(
                TestException('delete failed'),
              ),
            ),
          ),
        );
        addTearDown(viewModel.dispose);
        await pumpEventQueue(times: 10);

        final result = await viewModel.setFavourite(places[1], false);

        expect(result, isA<Error<void>>());
        expect(viewModel.favouritePlaceIds, equals([10, 20, 30]));
        expect(viewModel.favouritePlaces, equals(places));
      },
    );

    test('rejects a mutation while the initial load is unresolved', () async {
      final pendingPlaceIds = Completer<Result<List<int>>>();
      final event = makeEvent();
      final eventRepository = FakeEventRepository();
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(
            getFavouritePlaceIdsHandler: () => pendingPlaceIds.future,
          ),
        ),
      );
      addTearDown(viewModel.dispose);

      final result = await viewModel.setFavourite(event, true);

      expect(viewModel.load.running, isTrue);
      expect(viewModel.isUpdating, isTrue);
      expect(result, isA<Error<void>>());
      expect(eventRepository.setFavouriteEventCalls, isEmpty);

      pendingPlaceIds.complete(const Result.success([]));
      await pumpEventQueue(times: 10);
    });

    test('rejects a second mutation while a write is pending', () async {
      final pendingWrite = Completer<Result<void>>();
      final event = makeEvent();
      final place = makePlace(remoteId: 2);
      final eventRepository = FakeEventRepository(
        setFavouriteEventHandler: (_, _) => pendingWrite.future,
      );
      final placeRepository = FakePlaceRepository();
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: placeRepository,
        ),
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue(times: 10);

      final firstResult = viewModel.setFavourite(event, true);
      final secondResult = await viewModel.setFavourite(place, true);

      expect(secondResult, isA<Error<void>>());
      expect(
        eventRepository.setFavouriteEventCalls,
        equals([(id: 1, save: true)]),
      );
      expect(placeRepository.setFavouritePlaceCalls, isEmpty);

      pendingWrite.complete(const Result.success(null));
      expect(await firstResult, isA<Success<void>>());
    });
  });

  group('FavouriteViewModel disposal', () {
    testWidgets(
      'is safe when a pending initial load completes after disposal',
      (
        tester,
      ) async {
        final pendingPlaceIds = Completer<Result<List<int>>>();
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: FakeEventRepository(),
            placeRepository: FakePlaceRepository(
              getFavouritePlaceIdsHandler: () => pendingPlaceIds.future,
            ),
          ),
        );

        expect(viewModel.load.running, isTrue);
        viewModel.dispose();
        pendingPlaceIds.complete(const Result.success([]));
        await tester.pump();
        await tester.pump();

        expect(viewModel.load.running, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    for (final persistenceResult in <Result<void>>[
      const Result<void>.success(null),
      Result<void>.error(TestException('write failed')),
    ]) {
      testWidgets(
        'is safe when a pending write completes with '
        '${persistenceResult.isSuccess ? 'success' : 'an error'}'
        ' after disposal',
        (tester) async {
          final pendingWrite = Completer<Result<void>>();
          final event = makeEvent();
          final viewModel = FavouriteViewModel(
            favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
              eventRepository: FakeEventRepository(
                setFavouriteEventHandler: (_, _) => pendingWrite.future,
              ),
              placeRepository: FakePlaceRepository(),
            ),
          );
          await tester.pump();

          final write = viewModel.setFavourite(event, true);
          expect(viewModel.isUpdating, isTrue);
          viewModel.dispose();
          pendingWrite.complete(persistenceResult);

          expect((await write).isSuccess, persistenceResult.isSuccess);
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
