import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/command_configuration.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart' hide Error;
import 'package:moliseis/utils/result_command.dart';

import '../support/mock_logger.dart';

void main() {
  final previousHandler = Command.globalExceptionHandler;
  final previousReportAll = Command.reportAllExceptions;
  final previousDetailed = Command.detailedStackTraces;

  tearDown(() {
    Command.globalExceptionHandler = previousHandler;
    Command.reportAllExceptions = previousReportAll;
    Command.detailedStackTraces = previousDetailed;
  });

  test('configuration preserves assertion policy and allow-lists names', () {
    final logger = MockLogger();
    final assertionPolicy = Command.assertionsAlwaysThrow;
    configureCommandReporting(logger);
    expect(assertionPolicy, isTrue);
    expect(Command.assertionsAlwaysThrow, assertionPolicy);
    expect(Command.reportAllExceptions, isFalse);
    final error = StateError('runtime');
    final stack = StackTrace.fromString('original stack');
    Command.globalExceptionHandler!(
      CommandError<String>(error: error, paramData: 'PRIVATE QUERY'),
      stack,
    );
    expect(logger.calls, hasLength(1));
    final call = logger.calls.single;
    expect(call.event, isA<CommandExecutionFailed>());
    expect(call.event.name, 'command_execution_failed');
    expect(call.event.data, {'debugName': 'command'});
    expect(call.error, same(error));
    expect(call.stackTrace, same(stack));
    expect(call.extra, isNull);
  });

  testWidgets('arbitrary command names never enter the event payload', (
    tester,
  ) async {
    final logger = MockLogger();
    configureCommandReporting(logger);
    final command = createResultCommand<String, void>(
      (_) async => const Result.success(null),
      debugName: 'PRIVATE USER TEXT',
    );
    final error = StateError('runtime');
    Command.globalExceptionHandler!(
      CommandError<String>(
        command: command,
        error: error,
        paramData: 'PRIVATE QUERY',
      ),
      StackTrace.empty,
    );
    expect(logger.calls.single.event.data, {'debugName': 'command'});
    expect(logger.calls.single.error, same(error));
    expect(logger.calls.single.extra, isNull);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('domain error never invokes global reporting', (tester) async {
    final logger = MockLogger();
    configureCommandReporting(logger);
    final expected = Exception('domain');
    final command = createResultCommand<String, void>(
      (_) async => Result.error(expected),
      debugName: 'search_results',
    )..run('PRIVATE QUERY');
    await tester.pump(Duration.zero);
    expect(command.results.value.domainError, same(expected));
    expect(logger.calls, isEmpty);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('AssertionError keeps the upstream uncaught development path', (
    tester,
  ) async {
    final logger = MockLogger();
    configureCommandReporting(logger);
    final assertion = AssertionError('programming failure');
    final observed = <Object>[];
    late ResultCommand<String, void> command;
    runZonedGuarded(() {
      command = createResultCommand<String, void>(
        (_) => throw assertion,
        debugName: 'search_results',
      )..run('PRIVATE QUERY');
    }, (error, _) => observed.add(error));
    for (var i = 0; i < 4; i++) {
      await tester.pump(Duration.zero);
    }
    expect(observed, [same(assertion)]);
    expect(logger.calls, isEmpty);
    expect(command.results.value.completed, isFalse);
    expect(command.results.value.hasFailure, isFalse);
    expect(command.results.value.data, isNull);
    command.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  for (final error in <Object>[StateError('runtime'), TypeError()]) {
    testWidgets('handled ${error.runtimeType} reports once and is terminal', (
      tester,
    ) async {
      final logger = MockLogger();
      configureCommandReporting(logger);
      Command.detailedStackTraces = false;
      final stack = StackTrace.fromString('original runtime stack');
      final command = createResultCommand<String, void>((_) async {
        Error.throwWithStackTrace(error, stack);
      }, debugName: 'search_suggestions');
      final future = command.runAsync('PRIVATE QUERY');
      Object? futureError;
      final observed = future.then<void>(
        (_) => fail('Unexpected success'),
        onError: (Object caught, StackTrace _) => futureError = caught,
      );
      await tester.pump(Duration.zero);
      await observed;
      expect(futureError, same(error));
      expect(command.results.value.unexpectedError, same(error));
      expect(command.results.value.isRunning, isFalse);
      expect(logger.calls, hasLength(1));
      final call = logger.calls.single;
      expect(call.error, same(error));
      expect(call.stackTrace, same(stack));
      expect(call.event.data, {'debugName': 'search_suggestions'});
      expect(call.extra, isNull);
      command.dispose();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
