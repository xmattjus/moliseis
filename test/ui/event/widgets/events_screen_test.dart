import 'dart:async' show Completer;

import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:paged_vertical_calendar/paged_vertical_calendar.dart';

import '../../../support/command_test_support.dart';
import '../../../support/events_harness.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testOwnerUI(
    'provider initialization does not notify its Consumer during build',
    (tester) async {
      final loadAll = Completer<Result<List<Event>>>();
      final loadByDate = Completer<Result<List<Event>>>();
      final repository = FakeEventRepository()
        ..pendingGetByCurrentYear = loadAll
        ..pendingGetByDate = loadByDate;
      final harness = EventsProviderHarness(
        repository: repository,
        nowUtc: () => DateTime.utc(2026, 3, 11, 12),
      );

      await tester.pumpWidget(harness.app);

      expect(tester.takeException(), isNull);
      expect(harness.viewModel.loadAll.isRunningSync.value, isTrue);
      expect(harness.viewModel.loadByDate.isRunningSync.value, isTrue);
      expect(repository.getByDateCallCount, 0);
      await pumpCommandTurns(tester);
      expect(repository.getByDateCallCount, 1);
      expect(repository.lastGetByDate, EventCalendarDate(2026, 3, 11));

      loadAll.complete(Result.error(TestException('year load released')));
      loadByDate.complete(Result.error(TestException('date load released')));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testOwnerUI(
    'provider initialization uses the current Europe/Rome calendar day',
    (tester) async {
      final event = makeEvent(startDate: DateTime.utc(2026, 1, 10, 23, 30));
      final repository = FakeEventRepository(
        getByCurrentYearResult: Result.success([event]),
        getByDateResult: Result.success([event]),
      );
      final harness = EventsProviderHarness(
        repository: repository,
        nowUtc: () => DateTime.utc(2026, 1, 10, 23, 30),
      );

      await tester.pumpWidget(harness.app);
      await pumpCommandTurns(tester);

      expect(harness.viewModel.selectedDate, EventCalendarDate(2026, 1, 11));
      expect(repository.getByDateCallCount, 1);
      expect(repository.lastGetByDate, EventCalendarDate(2026, 1, 11));
      expect(harness.viewModel.byMonth, hasLength(1));
    },
  );

  testOwnerUI('legacy paged calendar has a compatible Material subtree', (
    tester,
  ) async {
    final harness = EventsProviderHarness(
      repository: FakeEventRepository(),
      nowUtc: () => DateTime.utc(2026, 3, 11, 12),
    );

    await tester.pumpWidget(harness.app);
    await pumpCommandTurns(tester);
    await tester.pump();

    expect(find.byType(PagedVerticalCalendar), findsOneWidget);
    expect(find.byType(legacy.Material), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
