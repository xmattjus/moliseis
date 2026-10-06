import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/sync_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('production Home bootstraps once and rebuilds keep its owner', (
    tester,
  ) async {
    final repository = FakeEventRepository();
    final fixture = buildSyncRouterApp(
      SyncHarness(),
      eventRepository: repository,
    );
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    final screen = tester.widget<ExploreScreen>(find.byType(ExploreScreen));
    expect(repository.getOngoingEventsCallCount, 1);
    expect(repository.getNextEventsCallCount, 1);
    expect(
      repository.receivedOngoingSnapshots,
      repository.receivedNextSnapshots,
    );
    expect(repository.getByIdCallCount, 0);

    fixture.router.go(RoutePaths.home);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ExploreScreen>(find.byType(ExploreScreen)).eventViewModel,
      same(screen.eventViewModel),
    );
    expect(repository.getOngoingEventsCallCount, 1);
    expect(repository.getNextEventsCallCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retained Home reloads both final collections after another tab',
    (tester) async {
      final repository = FakeEventRepository();
      final fixture = buildSyncRouterApp(
        SyncHarness(),
        eventRepository: repository,
      );
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      final vm = tester
          .widget<ExploreScreen>(find.byType(ExploreScreen))
          .eventViewModel;
      await tester.tap(find.text('Eventi'));
      await tester.pumpAndSettle();
      final active = makeEvent(remoteId: 31);
      final future = makeEvent(remoteId: 32);
      repository
        ..getOngoingEventsResult = Result.success([active])
        ..getNextEventsResult = Result.success([future]);
      await tester.tap(find.text('Esplora'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ExploreScreen>(find.byType(ExploreScreen)).eventViewModel,
        same(vm),
      );
      expect(vm.ongoing, [active]);
      expect(vm.next, [future]);
      expect(repository.getOngoingEventsCallCount, 2);
      expect(repository.getNextEventsCallCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final destination in ['detail', 'search', 'category', 'settings']) {
    testWidgets('Home refreshes after $destination return', (tester) async {
      final repository = FakeEventRepository(
        getByIdResults: {1: Result.success(makeEvent())},
      );
      final fixture = buildSyncRouterApp(
        SyncHarness(),
        eventRepository: repository,
      );
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      final vm = tester
          .widget<ExploreScreen>(find.byType(ExploreScreen))
          .eventViewModel;
      switch (destination) {
        case 'detail':
          fixture.router.goNamed(
            RouteNames.homePost,
            pathParameters: {'id': '1'},
            queryParameters: {'type': 'event'},
          );
        case 'search':
          fixture.router.goNamed(
            RouteNames.homeSearchResult,
            queryParameters: {'q': 'Molise'},
          );
        case 'category':
          fixture.router.goNamed(
            RouteNames.homeCategory,
            pathParameters: {'categorySlug': 'event'},
          );
        case 'settings':
          unawaited(fixture.router.pushNamed<void>(RouteNames.settings));
      }
      await tester.pumpAndSettle();
      // Settings push does not change the canonical browser URI. The top
      // GoRouter state still changes, which is the return hook's contract.
      expect(fixture.router.state.matchedLocation, isNot(RoutePaths.home));
      final active = makeEvent(remoteId: 40);
      repository.getOngoingEventsResult = Result.success([active]);
      fixture.router.pop();
      await tester.pumpAndSettle();
      expect(vm.ongoing, [active]);
      expect(repository.getOngoingEventsCallCount, 2);
      expect(repository.getNextEventsCallCount, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('return during pending discovery coalesces a subsequent pass', (
    tester,
  ) async {
    final pending = Completer<Result<List<Event>>>();
    final repository = FakeEventRepository()..pendingGetOngoingEvents = pending;
    final fixture = buildSyncRouterApp(
      SyncHarness(),
      eventRepository: repository,
    );
    await tester.pumpWidget(fixture.app);
    await pumpSyncRedirects(tester);
    expect(repository.getOngoingEventsCallCount, 1);
    unawaited(fixture.router.pushNamed<void>(RouteNames.settings));
    await tester.pumpAndSettle();
    fixture.router.pop();
    await pumpSyncRedirects(tester);
    expect(repository.getOngoingEventsCallCount, 1);
    repository.pendingGetOngoingEvents = null;
    pending.complete(const Result.success([]));
    await tester.pumpAndSettle();
    expect(repository.getOngoingEventsCallCount, 2);
    expect(repository.getNextEventsCallCount, 2);
    expect(
      repository.receivedOngoingSnapshots,
      repository.receivedNextSnapshots,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SearchAnchor popup without GoRouter navigation does not refresh',
    (tester) async {
      final repository = FakeEventRepository();
      final fixture = buildSyncRouterApp(
        SyncHarness(),
        eventRepository: repository,
      );
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsNWidgets(2));
      Navigator.of(tester.element(find.byType(SearchBar).last)).pop();
      await tester.pumpAndSettle();
      expect(fixture.router.state.matchedLocation, RoutePaths.home);
      expect(repository.getOngoingEventsCallCount, 1);
      expect(repository.getNextEventsCallCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unmount removes return listener and stops pending continuation',
    (tester) async {
      final pending = Completer<Result<List<Event>>>();
      final repository = FakeEventRepository()
        ..pendingGetOngoingEvents = pending;
      final fixture = buildSyncRouterApp(
        SyncHarness(),
        eventRepository: repository,
      );
      await tester.pumpWidget(fixture.app);
      await pumpSyncRedirects(tester);
      final vm = tester
          .widget<ExploreScreen>(find.byType(ExploreScreen))
          .eventViewModel;
      var notifications = 0;
      vm.addListener(() => notifications++);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.router.go(RoutePaths.settings);
      fixture.router.go(RoutePaths.home);
      pending.complete(Result.success([makeEvent()]));
      await tester.pumpAndSettle();
      expect(notifications, 0);
      expect(repository.getOngoingEventsCallCount, 1);
      expect(repository.getNextEventsCallCount, 0);
      expect(vm.ongoing, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
