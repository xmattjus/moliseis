import 'dart:io' show File;

import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/utils/result.dart';

/// Owns durable local attachment descriptors for Content Submission drafts.
abstract interface class ContentSubmissionStagedAssetRepository {
  /// Repairs local state and returns assets for [activeClientSubmissionId].
  ///
  /// A `null` active identity removes all orphaned staged state.
  Future<Result<List<ContentSubmissionStagedAsset>>> reconcileAndLoad(
    String? activeClientSubmissionId,
  );

  /// Acquires [source] into [clientSubmissionId]'s staging directory.
  Future<Result<ContentSubmissionStagedAsset>> acquire({
    required String clientSubmissionId,
    required String digest,
    required File source,
  });

  /// Resolves [asset] to its validated final file beneath the staging root.
  Future<Result<File>> resolveAbsolutePath(ContentSubmissionStagedAsset asset);

  /// Removes one asset owned by [clientSubmissionId].
  Future<Result<void>> remove({
    required String clientSubmissionId,
    required String digest,
  });

  /// Idempotently removes all staged state for one draft identity.
  Future<Result<void>> clearSession(String clientSubmissionId);
}
