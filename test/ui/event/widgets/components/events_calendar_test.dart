import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day_markers.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';

void main() {
  group('EventViewModel.isEventOnDay', () {
    late EventViewModel viewModel;

    setUp(() {
      viewModel = EventViewModel(repository: FakeEventRepository());
    });

    test('returns true for each day in an inclusive multi-day span', () {
      final event = makeEvent(
        startDate: DateTime(2026, 3, 10, 10, 30),
        endDate: DateTime(2026, 3, 12, 22, 45),
      );

      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 9)), isFalse);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 10)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 11)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 12)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 13)), isFalse);
    });

    test('treats null end date as a single-day event', () {
      final event = makeEvent(startDate: DateTime(2026, 3, 15, 18));

      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 14)), isFalse);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 15)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 16)), isFalse);
    });

    test('falls back to start day when end date is before start date', () {
      final event = makeEvent(
        startDate: DateTime(2026, 3, 20, 10),
        endDate: DateTime(2026, 3, 19, 10),
      );

      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 19)), isFalse);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 20)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 21)), isFalse);
    });
  });

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
        await viewModel.loadByDate.execute(DateTime(2026, 3, 11));
        await _waitForCommand(viewModel.loadByDate);

        expect(viewModel.byMonth, hasLength(1));
        expect(viewModel.byMonth.first.remoteId, 42);
        expect(repository.getByDateCallCount, 0);
      },
    );

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
      await viewModel.loadByDate.execute(DateTime(2026, 3, 11));
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 0);

      await viewModel.loadByDate.execute(DateTime(2026, 3, 11));
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 0);
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
            .getEventsOnDay(DateTime(2026, 3, 11))
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
}

Future<void> _waitForCommand(Command<void> command) async {
  while (command.running) {
    await Future<void>.delayed(Duration.zero);
  }
}
