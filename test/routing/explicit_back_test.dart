import 'dart:async' show unawaited;

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/routing/explicit_back.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_screen.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/search/widgets/search_result_screen.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/sync_harness.dart';

void main() {
  testOwnerUI('standalone Login Back never commits an empty stack', (
    tester,
  ) async {
    final fixture = buildSyncRouterApp(SyncHarness(gated: false));
    final router = fixture.router..go('/admin/login');
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    final commits = <RouteMatchList>[];
    router.routerDelegate.addListener(
      () => commits.add(router.routerDelegate.currentConfiguration),
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(router.state.uri.path, '/home');
    expect(commits, isNotEmpty);
    expect(commits.every((commit) => commit.isNotEmpty), isTrue);
    expect(tester.takeException(), isNull);
    final explore = router.routerDelegate.currentConfiguration;
    final provider = router.routeInformationProvider;
    final initialInformation = provider.value;
    var notifications = 0;
    void recordNotification() => notifications++;

    provider.addListener(recordNotification);
    try {
      requestExplicitBack(tester.element(find.byType(ExploreScreen)));
      expect(
        notifications,
        0,
        reason: 'Back at canonical Explore must not notify the router.',
      );
      expect(provider.value, same(initialInformation));
      await tester.pumpAndSettle();
      expect(notifications, 0);
      expect(provider.value, same(initialInformation));
      expect(router.routerDelegate.currentConfiguration, same(explore));
    } finally {
      provider.removeListener(recordNotification);
    }
  });

  testOwnerUI('pushed Login reveals the same Settings route and state', (
    tester,
  ) async {
    final fixture = buildSyncRouterApp(SyncHarness(gated: false));
    fixture.router.go('/settings');
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    final settings = find.byType(SettingsScreen);
    final predecessor = ModalRoute.of(tester.element(settings));
    await tester.tap(find.byType(DropdownMenu<ThemeBrightness>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chiaro').last);
    await tester.pumpAndSettle();
    expect(
      tester.element(settings).read<ThemeViewModel>().themeMode,
      ThemeMode.light,
    );

    await tester.tap(find.text('Area redazione'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(ModalRoute.of(tester.element(settings)), same(predecessor));
    expect(
      tester.element(settings).read<ThemeViewModel>().themeMode,
      ThemeMode.light,
    );
    expect(tester.takeException(), isNull);
  });

  testOwnerUI('Settings rejects a pointer release during push reconciliation', (
    tester,
  ) async {
    final fixture = buildSyncRouterApp(SyncHarness(gated: false));
    final router = fixture.router;
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    final predecessor = ModalRoute.of(
      tester.element(find.byType(ExploreScreen)),
    );
    unawaited(router.push<void>('/settings'));
    await tester.pumpAndSettle();
    final settings = find.byType(SettingsScreen);
    final shown = ModalRoute.of(tester.element(settings));
    final original =
        router.routerDelegate.currentConfiguration.last as ImperativeRouteMatch;
    final back = find.byType(BackButton);
    final press = await tester.startGesture(tester.getCenter(back));
    fixture.auth
      ..setUser(null)
      ..emit(AuthChangeEvent.signedOut);
    await tester.idle();
    final live =
        router.routerDelegate.currentConfiguration.last as ImperativeRouteMatch;
    expect(live.pageKey, original.pageKey);
    expect(live.completer, isNot(same(original.completer)));
    expect(ModalRoute.of(tester.element(settings)), same(shown));

    await press.up();
    await tester.idle();
    expect(router.routerDelegate.currentConfiguration.last, same(live));
    expect(original.completer.isCompleted, isFalse);
    expect(live.completer.isCompleted, isFalse);

    await tester.pumpAndSettle();
    expect(ModalRoute.of(tester.element(settings)), same(shown));
    await tester.tap(back);
    router.refresh();
    await tester.pumpAndSettle();
    expect(settings, findsNothing);
    expect(original.completer.isCompleted, isFalse);
    expect(live.completer.isCompleted, isTrue);
    expect(
      ModalRoute.of(tester.element(find.byType(ExploreScreen))),
      same(predecessor),
    );
    expect(tester.takeException(), isNull);
  });

  testOwnerUI('Search Post Back waits for active, uncovered branch ownership', (
    tester,
  ) async {
    const query = 'borghi e storia';
    final fixture = buildSyncRouterApp(
      SyncHarness(gated: false),
      eventRepository: FakeEventRepository(
        getByIdResults: {1: Result.success(makeEvent())},
      ),
    );
    final router = fixture.router;
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    router.go(
      Uri(
        path: '/home/search_results',
        queryParameters: {'q': query},
      ).toString(),
    );
    await tester.pumpAndSettle();
    final search = find.byType(SearchResultScreen);
    final parent = ModalRoute.of(tester.element(search));
    router.go(
      Uri(
        path: '/home/search_results/posts/1',
        queryParameters: {'q': query, 'type': 'event'},
      ).toString(),
    );
    await tester.pumpAndSettle();

    final post = find.byType(PostScreen);
    final source = tester.element(post);
    final route = ModalRoute.of(source)!;
    final back = tester.widget<BackButton>(find.byType(BackButton)).onPressed!;
    showDialog<void>(
      context: source,
      builder: (_) => const AlertDialog(content: Text('Root popup')),
    );
    await tester.pumpAndSettle();
    final popup = ModalRoute.of(tester.element(find.text('Root popup')))!;
    final provider = router.routeInformationProvider;
    final beforePopupBack = provider.value;
    final popupConfiguration = router.routerDelegate.currentConfiguration;
    expect(route.isCurrent, isTrue);
    back();
    expect(popup.isCurrent, isTrue);
    expect(popup.isActive, isTrue);
    expect(provider.value, same(beforePopupBack));
    expect(
      router.routerDelegate.currentConfiguration,
      same(popupConfiguration),
    );
    expect(router.state.uri.path, '/home/search_results/posts/1');
    router.configuration.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    unawaited(router.push<void>('/settings'));
    await tester.idle();
    final covered = router.routerDelegate.currentConfiguration;
    expect(router.state.uri.path, '/settings');
    expect(route.isCurrent, isTrue);
    final coveringPush = covered.last as ImperativeRouteMatch;
    final beforeCoveredBack = provider.value;
    back();
    expect(provider.value, same(beforeCoveredBack));
    expect(router.routerDelegate.currentConfiguration, same(covered));
    expect(coveringPush.completer.isCompleted, isFalse);
    expect(route.isActive, isTrue);
    expect(route.isCurrent, isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(ModalRoute.of(tester.element(post)), same(route));

    router.go('/favourites');
    await tester.idle();
    expect(router.state.uri.path, '/favourites');
    expect(route.isCurrent, isTrue);
    final favourites = router.routerDelegate.currentConfiguration;
    final beforeBranchBuild = provider.value;
    back();
    expect(provider.value, same(beforeBranchBuild));
    expect(router.routerDelegate.currentConfiguration, same(favourites));
    expect(route.isActive, isTrue);
    expect(route.isCurrent, isTrue);
    await tester.pumpAndSettle();
    final beforeInactiveBack = provider.value;
    back();
    expect(provider.value, same(beforeInactiveBack));
    expect(router.routerDelegate.currentConfiguration, same(favourites));
    expect(route.isActive, isTrue);
    expect(route.isCurrent, isTrue);
    expect(router.state.uri.path, '/favourites');

    await tester.tap(find.text('Esplora'));
    await tester.pumpAndSettle();
    expect(ModalRoute.of(tester.element(post)), same(route));
    await tester.tap(find.byType(BackButton));
    router.refresh();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home/search_results');
    expect(router.state.uri.queryParameters['q'], query);
    expect(ModalRoute.of(tester.element(search)), same(parent));

    final searchBack = find.descendant(
      of: find.descendant(of: search, matching: find.byType(CustomBackButton)),
      matching: find.byType(BackButton),
    );
    final semantics = tester.getSemantics(searchBack);
    semantics.owner!.performAction(semantics.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home');
    expect(tester.takeException(), isNull);
  });

  testOwnerUI(
    'a standalone branch requests Explore root over retained detail',
    (tester) async {
      final fixture = buildSyncRouterApp(SyncHarness(gated: false));
      final router = fixture.router..go('/home/category/nature');
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      router.go('/favourites');
      await tester.pumpAndSettle();
      expect(find.byType(FavouriteScreen), findsOneWidget);
      requestExplicitBack(tester.element(find.byType(FavouriteScreen)));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
      expect(find.byType(ExploreScreen), findsOneWidget);
    },
  );

  for (final leading in [true, false]) {
    testOwnerUI('ordinary error departures (leading: $leading)', (
      tester,
    ) async {
      final fixture = buildSyncRouterApp(SyncHarness(gated: false));
      final router = fixture.router..go('/home/category/nature');
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      final back = leading ? find.byType(BackButton) : find.text('Indietro');

      // The committed error Page can have no ordinary RouteMatch.
      router.go('/no-such-page');
      await tester.pumpAndSettle();
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');

      unawaited(router.push<void>('/settings'));
      await tester.pumpAndSettle();
      final predecessor = ModalRoute.of(
        tester.element(find.byType(SettingsScreen)),
      );
      unawaited(router.push<void>('/no-such-page'));
      await tester.pumpAndSettle();
      final error = find.byType(RouteErrorScreen);
      expect(error, findsOneWidget);
      final errorState = tester.widget<RouteErrorScreen>(error);
      final source = tester.element(error);
      final oldBack = errorState.onBack!;
      final errorRoute = ModalRoute.of(source)!;
      final original =
          router.routerDelegate.currentConfiguration.last
              as ImperativeRouteMatch;
      expect(original.matches.error, same(errorState.error));
      showDialog<void>(
        context: source,
        builder: (_) => const AlertDialog(content: Text('Covers error')),
      );
      await tester.pumpAndSettle();
      final popup = ModalRoute.of(tester.element(find.text('Covers error')))!;
      final provider = router.routeInformationProvider;
      final beforeCoveredBack = provider.value;
      final covered = router.routerDelegate.currentConfiguration;
      oldBack(source);
      expect(popup.isCurrent, isTrue);
      expect(popup.isActive, isTrue);
      expect(provider.value, same(beforeCoveredBack));
      expect(router.routerDelegate.currentConfiguration, same(covered));
      expect(original.completer.isCompleted, isFalse);
      router.configuration.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      router.refresh();
      await tester.idle();
      final live =
          router.routerDelegate.currentConfiguration.last
              as ImperativeRouteMatch;
      expect(live, isNot(same(original)));
      expect(live.pageKey, original.pageKey);
      expect(live.matches.error, isA<GoException>());
      expect(live.matches.error, isNot(same(errorState.error)));
      expect(live.completer, isNot(same(original.completer)));
      expect(ModalRoute.of(source), same(errorRoute));
      expect(errorRoute.isCurrent, isTrue);
      final staleConfiguration = router.routerDelegate.currentConfiguration;
      final beforeStaleBack = provider.value;
      var notifications = 0;
      void recordNotification() => notifications++;

      provider.addListener(recordNotification);
      try {
        oldBack(source);
        await tester.idle();
        expect(
          original.completer.isCompleted,
          isFalse,
          reason: 'Stale error Back must leave the original push pending.',
        );
        expect(live.completer.isCompleted, isFalse);
        expect(
          router.routerDelegate.currentConfiguration,
          same(staleConfiguration),
        );
        expect(router.routerDelegate.currentConfiguration.last, same(live));
        expect(errorRoute.isActive, isTrue);
        expect(errorRoute.isCurrent, isTrue);
        expect(notifications, 0);
        expect(provider.value, same(beforeStaleBack));
      } finally {
        provider.removeListener(recordNotification);
      }

      await tester.pumpAndSettle();
      final reconciled = tester.element(error);
      expect(ModalRoute.of(reconciled), same(errorRoute));
      expect(
        tester.widget<RouteErrorScreen>(error).error,
        same(live.matches.error),
      );
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(live.completer.isCompleted, isTrue);
      expect(original.completer.isCompleted, isFalse);
      expect(
        ModalRoute.of(tester.element(find.byType(SettingsScreen))),
        same(predecessor),
      );
      expect(tester.takeException(), isNull);

      router.go('/home/category/nature/posts/invalid');
      await tester.pumpAndSettle();
      expect(error, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home/category/nature');
      expect(tester.takeException(), isNull);
    });
  }

  testOwnerUI('Gallery Unavailable keeps its text-only Back action', (
    tester,
  ) async {
    final fixture = buildSyncRouterApp(SyncHarness(gated: false));
    final router = fixture.router..go('/gallery');
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    expect(find.byType(GalleryUnavailableScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.text('Torna indietro'));
    await tester.pumpAndSettle();
    final home = ModalRoute.of(tester.element(find.byType(ExploreScreen)));
    unawaited(router.push<void>('/gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryUnavailableScreen), findsOneWidget);
    await tester.tap(find.text('Torna indietro'));
    await tester.pumpAndSettle();
    expect(
      ModalRoute.of(tester.element(find.byType(ExploreScreen))),
      same(home),
    );
    expect(tester.takeException(), isNull);
  });

  for (final branch in [false, true]) {
    testOwnerUI('Back rejects an uninstalled Page (branch: $branch)', (
      tester,
    ) async {
      final fixture = buildSyncRouterApp(SyncHarness(gated: false));
      final router = fixture.router
        ..go(branch ? '/home/category/nature' : '/settings');
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      final committed = router.routerDelegate.currentConfiguration;
      final top = committed.matches.last;
      final shell = top is ShellRouteMatch ? top : null;
      final match = shell?.matches.last ?? top;
      final owner = (shell?.navigatorKey ?? router.configuration.navigatorKey)
          .currentState!;
      const unassociatedKey = ValueKey('unassociated back');
      // The local Page shares the live key but is absent from Navigator.pages.
      // Back rejects it at the installed-Page identity check.
      final unassociated = MaterialPage<void>(
        key: match.pageKey,
        child: const Scaffold(
          body: Center(child: CustomBackButton(key: unassociatedKey)),
        ),
      ).createRoute(owner.context);
      owner.push(unassociated);
      await tester.pumpAndSettle();
      final control = find.byKey(unassociatedKey);
      final source = tester.element(control);
      if (shell == null) {
        expect(() => GoRouterState.of(source), throwsA(isA<GoError>()));
      }
      expect(owner.widget.pages, isNot(contains(unassociated.settings)));

      final provider = router.routeInformationProvider;
      final beforeBack = provider.value;
      await tester.tap(control);
      expect(provider.value, same(beforeBack));
      expect(unassociated.isActive, isTrue);
      expect(unassociated.isCurrent, isTrue);
      await tester.pumpAndSettle();
      expect(unassociated.isCurrent, isTrue);
      expect(router.routerDelegate.currentConfiguration, same(committed));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('veto and local history do not authorize another departure', (
    tester,
  ) async {
    final canPop = ValueNotifier(false);
    addTearDown(canPop.dispose);
    final button = find.byType(CustomBackButton);
    final popAttempts = <bool>[];
    final router = GoRouter(
      initialLocation: '/home/protected',
      routes: [
        GoRoute(
          name: 'home',
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Explore')),
          routes: [
            GoRoute(
              path: 'protected',
              builder: (_, _) => ValueListenableBuilder(
                valueListenable: canPop,
                builder: (_, allowed, _) => PopScope(
                  canPop: allowed,
                  onPopInvokedWithResult: (didPop, _) =>
                      popAttempts.add(didPop),
                  child: const Scaffold(
                    body: Center(child: CustomBackButton()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final configuration = router.routerDelegate.currentConfiguration;
    final provider = router.routeInformationProvider;
    final route = ModalRoute.of(tester.element(button))!;
    final beforeVeto = provider.value;
    await tester.tap(button);
    expect(popAttempts, isEmpty);
    expect(provider.value, same(beforeVeto));
    expect(route.isCurrent, isTrue);
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration, same(configuration));

    canPop.value = true;
    await tester.pumpAndSettle();
    var historyRemoved = false;
    final history = LocalHistoryEntry(onRemove: () => historyRemoved = true);
    route.addLocalHistoryEntry(history);
    final beforeLocalHistoryBack = provider.value;
    await tester.tap(button);
    expect(historyRemoved, isFalse);
    expect(popAttempts, isEmpty);
    expect(provider.value, same(beforeLocalHistoryBack));
    expect(route.isCurrent, isTrue);
    await tester.pumpAndSettle();
    expect(route.willHandlePopInternally, isTrue);
    expect(router.routerDelegate.currentConfiguration, same(configuration));
    history.remove();
    expect(historyRemoved, isTrue);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(popAttempts, [true]);
    expect(find.text('Explore'), findsOneWidget);
  });
}
