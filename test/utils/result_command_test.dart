import 'dart:async';

import 'package:command_it/command_it.dart' as command_it;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

void main() {
  testWidgets('MockCommand distinguishes nullable success from initial null', (
    tester,
  ) async {
    final command = command_it.MockCommand<String, Result<int>?>(
      initialValue: null,
    );
    expect(command.results.value.idle, isTrue);
    command
      ..queueResultsForNextRunCall([
        const command_it.CommandResult.isLoading('A'),
        const command_it.CommandResult.data('A', Result.success(1)),
      ])
      ..run('A');
    await tester.pump(Duration.zero);
    expect(command.results.value.completed, isTrue);
    expect(command.runCount, 1);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    const nullable = command_it.CommandResult<void, Result<int?>?>.data(
      null,
      Result.success(null),
    );
    expect(nullable.completed, isTrue);
    expect(nullable.idle, isFalse);
  });

  testWidgets('empty success and retained value never hide domain failure', (
    tester,
  ) async {
    final failure = Exception('expected');
    var outcome = const Result<List<int>>.success([]);
    final command = createResultCommandNoParam<List<int>>(
      () async => outcome,
      debugName: 'search_results',
    )..run();
    await tester.pump(Duration.zero);
    expect(command.results.value.completed, isTrue);
    expect(command.results.value.data!.getOrNull(), isEmpty);
    final priorValue = command.value;
    outcome = Result.error(failure);
    command.run();
    expect(command.results.value.isRunning, isTrue);
    expect(command.results.value.data, isNull);
    expect(command.value, same(priorValue));
    await tester.pump(Duration.zero);
    expect(command.results.value.domainError, same(failure));
    expect(command.results.value.completed, isFalse);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  test('snapshot projections separate neutral, null success and failures', () {
    const idle = command_it.CommandResult<void, Result<void>?>.blank();
    const running = command_it.CommandResult<void, Result<void>?>.isLoading();
    const success = command_it.CommandResult<void, Result<void>?>.data(
      null,
      Result.success(null),
    );
    final exception = Exception('expected');
    final failure = command_it.CommandResult<void, Result<void>?>.data(
      null,
      Result.error(exception),
    );
    final runtime = StateError('unexpected');
    final unexpected = command_it.CommandResult<void, Result<void>?>.error(
      null,
      runtime,
      command_it.ErrorReaction.globalHandler,
      StackTrace.empty,
    );
    expect(idle.idle, isTrue);
    expect(idle.completed, isFalse);
    expect(idle.hasFailure, isFalse);
    expect(running.idle, isFalse);
    expect(running.completed, isFalse);
    expect(running.hasFailure, isFalse);
    expect(success.completed, isTrue);
    expect(success.idle, isFalse);
    expect(failure.domainError, same(exception));
    expect(failure.completed, isFalse);
    expect(failure.hasFailure, isTrue);
    expect(unexpected.unexpectedError, same(runtime));
    expect(unexpected.domainError, isNull);
    expect(unexpected.hasFailure, isTrue);
  });

  testWidgets('ordinary admission is single-flight and runAsync joins', (
    tester,
  ) async {
    final pending = Completer<Result<int>>();
    final calls = <String>[];
    final command = createResultCommand<String, int>((value) {
      calls.add(value);
      return pending.future;
    }, debugName: 'search_results');
    final running = <bool>[];
    command.isRunning.addListener(() => running.add(command.isRunning.value));
    expect(command.results.value.idle, isTrue);
    command.run('A');
    expect(command.isRunningSync.value, isTrue);
    expect(command.canRun.value, isFalse);
    expect(running, isEmpty);
    final first = command.runAsync('ignored');
    final joined = command.runAsync('also ignored');
    expect(joined, same(first));
    command.run('B');
    await tester.pump(Duration.zero);
    expect(calls, ['A']);
    expect(running, [true]);
    expect(command.results.value.isRunning, isTrue);
    const result = Result.success(7);
    pending.complete(result);
    await tester.pump(Duration.zero);
    expect(await first, same(result));
    expect(command.results.value.completed, isTrue);
    expect(command.isRunningSync.value, isFalse);
    expect(command.canRun.value, isTrue);
    expect(running, [true, false]);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('no-param factory supports real Success<void>(null)', (
    tester,
  ) async {
    final command = createResultCommandNoParam<void>(
      () async => const Result.success(null),
      debugName: 'search_results',
    )..run();
    await tester.pump(Duration.zero);
    expect(command.results.value.completed, isTrue);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('dispose completes pending runAsync with neutral current value', (
    tester,
  ) async {
    final pending = Completer<Result<int>>();
    final command = createResultCommand<String, int>(
      (_) => pending.future,
      debugName: 'search_results',
    );
    final completion = command.runAsync('A');
    await tester.pump(Duration.zero);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    expect(await completion, isNull);
    expect(command.results.value.completed, isFalse);
    pending.complete(const Result.success(7));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('upstream canRun restriction remains authoritative', (
    tester,
  ) async {
    final restriction = ValueNotifier(true);
    var calls = 0;
    final command = command_it.Command.createAsyncNoParam<Result<void>?>(
      () async {
        calls++;
        return const Result.success(null);
      },
      initialValue: null,
      restriction: restriction,
    )..run();
    await tester.pump(Duration.zero);
    expect(calls, 0);
    expect(command.canRun.value, isFalse);
    restriction.value = false;
    await tester.pump(Duration.zero);
    command.run();
    await tester.pump(Duration.zero);
    expect(calls, 1);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    restriction.dispose();
  });
}
