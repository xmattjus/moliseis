import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

import '../support/fake_cache_manager.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';

void main() {
  group('buildAppRouter admin auth guard', () {
    testWidgets('redirects an anonymous user from /admin to the login', (
      tester,
    ) async {
      final harness = _AdminRouteHarness();
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.adminLoginLocation,
      );
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(harness.repository.listCallCount, 0);
    });

    testWidgets('redirects an anonymous user from an admin child to login', (
      tester,
    ) async {
      final harness = _AdminRouteHarness();
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go('/admin/submissions/12');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.adminLoginLocation,
      );
      expect(harness.repository.listCallCount, 0);
    });

    testWidgets('redirects a permanent non-admin user from /admin to login', (
      tester,
    ) async {
      final harness = _AdminRouteHarness(initialUser: makeAuthUser());
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.adminLoginLocation,
      );
      expect(harness.repository.listCallCount, 0);
    });

    testWidgets('keeps an admin user on the dashboard', (tester) async {
      final harness = _AdminRouteHarness(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.admin,
      );
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('redirects an admin user from the login to the dashboard', (
      tester,
    ) async {
      final harness = _AdminRouteHarness(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go(RoutePaths.adminLoginLocation);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.admin,
      );
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('keeps an anonymous user on settings', (tester) async {
      final harness = _AdminRouteHarness();
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go(RoutePaths.settings);
      await tester.pumpWidget(harness.app(withSettingsProviders: true));
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('keeps an admin user on settings', (tester) async {
      final harness = _AdminRouteHarness(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go(RoutePaths.settings);
      await tester.pumpWidget(harness.app(withSettingsProviders: true));
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('refreshes from login to dashboard after an auth event', (
      tester,
    ) async {
      final harness = _AdminRouteHarness();
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

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
    });

    testWidgets('refreshes from dashboard to login after a sign-out event', (
      tester,
    ) async {
      final harness = _AdminRouteHarness(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

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
    });

    testWidgets('settings entry preserves back navigation after login', (
      tester,
    ) async {
      final harness = _AdminRouteHarness();
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);
      when(
        () => harness.auth.client.signInWithPassword(
          email: 'redazione@example.com',
          password: 'password-sicura',
        ),
      ).thenAnswer((_) async {
        harness.auth
          ..setUser(makeAuthUser(isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        return MockAuthResponse();
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
      expect(
        harness.router.routerDelegate.state.uri.path,
        RoutePaths.admin,
      );
      expect(harness.repository.listCallCount, 1);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        harness.router.routerDelegate.state.uri.path,
        RoutePaths.settings,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('builds the real create editor route for an admin', (
      tester,
    ) async {
      final harness = _AdminRouteHarness(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go('/admin/submissions/new');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/admin/submissions/new',
      );
      expect(find.text('Nuovo contributo'), findsOneWidget);
    });

    testWidgets('shows the route error screen for an invalid submission id', (
      tester,
    ) async {
      final harness = _AdminRouteHarness(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(harness.router.dispose);
      addTearDown(harness.auth.dispose);

      harness.router.go('/admin/submissions/abc');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
    });
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
    settingsRepository = FakeSettingsRepository(lastSyncedAt: DateTime.now());
    syncViewModel = SyncViewModel(
      syncUseCase: SyncUseCase(
        cityRepository: FakeCityRepository(),
        eventRepository: FakeEventRepository(),
        mediaRepository: FakeMediaRepository(),
        placeRepository: FakePlaceRepository(),
        settingsRepository: settingsRepository,
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
        ChangeNotifierProvider<AdminAuthViewModel>.value(
          value: auth.viewModel,
        ),
        Provider<AdminContentSubmissionRepository>.value(value: repository),
        Provider<ContentSubmissionRepository>.value(
          value: FakeContentSubmissionRepository(),
        ),
        Provider<CacheManager>.value(value: FakeCacheManager()),
        if (withSettingsProviders) ...<SingleChildWidget>[
          Provider<SettingsRepository>.value(value: settingsRepository),
          Provider<Logger>.value(value: logger),
          Provider<UrlLaunchService>(
            create: (_) => UrlLaunchService(logger: logger),
          ),
          ChangeNotifierProvider<ThemeViewModel>(
            create: (_) => ThemeViewModel(
              settingsRepository: settingsRepository,
            ),
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
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          FlutterQuillLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('en'), Locale('it')],
      ),
    );
  }
}
