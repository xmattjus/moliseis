import 'dart:async';

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/search_history_harness.dart';

void main() {
  late bool detailedStackTraces;
  setUp(() {
    detailedStackTraces = commands.Command.detailedStackTraces;
    commands.Command.detailedStackTraces = false;
  });
  tearDown(() {
    commands.Command.detailedStackTraces = detailedStackTraces;
  });
  for (final outcome in ['success', 'domain', 'runtime']) {
    testOwnerUI('S9 detached accepted FIFO survives teardown: $outcome', (
      tester,
    ) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final h = SearchHistoryHarness();
      await pumpCommandTurns(tester);
      h.vm.addToPastSearches('A');
      h.vm.addToPastSearches('B');
      h.vm.dispose();
      final notifications = h.notifications;
      expect(h.writes, isEmpty);
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 51));
      expect(h.writes, hasLength(1));
      final original = StateError('detached write');
      final stack = StackTrace.current;
      if (outcome == 'runtime') {
        h.writes.first.completeError(original, stack);
      } else {
        h.writes.first.complete(
          outcome == 'domain'
              ? Result.error(TestException('detached expected failure'))
              : const Result.success(null),
        );
      }
      await pumpCommandTurns(tester);
      expect(h.writes, hasLength(2));
      h.writes.last.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 51));
      await pumpCommandTurns(tester);
      expect(h.repository.historyWrites, [
        (operation: 'add', query: 'A'),
        (operation: 'add', query: 'B'),
      ]);
      expect(h.stored, outcome == 'success' ? ['A', 'B'] : ['B']);
      expect(h.vm.pastSearches, isEmpty);
      expect(h.notifications, notifications);
      expect(h.reads, hasLength(1));
      expect(logger.calls, hasLength(outcome == 'runtime' ? 1 : 0));
      if (outcome == 'runtime') {
        expect(logger.calls.single.error, same(original));
        expect(logger.calls.single.stackTrace.toString(), stack.toString());
      }
      expect(tester.takeException(), isNull);
    });
  }

  testOwnerUI(
    'S12 reader waiting for drain detaches before physical settlement',
    (tester) async {
      final h = SearchHistoryHarness(holdReads: true);
      await pumpCommandTurns(tester);
      h.vm.addToPastSearches('A');
      h.reads.first.complete(const Result.success(['obsolete']));
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(1));
      expect(h.vm.pastSearches, ['obsolete']);
      h.vm.dispose();
      final notifications = h.notifications;
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 51));
      expect(h.reads, hasLength(1));
      h.writes.single.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      expect(h.stored, ['A']);
      expect(h.notifications, notifications);
      expect(h.reads, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final runtimeRead in [false, true]) {
    testOwnerUI(
      'S14 reconciliation failure consumes demand runtime=$runtimeRead',
      (tester) async {
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final h = SearchHistoryHarness(holdReads: true);
        await pumpCommandTurns(tester);
        h.reads.first.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        h.vm.addToPastSearches('A');
        await pumpCommandTurns(tester);
        final writeError = StateError('write uncertainty');
        h.writes.single.completeError(writeError);
        await pumpCommandTurns(tester);
        expect(h.reads, hasLength(1));
        expect(h.vm.pastSearchesFailure, same(writeError));
        h.vm.requestPastSearchesRefresh();
        await pumpCommandTurns(tester);
        expect(h.reads, hasLength(2));
        final readError = StateError('read failure');
        if (runtimeRead) {
          h.reads.last.completeError(readError);
        } else {
          h.reads.last.complete(Result.error(TestException('read failure')));
        }
        await pumpCommandTurns(tester);
        await pumpCommandTurns(tester);
        expect(h.vm.pastSearches, isEmpty);
        expect(
          h.vm.pastSearchesFailure,
          same(
            runtimeRead ? readError : h.vm.pastSearchesState.value.domainError,
          ),
        );
        expect(h.reads, hasLength(2));
        expect(h.writes, hasLength(1));
        expect(logger.calls, hasLength(runtimeRead ? 2 : 1));
        expect(logger.calls.first.error, same(writeError));
        if (runtimeRead) expect(logger.calls.last.error, same(readError));
        h.vm.requestPastSearchesRefresh();
        await pumpCommandTurns(tester);
        expect(h.reads, hasLength(3));
        h.reads.last.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        expect(h.vm.pastSearches, isEmpty);
        expect(h.vm.pastSearchesFailure, isNull);
        h.vm.dispose();
      },
    );
  }

  testOwnerUI('S15 runtime report detaches owner before reconciliation entry', (
    tester,
  ) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final h = SearchHistoryHarness();
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    await pumpCommandTurns(tester);
    h.writes.single.completeError(StateError('late write'));
    // The Future error has settled physically, but no command terminal event
    // or scheduled reconciliation has been delivered yet.
    h.vm.dispose();
    final notifications = h.notifications;
    await pumpCommandTurns(tester);
    expect(logger.calls, hasLength(1));
    expect(h.reads, hasLength(1));
    expect(h.notifications, notifications);
    expect(h.repository.historyWrites, hasLength(1));
  });

  testOwnerUI('S18 uncertain base cannot deduplicate a new accepted add', (
    tester,
  ) async {
    final logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
    final h = SearchHistoryHarness(holdReads: true);
    await pumpCommandTurns(tester);
    h.reads.first.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    await pumpCommandTurns(tester);
    h.writes.single.completeError(StateError('unknown commit'));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(1));
    h.vm.requestPastSearchesRefresh();
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    h.vm.addToPastSearches('a');
    await pumpCommandTurns(tester);
    expect(h.writes, hasLength(2));
    expect(
      h.vm.pastSearches,
      isEmpty,
      reason: 'only confirmed reads change presentation',
    );
    h.writes.last.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(
      h.writes,
      hasLength(3),
      reason: 'idempotent duplicates belong to repository',
    );
    h.writes.last.complete(const Result.success(null));
    h.reads.last.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    h.vm.requestPastSearchesRefresh();
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(3));
    h.reads.last.complete(Result.success(List.of(h.stored)));
    await pumpCommandTurns(tester);
    expect(h.vm.pastSearches, ['A']);
    expect(h.stored, ['A']);
    expect(h.repository.historyWrites, hasLength(3));
    expect(logger.calls, hasLength(1));
    h.vm.dispose();
  });

  testOwnerUI('S12 reentrant settlement acceptance preserves queued order', (
    tester,
  ) async {
    final h = SearchHistoryHarness();
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    h.vm.addToPastSearches('B');
    var reentered = false;
    h.vm.addListener(() {
      if (!reentered && !h.vm.pastSearches.contains('A')) {
        reentered = true;
        h.vm.addToPastSearches('C');
      }
    });
    await pumpCommandTurns(tester);
    h.writes.first.complete(Result.error(TestException('first failed')));
    await pumpCommandTurns(tester);
    expect(reentered, isTrue);
    expect(h.vm.pastSearches, isEmpty);
    h.writes[1].complete(const Result.success(null));
    await pumpCommandTurns(tester);
    h.writes[2].complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.stored, ['B', 'C']);
    expect(h.repository.historyWrites.map((write) => write.query), [
      'A',
      'B',
      'C',
    ]);
    expect(h.vm.pastSearches, ['B', 'C']);
    h.vm.dispose();
  });

  testOwnerUI(
    'S9 assertion remains fail loud and releases pending obligations',
    (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final observed = <Object>[];
      final assertion = AssertionError('writer contract failure');
      late SearchHistoryHarness h;
      runZonedGuarded(() {
        h = SearchHistoryHarness();
        h.vm.addToPastSearches('A');
        h.vm.addToPastSearches('B');
      }, (error, _) => observed.add(error));
      await pumpCommandTurns(tester);
      h.writes.single.completeError(assertion, StackTrace.current);
      await pumpCommandTurns(tester);
      expect(observed, [same(assertion)]);
      expect(logger.calls, isEmpty);
      expect(
        h.writes,
        hasLength(1),
        reason: 'assertion must not continue FIFO',
      );
      h.vm.requestPastSearchesRefresh();
      h.vm.addToPastSearches('C');
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(1), reason: 'bootstrap reads are independent');
      expect(h.writes, hasLength(1));
      h.vm.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 51));
      expect(tester.takeException(), isNull);
      expect(observed, hasLength(1));
    },
  );
}
