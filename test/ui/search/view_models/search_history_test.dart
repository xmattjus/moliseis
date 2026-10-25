import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/search_history_harness.dart';

void main() {
  final cases = [
    (
      initial: <String>[],
      operations: [('A', false), ('A', false)],
      expected: ['A'],
      count: 2,
      notify: 1,
      fail: false,
    ),
    (
      initial: <String>[],
      operations: [('A', false), ('A', true)],
      expected: <String>[],
      count: 2,
      notify: 2,
      fail: false,
    ),
    (
      initial: ['A', 'B'],
      operations: [('A', true), ('A', false)],
      expected: ['B', 'A'],
      count: 2,
      notify: 2,
      fail: false,
    ),
    (
      initial: <String>[],
      operations: [('A', false), ('B', false)],
      expected: ['A', 'B'],
      count: 2,
      notify: 2,
      fail: false,
    ),
    (
      initial: ['A', 'B', 'C'],
      operations: [('A', true), ('B', true)],
      expected: ['C'],
      count: 2,
      notify: 2,
      fail: false,
    ),
    (
      initial: <String>[],
      operations: [('A', false), ('B', false)],
      expected: ['B'],
      count: 2,
      notify: 3,
      fail: true,
    ),
    (
      initial: <String>[],
      operations: [('A', false), ('A', true)],
      expected: <String>[],
      count: 2,
      notify: 2,
      fail: true,
    ),
    (
      initial: ['A', 'B'],
      operations: [('A', true), ('A', false)],
      expected: ['A', 'B'],
      count: 2,
      notify: 3,
      fail: true,
    ),
  ];
  for (var index = 0; index < cases.length; index++) {
    testOwnerUI('S4/F2 ordered intentions $index', (tester) async {
      final value = cases[index];
      final h = SearchHistoryHarness(initial: value.initial);
      await pumpCommandTurns(tester);
      h.notifications = 0;
      for (final operation in value.operations) {
        if (operation.$2) {
          h.vm.removeFromPastSearches(operation.$1);
        } else {
          h.vm.addToPastSearches(operation.$1);
        }
      }
      expect(h.writes, isEmpty, reason: 'action entry is deferred');
      await pumpCommandTurns(tester);
      expect(h.writes, hasLength(1));
      h.writes.first.complete(
        value.fail
            ? Result.error(TestException('first'))
            : const Result.success(null),
      );
      await pumpCommandTurns(tester);
      if (value.count == 2) {
        expect(h.writes, hasLength(2));
        h.writes.last.complete(const Result.success(null));
        await pumpCommandTurns(tester);
      }
      expect(h.repository.historyWrites, hasLength(value.count));
      expect(h.repository.historyWrites.first.query, value.operations.first.$1);
      expect(
        h.repository.historyWrites.first.operation,
        value.operations.first.$2 ? 'remove' : 'add',
      );
      if (value.count == 2) {
        expect(h.repository.historyWrites.last.query, value.operations.last.$1);
        expect(
          h.repository.historyWrites.last.operation,
          value.operations.last.$2 ? 'remove' : 'add',
        );
      }
      expect(h.vm.pastSearches, value.expected);
      expect(h.stored, value.expected);
      // Notifications include read loading and terminal transitions.
      // The public contract is the confirmed data, not notification counts.
      expect(h.repository.getPastSearchesCallCount, greaterThanOrEqualTo(2));
      h.vm.dispose();
      await pumpCommandTurns(tester);
    });
  }

  testOwnerUI(
    'S3 known exclusions, exact remove and case insensitive duplicate',
    (tester) async {
      final h = SearchHistoryHarness(initial: ['A']);
      await pumpCommandTurns(tester);
      h.notifications = 0;
      h.vm.addToPastSearches('');
      h.vm.addToPastSearches('nAtUrA');
      h.vm.addToPastSearches('a');
      h.vm.removeFromPastSearches('a');
      await pumpCommandTurns(tester);
      expect(h.writes, hasLength(1));
      h.writes.first.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      h.writes.last.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      expect(h.repository.historyWrites, [
        (operation: 'add', query: 'a'),
        (operation: 'remove', query: 'a'),
      ]);
      expect(h.stored, ['A']);
      expect(h.vm.pastSearches, ['A']);
      h.vm.dispose();
    },
  );

  for (final stored in ['Natura', '']) {
    testOwnerUI('exact removal accepts stored category/empty: $stored', (
      tester,
    ) async {
      final h = SearchHistoryHarness(initial: [stored]);
      await pumpCommandTurns(tester);
      h.vm.removeFromPastSearches(stored);
      expect(h.vm.pastSearches, [stored]);
      await pumpCommandTurns(tester);
      expect(h.writes, hasLength(1));
      h.writes.single.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      expect(h.stored, isEmpty);
      h.vm.dispose();
    });
  }

  for (final order in ['before-entry', 'during-write', 'after-write']) {
    testOwnerUI('S5/S6 bootstrap authority $order', (tester) async {
      final h = SearchHistoryHarness(initial: ['old'], holdReads: true);
      await pumpCommandTurns(tester);
      h.vm.addToPastSearches('A');
      expect(h.vm.pastSearches, isEmpty);
      if (order != 'after-write') {
        h.reads.first.complete(const Result.success(['old']));
      }
      await pumpCommandTurns(tester);
      expect(h.vm.pastSearches, order == 'after-write' ? isEmpty : ['old']);
      expect(h.reads, hasLength(1));
      h.writes.first.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      if (order == 'after-write') {
        h.reads.first.complete(const Result.success(['old']));
      }
      await pumpCommandTurns(tester);
      if (order == 'after-write') {
        expect(h.reads, hasLength(1), reason: 'busy read retains no demand');
        h.vm.requestPastSearchesRefresh();
        await pumpCommandTurns(tester);
      }
      expect(h.reads, hasLength(2));
      h.reads.last.complete(Result.success(List.of(h.stored)));
      await pumpCommandTurns(tester);
      expect(h.vm.pastSearches, ['old', 'A']);

      expect(h.repository.historyWrites, hasLength(1));
      h.vm.dispose();
    });
  }

  testOwnerUI('H4 failed bootstrap does not prevent accepted FIFO writes', (
    tester,
  ) async {
    final h = SearchHistoryHarness(holdReads: true);
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    h.vm.addToPastSearches('B');
    h.reads.first.complete(Result.error(TestException('old get')));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(1));
    h.writes.first.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(2));
    // A successful write can request an independent best-effort read.
    h.writes.last.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(2));
    h.reads.last.complete(const Result.success(['A', 'B']));
    await pumpCommandTurns(tester);
    expect(h.vm.pastSearches, ['A', 'B']);

    h.vm.dispose();
  });

  for (final committed in [false, true]) {
    testOwnerUI('S7/F4 runtime commit=$committed without pending read', (
      tester,
    ) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final h = SearchHistoryHarness();
      await pumpCommandTurns(tester);
      h.notifications = 0;
      h.vm.addToPastSearches('A');
      await pumpCommandTurns(tester);
      final original = StateError('write runtime');
      final stack = StackTrace.fromString(
        '#0 controlledWrite (file:///history_store.dart:17:3)',
      );
      if (committed) h.applyStored('A');
      h.writes.first.completeError(original, stack);
      await pumpCommandTurns(tester);
      expect(h.repository.historyWrites, hasLength(1));
      expect(h.reads, hasLength(1));
      expect(h.vm.pastSearches, isEmpty);
      expect(h.vm.pastSearchesFailure, same(original));
      h.vm.requestPastSearchesRefresh();
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(2));
      expect(h.vm.pastSearches, committed ? ['A'] : isEmpty);
      expect(h.vm.pastSearchesFailure, isNull);
      expect(h.repository.historyWrites, hasLength(1));
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(original));
      expect(
        logger.calls.single.stackTrace.toString(),
        contains('history_store.dart'),
      );
      expect(logger.calls.single.stackTrace.toString(), contains('17:3'));
      h.vm.dispose();
    });
  }

  testOwnerUI(
    'S13 runtime waits for newer accepted mutation before reconcile',
    (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final h = SearchHistoryHarness();
      await pumpCommandTurns(tester);
      h.vm.addToPastSearches('A');
      h.vm.addToPastSearches('B');
      await pumpCommandTurns(tester);
      h.writes.first.completeError(StateError('first'));
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(1));
      expect(h.vm.pastSearches, isEmpty);
      expect(h.vm.pastSearchesFailure, isA<StateError>());
      h.writes.last.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(2));
      expect(h.vm.pastSearches, ['B']);
      expect(logger.calls, hasLength(1));
      h.vm.dispose();
    },
  );

  for (final runtime in [false, true]) {
    testOwnerUI('R1.1/2/3 read retry runtime=$runtime', (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final h = SearchHistoryHarness(holdReads: true);
      h.vm.requestPastSearchesRefresh();
      h.vm.requestPastSearchesRefresh();
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(1));
      final original = runtime
          ? StateError('get runtime')
          : TestException('get domain');
      if (runtime) {
        h.reads.first.completeError(original);
      } else {
        h.reads.first.complete(Result.error(original as Exception));
      }
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(1));
      expect(h.vm.pastSearchesState.value.hasFailure, isTrue);
      expect(logger.calls, hasLength(runtime ? 1 : 0));
      h.vm.requestPastSearchesRefresh();
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(2));
      h.reads.last.complete(const Result.success(['recovered']));
      await pumpCommandTurns(tester);
      expect(h.vm.pastSearchesState.value.completed, isTrue);
      expect(h.vm.pastSearches, ['recovered']);
      h.vm.dispose();
    });
  }

  testOwnerUI('H6 indefinitely pending read cannot block two accepted writes', (
    tester,
  ) async {
    final h = SearchHistoryHarness(holdReads: true);
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    h.vm.addToPastSearches('B');
    await pumpCommandTurns(tester);
    h.writes.first.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.writes, hasLength(2));
    h.writes.last.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.stored, ['A', 'B']);
    expect(h.reads, hasLength(1));
    expect(h.vm.pastSearches, isEmpty);
    h.reads.single.complete(const Result.success(['older confirmed']));
    await pumpCommandTurns(tester);
    expect(h.vm.pastSearches, ['older confirmed']);
    expect(h.reads, hasLength(1));
    h.vm.dispose();
  });

  testOwnerUI('H6 reads progress independently of accepted writes', (
    tester,
  ) async {
    final h = SearchHistoryHarness();
    await pumpCommandTurns(tester);
    h.vm.addToPastSearches('A');
    h.vm.addToPastSearches('B');
    h.vm.requestPastSearchesRefresh();
    h.vm.requestPastSearchesRefresh();
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(2));
    h.writes.first.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(3));
    h.writes.last.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(4));
    expect(h.vm.pastSearches, ['A', 'B']);
    h.vm.dispose();
  });

  testOwnerUI(
    'H5 busy refresh does not retain demand or revoke confirmed read',
    (tester) async {
      final h = SearchHistoryHarness(holdReads: true);
      await pumpCommandTurns(tester);
      h.vm.requestPastSearchesRefresh();
      h.reads.first.complete(const Result.success(['obsolete']));
      await pumpCommandTurns(tester);
      expect(h.vm.pastSearches, ['obsolete']);
      expect(h.reads, hasLength(1));
      h.vm.requestPastSearchesRefresh();
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(2));
      h.reads.last.complete(const Result.success(['current']));
      await pumpCommandTurns(tester);
      expect(h.vm.pastSearches, ['current']);

      h.vm.dispose();
    },
  );

  for (final duringRead in [false, true]) {
    testOwnerUI('R1.6/S12 dispose releases reader duringRead=$duringRead', (
      tester,
    ) async {
      final h = SearchHistoryHarness(holdReads: true);
      if (duringRead) await pumpCommandTurns(tester);
      h.vm.addToPastSearches('A');
      h.vm.requestPastSearchesRefresh();
      h.vm.dispose();
      final notifications = h.notifications;
      h.vm.requestPastSearchesRefresh();
      h.vm.addToPastSearches('forbidden');
      if (duringRead) h.reads.first.complete(const Result.success(['late']));
      await pumpCommandTurns(tester);
      expect(h.writes, hasLength(1));
      h.writes.first.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      expect(h.reads, hasLength(duringRead ? 1 : 0));
      expect(h.repository.historyWrites, hasLength(1));
      expect(h.notifications, notifications);
    });
  }

  testOwnerUI('H1 reentrant accepted write follows confirmed bootstrap', (
    tester,
  ) async {
    final h = SearchHistoryHarness(initial: ['base']);
    var accepted = false;
    h.vm.addListener(() {
      if (!accepted) {
        accepted = true;
        h.vm.addToPastSearches('A');
      }
    });
    await pumpCommandTurns(tester);
    expect(h.vm.pastSearches, ['base']);
    h.writes.first.complete(const Result.success(null));
    await pumpCommandTurns(tester);
    expect(h.reads, hasLength(2));
    expect(h.vm.pastSearches, ['base', 'A']);
    h.vm.dispose();
  });
}
