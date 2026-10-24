import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/command_test_support.dart';
import '../support/fake_cache_manager.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';
import '../support/recording_tile_http_client.dart';

void main() {
  group('buildAppRouter admin auth guard', () {
    late _AdminRouteHarness harness;
    testOwnerUI(
      'NAV-03 direct anonymous login Back cannot expose dashboard',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.adminLoginLocation);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(harness.repository.listCallCount, 0);

        expect(await tester.binding.handlePopRoute(), isFalse);
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects an anonymous user from /admin to the login',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects an anonymous user from an admin child to login',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go('/admin/submissions/12');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects a permanent non-admin user from /admin to login',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser());

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'keeps an admin user on the dashboard',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.admin,
        );
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects an admin user from the login to the dashboard',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));

        harness.router.go(RoutePaths.adminLoginLocation);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.admin,
        );
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'keeps an anonymous user on settings',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.settings);
        await tester.pumpWidget(harness.app(withSettingsProviders: true));
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.settings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'keeps an admin user on settings',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));

        harness.router.go(RoutePaths.settings);
        await tester.pumpWidget(harness.app(withSettingsProviders: true));
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.settings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'refreshes from login to dashboard after an auth event',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.adminLoginLocation);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 0);

        harness.auth
          ..setUser(makeAuthUser(isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.admin,
        );
        expect(find.byType(AdminLoginScreen), findsNothing);
        expect(harness.repository.listCallCount, 1);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'refreshes from dashboard to login after a sign-out event',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.byType(AdminDashboardScreen), findsOneWidget);

        harness.auth
          ..setUser(null)
          ..emit(AuthChangeEvent.signedOut);
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'settings entry preserves back navigation after login',
      (tester) async {
        harness = _AdminRouteHarness();
        when(
          () => harness.auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).thenAnswer((_) async {
          harness.auth
            ..setUser(makeAuthUser(isAdmin: true))
            ..emit(AuthChangeEvent.signedIn);
          return AuthResponse(
            user: harness.auth.client.currentUser,
            session: harness.auth.client.currentSession,
          );
        });

        harness.router.go(RoutePaths.settings);
        await tester.pumpWidget(harness.app(withSettingsProviders: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Area redazione'));
        await tester.pumpAndSettle();

        expect(
          harness.router.routerDelegate.state.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 0);

        await tester.enterText(
          find.byType(TextFormField).first,
          'redazione@example.com',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'password-sicura',
        );
        await tester.tap(find.text('Accedi'));
        await tester.pumpAndSettle();

        verify(
          () => harness.auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).called(1);
        expect(harness.router.routerDelegate.state.uri.path, RoutePaths.admin);
        expect(harness.repository.listCallCount, 1);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          harness.router.routerDelegate.state.uri.path,
          RoutePaths.settings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    for (final fromSettings in [false, true]) {
      testOwnerUI(
        'R2/R3 event plus pending login completion navigates once settings=$fromSettings',
        (tester) async {
          harness = _AdminRouteHarness();
          final gate = Completer<AuthResponse>();
          harness.auth.onPassword = () => gate.future;
          harness.router.go(
            fromSettings ? RoutePaths.settings : RoutePaths.adminLoginLocation,
          );
          await tester.pumpWidget(
            harness.app(withSettingsProviders: fromSettings),
          );
          await tester.pumpAndSettle();
          if (fromSettings) {
            await tester.tap(find.text('Area redazione'));
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byType(TextFormField).first,
            'staff@example.com',
          );
          await tester.enterText(find.byType(TextFormField).last, 'secret');
          await tester.tap(find.text('Accedi'));
          await pumpCommandTurns(tester);
          expect(harness.auth.passwordCalls, 1);
          harness.auth
            ..setUser(makeAuthUser(isAdmin: true))
            ..emit(AuthChangeEvent.signedIn);
          final response = AuthResponse(
            user: harness.auth.client.currentUser,
            session: harness.auth.client.currentSession,
          );
          await tester.pumpAndSettle();
          expect(find.byType(AdminDashboardScreen), findsOneWidget);
          expect(harness.auth.viewModel.canLogout, isFalse);
          expect(harness.repository.listCallCount, 1);
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton &&
                        widget.tooltip == 'Esegui il logout',
                  ),
                )
                .onPressed,
            isNull,
          );
          harness.auth.emit(AuthChangeEvent.signedIn);
          gate.complete(response);
          await tester.pumpAndSettle();
          expect(
            harness.router.routerDelegate.state.uri.path,
            RoutePaths.admin,
          );
          expect(harness.repository.listCallCount, 1);
          expect(harness.auth.viewModel.canLogout, isTrue);
          if (fromSettings) {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(
              harness.router.routerDelegate.state.uri.path,
              RoutePaths.settings,
            );
            expect(find.byType(SettingsScreen), findsOneWidget);
          } else {
            expect(await tester.binding.handlePopRoute(), isFalse);
            expect(find.byType(AdminDashboardScreen), findsOneWidget);
          }
        },
        disposeOwners: () {
          harness.auth.dispose();
          harness.syncViewModel.dispose();
          harness.router.dispose();
        },
      );
    }

    testOwnerUI(
      'R2 logout auth event and completion leave a single protected redirect',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));
        final gate = Completer<void>();
        harness.auth.onSignOut = () async {
          harness.auth
            ..setUser(null)
            ..emit(AuthChangeEvent.signedOut);
          await gate.future;
        };
        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(harness.repository.listCallCount, 1);
        expect(harness.auth.viewModel.requestLogout(), isTrue);
        await pumpCommandTurns(tester);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.auth.viewModel.canLogin, isFalse);
        gate.complete();
        await tester.pumpAndSettle();
        harness.auth.emit(AuthChangeEvent.signedOut);
        await tester.pumpAndSettle();
        expect(
          harness.router.routerDelegate.state.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 1);
        expect(harness.auth.signOutCalls, 1);
        expect(harness.auth.anonymousCalls, 1);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'builds the real create editor route for an admin',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));

        harness.router.go('/admin/submissions/new');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          '/admin/submissions/new',
        );
        expect(find.text('Nuovo contributo'), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'shows the route error screen for an invalid submission id',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser(isAdmin: true));

        harness.router.go('/admin/submissions/abc');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );
  });
}

