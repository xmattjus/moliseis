import 'package:command_it/command_it.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logger.dart';

/// Routes handled command failures through the existing application logger.
///
/// Parameters and error wrappers are deliberately excluded from telemetry.
/// Upstream's fail-loud assertion policy remains unchanged.
void configureCommandReporting(Logger logger) {
  Command.reportAllExceptions = false;
  Command.globalExceptionHandler = (commandError, stackTrace) {
    final name = commandError.commandName;
    final safeName = switch (name) {
      'search_results' || 'search_suggestions' || 'geo_map_selection' => name!,
      _ => 'command',
    };
    logger.log(
      CommandExecutionFailed(debugName: safeName),
      error: commandError.error,
      stackTrace: stackTrace,
    );
  };
}
