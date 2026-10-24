// Sequential command assertions keep temporal regressions readable.
// ignore_for_file: cascade_invocations

import 'dart:async' show Completer, runZonedGuarded;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_mode.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_selection_intent.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  const coordinates = LatLng(41.56, 14.66);

  test(
    'disposal during filter reload skips the remaining collection load',
    () async {
      final events = FakeEventRepository();
      final places = FakePlaceRepository();
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpEventQueue();
      expect(events.getByCurrentYearCallCount, 1);
      expect(places.getAllCallCount, 1);

      final pending = Completer<Result<List<Event>>>();
      events.pendingGetByCurrentYear = pending;
      vm.setSelectedCategories({ContentCategory.nature});
      await pumpEventQueue();
      expect(events.getByCurrentYearCallCount, 2);
      vm.dispose();
      pending.complete(Result.success(<Event>[makeEvent()]));
      await pumpEventQueue();

      expect(places.getAllCallCount, 1);
      expect(vm.allEvents, isEmpty);
      expect(vm.isDisposed, isTrue);
    },
  );

  for (final firstPending in [true, false]) {
    testWidgets(
      'Nearby disposal after ${firstPending ? 'first' : 'second'} fetch '
      'publishes nothing',
      (tester) async {
        final events = FakeEventRepository();
        final places = FakePlaceRepository();
        final pendingPlaces = Completer<Result<List<Place>>>();
        final pendingEvents = Completer<Result<List<Event>>>();
        if (firstPending) {
          places.pendingGetByCoordinates = pendingPlaces;
        } else {
          places.getByCoordinatesResult = Result.success([makePlace()]);
          events.pendingGetByCoordinates = pendingEvents;
        }
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: places,
          ),
        );
        await pumpCommandTurns(tester);
        vm.showExplore(coordinates);
        vm.requestNearby(vm.nearbyTarget!);
        await pumpCommandTurns(tester);
        expect(vm.nearContent, isEmpty);
        var notifications = 0;
        vm.addListener(() => notifications++);
        vm.dispose();
        if (firstPending) {
          pendingPlaces.complete(Result.success([makePlace()]));
        } else {
          pendingEvents.complete(Result.success([makeEvent()]));
        }
        await pumpCommandTurns(tester);
        // Fetch-only actions may settle physically.
        // They cannot commit after disposal.
        expect(events.getByCoordinatesCallCount, 1);
        expect(vm.nearContent, isEmpty);
        expect(vm.nearbyTerminal, isNull);
        expect(notifications, 0);
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }

  test(
    'shared payload matching rejects wrong id, type and null before commit',
    () {
      final event = makeEvent();
      final place = makePlace();
      expect(const EventSelection(1).matchesPayload(event), isTrue);
      expect(const PlaceSelection(1).matchesPayload(place), isTrue);
      expect(const EventSelection(2).matchesPayload(event), isFalse);
      expect(const PlaceSelection(2).matchesPayload(place), isFalse);
      expect(const EventSelection(1).matchesPayload(place), isFalse);
      expect(const PlaceSelection(1).matchesPayload(event), isFalse);
      expect(const EventSelection(1).matchesPayload(null), isFalse);
      expect(const PlaceSelection(1).matchesPayload(null), isFalse);
      expect(const ClearSelection().matchesPayload(null), isTrue);
      expect(const ClearSelection().matchesPayload(event), isFalse);
      expect(const ClearSelection().matchesPayload(place), isFalse);
    },
  );

  for (final firstEvent in [false, true]) {
    for (final secondEvent in [false, true]) {
      for (final staleOutcome in ['success', 'domain', 'runtime']) {
        testWidgets(
          '${firstEvent ? 'event' : 'place'} A to '
          '${secondEvent ? 'event' : 'place'} B ignores stale $staleOutcome',
          (tester) async {
            final logger = MockLogger();
            addTearDown(installCommandTestReporting(logger));
            final events = FakeEventRepository();
            final places = FakePlaceRepository();
            final aEvent = Completer<Result<Event>>();
            final bEvent = Completer<Result<Event>>();
            final aPlace = Completer<Result<Place>>();
            final bPlace = Completer<Result<Place>>();
            if (firstEvent) {
              events.pendingGetById[1] = aEvent;
            } else {
              places.pendingGetById[1] = aPlace;
            }
            if (secondEvent) {
              events.pendingGetById[2] = bEvent;
            } else {
              places.pendingGetById[2] = bPlace;
            }
            final vm = GeoMapViewModel(
              geoMapUseCase: GeoMapUseCase(
                eventRepository: events,
                placeRepository: places,
              ),
            );
            await pumpCommandTurns(tester);
            var commits = 0;
            vm.addListener(() => commits++);
            vm.requestSelection(
              firstEvent ? const EventSelection(1) : const PlaceSelection(1),
            );
            await pumpCommandTurns(tester);
            vm.requestSelection(
              secondEvent ? const EventSelection(2) : const PlaceSelection(2),
            );
            await pumpCommandTurns(tester);
            expect(events.getByIdCallCount + places.getByIdCallCount, 2);
            final latest = secondEvent
                ? makeEvent(remoteId: 2)
                : makePlace(remoteId: 2);
            if (secondEvent) {
              bEvent.complete(Result.success(latest as Event));
            } else {
              bPlace.complete(Result.success(latest as Place));
            }
            await pumpCommandTurns(tester);
            expect(vm.selectedContent, same(latest));
            expect(vm.selectContent.isRunningSync.value, isFalse);
            expect(commits, 3);
            final domain = TestException('obsolete');
            final failure = StateError('obsolete runtime');
            if (staleOutcome == 'runtime') {
              if (firstEvent) {
                aEvent.completeError(failure, StackTrace.current);
              } else {
                aPlace.completeError(failure, StackTrace.current);
              }
            } else if (firstEvent) {
              aEvent.complete(
                staleOutcome == 'domain'
                    ? Result.error(domain)
                    : Result.success(makeEvent()),
              );
            } else {
              aPlace.complete(
                staleOutcome == 'domain'
                    ? Result.error(domain)
                    : Result.success(makePlace()),
              );
            }
            await pumpCommandTurns(tester);
            expect(vm.selectedContent, same(latest));
            expect(commits, 3);
            expect(vm.selectContent.results.value.completed, isTrue);
            expect(logger.calls, hasLength(staleOutcome == 'runtime' ? 1 : 0));
            if (staleOutcome == 'runtime') {
              expect(logger.calls.single.error, same(failure));
            }
            vm.dispose();
            await tester.pump(const Duration(milliseconds: 50));
          },
        );
      }
    }
  }

  for (final event in [false, true]) {
    testWidgets('pending ${event ? 'event' : 'place'} to clear remains null', (
      tester,
    ) async {
      final events = FakeEventRepository();
      final places = FakePlaceRepository();
      final pendingEvent = Completer<Result<Event>>();
      final pendingPlace = Completer<Result<Place>>();
      if (event) {
        events.pendingGetById[1] = pendingEvent;
      } else {
        places.pendingGetById[1] = pendingPlace;
      }
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestSelection(
        event ? const EventSelection(1) : const PlaceSelection(1),
      );
      await pumpCommandTurns(tester);
      vm.invalidateRequestedSelection();
      expect(vm.selectedContent, isNull);
      await pumpCommandTurns(tester);
      if (event) {
        pendingEvent.complete(Result.success(makeEvent()));
      } else {
        pendingPlace.complete(Result.success(makePlace()));
      }
      await pumpCommandTurns(tester);
      expect(vm.selectedContent, isNull);
      expect(vm.selectContent.results.value.idle, isTrue);
      expect(events.getByIdCallCount + places.getByIdCallCount, 1);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('wrong ${event ? 'event' : 'place'} identity never commits', (
      tester,
    ) async {
      final events = FakeEventRepository(
        getByIdResults: {1: Result.success(makeEvent(remoteId: 2))},
      );
      final places = FakePlaceRepository(
        getByIdResults: {1: Result.success(makePlace(remoteId: 2))},
      );
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpCommandTurns(tester);
      var commits = 0;
      vm.addListener(() => commits++);
      vm.requestSelection(
        event ? const EventSelection(1) : const PlaceSelection(1),
      );
      await pumpCommandTurns(tester);
      expect(vm.selectedContent, isNull);
      expect(commits, 1);
      expect(
        vm.selectContent.results.value.domainError,
        isA<GeoMapSelectionIdentityException>(),
      );
      expect(events.getByIdCallCount + places.getByIdCallCount, 1);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  testWidgets('late selected Event and Place do not notify a disposed VM', (
    tester,
  ) async {
    final events = FakeEventRepository();
    final places = FakePlaceRepository();
    final pendingEvent = Completer<Result<Event>>();
    final pendingPlace = Completer<Result<Place>>();
    events.pendingGetById[1] = pendingEvent;
    places.pendingGetById[2] = pendingPlace;
    final vm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: events,
        placeRepository: places,
      ),
    );
    await pumpCommandTurns(tester);
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.requestSelection(const EventSelection(1));
    await pumpCommandTurns(tester);
    vm.requestSelection(const PlaceSelection(2));
    await pumpCommandTurns(tester);
    vm.dispose();
    pendingEvent.complete(Result.success(makeEvent()));
    pendingPlace.complete(Result.success(makePlace(remoteId: 2)));
    await pumpCommandTurns(tester);
    expect(vm.selectedContent, isNull);
    expect(notifications, 2);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testOwnerUI('semantic transitions are atomic, valid-only and '
      'materialized selection is lookup-free', (tester) async {
    final events = FakeEventRepository();
    final places = FakePlaceRepository();
    final vm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: events,
        placeRepository: places,
      ),
    );
    await pumpCommandTurns(tester);
    expect(vm.mode, isA<GeoMapExplore>());
    expect(vm.exploreAnchor, const LatLng(41.5575078, 14.6485406));
    var notifications = 0;
    vm.addListener(() {
      notifications++;
      if (vm.resolvedContent != null) {
        expect(vm.mode, isA<GeoMapPostDetail>());
        expect(
          (vm.mode as GeoMapPostDetail).identity.id,
          vm.resolvedContent!.remoteId,
        );
      }
    });
    final initial = vm.mode;
    expect(vm.showSearchResults('ab'), isNull);
    expect(vm.mode, same(initial));
    expect(notifications, 0);
    final search = vm.showSearchResults('abc');
    expect(vm.mode, same(search));
    expect(vm.nearbyTarget, isNull);
    final event = makeEvent(remoteId: 12);
    vm.showContent(event);
    expect(vm.resolvedContent, same(event));
    expect(vm.nearbyTarget!.post, (id: 12, type: ContentType.event));
    expect(events.getByIdCallCount + places.getByIdCallCount, 0);
    expect(notifications, 2);
    vm.showExplore(coordinates);
    final explore = vm.mode;
    vm.commitExploreAnchor(const LatLng(42, 15));
    expect(vm.mode, same(explore));
    expect(vm.nearbyTarget!.latitude, 42);
    vm.dispose();
    await pumpCommandTurns(tester);
  });

  for (final transition in ['explore', 'search', 'materialized']) {
    testWidgets(
      '$transition supersedes a pending selection including equal identity',
      (tester) async {
        final pending = Completer<Result<Event>>();
        final events = FakeEventRepository()..pendingGetById[1] = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: FakePlaceRepository(),
          ),
        );
        await pumpCommandTurns(tester);
        vm.requestSelection(const EventSelection(1));
        final admitted = vm.mode;
        await pumpCommandTurns(tester);
        final materialized = makeEvent();
        if (transition == 'explore') vm.showExplore(coordinates);
        if (transition == 'search') vm.showSearchResults('abc');
        if (transition == 'materialized') vm.showContent(materialized);
        final current = vm.mode;
        expect(current, isNot(same(admitted)));
        pending.complete(Result.success(makeEvent()));
        await pumpCommandTurns(tester);
        expect(vm.mode, same(current));
        expect(
          vm.resolvedContent,
          transition == 'materialized' ? same(materialized) : isNull,
        );
        expect(events.getByIdCallCount, 1);
        vm.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }

  for (final runtime in [false, true]) {
    testWidgets('fallback retains ${runtime ? 'runtime' : 'expected'} terminal '
        'and aligns anchor without another lookup', (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository()..pendingGetById[1] = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestSelection(const EventSelection(1));
      await pumpCommandTurns(tester);
      final error = runtime ? StateError('current') : TestException('current');
      if (runtime) {
        pending.completeError(error, StackTrace.current);
      } else {
        pending.complete(Result.error(error as Exception));
      }
      await pumpCommandTurns(tester);
      final terminal = vm.selectContent.results.value;
      expect(terminal.hasFailure, isTrue);
      final fallback = vm.fallbackToExplore(coordinates, terminal);
      expect(vm.mode, same(fallback));
      expect(vm.exploreAnchor, coordinates);
      expect(vm.nearbyTarget!.latitude, coordinates.latitude);
      expect(vm.selectContent.results.value, same(terminal));
      await pumpCommandTurns(tester);
      expect(vm.selectContent.results.value, same(terminal));
      expect(events.getByIdCallCount, 1);
      expect(logger.calls.length, runtime ? 1 : 0);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  testWidgets(
    'fallback returns the locally admitted mode despite reentrant transition',
    (tester) async {
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {1: Result.error(TestException('missing'))},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestSelection(const EventSelection(1));
      await pumpCommandTurns(tester);
      vm.addListener(() {
        if (vm.mode is GeoMapExplore) vm.showSearchResults('new');
      });
      final fallback = vm.fallbackToExplore(
        coordinates,
        vm.selectContent.results.value,
      );
      expect(fallback, isA<GeoMapExplore>());
      expect(vm.mode, isA<GeoMapSearchResults>());
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  for (final placesFail in [false, true]) {
    for (final eventsFail in [false, true]) {
      testWidgets(
        'Nearby aggregate placesFailure=$placesFail eventsFailure=$eventsFail '
        'preserves data and first error',
        (tester) async {
          final place = makePlace();
          final event = makeEvent(remoteId: 2);
          final placeError = TestException('places');
          final eventError = TestException('events');
          final events = FakeEventRepository(
            getByCoordinatesResult: eventsFail
                ? Result.error(eventError)
                : Result.success([event]),
          );
          final places = FakePlaceRepository(
            getByCoordinatesResult: placesFail
                ? Result.error(placeError)
                : Result.success([place]),
          );
          final vm = GeoMapViewModel(
            geoMapUseCase: GeoMapUseCase(
              eventRepository: events,
              placeRepository: places,
            ),
          );
          await pumpCommandTurns(tester);
          vm.requestNearby(vm.nearbyTarget!);
          expect(vm.nearbyTerminal, isNull);
          await pumpCommandTurns(tester);
          expect(vm.nearContent, [
            if (!placesFail) place,
            if (!eventsFail) event,
          ]);
          expect(
            vm.nearbyOutcome!.firstError,
            placesFail
                ? same(placeError)
                : eventsFail
                ? same(eventError)
                : isNull,
          );
          expect(vm.nearbyTerminal!.completed, isTrue);
          expect(
            () => vm.nearbyOutcome!.items.add(event),
            throwsUnsupportedError,
          );
          vm.requestNearby(vm.nearbyTarget!);
          await pumpCommandTurns(tester);
          expect(places.getByCoordinatesCallCount, 1);
          vm.requestNearby(vm.nearbyTarget!, retry: true);
          expect(vm.nearbyTerminal, isNull);
          await pumpCommandTurns(tester);
          expect(places.getByCoordinatesCallCount, 2);
          vm.dispose();
          await tester.pump(const Duration(milliseconds: 50));
        },
      );
    }
  }

  testWidgets('Nearby target A to B to A synchronously clears old terminal '
      'and rejects stale callbacks', (tester) async {
    final events = FakeEventRepository();
    final places = FakePlaceRepository(
      getByCoordinatesResult: Result.success([makePlace()]),
    );
    final vm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: events,
        placeRepository: places,
      ),
    );
    await pumpCommandTurns(tester);
    vm.showExplore(coordinates);
    final a = vm.nearbyTarget!;
    vm.requestNearby(a);
    await pumpCommandTurns(tester);
    final old = vm.nearbyTerminal;
    vm.showContent(makeEvent());
    final postA = vm.nearbyTarget!;
    expect(postA, isNot(a));
    vm.showContent(makeEvent(remoteId: 2));
    expect(vm.nearbyTarget, isNot(postA));
    vm.showExplore(coordinates);
    expect(vm.nearbyTarget, a);
    expect(vm.nearbyTerminal, isNull);
    expect(vm.loadNearContent.results.value, same(old));
    vm.requestNearby(postA);
    expect(vm.loadNearContent.isRunningSync.value, isFalse);
    vm.requestNearby(a);
    expect(vm.loadNearContent.isRunningSync.value, isTrue);
    expect(vm.nearContent, isEmpty);
    await pumpCommandTurns(tester);
    expect(places.getByCoordinatesCallCount, 2);
    vm.showExplore(const LatLng(double.nan, double.nan));
    vm.requestNearby(vm.nearbyTarget!);
    await pumpCommandTurns(tester);
    expect(places.getByCoordinatesCallCount, 2);
    vm.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
    'Nearby raw error commits terminal rather than permanent loading',
    (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final pending = Completer<Result<List<Place>>>();
      final places = FakePlaceRepository()..pendingGetByCoordinates = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: places,
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestNearby(vm.nearbyTarget!);
      await pumpCommandTurns(tester);
      final error = StateError('nearby');
      pending.completeError(error, StackTrace.current);
      await pumpCommandTurns(tester);
      expect(vm.nearbyTerminal!.unexpectedError, same(error));
      expect(vm.nearbyOutcome, isNull);
      expect(vm.nearContent, isEmpty);
      expect(logger.calls.single.error, same(error));
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  for (final staleOutcome in ['success', 'domain', 'runtime']) {
    testWidgets('Nearby pending A to B rejects stale $staleOutcome', (
      tester,
    ) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final a = Completer<Result<List<Place>>>();
      final b = Completer<Result<List<Place>>>();
      final places = FakePlaceRepository()..pendingGetByCoordinates = a;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: places,
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestNearby(vm.nearbyTarget!);
      await pumpCommandTurns(tester);
      vm.showContent(makePlace(remoteId: 2));
      places.pendingGetByCoordinates = b;
      vm.requestNearby(vm.nearbyTarget!);
      await pumpCommandTurns(tester);
      final content = makePlace(remoteId: 2);
      b.complete(Result.success([content]));
      await pumpCommandTurns(tester);
      final current = vm.nearbyTerminal;
      expect(vm.nearContent, [content]);
      if (staleOutcome == 'runtime') {
        a.completeError(StateError('obsolete'), StackTrace.current);
      } else {
        a.complete(
          staleOutcome == 'domain'
              ? Result.error(TestException('obsolete'))
              : Result.success([makePlace()]),
        );
      }
      await pumpCommandTurns(tester);
      expect(vm.nearbyTerminal, same(current));
      expect(vm.nearContent, [content]);
      expect(logger.calls.length, staleOutcome == 'runtime' ? 1 : 0);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  for (final firstEvent in [true, false]) {
    for (final secondEvent in [true, false]) {
      testWidgets(
        'old-first selection $firstEvent to $secondEvent cannot commit A',
        (tester) async {
          final events = FakeEventRepository();
          final places = FakePlaceRepository();
          final ae = Completer<Result<Event>>();
          final ap = Completer<Result<Place>>();
          final be = Completer<Result<Event>>();
          final bp = Completer<Result<Place>>();
          if (firstEvent) {
            events.pendingGetById[1] = ae;
          } else {
            places.pendingGetById[1] = ap;
          }
          if (secondEvent) {
            events.pendingGetById[2] = be;
          } else {
            places.pendingGetById[2] = bp;
          }
          final vm = GeoMapViewModel(
            geoMapUseCase: GeoMapUseCase(
              eventRepository: events,
              placeRepository: places,
            ),
          );
          await pumpCommandTurns(tester);
          vm.requestSelection(
            firstEvent ? const EventSelection(1) : const PlaceSelection(1),
          );
          await pumpCommandTurns(tester);
          vm.requestSelection(
            secondEvent ? const EventSelection(2) : const PlaceSelection(2),
          );
          await pumpCommandTurns(tester);
          if (firstEvent) {
            ae.complete(Result.success(makeEvent()));
          } else {
            ap.complete(Result.success(makePlace()));
          }
          await pumpCommandTurns(tester);
          expect(vm.resolvedContent, isNull);
          expect(vm.selectContent.isRunningSync.value, isTrue);
          if (secondEvent) {
            be.complete(Result.success(makeEvent(remoteId: 2)));
          } else {
            bp.complete(Result.success(makePlace(remoteId: 2)));
          }
          await pumpCommandTurns(tester);
          expect(vm.resolvedContent!.remoteId, 2);
          vm.dispose();
          await tester.pump(const Duration(milliseconds: 50));
        },
      );
    }
  }

  testWidgets(
    'Nearby invalidation reentrancy cannot admit an obsolete Post resolver',
    (tester) async {
      final pending = Completer<Result<List<Place>>>();
      final events = FakeEventRepository();
      final places = FakePlaceRepository()..pendingGetByCoordinates = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestNearby(vm.nearbyTarget!);
      await pumpCommandTurns(tester);
      vm.loadNearContent.isRunningSync.addListener(() {
        if (!vm.loadNearContent.isRunningSync.value) {
          vm.showSearchResults('new');
        }
      });
      vm.requestSelection(const EventSelection(1));
      await pumpCommandTurns(tester);
      expect(vm.mode, isA<GeoMapSearchResults>());
      expect(events.getByIdCallCount, 0);
      pending.complete(const Result.success([]));
      await pumpCommandTurns(tester);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets('current resolver assertion remains fail-loud without fallback', (
    tester,
  ) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final errors = <Object>[];
    final assertion = AssertionError('resolver invariant');
    late Completer<Result<Event>> pending;
    late GeoMapViewModel vm;
    runZonedGuarded(() {
      pending = Completer<Result<Event>>();
      final events = FakeEventRepository()..pendingGetById[1] = pending;
      vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      vm.requestSelection(const EventSelection(1));
    }, (error, _) => errors.add(error));
    await pumpCommandTurns(tester);
    final admitted = vm.mode;
    pending.completeError(assertion, StackTrace.current);
    await pumpCommandTurns(tester);
    expect(errors, [same(assertion)]);
    expect(logger.calls, isEmpty);
    expect(vm.mode, same(admitted));
    expect(vm.resolvedContent, isNull);
    expect(vm.selectContent.results.value.hasFailure, isFalse);
    expect(
      vm.fallbackToExplore(coordinates, vm.selectContent.results.value),
      isNull,
    );
    vm.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final reentry in ['search', 'anchor', 'dispose']) {
    testWidgets(
      'anchor invalidation reentry to $reentry emits no obsolete notification',
      (tester) async {
        final pending = Completer<Result<List<Place>>>();
        final places = FakePlaceRepository()..pendingGetByCoordinates = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: FakeEventRepository(),
            placeRepository: places,
          ),
        );
        await pumpCommandTurns(tester);
        vm.requestNearby(vm.nearbyTarget!);
        await pumpCommandTurns(tester);
        var notifications = 0;
        vm.addListener(() => notifications++);
        vm.loadNearContent.isRunningSync.addListener(() {
          if (vm.loadNearContent.isRunningSync.value) return;
          switch (reentry) {
            case 'search':
              vm.showSearchResults('new');
            case 'anchor':
              vm.commitExploreAnchor(const LatLng(43, 16));
            case 'dispose':
              vm.dispose();
          }
        });
        vm.commitExploreAnchor(const LatLng(42, 15));
        expect(notifications, reentry == 'dispose' ? 0 : 1);
        if (reentry == 'search') expect(vm.mode, isA<GeoMapSearchResults>());
        if (reentry == 'anchor') expect(vm.exploreAnchor, const LatLng(43, 16));
        expect(tester.takeException(), isNull);
        pending.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        expect(notifications, reentry == 'dispose' ? 0 : 1);
        if (!vm.isDisposed) vm.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }

  testWidgets(
    'route preparation quietly hides old materialization and Nearby',
    (tester) async {
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository()..pendingGetById[2] = pending;
      final places = FakePlaceRepository(
        getByCoordinatesResult: Result.success([makePlace()]),
      );
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      await pumpCommandTurns(tester);
      vm.showContent(makeEvent());
      vm.requestNearby(vm.nearbyTarget!);
      await pumpCommandTurns(tester);
      expect(vm.nearbyTerminal, isNotNull);
      var notifications = 0;
      vm.addListener(() => notifications++);
      final prepared = vm.prepareRouteAdmission((
        id: 2,
        type: ContentType.event,
      ), coordinates)!;
      expect(vm.mode, same(prepared));
      expect(vm.resolvedContent, isNull);
      expect(vm.nearbyTarget, isNull);
      expect(vm.nearbyTerminal, isNull);
      expect(events.getByIdCallCount, 0);
      expect(notifications, 0);
      await pumpCommandTurns(tester);
      expect(notifications, 0);
      vm.admitPreparedRoute(prepared);
      expect(vm.mode, same(prepared));
      expect(notifications, 1);
      expect(vm.selectContent.isRunningSync.value, isTrue);
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, 1);
      pending.complete(Result.success(makeEvent(remoteId: 2)));
      await pumpCommandTurns(tester);
      expect(vm.mode, same(prepared));
      expect(vm.resolvedContent!.remoteId, 2);
      expect(notifications, 2);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'route A B A preparation accepts only the final exact admission',
    (tester) async {
      final events = FakeEventRepository(
        getByIdResults: {1: Result.success(makeEvent())},
      );
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      await pumpCommandTurns(tester);
      final a = vm.prepareRouteAdmission((
        id: 1,
        type: ContentType.event,
      ), coordinates)!;
      final b = vm.prepareRouteAdmission((
        id: 2,
        type: ContentType.place,
      ), coordinates)!;
      final latestA = vm.prepareRouteAdmission((
        id: 1,
        type: ContentType.event,
      ), coordinates)!;
      expect(latestA, isNot(same(a)));
      var notifications = 0;
      vm.addListener(() => notifications++);
      vm.admitPreparedRoute(a);
      vm.admitPreparedRoute(b);
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, 0);
      expect(notifications, 0);
      vm.admitPreparedRoute(latestA);
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, 1);
      expect(vm.resolvedContent!.remoteId, 1);
      expect(notifications, 2);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  for (final transition in ['materialized', 'search', 'dispose']) {
    testWidgets('local $transition supersedes queued route admission', (
      tester,
    ) async {
      final events = FakeEventRepository();
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      await pumpCommandTurns(tester);
      final prepared = vm.prepareRouteAdmission((
        id: 1,
        type: ContentType.event,
      ), coordinates)!;
      if (transition == 'materialized') vm.showContent(makeEvent());
      if (transition == 'search') vm.showSearchResults('new');
      if (transition == 'dispose') vm.dispose();
      final current = vm.mode;
      vm.admitPreparedRoute(prepared);
      await pumpCommandTurns(tester);
      expect(vm.mode, same(current));
      expect(events.getByIdCallCount, 0);
      if (!vm.isDisposed) vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  testWidgets(
    'default route quietly revokes pending Post and commits live anchor',
    (tester) async {
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository()..pendingGetById[1] = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      await pumpCommandTurns(tester);
      vm.requestSelection(const EventSelection(1));
      await pumpCommandTurns(tester);
      var notifications = 0;
      vm.addListener(() => notifications++);
      final prepared = vm.prepareRouteAdmission(null, coordinates)!;
      expect(prepared, isA<GeoMapExplore>());
      expect(vm.exploreAnchor, coordinates);
      expect(vm.nearbyTarget!.latitude, coordinates.latitude);
      expect(vm.selectContent.isRunningSync.value, isFalse);
      expect(notifications, 0);
      pending.complete(Result.success(makeEvent()));
      await pumpCommandTurns(tester);
      expect(vm.resolvedContent, isNull);
      expect(vm.mode, same(prepared));
      expect(notifications, 0);
      vm.admitPreparedRoute(prepared);
      expect(notifications, 1);
      expect(vm.selectContent.isRunningSync.value, isFalse);
      expect(events.getByIdCallCount, 1);
      vm.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  for (final dispose in [false, true]) {
    testWidgets(
      'quiet route preparation survives coordination reentry dispose=$dispose',
      (tester) async {
        final pending = Completer<Result<List<Place>>>();
        final places = FakePlaceRepository()..pendingGetByCoordinates = pending;
        final events = FakeEventRepository();
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: places,
          ),
        );
        await pumpCommandTurns(tester);
        vm.requestNearby(vm.nearbyTarget!);
        await pumpCommandTurns(tester);
        var notifications = 0;
        vm.addListener(() => notifications++);
        vm.loadNearContent.isRunningSync.addListener(() {
          if (vm.loadNearContent.isRunningSync.value) return;
          if (dispose) {
            vm.dispose();
          } else {
            vm.showSearchResults('new');
          }
        });
        final prepared = vm.prepareRouteAdmission((
          id: 1,
          type: ContentType.event,
        ), coordinates)!;
        if (!dispose) expect(vm.mode, isNot(same(prepared)));
        vm.admitPreparedRoute(prepared);
        pending.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        expect(events.getByIdCallCount, 0);
        expect(notifications, dispose ? 0 : 1);
        if (!vm.isDisposed) vm.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }
}
