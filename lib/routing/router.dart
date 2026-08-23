import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/routing/core_routes.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_screen.dart';
import 'package:moliseis/ui/core/ui/logging_screen.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/events_screen.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_screen.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/search_result_screen.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:talker_flutter/talker_flutter.dart';

final _eventsShellNavigatorKey = GlobalKey<NavigatorState>();
final _exploreShellNavigatorKey = GlobalKey<NavigatorState>();
final _favouritesShellNavigatorKey = GlobalKey<NavigatorState>();
final _mapShellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildAppRouter({
  required SyncViewModel syncViewModel,
  required AdminAuthViewModel adminAuthViewModel,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.home,
    restorationScopeId: 'router',
    refreshListenable: Listenable.merge([
      syncViewModel.sync,
      adminAuthViewModel,
    ]),
    redirect: (context, state) =>
        _redirectForSync(context, syncViewModel, state) ??
        _redirectForAdminAuth(adminAuthViewModel, state),
    errorBuilder: (_, state) => RouteErrorScreen(
      uri: state.uri,
      error: state.error,
    ),
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
        path: RoutePaths.contentSubmission,
        name: RouteNames.contentSubmission,
        builder: (context, _) {
          final viewModel = context.read<ContentSubmissionViewModel>();
          return ContentSubmissionScreen(viewModel: viewModel);
        },
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.contentSubmissionUploadProgress,
            name: RouteNames.contentSubmissionUploadProgress,
            builder: (context, _) {
              final viewModel = context.read<ContentSubmissionViewModel>();
              return ContentSubmissionProgressScreen(viewModel: viewModel);
            },
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.logging,
        name: RouteNames.logging,
        builder: (_, _) {
          return LoggingScreen(talker: $talker);
        },
      ),
      GoRoute(
        path: RoutePaths.admin,
        name: RouteNames.adminDashboard,
        builder: (context, state) {
          if (state.uri.path == RoutePaths.adminLoginLocation) {
            return const SizedBox.shrink();
          }

          return ChangeNotifierProvider<AdminSubmissionsViewModel>(
            create: (context) {
              final viewModel = AdminSubmissionsViewModel(
                repository: context.read(),
              );
              unawaited(viewModel.load.execute());
              return viewModel;
            },
            builder: (context, _) => AdminDashboardScreen(
              viewModel: context.read<AdminSubmissionsViewModel>(),
              authViewModel: context.read<AdminAuthViewModel>(),
            ),
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.adminLogin,
            name: RouteNames.adminLogin,
            builder: (context, _) => AdminLoginScreen(
              viewModel: context.read<AdminAuthViewModel>(),
            ),
          ),
          GoRoute(
            path: RoutePaths.adminSubmissionsNew,
            name: RouteNames.adminSubmissionNew,
            builder: (context, _) {
              final auth = context.read<AdminAuthViewModel>();
              return ChangeNotifierProvider<AdminSubmissionEditorViewModel>(
                create: (context) => AdminSubmissionEditorViewModel(
                  repository: context.read<AdminContentSubmissionRepository>(),
                  contentSubmissionRepository: context
                      .read<ContentSubmissionRepository>(),
                  creatorName: auth.displayName ?? auth.email,
                  creatorEmail: auth.email,
                ),
                builder: (context, _) => AdminSubmissionEditorScreen(
                  viewModel: context.read<AdminSubmissionEditorViewModel>(),
                ),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.adminSubmission,
            name: RouteNames.adminSubmissionEditor,
            builder: (context, state) {
              final id = RouteParameters.submissionId(
                state.pathParameters['id'],
              );
              if (id == null) {
                return RouteErrorScreen(
                  uri: state.uri,
                  error: GoException(
                    'Invalid submission id "${state.pathParameters['id']}"',
                  ),
                );
              }

              return ChangeNotifierProvider<AdminSubmissionEditorViewModel>(
                key: ValueKey<int>(id),
                create: (context) {
                  final viewModel = AdminSubmissionEditorViewModel(
                    repository: context
                        .read<AdminContentSubmissionRepository>(),
                    contentSubmissionRepository: context
                        .read<ContentSubmissionRepository>(),
                    submissionId: id,
                  );
                  unawaited(viewModel.load.execute());
                  return viewModel;
                },
                builder: (context, _) => AdminSubmissionEditorScreen(
                  viewModel: context.read<AdminSubmissionEditorViewModel>(),
                ),
              );
            },
          ),
        ],
      ),
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
                      ChangeNotifierProvider<SuggestionViewModel>(
                        create: (context) => SuggestionViewModel(
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
                        suggestedViewModel: context.read(),
                      );
                    },
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: RoutePaths.homeSearchResults,
                    name: RouteNames.homeSearchResult,
                    builder: (_, state) {
                      final query = state.uri.queryParameters['q'] ?? '';

                      return ChangeNotifierProvider(
                        key: ValueKey(query),
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
                      postRoute(
                        name: RouteNames.homeSearchResultPost,
                        parentNavigatorKey: _rootNavigatorKey,
                      ),
                    ],
                  ),
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: RoutePaths.homeSearchResultsLegacy,
                    redirect: redirectLegacySearchResults,
                  ),
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: RoutePaths.homeSearchResultsLegacyPost,
                    redirect: redirectLegacySearchResults,
                  ),
                  postRoute(
                    name: RouteNames.homePost,
                    parentNavigatorKey: _rootNavigatorKey,
                  ),
                  categoryRoute(
                    name: RouteNames.homeCategory,
                    childName: RouteNames.homeCategoryPost,
                    parentNavigatorKey: _rootNavigatorKey,
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
                  postRoute(
                    name: RouteNames.favouritesPost,
                    parentNavigatorKey: _rootNavigatorKey,
                  ),
                  categoryRoute(
                    name: RouteNames.favouritesCategory,
                    childName: RouteNames.favouritesCategoryPost,
                    parentNavigatorKey: _rootNavigatorKey,
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
                  postRoute(
                    name: RouteNames.eventsPost,
                    parentNavigatorKey: _rootNavigatorKey,
                  ),
                  categoryRoute(
                    name: RouteNames.eventsCategory,
                    childName: RouteNames.eventsCategoryPost,
                    parentNavigatorKey: _rootNavigatorKey,
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
                redirect: _redirectLegacyMapKey,
                builder: (context, state) {
                  final contentId = RouteParameters.contentId(
                    state.uri.queryParameters['contentId'],
                  );
                  final contentType = RouteParameters.contentType(
                    state.uri.queryParameters['type'],
                  );

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
                    weatherDescriptionMapper:
                        const WmoWeatherDescriptionMapper(),
                    weatherCodeIconMapper: const WmoWeatherIconMapper(),
                  );

                  return GeoMapScreen(
                    initialContentId: contentId,
                    initialContentType: contentType,
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
      ),
    ],
    observers: [
      TalkerRouteObserver($talker),
    ],
  );
}

/// Side-effect-free sync redirect that preserves a requested internal URI.
///
/// Mirrors the Sync Redirect Contract:
/// - sync starts outside `/sync` -> `/sync?from=<encoded current URI>`
/// - sync running on `/sync` -> no redirect
/// - fatal first-sync error on `/sync` -> remain for retry
/// - any other non-running state on `/sync` (completed, non-fatal error, or
///   idle) -> validated `from` URI, otherwise `/home`
String? _redirectForSync(
  BuildContext context,
  SyncViewModel syncViewModel,
  GoRouterState state,
) {
  final sync = syncViewModel.sync;
  final onSync = state.matchedLocation == RoutePaths.sync;

  if (sync.running) {
    return onSync ? null : RoutePaths.syncFor(state.uri);
  }

  if (!onSync || (sync.error && syncViewModel.fatalError)) return null;

  return _validatedFrom(
        context,
        state.uri.queryParameters['from'],
      ) ??
      RoutePaths.home;
}

/// Guards the staff-only route subtree after the sync redirect declined.
///
/// Authenticated staff are sent from the login page to the dashboard. Everyone
/// else is sent from a protected admin location to the full login location;
/// public routes remain reachable for every session type.
String? _redirectForAdminAuth(
  AdminAuthViewModel adminAuthViewModel,
  GoRouterState state,
) {
  final location = state.matchedLocation;
  final isAdminRoute =
      location == RoutePaths.admin ||
      location.startsWith('${RoutePaths.admin}/');
  if (!isAdminRoute) return null;

  if (location == RoutePaths.adminLoginLocation) {
    return adminAuthViewModel.isAdmin ? RoutePaths.admin : null;
  }

  return adminAuthViewModel.isAdmin ? null : RoutePaths.adminLoginLocation;
}

/// Returns the [from] query value only when it is a safe internal URI.
///
/// Rejects external URLs, network-path references, non-leading-slash values,
/// recursive `/sync` targets, and locations not accepted by the router.
String? _validatedFrom(BuildContext context, String? from) {
  if (from == null || from.isEmpty) return null;

  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;

  if (!uri.path.startsWith('/')) return null;

  if (uri.path == RoutePaths.sync) return null;

  if (GoRouter.of(context).configuration.findMatch(uri).isError) return null;

  return from;
}

/// Canonicalizes restored map locations that carried the old random key.
///
/// Compatibility marker: the `key` query parameter is supported only for
/// restored pre-2.3.0 locations and can be removed in the next major release.
String? _redirectLegacyMapKey(BuildContext _, GoRouterState state) {
  final query = state.uri.queryParameters;
  if (!query.containsKey('key')) return null;

  final canonicalQuery = <String, String>{...query}..remove('key');
  return state.uri.replace(queryParameters: canonicalQuery).toString();
}
