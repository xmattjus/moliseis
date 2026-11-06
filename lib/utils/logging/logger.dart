import 'package:moliseis/utils/logging/log_event.dart';

/// Contract for logging events from any layer of the application.
///
/// Implementations decide how events are rendered (console, file, remote
/// service).
// Interface is used to allow logging implementations change.
abstract interface class Logger {
  /// Writes [event] best effort, without changing business outcomes.
  ///
  /// Pass [error] and [stackTrace] to attach exception context. Additional
  /// [extra] data is local only. Remote intent and approved fields are defined
  /// centrally by the application logger, independently of severity.
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  });
}
