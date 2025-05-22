import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/repositories/core/repository_sync_result.dart';
import 'package:moliseis/data/repositories/core/repository_sync_state.dart';
import 'package:moliseis/domain/models/geo_map/geo_map_state.dart';
import 'package:moliseis/routing/core_routes.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_screen.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_screen.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/search_result.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:provider/provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _exploreShellNavigatorKey = GlobalKey<NavigatorState>();
final _searchShellNavigatorKey = GlobalKey<NavigatorState>();
final _galleryShellNavigatorKey = GlobalKey<NavigatorState>();
final _mapShellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  redirect: (context, state) {
    final repositoryViewModel = context.read<SyncViewModel>();

    if (repositoryViewModel.state == RepositorySyncState.loading) {
      return RoutePaths.sync;
    }

    if (repositoryViewModel.state == RepositorySyncState.done &&
        repositoryViewModel.result != RepositorySyncResult.majorError &&
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
    StatefulShellRoute.indexedStack(
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          navigatorKey: _exploreShellNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.home,
              name: RouteNames.home,
              builder: (_, _) => const ExploreScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.homeSearchResults,
                  name: RouteNames.homeSearchResults,
                  builder: (context, state) {
                    final viewModel = SearchViewModel(
                      attractionRepository: context.read(),
                      searchRepository: context.read(),
                    );

                    return SearchResult(
                      viewModel: viewModel,
                      query: state.pathParameters['query'],
                    );
                  },
                ),
                storyRoute(routeName: RouteNames.homeStory),
                categoriesRoute(
                  routeName: RouteNames.exploreCategories,
                  childRouteName: RouteNames.exploreCategoriesStory,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _searchShellNavigatorKey,
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
                storyRoute(routeName: RouteNames.favouritesStory),
                categoriesRoute(
                  routeName: RouteNames.favouritesCategory,
                  childRouteName: RouteNames.favouritesCategoryStory,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _galleryShellNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.gallery,
              name: RouteNames.gallery,
              builder: (_, _) {
                return const GalleryScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _mapShellNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.geoMap,
              name: RouteNames.geoMap,
              builder: (context, state) {
                final mapState =
                    state.extra as GeoMapState? ?? const GeoMapState();
                final viewModel = GeoMapViewModel(
                  attractionRepository: context.read(),
                );

                return GeoMapScreen(mapState: mapState, viewModel: viewModel);
              },
            ),
          ],
        ),
      ],
      builder: (_, _, navigationShell) {
        return ScaffoldShell(navigationShell: navigationShell);
      },
    ),
  ],
);
