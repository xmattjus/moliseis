import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/mock_gotrue_client.dart';
import '../../../support/mock_logger.dart';

void main() {
  group('SettingsScreen editorial area entry', () {
    late ControllableAdminAuth auth;
    late GoRouter router;
    late Widget app;

    setUp(() {
      auth = ControllableAdminAuth();
      final repository = FakeSettingsRepository();
      final logger = MockLogger();
      router = GoRouter(
        initialLocation: RoutePaths.settings,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          ),
          GoRoute(
            path: RoutePaths.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminLoginLocation,
            builder: (_, _) => const Scaffold(body: Text('LOGIN_MARKER')),
          ),
          GoRoute(
            path: RoutePaths.admin,
            builder: (_, _) => const Scaffold(body: Text('ADMIN_MARKER')),
          ),
        ],
      );
      app = MultiProvider(
        providers: <SingleChildWidget>[
          Provider<SettingsRepository>.value(value: repository),
          Provider<Logger>.value(value: logger),
          Provider<UrlLaunchService>(
            create: (_) => UrlLaunchService(logger: logger),
          ),
          ChangeNotifierProvider<ThemeViewModel>(
            create: (_) => ThemeViewModel(settingsRepository: repository),
          ),
          ChangeNotifierProvider<SettingsViewModel>(
            create: (_) => SettingsViewModel(
              settingsRepository: repository,
              sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
            ),
          ),
          ChangeNotifierProvider<AdminAuthViewModel>.value(
            value: auth.viewModel,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
    });

    testWidgets('renders the editorial area entry', (tester) async {
      await tester.pumpWidget(app);

      expect(find.text('Area redazione'), findsOneWidget);
      expect(
        find.text('Rivedi e cura i contributi della community'),
        findsOneWidget,
      );
    });

    testWidgets('pushes anonymous users to login and preserves settings', (
      tester,
    ) async {
      await tester.pumpWidget(app);
      await tester.tap(find.text('Area redazione'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.uri.path,
        RoutePaths.adminLoginLocation,
      );
      expect(find.text('LOGIN_MARKER'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.uri.path,
        RoutePaths.settings,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('pushes admin users to the dashboard', (tester) async {
      auth
        ..setUser(makeAuthUser(isAdmin: true))
        ..emit(AuthChangeEvent.signedIn);
      await tester.pumpWidget(app);
      await tester.pump();

      await tester.tap(find.text('Area redazione'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.state.uri.path,
        RoutePaths.admin,
      );
      expect(find.text('ADMIN_MARKER'), findsOneWidget);
    });
  });
}
