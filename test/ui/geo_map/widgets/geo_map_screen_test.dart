import 'dart:async' show Completer;

import 'package:command_it/command_it.dart' as command_it;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/combined_weather_forecast_response.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_selection_intent.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_post.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_search_results.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';
import '../../../support/recording_tile_http_client.dart';
import '../../../support/weather_harness.dart';

void main() {
  final response = CombinedWeatherForecastResponse(
    latitude: 41.56,
    longitude: 14.66,
    generationTimeMs: 1,
    utcOffsetSeconds: 7200,
    timezone: 'Europe/Rome',
    timezoneAbbreviation: 'CEST',
    elevation: 700,
    current: CurrentWeatherForecastData(
      time: DateTime.utc(2026, 4, 7, 10),
      interval: 900,
      temperature2m: 18.5,
      isDay: 1,
      weatherCode: 0,
      precipitation: 0,
    ),
    hourly: const HourlyWeatherForecastData(
      time: [],
      temperature2m: [],
      weatherCode: [],
      precipitationProbability: [],
      isDay: [],
    ),
    daily: const DailyWeatherForecastData(
      time: [],
      weatherCode: [],
      temperature2mMax: [],
      temperature2mMin: [],
      precipitationProbabilityMax: [],
    ),
  );
  for (final invalidPayload in <ContentBase?>[makePlace(), null]) {
    testWidgets('invalid ${invalidPayload == null ? 'null' : 'type'} payload '
        'never commits and produces one terminal feedback', (tester) async {
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository()..pendingGetById[1] = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searches = _buildSearchViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            initialContentId: 1,
            initialContentType: ContentType.event,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      expect(events.getByIdCallCount, 1);
      var notifications = 0;
      void observeCommit() {
        if (vm.selectedContent != null) notifications++;
      }

      vm.addListener(observeCommit);
      // Typed repositories cannot return these values. Inject the public
      // terminal snapshot to prove the shared VM/Screen validation pipeline.
      (vm.selectContent.results
              as ValueNotifier<
                command_it.CommandResult<
                  GeoMapSelectionIntent?,
                  Result<ContentBase?>?
                >
              >)
          .value = command_it.CommandResult.data(
        const EventSelection(1),
        Result.success(invalidPayload),
      );
      await pumpCommandTurns(tester);
      expect(vm.selectedContent, isNull);
      expect(notifications, 0);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(events.getByIdCallCount, 1);
      pending.complete(Result.error(TestException('physical lookup settled')));
      await pumpCommandTurns(tester);
      expect(vm.selectedContent, isNull);
      expect(notifications, 0);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      expect(events.getByIdCallCount, 1);
      vm.removeListener(observeCommit);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in ['pending', 'success', 'default_local']) {
    testWidgets(
      'same URI $state retains selection while Weather owner changes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pending = Completer<Result<Event>>();
        final events = FakeEventRepository(
          getByIdResults: {1: Result.success(makeEvent())},
        );
        if (state == 'pending') events.pendingGetById[1] = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: FakePlaceRepository(),
          ),
        );
        final searches = _buildSearchViewModel();
        final oldWeatherClient = FakeWeatherApiClient(
          result: Result.success(response),
        );
        final oldWeather = buildWeatherViewModel(
          MockLogger(),
          weatherApiClient: oldWeatherClient,
        );
        final weatherOwner = ValueNotifier(oldWeather);
        addTearDown(weatherOwner.dispose);
        await tester.pumpWidget(
          _buildApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: ValueListenableBuilder<WeatherViewModel>(
              valueListenable: weatherOwner,
              builder: (_, weather, _) => GeoMapScreen(
                initialContentId: state == 'default_local' ? null : 1,
                initialContentType: state == 'default_local'
                    ? null
                    : ContentType.event,
                viewModel: vm,
                searchViewModel: searches,
                weatherViewModel: weather,
              ),
            ),
          ),
        );
        await pumpCommandTurns(tester);
        if (state != 'pending') await tester.pumpAndSettle();
        if (state == 'default_local') {
          tester
              .widget<GeoMapBottomSheet>(find.byType(GeoMapBottomSheet))
              .onContentPressed(makePlace(remoteId: 2));
          await tester.pumpAndSettle();
        }
        final beforeState = tester.state(find.byType(GeoMapScreen));
        final beforeSnapshot = vm.selectContent.results.value;
        final sheet = tester.widget<GeoMapBottomSheet>(
          find.byType(GeoMapBottomSheet),
        );
        if (state != 'pending') {
          final animation = sheet.controller.animateTo(
            0.7,
            duration: const Duration(milliseconds: 1),
            curve: Curves.linear,
          );
          await tester.pumpAndSettle();
          await animation;
        }
        final newWeatherClient = FakeWeatherApiClient(
          result: Result.success(response),
        );
        final newWeather = buildWeatherViewModel(
          MockLogger(),
          weatherApiClient: newWeatherClient,
        );
        weatherOwner.value = newWeather;
        await pumpCommandTurns(tester);
        expect(tester.state(find.byType(GeoMapScreen)), same(beforeState));
        expect(vm.selectContent.results.value, same(beforeSnapshot));
        expect(events.getByIdCallCount, state == 'default_local' ? 0 : 1);
        expect(() => oldWeather.addListener(() {}), throwsFlutterError);
        if (state == 'pending') {
          expect(find.byType(SliverSkeletonizer), findsOneWidget);
          pending.complete(Result.success(makeEvent()));
        } else {
          expect(find.byType(GeoMapModalPost), findsOneWidget);
          expect(sheet.controller.size, closeTo(0.7, 0.01));
        }
        await tester.pumpAndSettle();
        await pumpCommandTurns(tester);
        expect(newWeather.loadCurrentForecast.completed, isTrue);
        expect(newWeatherClient.getCombinedWeatherForecastCallCount, 1);
        expect(
          oldWeatherClient.getCombinedWeatherForecastCallCount,
          state == 'pending' ? 0 : 1,
        );
        expect(events.getByIdCallCount, state == 'default_local' ? 0 : 1);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        searches.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final stale in [false, true]) {
    testWidgets('${stale ? 'stale' : 'latest'} runtime failure reports once '
        'with ${stale ? 'zero stale' : 'one terminal'} feedback', (
      tester,
    ) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final pending = Completer<Result<Event>>();
      final events = FakeEventRepository(
        getByIdResults: {2: Result.success(makeEvent(remoteId: 2))},
      );
      events.pendingGetById[1] = pending;
      final vm = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: events,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final id = ValueNotifier(1);
      addTearDown(id.dispose);
      final searches = _buildSearchViewModel();
      final weather = _buildWeatherViewModel();
      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: ValueListenableBuilder<int>(
            valueListenable: id,
            builder: (_, requested, _) => GeoMapScreen(
              initialContentId: requested,
              initialContentType: ContentType.event,
              viewModel: vm,
              searchViewModel: searches,
              weatherViewModel: weather,
            ),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      if (stale) {
        id.value = 2;
        await tester.pumpAndSettle();
      }
      final failure = StateError('repository runtime failure');
      pending.completeError(failure, StackTrace.current);
      await pumpCommandTurns(tester);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(failure));
      expect(
        find.text('Contenuto non trovato'),
        stale ? findsNothing : findsOneWidget,
      );
      expect(vm.selectedContent?.remoteId, stale ? 2 : isNull);
      expect(events.getByIdCallCount, stale ? 2 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      searches.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final transition in ['search', 'close', 'local_content']) {
    testWidgets(
      'pending route lookup cannot replace local $transition transition',
      (tester) async {
        final pending = Completer<Result<Event>>();
        final events = FakeEventRepository();
        events.pendingGetById[1] = pending;
        final vm = GeoMapViewModel(
          geoMapUseCase: GeoMapUseCase(
            eventRepository: events,
            placeRepository: FakePlaceRepository(),
          ),
        );
        final searches = _buildSearchViewModel();
        await tester.pumpWidget(
          _buildApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: GeoMapScreen(
              initialContentId: 1,
              initialContentType: ContentType.event,
              viewModel: vm,
              searchViewModel: searches,
              weatherViewModel: _buildWeatherViewModel(),
            ),
          ),
        );
        await pumpCommandTurns(tester);
        expect(events.getByIdCallCount, 1);
        final sheet = tester.widget<GeoMapBottomSheet>(
          find.byType(GeoMapBottomSheet),
        );
        switch (transition) {
          case 'search':
            tester
                .widget<AnimatedGeoMapSearchBar>(
                  find.byType(AnimatedGeoMapSearchBar),
                )
                .onSubmitted!('molise');
          case 'close':
            sheet.onCloseButtonPressed();
          case 'local_content':
            sheet.onContentPressed(makePlace(remoteId: 2));
        }
        pending.complete(Result.success(makeEvent()));
        await tester.pumpAndSettle();
        expect(vm.selectedContent, isNull);
        expect(find.text('Contenuto non trovato'), findsNothing);
        if (transition == 'local_content') {
          expect(
            tester
                .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
                .content
                .remoteId,
            2,
          );
        } else {
          expect(find.byType(GeoMapModalPost), findsNothing);
        }
        if (transition == 'search') {
          expect(find.byType(GeoMapModalSearchResults), findsOneWidget);
        }
        expect(events.getByIdCallCount, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        searches.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('same route with replacement selection owner resolves anew', (
    tester,
  ) async {
    final oldEvents = FakeEventRepository();
    final newEvents = FakeEventRepository();
    final oldPending = Completer<Result<Event>>();
    final newPending = Completer<Result<Event>>();
    oldEvents.pendingGetById[1] = oldPending;
    newEvents.pendingGetById[1] = newPending;
    final oldVm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: oldEvents,
        placeRepository: FakePlaceRepository(),
      ),
    );
    final newVm = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: newEvents,
        placeRepository: FakePlaceRepository(),
      ),
    );
    final owner = ValueNotifier(oldVm);
    addTearDown(owner.dispose);
    final searches = _buildSearchViewModel();
    final weather = _buildWeatherViewModel();
    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: ValueListenableBuilder<GeoMapViewModel>(
          valueListenable: owner,
          builder: (_, vm, _) => GeoMapScreen(
            initialContentId: 1,
            initialContentType: ContentType.event,
            viewModel: vm,
            searchViewModel: searches,
            weatherViewModel: weather,
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);
    owner.value = newVm;
    await pumpCommandTurns(tester);
    expect(oldEvents.getByIdCallCount, 1);
    expect(newEvents.getByIdCallCount, 1);
    newPending.complete(Result.success(makeEvent(name: 'New owner content')));
    await tester.pumpAndSettle();
    oldPending.complete(Result.error(TestException('old owner')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GeoMapModalPost>(find.byType(GeoMapModalPost)).content.name,
      'New owner content',
    );
    expect(find.text('Contenuto non trovato'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    oldVm.dispose();
    newVm.dispose();
    searches.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'content resolution is safe while the sheet controller attaches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searchViewModel = SearchViewModel(
        searchRepository: _FakeSearchRepository(),
      );
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final contentIdentity = ValueNotifier<({int id, ContentType type})?>(
        null,
      );
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) =>
                ValueListenableBuilder<({int id, ContentType type})?>(
                  valueListenable: contentIdentity,
                  builder: (_, identity, _) => GeoMapScreen(
                    initialContentId: identity?.id,
                    initialContentType: identity?.type,
                    viewModel: geoMapViewModel,
                    searchViewModel: searchViewModel,
                    weatherViewModel: weatherViewModel,
                  ),
                ),
          ),
        ],
      );
      addTearDown(contentIdentity.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        Provider<http.Client>.value(
          value: RecordingTileHttpClient(),
          child: ChangeNotifierProvider<FavouriteViewModel>.value(
            value: favouriteViewModel,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      contentIdentity.value = (id: event.remoteId, type: ContentType.event);
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);

      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a suggestion while a post is selected shows search results',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final searchViewModel = SearchViewModel(
        searchRepository: _FakeSearchRepository(),
      );
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            getByIdResults: {event.remoteId: Result.success(event)},
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => GeoMapScreen(
              initialContentId: event.remoteId,
              initialContentType: ContentType.event,
              viewModel: geoMapViewModel,
              searchViewModel: searchViewModel,
              weatherViewModel: weatherViewModel,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        Provider<http.Client>.value(
          value: RecordingTileHttpClient(),
          child: ChangeNotifierProvider<FavouriteViewModel>.value(
            value: favouriteViewModel,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(GeoMapModalPost), findsOneWidget);

      final searchBar = tester.widget<AnimatedGeoMapSearchBar>(
        find.byType(AnimatedGeoMapSearchBar),
      );
      searchBar.onSuggestionPressed(event);
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 1));

      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(GeoMapModalSearchResults), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);
    },
  );

  for (final content in <ContentBase>[makeEvent(), makePlace(remoteId: 2)]) {
    final contentType = content is Event ? 'event' : 'place';
    testWidgets(
      'renders supplied $contentType content without resolving it again',
      (tester) async {
        final sheetController = DraggableScrollableController();
        addTearDown(sheetController.dispose);

        final geoMapViewModel = _buildGeoMapViewModel();

        await tester.pumpWidget(
          _buildBottomSheetApp(
            favouriteViewModel: _buildFavouriteViewModel(),
            child: GeoMapBottomSheet(
              content: content,
              isResolvingRequestedSelection: false,
              controller: sheetController,
              currentCenter: content.coordinates,
              onCloseButtonPressed: () {},
              onContentPressed: (_) {},
              onVerticalDragUpdate: (_) {},
              viewModel: geoMapViewModel,
              searchViewModel: _buildSearchViewModel(),
              weatherViewModel: _buildWeatherViewModel(),
              searchQuery: content.name,
            ),
          ),
        );
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 1));

        if (content is Event) {
          expect(geoMapViewModel.selectContent.results.value.idle, isTrue);
        } else {
          expect(geoMapViewModel.selectContent.results.value.idle, isTrue);
        }
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(GeoMapModalPost), findsOneWidget);
        expect(
          tester
              .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
              .content
              .remoteId,
          content.remoteId,
        );
      },
    );
  }

  testWidgets('resolving selection hides stale content', (tester) async {
    final staleContent = makeEvent();
    final sheetController = DraggableScrollableController();
    final geoMapViewModel = _buildGeoMapViewModel();
    addTearDown(sheetController.dispose);

    await tester.pumpWidget(
      _buildBottomSheetApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: GeoMapBottomSheet(
          content: staleContent,
          isResolvingRequestedSelection: true,
          controller: sheetController,
          currentCenter: staleContent.coordinates,
          onCloseButtonPressed: () {},
          onContentPressed: (_) {},
          onVerticalDragUpdate: (_) {},
          viewModel: geoMapViewModel,
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: _buildWeatherViewModel(),
        ),
      ),
    );
    await pumpCommandTurns(tester);

    expect(geoMapViewModel.selectContent.results.value.idle, isTrue);
    expect(find.byType(SliverSkeletonizer), findsOneWidget);
    expect(find.byType(GeoMapModalPost), findsNothing);
  });

  testWidgets('recreates the post when the selected identity changes', (
    tester,
  ) async {
    final first = makeEvent();
    final second = makeEvent(remoteId: 2, name: 'Evento 2');
    final selectedContent = ValueNotifier<ContentBase>(first);
    final sheetController = DraggableScrollableController();
    final geoMapViewModel = _buildGeoMapViewModel();
    final searchViewModel = _buildSearchViewModel();
    final weatherViewModel = _buildWeatherViewModel();
    addTearDown(selectedContent.dispose);
    addTearDown(sheetController.dispose);

    await tester.pumpWidget(
      _buildBottomSheetApp(
        favouriteViewModel: _buildFavouriteViewModel(),
        child: ValueListenableBuilder<ContentBase>(
          valueListenable: selectedContent,
          builder: (_, content, _) => GeoMapBottomSheet(
            content: content,
            isResolvingRequestedSelection: false,
            controller: sheetController,
            currentCenter: content.coordinates,
            onCloseButtonPressed: () {},
            onContentPressed: (_) {},
            onVerticalDragUpdate: (_) {},
            viewModel: geoMapViewModel,
            searchViewModel: searchViewModel,
            weatherViewModel: weatherViewModel,
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);

    final firstPost = find.byKey(ValueKey((first.runtimeType, first.remoteId)));
    expect(firstPost, findsOneWidget);
    final firstElement = tester.element(firstPost);

    selectedContent.value = second;
    await pumpCommandTurns(tester);

    final secondPost = find.byKey(
      ValueKey((second.runtimeType, second.remoteId)),
    );
    expect(firstPost, findsNothing);
    expect(secondPost, findsOneWidget);
    expect(tester.element(secondPost), isNot(same(firstElement)));
  });

  testWidgets('explicit close from selected content resets the sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = makeEvent();
    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel(event: event);

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: GeoMapScreen(
          initialContentId: event.remoteId,
          initialContentType: ContentType.event,
          viewModel: _buildGeoMapViewModel(event: event),
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: weatherViewModel,
        ),
      ),
    );
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(GeoMapModalPost), findsOneWidget);

    expect(find.byTooltip('Chiudi'), findsOneWidget);
    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalPost), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit close from search results resets the sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel();

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: GeoMapScreen(
          initialContentId: null,
          initialContentType: null,
          viewModel: _buildGeoMapViewModel(),
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: weatherViewModel,
        ),
      ),
    );
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));

    final searchBar = tester.widget<AnimatedGeoMapSearchBar>(
      find.byType(AnimatedGeoMapSearchBar),
    );
    searchBar.onSubmitted!('festival');
    await tester.pumpAndSettle();
    expect(find.byType(GeoMapModalSearchResults), findsOneWidget);

    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalSearchResults), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back does not silently reset the sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = makeEvent();
    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel(event: event);

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: GeoMapScreen(
          initialContentId: event.remoteId,
          initialContentType: ContentType.event,
          viewModel: _buildGeoMapViewModel(event: event),
          searchViewModel: _buildSearchViewModel(),
          weatherViewModel: weatherViewModel,
        ),
      ),
    );
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(GeoMapModalPost), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalPost), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'deep-linked content resolves once and never returns to a skeleton',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final eventRepository = ControllableEventRepository();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            initialContentId: event.remoteId,
            initialContentType: ContentType.event,
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      expect(eventRepository.getByIdCallCount, 1);
      expect(eventRepository.pendingGetById, contains(event.remoteId));
      expect(find.byType(SliverSkeletonizer), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);

      eventRepository.completeGetById(event.remoteId, Result.success(event));
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();

      // A second completion is a no-op because displaying content does not
      // start another show command.
      eventRepository.completeGetById(
        event.remoteId,
        Result.error(TestException('Unexpected second lookup')),
      );
      await pumpCommandTurns(tester);

      expect(eventRepository.getByIdCallCount, 1);
      expect(eventRepository.pendingGetById, isEmpty);
      expect(find.byType(SliverSkeletonizer), findsNothing);
      expect(find.byType(GeoMapModalPost), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed deep-link resolution replaces the skeleton with feedback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final eventRepository = ControllableEventRepository();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: _buildFavouriteViewModel(),
          child: GeoMapScreen(
            initialContentId: event.remoteId,
            initialContentType: ContentType.event,
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: _buildWeatherViewModel(),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      expect(find.byType(SliverSkeletonizer), findsOneWidget);

      eventRepository.completeGetById(
        event.remoteId,
        Result.error(TestException('Event unavailable')),
      );
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);

      expect(find.byType(SliverSkeletonizer), findsNothing);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mismatched repository response has zero invalid commit and zero retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The repository returns a different content on success: the exact
      // "wrong id, no error" state that would previously retry forever.
      final event = makeEvent(remoteId: 2, name: 'Evento sbagliato');
      final eventRepository = ControllableEventRepository();
      final geoMapViewModel = GeoMapViewModel(
        geoMapUseCase: GeoMapUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = _buildFavouriteViewModel();

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: favouriteViewModel,
          child: GeoMapScreen(
            initialContentId: 1,
            initialContentType: ContentType.event,
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: weatherViewModel,
          ),
        ),
      );
      await pumpCommandTurns(tester);

      eventRepository.completeGetById(1, Result.success(event));
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(eventRepository.getByIdCallCount, 1);
      expect(geoMapViewModel.selectedContent, isNull);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid navigation resolves B before A physically settles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = makeEvent(name: 'Evento 1');
    final second = makeEvent(remoteId: 2, name: 'Evento 2');
    final eventRepository = ControllableEventRepository();
    final geoMapViewModel = GeoMapViewModel(
      geoMapUseCase: GeoMapUseCase(
        eventRepository: eventRepository,
        placeRepository: FakePlaceRepository(),
      ),
    );
    final weatherViewModel = _buildWeatherViewModel();
    final favouriteViewModel = _buildFavouriteViewModel();
    final contentIdentity = ValueNotifier<({int id, ContentType type})?>((
      id: 1,
      type: ContentType.event,
    ));
    addTearDown(contentIdentity.dispose);

    await tester.pumpWidget(
      _buildApp(
        favouriteViewModel: favouriteViewModel,
        child: ValueListenableBuilder<({int id, ContentType type})?>(
          valueListenable: contentIdentity,
          builder: (_, identity, _) => GeoMapScreen(
            initialContentId: identity?.id,
            initialContentType: identity?.type,
            viewModel: geoMapViewModel,
            searchViewModel: _buildSearchViewModel(),
            weatherViewModel: weatherViewModel,
          ),
        ),
      ),
    );
    await pumpCommandTurns(tester);

    contentIdentity.value = (id: 2, type: ContentType.event);
    await pumpCommandTurns(tester);
    expect(eventRepository.getByIdCallCount, 2);
    eventRepository.completeGetById(1, Result.success(first));
    await pumpCommandTurns(tester);
    expect(eventRepository.getByIdCallCount, 2);
    expect(find.byType(SliverSkeletonizer), findsOneWidget);

    // The new request resolves the requested content. The sheet renders
    // the resolved object directly and never re-executes the show command.
    eventRepository.completeGetById(2, Result.success(second));
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(eventRepository.getByIdCallCount, 2);
    expect(find.byType(SliverSkeletonizer), findsNothing);
    expect(
      tester
          .widget<GeoMapModalPost>(find.byType(GeoMapModalPost))
          .content
          .remoteId,
      2,
    );
    expect(find.text('Contenuto non trovato'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'route removal and disposal produce no controller or setState errors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final event = makeEvent();
      final weatherViewModel = _buildWeatherViewModel();
      final favouriteViewModel = _buildFavouriteViewModel(event: event);

      await tester.pumpWidget(
        _buildApp(
          favouriteViewModel: favouriteViewModel,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => GeoMapScreen(
                          initialContentId: event.remoteId,
                          initialContentType: ContentType.event,
                          viewModel: _buildGeoMapViewModel(event: event),
                          searchViewModel: _buildSearchViewModel(),
                          weatherViewModel: weatherViewModel,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open map'),
                ),
              ),
            ),
          ),
        ),
      );
      await pumpCommandTurns(tester);

      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();
      expect(find.byType(GeoMapModalPost), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Open map'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _buildApp({
  required FavouriteViewModel favouriteViewModel,
  required Widget child,
}) {
  final router = GoRouter(
    routes: <RouteBase>[GoRoute(path: '/', builder: (_, _) => child)],
  );
  addTearDown(router.dispose);
  return Provider<http.Client>.value(
    value: RecordingTileHttpClient(),
    child: ChangeNotifierProvider<FavouriteViewModel>.value(
      value: favouriteViewModel,
      child: MaterialApp.router(
        scaffoldMessengerKey: $scaffoldMessengerKey,
        routerConfig: router,
      ),
    ),
  );
}

