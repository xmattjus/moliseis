import 'package:command_it/command_it.dart';
import 'package:moliseis/utils/logging/logging.dart';

/// Routes handled command failures through the existing application logger.
///
/// Parameters and error wrappers are deliberately excluded from telemetry.
/// Upstream's fail-loud assertion policy remains unchanged.
void configureCommandReporting(Logger logger) {
  Command.reportAllExceptions = false;
  Command.globalExceptionHandler = (commandError, stackTrace) {
    final name = commandError.commandName;
    if (name == 'sync_view_model.sync') {
      logger.log(
        SyncFailure(
          owner: SyncFailureOwner.command,
          category: syncFailureCategory(commandError.error),
        ),
        error: commandError.error,
        stackTrace: stackTrace,
      );
      return;
    }
    final safeName = switch (name) {
      'search_results' ||
      'search_suggestions' ||
      'geo_map_selection' ||
      'content_submission_submit' ||
      'admin_submission_editor_save' ||
      'admin_submission_editor_add_asset' => name!,
      _ => 'command',
    };
    logger.log(
      CommandExecutionFailed(debugName: safeName),
      error: commandError.error,
      stackTrace: stackTrace,
    );
  };
}
