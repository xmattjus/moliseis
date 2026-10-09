// Sequential command assertions keep temporal regressions readable.
// ignore_for_file: cascade_invocations

import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
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
      final filter = vm.setSelectedCategories.execute({ContentCategory.nature});
      expect(events.getByCurrentYearCallCount, 2);
      vm.dispose();
      pending.complete(Result.success(<Event>[makeEvent()]));
      await filter;

      expect(places.getAllCallCount, 1);
      expect(vm.allEvents, isEmpty);
      expect(vm.setSelectedCategories.completed, isTrue);
    },
  );

  test(
    'disposal during first nearby request skips the second request',
    () async {
      final events = FakeEventRepository();
      final places = FakePlaceRepository();
      final pending = Completer<Result<List<Place>>>();
      places.pendingGetByCoordinates = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );

      final operation = vm.loadNearContent.execute(coordinates);
      expect(places.getByCoordinatesCallCount, 1);
      vm.dispose();
      pending.complete(Result.success(<Place>[makePlace()]));
      await operation;

      expect(events.getByCoordinatesCallCount, 0);
      expect(vm.nearContent, isEmpty);
      expect(vm.loadNearContent.completed, isTrue);
    },
  );

  test(
    'disposal during second nearby request leaves prior state unchanged',
    () async {
      final events = FakeEventRepository();
      final places = FakePlaceRepository(
        getByCoordinatesResult: Result.success(<Place>[makePlace()]),
      );
      final pending = Completer<Result<List<Event>>>();
      final called = Completer<void>();
      events
        ..pendingGetByCoordinates = pending
        ..getByCoordinatesCalled = called;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );

      final operation = vm.loadNearContent.execute(coordinates);
      await called.future;
      expect(vm.nearContent.map((content) => content.remoteId), [1]);
      vm.dispose();
      pending.complete(Result.success(<Event>[makeEvent(remoteId: 2)]));
      await operation;

      expect(vm.nearContent.map((content) => content.remoteId), [1]);
      expect(vm.loadNearContent.completed, isTrue);
    },
  );

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
            expect(commits, 1);
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
            expect(commits, 1);
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
      expect(vm.selectContent.results.value.paramData, isA<ClearSelection>());
      expect(vm.selectContent.results.value.completed, isTrue);
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
      expect(commits, 0);
      expect(vm.selectContent.results.value.completed, isTrue);
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
    expect(notifications, 0);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
