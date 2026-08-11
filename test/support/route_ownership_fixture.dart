import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/routing/core_routes.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'fake_cache_manager.dart';
import 'fake_repositories.dart';
import 'fixtures.dart';
import 'mock_logger.dart';

/// Test router that mirrors the production route tree while exercising the
/// real [postRoute] and [categoryRoute] factories.
///
/// The four tab roots and the search-results page use lightweight stub screens
/// because the ownership assertions inspect the Navigator page stacks, not the
/// root screens. The category and post routes are the production factories, so
/// their `parentNavigatorKey` behavior is exercised exactly as shipped.
///
/// The fixture intentionally excludes the production sync redirect, which is
/// not part of route ownership.
final class RouteOwnershipFixture {
  RouteOwnershipFixture() {
    eventRepository = FakeEventRepository(
      getByIdResults: <int, Result<Event>>{
        1: Result.success(makeEvent(remoteId: 1)),
        2: Result.success(makeEvent(remoteId: 2)),
      },
      getByCoordinatesResult: const Result.success(<Event>[]),
    );
    placeRepository = FakePlaceRepository(
      getByIdResults: <int, Result<Place>>{
        2: Result.success(makePlace(remoteId: 2)),
      },
      getByCoordinatesResult: const Result.success(<Place>[]),
    );
    cacheManager = FakeCacheManager();
    weatherApiClient = CachedWeatherApiClient(
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

    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.home,
      errorBuilder: (_, state) => RouteErrorScreen(
        uri: state.uri,
        error: state.error,
      ),
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.gallery,
          name: RouteNames.gallery,
          builder: (_, state) {
            final data = GalleryPreviewRouteData.tryParse(state.extra);
            return data == null
                ? const GalleryUnavailableScreen()
                : GalleryPreviewScreen(data: data);
          },
        ),
        StatefulShellRoute.indexedStack(
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              navigatorKey: exploreNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.home,
                  name: RouteNames.home,
                  builder: (_, _) => const _StubScreen(label: 'Home'),
                  routes: <RouteBase>[
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: RoutePaths.homeSearchResults,
                      name: RouteNames.homeSearchResult,
                      builder: (_, state) => _StubScreen(
                        label: 'Search ${state.uri.queryParameters['q'] ?? ''}',
                      ),
                      routes: <RouteBase>[
                        postRoute(
                          name: RouteNames.homeSearchResultPost,
                          parentNavigatorKey: rootNavigatorKey,
                        ),
                      ],
                    ),
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: RoutePaths.homeSearchResultsLegacy,
                      redirect: redirectLegacySearchResults,
                    ),
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: RoutePaths.homeSearchResultsLegacyPost,
                      redirect: redirectLegacySearchResults,
                    ),
                    postRoute(
                      name: RouteNames.homePost,
                      parentNavigatorKey: rootNavigatorKey,
                    ),
                    categoryRoute(
                      name: RouteNames.homeCategory,
                      childName: RouteNames.homeCategoryPost,
                      parentNavigatorKey: rootNavigatorKey,
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: favouritesNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.favourites,
                  name: RouteNames.favourites,
                  builder: (_, _) => const _StubScreen(label: 'Favourites'),
                  routes: <RouteBase>[
                    postRoute(
                      name: RouteNames.favouritesPost,
                      parentNavigatorKey: rootNavigatorKey,
                    ),
                    categoryRoute(
                      name: RouteNames.favouritesCategory,
                      childName: RouteNames.favouritesCategoryPost,
                      parentNavigatorKey: rootNavigatorKey,
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: eventsNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.events,
                  name: RouteNames.events,
                  builder: (_, _) => const _StubScreen(label: 'Events'),
                  routes: <RouteBase>[
                    postRoute(
                      name: RouteNames.eventsPost,
                      parentNavigatorKey: rootNavigatorKey,
                    ),
                    categoryRoute(
                      name: RouteNames.eventsCategory,
                      childName: RouteNames.eventsCategoryPost,
                      parentNavigatorKey: rootNavigatorKey,
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: mapNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.geoMap,
                  name: RouteNames.geoMap,
                  builder: (_, _) => const _StubScreen(label: 'Map'),
                ),
              ],
            ),
          ],
          builder: (_, _, navigationShell) => navigationShell,
        ),
      ],
    );
  }

  /// The root Navigator key that owns the shell page and secondary pages.
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// The Explore branch Navigator key.
  final exploreNavigatorKey = GlobalKey<NavigatorState>();

  /// The Favourites branch Navigator key.
  final favouritesNavigatorKey = GlobalKey<NavigatorState>();

  /// The Events branch Navigator key.
  final eventsNavigatorKey = GlobalKey<NavigatorState>();

  /// The Map branch Navigator key.
  final mapNavigatorKey = GlobalKey<NavigatorState>();

  /// The fake event repository backing the post and category routes.
  late final FakeEventRepository eventRepository;

  /// The fake place repository backing the post and category routes.
  late final FakePlaceRepository placeRepository;

  /// The fake cache manager for network-image widgets.
  late final FakeCacheManager cacheManager;

  /// The cached weather API client backing the post route.
  late final CachedWeatherApiClient weatherApiClient;

  /// The fixture router, created in the constructor.
  late final GoRouter router;

  /// All branch Navigator keys in tab order.
  List<GlobalKey<NavigatorState>> get branchNavigatorKeys =>
      <GlobalKey<NavigatorState>>[
        exploreNavigatorKey,
        favouritesNavigatorKey,
        eventsNavigatorKey,
        mapNavigatorKey,
      ];

  /// The currently matched application URI.
  Uri get uri => router.routeInformationProvider.value.uri;

  /// Builds the fixture application around [router] with fake dependencies.
  Widget get app => MultiProvider(
    providers: <SingleChildWidget>[
      Provider<EventRepository>.value(value: eventRepository),
      Provider<PlaceRepository>.value(value: placeRepository),
      Provider<SettingsRepository>.value(value: FakeSettingsRepository()),
      Provider<CachedWeatherApiClient>.value(value: weatherApiClient),
      ChangeNotifierProvider<FavouriteViewModel>(
        create: (_) => FavouriteViewModel(
          favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
            eventRepository: eventRepository,
            placeRepository: placeRepository,
          ),
        ),
      ),
      Provider<CacheManager>.value(value: cacheManager),
    ],
    child: MaterialApp.router(routerConfig: router),
  );

  /// Disposes the router.
  void dispose() {
    router.dispose();
  }
}

/// Lightweight stateful page used for tab roots and the search-results page.
class _StubScreen extends StatefulWidget {
  const _StubScreen({required this.label});

  /// The text rendered in the stub page body.
  final String label;

  @override
  State<_StubScreen> createState() => _StubScreenState();
}

class _StubScreenState extends State<_StubScreen> {
  var _count = 0;

  void _increment() => setState(() => _count++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('${widget.label} root'),
            Text('Count: $_count'),
            FilledButton(
              onPressed: _increment,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
