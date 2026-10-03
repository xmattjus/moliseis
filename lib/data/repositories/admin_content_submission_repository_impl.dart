import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
import 'package:moliseis/data/mappers/submission_asset_mapper.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/data/services/api/supabase_functions_fetch_error.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edge Function implementation of the admin submissions repository.
final class AdminContentSubmissionRepositoryImpl
    implements AdminContentSubmissionRepository {
  AdminContentSubmissionRepositoryImpl({
    required Logger logger,
    required SupabaseClient supabaseClient,
  }) : _logger = logger,
       _supabaseClient = supabaseClient;

  static const _functionName = 'admin-content-submissions';

  final Logger _logger;
  final SupabaseClient _supabaseClient;

  @override
  Future<Result<List<AdminSubmission>>> list() {
    return _invoke(
      operation: 'list',
      body: <String, dynamic>{'operation': 'list'},
      parse: _listFromEnvelope,
    );
  }

  @override
  Future<Result<AdminSubmission>> getById(int id) {
    return _invoke(
      operation: 'getById',
      body: <String, dynamic>{'operation': 'getById', 'submission_id': id},
      parse: _submissionFromEnvelope,
    );
  }

  @override
  Future<Result<AdminSubmission>> create(AdminSubmissionInput input) {
    return _invoke(
      operation: 'create',
      body: <String, dynamic>{
        'operation': 'create',
        'input': adminSubmissionInputToWireMap(input),
      },
      parse: _submissionFromEnvelope,
    );
  }

  @override
  Future<Result<AdminSubmission>> update(int id, AdminSubmissionInput input) {
    return _invoke(
      operation: 'update',
      body: <String, dynamic>{
        'operation': 'update',
        'submission_id': id,
        'input': adminSubmissionInputToWireMap(input),
      },
      parse: _submissionFromEnvelope,
    );
  }

  @override
  Future<Result<AdminEventResolution>> reject(
    int id, {
    bool? ignoreSource,
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  }) {
    return _invoke(
      operation: 'changeStatus',
      body: <String, dynamic>{
        'operation': 'changeStatus',
        'submission_id': id,
        // Rejection is the only final transition this repository can express;
        // Acceptance uses the explicit promotion/link/apply operations.
        'status': AdminSubmissionStatus.rejected.name,
        'ignore_source': ?ignoreSource,
        ..._sourceAcknowledgement(acknowledgeCurrentSource, expectedSourceHash),
      },
      parse: _rejectFromEnvelope,
    );
  }

  @override
  Future<Result<AdminSubmissionPromotion>> promote(
    int id,
    AdminPromotionTarget target, {
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  }) {
    return _invoke(
      operation: 'promote',
      body: <String, dynamic>{
        'operation': 'promote',
        'submission_id': id,
        'target': target.name,
        ..._sourceAcknowledgement(acknowledgeCurrentSource, expectedSourceHash),
      },
      parse: _promotionFromEnvelope,
    );
  }

  @override
  Future<Result<AdminEventCandidates>> eventCandidates(
    int id, {
    String? searchName,
    int? targetEventId,
  }) => _invoke(
    operation: 'eventCandidates',
    body: {
      'operation': 'eventCandidates',
      'submission_id': id,
      'search_name': ?searchName,
      'target_event_id': ?targetEventId,
    },
    parse: (value) => adminEventCandidatesFromWire(
      _object(value, 'candidates response')['candidates'],
    ),
  );

  @override
  Future<Result<AdminEventMergePreview>> mergePreview(
    int id,
    int targetEventId,
  ) => _invoke(
    operation: 'mergePreview',
    body: {
      'operation': 'mergePreview',
      'submission_id': id,
      'target_event_id': targetEventId,
    },
    parse: (value) => adminEventMergePreviewFromWire(
      _object(value, 'preview response')['preview'],
    ),
  );

  @override
  Future<Result<AdminEventResolution>> link(
    int id,
    int targetEventId, {
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  }) => _invoke(
    operation: 'link',
    body: {
      'operation': 'link',
      'submission_id': id,
      'target_event_id': targetEventId,
      ..._sourceAcknowledgement(acknowledgeCurrentSource, expectedSourceHash),
    },
    parse: (value) => adminEventResolutionFromWire(
      _object(value, 'link response')['resolution'],
    ),
  );

  @override
  Future<Result<AdminEventResolution>> apply(
    int id,
    AdminEventMergePreview preview, {
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  }) => _invoke(
    operation: 'apply',
    body: {
      'operation': 'apply',
      'submission_id': id,
      'target_event_id': preview.targetEventId,
      'submission_version_token': preview.submissionVersionToken,
      'event_version_token': preview.eventVersionToken,
      ..._sourceAcknowledgement(acknowledgeCurrentSource, expectedSourceHash),
    },
    parse: (value) => adminEventResolutionFromWire(
      _object(value, 'apply response')['resolution'],
    ),
  );

  @override
  Future<Result<List<AdminIgnoredSource>>> listIgnoredSources() => _invoke(
    operation: 'listIgnoredSources',
    body: {'operation': 'listIgnoredSources'},
    parse: (value) {
      final sources = _object(value, 'ignored sources')['sources'];
      if (sources is! List) throw const FormatException('sources is invalid');
      return sources.map(adminIgnoredSourceFromWire).toList();
    },
  );

  @override
  Future<Result<AdminEventResolution>> unIgnoreSource(int recordId) => _invoke(
    operation: 'unIgnoreSource',
    body: {'operation': 'unIgnoreSource', 'external_event_record_id': recordId},
    parse: adminEventResolutionFromWire,
  );

  @override
  Future<Result<AdminSubmissionAsset>> addAsset(
    int submissionId,
    SubmissionAsset asset,
  ) {
    return _invoke(
      operation: 'addAsset',
      body: <String, dynamic>{
        'operation': 'addAsset',
        'submission_id': submissionId,
        'asset': asset.toDto().toMap(),
      },
      parse: _assetFromEnvelope,
    );
  }

  @override
  Future<Result<void>> deleteAsset(int submissionId, int assetId) {
    return _invoke<void>(
      operation: 'deleteAsset',
      body: <String, dynamic>{
        'operation': 'deleteAsset',
        'submission_id': submissionId,
        'asset_id': assetId,
      },
      parse: _deleteAssetFromEnvelope,
    );
  }

  Future<Result<T>> _invoke<T>({
    required String operation,
    required Map<String, dynamic> body,
    required T Function(Object? data) parse,
  }) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        _functionName,
        body: body,
      );
      return Result.success(parse(response.data));
    } on FunctionsFetchException catch (error, stackTrace) {
      final transportError = recoverSupabaseFunctionsFetchError(error);
      _logFailure(operation, transportError, stackTrace);
      return Result.error(transportError);
    } on FunctionException catch (error, stackTrace) {
      final normalized = _normalizeFunctionException(error);
      _logFailure(operation, normalized, stackTrace);
      return Result.error(normalized);
    } on Exception catch (error, stackTrace) {
      _logFailure(operation, error, stackTrace);
      return Result.error(error);
    }
  }

  void _logFailure(String operation, Exception error, StackTrace stackTrace) {
    _logger.log(
      AdminBackendRequestFailed(operation: operation),
      error: error,
      stackTrace: stackTrace,
    );
  }
}

