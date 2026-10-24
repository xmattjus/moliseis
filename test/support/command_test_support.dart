import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/utils/command_configuration.dart';

import 'mock_logger.dart';

/// Installs application command reporting and returns its static restoration.
VoidCallback installCommandTestReporting(MockLogger logger) {
  final handler = commands.Command.globalExceptionHandler;
  final reports = commands.Command.reportAllExceptions;
  configureCommandReporting(logger);
  return () {
    commands.Command.globalExceptionHandler = handler;
    commands.Command.reportAllExceptions = reports;
  };
}

/// Drives microtasks and upstream zero timers without real time.
Future<void> pumpCommandTurns(WidgetTester tester) async {
  for (var turn = 0; turn < 4; turn++) {
    await tester.pump(Duration.zero);
  }
}

/// Unmounts Provider owners before Flutter verifies pending timer invariants.
///
/// Owners revoke synchronously and release commands across event turns;
/// command_it owns a documented 50 ms notifier teardown. Keep cleanup
/// inside the widget test's virtual clock, rather than in late test teardown.
@isTest
void testOwnerUI(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  VoidCallback? disposeOwners,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(
    description,
    (tester) async {
      try {
        await callback(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        disposeOwners?.call();
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 50));
        await pumpCommandTurns(tester);
      }
    },
    skip: skip,
    timeout: timeout,
    variant: variant,
  );
}
