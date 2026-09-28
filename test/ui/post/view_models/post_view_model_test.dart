import 'dart:async' show Completer;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('PostViewModel async lifetime', () {
    late FakeEventRepository events;
    late FakePlaceRepository places;
    late PostViewModel viewModel;
    late List<FlutterErrorDetails> reportedErrors;
    late FlutterExceptionHandler? previousErrorHandler;
    var disposed = false;

    setUp(() {
      events = FakeEventRepository();
      places = FakePlaceRepository();
      viewModel = PostViewModel(
        postUseCase: PostUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      disposed = false;
      reportedErrors = <FlutterErrorDetails>[];
      previousErrorHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;
    });

    tearDown(() {
      if (!disposed) viewModel.dispose();
      FlutterError.onError = previousErrorHandler;
    });

    test('Event completion after dispose cannot mutate or notify', () async {
      final pending = Completer<Result<Event>>();
      events.pendingGetById[1] = pending;
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final execution = viewModel.loadEvent.execute(1);
      expect(viewModel.loadEvent.running, isTrue);
      viewModel.dispose();
      disposed = true;
      pending.complete(Result.success(makeEvent()));
      await execution;

      expect(
        reportedErrors.map(
          (details) => '${details.library}: ${details.exception}',
        ),
        isEmpty,
      );
      expect(notifications, 0);
      expect(() => viewModel.content, throwsA(anything));
      expect(viewModel.loadEvent.completed, isTrue);
      expect(viewModel.loadEvent.error, isFalse);
    });

    test('Place completion after dispose cannot mutate or notify', () async {
      final pending = Completer<Result<Place>>();
      places.pendingGetById[2] = pending;
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final execution = viewModel.loadPlace.execute(2);
      expect(viewModel.loadPlace.running, isTrue);
      viewModel.dispose();
      disposed = true;
      pending.complete(Result.success(makePlace(remoteId: 2)));
      await execution;

      expect(
        reportedErrors.map(
          (details) => '${details.library}: ${details.exception}',
        ),
        isEmpty,
      );
      expect(notifications, 0);
      expect(() => viewModel.content, throwsA(anything));
      expect(viewModel.loadPlace.completed, isTrue);
      expect(viewModel.loadPlace.error, isFalse);
    });

    test('Repository errors remain errors after disposal', () async {
      final pendingEvent = Completer<Result<Event>>();
      final pendingPlace = Completer<Result<Place>>();
      final eventError = TestException('event unavailable');
      final placeError = TestException('place unavailable');
      events.pendingGetById[1] = pendingEvent;
      places.pendingGetById[2] = pendingPlace;

      final eventExecution = viewModel.loadEvent.execute(1);
      final placeExecution = viewModel.loadPlace.execute(2);
      viewModel.dispose();
      disposed = true;
      pendingEvent.complete(Result.error(eventError));
      pendingPlace.complete(Result.error(placeError));
      await Future.wait(<Future<void>>[eventExecution, placeExecution]);

      expect(viewModel.loadEvent.error, isTrue);
      expect(viewModel.loadPlace.error, isTrue);
      expect(
        (viewModel.loadEvent.result! as Error<void>).error,
        same(eventError),
      );
      expect(
        (viewModel.loadPlace.result! as Error<void>).error,
        same(placeError),
      );
      expect(reportedErrors, isEmpty);
    });

    test(
      'Nearby disposal during events request does not start places',
      () async {
        final pendingEvents = Completer<Result<List<Event>>>();
        events.pendingGetByCoordinates = pendingEvents;
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final execution = viewModel.loadNearContent.execute(
          const LatLng(41, 14),
        );
        expect(viewModel.loadNearContent.running, isTrue);
        viewModel.dispose();
        disposed = true;
        pendingEvents.complete(Result.success(<Event>[makeEvent()]));
        await execution;

        expect(places.getByCoordinatesCallCount, 0);
        expect(viewModel.nearContent, isEmpty);
        expect(notifications, 0);
        expect(reportedErrors, isEmpty);
        expect(viewModel.loadNearContent.completed, isTrue);
      },
    );

    test('Nearby disposal after events complete but before continuation '
        'does not start places', () async {
      final pendingEvents = Completer<Result<List<Event>>>();
      events.pendingGetByCoordinates = pendingEvents;

      final execution = viewModel.loadNearContent.execute(const LatLng(41, 14));
      pendingEvents.complete(Result.success(<Event>[makeEvent()]));
      // The repository Future is complete, but its awaiting continuation has
      // not run yet. No timer or scheduler delay is involved.
      viewModel.dispose();
      disposed = true;
      await execution;

      expect(places.getByCoordinatesCallCount, 0);
      expect(viewModel.nearContent, isEmpty);
      expect(reportedErrors, isEmpty);
    });

    test('Nearby event error after disposal remains a Command error', () async {
      final pendingEvents = Completer<Result<List<Event>>>();
      final repositoryError = TestException('nearby events failed');
      events.pendingGetByCoordinates = pendingEvents;

      final execution = viewModel.loadNearContent.execute(const LatLng(41, 14));
      viewModel.dispose();
      disposed = true;
      pendingEvents.complete(Result.error(repositoryError));
      await execution;

      expect(places.getByCoordinatesCallCount, 0);
      expect(viewModel.loadNearContent.error, isTrue);
      expect(
        (viewModel.loadNearContent.result! as Error<void>).error,
        same(repositoryError),
      );
      expect(reportedErrors, isEmpty);
    });

    test(
      'Nearby disposal during places request leaves events unchanged',
      () async {
        final event = makeEvent();
        final place = makePlace(remoteId: 2);
        final pendingEvents = Completer<Result<List<Event>>>();
        final pendingPlaces = Completer<Result<List<Place>>>();
        events.pendingGetByCoordinates = pendingEvents;
        places
          ..pendingGetByCoordinates = pendingPlaces
          ..getByCoordinatesCalled = Completer<void>();
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final execution = viewModel.loadNearContent.execute(
          const LatLng(41, 14),
        );
        pendingEvents.complete(Result.success(<Event>[event]));
        await places.getByCoordinatesCalled!.future;
        expect(places.getByCoordinatesCallCount, 1);
        expect(viewModel.nearContent, <Event>[event]);

        viewModel.dispose();
        disposed = true;
        pendingPlaces.complete(Result.success(<Place>[place]));
        await execution;

        expect(viewModel.nearContent, <Event>[event]);
        expect(notifications, 0);
        expect(reportedErrors, isEmpty);
        expect(viewModel.loadNearContent.completed, isTrue);
      },
    );

    test(
      'Nearby execution after disposal does not clear prior content',
      () async {
        final event = makeEvent();
        events.getByCoordinatesResult = Result.success(<Event>[event]);
        await viewModel.loadNearContent.execute(const LatLng(41, 14));
        expect(viewModel.nearContent, <Event>[event]);

        viewModel.dispose();
        disposed = true;
        await viewModel.loadNearContent.execute(const LatLng(42, 15));

        expect(viewModel.nearContent, <Event>[event]);
        expect(events.getByCoordinatesCallCount, 1);
        expect(places.getByCoordinatesCallCount, 1);
        expect(reportedErrors, isEmpty);
      },
    );

    test('Event success updates content and completes Command', () async {
      final event = makeEvent();
      events.getByIdResults[1] = Result.success(event);
      var notifications = 0;
      var commandNotifications = 0;
      viewModel.addListener(() => notifications++);
      viewModel.loadEvent.addListener(() => commandNotifications++);

      await viewModel.loadEvent.execute(1);

      expect(viewModel.content, same(event));
      expect(notifications, 1);
      expect(commandNotifications, 2);
      expect(viewModel.loadEvent.completed, isTrue);
      expect(viewModel.loadEvent.error, isFalse);
      expect(viewModel.loadEvent.running, isFalse);
      expect(reportedErrors, isEmpty);
    });

    test('Place success updates content and completes Command', () async {
      final place = makePlace(remoteId: 2);
      places.getByIdResults[2] = Result.success(place);
      var notifications = 0;
      var commandNotifications = 0;
      viewModel.addListener(() => notifications++);
      viewModel.loadPlace.addListener(() => commandNotifications++);

      await viewModel.loadPlace.execute(2);

      expect(viewModel.content, same(place));
      expect(notifications, 1);
      expect(commandNotifications, 2);
      expect(viewModel.loadPlace.completed, isTrue);
      expect(viewModel.loadPlace.error, isFalse);
      expect(viewModel.loadPlace.running, isFalse);
      expect(reportedErrors, isEmpty);
    });

    test('Repository errors remain Command errors', () async {
      final eventError = TestException('event failed');
      final placeError = TestException('place failed');
      events.getByIdResults[1] = Result.error(eventError);
      places.getByIdResults[2] = Result.error(placeError);

      await viewModel.loadEvent.execute(1);
      await viewModel.loadPlace.execute(2);

      expect(viewModel.loadEvent.error, isTrue);
      expect(viewModel.loadPlace.error, isTrue);
      expect(
        (viewModel.loadEvent.result! as Error<void>).error,
        same(eventError),
      );
      expect(
        (viewModel.loadPlace.result! as Error<void>).error,
        same(placeError),
      );
      expect(reportedErrors, isEmpty);
    });

    test(
      'Nearby success merges events then places with one notification',
      () async {
        final event = makeEvent();
        final place = makePlace(remoteId: 2);
        events.getByCoordinatesResult = Result.success(<Event>[event]);
        places.getByCoordinatesResult = Result.success(<Place>[place]);
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        await viewModel.loadNearContent.execute(const LatLng(41, 14));

        expect(viewModel.nearContent, <Object>[event, place]);
        expect(notifications, 1);
        expect(viewModel.loadNearContent.completed, isTrue);
        expect(places.getByCoordinatesCallCount, 1);
        expect(reportedErrors, isEmpty);
      },
    );

    test('Nearby keeps first-error precedence and partial successes', () async {
      final eventError = TestException('events failed');
      final place = makePlace(remoteId: 2);
      events.getByCoordinatesResult = Result.error(eventError);
      places.getByCoordinatesResult = Result.success(<Place>[place]);

      await viewModel.loadNearContent.execute(const LatLng(41, 14));

      expect(viewModel.nearContent, <Place>[place]);
      expect(viewModel.loadNearContent.error, isTrue);
      expect(
        (viewModel.loadNearContent.result! as Error<void>).error,
        same(eventError),
      );
      expect(reportedErrors, isEmpty);
    });
  });
}
