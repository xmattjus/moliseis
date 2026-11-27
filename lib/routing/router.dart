import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/use-cases/geo_map_use_case.dart';
import 'package:moliseis/routing/admin_route_history.dart';
import 'package:moliseis/routing/admin_submission_exit_policy.dart';
import 'package:moliseis/routing/core_routes.dart';
import 'package:moliseis/routing/explicit_back.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_route.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_screen.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/logging_screen.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/events_screen.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_screen.dart';
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
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
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
  final adminExit = AdminSubmissionExitPolicy(adminAuthViewModel);
  late final AdminRouteHistoryRouter appRouter;
  Object? contentSubmissionTransitionOwner;

  Object? acquireContentSubmissionTransition() {
    if (contentSubmissionTransitionOwner != null) return null;
    final token = Object();
    contentSubmissionTransitionOwner = token;
    return token;
  }

  void releaseContentSubmissionTransition(Object token) {
    if (identical(contentSubmissionTransitionOwner, token)) {
      contentSubmissionTransitionOwner = null;
    }
  }

  void releaseAfterRouteRemoval(Object token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      releaseContentSubmissionTransition(token);
    });
  }

  final routing = RoutingConfig(
    onEnter: (context, current, next, router) {
      if (router is AdminRouteHistoryRouter &&
          (router.removingRetiredAdmin || router.validatingRestoredHistory)) {
        return const Allow();
      }
      final decision = adminExit.onEnter(context, current, next, router);
      if (next.matchedLocation != RoutePaths.gallery) return decision;

      OnEnterResult observe(OnEnterResult result) {
        if (result is Block) GalleryPreviewScreen.refuseOpening(next.extra);
        return result;
      }

      return decision is OnEnterResult
          ? observe(decision)
          : decision.then(observe);
    },
    redirect: (context, state) =>
        _redirectForSync(context, syncViewModel, state) ??
        _redirectForAdminAuth(adminAuthViewModel, state),
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
        onExit: (context, _) async {
          final token = acquireContentSubmissionTransition();
          if (token == null) return false;
          ContentSubmissionViewModel? owner;
          String? identity;
          var exiting = false;
          bool current() {
            if (!context.mounted) return false;
            final captured = owner;
            return captured != null &&
                identical(
                  context.read<ContentSubmissionViewModel?>(),
                  captured,
                ) &&
                captured.state.clientSubmissionId == identity;
          }

          try {
            if (!context.mounted) return false;
            final viewModel = context.read<ContentSubmissionViewModel>();
            owner = viewModel;
            identity = viewModel.state.clientSubmissionId;
            if (viewModel.isSubmitting ||
                viewModel.submissionFinalizationPending) {
              return false;
            }
            if (!viewModel.hasUnsavedChanges) {
              releaseAfterRouteRemoval(token);
              exiting = true;
              return true;
            }
            final choice = await showDialog<UnsavedChangesDecision>(
              context: context,
              builder: (_) => const UnsavedChangesDialog(),
            );
            if (!context.mounted) return false;
            if (!current() ||
                viewModel.isSubmitting ||
                viewModel.submissionFinalizationPending) {
              return false;
            }
            final result = switch (choice) {
              UnsavedChangesDecision.saveAndExit =>
                await viewModel.checkpointDraft(),
              UnsavedChangesDecision.discardAndExit =>
                await viewModel.restoreCheckpointDraft(),
              UnsavedChangesDecision.cancel || null => null,
            };
            if (!context.mounted) return false;
            if (!current() ||
                viewModel.isSubmitting ||
                viewModel.submissionFinalizationPending) {
              return false;
            }
            if (result == null) return false;
            if (result is Error<void>) {
              showSnackBarGenericError(context: context);
              return false;
            }
            releaseAfterRouteRemoval(token);
            exiting = true;
            return true;
          } on Object catch (error, stack) {
            if (error is AssertionError) rethrow;
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                context: ErrorDescription('leaving a content submission form'),
              ),
            );
            if (current()) showSnackBarGenericError(context: context);
            return false;
          } finally {
            if (!exiting) releaseContentSubmissionTransition(token);
          }
        },
        builder: (context, _) {
          final viewModel = context
              .select<ContentSubmissionViewModel, ContentSubmissionViewModel>(
                (owner) => owner,
              );
          return ContentSubmissionScreen(
            viewModel: viewModel,
            acquireTransition: acquireContentSubmissionTransition,
            releaseTransition: releaseContentSubmissionTransition,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.contentSubmissionUploadProgress,
            name: RouteNames.contentSubmissionUploadProgress,
            builder: (context, _) {
              final viewModel = context
                  .select<
                    ContentSubmissionViewModel,
                    ContentSubmissionViewModel
                  >((owner) => owner);
              return ContentSubmissionProgressScreen(viewModel: viewModel);
            },
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(
          path: RoutePaths.logging,
          name: RouteNames.logging,
          builder: (_, _) => LoggingScreen(talker: $talker!),
        ),
      GoRoute(
        path: RoutePaths.adminLoginLocation,
        name: RouteNames.adminLogin,
        builder: (context, _) =>
            AdminLoginScreen(viewModel: context.read<AdminAuthViewModel>()),
      ),
      GoRoute(
        path: RoutePaths.admin,
        name: RouteNames.adminDashboard,
        pageBuilder: (context, state) {
          final authority = appRouter.admittedAuthority;
          return MaterialPage<void>(
            key: state.pageKey.value == RoutePaths.admin
                ? ValueKey((state.pageKey, authority))
                : state.pageKey,
            name: state.name,
            child: _adminBoundary(
              adminAuthViewModel,
              authority,
              ChangeNotifierProvider<AdminSubmissionsViewModel>(
                create: (context) {
                  final viewModel = AdminSubmissionsViewModel(
                    repository: context.read(),
                    auth: adminAuthViewModel,
                    authority: authority,
                  );
                  unawaited(viewModel.refreshSubmissions());
                  return viewModel;
                },
                builder: (context, _) => AdminDashboardScreen(
                  viewModel: context.read<AdminSubmissionsViewModel>(),
                  authViewModel: adminAuthViewModel,
                  draftRepository: context
                      .read<AdminSubmissionDraftRepository>(),
                ),
              ),
            ),
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.adminSubmissionsNew,
            name: RouteNames.adminSubmissionNew,
            onExit: (context, state) =>
                appRouter.removingRetiredAdmin || !adminAuthViewModel.isAdmin
                ? true
                : adminExit.exit(context, state),
            builder: (context, state) {
              final authority = appRouter.admittedAuthority;
              return AdminSubmissionEditorRoute(
                viewModel: context.read<AdminSubmissionEditorViewModel>(),
                auth: adminAuthViewModel,
                authority: authority,
                exitPolicy: adminExit,
                exitLocation: state.matchedLocation,
                sessionId: state.uri.queryParameters['session'],
              );
            },
          ),
          GoRoute(
            path: RoutePaths.adminSubmissionSaveProgress,
            name: RouteNames.adminSubmissionSaveProgress,
            onExit: (context, state) {
              final owner = context.read<AdminSubmissionEditorViewModel>();
              final session = state.uri.queryParameters['session'];
              final attempt = int.tryParse(
                state.uri.queryParameters['attempt'] ?? '',
              );
              return appRouter.removingRetiredAdmin ||
                  !adminAuthViewModel.isAdmin ||
                  owner.sessionId != session ||
                  owner.saveExecutionId != attempt ||
                  !owner.isSaveRunning;
            },
            builder: (context, state) {
              final authority = appRouter.admittedAuthority;
              final owner = context.read<AdminSubmissionEditorViewModel>();
              final session = state.uri.queryParameters['session'];
              final progress = AdminSubmissionSaveProgressScreen(
                viewModel: owner,
                sessionId: session,
                attemptId: int.tryParse(
                  state.uri.queryParameters['attempt'] ?? '',
                ),
                editorTarget: state.uri.queryParameters['editor'],
              );
              // Missing or malformed presentation metadata cannot admit work.
              if (session == null) {
                return _adminBoundary(adminAuthViewModel, authority, progress);
              }
              return AdminSubmissionEditorRoute(
                viewModel: owner,
                auth: adminAuthViewModel,
                authority: authority,
                sessionId: session,
                exitPolicy: adminExit,
                child: progress,
              );
            },
          ),
          GoRoute(
            path: RoutePaths.adminSubmission,
            name: RouteNames.adminSubmissionEditor,
            onExit: (context, state) =>
                appRouter.removingRetiredAdmin || !adminAuthViewModel.isAdmin
                ? true
                : adminExit.exit(context, state),
            builder: (context, state) {
              final authority = appRouter.admittedAuthority;
              final id = RouteParameters.submissionId(
                state.pathParameters['id'],
              );
              if (id == null) {
                return _adminBoundary(
                  adminAuthViewModel,
                  authority,
                  RouteErrorScreen(
                    uri: state.uri,
                    error: GoException(
                      'Invalid submission id "${state.pathParameters['id']}"',
                    ),
                    onBack: (context) =>
                        requestExplicitBack(context, predecessorOnly: true),
                  ),
                );
              }

              return AdminSubmissionEditorRoute(
                viewModel: context.read<AdminSubmissionEditorViewModel>(),
                auth: adminAuthViewModel,
                authority: authority,
                submissionId: id,
                exitPolicy: adminExit,
                exitLocation: state.matchedLocation,
                sessionId: state.uri.queryParameters['session'],
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.gallery,
        name: RouteNames.gallery,
        pageBuilder: GalleryPreviewScreen.buildPage,
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
                          unawaited(viewModel.refreshHomeDiscovery());
                          return viewModel;
                        },
                      ),
                      ChangeNotifierProvider<ExploreViewModel>(
                        create: (context) =>
                            ExploreViewModel(placeRepository: context.read()),
                      ),
                      ChangeNotifierProvider<SuggestionViewModel>(
                        create: (context) => SuggestionViewModel(
                          placeRepository: context.read(),
                        ),
                      ),
                      ChangeNotifierProvider<SearchViewModel>(
                        create: (context) =>
                            SearchViewModel(searchRepository: context.read()),
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
                    parentNavigatorKey: _exploreShellNavigatorKey,
                    path: RoutePaths.homeSearchResults,
                    name: RouteNames.homeSearchResult,
                    builder: (_, state) {
                      final query = state.uri.queryParameters['q'] ?? '';

                      return BranchDetailPopScope(
                        branchIndex: 0,
                        child: ChangeNotifierProvider(
                          key: ValueKey(query),
                          create: (context) {
                            final viewModel = SearchViewModel(
                              searchRepository: context.read(),
                            );

                            viewModel.loadResults.run(query);

                            return viewModel;
                          },
                          builder: (context, _) => SearchResultScreen(
                            query: query,
                            viewModel: context.read(),
                          ),
                        ),
                      );
                    },
                    routes: <RouteBase>[
                      postRoute(
                        name: RouteNames.homeSearchResultPost,
                        parentNavigatorKey: _exploreShellNavigatorKey,
                        branchIndex: 0,
                      ),
                    ],
                  ),
                  postRoute(
                    name: RouteNames.homePost,
                    parentNavigatorKey: _exploreShellNavigatorKey,
                    branchIndex: 0,
                  ),
                  categoryRoute(
                    name: RouteNames.homeCategory,
                    childName: RouteNames.homeCategoryPost,
                    parentNavigatorKey: _exploreShellNavigatorKey,
                    branchIndex: 0,
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
                    parentNavigatorKey: _favouritesShellNavigatorKey,
                    branchIndex: 1,
                  ),
                  categoryRoute(
                    name: RouteNames.favouritesCategory,
                    childName: RouteNames.favouritesCategoryPost,
                    parentNavigatorKey: _favouritesShellNavigatorKey,
                    branchIndex: 1,
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
                      final viewModel = EventViewModel(
                        repository: context.read(),
                      );
                      viewModel.selectDate(viewModel.currentCalendarDate);
                      return viewModel;
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
                    parentNavigatorKey: _eventsShellNavigatorKey,
                    branchIndex: 2,
                  ),
                  categoryRoute(
                    name: RouteNames.eventsCategory,
                    childName: RouteNames.eventsCategoryPost,
                    parentNavigatorKey: _eventsShellNavigatorKey,
                    branchIndex: 2,
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
                  final contentId = RouteParameters.contentId(
                    state.uri.queryParameters['contentId'],
                  );
                  final contentType = RouteParameters.contentType(
                    state.uri.queryParameters['type'],
                  );

                  // Weather is content-specific. Its inexpensive ViewModel is
                  // replaced with the URI so overlapping forecasts cannot
                  // share a Command across different selected content.
                  final weatherViewModel = WeatherViewModel(
                    weatherApiClient: context.read(),
                    weatherDescriptionMapper:
                        const WmoWeatherDescriptionMapper(),
                    weatherCodeIconMapper: const WmoWeatherIconMapper(),
                  );

                  return MultiProvider(
                    providers: <SingleChildWidget>[
                      ChangeNotifierProvider<GeoMapViewModel>(
                        create: (context) => GeoMapViewModel(
                          geoMapUseCase: GeoMapUseCase(
                            eventRepository: context.read(),
                            placeRepository: context.read(),
                          ),
                        ),
                      ),
                      ChangeNotifierProvider<SearchViewModel>(
                        create: (context) =>
                            SearchViewModel(searchRepository: context.read()),
                      ),
                    ],
                    child: Builder(
                      builder: (context) => GeoMapScreen(
                        routeSelection: contentId != null && contentType != null
                            ? (id: contentId, type: contentType)
                            : null,
                        viewModel: context.read<GeoMapViewModel>(),
                        searchViewModel: context.read<SearchViewModel>(),
                        weatherViewModel: weatherViewModel,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
        pageBuilder: (_, state, navigationShell) {
          return MaterialPage<void>(
            restorationId: 'appShellPage',
            child: ScaffoldShell(navigationShell: navigationShell),
          );
        },
      ),
    ],
  );
  return appRouter = AdminRouteHistoryRouter(
    routing: routing,
    observers: [if (kDebugMode) TalkerRouteObserver($talker!)],
    auth: adminAuthViewModel,
    onAuthorityRetired: adminExit.retireAuthority,
    navigatorKey: _rootNavigatorKey,
    refreshListenable: Listenable.merge([
      syncViewModel.sync.results,
      syncViewModel.sync.isRunning,
    ]),
    errorPageBuilder: (_, state) {
      final error = RouteErrorScreen(
        uri: state.uri,
        error: state.error,
        onBack: (context) =>
            requestExplicitBack(context, unmatchedError: state.error),
      );
      return MaterialPage<void>(
        key: state.pageKey,
        restorationId: state.pageKey.value,
        child: isProtectedAdminLocation(state.uri.path)
            ? _adminBoundary(
                adminAuthViewModel,
                appRouter.admittedAuthority,
                error,
              )
            : error,
      );
    },
  );
}

/// Retires protected pixels, input, focus and semantics before route disposal.
Widget _adminBoundary(
  AdminAuthViewModel auth,
  AdminAuthority? authority,
  Widget child,
) {
  return ListenableBuilder(
    listenable: auth,
    child: child,
    builder: (context, child) =>
        authority != null && identical(auth.authority, authority)
        ? child!
        : const SizedBox.expand(),
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

  if (sync.isRunningSync.value) {
    return onSync ? null : RoutePaths.syncFor(state.uri);
  }

  if (!onSync || (sync.results.value.hasFailure && syncViewModel.fatalError)) {
    return null;
  }

  return _validatedFrom(context, state.uri.queryParameters['from']) ??
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
  final location = state.matchedLocation.toLowerCase();
  if (location == RoutePaths.adminLoginLocation) {
    return adminAuthViewModel.isAdmin ? RoutePaths.admin : null;
  }

  return !isProtectedAdminLocation(location) || adminAuthViewModel.isAdmin
      ? null
      : RoutePaths.adminLoginLocation;
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
