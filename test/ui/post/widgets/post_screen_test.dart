import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_nearby_content.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';
import '../../../support/recording_tile_http_client.dart';
import '../../../support/weather_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
  });

  group('PostScreen', () {
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
    });

    testWidgets('screen binds completed source and replaces Weather owner', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final oldWeather = buildWeatherViewModel(mockLogger);
      final newWeather = buildWeatherViewModel(mockLogger);
      final owner = ValueNotifier(oldWeather);
      final favourites = _buildFavouriteViewModel(event: event, place: place);
      addTearDown(owner.dispose);
      addTearDown(viewModel.dispose);
      addTearDown(oldWeather.dispose);
      addTearDown(newWeather.dispose);
      addTearDown(favourites.dispose);
      viewModel.loadEvent.run(event.remoteId);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(
        _buildTestApp(
          ValueListenableBuilder(
            valueListenable: owner,
            builder: (_, weather, _) => PostScreen(
              isEvent: true,
              viewModel: viewModel,
              weatherViewModel: weather,
            ),
          ),
          favourites,
        ),
      );
      final expected = (
        id: event.remoteId,
        type: ContentType.event,
        latitude: event.coordinates.latitude,
        longitude: event.coordinates.longitude,
      );
      expect(oldWeather.currentTarget, expected);
      owner.value = newWeather;
      await tester.pump();
      expect(oldWeather.currentTarget, isNull);
      expect(newWeather.currentTarget, expected);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(newWeather.currentTarget, isNull);
      await pumpCommandTurns(tester);
      // command_it retires settled children with a 50ms notifier teardown.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending replacement source cannot reuse old Weather target', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final first = _buildPostViewModel(event: event, place: place);
      first.loadEvent.run(event.remoteId);
      await pumpCommandTurns(tester);
      final pending = Completer<Result<Place>>();
      final places = FakePlaceRepository()
        ..pendingGetById[place.remoteId] = pending;
      final second = PostViewModel(
        postUseCase: PostUseCase(
          eventRepository: FakeEventRepository(),
          placeRepository: places,
        ),
      );
      final weather = buildWeatherViewModel(mockLogger);
      final source = ValueNotifier(first);
      final favourites = _buildFavouriteViewModel(event: event, place: place);
      addTearDown(source.dispose);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(weather.dispose);
      addTearDown(favourites.dispose);
      await tester.pumpWidget(
        _buildTestApp(
          ValueListenableBuilder(
            valueListenable: source,
            builder: (_, vm, _) => PostScreen(
              isEvent: identical(vm, first),
              viewModel: vm,
              weatherViewModel: weather,
            ),
          ),
          favourites,
        ),
      );
      expect(weather.currentTarget?.type, ContentType.event);
      second.loadPlace.run(place.remoteId);
      source.value = second;
      await tester.pump();
      expect(weather.currentTarget, isNull);
      pending.complete(Result.success(place));
      await pumpCommandTurns(tester);
      expect(weather.currentTarget?.type, ContentType.place);
      expect(weather.currentTarget?.id, place.remoteId);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(weather.currentTarget, isNull);
      await pumpCommandTurns(tester);
      // command_it retires settled children with a 50ms notifier teardown.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid Post Nearby coordinates cause no repository lookup', (
      tester,
    ) async {
      final place = makePlace(coordinates: const LatLng(91, 0));
      final events = FakeEventRepository();
      final places = FakePlaceRepository(
        getByIdResults: {place.remoteId: Result.success(place)},
      );
      final viewModel = PostViewModel(
        postUseCase: PostUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      final weather = buildWeatherViewModel(mockLogger);
      final favourites = _buildFavouriteViewModel(
        event: _buildEvent(),
        place: place,
      );
      addTearDown(viewModel.dispose);
      addTearDown(weather.dispose);
      addTearDown(favourites.dispose);
      viewModel.loadPlace.run(place.remoteId);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(
        _buildTestApp(
          PostScreen(
            isEvent: false,
            viewModel: viewModel,
            weatherViewModel: weather,
          ),
          favourites,
        ),
      );
      final scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView).first,
      );
      final section = scroll.slivers
          .whereType<PostSectionNearbyContent>()
          .single;
      section.onLoad();
      expect(events.getByCoordinatesCallCount, 0);
      expect(places.getByCoordinatesCallCount, 0);
      expect(section.readState().pending, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ordinary Post preserves error display without adding retry', (
      tester,
    ) async {
      final place = _buildPlace();
      final failure = TestException('events');
      final events = FakeEventRepository(
        getByCoordinatesResult: Result.error(failure),
      );
      final places = FakePlaceRepository(
        getByIdResults: {place.remoteId: Result.success(place)},
        getByCoordinatesResult: Result.success([makePlace(remoteId: 3)]),
      );
      final vm = PostViewModel(
        postUseCase: PostUseCase(
          eventRepository: events,
          placeRepository: places,
        ),
      );
      final weather = buildWeatherViewModel(mockLogger);
      final favourites = _buildFavouriteViewModel(
        event: _buildEvent(),
        place: place,
      );
      addTearDown(vm.dispose);
      addTearDown(weather.dispose);
      addTearDown(favourites.dispose);
      vm.loadPlace.run(place.remoteId);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(
        _buildTestApp(
          PostScreen(isEvent: false, viewModel: vm, weatherViewModel: weather),
          favourites,
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(PostSectionNearbyContent),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final section = tester.widget<PostSectionNearbyContent>(
        find.byType(PostSectionNearbyContent),
      );
      expect(vm.nearContent, hasLength(1));
      expect(section.readState().pending, isFalse);
      expect(section.readState().items, isEmpty);
      expect(section.readState().error, same(failure));
      expect(section.onRetry, isNull);
      expect(
        find.text('Si è verificato un errore durante il caricamento.'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'captured old Nearby callback cannot load a replacement owner',
      (tester) async {
        final firstPlace = makePlace();
        final secondPlace = makePlace(remoteId: 2);
        final firstEvents = FakeEventRepository();
        final secondEvents = FakeEventRepository();
        final first = PostViewModel(
          postUseCase: PostUseCase(
            eventRepository: firstEvents,
            placeRepository: FakePlaceRepository(
              getByIdResults: {1: Result.success(firstPlace)},
            ),
          ),
        );
        final second = PostViewModel(
          postUseCase: PostUseCase(
            eventRepository: secondEvents,
            placeRepository: FakePlaceRepository(
              getByIdResults: {2: Result.success(secondPlace)},
            ),
          ),
        );
        first.loadPlace.run(1);
        await pumpCommandTurns(tester);
        second.loadPlace.run(2);
        await pumpCommandTurns(tester);
        final source = ValueNotifier(first);
        final weather = buildWeatherViewModel(mockLogger);
        final favourites = _buildFavouriteViewModel(
          event: _buildEvent(),
          place: firstPlace,
        );
        addTearDown(source.dispose);
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        addTearDown(weather.dispose);
        addTearDown(favourites.dispose);
        await tester.pumpWidget(
          _buildTestApp(
            ValueListenableBuilder(
              valueListenable: source,
              builder: (_, vm, _) => PostScreen(
                isEvent: false,
                viewModel: vm,
                weatherViewModel: weather,
              ),
            ),
            favourites,
          ),
        );
        final old = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView).first)
            .slivers
            .whereType<PostSectionNearbyContent>()
            .single;
        source.value = second;
        await tester.pumpAndSettle();
        final secondCalls = secondEvents.getByCoordinatesCallCount;
        final firstCalls = firstEvents.getByCoordinatesCallCount;
        old.onLoad();
        await tester.pumpAndSettle();
        expect(firstEvents.getByCoordinatesCallCount, firstCalls);
        expect(secondEvents.getByCoordinatesCallCount, secondCalls);
        expect(old.readState().pending, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        old.onLoad();
        expect(old.readState().pending, isTrue);
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      },
    );

    for (final isEvent in [true, false]) {
      for (final runtime in [null, StateError('detail'), TypeError()]) {
        testWidgets('${isEvent ? 'Event' : 'Place'} terminal '
            '${runtime?.runtimeType ?? 'domain'} failure '
            'ends loading and recovers Weather', (tester) async {
          final event = _buildEvent();
          final place = _buildPlace();
          final events = FakeEventRepository();
          final places = FakePlaceRepository();
          final pendingEvent = Completer<Result<Event>>();
          final pendingPlace = Completer<Result<Place>>();
          events.pendingGetById[event.remoteId] = pendingEvent;
          places.pendingGetById[place.remoteId] = pendingPlace;
          final vm = PostViewModel(
            postUseCase: PostUseCase(
              eventRepository: events,
              placeRepository: places,
            ),
          );
          final weather = buildWeatherViewModel(mockLogger);
          final favourites = _buildFavouriteViewModel(
            event: event,
            place: place,
          );
          final restore = installCommandTestReporting(mockLogger);
          addTearDown(restore);
          addTearDown(vm.dispose);
          addTearDown(weather.dispose);
          addTearDown(favourites.dispose);
          final command = isEvent ? vm.loadEvent : vm.loadPlace;
          final id = isEvent ? event.remoteId : place.remoteId;
          command.run(id);
          await tester.pumpWidget(
            _buildTestApp(
              PostScreen(
                isEvent: isEvent,
                viewModel: vm,
                weatherViewModel: weather,
              ),
              favourites,
            ),
          );
          await pumpCommandTurns(tester);
          expect(find.text('Caricamento in corso...'), findsOneWidget);
          expect(weather.currentTarget, isNull);
          final failure = TestException('detail');
          final stack = StackTrace.fromString(
            '#0 postOriginal (package:moliseis/post_original.dart:123:45)',
          );
          if (runtime != null) {
            if (isEvent) {
              pendingEvent.completeError(runtime, stack);
            } else {
              pendingPlace.completeError(runtime, stack);
            }
          } else {
            if (isEvent) {
              pendingEvent.complete(Result.error(failure));
            } else {
              pendingPlace.complete(Result.error(failure));
            }
          }
          await pumpCommandTurns(tester);
          expect(find.text('Caricamento in corso...'), findsNothing);
          expect(
            find.text('Si è verificato un errore durante il caricamento.'),
            findsOneWidget,
          );
          expect(find.text('Riprova'), findsNothing);
          expect(weather.currentTarget, isNull);
          expect(() => vm.content, throwsA(anything));
          expect(events.getByCoordinatesCallCount, 0);
          expect(places.getByCoordinatesCallCount, 0);
          expect(
            command.results.value.domainError,
            runtime == null ? same(failure) : isNull,
          );
          expect(
            command.results.value.unexpectedError,
            runtime == null ? isNull : same(runtime),
          );
          expect(mockLogger.calls, runtime == null ? isEmpty : hasLength(1));
          if (runtime != null) {
            expect(mockLogger.calls.single.error, same(runtime));
            expect(
              mockLogger.calls.single.stackTrace.toString(),
              contains('post_original.dart 123:45'),
            );
          }
          events.pendingGetById.clear();
          places.pendingGetById.clear();
          events.getByIdResults[id] = Result.success(event);
          places.getByIdResults[id] = Result.success(place);
          command.run(id);
          expect(weather.currentTarget, isNull);
          await pumpCommandTurns(tester);
          expect(command.results.value.completed, isTrue);
          expect(find.text('Caricamento in corso...'), findsNothing);
          expect(weather.currentTarget?.id, id);
          expect(
            weather.currentTarget?.type,
            isEvent ? ContentType.event : ContentType.place,
          );
          command.run(id);
          expect(weather.currentTarget, isNull);
          await pumpCommandTurns(tester);
          expect(weather.currentTarget?.id, id);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(weather.currentTarget, isNull);
          vm.dispose();
          weather.dispose();
          favourites.dispose();
          await pumpCommandTurns(tester);
          await tester.pump(const Duration(milliseconds: 50));
          await pumpCommandTurns(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('renders EventFormattedDateTime for event content', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = buildWeatherViewModel(mockLogger);
      final favouriteViewModel = _buildFavouriteViewModel(
        event: event,
        place: place,
      );

      viewModel.loadEvent.run(event.remoteId);
      await pumpCommandTurns(tester);

      await tester.pumpWidget(
        _buildTestApp(
          PostScreen(
            isEvent: true,
            viewModel: viewModel,
            weatherViewModel: weatherViewModel,
          ),
          favouriteViewModel,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PostScreen), findsOneWidget);
      expect(find.byType(EventFormattedDateTime), findsOneWidget);
    });

    testWidgets('does not render EventFormattedDateTime for place content', (
      tester,
    ) async {
      final event = _buildEvent();
      final place = _buildPlace();
      final viewModel = _buildPostViewModel(event: event, place: place);
      final weatherViewModel = buildWeatherViewModel(mockLogger);
      final favouriteViewModel = _buildFavouriteViewModel(
        event: event,
        place: place,
      );

      viewModel.loadPlace.run(place.remoteId);
      await pumpCommandTurns(tester);

      await tester.pumpWidget(
        _buildTestApp(
          PostScreen(
            isEvent: false,
            viewModel: viewModel,
            weatherViewModel: weatherViewModel,
          ),
          favouriteViewModel,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PostScreen), findsOneWidget);
      expect(find.byType(EventFormattedDateTime), findsNothing);
    });
  });
}

Widget _buildTestApp(Widget child, FavouriteViewModel favouriteViewModel) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[GoRoute(path: '/', builder: (_, _) => child)],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FavouriteViewModel>.value(
        value: favouriteViewModel,
      ),
      Provider<http.Client>.value(value: RecordingTileHttpClient()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

FavouriteViewModel _buildFavouriteViewModel({
  required Event event,
  required Place place,
}) {
  return FavouriteViewModel(
    favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {event.remoteId: Result.success(event)},
      ),
      placeRepository: FakePlaceRepository(
        getByIdResults: {place.remoteId: Result.success(place)},
      ),
    ),
  );
}

PostViewModel _buildPostViewModel({
  required Event event,
  required Place place,
}) {
  return PostViewModel(
    postUseCase: PostUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {event.remoteId: Result.success(event)},
      ),
      placeRepository: FakePlaceRepository(
        getByIdResults: {place.remoteId: Result.success(place)},
      ),
    ),
  );
}

Event _buildEvent() {
  final event = makeEvent(
    startDate: DateTime(2026, 4, 10, 10, 30),
    endDate: DateTime(2026, 4, 10, 12),
  );

  return Event(
    category: event.category,
    city: event.city,
    coordinates: event.coordinates,
    createdAt: event.createdAt,
    description: event.description,
    media: const [],
    modifiedAt: event.modifiedAt,
    name: event.name,
    remoteId: event.remoteId,
    isSaved: event.isSaved,
    startDate: event.startDate,
    endDate: event.endDate,
  );
}

Place _buildPlace() => makePlace(remoteId: 2);
