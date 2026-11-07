import 'dart:async' show TimeoutException;
import 'dart:io' show FileSystemException, HttpException, SocketException;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show HttpExceptionWithStatus, UnsupportedImageFormatException;
import 'package:flutter/painting.dart' show NetworkImageLoadException;
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/app_log_level_mapper.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logger.dart';
import 'package:moliseis/utils/logging/safe_error_diagnostics.dart';
import 'package:moliseis/utils/logging/sync_failure_category.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Best-effort local diagnostics and explicitly owned, bounded remote reports.
class AppLogger implements Logger {
  AppLogger(
    this._talker, {
    required SentryLoggingFlag sentryFlag,
    this.minLevel = AppLogLevel.debug,
  }) : _sentryFlag = sentryFlag;

  static const _approvedReportKey = 'moliseis.approved_report';
  static const _uploadCommands = {
    'content_submission_submit',
    'admin_submission_editor_save',
    'admin_submission_editor_add_asset',
  };

  /// Restores approved app payloads and filters SDK-owned Dart errors.
  ///
  /// Wire this only at Sentry bootstrap. The private hint is never transmitted.
  static SentryEvent? beforeSend(SentryEvent event, Hint hint) {
    final approved = hint.get(_approvedReportKey);
    if (approved is! SentryEvent) return _automaticEvent(event, hint);
    return _restoreEvent(event, hint, approved);
  }

  static SentryEvent? _restoreEvent(
    SentryEvent event,
    Hint hint,
    SentryEvent approved, {
    String operation = 'app.report',
  }) {
    try {
      final os = event.contexts['os'];
      if (os is SentryOperatingSystem) {
        approved.contexts.operatingSystem = SentryOperatingSystem(
          name:
              const {
                'Android',
                'iOS',
                'Mac OS X',
                'macOS',
                'Windows',
                'Linux',
              }.contains(os.name)
              ? os.name
              : null,
          version: _technicalVersion(os.version),
        );
      }
      final app = event.contexts['app'];
      if (app is SentryApp) {
        approved.contexts.app = SentryApp(
          version: _technicalVersion(app.version),
          build: _technicalVersion(app.build),
        );
      }
      final trace = event.contexts.trace;
      if (trace != null) {
        approved.contexts.trace = SentryTraceContext(
          traceId: trace.traceId,
          spanId: trace.spanId,
          parentSpanId: trace.parentSpanId,
          replayId: trace.replayId,
          sampled: trace.sampled,
          status: trace.status,
          operation: operation,
        );
      }
      hint
        ..attachments.clear()
        ..screenshot = null
        ..viewHierarchy = null;
      return SentryEvent(
        eventId: event.eventId,
        timestamp: event.timestamp,
        sdk: event.sdk,
        platform: event.platform,
        release: event.release,
        dist: event.dist,
        environment: event.environment,
        level: approved.level,
        exceptions: approved.exceptions,
        threads: approved.threads,
        debugMeta: approved.debugMeta,
        contexts: approved.contexts,
        breadcrumbs: approved.breadcrumbs,
      );
    } on Object catch (_) {
      // Never let SDK fallback forward an unisolated app report.
      return null;
    }
  }

  /// Keeps automatic errors under SDK ownership with their own field policy.
  static SentryEvent _automaticEvent(SentryEvent event, Hint hint) {
    // shortcut: SDK scope bytes bypass this hook, review before adding any.
    hint
      ..attachments.clear()
      ..screenshot = null
      ..viewHierarchy = null;
    try {
      final exceptions = event.exceptions;
      final safe = SentryEvent(
        eventId: event.eventId,
        timestamp: event.timestamp,
        level: event.level,
        exceptions: exceptions == null || exceptions.isEmpty
            ? [SentryException(type: 'DartError', value: 'SDK error')]
            : exceptions.reversed
                  .take(16)
                  .toList()
                  .reversed
                  .map(safeAutomaticException)
                  .toList(),
        breadcrumbs: _syncBreadcrumbs(
          event.breadcrumbs ?? [],
          includeDatabase: true,
        ),
        debugMeta: safeAutomaticImages(event.debugMeta),
        threads: event.threads
            ?.take(32)
            .map(
              (thread) => SentryThread(
                id: thread.id,
                crashed: thread.crashed,
                current: thread.current,
                stacktrace: thread.stacktrace == null
                    ? null
                    : safeDiagnosticFrames(
                        thread.stacktrace!.frames,
                        allowNative: true,
                      ),
              ),
            )
            .toList(),
      );
      return _restoreEvent(event, hint, safe, operation: 'sdk.error') ?? safe;
    } on Object catch (_) {
      return _automaticFallback(event);
    }
  }

