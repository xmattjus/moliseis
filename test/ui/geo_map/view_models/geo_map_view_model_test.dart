import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

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

  test('late selected Event and Place do not mutate a disposed VM', () async {
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

    final event = vm.showEvent.execute(1);
    final place = vm.showPlace.execute(2);
    vm.dispose();
    pendingEvent.complete(Result.success(makeEvent()));
    pendingPlace.complete(Result.success(makePlace(remoteId: 2)));
    await Future.wait([event, place]);

    expect(vm.selectedContent, isNull);
    expect(vm.showEvent.completed, isTrue);
    expect(vm.showPlace.completed, isTrue);
  });
}
