import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';

/// Validates untrusted persisted descriptors before exposing domain ownership.
extension AdminSubmissionStagedAssetEntityMapper
    on AdminSubmissionStagedAssetEntity {
  /// Returns null for malformed ownership, digest or relative paths.
  AdminSubmissionStagedAsset? toModel() {
    if (!AdminDraftOwner.isValidAccountId(accountId) ||
        !AdminDraftOwner.isValidSessionId(sessionId) ||
        (submissionId != null && submissionId! <= 0) ||
        !AdminSubmissionStagedAsset.isValidDigest(digest)) {
      return null;
    }
    final owner = AdminDraftOwner(
      accountId: accountId,
      sessionId: sessionId,
      submissionId: submissionId,
    );
    if (!AdminSubmissionStagedAsset.isValidRelativePath(
      relativePath,
      owner,
      digest,
    )) {
      return null;
    }
    return AdminSubmissionStagedAsset(
      owner: owner,
      digest: digest,
      relativePath: relativePath,
    );
  }
}

/// Converts validated descriptors without changing ownership or paths.
extension AdminSubmissionStagedAssetMapper on AdminSubmissionStagedAsset {
  /// Creates an auto-ordered new descriptor row.
  AdminSubmissionStagedAssetEntity toEntity() =>
      AdminSubmissionStagedAssetEntity(
        accountId: owner.accountId,
        sessionId: owner.sessionId,
        submissionId: owner.submissionId,
        digest: digest,
        relativePath: relativePath,
      );
}
