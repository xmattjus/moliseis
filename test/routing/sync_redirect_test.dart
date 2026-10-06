import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/mock_gotrue_client.dart';
import '../support/sync_harness.dart';

void main() {
  group('buildAppRouter sync redirect', () {
    testWidgets('unknown route renders the route error screen', (tester) async {
      final harness = SyncHarness();
      final router = buildSyncRouterApp(harness);

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);

      router.router.go('/home/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(
        router.router.routeInformationProvider.value.uri.path,
        '/home/does-not-exist',
      );
    });

    testWidgets('cold start without a due sync stays on /home', (tester) async {
      final harness = SyncHarness();
      final router = buildSyncRouterApp(harness);

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);

      expect(router.router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(SyncScreen), findsNothing);
    });

    testWidgets('automatic sync from /home preserves /home and returns', (
      tester,
    ) async {
      final harness = SyncHarness(autoSync: true);
      final router = buildSyncRouterApp(harness);

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);

      final uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.sync);
      expect(uri.queryParameters['from'], RoutePaths.home);

      harness.release();
      await tester.pumpAndSettle();

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
      expect(find.byType(SyncScreen), findsNothing);
    });

    testWidgets('manual sync from /home preserves /home and returns', (
      tester,
    ) async {
      final harness = SyncHarness();
      final router = buildSyncRouterApp(harness);

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);
      expect(router.router.routeInformationProvider.value.uri.path, '/home');

      unawaited(harness.viewModel.sync.execute(true));
      await pumpSyncRedirects(tester);

      final uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.sync);
      expect(uri.queryParameters['from'], RoutePaths.home);

      harness.release();
      await tester.pumpAndSettle();

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
    });

    testWidgets('sync from a detail URI preserves and restores it', (
      tester,
    ) async {
      final event = makeEvent();
      final eventRepository = FakeEventRepository(
        getByIdResults: <int, Result<Event>>{1: Result.success(event)},
      );
      final harness = SyncHarness();
      final router = buildSyncRouterApp(
        harness,
        eventRepository: eventRepository,
      );

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);

      router.router.goNamed(
        RouteNames.homePost,
        pathParameters: <String, String>{'id': '1'},
        queryParameters: <String, String>{'type': 'event'},
      );
      await pumpSyncRedirects(tester);

      var uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, '/home/posts/1');
      expect(uri.queryParameters['type'], 'event');

      unawaited(harness.viewModel.sync.execute(true));
      await pumpSyncRedirects(tester);

      uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.sync);
      expect(uri.queryParameters['from'], '/home/posts/1?type=event');

      harness.release();
      await tester.pumpAndSettle();

      uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, '/home/posts/1');
      expect(uri.queryParameters['type'], 'event');
    });

    testWidgets('non-fatal error returns to the preserved URI', (tester) async {
      final harness = SyncHarness(
        cityResult: Result.error(TestException('sync failed')),
      );
      final router = buildSyncRouterApp(harness);

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);

      unawaited(harness.viewModel.sync.execute(true));
      await pumpSyncRedirects(tester);
      expect(router.router.routeInformationProvider.value.uri.path, '/sync');

      harness.release();
      await pumpSyncRedirects(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
      expect(
        find.text(
          "Si è verificato un errore durante l'aggiornamento dei contenuti",
        ),
        findsOneWidget,
      );
    });

    testWidgets('fatal first-sync error remains on /sync', (tester) async {
      final harness = SyncHarness(
        autoSync: true,
        cityResult: Result.error(TestException('sync failed')),
      );
      final router = buildSyncRouterApp(harness);

      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);
      expect(router.router.routeInformationProvider.value.uri.path, '/sync');

      harness.release();
      await tester.pumpAndSettle();

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.sync,
      );
      expect(
        find.textContaining(
          'Molise Is necessita di una connessione ad internet',
        ),
        findsOneWidget,
      );
    });

    for (final from in _invalidFromValues) {
      testWidgets(
        'rejects invalid from value "$from" and falls back to /home',
        (tester) async {
          final harness = SyncHarness();
          final router = buildSyncRouterApp(harness);

          await tester.pumpWidget(router.app);
          await pumpSyncRedirects(tester);

          // Keep the command running while substituting the crafted value.
          unawaited(harness.viewModel.sync.execute(true));
          await pumpSyncRedirects(tester);

          router.router.go(
            '${RoutePaths.sync}?from=${Uri.encodeComponent(from)}',
          );
          await pumpSyncRedirects(tester);
          expect(
            router.router.routeInformationProvider.value.uri.path,
            '/sync',
          );

          harness.release();
          await tester.pumpAndSettle();

          expect(
            router.router.routeInformationProvider.value.uri.path,
            RoutePaths.home,
          );
        },
      );
    }

    testWidgets('sync restores an admin user to /admin after completing', (
      tester,
    ) async {
      final auth = ControllableAdminAuth(
        initialUser: makeAuthUser(isAdmin: true),
      );
      final harness = SyncHarness();
      final router = buildSyncRouterApp(harness, auth: auth);

      router.router.go(RoutePaths.admin);
      unawaited(harness.viewModel.sync.execute(true));
      await tester.pumpWidget(router.app);
      await pumpSyncRedirects(tester);

      final syncUri = router.router.routeInformationProvider.value.uri;
      expect(syncUri.path, RoutePaths.sync);
      expect(syncUri.queryParameters['from'], RoutePaths.admin);

      harness.release();
      await pumpSyncRedirects(tester);

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.admin,
      );
    });

    testWidgets(
      'sync restores an anonymous user to /admin/login after completing',
      (tester) async {
        final auth = ControllableAdminAuth();
        final harness = SyncHarness();
        final router = buildSyncRouterApp(harness, auth: auth);

        router.router.go(RoutePaths.admin);
        unawaited(harness.viewModel.sync.execute(true));
        await tester.pumpWidget(router.app);
        await pumpSyncRedirects(tester);

        final syncUri = router.router.routeInformationProvider.value.uri;
        expect(syncUri.path, RoutePaths.sync);
        expect(syncUri.queryParameters['from'], RoutePaths.admin);

        harness.release();
        await pumpSyncRedirects(tester);

        expect(
          router.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
      },
    );
  });

  group('Home temporal discovery after sync', () {
    for (final trigger in ['menu', 'pull-to-refresh']) {
      testWidgets(
        '$trigger refreshes both collections after the cache commit',
        (tester) async {
          if (trigger == 'pull-to-refresh') {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
          }
          await tester.binding.setSurfaceSize(
            trigger == 'menu' ? const Size(1000, 1800) : const Size(400, 600),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final repository = FakeEventRepository();
          final active = makeEvent(remoteId: 51);
          final future = makeEvent(remoteId: 52);
          var committed = false;
          final harness = SyncHarness(
            onCommit: () {
              committed = true;
              repository
                ..getOngoingEventsResult = Result.success([active])
                ..getNextEventsResult = Result.success([future]);
            },
          );
          final fixture = buildSyncRouterApp(
            harness,
            eventRepository: repository,
          );
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();
          expect(repository.getOngoingEventsCallCount, 1);
          expect(repository.getNextEventsCallCount, 1);
          if (trigger == 'menu') {
            await tester.tap(find.byTooltip('Aggiorna i contenuti'));
          } else {
            final scroll = find.byType(CustomScrollView).first;
            await tester.dragFrom(
              tester.getTopLeft(scroll) + const Offset(150, 180),
              const Offset(0, 1000),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          await pumpSyncRedirects(tester);
          expect(fixture.router.state.matchedLocation, RoutePaths.sync);
          expect(committed, isFalse);
          expect(repository.getOngoingEventsCallCount, 1);
          harness.release();
          await tester.pumpAndSettle();
          expect(committed, isTrue);
          expect(fixture.router.state.matchedLocation, RoutePaths.home);
          final vm = tester
              .widget<ExploreScreen>(find.byType(ExploreScreen))
              .eventViewModel;
          expect(vm.ongoing, [active]);
          expect(vm.next, [future]);
          expect(repository.getOngoingEventsCallCount, 2);
          expect(repository.getNextEventsCallCount, 2);
          expect(
            repository.receivedOngoingSnapshots,
            repository.receivedNextSnapshots,
          );
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }

    testWidgets('non-fatal sync error reloads valid cached discovery', (
      tester,
    ) async {
      final active = makeEvent(remoteId: 61);
      final future = makeEvent(remoteId: 62);
      final repository = FakeEventRepository()
        ..getOngoingEventsResult = Result.success([active])
        ..getNextEventsResult = Result.success([future]);
      final harness = SyncHarness(
        cityResult: Result.error(TestException('offline')),
      );
      final fixture = buildSyncRouterApp(harness, eventRepository: repository);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      unawaited(harness.viewModel.sync.execute(true));
      await pumpSyncRedirects(tester);
      harness.release();
      await pumpSyncRedirects(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      final vm = tester
          .widget<ExploreScreen>(find.byType(ExploreScreen))
          .eventViewModel;
      expect(fixture.router.state.matchedLocation, RoutePaths.home);
      expect(vm.ongoing, [active]);
      expect(vm.next, [future]);
      expect(repository.getOngoingEventsCallCount, 2);
      expect(repository.getNextEventsCallCount, 2);
      expect(
        find.text(
          "Si è verificato un errore durante l'aggiornamento dei contenuti",
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('buildAppRouter sync restoration', () {
    testWidgets('restored idle /sync returns to the preserved settings URI', (
      tester,
    ) async {
      // Persist a recent timestamp so the fresh view model skips auto-sync.
      final settings = FakeSettingsRepository(lastSyncedAt: DateTime.now());
      final holder = _SyncRestorationHolder(settingsFactory: () => settings);

      await tester.pumpWidget(_RestorableSyncHarness(holder: holder));
      await pumpSyncRedirects(tester);
      final before = holder.fixture!;

      before.router.go(RoutePaths.settings);
      await pumpSyncRedirects(tester);
      expect(
        before.router.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );

      unawaited(before.harness.viewModel.sync.execute(true));
      await pumpSyncRedirects(tester);
      expect(
        before.router.routeInformationProvider.value.uri.path,
        RoutePaths.sync,
      );
      expect(
        before
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        RoutePaths.settings,
      );

      await tester.restartAndRestore();
      await pumpSyncRedirects(tester);

      final after = holder.fixture!;
      expect(after, isNot(same(before)));
      expect(after.harness.viewModel, isNot(same(before.harness.viewModel)));
      expect(after.harness.viewModel.sync.idle, isTrue);
      expect(
        after.router.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );
      expect(find.byType(SyncScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('restored due sync remains on /sync until it completes', (
      tester,
    ) async {
      final holder = _SyncRestorationHolder(
        // Each fixture needs its own settings so completing the old gated
        // sync cannot make the fresh view model think it is up to date.
        settingsFactory: FakeSettingsRepository.new,
      );

      await tester.pumpWidget(_RestorableSyncHarness(holder: holder));
      await pumpSyncRedirects(tester);
      final before = holder.fixture!;
      expect(before.harness.viewModel.sync.running, isTrue);
      expect(
        before.router.routeInformationProvider.value.uri.path,
        RoutePaths.sync,
      );
      expect(
        before
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        RoutePaths.home,
      );

      await tester.restartAndRestore();
      await pumpSyncRedirects(tester);

      final after = holder.fixture!;
      expect(after, isNot(same(before)));
      expect(after.harness.viewModel.sync.running, isTrue);
      expect(
        after.router.routeInformationProvider.value.uri.path,
        RoutePaths.sync,
      );
      expect(
        after.router.routeInformationProvider.value.uri.queryParameters['from'],
        RoutePaths.home,
      );
      expect(find.byType(SyncScreen), findsOneWidget);

      after.harness.release();
      await tester.pumpAndSettle();

      expect(
        after.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
      expect(find.byType(SyncScreen), findsNothing);
    });
  });

  group('MoliseIsApp router lifecycle', () {
    testWidgets('theme rebuild keeps the same router and URI', (tester) async {
      final harness = SyncHarness();
      await tester.pumpWidget(buildRealSyncApp(harness));
      await tester.pumpAndSettle();

      final exploreContext = tester.element(find.byType(ExploreScreen));
      final routerBefore = GoRouter.of(exploreContext);

      exploreContext.goNamed(RouteNames.settings);
      await tester.pumpAndSettle();

      final settingsContext = tester.element(find.byType(SettingsScreen));
      expect(
        routerBefore.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );

      await settingsContext.read<ThemeViewModel>().setThemeType.execute(
        ThemeType.app,
      );
      await tester.pumpAndSettle();

      expect(GoRouter.of(settingsContext), same(routerBefore));
      expect(
        routerBefore.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );
    });
  });
}

/// Values that must never be honored as a sync `from` target.
const List<String> _invalidFromValues = <String>[
  'https://evil.example/private',
  '//evil.example/private',
  'javascript:alert(1)',
  'posts/1?type=event',
  '/sync',
  '/sync?from=%2Fhome',
  '/home/does-not-exist',
];

/// Rebuilds the production router with a fresh [SyncViewModel] on restoration.
final class _SyncRestorationFixture {
  _SyncRestorationFixture({required FakeSettingsRepository settings}) {
    harness = SyncHarness(settings: settings);
    auth = ControllableAdminAuth();
    router = buildAppRouter(
      syncViewModel: harness.viewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  late final ControllableAdminAuth auth;
  late final SyncHarness harness;
  late final GoRouter router;

  Widget get app => MultiProvider(
    providers: buildSyncProviders(harness, auth: auth),
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      restorationScopeId: 'app',
      routerConfig: router,
    ),
  );

  void dispose() {
    router.dispose();
    auth.dispose();

    final sync = harness.viewModel.sync;
    if (!sync.running) {
      harness.viewModel.dispose();
      return;
    }

    void disposeWhenComplete() {
      if (sync.running) return;

      sync.removeListener(disposeWhenComplete);
      scheduleMicrotask(harness.viewModel.dispose);
    }

    // Detach the router before unblocking the command. It may notify while
    // completing, so dispose the view model only after that notification.
    sync.addListener(disposeWhenComplete);
    final gate = harness.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

/// Holds test state that can either persist or be recreated on restoration.
final class _SyncRestorationHolder {
  _SyncRestorationHolder({required this.settingsFactory});

  final FakeSettingsRepository Function() settingsFactory;
  _SyncRestorationFixture? fixture;
}

class _RestorableSyncHarness extends StatefulWidget {
  const _RestorableSyncHarness({required this.holder});

  final _SyncRestorationHolder holder;

  @override
  State<_RestorableSyncHarness> createState() => _RestorableSyncHarnessState();
}

class _RestorableSyncHarnessState extends State<_RestorableSyncHarness> {
  late final _SyncRestorationFixture fixture = _SyncRestorationFixture(
    settings: widget.holder.settingsFactory(),
  );

  @override
  void initState() {
    super.initState();
    widget.holder.fixture = fixture;
  }

  @override
  void dispose() {
    fixture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => fixture.app;
}
