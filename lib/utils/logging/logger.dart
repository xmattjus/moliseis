import 'package:moliseis/utils/logging/log_event.dart';

/// Contract for logging events from any layer of the application.
///
/// Implementations own local rendering and remote forwarding.
// Interface is used to allow logging implementations change.
abstract interface class Logger {
  /// Writes [event] best effort, without changing business outcomes.
  ///
  /// Pass [error] and [stackTrace] to attach exception context. Additional
  /// [extra] data is Debug-only local context. The application logger defines
  /// remote intent and approved fields independently of severity.
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  });
}
