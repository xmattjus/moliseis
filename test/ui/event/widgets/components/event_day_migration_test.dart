import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_calendar.dart';
import 'package:moliseis/ui/event/widgets/components/events_modal.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/command_test_support.dart';
import '../../../../support/events_harness.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';
import '../../../../support/mock_logger.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  final a = EventCalendarDate(2026, 4, 2);
  final b = EventCalendarDate(2026, 4, 3);
  const months = ['January', 'February', 'March', 'April'];

  for (final runtime in [false, true]) {
    testOwnerUI(
      'F1 modal hides A on B admission; ${runtime ? 'runtime' : 'domain'} '
      'error and retry use current B',
      (tester) async {
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final repo = FakeEventRepository();
        final vm = EventViewModel(
          repository: repo,
          nowUtc: () => DateTime.utc(2026, 4, 2),
        );
        await tester.pumpWidget(
          eventCommandApp(
            vm,
            repo,
            EventsModal(
              localizedMonths: months,
              selectedDate: a,
              viewModel: vm,
            ),
          ),
        );
        await pumpCommandTurns(tester);
        repo.getByDateResult = Result.success([makeEvent(name: 'A content')]);
        vm.selectDate(a);
        await pumpCommandTurns(tester);
        expect(find.text('A content'), findsOneWidget);
        final gate = Completer<Result<List<Event>>>();
        repo.pendingGetByDate = gate;
        vm.selectDate(b);
        expect(vm.selectedDate, b);
        expect(vm.loadByDate.isRunningSync.value, isTrue);
        expect(vm.hasCurrentDaySnapshot, isFalse);
        // Rebuild the direct observer before the fallback settles.
        await tester.pump();
        expect(find.text('A content'), findsNothing);
        expect(find.byType(ContentSliverGrid), findsNothing);
        expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
        expect(find.text('Eventi del 3 April'), findsOneWidget);
        await pumpCommandTurns(tester);
        final error = runtime ? TypeError() : TestException('domain B');
        if (runtime) {
          gate.completeError(error, StackTrace.fromString('modal-original'));
        } else {
          gate.complete(Result.error(error as Exception));
        }
        await pumpCommandTurns(tester);
        expect(find.byType(SkeletonContentSliverGrid), findsNothing);
        expect(
          find.text('Si è verificato un errore durante il caricamento.'),
          findsOneWidget,
        );
        expect(find.text('Riprova'), findsOneWidget);
        expect(find.text('A content'), findsNothing);
        expect(
          runtime
              ? vm.loadByDate.results.value.unexpectedError
              : vm.loadByDate.results.value.domainError,
          same(error),
        );
        expect(logger.calls, hasLength(runtime ? 1 : 0));
        repo
          ..pendingGetByDate = null
          ..getByDateResult = const Result.success([]);
        await tester.tap(find.text('Riprova'));
        expect(vm.loadByDate.isRunningSync.value, isTrue);
        await pumpCommandTurns(tester);
        expect(repo.lastGetByDate, b);
        expect(repo.getByDateCallCount, 3);
        expect(repo.getByCurrentYearCallCount, 1);
        expect(
          find.text('Nessun evento trovato per questa data.'),
          findsOneWidget,
        );
        expect(find.byType(SkeletonContentSliverGrid), findsNothing);
        final request = vm.currentDayRequest;
        vm.selectDate(b);
        await tester.pump();
        expect(vm.currentDayRequest, same(request));
        expect(
          find.text('Nessun evento trovato per questa data.'),
          findsOneWidget,
        );
        expect(repo.getByDateCallCount, 3);
      },
    );
  }

  testOwnerUI('F5 modal preserves fallback X on cache hit and annual rebase '
      'terminates pending UI', (tester) async {
    final repo = FakeEventRepository();
    final vm = EventViewModel(
      repository: repo,
      nowUtc: () => DateTime.utc(2026, 4, 2),
    );
    await tester.pumpWidget(
      eventCommandApp(
        vm,
        repo,
        EventsModal(localizedMonths: months, selectedDate: a, viewModel: vm),
      ),
    );
    await pumpCommandTurns(tester);
    repo.getByDateResult = Result.success([makeEvent(name: 'Fallback X')]);
    vm.selectDate(a);
    await pumpCommandTurns(tester);
    expect(find.text('Fallback X'), findsOneWidget);
    vm.selectDate(a);
    await tester.pump();
    expect(find.text('Fallback X'), findsOneWidget);
    expect(repo.getByDateCallCount, 1);
    final fallback = Completer<Result<List<Event>>>();
    repo.pendingGetByDate = fallback;
    vm.selectDate(b);
    await pumpCommandTurns(tester);
    vm.loadAll.run();
    await pumpCommandTurns(tester);
    expect(find.text('Nessun evento trovato per questa data.'), findsOneWidget);
    expect(find.byType(SkeletonContentSliverGrid), findsNothing);
    expect(repo.getByDateCallCount, 2);
    fallback.complete(Result.success([makeEvent(name: 'Stale')]));
    await pumpCommandTurns(tester);
    expect(find.text('Stale'), findsNothing);
    expect(find.text('Nessun evento trovato per questa data.'), findsOneWidget);
  });

  testOwnerUI(
    'F1 calendar observes selected day directly while fallback remains pending',
    (tester) async {
      final repo = FakeEventRepository();
      final vm = EventViewModel(
        repository: repo,
        nowUtc: () => DateTime.utc(2026, 4, 2),
      );
      await tester.pumpWidget(
        eventCommandApp(
          vm,
          repo,
          CustomScrollView(
            slivers: [
              EventsCalendar(
                viewModel: vm,
                onDayPressed: (date) => vm.selectDate(
                  EventCalendarDate(date.year, date.month, date.day),
                ),
              ),
            ],
          ),
        ),
      );
      await pumpCommandTurns(tester);
      final gate = Completer<Result<List<Event>>>();
      repo.pendingGetByDate = gate;
      vm.selectDate(b);
      expect(vm.selectedDate, b);
      await tester.pump();
      final days = tester.widgetList<EventsVerticalCalendarDay>(
        find.byType(EventsVerticalCalendarDay),
      );
      expect(
        days.where((day) => day.isSelected).single.date,
        DateTime(2026, 4, 3),
      );
      expect(vm.loadByDate.isRunningSync.value, isTrue);
      gate.complete(const Result.success([]));
      await pumpCommandTurns(tester);
    },
  );

  testOwnerUI('F1 unmounted modal receives no effects from late day runtime', (
    tester,
  ) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final repo = FakeEventRepository();
    final vm = EventViewModel(
      repository: repo,
      nowUtc: () => DateTime.utc(2026, 4, 2),
    );
    await tester.pumpWidget(
      eventCommandApp(
        vm,
        repo,
        EventsModal(localizedMonths: months, selectedDate: a, viewModel: vm),
      ),
    );
    await pumpCommandTurns(tester);
    final gate = Completer<Result<List<Event>>>();
    repo.pendingGetByDate = gate;
    vm.selectDate(a);
    await pumpCommandTurns(tester);
    await tester.pumpWidget(const SizedBox());
    gate.completeError(StateError('late day'));
    await pumpCommandTurns(tester);
    expect(logger.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
