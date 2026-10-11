import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/command_configuration.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart' as domain;

import '../support/mock_logger.dart';

// Audited command_it 9.5.2 / listen_it 6.0.0 from package_config.json.
// Success checks _isDisposing after await; catch does not. Result.error is
// a value, not a throw. dispose defers notifier teardown and runAsync
// completion by 50 ms. Assertions rethrow before filtering/reporting (upstream default).
// CustomValueNotifier.results notifies synchronously; isRunning asynchronously.
// notifyListeners asserts against disposal before checking listener count,
// throwing FlutterError; removeListener remains legal after disposal.
void main() {
  late List<CommandError<dynamic>> globalErrors;
  late List<StackTrace> globalStacks;
  late List<FlutterErrorDetails> flutterErrors;

  setUp(() {
    final handler = Command.globalExceptionHandler;
    final reportAll = Command.reportAllExceptions;
    final filter = Command.errorFilterDefault;
    // Preserve the deprecated debug policy while observing upstream defaults.
    // ignore: deprecated_member_use
    final debugThrows = Command.debugErrorsThrowAlways;
    final flutterHandler = FlutterError.onError;
    final assertionPolicy = Command.assertionsAlwaysThrow;
    addTearDown(() {
      Command.globalExceptionHandler = handler;
      Command.reportAllExceptions = reportAll;
      Command.errorFilterDefault = filter;
      // Restore the exact policy, including this deprecated switch.
      // ignore: deprecated_member_use
      Command.debugErrorsThrowAlways = debugThrows;
      FlutterError.onError = flutterHandler;
      // This suite never changes the assertion policy.
      expect(Command.assertionsAlwaysThrow, assertionPolicy);
    });
    expect(
      assertionPolicy,
      isTrue,
      reason: 'Observe upstream assertion policy',
    );
    globalErrors = [];
    globalStacks = [];
    flutterErrors = [];
    Command.reportAllExceptions = false;
    // Match the audited upstream default, without replacing its semantics.
    // ignore: deprecated_member_use
    Command.debugErrorsThrowAlways = false;
    Command.errorFilterDefault = const GlobalIfNoLocalErrorFilter();
    Command.globalExceptionHandler = (error, stack) {
      globalErrors.add(error);
      globalStacks.add(stack);
    };
    FlutterError.onError = flutterErrors.add;
  });

  // Parameterization keeps identical timing and instrumentation across A/B/E.
  // No custom filter, ResultCommand, RestartableCommand or production wrapper.
  for (final suite in ['A upstream-like', 'B runAsync', 'E Molise reporting']) {
    group(suite, () {
      final scenarios = suite.startsWith('A')
          ? [
              'success',
              'Result.error',
              'StateError early',
              'StateError',
              'AssertionError',
            ]
          : suite.startsWith('B')
          ? ['success', 'StateError', 'AssertionError']
          : ['StateError', 'AssertionError', 'Result.error'];
      for (final scenario in scenarios) {
        test(
          'captures current $scenario after dispose; checks notifier safety',
          () async {
            final useRunAsync = suite.startsWith('B');
            final appReporting = suite.startsWith('E');
            final early = scenario.endsWith('early');
            final resultValue = scenario == 'Result.error';
            final throwsState = scenario.startsWith('StateError');
            final throwsAssertion = scenario == 'AssertionError';
            final logger = MockLogger();
            if (appReporting) configureCommandReporting(logger);
            final initial = resultValue
                ? const domain.Result<int>.success(7)
                : 7;
            final terminal = resultValue
                ? domain.Result<int>.error(Exception('domain failure'))
                : 42;
            final original = throwsAssertion
                ? AssertionError('original late assertion')
                : StateError('original late state error');
            late Completer<Object> pending;
            final entered = Completer<void>();
            final exited = Completer<void>();
            final zoneErrors = <({Object error, StackTrace stack})>[];
            final publications = <Object?>[];
            final resultPublications = <CommandResult<String?, Object>>[];
            final localErrors = <CommandError<String>?>[];
            var executions = 0;
            var disposed = false;
            var futureCompletions = 0;
            Object? returnedValue;
            Object? returnedError;
            Future<void>? observedFuture;
            late Command<String, Object> command;
            runZonedGuarded(() {
              pending = Completer<Object>();
              if (resultValue) {
                command = Command.createAsync<String, domain.Result<int>>(
                  (parameter) async {
                    executions++;
                    entered.complete();
                    try {
                      return (await pending.future) as domain.Result<int>;
                    } finally {
                      exited.complete();
                    }
                  },
                  initialValue: initial as domain.Result<int>,
                  debugName: 'search_results',
                );
              } else {
                command = Command.createAsync<String, Object>(
                  (parameter) async {
                    executions++;
                    entered.complete();
                    try {
                      return await pending.future;
                    } finally {
                      exited.complete();
                    }
                  },
                  initialValue: initial,
                  debugName: 'search_results',
                );
              }
              command.addListener(() {
                if (disposed) publications.add(command.value);
              });
              command.results.addListener(() {
                if (disposed) resultPublications.add(command.results.value);
              });
              command.errors.addListener(() {
                if (disposed) localErrors.add(command.errors.value);
              });
              if (useRunAsync) {
                observedFuture = command
                    .runAsync('PRIVATE TEST PARAM')
                    .then<void>(
                      (value) {
                        futureCompletions++;
                        returnedValue = value;
                      },
                      onError: (Object error, StackTrace stack) {
                        futureCompletions++;
                        returnedError = error;
                      },
                    );
              } else {
                command.run('PRIVATE TEST PARAM');
              }
            }, (error, stack) => zoneErrors.add((error: error, stack: stack)));
            await entered.future;
            // Drain the startup async notification before marking disposal.
            await Future<void>(() {});
            final runningBefore = command.isRunning.value;
            disposed = true;
            command.dispose();
            addTearDown(() async {
              // Drain deferred teardown even when safety assertions fail.
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            if (!early) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
            if (useRunAsync) {
              await observedFuture;
              expect(futureCompletions, 1);
              expect(returnedValue, same(initial));
              expect(returnedError, isNull);
              expect(exited.isCompleted, isFalse);
            }
            if (throwsState || throwsAssertion) {
              pending.completeError(original, StackTrace.current);
            } else {
              pending.complete(terminal);
            }
            await exited.future;
            // Zero event turns drain CommandAsync, finally and notifier work;
            // they do not create the race or approximate the 50 ms boundary.
            for (var turn = 0; turn < 4; turn++) {
              await Future<void>(() {});
            }
            final result = command.results.value;
            final runningAfter = command.isRunning.value;
            // Record secondary failures before safety checks.
            // Disposed notifiers throw FlutterError objects into the Zone;
            // whereas FlutterError.onError only sees reportError notifications.
            // ignore: avoid_print
            print(
              '$suite / $scenario: global=${globalErrors.length}, '
              'logger=${logger.calls.length}, '
              'FlutterError.onError=${flutterErrors.length}, '
              'zone=${zoneErrors.map((e) => e.error.runtimeType).toList()}, '
              'value publications=${publications.length}, '
              'result publications=${resultPublications.length}, '
              'local errors=${localErrors.length}, '
              'running=$runningBefore->$runningAfter, '
              'resultError=${result.error?.runtimeType}, '
              'runAsync=$returnedValue/$futureCompletions',
            );
            for (final captured in zoneErrors) {
              // Retain type and upstream stack evidence even for red tests.
              // ignore: avoid_print
              print(
                'Captured Zone error: ${captured.error}\n${captured.stack}',
              );
            }
            expect(executions, 1);
            expect(exited.isCompleted, isTrue);
            expect(command.value, same(initial));
            expect(runningBefore, isTrue);
            expect(
              runningAfter,
              isTrue,
            ); // finally skips state updates on disposal.
            expect(publications, isEmpty);
            expect(flutterErrors, isEmpty);
            expect(globalErrors, isEmpty);
            expect(globalStacks, isEmpty);
            expect(logger.calls, isEmpty);
            if (early) {
              expect(resultPublications, hasLength(1));
              expect(resultPublications.single.error, same(original));
              expect(localErrors, hasLength(1));
              expect(localErrors.single!.error, same(original));
              expect(localErrors.single!.paramData, 'PRIVATE TEST PARAM');
              expect(result.error, same(original));
              expect(result.isRunning, isFalse);
              expect(zoneErrors, isEmpty);
            } else if (throwsState) {
              expect(resultPublications, isEmpty);
              expect(localErrors, isEmpty);
              // Assignment happens before notifyListeners' disposal assertion.
              expect(result.error, same(original));
              expect(zoneErrors, hasLength(1));
              expect(zoneErrors.single.error, isA<FlutterError>());
              expect(zoneErrors.single.error, isNot(same(original)));
              expect(
                zoneErrors.single.error.toString(),
                contains('used after being disposed'),
              );
              expect(
                zoneErrors.single.stack.toString(),
                contains('CustomChangeNotifier.debugAssertNotDisposed'),
              );
              expect(
                zoneErrors.single.stack.toString(),
                contains('Command._handleErrorFiltered'),
              );
            } else {
              expect(resultPublications, isEmpty);
              expect(localErrors, isEmpty);
              expect(result.error, isNull);
              expect(result.isRunning, isTrue);
              if (throwsAssertion) {
                expect(zoneErrors, hasLength(1));
                expect(zoneErrors.single.error, same(original));
                expect(zoneErrors.single.stack.toString(), isNotEmpty);
              } else {
                expect(zoneErrors, isEmpty);
              }
            }
            if (appReporting) {
              expect(logger.eventsOfType<CommandExecutionFailed>(), isEmpty);
              // No error, paramData, or duplicate is logged.
              expect(logger.calls.where((call) => call.extra != null), isEmpty);
            }
            if (useRunAsync) {
              expect(futureCompletions, 1);
              expect(returnedValue, same(initial));
              expect(returnedError, isNull);
            }
            if (throwsState && !early) {
              // Desired safety invariant intentionally red on 9.5.2; captured
              // evidence above is not an endorsement of the secondary failure.
              expect(
                zoneErrors,
                isEmpty,
                reason:
                    'Late StateError must not cause secondary '
                    'notifier use-after-dispose',
              );
            }
          },
          skip: scenario == 'StateError'
              ? 'command_it 9.5.2: late StateError after dispose causes upstream '
                    'notifier use-after-dispose. Re-enable after an upstream fix.'
              : false,
        );
      }
    });
  }

  for (final beforeEntry in [true, false]) {
    group(
      beforeEntry ? 'C dispose before action entry' : 'D run after dispose',
      () {
        test(
          'never enters the user action or publishes a terminal result',
          () async {
            final zoneErrors = <Object>[];
            var executions = 0;
            final values = <int>[];
            final results = <CommandResult<void, int>>[];
            late Command<void, int> command;
            runZonedGuarded(() {
              command = Command.createAsyncNoParam<int>(() async {
                executions++;
                return 42;
              }, initialValue: 7);
              command.addListener(() => values.add(command.value));
              command.results.addListener(
                () => results.add(command.results.value),
              );
              if (beforeEntry) {
                // Same synchronous turn, before deferred entry.
                command
                  ..run()
                  ..dispose();
              } else {
                // Immediate run after logical disposal.
                command
                  ..dispose()
                  ..run();
              }
            }, (error, stack) => zoneErrors.add(error));
            await Future<void>.delayed(const Duration(milliseconds: 100));
            if (!beforeEntry) {
              runZonedGuarded(
                command.run, // Also after physical teardown.
                (error, stack) => zoneErrors.add(error),
              );
            }
            for (var turn = 0; turn < 4; turn++) {
              await Future<void>(() {});
            }
            expect(executions, 0);
            expect(values, isEmpty);
            expect(results.where((result) => !result.isRunning), isEmpty);
            expect(results, hasLength(beforeEntry ? 1 : 0));
            expect(command.value, 7);
            expect(flutterErrors, isEmpty);
            expect(zoneErrors, isEmpty);
            expect(globalErrors, isEmpty);
          },
        );
      },
    );
  }
}
