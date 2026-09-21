import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/event/widgets/events_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../support/events_harness.dart';
import '../support/fake_repositories.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('Eventi navigation initializes its retained production branch', (
    tester,
  ) async {
    final loadAll = Completer<Result<List<Event>>>();
    final loadByDate = Completer<Result<List<Event>>>();
    final repository = FakeEventRepository()
      ..pendingGetByCurrentYear = loadAll
      ..pendingGetByDate = loadByDate;
    final harness = EventsRouteHarness(eventRepository: repository);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app);
    await tester.pump();

    expect(find.byType(EventsScreen), findsNothing);
    expect(find.text('Eventi'), findsOneWidget);

    final policy = EventTimePolicy();
    final dateBeforeNavigation = policy.currentCalendarDate(
      DateTime.now().toUtc(),
    );

    await tester.tap(find.text('Eventi'));
    await tester.pump();

    final dateAfterNavigation = policy.currentCalendarDate(
      DateTime.now().toUtc(),
    );
    expect(find.byType(EventsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      repository.lastGetByDate,
      anyOf(dateBeforeNavigation, dateAfterNavigation),
    );
    expect(repository.getByDateCallCount, 1);

    await tester.tap(find.text('Esplora'));
    await tester.pump();
    expect(find.byType(EventsScreen), findsNothing);

    await tester.tap(find.text('Eventi'));
    await tester.pump();

    expect(find.byType(EventsScreen), findsOneWidget);
    expect(repository.getByDateCallCount, 1);
    expect(tester.takeException(), isNull);

    loadAll.complete(Result.error(TestException('year load released')));
    loadByDate.complete(Result.error(TestException('date load released')));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