Widget _buildBottomSheetApp({
  required FavouriteViewModel favouriteViewModel,
  required Widget child,
}) {
  return ChangeNotifierProvider<FavouriteViewModel>.value(
    value: favouriteViewModel,
    child: MaterialApp(
      home: Scaffold(body: SizedBox(height: 800, child: child)),
    ),
  );
}

GeoMapViewModel _buildGeoMapViewModel({Event? event}) {
  return GeoMapViewModel(
    geoMapUseCase: GeoMapUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {
          if (event != null) event.remoteId: Result.success(event),
        },
      ),
      placeRepository: FakePlaceRepository(),
    ),
  );
}

SearchViewModel _buildSearchViewModel() {
  return SearchViewModel(searchRepository: _FakeSearchRepository());
}

FavouriteViewModel _buildFavouriteViewModel({Event? event}) {
  return FavouriteViewModel(
    favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
      eventRepository: FakeEventRepository(
        getByIdResults: {
          if (event != null) event.remoteId: Result.success(event),
        },
      ),
      placeRepository: FakePlaceRepository(),
    ),
  );
}

WeatherViewModel _buildWeatherViewModel() {
  final weatherApiClient = CachedWeatherApiClient(
    weatherApiClient: FakeWeatherApiClient(),
    currentWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
        >(maxSize: 8),
    hourlyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
        >(maxSize: 8),
    dailyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<DailyWeatherForecastData>
        >(maxSize: 8),
    logger: MockLogger(),
  );

  return WeatherViewModel(
    weatherApiClient: weatherApiClient,
    weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
    weatherCodeIconMapper: const WmoWeatherIconMapper(),
  );
}

final class _FakeSearchRepository implements SearchRepository {
  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      const Result.success(null);

  @override
  Future<Result<List<ContentBase>>> getResultsByQuery(String text) async =>
      const Result.success([]);

  @override
  Future<Result<List<String>>> getPastSearches() async =>
      const Result.success([]);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      const Result.success(null);
}