AdminContentSubmissionApiException _normalizeFunctionException(
  FunctionException exception,
) {
  final details = exception.details;
  final mapDetails = details is Map ? details : null;
  final code = _nonEmptyString(mapDetails?['code']);
  final message =
      _nonEmptyString(mapDetails?['message']) ??
      (details is String ? _nonEmptyString(details) : null) ??
      _nonEmptyString(exception.reasonPhrase) ??
      'Admin content submission request failed.';

  return AdminContentSubmissionApiException(
    statusCode: exception.status,
    code: code,
    message: message,
  );
}

String? _nonEmptyString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

List<AdminSubmission> _listFromEnvelope(Object? value) {
  final envelope = _object(value, 'list response');
  final submissions = envelope['submissions'];
  if (submissions is! List) {
    throw const FormatException('submissions is invalid');
  }
  return submissions.map(adminSubmissionFromWire).toList(growable: false);
}

AdminSubmission _submissionFromEnvelope(Object? value) {
  final envelope = _object(value, 'submission response');
  return adminSubmissionFromWire(envelope['submission']);
}

AdminSubmissionAsset _assetFromEnvelope(Object? value) {
  final envelope = _object(value, 'add asset response');
  return adminSubmissionAssetFromWire(envelope['asset']);
}

void _deleteAssetFromEnvelope(Object? value) {
  final envelope = _object(value, 'delete asset response');
  if (envelope['ok'] != true) {
    throw const FormatException('ok is invalid');
  }
}

/// Requires the reject-only success contract of the changeStatus operation.
AdminEventResolution _rejectFromEnvelope(Object? value) {
  final envelope = _object(value, 'changeStatus response');
  if (envelope['ok'] != true) {
    throw const FormatException('ok is invalid');
  }
  if (adminSubmissionStatusFromWire(envelope['status']) !=
      AdminSubmissionStatus.rejected) {
    throw const FormatException('status does not match request');
  }
  final pending = envelope['pending_submission_id'];
  if (pending != null && (pending is! int || pending <= 0)) {
    throw const FormatException('pending_submission_id is invalid');
  }
  return AdminEventResolution(outcome: 'rejected', pendingId: pending as int?);
}

AdminSubmissionPromotion _promotionFromEnvelope(Object? value) {
  final envelope = _object(value, 'promotion response');
  return adminSubmissionPromotionFromWire(envelope['promotion']);
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map) {
    throw FormatException('$path must be an object');
  }

  final object = <String, dynamic>{};
  for (final MapEntry(:key, :value) in value.entries) {
    if (key is! String) {
      throw FormatException('$path has a non-string key');
    }
    object[key] = value;
  }
  return object;
}

Map<String, dynamic> _sourceAcknowledgement(bool? acknowledge, String? hash) =>
    {'acknowledge_current_source': ?acknowledge, 'expected_source_hash': ?hash};
