import 'dart:async' show unawaited;

import 'package:animated_stateful_shell_route/animated_stateful_shell_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/routing/core_routes.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/core/ui/logging_screen.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/events_screen.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_screen.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/search_result_screen.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/ui/user_contribution/view_models/user_contribution_view_model.dart';
import 'package:moliseis/ui/user_contribution/widgets/user_contribution_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:talker_flutter/talker_flutter.dart';

final _eventsShellNavigatorKey = GlobalKey<NavigatorState>();
final _exploreShellNavigatorKey = GlobalKey<NavigatorState>();
final _favouritesShellNavigatorKey = GlobalKey<NavigatorState>();
final _mapShellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  redirect: (context, state) {
    final syncViewModel = context.read<SyncViewModel>();

    if (syncViewModel.sync.running) {
      return RoutePaths.sync;
    }

    if ((syncViewModel.sync.completed ||
            syncViewModel.sync.error && !syncViewModel.fatalError) &&
        state.uri.toString().contains(RoutePaths.sync)) {
      return RoutePaths.home;
    }

    // https://stackoverflow.com/a/78203240
    if (state.fullPath?.isEmpty ?? true) return RoutePaths.home;

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: RoutePaths.sync,
      pageBuilder: (_, _) => const NoTransitionPage(child: SyncScreen()),
    ),
    GoRoute(
      path: RoutePaths.settings,
      name: RouteNames.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: RoutePaths.userContribution,
      name: RouteNames.userContribution,
      builder: (context, _) {
        final viewModel = UserContributionViewModel(
          logger: context.read<Logger>(),
          userContributionRepository: context
              .read<UserContributionRepository>(),
        );
        return UserContributionScreen(viewModel: viewModel);
      },
    ),
    GoRoute(
      path: RoutePaths.logging,
      name: RouteNames.logging,
      builder: (_, _) {
        return LoggingScreen(talker: $talker);
      },
    ),
    AnimatedStatefulShellRoute(
      restorationScopeId: 'appShell',
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          restorationScopeId: 'exploreBranch',
          navigatorKey: _exploreShellNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.home,
              name: RouteNames.home,
              builder: (_, _) {
                return MultiProvider(
                  providers: <SingleChildWidget>[
                    ChangeNotifierProvider<EventViewModel>(
                      create: (context) {
                        final viewModel = EventViewModel(
                          repository: context.read(),
                        );
                        unawaited(viewModel.loadNextIds.execute());
                        return viewModel;
                      },
                    ),
                    ChangeNotifierProvider<ExploreViewModel>(
                      create: (context) => ExploreViewModel(
                        byIdUseCase: ExploreUseCase(
                          eventRepository: context.read(),
                          placeRepository: context.read(),
                        ),
                        placeRepository: context.read(),
                      ),
                    ),
                    ChangeNotifierProvider<SearchViewModel>(
                      create: (context) => SearchViewModel(
                        eventRepository: context.read(),
                        exploreGetByIdUseCase: ExploreUseCase(
                          eventRepository: context.read(),
                          placeRepository: context.read(),
                        ),
                        searchRepository: context.read(),
                      ),
                    ),
                  ],
                  builder: (context, _) {
                    return ExploreScreen(
                      eventViewModel: context.read(),
                      exploreViewModel: context.read(),
                      searchViewModel: context.read(),
                    );
                  },
                );
              },
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.homeSearchResults,
                  name: RouteNames.homeSearchResult,
                  builder: (_, state) {
                    final query = state.pathParameters['query'] ?? '';

                    return ChangeNotifierProvider(
                      create: (context) {
                        final viewModel = SearchViewModel(
                          eventRepository: context.read(),
                          exploreGetByIdUseCase: ExploreUseCase(
                            eventRepository: context.read(),
                            placeRepository: context.read(),
                          ),
                          searchRepository: context.read(),
                        );

                        unawaited(viewModel.loadResults.execute(query));

                        return viewModel;
                      },
                      builder: (context, _) => SearchResultScreen(
                        query: query,
                        viewModel: context.read(),
                      ),
                    );
                  },
                  routes: <RouteBase>[
                    postRoute(name: RouteNames.homeSearchResultPost),
                  ],
                ),
                postRoute(name: RouteNames.homePost),
                categoryRoute(
                  name: RouteNames.homeCategory,
                  childName: RouteNames.homeCategoryPost,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          restorationScopeId: 'favouritesBranch',
          navigatorKey: _favouritesShellNavigatorKey,
          routes: [
            GoRoute(
              path: RoutePaths.favourites,
              name: RouteNames.favourites,
              builder: (context, _) {
                return FavouriteScreen(
                  viewModel: context.read<FavouriteViewModel>(),
                );
              },
              routes: <RouteBase>[
                postRoute(name: RouteNames.favouritesPost),
                categoryRoute(
                  name: RouteNames.favouritesCategory,
                  childName: RouteNames.favouritesCategoryPost,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          restorationScopeId: 'eventsBranch',
          navigatorKey: _eventsShellNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.events,
              name: RouteNames.events,
              builder: (context, _) {
                return ChangeNotifierProvider<EventViewModel>(
                  create: (context) {
                    return EventViewModel(repository: context.read());
                  },
                  child: Consumer<EventViewModel>(
                    builder: (_, viewModel, _) {
                      return EventsScreen(viewModel: viewModel);
                    },
                  ),
                );
              },
              routes: <RouteBase>[
                postRoute(name: RouteNames.eventsPost),
                categoryRoute(
                  name: RouteNames.eventsCategory,
                  childName: RouteNames.eventsCategoryPost,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          restorationScopeId: 'mapBranch',
          navigatorKey: _mapShellNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.geoMap,
              name: RouteNames.geoMap,
              builder: (context, state) {
                final contentExtra = state.extra as ContentBase?;

                final viewModel = GeoMapViewModel(
                  geoMapUseCase: GeoMapUseCase(
                    eventRepository: context.read(),
                    placeRepository: context.read(),
                  ),
                );

                final searchViewModel = SearchViewModel(
                  eventRepository: context.read(),
                  exploreGetByIdUseCase: ExploreUseCase(
                    eventRepository: context.read(),
                    placeRepository: context.read(),
                  ),
                  searchRepository: context.read(),
                );

                final weatherViewModel = WeatherViewModel(
                  weatherApiClient: context.read(),
                  weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
                  weatherCodeIconMapper: const WmoWeatherIconMapper(),
                );

                return GeoMapScreen(
                  // mapState: mapState,
                  contentExtra: contentExtra,
                  viewModel: viewModel,
                  searchViewModel: searchViewModel,
                  weatherViewModel: weatherViewModel,
                );
              },
            ),
          ],
        ),
      ],
      pageBuilder: (_, _, navigationShell) {
        return MaterialPage<void>(
          restorationId: 'appShellPage',
          child: ScaffoldShell(navigationShell: navigationShell),
        );
      },
      transitionBuilder: ShellRouteTransitions.fade,
    ),
  ],
  observers: [
    TalkerRouteObserver($talker),
  ],
  navigatorKey: _rootNavigatorKey,
  restorationScopeId: 'router',
);
