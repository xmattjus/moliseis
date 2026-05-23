import 'dart:async' show unawaited;

import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/app_log_level_mapper.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logger.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide logger that writes to Talker's console and optionally
/// reports events to Sentry.
class AppLogger implements Logger {
  /// Sentry integration is controlled by [sentryFlag] and only sends
  /// non-debug breadcrumbs. Error and critical events with an attached error
  /// are forwarded to Sentry as exceptions.
  AppLogger(
    this._talker, {
    required SentryLoggingFlag sentryFlag,
    this.minLevel = AppLogLevel.debug,
  }) : _sentryFlag = sentryFlag;

  final Talker _talker;

  /// The minimum [AppLogLevel] below which events are not logged while calling
  /// this instance [log] method.
  final AppLogLevel minLevel;

  final SentryLoggingFlag _sentryFlag;

  @override
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  }) {
    final level = event.level;

    if (level.index < minLevel.index) return;

    assert(
      eventNamePattern.hasMatch(event.name),
      'Invalid log event name: "${event.name}". '
      'Expected: <domain>_<action>_<result> (3+ segments, snake_case)',
    );

    final mergedData = _mergeData(event.data, extra);

    _talker.log(
      {event.name, mergedData},
      logLevel: mapToTalkerLevel(level),
      exception: error,
      stackTrace: stackTrace,
    );

    // Do not send logs to Sentry if it is not necessary.
    if (!_sentryFlag.enabled || level.index < AppLogLevel.info.index) return;

    unawaited(_addBreadcrumb(event.name, mergedData, level));

    if (error != null && level.index >= AppLogLevel.error.index) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }
  }

  Map<String, Object?> _mergeData(
    Map<String, Object?> base,
    Map<String, Object?>? extra,
  ) {
    if (extra == null) {
      return base;
    }

    return <String, Object?>{...base, ...extra};
  }

  Future<void> _addBreadcrumb(
    String message,
    Map<String, Object?> data,
    AppLogLevel level,
  ) async => Sentry.addBreadcrumb(
    Breadcrumb(
      message: message,
      data: data,
      level: mapToSentryLevel(level),
      type: 'log',
      category: 'app',
    ),
  );
}
