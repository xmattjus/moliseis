import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_calendar.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day_markers.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';

void main() {
  group('EventViewModel.loadByDate', () {
    test(
      'includes multi-day event on middle day when repository getByDate is '
      'empty',
      () async {
        final event = makeEvent(
          remoteId: 42,
          startDate: DateTime(2026, 3, 10, 10, 30),
          endDate: DateTime(2026, 3, 12, 22, 45),
        );

        final repository = FakeEventRepository(
          getByCurrentYearResult: Result.success([event]),
        );
        final viewModel = EventViewModel(repository: repository);

        await _waitForCommand(viewModel.loadAll);
        await viewModel.loadByDate.execute(EventCalendarDate(2026, 3, 11));
        await _waitForCommand(viewModel.loadByDate);

        expect(viewModel.byMonth, hasLength(1));
        expect(viewModel.byMonth.first.remoteId, 42);
        expect(repository.getByDateCallCount, 0);
      },
    );

    test('uses semantic Rome calendar dates for repository fetches', () async {
      final repository = FakeEventRepository();
      final viewModel = EventViewModel(
        repository: repository,
        nowUtc: () => DateTime.utc(2026, 3, 1, 1),
      );

      await _waitForCommand(viewModel.loadAll);
      await viewModel.loadByDate.execute(EventCalendarDate(2026, 3, 11));

      expect(repository.lastGetByDate, EventCalendarDate(2026, 3, 11));
    });

    test('returns cached events on same day without repository call', () async {
      final event = makeEvent(
        remoteId: 7,
        startDate: DateTime(2026, 3, 11, 8),
      );
      final repository = FakeEventRepository(
        getByCurrentYearResult: Result.success([event]),
      );
      final viewModel = EventViewModel(repository: repository);

      await _waitForCommand(viewModel.loadAll);
      await viewModel.loadByDate.execute(EventCalendarDate(2026, 3, 11));
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 0);

      await viewModel.loadByDate.execute(EventCalendarDate(2026, 3, 11));
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 0);
    });

    test('retries a date after its repository load fails', () async {
      final repository = FakeEventRepository();
      final viewModel = EventViewModel(repository: repository);
      final loadedDate = EventCalendarDate(2026, 3, 11);
      final failedDate = EventCalendarDate(2026, 3, 12);

      await _waitForCommand(viewModel.loadAll);
      await viewModel.loadByDate.execute(loadedDate);
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 1);

      repository.getByDateResult = Result.error(
        TestException('temporary failure'),
      );
      await viewModel.loadByDate.execute(failedDate);
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 2);
      expect(viewModel.loadByDate.error, isTrue);

      repository.getByDateResult = const Result.success([]);
      await viewModel.loadByDate.execute(failedDate);
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 3);
      expect(viewModel.loadByDate.completed, isTrue);
    });
  });

  group('EventViewModel.getEventsOnDay', () {
    test('returns events sorted by start date and remote id', () async {
      final repository = FakeEventRepository(
        getByCurrentYearResult: Result.success([
          makeEvent(remoteId: 2, startDate: DateTime(2026, 3, 11, 10)),
          // Test readability benefits from redundant argument values.
          // ignore: avoid_redundant_argument_values
          makeEvent(remoteId: 1, startDate: DateTime(2026, 3, 11, 10)),
          makeEvent(remoteId: 3, startDate: DateTime(2026, 3, 11, 9)),
        ]),
      );
      final viewModel = EventViewModel(repository: repository);

      await _waitForCommand(viewModel.loadAll);

      expect(
        viewModel
            .getEventsOnDay(EventCalendarDate(2026, 3, 11))
            .map((event) => event.remoteId)
            .toList(growable: false),
        <int>[3, 1, 2],
      );
    });
  });

  group('EventsVerticalCalendarDayMarkers', () {
    testWidgets('maps marker colors deterministically from remote id', (
      tester,
    ) async {
      const expectedColor = Color(0xFF00897B);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventsVerticalCalendarDayMarkers(
              events: [
                makeEvent(
                  remoteId: 5,
                  startDate: DateTime(2026, 3, 11, 8),
                ),
                makeEvent(
                  remoteId: 13,
                  startDate: DateTime(2026, 3, 11, 9),
                ),
              ],
            ),
          ),
        ),
      );

      final markerColorCount = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) => (box.decoration as BoxDecoration).color == expectedColor,
          )
          .length;

      expect(markerColorCount, 2);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNWidgets(2),
      );
    });
  });

  test(
    'derives calendar package bounds from canonical Rome calendar values',
    () {
      final bounds = EventsCalendar.calendarDateBounds(
        EventCalendarDate(2027, 1, 1),
      );

      expect(bounds.startDate, DateTime.utc(2027));
      expect(bounds.endDate, DateTime.utc(2027, 12, 31));
      expect(bounds.initialDate, DateTime.utc(2027));
    },
  );
}

Future<void> _waitForCommand(Command<void> command) async {
  while (command.running) {
    await Future<void>.delayed(Duration.zero);
  }
}
