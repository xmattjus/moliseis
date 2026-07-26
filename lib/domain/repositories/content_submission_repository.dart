import 'dart:io' show File;

import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';

abstract interface class ContentSubmissionRepository {
  Future<Result<void>> upload(
    ContentSubmission contentSubmission,
    List<SubmissionAsset> submissionAssets,
  );

  ImageUploadTask uploadImageTask(File image);

  /// Releases resources owned by this repository.
  void dispose();
}
