import 'package:moliseis/utils/logging/log_event.dart';

/// Contract for logging events from any layer of the application.
///
/// Implementations decide how events are rendered (console, file, remote
/// service).
// Interface is used to allow logging implementations change.
// ignore: one_member_abstracts
abstract interface class Logger {
  /// Writes [event] to the underlying log destination.
  ///
  /// Pass [error] and [stackTrace] to attach exception context. Additional
  /// [extra] data is merged into the event payload.
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  });
}
