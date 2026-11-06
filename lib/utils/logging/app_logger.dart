import 'dart:async' show TimeoutException;
import 'dart:io' show FileSystemException, HttpException, SocketException;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show HttpExceptionWithStatus, UnsupportedImageFormatException;
import 'package:flutter/painting.dart' show NetworkImageLoadException;
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/app_log_level_mapper.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logger.dart';
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
        _capture(event, name, data, level, error, breadcrumb).ignore();
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
        final command = _known(event.debugName, const {
          'search_results',
          'search_suggestions',
          'geo_map_selection',
          'content_submission_submit',
          'admin_submission_editor_save',
          'admin_submission_editor_add_asset',
          'command',
        });
        final uploadCommand = const {
          'content_submission_submit',
          'admin_submission_editor_save',
          'admin_submission_editor_add_asset',
        }.contains(command);
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
      case EntityInsertFailed() || EntityRemoveFailed():
        final entity = switch (event) {
          EntityInsertFailed() => event.entityType,
          EntityRemoveFailed() => event.entityType,
          _ => null,
        };
        return (report: report, data: {'entityType': _repository(entity)});
      case EntityInsertSuccess() ||
          EntityDeleteSuccess() ||
          EntityUpdateSuccess():
        final entity = switch (event) {
          EntityInsertSuccess() => event.entityType,
          EntityDeleteSuccess() => event.entityType,
          EntityUpdateSuccess() => event.entityType,
          _ => null,
        };
        return (report: false, data: {'entityType': _repository(entity)});
      case RepositorySyncStarted() ||
          RepositorySyncFinished() ||
          RepositorySyncFailed():
        final repository = switch (event) {
          RepositorySyncStarted() => event.repositoryName,
          RepositorySyncFinished() => event.repositoryName,
          RepositorySyncFailed() => event.repositoryName,
          _ => null,
        };
        return (
          report: event is RepositorySyncFailed && report,
          data: {'repositoryName': _repository(repository)},
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
    Breadcrumb currentBreadcrumb,
  ) async {
    final causeType = _causeType(error);
    final upload =
        event is CloudinaryRequestFailed ||
        event is ContentSubmissionUploadFailed ||
        (event is AdminBackendRequestFailed &&
            event.operation == 'associateStagedAsset') ||
        (event is CommandExecutionFailed &&
            const {
              'content_submission_submit',
              'admin_submission_editor_save',
              'admin_submission_editor_add_asset',
            }.contains(event.debugName));
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
        ),
      ],
    );
    await Sentry.captureEvent(
      reportEvent,
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
      },
    );
  }

  /// Reprojects only current-run sync context, never ambient raw breadcrumbs.
  List<Breadcrumb> _syncBreadcrumbs(List<Breadcrumb> breadcrumbs) {
    final start = breadcrumbs.lastIndexWhere(
      (b) => b.category == 'app' && b.message == 'content_sync_started',
    );
    if (start < 0) return [];
    final approved = <Breadcrumb>[];
    for (final b in breadcrumbs.skip(start)) {
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

  String _repository(Object? value) =>
      _known(value, const {'city', 'place', 'event', 'media', 'search'});
  String _known(Object? value, Set<String> allowed) =>
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
