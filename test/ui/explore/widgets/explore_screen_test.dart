import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/events_harness.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/sync_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  testWidgets('Home shows direct discovery errors and retries both queries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final placeRepository = FakePlaceRepository(
      getLatestResult: Result.error(TestException('latest failed')),
    );
    final eventRepository = FakeEventRepository(
      getNextEventsResult: Result.error(TestException('upcoming failed')),
    );
    final harness = EventsRouteHarness(
      eventRepository: eventRepository,
      placeRepository: placeRepository,
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Riprova'), findsNWidgets(2));
    expect(placeRepository.getLatestCallCount, 1);
    expect(eventRepository.getNextEventsCallCount, 1);
    expect(eventRepository.getOngoingEventsCallCount, 1);
    placeRepository.getLatestResult = const Result.success([]);
    eventRepository.getNextEventsResult = const Result.success([]);

    await tester.ensureVisible(find.text('Riprova').first);
    await tester.tap(find.text('Riprova').first);
    await tester.pumpAndSettle();
    expect(eventRepository.getNextEventsCallCount, 2);
    expect(eventRepository.getOngoingEventsCallCount, 2);
    expect(
      eventRepository.receivedOngoingSnapshots,
      eventRepository.receivedNextSnapshots,
    );
    expect(find.text('Riprova'), findsOneWidget);

    await tester.ensureVisible(find.text('Riprova'));
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(placeRepository.getLatestCallCount, 2);
    expect(find.text('Riprova'), findsNothing);
    expect(eventRepository.getByIdCallCount, 0);
    expect(placeRepository.getByIdCallCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'distinct Home sections consume disjoint collections for a fixed snapshot',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final snapshot = DateTime.utc(2026, 10, 6, 11);
      final active = makeEvent(
        remoteId: 71,
        name: 'Active festival',
        startDate: snapshot.subtract(const Duration(hours: 1)),
        endDate: snapshot.add(const Duration(hours: 1)),
      );
      final future = makeEvent(
        remoteId: 72,
        name: 'Future concert',
        startDate: snapshot.add(const Duration(hours: 2)),
        endDate: snapshot.add(const Duration(hours: 3)),
      );
      final dataset = [active, future];
      final repository = FakeEventRepository()
        ..getOngoingEventsHandler = (instant) async {
          return Result.success(
            dataset
                .where(
                  (event) =>
                      !event.startDate.isAfter(instant) &&
                      !event.endDate!.isBefore(instant),
                )
                .toList(),
          );
        }
        ..getNextEventsHandler = (instant) async {
          return Result.success(
            dataset.where((event) => event.startDate.isAfter(instant)).toList(),
          );
        };
      final harness = EventsRouteHarness(eventRepository: repository);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      final vm = tester
          .widget<ExploreScreen>(find.byType(ExploreScreen))
          .eventViewModel;
      await vm.loadOngoing.execute(snapshot);
      await vm.loadNext.execute(snapshot);
      await tester.pumpAndSettle();
      expect(find.text('Eventi in corso'), findsOneWidget);
      expect(find.text('Prossimi eventi'), findsOneWidget);
      final grids = tester
          .widgetList<ContentSliverGrid>(find.byType(ContentSliverGrid))
          .toList();
      expect(grids[0].items, [active]);
      expect(grids[1].items, [future]);
      expect(find.text('Active festival'), findsOneWidget);
      expect(find.text('Future concert'), findsOneWidget);
      expect(
        grids[0].items
            .map((event) => event.remoteId)
            .toSet()
            .intersection(
              grids[1].items.map((event) => event.remoteId).toSet(),
            ),
        isEmpty,
      );
      expect(repository.getByIdCallCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful empty temporal sections differ from discovery errors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeEventRepository();
      final harness = EventsRouteHarness(eventRepository: repository);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      expect(find.text('Eventi in corso'), findsOneWidget);
      expect(find.text('Prossimi eventi'), findsOneWidget);
      expect(
        find.text("Non c'è nulla qui per il momento, riprova più tardi!"),
        findsNWidgets(3),
      );
      expect(find.text('Riprova'), findsNothing);
      expect(find.byType(SkeletonContentSliverGrid), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in ['ongoing', 'upcoming']) {
    testWidgets(
      '$failure error retry requests both classifications through coordinator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = FakeEventRepository();
        if (failure == 'ongoing') {
          repository.getOngoingEventsResult = Result.error(
            TestException('ongoing failed'),
          );
        } else {
          repository.getNextEventsResult = Result.error(
            TestException('next failed'),
          );
        }
        final harness = EventsRouteHarness(eventRepository: repository);
        addTearDown(harness.dispose);
        await tester.pumpWidget(harness.app);
        await tester.pumpAndSettle();
        expect(find.text('Riprova'), findsOneWidget);
        expect(
          find.text('Si è verificato un errore durante il caricamento.'),
          findsOneWidget,
        );
        repository
          ..getOngoingEventsResult = const Result.success([])
          ..getNextEventsResult = const Result.success([]);
        await tester.ensureVisible(find.text('Riprova'));
        await tester.tap(find.text('Riprova'));
        await tester.pumpAndSettle();
        expect(repository.getOngoingEventsCallCount, 2);
        expect(repository.getNextEventsCallCount, 2);
        expect(
          repository.receivedOngoingSnapshots,
          repository.receivedNextSnapshots,
        );
        expect(find.text('Riprova'), findsNothing);
        expect(repository.getByIdCallCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('each temporal section observes its own pending command', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ongoing = Completer<Result<List<Event>>>();
    final upcoming = Completer<Result<List<Event>>>();
    final active = makeEvent(remoteId: 81, name: 'Ongoing loaded');
    final repository = FakeEventRepository()
      ..pendingGetOngoingEvents = ongoing
      ..pendingGetNextEvents = upcoming;
    final harness = EventsRouteHarness(eventRepository: repository);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);
    await pumpSyncRedirects(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExploreScreen), findsOneWidget);
    final vm = tester
        .widget<ExploreScreen>(find.byType(ExploreScreen))
        .eventViewModel;
    expect(vm.loadOngoing.running, isTrue);
    expect(vm.loadNext.idle, isTrue);
    // The reused skeleton sliver fills available space until its query
    // completes; the later section becomes visible after ongoing publishes.
    expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
    ongoing.complete(Result.success([active]));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ongoing loaded'), findsOneWidget);
    expect(vm.loadOngoing.completed, isTrue);
    expect(vm.loadNext.running, isTrue);
    expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
    expect(repository.getNextEventsCallCount, 1);
    upcoming.complete(const Result.success([]));
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonContentSliverGrid), findsNothing);
    expect(find.text('Riprova'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ongoing content opens the existing production event detail route',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final event = makeEvent(remoteId: 91, name: 'Open active event');
      final repository = FakeEventRepository(
        getByIdResults: {91: Result.success(event)},
      )..getOngoingEventsResult = Result.success([event]);
      final fixture = buildSyncRouterApp(
        SyncHarness(),
        eventRepository: repository,
      );
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      final card = find.byType(ContentEventCardGridItem);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(fixture.router.state.name, RouteNames.homePost);
      expect(fixture.router.state.pathParameters['id'], '91');
      expect(fixture.router.state.uri.queryParameters['type'], 'event');
      expect(repository.getByIdCallCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
