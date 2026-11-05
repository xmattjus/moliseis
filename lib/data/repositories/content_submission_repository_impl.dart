import 'dart:io' show File;

import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/data/repositories/content_submission_api_exception.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client.dart';
import 'package:moliseis/data/services/api/supabase_functions_fetch_error.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/logging/run_traced_result.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentSubmissionRepositoryImpl implements ContentSubmissionRepository {
  ContentSubmissionRepositoryImpl({
    required Logger logger,
    required SupabaseClient supabaseClient,
    required CloudinaryUploadClient cloudinaryUploadClient,
  }) : _logger = logger,
       _supabaseClient = supabaseClient,
       _cloudinaryUploadClient = cloudinaryUploadClient;

  final Logger _logger;

  final SupabaseClient _supabaseClient;
  final CloudinaryUploadClient _cloudinaryUploadClient;

  @override
  Future<Result<void>> submit({
    required String clientSubmissionId,
    required ContentSubmission contentSubmission,
    required List<SubmissionAsset> submissionAssets,
  }) => runTracedResult('content-submission', () async {
    _logger.log(const ContentSubmissionUploadStarted());

    try {
      final response = await _supabaseClient.functions.invoke(
        'submit-content',
        body: contentSubmissionToWireMap(
          clientSubmissionId: clientSubmissionId,
          contentSubmission: contentSubmission,
          submissionAssets: submissionAssets,
        ),
      );
      final data = response.data;
      if (data is! Map || data['submission_id'] is! int) {
        throw const FormatException('submit-content response is invalid.');
      }
      if ((data['submission_id'] as int) <= 0) {
        throw const FormatException('submit-content response is invalid.');
      }
      if (data['replayed'] == true) {
        _logger.log(const ContentSubmissionReplayAcknowledged());
      } else {
        _logger.log(const ContentSubmissionConfirmed());
      }
      return const Result.success(null);
    } on FunctionsFetchException catch (exception, stackTrace) {
      final transportError = recoverSupabaseFunctionsFetchError(exception);
      _logger.log(
        const ContentSubmissionUploadFailed(),
        error: transportError,
        stackTrace: stackTrace,
      );
      return Result.error(transportError);
    } on FunctionException catch (exception, stackTrace) {
      final normalized = _normalizeFunctionException(exception);
      _logger.log(
        ContentSubmissionUploadFailed(
          outcome:
              const {
                (400, 'VALIDATION_ERROR'),
                (401, 'UNAUTHORIZED'),
                (405, 'METHOD_NOT_ALLOWED'),
                (429, 'RATE_LIMIT_EXCEEDED'),
              }.contains((normalized.statusCode, normalized.code))
              ? AssociationOutcome.rejected
              : AssociationOutcome.unconfirmed,
          statusCode: normalized.statusCode,
        ),
        error: normalized,
        stackTrace: stackTrace,
      );
      return Result.error(normalized);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionUploadFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  });

  ContentSubmissionApiException _normalizeFunctionException(
    FunctionException exception,
  ) {
    final details = exception.details;
    final mapDetails = details is Map ? details : null;
    final code = _nonEmptyString(mapDetails?['code']);
    final message =
        _nonEmptyString(mapDetails?['message']) ??
        (details is String ? _nonEmptyString(details) : null) ??
        _nonEmptyString(exception.reasonPhrase) ??
        'Content Submission request failed.';

    return ContentSubmissionApiException(
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

  @override
  ImageUploadTask uploadImageTask(File image) =>
      _cloudinaryUploadClient.uploadImageTask(image);

  @override
  void dispose() {
    _cloudinaryUploadClient.dispose();
  }
}
