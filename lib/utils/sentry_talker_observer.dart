import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Forwards Talker errors and warning-level logs to Sentry.
///
/// Forwarding is controlled by [SentryLoggingFlag] so user consent changes
/// can be reflected at runtime without rebuilding the logger.
class SentryTalkerObserver extends TalkerObserver {
  SentryTalkerObserver({required SentryLoggingFlag flag}) : _flag = flag;

  final SentryLoggingFlag _flag;

  @override
  void onError(TalkerError err) {
    if (!_flag.enabled) return;

    Sentry.captureException(
      err.error,
      stackTrace: err.stackTrace,
      hint: Hint.withMap({'talker_message': err.generateTextMessage()}),
    );
    super.onError(err);
  }

  @override
  void onException(TalkerException exception) {
    if (!_flag.enabled) return;

    Sentry.captureException(
      exception.exception,
      stackTrace: exception.stackTrace,
      hint: Hint.withMap({'talker_message': exception.generateTextMessage()}),
    );
    super.onException(exception);
  }

  @override
  void onLog(TalkerData log) {
    if (!_flag.enabled) return;

    // Only forward warnings and above to Sentry to avoid noise
    if (log.logLevel == null) return;
    if (log.logLevel!.index < LogLevel.warning.index) return;

    Sentry.captureEvent(
      SentryEvent(
        message: SentryMessage(log.generateTextMessage()),
        level: _toSentryLevel(log.logLevel!),
      ),
    );

    super.onLog(log);
  }

  SentryLevel _toSentryLevel(LogLevel level) => switch (level) {
    LogLevel.warning => SentryLevel.warning,
    LogLevel.error => SentryLevel.error,
    LogLevel.critical => SentryLevel.fatal,
    _ => SentryLevel.info,
  };
}
