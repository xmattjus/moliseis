import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/geo_map_marker_harness.dart';
import '../../../support/mock_logger.dart';

void main() {
  testOwnerUI('G1 bootstrap commits both sources once atomically', (
    tester,
  ) async {
    final h = GeoMapMarkerHarness();
    expect(h.vm.markerStatus, GeoMapMarkerStatus.loading);
    expect(h.vm.selectedTypes, ContentType.values.toSet());
    expect(h.vm.selectedCategories, isNot(contains(ContentCategory.unknown)));
    expect(h.eventReads, isEmpty);
    await pumpCommandTurns(tester);
    expect(h.eventReads, hasLength(1));
    expect(h.placeReads, isEmpty);
    final event = makeEvent(name: 'Z event', category: ContentCategory.nature);
    final place = makePlace(name: 'A place', category: ContentCategory.nature);
    h.eventReads.single.complete(Result.success([event]));
    await pumpCommandTurns(tester);
    expect(h.vm.allEvents, isEmpty);
    expect(h.notifications, 0);
    expect(h.placeReads, hasLength(1));
    h.placeReads.single.complete(Result.success([place]));
    await pumpCommandTurns(tester);
    expect(h.vm.allEvents, [event]);
    expect(h.vm.allPlaces, [place]);
    expect(h.vm.markerStatus, GeoMapMarkerStatus.successData);
    expect(h.notifications, 1);
    expect(h.vm.markerTerminal!.completed, isTrue);
    h.vm.dispose();
  });

  for (final type in ContentType.values) {
    testOwnerUI('G2 immutable filters and selected source $type', (
      tester,
    ) async {
      final h = GeoMapMarkerHarness();
      await h.finishBootstrap(tester);
      final old = h.vm.markerRequest;
      final categories = {ContentCategory.nature};
      final types = {type};
      h.vm.setSelectedCategories(categories);
      h.vm.setSelectedTypes(types);
      categories.clear();
      types.clear();
      expect(h.vm.selectedCategories, {ContentCategory.nature});
      expect(h.vm.selectedTypes, {type});
      expect(h.vm.markerRequest, isNot(same(old)));
      expect(h.vm.markerStatus, GeoMapMarkerStatus.loading);
      expect(h.notifications, 2);
      expect(
        () => h.vm.markerRequest.categories.clear(),
        throwsUnsupportedError,
      );
      await pumpCommandTurns(tester);
      final event = makeEvent(category: ContentCategory.nature);
      final place = makePlace(category: ContentCategory.nature);
      if (type == ContentType.event) {
        expect(h.eventReads, hasLength(2));
        expect(h.placeReads, hasLength(1));
        h.eventReads.last.complete(
          Result.success([event, makeEvent(category: ContentCategory.history)]),
        );
      } else {
        expect(h.eventReads, hasLength(1));
        expect(h.placeReads, hasLength(2));
        h.placeReads.last.complete(
          Result.success([place, makePlace(category: ContentCategory.history)]),
        );
      }
      await pumpCommandTurns(tester);
      expect(h.vm.allEvents, type == ContentType.event ? [event] : isEmpty);
      expect(h.vm.allPlaces, type == ContentType.place ? [place] : isEmpty);
      expect(h.notifications, 3);
      h.vm.dispose();
    });
  }

  for (final emptyCategories in [true, false]) {
    testOwnerUI('G3 empty selection no I/O categories=$emptyCategories', (
      tester,
    ) async {
      final h = GeoMapMarkerHarness();
      await pumpCommandTurns(tester);
      final pending = h.eventReads.single;
      final request = h.vm.markerRequest;
      h.vm.setSelectedCategories(Set.of(h.vm.selectedCategories));
      h.vm.setSelectedTypes(Set.of(h.vm.selectedTypes));
      expect(h.vm.markerRequest, same(request));
      expect(h.notifications, 0);
      if (emptyCategories) {
        h.vm.setSelectedCategories({});
      } else {
        h.vm.setSelectedTypes({});
      }
      expect(h.vm.markerStatus, GeoMapMarkerStatus.successEmpty);
      expect(h.notifications, 1);
      h.vm.retryMarkers();
      expect(h.notifications, 1);
      pending.complete(const Result.success([]));
      await pumpCommandTurns(tester);
      // Supersession revokes commits; the old physical second phase may run.
      for (final read in h.placeReads) {
        read.complete(const Result.success([]));
      }
      await pumpCommandTurns(tester);
      expect(h.vm.markerStatus, GeoMapMarkerStatus.successEmpty);
      expect(h.vm.allEvents, isEmpty);
      expect(h.notifications, 1);
      h.vm.dispose();
    });
  }

  testOwnerUI('G4 A-B-A different requests ignore out-of-order outcomes', (
    tester,
  ) async {
    final h = GeoMapMarkerHarness();
    final all = Set.of(h.vm.selectedCategories);
    final first = h.vm.markerRequest;
    await pumpCommandTurns(tester);
    h.vm.setSelectedCategories({ContentCategory.nature});
    await pumpCommandTurns(tester);
    h.vm.setSelectedCategories(all);
    final last = h.vm.markerRequest;
    expect(last, isNot(same(first)));
    await pumpCommandTurns(tester);
    expect(h.eventReads, hasLength(3));
    final current = makeEvent(
      name: 'current',
      category: ContentCategory.nature,
    );
    h.eventReads.last.complete(Result.success([current]));
    await pumpCommandTurns(tester);
    h.placeReads.single.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(h.vm.allEvents, [current]);
    final notifications = h.notifications;
    h.eventReads[0].complete(
      Result.success([
        makeEvent(name: 'old A', category: ContentCategory.nature),
      ]),
    );
    h.eventReads[1].complete(Result.error(TestException('old B')));
    await pumpCommandTurns(tester);
    for (final read in h.placeReads.skip(1)) {
      read.complete(const Result.success([]));
    }
    await pumpCommandTurns(tester);
    expect(h.vm.allEvents, [current]);
    expect(h.vm.markerRequest, same(last));
    expect(h.vm.markerStatus, GeoMapMarkerStatus.successData);
    expect(h.notifications, notifications);
    h.vm.dispose();
  });

  for (final empty in [false, true]) {
    testOwnerUI('G5 superseded queued envelopes perform no I/O empty=$empty', (
      tester,
    ) async {
      final h = GeoMapMarkerHarness();
      final all = Set.of(h.vm.selectedCategories);
      h.vm.setSelectedCategories({ContentCategory.nature});
      h.vm.setSelectedCategories(empty ? {} : all);
      await pumpCommandTurns(tester);
      expect(h.eventReads, hasLength(empty ? 0 : 1));
      if (!empty) {
        h.eventReads.single.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        h.placeReads.single.complete(const Result.success([]));
        await pumpCommandTurns(tester);
      }
      expect(h.vm.markerStatus, GeoMapMarkerStatus.successEmpty);
      h.vm.dispose();
    });
  }

  for (final eventError in [false, true]) {
    for (final placeError in [false, true]) {
      for (final empty in [false, true]) {
        testOwnerUI('G6 Eerror=$eventError Perror=$placeError empty=$empty', (
          tester,
        ) async {
          final h = GeoMapMarkerHarness();
          await pumpCommandTurns(tester);
          final eventFailure = TestException('events');
          final placeFailure = TestException('places');
          final event = makeEvent(category: ContentCategory.nature);
          final place = makePlace(category: ContentCategory.nature);
          h.eventReads.single.complete(
            eventError
                ? Result.error(eventFailure)
                : Result.success(empty ? [] : [event]),
          );
          await pumpCommandTurns(tester);
          expect(h.vm.allEvents, isEmpty);
          expect(h.notifications, 0);
          h.placeReads.single.complete(
            placeError
                ? Result.error(placeFailure)
                : Result.success(empty ? [] : [place]),
          );
          await pumpCommandTurns(tester);
          expect(h.vm.allEvents, eventError || empty ? isEmpty : [event]);
          expect(h.vm.allPlaces, placeError || empty ? isEmpty : [place]);
          expect(
            h.vm.markerOutcome!.eventError,
            same(eventError ? eventFailure : null),
          );
          expect(
            h.vm.markerOutcome!.placeError,
            same(placeError ? placeFailure : null),
          );
          expect(
            h.vm.markerOutcome!.firstError,
            same(
              eventError
                  ? eventFailure
                  : placeError
                  ? placeFailure
                  : null,
            ),
          );
          expect(
            h.vm.markerStatus,
            eventError || placeError
                ? GeoMapMarkerStatus.failure
                : empty
                ? GeoMapMarkerStatus.successEmpty
                : GeoMapMarkerStatus.successData,
          );
          expect(h.notifications, 1);
          h.vm.dispose();
        });
      }
    }
  }

  for (final phase in ['events', 'places', 'stale']) {
    testOwnerUI('G7 runtime original reporting $phase', (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final h = GeoMapMarkerHarness();
      await pumpCommandTurns(tester);
      if (phase == 'places') {
        h.eventReads.single.complete(
          Result.success([makeEvent(category: ContentCategory.nature)]),
        );
        await pumpCommandTurns(tester);
      }
      if (phase == 'stale') h.vm.setSelectedTypes({});
      final original = StateError('marker failure');
      if (phase == 'places') {
        h.placeReads.single.completeError(original);
      } else {
        h.eventReads.single.completeError(original);
      }
      await pumpCommandTurns(tester);
      expect(
        h.vm.markerStatus,
        phase == 'stale'
            ? GeoMapMarkerStatus.successEmpty
            : GeoMapMarkerStatus.failure,
      );
      expect(h.vm.allEvents, isEmpty);
      expect(h.vm.allPlaces, isEmpty);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(original));
      expect(h.placeReads, hasLength(phase == 'places' ? 1 : 0));
      h.vm.dispose();
    });
  }

  testOwnerUI('G8 identical selection is no-op, explicit retry is current', (
    tester,
  ) async {
    final h = GeoMapMarkerHarness();
    await pumpCommandTurns(tester);
    h.vm.retryMarkers();
    expect(h.notifications, 0);
    h.eventReads.single.complete(Result.error(TestException('first')));
    await pumpCommandTurns(tester);
    h.placeReads.single.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    final failed = h.vm.markerRequest;
    h.vm.setSelectedCategories(Set.of(h.vm.selectedCategories));
    expect(h.vm.markerRequest, same(failed));
    expect(h.notifications, 1);
    h.vm.retryMarkers();
    expect(h.vm.markerRequest, isNot(same(failed)));
    expect(h.vm.markerStatus, GeoMapMarkerStatus.loading);
    expect(h.vm.markerTerminal, isNull);
    expect(h.notifications, 2);
    h.vm.retryMarkers();
    await pumpCommandTurns(tester);
    expect(h.eventReads, hasLength(2));
    h.eventReads.last.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    h.placeReads.last.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(h.vm.markerStatus, GeoMapMarkerStatus.successEmpty);
    expect(h.notifications, 3);
    h.vm.dispose();
  });

  for (final phase in ['before', 'events', 'places']) {
    testOwnerUI('G9 disposal $phase blocks commit and unstarted phases', (
      tester,
    ) async {
      final h = GeoMapMarkerHarness();
      if (phase != 'before') await pumpCommandTurns(tester);
      if (phase == 'places') {
        h.eventReads.single.complete(const Result.success([]));
        await pumpCommandTurns(tester);
      }
      h.vm.dispose();
      if (phase == 'events') {
        h.eventReads.single.complete(const Result.success([]));
      }
      if (phase == 'places') {
        h.placeReads.single.complete(const Result.success([]));
      }
      await pumpCommandTurns(tester);
      expect(h.eventReads, hasLength(phase == 'before' ? 0 : 1));
      expect(h.placeReads, hasLength(phase == 'places' ? 1 : 0));
      expect(h.notifications, 0);
      expect(h.vm.allEvents, isEmpty);
    });
  }

  testOwnerUI('G9 reentrant admission revokes older queued snapshot', (
    tester,
  ) async {
    final h = GeoMapMarkerHarness();
    await h.finishBootstrap(tester);
    var entered = false;
    h.vm.addListener(() {
      if (!entered) {
        entered = true;
        h.vm.setSelectedTypes({});
      }
    });
    h.vm.setSelectedCategories({ContentCategory.nature});
    expect(h.vm.markerStatus, GeoMapMarkerStatus.successEmpty);
    expect(h.notifications, 2);
    await pumpCommandTurns(tester);
    expect(h.eventReads, hasLength(1));
    expect(h.placeReads, hasLength(1));
    expect(h.notifications, 2);
    h.vm.dispose();
  });

  testOwnerUI('G9 terminal notification can replace filter and dispose', (
    tester,
  ) async {
    final h = GeoMapMarkerHarness();
    await h.finishBootstrap(tester);
    h.vm.setSelectedCategories({ContentCategory.nature});
    await pumpCommandTurns(tester);
    var reentered = false;
    h.vm.addListener(() {
      if (!reentered && h.vm.markerStatus == GeoMapMarkerStatus.successData) {
        reentered = true;
        h.vm.setSelectedTypes({});
        h.vm.dispose();
      }
    });
    h.eventReads.last.complete(
      Result.success([makeEvent(category: ContentCategory.nature)]),
    );
    await pumpCommandTurns(tester);
    h.placeReads.last.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(reentered, isTrue);
    expect(h.vm.isDisposed, isTrue);
    expect(h.vm.markerStatus, GeoMapMarkerStatus.successEmpty);
    expect(h.vm.allEvents, isEmpty);
    expect(h.notifications, 3);
    expect(h.eventReads, hasLength(2));
    expect(h.placeReads, hasLength(2));
  });

  testOwnerUI('marker filtering preserves source order and semantic Post', (
    tester,
  ) async {
    final h = GeoMapMarkerHarness();
    await h.finishBootstrap(tester);
    final post = makePlace(remoteId: 90);
    h.vm.showContent(post);
    final mode = h.vm.mode;
    final target = h.vm.nearbyTarget;
    h.notifications = 0;
    h.vm.setSelectedCategories({ContentCategory.nature});
    await pumpCommandTurns(tester);
    final first = makeEvent(
      remoteId: 2,
      name: 'Z',
      category: ContentCategory.nature,
    );
    final last = makeEvent(name: 'A', category: ContentCategory.nature);
    h.eventReads.last.complete(
      Result.success([
        first,
        makeEvent(category: ContentCategory.history),
        last,
      ]),
    );
    await pumpCommandTurns(tester);
    final place = makePlace(category: ContentCategory.nature);
    h.placeReads.last.complete(Result.success([place]));
    await pumpCommandTurns(tester);
    expect(h.vm.allEvents, [first, last]);
    expect(h.vm.allPlaces, [place]);
    expect(h.vm.mode, same(mode));
    expect(h.vm.resolvedContent, same(post));
    expect(h.vm.nearbyTarget, target);
    expect(h.notifications, 2);
    h.vm.dispose();
  });

  testOwnerUI('G7 assertion remains fail loud with settled private cleanup', (
    tester,
  ) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final errors = <Object>[];
    final entered = Completer<void>();
    late GeoMapMarkerHarness h;
    runZonedGuarded(() {
      h = GeoMapMarkerHarness();
      entered.complete();
    }, (error, stack) => errors.add(error));
    await entered.future;
    await pumpCommandTurns(tester);
    final original = AssertionError('marker assert');
    h.eventReads.single.completeError(original);
    await pumpCommandTurns(tester);
    expect(errors, [same(original)]);
    expect(logger.calls, isEmpty);
    expect(h.placeReads, isEmpty);
    expect(h.vm.loadMarkers.debugLiveChildCount, 0);
    h.vm.dispose();
  });
}
