import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';

extension ContentSubmissionStagedAssetEntityMapper
    on ContentSubmissionStagedAssetEntity {
  /// Converts only a structurally safe persisted descriptor to its model.
  ContentSubmissionStagedAsset? toModel() {
    if (!ContentSubmissionDraft.isValidClientSubmissionId(clientSubmissionId) ||
        !ContentSubmissionStagedAsset.isValidDigest(digest) ||
        !ContentSubmissionStagedAsset.isValidRelativePath(
          relativePath,
          clientSubmissionId,
          digest,
        )) {
      return null;
    }

    return ContentSubmissionStagedAsset(
      clientSubmissionId: clientSubmissionId,
      digest: digest,
      relativePath: relativePath,
    );
  }
}

extension ContentSubmissionStagedAssetMapper on ContentSubmissionStagedAsset {
  /// Converts the validated domain descriptor to its ObjectBox representation.
  ContentSubmissionStagedAssetEntity toEntity() =>
      ContentSubmissionStagedAssetEntity(
        clientSubmissionId: clientSubmissionId,
        digest: digest,
        relativePath: relativePath,
      );
}
