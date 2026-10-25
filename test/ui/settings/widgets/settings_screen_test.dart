import 'dart:async';

import 'package:command_it/command_it.dart' as command_it;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
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
    late FakeSettingsRepository repository;

    setUp(() {
      auth = ControllableAdminAuth();
      repository = FakeSettingsRepository();
      final logger = MockLogger();
      router = GoRouter(
        initialLocation: RoutePaths.settings,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.home,
            name: RouteNames.home,
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
        child: Builder(
          builder: (context) => MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            theme: AppThemeData.light(context: context),
            routerConfig: router,
          ),
        ),
      );
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
    });

    for (final outcome in [
      'success',
      'failure',
      'throw',
      'disposed',
      'unmounted',
      'replacement',
    ]) {
      testWidgets('crash-reporting feedback owns its accepted $outcome run', (
        tester,
      ) async {
        final pending = Completer<Result<void>>();
        var writes = 0;
        repository.onSetCrashReporting = (_) {
          writes++;
          return pending.future;
        };
        final reports = <Object>[];
        final oldHandler = command_it.Command.globalExceptionHandler;
        command_it.Command.globalExceptionHandler = (error, _) =>
            reports.add(error.error);
        addTearDown(
          () => command_it.Command.globalExceptionHandler = oldHandler,
        );
        await tester.pumpWidget(app);
        final context = tester.element(find.byType(SettingsScreen));
        final vm = context.read<SettingsViewModel>();
        final callback = tester
            .widget<SwitchListTile>(find.byType(SwitchListTile))
            .onChanged!;
        callback(true);
        callback(true); // This callback did not admit its own execution.
        expect(vm.crashReporting, isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        expect(writes, 1);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
        if (outcome == 'disposed') vm.dispose();
        if (outcome == 'unmounted') {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        SettingsViewModel? replacement;
        ThemeViewModel? replacementTheme;
        if (outcome == 'replacement') {
          replacement = SettingsViewModel(
            settingsRepository: repository,
            sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
          );
          replacementTheme = ThemeViewModel(settingsRepository: repository);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsViewModel>.value(
                  value: replacement,
                ),
                ChangeNotifierProvider<ThemeViewModel>.value(
                  value: replacementTheme,
                ),
              ],
              child: const MaterialApp(home: SettingsScreen()),
            ),
          );
        }
        final thrown = StateError('write failed');
        if (outcome == 'throw') {
          pending.completeError(thrown);
        } else {
          pending.complete(
            outcome == 'failure'
                ? Result.error(TestException('write failed'))
                : const Result.success(null),
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Gli errori verranno inviati al prossimo avvio '
            "dell'app",
          ),
          outcome == 'success' ? findsOneWidget : findsNothing,
        );
        if (outcome == 'failure') {
          expect(
            tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
            isFalse,
          );
        }
        expect(reports, outcome == 'throw' ? [same(thrown)] : isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        replacement?.dispose();
        replacementTheme?.dispose();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 50));
      });
    }

    testWidgets('owner replacement preserves mounted context '
        'and suppresses prior success feedback', (tester) async {
      final pending = Completer<Result<void>>();
      repository.onSetCrashReporting = (_) => pending.future;
      final previous = SettingsViewModel(
        settingsRepository: repository,
        sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
      );
      final replacement = SettingsViewModel(
        settingsRepository: repository,
        sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
      );
      final owner = ValueNotifier(previous);
      final theme = ThemeViewModel(settingsRepository: repository);
      addTearDown(owner.dispose);
      addTearDown(previous.dispose);
      addTearDown(replacement.dispose);
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        Provider<Logger>.value(
          value: MockLogger(),
          child: ChangeNotifierProvider<ThemeViewModel>.value(
            value: theme,
            child: ValueListenableBuilder<SettingsViewModel>(
              valueListenable: owner,
              builder: (_, vm, child) =>
                  ChangeNotifierProvider<SettingsViewModel>.value(
                    value: vm,
                    child: child,
                  ),
              child: Builder(
                builder: (context) => MaterialApp(
                  scaffoldMessengerKey: $scaffoldMessengerKey,
                  theme: AppThemeData.light(context: context),
                  home: const SettingsScreen(),
                ),
              ),
            ),
          ),
        ),
      );
      final originalContext = tester.element(find.byType(SettingsScreen));
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
        true,
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(previous.crashReporting, isTrue);
      owner.value = replacement;
      await tester.pump();
      expect(originalContext.mounted, isTrue);
      expect(
        tester.element(find.byType(SettingsScreen)),
        same(originalContext),
      );
      expect(originalContext.read<SettingsViewModel>(), same(replacement));
      expect(previous.isDisposed, isFalse);
      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Gli errori verranno inviati al prossimo avvio '
          "dell'app",
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      previous.dispose();
      replacement.dispose();
      theme.dispose();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('renders the editorial area entry', (tester) async {
      await tester.pumpWidget(app);

      expect(find.text('Area redazione'), findsOneWidget);
      expect(
        find.text('Rivedi e cura i contributi della community'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('NAV-04 pushed Settings Back returns to Home', (tester) async {
      router.go(RoutePaths.home);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push<void>(RoutePaths.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Indietro'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, RoutePaths.home);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('NAV-04 direct Settings Back uses a safe Home fallback', (
      tester,
    ) async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );

      await tester.tap(find.byTooltip('Indietro'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, RoutePaths.home);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
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

      expect(router.routerDelegate.state.uri.path, RoutePaths.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('pushes admin users to the dashboard', (tester) async {
      auth
        ..setUser(makeAuthUser(isAdmin: true))
        ..emit(AuthChangeEvent.signedIn);
      await tester.pumpWidget(app);
      await tester.pump();

      await tester.tap(find.text('Area redazione'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.uri.path, RoutePaths.admin);
      expect(find.text('ADMIN_MARKER'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
