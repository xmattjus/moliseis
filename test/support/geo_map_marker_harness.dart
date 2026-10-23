import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/utils/result.dart';

import 'command_test_support.dart';
import 'fake_repositories.dart';

/// Real use-case boundary with independently controlled marker source calls.
class GeoMapMarkerHarness {
  GeoMapMarkerHarness() {
    events.getByCurrentYearHandler = () {
      final gate = Completer<Result<List<Event>>>();
      eventReads.add(gate);
      return gate.future;
    };
    places.getAllHandler = (_) {
      final gate = Completer<Result<List<Place>>>();
      placeReads.add(gate);
      return gate.future;
    };
    vm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: events,
        placeRepository: places,
      ),
    );
    vm.addListener(() => notifications++);
  }

  final events = FakeEventRepository();
  final places = FakePlaceRepository();
  final List<Completer<Result<List<Event>>>> eventReads = [];
  final List<Completer<Result<List<Place>>>> placeReads = [];
  late final GeoMapViewModel vm;
  int notifications = 0;

  /// Completes bootstrap without content so later assertions start at a gate.
  Future<void> finishBootstrap(WidgetTester tester) async {
    await pumpCommandTurns(tester);
    eventReads.single.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    placeReads.single.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    notifications = 0;
  }
}
