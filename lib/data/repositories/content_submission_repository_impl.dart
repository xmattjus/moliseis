import 'dart:async';
import 'dart:io' show File;

import 'package:moliseis/data/mappers/mappers.dart';
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
    required Supabase supabase,
    required CloudinaryUploadClient cloudinaryUploadClient,
  }) : _logger = logger,
       _supabase = supabase,
       _cloudinaryUploadClient = cloudinaryUploadClient;

  final Logger _logger;

  final Supabase _supabase;
  final CloudinaryUploadClient _cloudinaryUploadClient;

  @override
  Future<Result<void>> upload(
    ContentSubmission contentSubmission,
    List<SubmissionAsset> submissionAssets,
  ) async {
    final transaction = Sentry.startTransaction(
      'content-submission',
      'upload',
      bindToScope: true,
    );

    var spanStatus = const SpanStatus.internalError();

    _logger.log(const ContentSubmissionUploadStarted());

    try {
      final userId = _supabase.client.auth.currentUser?.id;

      if (userId == null) {
        final exception = Exception(const UserIdFetchFailed());
        _logger.log(
          const ContentSubmissionUploadFailed(),
          error: exception,
        );
        spanStatus = const SpanStatus.internalError();
        return Result.error(exception);
      }

      final submission = contentSubmission.toDto(userId: userId).toMap();

      final assets = submissionAssets
          .map((asset) => asset.toDto().toMap())
          .toList();

      final payload = {
        ...submission,
        'assets': assets,
      };

      await _supabase.client.functions.invoke(
        'submit-content',
        body: payload,
      );
      spanStatus = const SpanStatus.ok();
      return const Result.success(null);
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

  @override
  ImageUploadTask uploadImageTask(File image) =>
      _cloudinaryUploadClient.uploadImageTask(image);

  @override
  void dispose() {
    _cloudinaryUploadClient.dispose();
  }
}
