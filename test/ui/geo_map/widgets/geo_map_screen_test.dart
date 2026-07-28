import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
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

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  testWidgets('skips content animation while the sheet is detached', (
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
    final contentExtra = ValueNotifier<Event?>(null);
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<Event?>(
            valueListenable: contentExtra,
            builder: (_, content, _) => GeoMapScreen(
              contentExtra: content,
              viewModel: geoMapViewModel,
              searchViewModel: searchViewModel,
              weatherViewModel: weatherViewModel,
            ),
          ),
        ),
      ],
    );
    addTearDown(contentExtra.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<FavouriteViewModel>.value(
        value: favouriteViewModel,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    contentExtra.value = event;
    await tester.pump();

    final bottomSheet = tester.widget<GeoMapBottomSheet>(
      find.byType(GeoMapBottomSheet),
    );
    expect(bottomSheet.controller.isAttached, isFalse);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.takeException(), isNull);
  });

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
              contentExtra: event,
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

  testWidgets(
    'selected content remains structurally safe when searchQuery is non-empty',
    (
      tester,
    ) async {
      final event = makeEvent();
      final sheetController = DraggableScrollableController();
      addTearDown(sheetController.dispose);

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

      await tester.pumpWidget(
        ChangeNotifierProvider<FavouriteViewModel>.value(
          value: favouriteViewModel,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 800,
                child: GeoMapBottomSheet(
                  content: event,
                  searchQuery: event.name,
                  controller: sheetController,
                  currentCenter: event.coordinates,
                  onCloseButtonPressed: () {},
                  onContentPressed: (_) {},
                  onVerticalDragUpdate: (_) {},
                  viewModel: geoMapViewModel,
                  searchViewModel: searchViewModel,
                  weatherViewModel: weatherViewModel,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(GeoMapModalPost), findsOneWidget);
    },
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