/// Local harness for the admin auth guard.
///
/// Sync is idle by construction, so it declines every redirect and leaves the
/// admin guard as the only active redirect for these route tests.
final class _AdminRouteHarness {
  _AdminRouteHarness({User? initialUser}) {
    auth = ControllableAdminAuth(initialUser: initialUser);
    repository = FakeAdminContentSubmissionRepository();
    settingsRepository = FakeSettingsRepository(
      lastSyncedAt: DateTime.now(),
      contentSyncCursorAt: DateTime.utc(2026, 10, 12),
    );
    syncViewModel = SyncViewModel(
      syncUseCase: SyncUseCase(
        cityRepository: FakeCityRepository(),
        eventRepository: FakeEventRepository(),
        mediaRepository: FakeMediaRepository(),
        placeRepository: FakePlaceRepository(),
        settingsRepository: settingsRepository,
        cursorSource: FakeSyncCursorSource(),
        transactionCoordinator: FakeTransactionCoordinator(),
      ),
    );
    router = buildAppRouter(
      syncViewModel: syncViewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  late final ControllableAdminAuth auth;
  late final FakeAdminContentSubmissionRepository repository;
  late final FakeSettingsRepository settingsRepository;
  late final SyncViewModel syncViewModel;
  late final GoRouter router;

  /// Builds the minimal provider tree required by each tested route.
  Widget app({bool withSettingsProviders = false}) {
    final logger = MockLogger();

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AdminAuthViewModel>.value(value: auth.viewModel),
        Provider<AdminContentSubmissionRepository>.value(value: repository),
        Provider<ContentSubmissionRepository>.value(
          value: FakeContentSubmissionRepository(),
        ),
        Provider<CacheManager>.value(value: FakeCacheManager()),
        Provider<http.Client>.value(value: RecordingTileHttpClient()),
        if (withSettingsProviders) ...<SingleChildWidget>[
          Provider<SettingsRepository>.value(value: settingsRepository),
          Provider<Logger>.value(value: logger),
          Provider<UrlLaunchService>(
            create: (_) => UrlLaunchService(logger: logger),
          ),
          ChangeNotifierProvider<ThemeViewModel>(
            create: (_) =>
                ThemeViewModel(settingsRepository: settingsRepository),
          ),
          ChangeNotifierProvider<SettingsViewModel>(
            create: (_) => SettingsViewModel(
              settingsRepository: settingsRepository,
              sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
            ),
          ),
        ],
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('en'), Locale('it')],
      ),
    );
  }
}
