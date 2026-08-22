import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
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
  Future<Result<void>> changeStatus(int id, AdminSubmissionStatus status) {
    if (status == AdminSubmissionStatus.pending) {
      return Future<Result<void>>.value(
        Result.error(
          Exception('Only accepted or rejected statuses can be sent.'),
        ),
      );
    }

    return _invoke<void>(
      operation: 'changeStatus',
      body: <String, dynamic>{
        'operation': 'changeStatus',
        'submission_id': id,
        'status': status.name,
      },
      parse: (data) => _changeStatusFromEnvelope(data, status),
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

void _changeStatusFromEnvelope(
  Object? value,
  AdminSubmissionStatus requestedStatus,
) {
  final envelope = _object(value, 'changeStatus response');
  if (envelope['ok'] != true) {
    throw const FormatException('ok is invalid');
  }
  final status = adminSubmissionStatusFromWire(envelope['status']);
  if (status != requestedStatus) {
    throw const FormatException('status does not match request');
  }
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