  /// A broken optional field must neither leak the input nor erase the error.
  static SentryEvent _automaticFallback(SentryEvent event) => SentryEvent(
    eventId: event.eventId,
    timestamp: event.timestamp,
    level: SentryLevel.error,
    exceptions: [
      SentryException(type: 'DartError', value: 'Diagnostic filtering failed'),
    ],
  );

  /// Accepts bounded version tokens, never arbitrary native descriptions.
  static String? _technicalVersion(String? value) =>
      value != null &&
          value.length <= 64 &&
          RegExp(r'^[0-9][0-9A-Za-z.+_-]*$').stringMatch(value) == value
      ? value
      : null;

  final Talker _talker;
  final SentryLoggingFlag _sentryFlag;

  /// Filters the complete logging operation, independently of consent.
  final AppLogLevel minLevel;

  @override
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  }) {
    final AppLogLevel level;
    final String name;
    try {
      level = event.level;
      if (level.index < minLevel.index) return;
      name = event.name;
      assert(eventNamePattern.hasMatch(name), 'Invalid log event name: $name');
    } on Object catch (_) {
      return;
    }

    var localData = <String, Object?>{};
    try {
      localData = {...event.data, ...?extra};
    } on Object catch (_) {
      // A broken metadata getter must not hide the original cause.
    }
    try {
      _talker.log(
        {name, localData},
        logLevel: mapToTalkerLevel(level),
        exception: error,
        stackTrace: stackTrace,
      );
    } on Object catch (_) {
      // Local output cannot revoke the independent remote attempt.
    }

    try {
      if (!_sentryFlag.enabled || level == AppLogLevel.debug) return;
      final diagnostic = _remoteDiagnostic(event, error);
      if (diagnostic == null) return;
      final data = diagnostic.data;
      final breadcrumb = Breadcrumb(
        message: name,
        data: data,
        level: mapToSentryLevel(level),
        type: 'log',
        category: 'app',
      );
      Sentry.addBreadcrumb(breadcrumb).ignore();
      if (diagnostic.report) {
        _capture(
          event,
          name,
          data,
          level,
          error,
          stackTrace,
          breadcrumb,
        ).ignore();
      }
    } on Object catch (_) {
      // Logging failures never replace business results or trigger reporting.
    }
  }

  /// Policy and approved projection live together; new event types stay local.
  ({bool report, Map<String, Object?> data})? _remoteDiagnostic(
    LogEvent event,
    Object? error,
  ) {
    final hasCause = error != null;
    final report =
        hasCause &&
        syncFailureCategory(error) != SyncFailureCategory.connectivity &&
        !(error is AuthRetryableFetchException && error.statusCode == null);
    switch (event) {
      case SyncFailure():
        return (
          report:
              event.report &&
              event.category != SyncFailureCategory.connectivity,
          data: {
            'owner': event.owner.name,
            'category': event.category.name,
            if (event.repository != null)
              'repository': _repository(event.repository),
          },
        );
      case SyncStarted() || SyncFinished() || SyncContentCommitSucceeded():
        return (report: false, data: event.data);
      case CloudinaryRequestFailed():
        return (
          report:
              hasCause &&
              event.category != CloudinaryFailureCategory.validation &&
              event.category != CloudinaryFailureCategory.fileRead,
          data: {
            'stage': event.stage.name,
            'category': event.category.name,
            if (_status(event.statusCode ?? _errorStatus(error))
                case final int status)
              'status_code': status,
          },
        );
      case CloudinaryUploadCompleted() ||
          CloudinaryUploadCancelled() ||
          ContentSubmissionUploadStarted() ||
          ContentSubmissionConfirmed() ||
          ContentSubmissionReplayAcknowledged() ||
          AdminStagedAssetAssociated():
        return (
          report: false,
          data: event is AdminStagedAssetAssociated
              ? {'outcome': event.replayed ? 'replayed' : 'confirmed'}
              : {},
        );
      case CloudinaryDuplicateDetected():
        return (report: false, data: {'source': event.source.name});
      case ContentSubmissionUploadFailed():
        return (
          report: hasCause,
          data: {
            'outcome': event.outcome.name,
            if (_status(event.statusCode) case final int status)
              'status_code': status,
          },
        );
      case AdminBackendRequestFailed():
        return (
          report: event.operation == 'associateStagedAsset' ? hasCause : report,
          data: {
            'operation': _known(event.operation, const {
              'list',
              'getById',
              'create',
              'update',
              'changeStatus',
              'promote',
              'eventCandidates',
              'mergePreview',
              'link',
              'apply',
              'listIgnoredSources',
              'unIgnoreSource',
              'addAsset',
              'associateStagedAsset',
              'deleteAsset',
            }),
            if (event.operation == 'associateStagedAsset') ...{
              'outcome': (event.outcome ?? AssociationOutcome.unconfirmed).name,
              if (_status(event.statusCode) case final int status)
                'status_code': status,
            },
          },
        );
      case CommandExecutionFailed():
        final command = safeCommandDebugName(event.debugName);
        final uploadCommand = _uploadCommands.contains(command);
        return (
          report: report && !(uploadCommand && error is FileSystemException),
          data: {'debugName': command},
        );
      case EntityLoadFailed():
        return (
          report: report,
          data: {
            'entityType': _repository(event.entityType),
            'method': _known(event.method, const {
              'getByEventId',
              'getByPlaceId',
              'getByCurrentYear',
              'getByCategories',
              'getByCoordinates',
              'getById',
              'getOngoingEvents',
              'getNextEvents',
              'getFavouriteEventIds',
              'getResultsByQuery',
              'getPastSearches',
              'getAll',
              'getLatest',
              'getFavouritePlaceIds',
              'getSuggestedPlaces',
              'getByDateRange',
              'getByDate',
            }),
          },
        );
      case EntityUpdateFailed():
        return (
          report: report,
          data: {
            'entityType': _repository(event.entityType),
            'method': _known(event.method, const {
              'setFavouriteEvent',
              'setFavouritePlace',
            }),
          },
        );
      case EntityInsertFailed(:final entityType) ||
          EntityRemoveFailed(:final entityType):
        return (report: report, data: {'entityType': _repository(entityType)});
      case EntityInsertSuccess(:final entityType) ||
          EntityDeleteSuccess(:final entityType) ||
          EntityUpdateSuccess(:final entityType):
        return (report: false, data: {'entityType': _repository(entityType)});
      case RepositorySyncStarted(:final repositoryName) ||
          RepositorySyncFinished(:final repositoryName) ||
          RepositorySyncFailed(:final repositoryName):
        return (
          report: event is RepositorySyncFailed && report,
          data: {'repositoryName': _repository(repositoryName)},
        );
      case ImageLoadFailed():
        return (
          report: false,
          data: {
            'cause_type': _causeType(error),
            if (_status(_errorStatus(error)) case final int status)
              'status_code': status,
          },
        );
      case RouteErrorScreenShown() ||
          WeatherForecastFetchFailed() ||
          ReverseGeocodingFetchFailed() ||
          LocalPersistenceInitFailed() ||
          LocalPersistenceSettingsInitFailed() ||
          ContentSubmissionDraftLoadFailed() ||
          ContentSubmissionDraftSaveFailed() ||
          ContentSubmissionDraftClearFailed() ||
          ContentSubmissionAssetAddFailed() ||
          ContentSubmissionAssetRemovalFailed() ||
          AdminAuthLoginFailed() ||
          AdminAuthLogoutFailed() ||
          AdminAuthStateError() ||
          SupabaseAuthAnonymousLoginFailed() ||
          UserIdFetchFailed():
        return (report: report, data: {});
      case NetworkRequestTimeout() ||
          SnackBarShowFailed() ||
          ImageSharingFailed() ||
          UrlLaunchFailed() ||
          ReverseGeocodingFetchStarted() ||
          AdminAuthLoginRejected() ||
          ContentSubmissionAssetSkippedTooLarge() ||
          ContentSubmissionAssetRetrievalFailed() ||
          ContentSubmissionAssetRetrievalStarted() ||
          ContentSubmissionDraftLoadStarted() ||
          ContentSubmissionDraftLoadSuccess() ||
          ContentSubmissionDraftSaveStarted() ||
          ContentSubmissionDraftSaveSuccess() ||
          ContentSubmissionDraftClearStarted() ||
          ContentSubmissionDraftClearSuccess() ||
          AdminLocalStorageFailed():
        return (report: false, data: {});
      default:
        return null;
    }
  }

  Future<void> _capture(
    LogEvent event,
    String name,
    Map<String, Object?> data,
    AppLogLevel level,
    Object? error,
    StackTrace? stackTrace,
    Breadcrumb currentBreadcrumb,
  ) async {
    final causeType = _causeType(error);
    final upload =
        event is CloudinaryRequestFailed ||
        event is ContentSubmissionUploadFailed ||
        (event is AdminBackendRequestFailed &&
            event.operation == 'associateStagedAsset') ||
        (event is CommandExecutionFailed &&
            _uploadCommands.contains(event.debugName));
    final diagnostic = {
      'event': name,
      ...data,
      'cause_type': causeType,
      if (error is PostgrestException)
        'backend_code': _known(error.code, const {
          'XX000',
          '42501',
          '23505',
          '22P02',
          'PGRST116',
          'PGRST301',
        }),
      if (_status(_errorStatus(error)) case final int status)
        'status_code': status,
    };
    final reportEvent = SentryEvent(
      level: mapToSentryLevel(level),
      contexts: Contexts()
        ..['app_diagnostic'] = diagnostic
        ..[upload ? 'upload_diagnostic' : 'failure_diagnostic'] = data,
      breadcrumbs: [currentBreadcrumb],
      exceptions: [
        SentryException(
          type: event is SyncFailure
              ? 'CanonicalSyncFailure'
              : upload
              ? 'UploadDiagnosticFailure'
              : 'ApplicationFailure',
          value: '$name:${data.values.join(':')}:$causeType',
          stackTrace: safeApplicationStack(stackTrace),
        ),
      ],
    );
    // Separate containers keep native enrichment out of the approved copy.
    final approvedReport = SentryEvent(
      level: reportEvent.level,
      exceptions: reportEvent.exceptions,
      breadcrumbs: reportEvent.breadcrumbs,
      contexts: Contexts()
        ..['app_diagnostic'] = diagnostic
        ..[upload ? 'upload_diagnostic' : 'failure_diagnostic'] = data,
    );
    final hint = Hint.withMap({_approvedReportKey: approvedReport});
    await Sentry.captureEvent(
      reportEvent,
      hint: hint,
      withScope: (scope) async {
        final previous = scope.breadcrumbs;
        await scope.clear();
        for (final key in scope.contexts.keys.toList()) {
          await scope.removeContexts(key);
        }
        reportEvent.breadcrumbs = [
          if (event is SyncFailure)
            ..._syncBreadcrumbs(
              previous.where((b) => !identical(b, currentBreadcrumb)).toList(),
            ),
          currentBreadcrumb,
        ];
        approvedReport.breadcrumbs = reportEvent.breadcrumbs;
      },
    );
  }

  /// Reprojects only current-run sync context, never ambient raw breadcrumbs.
  static List<Breadcrumb> _syncBreadcrumbs(
    List<Breadcrumb> breadcrumbs, {
    bool includeDatabase = false,
  }) {
    final start = breadcrumbs.lastIndexWhere(
      (b) => b.category == 'app' && b.message == 'content_sync_started',
    );
    if (start < 0 && !includeDatabase) return [];
    final approved = <Breadcrumb>[];
    for (
      var index = includeDatabase ? 0 : start;
      index < breadcrumbs.length;
      index++
    ) {
      final b = breadcrumbs[index];
      if (includeDatabase &&
          b.type == 'supabase' &&
          const {
            'cities',
            'places',
            'events',
            'media',
          }.contains(b.data?['table']) &&
          const {
            'select',
            'insert',
            'update',
            'upsert',
            'delete',
          }.contains(b.data?['operation'])) {
        approved.add(
          Breadcrumb(
            message: 'from(${b.data!['table']})',
            category: 'db.${b.data!['operation']}',
            type: 'supabase',
            timestamp: b.timestamp,
            data: {
              'table': b.data!['table'],
              'operation': b.data!['operation'],
            },
          ),
        );
        continue;
      }
      if (start < 0 || index < start) continue;
      if (b.category != 'app') continue;
      final data = b.data ?? {};
      final safe = switch (b.message) {
        'content_sync_started' => <String, Object?>{
          'mode': _known(data['mode'], const {'bootstrap', 'delta'}),
        },
        'content_commit_succeeded' => <String, Object?>{},
        'content_sync_failed' || 'content_sync_succeeded' => <String, Object?>{
          'mode': _known(data['mode'], const {'bootstrap', 'delta'}),
          'phase': _known(
            data['phase'],
            SyncPhase.values.map((phase) => phase.name).toSet(),
          ),
          if (data['category'] != null)
            'category': _known(
              data['category'],
              SyncFailureCategory.values
                  .map((category) => category.name)
                  .toSet(),
            ),
        },
        'repository_sync_started' => {
          'repositoryName': _repository(data['repositoryName']),
        },
        'content_sync_cause_failed' => {
          'owner': _known(data['owner'], const {
            'cursor',
            'prepare',
            'commit',
            'settings',
            'command',
          }),
          'category': _known(data['category'], const {
            'connectivity',
            'contract',
            'storage',
            'unexpected',
          }),
          if (data['repository'] != null)
            'repository': _repository(data['repository']),
        },
        _ => null,
      };
      if (safe != null) {
        approved.add(
          Breadcrumb(
            message: b.message,
            data: safe,
            timestamp: b.timestamp,
            category: 'app',
            type: 'log',
            level: b.level,
          ),
        );
      }
    }
    return approved;
  }

  static String _repository(Object? value) =>
      _known(value, const {'city', 'place', 'event', 'media', 'search'});
  static String _known(Object? value, Set<String> allowed) =>
      value is String && allowed.contains(value) ? value : 'other';
  int? _status(int? value) =>
      value != null && value >= 100 && value <= 599 ? value : null;
  int? _errorStatus(Object? error) => switch (error) {
    FunctionException() => error.status,
    PostgrestException() => int.tryParse(error.code ?? ''),
    AuthException() => int.tryParse(error.statusCode ?? ''),
    NetworkImageLoadException() => error.statusCode,
    HttpExceptionWithStatus() => error.statusCode,
    _ => null,
  };
  String _causeType(Object? error) => switch (error) {
    null => 'NoAttachedCause',
    FormatException() => 'FormatException',
    StateError() => 'StateError',
    TypeError() => 'TypeError',
    FileSystemException() => 'FileSystemException',
    NetworkImageLoadException() => 'NetworkImageLoadException',
    HttpExceptionWithStatus() => 'HttpExceptionWithStatus',
    UnsupportedImageFormatException() => 'UnsupportedImageFormatException',
    HttpException() => 'HttpException',
    TimeoutException() => 'TimeoutException',
    SocketException() => 'SocketException',
    FunctionException() => 'FunctionException',
    PostgrestException() => 'PostgrestException',
    AuthRetryableFetchException() => 'AuthRetryableFetchException',
    AuthException() => 'AuthException',
    Exception() => 'Exception',
    _ => 'UnexpectedObject',
  };
}
