import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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
