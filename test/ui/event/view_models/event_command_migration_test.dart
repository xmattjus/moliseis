import 'dart:async';

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/events_harness.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/mock_logger.dart';

void main() {
  final a = EventCalendarDate(2026, 4, 2);
  final b = EventCalendarDate(2026, 4, 3);

  for (final empty in [false, true]) {
    testOwnerUI(
      'F5 fallback ${empty ? 'empty' : 'items'} cache preserves result '
      'and terminal identity',
      (tester) async {
        final repo = FakeEventRepository();
        final vm = EventViewModel(repository: repo);
        await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
        await pumpCommandTurns(tester);
        final gate = Completer<Result<List<Event>>>();
        repo.pendingGetByDate = gate;
        vm.selectDate(a);
        expect(vm.selectedDate, a);
        expect(vm.loadByDate.isRunningSync.value, isTrue);
        expect(repo.getByDateCallCount, 0);
        await pumpCommandTurns(tester);
        final x = makeEvent(
          remoteId: 41,
          startDate: DateTime.utc(2026, 4, 2, 10),
        );
        gate.complete(Result.success(empty ? [] : [x]));
        await pumpCommandTurns(tester);
        expect(vm.loadByDate.results.value.completed, isTrue);
        expect(vm.byMonth, empty ? isEmpty : [x]);
        final request = vm.currentDayRequest;
        final snapshot = vm.loadByDate.results.value;
        var notifications = 0;
        vm
          ..addListener(() => notifications++)
          ..selectDate(a);
        expect(vm.currentDayRequest, same(request));
        expect(vm.loadByDate.results.value, same(snapshot));
        expect(vm.byMonth, empty ? isEmpty : [x]);
        expect(vm.loadByDate.isRunningSync.value, isFalse);
        expect(notifications, 0);
        expect(repo.getByDateCallCount, 1);
        repo.getByCurrentYearResult = Result.error(
          TestException('year failure'),
        );
        vm.loadAll.run();
        await pumpCommandTurns(tester);
        vm.selectDate(a);
        expect(vm.currentDayRequest, same(request));
        expect(vm.byMonth, empty ? isEmpty : [x]);
      },
    );
  }

  testOwnerUI('F1/F5 A B A revokes equal-date intent; stale domain and runtime '
      'cannot publish', (tester) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final repo = FakeEventRepository();
    final vm = EventViewModel(repository: repo);
    await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
    await pumpCommandTurns(tester);
    final detailed = commands.Command.detailedStackTraces;
    commands.Command.detailedStackTraces = false;
    addTearDown(() => commands.Command.detailedStackTraces = detailed);
    final first = Completer<Result<List<Event>>>();
    final middle = Completer<Result<List<Event>>>();
    final last = Completer<Result<List<Event>>>();
    repo.pendingGetByDate = first;
    vm.selectDate(a);
    final firstRequest = vm.currentDayRequest;
    await pumpCommandTurns(tester);
    repo.pendingGetByDate = middle;
    vm.selectDate(b);
    await pumpCommandTurns(tester);
    repo.pendingGetByDate = last;
    vm.selectDate(a);
    expect(vm.currentDayRequest, isNot(same(firstRequest)));
    await pumpCommandTurns(tester);
    final x = makeEvent(remoteId: 43);
    last.complete(Result.success([x]));
    await pumpCommandTurns(tester);
    expect(vm.byMonth, [x]);
    final terminal = vm.loadByDate.results.value;
    first.complete(Result.error(TestException('obsolete A')));
    final error = StateError('obsolete B');
    final stack = StackTrace.fromString('event-original-stack');
    middle.completeError(error, stack);
    await pumpCommandTurns(tester);
    expect(vm.byMonth, [x]);
    expect(vm.loadByDate.results.value, same(terminal));
    expect(logger.calls.where((c) => identical(c.error, error)), hasLength(1));
    expect(
      logger.calls.single.stackTrace.toString(),
      contains('event-original-stack'),
    );
  });

  for (final empty in [false, true]) {
    testOwnerUI(
      'F1/F5 annual rebase ${empty ? 'empty' : 'items'} settles without '
      'pending fallback',
      (tester) async {
        final repo = FakeEventRepository();
        final vm = EventViewModel(repository: repo);
        await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
        await pumpCommandTurns(tester);
        final fallback = Completer<Result<List<Event>>>();
        repo.pendingGetByDate = fallback;
        vm.selectDate(a);
        await pumpCommandTurns(tester);
        final old = vm.currentDayRequest;
        final annual = Completer<Result<List<Event>>>();
        repo.pendingGetByCurrentYear = annual;
        vm.loadAll.run();
        await pumpCommandTurns(tester);
        final y = makeEvent(
          remoteId: 44,
          startDate: DateTime.utc(2026, 4, 2, 12),
        );
        annual.complete(Result.success(empty ? [] : [y]));
        await pumpCommandTurns(tester);
        expect(vm.currentDayRequest, isNot(same(old)));
        expect(vm.byMonth, empty ? isEmpty : [y]);
        expect(vm.loadByDate.results.value.completed, isTrue);
        expect(vm.loadByDate.isRunningSync.value, isFalse);
        expect(repo.getByDateCallCount, 1);
        fallback.complete(Result.success([makeEvent(remoteId: 45)]));
        await pumpCommandTurns(tester);
        expect(vm.byMonth, empty ? isEmpty : [y]);
        repo.pendingGetByDate = null;
        vm.selectDate(a);
        await pumpCommandTurns(tester);
        expect(repo.getByDateCallCount, empty ? 2 : 1);
      },
    );
  }

  for (final runtime in [false, true]) {
    testOwnerUI('F5 retry ${runtime ? 'runtime' : 'domain'} failure does not '
        'cache; preserves error kind', (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final repo = FakeEventRepository();
      final vm = EventViewModel(repository: repo);
      await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
      await pumpCommandTurns(tester);
      final gate = Completer<Result<List<Event>>>();
      repo.pendingGetByDate = gate;
      vm.selectDate(a);
      await pumpCommandTurns(tester);
      final error = runtime
          ? StateError('day runtime')
          : TestException('day domain');
      final stack = StackTrace.fromString('event-original-stack');
      if (runtime) {
        gate.completeError(error, stack);
      } else {
        gate.complete(Result.error(error as Exception));
      }
      await pumpCommandTurns(tester);
      expect(vm.loadByDate.results.value.hasFailure, isTrue);
      expect(
        runtime
            ? vm.loadByDate.results.value.unexpectedError
            : vm.loadByDate.results.value.domainError,
        same(error),
      );
      expect(logger.calls, hasLength(runtime ? 1 : 0));
      repo.pendingGetByDate = null;
      vm.selectDate(vm.selectedDate);
      expect(vm.loadByDate.isRunningSync.value, isTrue);
      await pumpCommandTurns(tester);
      expect(vm.loadByDate.results.value.completed, isTrue);
      expect(vm.byMonth, isEmpty);
      expect(repo.getByDateCallCount, 2);
      expect(repo.getByCurrentYearCallCount, 1);
    });
  }

  testOwnerUI('Home runtime side settles independently and disposal releases '
      'public refresh immediately', (tester) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final repo = FakeEventRepository();
    final vm = EventViewModel(repository: repo);
    await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
    await pumpCommandTurns(tester);
    final gate = Completer<Result<List<Event>>>();
    repo.pendingGetOngoingEvents = gate;
    var completed = false;
    unawaited(vm.refreshHomeDiscovery().then((_) => completed = true));
    await pumpCommandTurns(tester);
    gate.completeError(StateError('ongoing'));
    await pumpCommandTurns(tester);
    expect(completed, isTrue);
    expect(repo.getNextEventsCallCount, 1);
    expect(vm.loadOngoing.results.value.unexpectedError, isA<StateError>());
    expect(vm.loadNext.results.value.completed, isTrue);
    expect(logger.calls, hasLength(1));
    final late = Completer<Result<List<Event>>>();
    repo.pendingGetOngoingEvents = late;
    completed = false;
    unawaited(vm.refreshHomeDiscovery().then((_) => completed = true));
    await pumpCommandTurns(tester);
    unawaited(vm.refreshHomeDiscovery());
    vm.dispose();
    await pumpCommandTurns(tester);
    expect(completed, isTrue);
    expect(repo.getNextEventsCallCount, 1);
    late.completeError(TypeError());
    await pumpCommandTurns(tester);
    expect(logger.calls, hasLength(2));
    expect(repo.getNextEventsCallCount, 1);
    expect(tester.takeException(), isNull);
  });

  testOwnerUI('dispose before deferred entries starts no Event retrieval', (
    tester,
  ) async {
    final repo = FakeEventRepository();
    final vm = EventViewModel(repository: repo)..selectDate(a);
    vm.loadOngoing.run(DateTime.utc(2026));
    vm.loadNext.run(DateTime.utc(2026));
    vm
      ..dispose()
      ..dispose();
    await pumpCommandTurns(tester);
    expect(repo.getByCurrentYearCallCount, 0);
    expect(repo.getByDateCallCount, 0);
    expect(repo.getOngoingEventsCallCount, 0);
    expect(repo.getNextEventsCallCount, 0);
  });
  testOwnerUI('Home waits for next occupied after snapshot capture', (
    tester,
  ) async {
    var reads = 0;
    final captured = DateTime.utc(2026, 4, 2, 10);
    final repo = FakeEventRepository();
    final vm = EventViewModel(
      repository: repo,
      nowUtc: () {
        reads++;
        return captured;
      },
    );
    await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
    await pumpCommandTurns(tester);
    reads = 0;
    final ongoing = Completer<Result<List<Event>>>();
    final external = Completer<Result<List<Event>>>();
    repo
      ..pendingGetOngoingEvents = ongoing
      ..pendingGetNextEvents = external;
    final externalSnapshot = DateTime.utc(2026, 4, 2, 9);
    late VoidCallback occupyNext;
    occupyNext = () {
      vm.removeListener(occupyNext);
      vm.loadNext.run(externalSnapshot);
    };
    vm.addListener(occupyNext);
    var settled = false;
    unawaited(vm.refreshHomeDiscovery().then((_) => settled = true));
    await pumpCommandTurns(tester);
    ongoing.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(repo.receivedNextSnapshots, [externalSnapshot]);
    expect(reads, 1);
    expect(settled, isFalse);
    repo.pendingGetNextEvents = null;
    external.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(repo.receivedNextSnapshots, [externalSnapshot, captured]);
    expect(repo.receivedOngoingSnapshots, [captured]);
    expect(reads, 1);
    expect(settled, isTrue);
  });

  testOwnerUI(
    'reentrant day selection owns the request before notification returns',
    (tester) async {
      final repo = FakeEventRepository();
      final vm = EventViewModel(repository: repo);
      await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
      await pumpCommandTurns(tester);
      late VoidCallback selectB;
      selectB = () {
        vm
          ..removeListener(selectB)
          ..selectDate(b);
      };
      vm
        ..addListener(selectB)
        ..selectDate(a);
      expect(vm.selectedDate, b);
      expect(vm.currentDayRequest!.date, b);
      await pumpCommandTurns(tester);
      expect(repo.lastGetByDate, b);
      expect(vm.byMonth, isEmpty);
      expect(vm.loadByDate.results.value.completed, isTrue);
    },
  );

  testOwnerUI(
    'dispose from day commit notification releases outside dispatch',
    (tester) async {
      final repo = FakeEventRepository();
      final vm = EventViewModel(repository: repo);
      await tester.pumpWidget(eventCommandApp(vm, repo, const SizedBox()));
      await pumpCommandTurns(tester);
      final gate = Completer<Result<List<Event>>>();
      repo.pendingGetByDate = gate;
      vm.addListener(() {
        if (vm.byMonth.isNotEmpty) vm.dispose();
      });
      vm.selectDate(a);
      await pumpCommandTurns(tester);
      gate.complete(Result.success([makeEvent()]));
      await pumpCommandTurns(tester);
      expect(vm.loadByDate.debugLiveChildCount, 0);
      expect(vm.loadByDate.debugRetiredChildCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
