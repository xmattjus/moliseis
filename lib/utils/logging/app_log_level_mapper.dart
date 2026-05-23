import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Maps [AppLogLevel] to [LogLevel] for Talker's console output.
LogLevel mapToTalkerLevel(AppLogLevel level) => switch (level) {
  AppLogLevel.debug => LogLevel.debug,
  AppLogLevel.info => LogLevel.info,
  AppLogLevel.warning => LogLevel.warning,
  AppLogLevel.error => LogLevel.error,
  AppLogLevel.critical => LogLevel.critical,
};

/// Maps [AppLogLevel] to [SentryLevel] for breadcrumbs and crash reports.
SentryLevel mapToSentryLevel(AppLogLevel level) => switch (level) {
  AppLogLevel.debug => SentryLevel.debug,
  AppLogLevel.info => SentryLevel.info,
  AppLogLevel.warning => SentryLevel.warning,
  AppLogLevel.error => SentryLevel.error,
  AppLogLevel.critical => SentryLevel.fatal,
};
