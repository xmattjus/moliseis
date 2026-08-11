import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/explore_get_by_id_use_case.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
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
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  testWidgets(
    'content resolution is safe while the sheet controller attaches',
    (
      tester,
    ) async {
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
        eventRepository: FakeEventRepository(),
        exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
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
        ChangeNotifierProvider<FavouriteViewModel>.value(
          value: favouriteViewModel,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      contentIdentity.value = (id: event.remoteId, type: ContentType.event);
      await tester.pump();
      await tester.pump();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a suggestion while a post is selected shows search results',
    (
      tester,
    ) async {
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
        eventRepository: FakeEventRepository(),
        exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
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
        ChangeNotifierProvider<FavouriteViewModel>.value(
          value: favouriteViewModel,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(GeoMapModalPost), findsOneWidget);

      final searchBar = tester.widget<AnimatedGeoMapSearchBar>(
        find.byType(AnimatedGeoMapSearchBar),
      );
      searchBar.onSuggestionPressed(event);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(GeoMapModalSearchResults), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);
    },
  );

  for (final content in <ContentBase>[
    makeEvent(),
    makePlace(remoteId: 2),
  ]) {
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
              searchQuery: content.name,
              controller: sheetController,
              currentCenter: content.coordinates,
              onCloseButtonPressed: () {},
              onContentPressed: (_) {},
              onVerticalDragUpdate: (_) {},
              viewModel: geoMapViewModel,
              searchViewModel: _buildSearchViewModel(),
              weatherViewModel: _buildWeatherViewModel(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        if (content is Event) {
          expect(geoMapViewModel.showEvent.idle, isTrue);
        } else {
          expect(geoMapViewModel.showPlace.idle, isTrue);
        }
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
    await tester.pump();

    expect(geoMapViewModel.showEvent.idle, isTrue);
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
    await tester.pump();

    final firstPost = find.byKey(ValueKey((first.runtimeType, first.remoteId)));
    expect(firstPost, findsOneWidget);
    final firstElement = tester.element(firstPost);

    selectedContent.value = second;
    await tester.pump();

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(GeoMapModalPost), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalPost), findsNothing);
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
    await tester.pump();
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(GeoMapModalPost), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();

    expect(find.byType(GeoMapModalPost), findsOneWidget);
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
      await tester.pump();

      expect(eventRepository.getByIdCallCount, 1);
      expect(eventRepository.pendingGetById, contains(event.remoteId));
      expect(find.byType(SliverSkeletonizer), findsOneWidget);
      expect(find.byType(GeoMapModalPost), findsNothing);

      eventRepository.completeGetById(event.remoteId, Result.success(event));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // A second completion is a no-op because displaying content does not
      // start another show command.
      eventRepository.completeGetById(
        event.remoteId,
        Result.error(TestException('Unexpected second lookup')),
      );
      await tester.pump();

      expect(eventRepository.getByIdCallCount, 1);
      expect(eventRepository.pendingGetById, isEmpty);
      expect(find.byType(SliverSkeletonizer), findsNothing);
      expect(find.byType(GeoMapModalPost), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed deep-link resolution replaces the skeleton with feedback',
    (
      tester,
    ) async {
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
      await tester.pump();

      expect(find.byType(SliverSkeletonizer), findsOneWidget);

      eventRepository.completeGetById(
        event.remoteId,
        Result.error(TestException('Event unavailable')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SliverSkeletonizer), findsNothing);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mismatched repository response terminates after the retry limit',
    (
      tester,
    ) async {
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
      await tester.pump();

      // The first completion mismatches: exactly one retry is issued.
      eventRepository.completeGetById(1, Result.success(event));
      await tester.pump();
      await tester.pump();
      expect(eventRepository.getByIdCallCount, 2);

      // The retry returns the same mismatched content: the resolution becomes
      // terminal with user feedback instead of retrying forever.
      eventRepository.completeGetById(1, Result.success(event));
      await tester.pump();
      await tester.pump();

      expect(eventRepository.getByIdCallCount, 2);
      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Contenuto non trovato'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid navigation to a new id resolves the new id through the retry path',
    (
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
      final contentIdentity = ValueNotifier<({int id, ContentType type})?>(
        (id: 1, type: ContentType.event),
      );
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
      await tester.pump();

      // The resolution for id 1 is still in flight when the location changes
      // to id 2: the second execute() is silently dropped by the running
      // command, so no new repository call is issued yet.
      contentIdentity.value = (id: 2, type: ContentType.event);
      await tester.pump();
      expect(eventRepository.getByIdCallCount, 1);

      // Completing id 1 surfaces the mismatch: the listener retries id 2.
      eventRepository.completeGetById(1, Result.success(first));
      await tester.pump();
      await tester.pump();
      expect(eventRepository.getByIdCallCount, 2);
      expect(find.byType(SliverSkeletonizer), findsOneWidget);

      // The retried request resolves the requested content. The sheet renders
      // the resolved object directly and never re-executes the show command.
      eventRepository.completeGetById(2, Result.success(second));
      await tester.pump();
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
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route removal and disposal produce no controller or setState errors',
    (
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
      await tester.pump();

      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();
      expect(find.byType(GeoMapModalPost), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(GeoMapModalPost), findsNothing);
      expect(find.text('Open map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _buildApp({
  required FavouriteViewModel favouriteViewModel,
  required Widget child,
}) {
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => child),
    ],
  );
  addTearDown(router.dispose);
  return ChangeNotifierProvider<FavouriteViewModel>.value(
    value: favouriteViewModel,
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      routerConfig: router,
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
      home: Scaffold(
        body: SizedBox(height: 800, child: child),
      ),
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
  return SearchViewModel(
    eventRepository: FakeEventRepository(),
    exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
    searchRepository: _FakeSearchRepository(),
  );
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
        >(
          maxSize: 8,
        ),
    hourlyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
        >(
          maxSize: 8,
        ),
    dailyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<DailyWeatherForecastData>
        >(
          maxSize: 8,
        ),
    logger: MockLogger(),
  );

  return WeatherViewModel(
    weatherApiClient: weatherApiClient,
    weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
    weatherCodeIconMapper: const WmoWeatherIconMapper(),
  );
}

final class _FakeExploreGetByIdUseCase implements ExploreGetByIdUseCase {
  @override
  Future<Result<Place>> getById(int id) async =>
      Result.error(TestException('Place $id not configured'));
}

final class _FakeSearchRepository implements SearchRepository {
  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      const Result.success(null);

  @override
  Future<Result<List<int>>> getEventIdsByQuery(String text) async =>
      const Result.success([]);

  @override
  Future<Result<List<int>>> getPlaceIdsByQuery(String text) async =>
      const Result.success([]);

  @override
  Future<Result<List<String>>> getPastSearches() async =>
      const Result.success([]);

  @override
  Future<Result<List<int>>> getRelatedResults(String text) async =>
      const Result.success([]);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      const Result.success(null);
}
