import 'dart:async';

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../support/command_test_support.dart';
import '../support/mock_logger.dart';

void main() {
  late MockLogger logger;
  setUp(() {
    logger = MockLogger();
    addTearDown(installCommandTestReporting(logger));
  });

  testWidgets('neutral, invalidate and dispose-before-start do no work', (
    tester,
  ) async {
    var calls = 0;
    final command = RestartableCommand<String, int>((_) async {
      calls++;
      return const Result.success(1);
    }, debugName: 'search_results');
    expect(command.results.value.idle, isTrue);
    expect(command.results.value.completed, isFalse);
    command.run('A');
    expect(command.isRunningSync.value, isTrue);
    command.invalidate();
    expect(command.isRunningSync.value, isFalse);
    await pumpCommandTurns(tester);
    expect(command.results.value.idle, isTrue);
    expect(calls, 0);
    command
      ..run('B')
      ..dispose()
      ..dispose();
    await pumpCommandTurns(tester);
    expect(calls, 0);
    expect(command.debugLiveChildCount, 0);
  });

  for (final staleOutcome in ['success', 'domain', 'runtime']) {
    testWidgets(
      'slow A / fast B ignores stale $staleOutcome and retires once',
      (tester) async {
        final a = Completer<Result<int>>();
        final b = Completer<Result<int>>();
        final starts = <String>[];
        final terminals = <String?>[];
        final running = <bool>[];
        final command = RestartableCommand<String, int>((parameter) {
          starts.add(parameter);
          return parameter == 'A' ? a.future : b.future;
        }, debugName: 'search_results');
        command.results.addListener(() {
          final result = command.results.value;
          if (!result.isRunning && !result.idle) {
            terminals.add(result.paramData);
          }
        });
        command.isRunning.addListener(
          () => running.add(command.isRunning.value),
        );
        command.run('A');
        await pumpCommandTurns(tester);
        command.run('B');
        expect(command.isRunningSync.value, isTrue);
        await pumpCommandTurns(tester);
        expect(starts, ['A', 'B']);
        expect(a.isCompleted, isFalse);
        b.complete(const Result.success(2));
        await pumpCommandTurns(tester);
        expect(command.results.value.data?.getOrNull(), 2);
        expect(command.isRunning.value, isFalse);
        expect(command.isRunningSync.value, isFalse);
        expect(command.debugLiveChildCount, 1);
        expect(command.debugRetiredChildCount, 1);
        final failure = StateError('stale');
        switch (staleOutcome) {
          case 'success':
            a.complete(const Result.success(1));
          case 'domain':
            a.complete(Result.error(Exception('expected')));
          case 'runtime':
            a.completeError(failure, StackTrace.current);
        }
        await pumpCommandTurns(tester);
        expect(terminals, ['B']);
        expect(running, [true, false]);
        expect(command.results.value.data?.getOrNull(), 2);
        expect(logger.calls, hasLength(staleOutcome == 'runtime' ? 1 : 0));
        if (staleOutcome == 'runtime') {
          expect(logger.calls.single.error, same(failure));
        }
        expect(command.debugLiveChildCount, 0);
        expect(command.debugRetiredChildCount, 2);
        command.dispose();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A/B/C admitted synchronously starts only C, including buffering',
    (tester) async {
      final starts = <String>[];
      final command =
          RestartableCommand<String, int>((parameter) async {
              starts.add(parameter);
              return const Result.success(3);
            }, debugName: 'search_results')
            ..run('A')
            ..run('B')
            ..run('C');
      await pumpCommandTurns(tester);
      expect(starts, ['C']);
      expect(command.results.value.paramData, 'C');
      expect(command.debugRetiredChildCount, 1);
      command.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'started A/B/C only C terminal; stale fast completion suppressed',
    (tester) async {
      final requests = <String, Completer<Result<int>>>{};
      final terminals = <String?>[];
      final command = RestartableCommand<String, int>((parameter) {
        return (requests[parameter] = Completer<Result<int>>()).future;
      }, debugName: 'search_results');
      command.results.addListener(() {
        if (command.results.value.completed) {
          terminals.add(command.results.value.paramData);
        }
      });
      command.run('A');
      await pumpCommandTurns(tester);
      command.run('B');
      requests['A']!.complete(const Result.success(1));
      await pumpCommandTurns(tester);
      command.run('C');
      requests['B']!.complete(const Result.success(2));
      await pumpCommandTurns(tester);
      expect(command.isRunning.value, isTrue);
      requests['C']!.complete(const Result.success(3));
      await pumpCommandTurns(tester);
      expect(terminals, ['C']);
      expect(command.debugRetiredChildCount, 3);
      command.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets('queued stale inner during cancellation never starts work', (
    tester,
  ) async {
    final requests = <String, Completer<Result<int>>>{};
    final command = RestartableCommand<String, int>((parameter) {
      return (requests[parameter] = Completer<Result<int>>()).future;
    }, debugName: 'search_results')..run('A');
    await pumpCommandTurns(tester);
    command
      ..run('B')
      ..run('C');
    await pumpCommandTurns(tester);
    expect(requests.keys, ['A', 'C']);
    command.invalidate();
    expect(command.isRunningSync.value, isFalse);
    requests
      ..['A']!.complete(const Result.success(1))
      ..['C']!.complete(const Result.success(3));
    await pumpCommandTurns(tester);
    expect(command.results.value.idle, isTrue);
    expect(command.debugRetiredChildCount, 2);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('equal parameters are separate executions', (tester) async {
    final requests = <Completer<Result<int>>>[];
    final command = RestartableCommand<String, int>((_) {
      final result = Completer<Result<int>>();
      requests.add(result);
      return result.future;
    }, debugName: 'search_results')..run('same');
    await pumpCommandTurns(tester);
    command.run('same');
    await pumpCommandTurns(tester);
    expect(requests, hasLength(2));
    requests
      ..[1].complete(const Result.success(2))
      ..[0].complete(const Result.success(1));
    await pumpCommandTurns(tester);
    expect(command.results.value.data?.getOrNull(), 2);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final synchronous in [false, true]) {
    testWidgets(
      'latest runtime throw terminal, exactly one report (sync=$synchronous)',
      (tester) async {
        final pending = Completer<Result<int>>();
        final failure = StateError('unexpected');
        final command = RestartableCommand<String, int>((_) {
          if (synchronous) throw failure;
          return pending.future;
        }, debugName: 'search_results')..run('A');
        await pumpCommandTurns(tester);
        if (!synchronous) pending.completeError(failure, StackTrace.current);
        await pumpCommandTurns(tester);
        expect(command.results.value.unexpectedError, same(failure));
        expect(command.results.value.data, isNull);
        expect(command.isRunning.value, isFalse);
        expect(logger.calls, hasLength(1));
        expect(command.debugLiveChildCount, 0);
        expect(command.debugRetiredChildCount, 1);
        command.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }

  for (final outcome in ['success', 'runtime']) {
    testWidgets(
      'dispose in-flight blocks emissions, retains $outcome cleanup',
      (tester) async {
        final pending = Completer<Result<int>>();
        var notifications = 0;
        final command = RestartableCommand<String, int>(
          (_) => pending.future,
          debugName: 'search_results',
        );
        command.results.addListener(() => notifications++);
        command.run('A');
        await pumpCommandTurns(tester);
        final before = notifications;
        command.dispose();
        expect(command.debugLiveChildCount, 1);
        if (outcome == 'success') {
          pending.complete(const Result.success(1));
        } else {
          pending.completeError(StateError('late'), StackTrace.current);
        }
        await pumpCommandTurns(tester);
        expect(notifications, before);
        expect(command.debugLiveChildCount, 0);
        expect(command.debugRetiredChildCount, 1);
        expect(logger.calls, hasLength(outcome == 'runtime' ? 1 : 0));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final reentry in ['run', 'dispose']) {
    testWidgets('synchronous running observer reentrant $reentry', (
      tester,
    ) async {
      final starts = <String>[];
      final command = RestartableCommand<String, int>((parameter) async {
        starts.add(parameter);
        return const Result.success(1);
      }, debugName: 'search_results');
      var reentered = false;
      command.isRunningSync.addListener(() {
        if (reentered || !command.isRunningSync.value) return;
        reentered = true;
        if (reentry == 'run') {
          command.run('B');
        } else {
          command.dispose();
        }
      });
      command.run('A');
      await pumpCommandTurns(tester);
      if (reentry == 'run') {
        expect(starts, ['B']);
        expect(command.results.value.paramData, 'B');
        expect(command.isRunningSync.value, isFalse);
        command.dispose();
      } else {
        expect(starts, isEmpty);
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(command.debugLiveChildCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reentry in ['run', 'dispose']) {
    testWidgets('terminal observer reentrant $reentry fences remainder of A', (
      tester,
    ) async {
      final b = Completer<Result<int>>();
      late final RestartableCommand<String, int> command;
      command = RestartableCommand<String, int>((parameter) async {
        return parameter == 'A' ? const Result.success(1) : await b.future;
      }, debugName: 'search_results');
      final running = <bool>[];
      command.isRunning.addListener(() => running.add(command.isRunning.value));
      command.results.addListener(() {
        if (command.results.value.completed &&
            command.results.value.paramData == 'A') {
          if (reentry == 'run') {
            command.run('B');
          } else {
            command.dispose();
          }
        }
      });
      command.run('A');
      await pumpCommandTurns(tester);
      expect(running, [true]);
      if (reentry == 'run') {
        expect(command.isRunningSync.value, isTrue);
        b.complete(const Result.success(2));
        await pumpCommandTurns(tester);
        expect(command.results.value.paramData, 'B');
        expect(running, [true, false]);
        command.dispose();
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  }

  for (final ownership in ['current', 'superseded', 'disposed']) {
    testWidgets('AssertionError $ownership rethrows once and cleans once', (
      tester,
    ) async {
      final errors = <Object>[];
      final assertion = AssertionError('development failure');
      late Completer<Result<int>> a;
      late RestartableCommand<String, int> command;
      final terminals = <String?>[];
      runZonedGuarded(() {
        a = Completer<Result<int>>();
        command = RestartableCommand<String, int>(
          (parameter) => parameter == 'A'
              ? a.future
              : Future.value(const Result.success(2)),
          debugName: 'search_results',
        );
        command.results.addListener(() {
          if (!command.results.value.isRunning && !command.results.value.idle) {
            terminals.add(command.results.value.paramData);
          }
        });
        command.run('A');
      }, (error, _) => errors.add(error));
      await pumpCommandTurns(tester);
      expect(command.debugLiveChildCount, 1);
      if (ownership == 'superseded') command.run('B');
      if (ownership == 'disposed') command.dispose();
      a.completeError(assertion, StackTrace.current);
      await pumpCommandTurns(tester);
      expect(errors, [same(assertion)]);
      expect(logger.calls, isEmpty);
      expect(terminals, ownership == 'superseded' ? ['B'] : isEmpty);
      expect(commands.Command.assertionsAlwaysThrow, isTrue);
      expect(command.debugLiveChildCount, 0);
      expect(command.debugRetiredChildCount, ownership == 'superseded' ? 2 : 1);
      if (ownership != 'disposed') command.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(errors, hasLength(1));
    });
  }
}
