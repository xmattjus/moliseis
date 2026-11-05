import 'dart:async' show unawaited;
import 'dart:io' show FileSystemException;

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

    final uploadDiagnostic = switch (event) {
      CloudinaryRequestStarted() ||
      CloudinaryRequestFailed() ||
      CloudinaryUploadCompleted() ||
      CloudinaryUploadCancelled() ||
      CloudinaryDuplicateDetected() ||
      ContentSubmissionUploadStarted() ||
      ContentSubmissionUploadFailed() ||
      ContentSubmissionConfirmed() ||
      ContentSubmissionReplayAcknowledged() ||
      AdminStagedAssetAssociated() => true,
      CommandExecutionFailed(:final debugName) => const {
        'content_submission_submit',
        'admin_submission_editor_save',
        'admin_submission_editor_add_asset',
      }.contains(debugName),
      AdminBackendRequestFailed(:final operation) =>
        operation == 'associateStagedAsset',
      _ => false,
    };
    // Only typed, bounded fields cross these diagnostic boundaries.
    final remoteData = event is SyncFailure || uploadDiagnostic
        ? event.data
        : mergedData;
    unawaited(_addBreadcrumb(event.name, remoteData, level));

    if (event is SyncFailure || uploadDiagnostic) {
      final report = switch (event) {
        SyncFailure() =>
          event.report && event.category != SyncFailureCategory.connectivity,
        CloudinaryRequestFailed() => error != null && event.report,
        CommandExecutionFailed() when error is FileSystemException => false,
        _ => error != null && level.index >= AppLogLevel.error.index,
      };
      if (report) {
        unawaited(
          Sentry.captureEvent(
            SentryEvent(
              exceptions: [
                SentryException(
                  type: event is SyncFailure
                      ? 'CanonicalSyncFailure'
                      : 'UploadDiagnosticFailure',
                  value: switch (event) {
                    SyncFailure() =>
                      '${event.owner.name}:${event.category.name}',
                    CloudinaryRequestFailed() =>
                      '${event.stage.name}:${event.category.name}',
                    ContentSubmissionUploadFailed() => event.outcome.name,
                    AdminBackendRequestFailed() =>
                      (event.outcome ?? AssociationOutcome.unconfirmed).name,
                    _ => event.name,
                  },
                ),
              ],
            ),
            withScope: (scope) async {
              // Ambient context may contain unrelated raw console or HTTP data.
              await scope.clear();
              for (final key in scope.contexts.keys.toList()) {
                await scope.removeContexts(key);
              }
            },
          ),
        );
      }
      return;
    }

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
  ) async => await Sentry.addBreadcrumb(
    Breadcrumb(
      message: message,
      data: data,
      level: mapToSentryLevel(level),
      type: 'log',
      category: 'app',
    ),
  );
}
