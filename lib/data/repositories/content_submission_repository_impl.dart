import 'dart:async';
import 'dart:io' show File;

import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/data/repositories/content_submission_api_exception.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry/sentry.dart';
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
  }) async {
    final transaction = Sentry.startTransaction(
      'content-submission',
      'upload',
      bindToScope: true,
    );

    var spanStatus = const SpanStatus.internalError();

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
      spanStatus = const SpanStatus.ok();
      return const Result.success(null);
    } on FunctionException catch (exception, stackTrace) {
      final normalized = _normalizeFunctionException(exception);
      _logger.log(
        const ContentSubmissionUploadFailed(),
        error: normalized,
        stackTrace: stackTrace,
      );
      spanStatus = const SpanStatus.internalError();
      return Result.error(normalized);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionUploadFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      spanStatus = const SpanStatus.internalError();
      return Result.error(exception);
    } finally {
      unawaited(transaction.finish(status: spanStatus));
    }
  }

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
