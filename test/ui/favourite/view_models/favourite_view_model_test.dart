import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  test(
    'load requested during a write remains unavailable after write settles',
    () async {
      final write = Completer<Result<void>>();
      var queries = 0;
      final places = FakePlaceRepository(
        getFavouritePlaceIdsHandler: () async {
          queries++;
          return const Result.success([]);
        },
        setFavouritePlaceHandler: (_, {required save}) => write.future,
      );
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: places,
        ),
      );
      addTearDown(vm.dispose);
      await pumpEventQueue();
      final mutation = vm.setFavourite(makePlace(), save: true);
      final loading = vm.load.runAsync();
      vm.load.run();
      expect(vm.load.runAsync(), same(loading));
      write.complete(const Result.success(null));
      await mutation;
      await loading;
      expect(vm.load.results.value.hasFailure, isTrue);
      expect(queries, 1);
      expect(
        vm.load.results.value.domainError.toString(),
        contains('another update'),
      );
      expect(await vm.load.runAsync(), isA<Success<void>>());
      expect(queries, 2);
    },
  );

  test('load admission rejects write before the first notification', () async {
    final places = FakePlaceRepository();
    final vm = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: places,
      ),
    );
    addTearDown(vm.dispose);
    expect(vm.load.isRunningSync.value, isTrue);
    expect(await vm.setFavourite(makePlace(), save: true), isA<Error<void>>());
    expect(places.setFavouritePlaceCalls, isEmpty);
    expect(vm.favouritePlaceIds, isEmpty);
    await pumpEventQueue();
  });

  test(
    'places publish progressively before pending events and first failure wins',
    () async {
      final gate = Completer<Result<List<int>>>();
      final places = FakePlaceRepository(
        getFavouritePlaceIdsResult: const Result.success([1, 1, 2]),
        getByIdResults: {
          1: Result.success(makePlace()),
          2: Result.error(TestException('missing')),
        },
      );
      final events = FakeEventRepository()
        ..getFavouriteEventIdsHandler = () => gate.future;
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      addTearDown(vm.dispose);
      await pumpEventQueue();
      expect(vm.load.isRunningSync.value, isTrue);
      expect(vm.favouritePlaceIds, [1, 2]);
      expect(vm.favouritePlaces.map((p) => p.remoteId), [1]);
      expect(vm.isFavourite(makePlace(remoteId: 2)), isTrue);
      final failure = TestException('events failed');
      gate.complete(Result.error(failure));
      await pumpEventQueue();
      expect(vm.load.results.value.domainError, same(failure));
      expect(vm.favouritePlaceIds, [1, 2]);
      final first = TestException('places failed');
      places.getFavouritePlaceIdsResult = Result.error(first);
      events
        ..getFavouriteEventIdsHandler = null
        ..getFavouriteEventIdsResult = Result.error(TestException('second'));
      await vm.load.runAsync();
      expect(vm.load.results.value.domainError, same(first));
      expect(vm.favouritePlaceIds, [1, 2]);
    },
  );

  test(
    'reentrant optimistic disposal starts no write and rejects future writes',
    () async {
      final places = FakePlaceRepository();
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: places,
        ),
      );
      await pumpEventQueue();
      vm.addListener(vm.dispose);
      expect(
        await vm.setFavourite(makePlace(), save: true),
        isA<Error<void>>(),
      );
      expect(places.setFavouritePlaceCalls, isEmpty);
      expect(
        await vm.setFavourite(makePlace(remoteId: 2), save: true),
        isA<Error<void>>(),
      );
      expect(vm.favouritePlaceIds, [1]);
    },
  );

  test(
    'reentrant partial publication disposal starts no events phase',
    () async {
      final places = FakePlaceRepository(
        getFavouritePlaceIdsResult: const Result.success([1]),
        getByIdResults: {1: Result.success(makePlace())},
      );
      final events = FakeEventRepository();
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      vm.addListener(() {
        if (vm.favouritePlaceIds.isNotEmpty) vm.dispose();
      });
      await pumpEventQueue();
      expect(events.getFavouriteEventIdsCallCount, 0);
      expect(vm.favouritePlaceIds, [1]);
    },
  );

  test(
    'disposal during place lookup prevents publication and all subsequent I/O',
    () async {
      final gate = Completer<Result<Place>>();
      final places = FakePlaceRepository(
        getFavouritePlaceIdsResult: const Result.success([1, 2]),
      );
      places.pendingGetById[1] = gate;
      final events = FakeEventRepository();
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpEventQueue();
      expect(places.getByIdCallCount, 1);
      vm.dispose();
      gate.complete(Result.success(makePlace()));
      await pumpEventQueue();
      expect(places.getByIdCallCount, 1);
      expect(events.getFavouriteEventIdsCallCount, 0);
      expect(vm.favouritePlaceIds, isEmpty);
    },
  );

  test(
    'direct write preserves a late unexpected throw without global reporting',
    () async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final gate = Completer<Result<void>>();
      final places = FakePlaceRepository(
        setFavouritePlaceHandler: (_, {required save}) => gate.future,
      );
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: places,
        ),
      );
      await pumpEventQueue();
      final write = vm.setFavourite(makePlace(), save: true);
      final original = StateError('direct write failed late');
      final observed = expectLater(write, throwsA(same(original)));
      vm.dispose();
      gate.completeError(original);
      await observed;
      expect(vm.favouritePlaceIds, [1]);
      expect(logger.calls, isEmpty);
    },
  );

  test(
    'dispose during event lookup retains published places and skips next event',
    () async {
      final gate = Completer<Result<Event>>();
      final places = FakePlaceRepository(
        getFavouritePlaceIdsResult: const Result.success([1]),
        getByIdResults: {1: Result.success(makePlace())},
      );
      final events = FakeEventRepository(
        getFavouriteEventIdsResult: const Result.success([1, 2]),
      );
      events.pendingGetById[1] = gate;
      final vm = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpEventQueue();
      expect(vm.favouritePlaceIds, [1]);
      expect(events.getByIdCallCount, 1);
      vm.dispose();
      gate.complete(Result.success(makeEvent()));
      await pumpEventQueue();
      expect(vm.favouritePlaceIds, [1]);
      expect(vm.favouriteEventIds, isEmpty);
      expect(events.getByIdCallCount, 1);
    },
  );

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

      expect(viewModel.load.results.value.completed, isTrue);
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

      expect(viewModel.load.results.value.hasFailure, isTrue);
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

      expect(viewModel.load.results.value.hasFailure, isTrue);
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

      await viewModel.load.runAsync();

      expect(viewModel.load.results.value.completed, isTrue);
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
            getByIdResults: {1: Result.error(TestException('event not found'))},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);

      await pumpEventQueue(times: 10);

      expect(viewModel.load.results.value.completed, isTrue);
      expect(viewModel.favouriteEventIds, equals([1]));
      expect(viewModel.favouriteEvents, isEmpty);
    });
  });

  group('FavouriteViewModel setFavourite', () {
    test('updates an event before its write completes', () async {
      final pendingWrite = Completer<Result<void>>();
      final event = makeEvent();
      final eventRepository = FakeEventRepository(
        setFavouriteEventHandler: (_, {required save}) => pendingWrite.future,
      );
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);
      await pumpEventQueue(times: 10);

      final result = viewModel.setFavourite(event, save: true);

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
          setFavouriteEventHandler: (_, {required save}) => pendingWrite.future,
        );
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: eventRepository,
            placeRepository: FakePlaceRepository(),
          ),
        );
        addTearDown(viewModel.dispose);
        await pumpEventQueue(times: 10);

        final result = viewModel.setFavourite(event, save: false);

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

        await viewModel.setFavourite(event, save: true);
        await viewModel.setFavourite(place, save: true);

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

      final result = await viewModel.setFavourite(event, save: true);

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

      final result = await viewModel.setFavourite(place, save: true);

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

      final result = await viewModel.setFavourite(events[1], save: false);

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

        final result = await viewModel.setFavourite(places[1], save: false);

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

      final result = await viewModel.setFavourite(event, save: true);

      expect(viewModel.load.isRunningSync.value, isTrue);
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
        setFavouriteEventHandler: (_, {required save}) => pendingWrite.future,
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

      final firstResult = viewModel.setFavourite(event, save: true);
      final secondResult = await viewModel.setFavourite(place, save: true);

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
    testOwnerUI(
      'is safe when a pending initial load completes after disposal',
      (tester) async {
        final pendingPlaceIds = Completer<Result<List<int>>>();
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: FakeEventRepository(),
            placeRepository: FakePlaceRepository(
              getFavouritePlaceIdsHandler: () => pendingPlaceIds.future,
            ),
          ),
        );

        expect(viewModel.load.isRunningSync.value, isTrue);
        viewModel.dispose();
        pendingPlaceIds.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        await pumpCommandTurns(tester);

        expect(viewModel.load.isRunningSync.value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    for (final persistenceResult in <Result<void>>[
      const Result<void>.success(null),
      Result<void>.error(TestException('write failed')),
    ]) {
      testOwnerUI('is safe when a pending write completes with '
          '${persistenceResult.isSuccess ? 'success' : 'an error'}'
          ' after disposal', (tester) async {
        final pendingWrite = Completer<Result<void>>();
        final event = makeEvent();
        final viewModel = FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: FakeEventRepository(
              setFavouriteEventHandler: (_, {required save}) =>
                  pendingWrite.future,
            ),
            placeRepository: FakePlaceRepository(),
          ),
        );
        await pumpCommandTurns(tester);

        final write = viewModel.setFavourite(event, save: true);
        expect(viewModel.isUpdating, isTrue);
        viewModel.dispose();
        pendingWrite.complete(persistenceResult);

        expect((await write).isSuccess, persistenceResult.isSuccess);
        await pumpCommandTurns(tester);

        expect(viewModel.favouriteEventIds, [event.remoteId]);
        expect(viewModel.favouriteEvents, [event]);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
