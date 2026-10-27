import 'dart:convert';

import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';

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
    AdminStagedAssetProgress? progress;
    var progressInvalid = false;
    try {
      progress = _decodeProgress(progressPayload, owner, digest);
    } on FormatException {
      progressInvalid = true;
    }
    return AdminSubmissionStagedAsset(
      owner: owner,
      digest: digest,
      relativePath: relativePath,
      progress: progress,
      progressInvalid: progressInvalid,
    );
  }
}

/// Converts validated descriptors without changing ownership or paths.
extension AdminSubmissionStagedAssetMapper on AdminSubmissionStagedAsset {
  /// Creates an auto-ordered new descriptor row.
  AdminSubmissionStagedAssetEntity toEntity({int id = 0}) =>
      AdminSubmissionStagedAssetEntity(
        id: id,
        progressPayload: _encodeProgress(this),
        accountId: owner.accountId,
        sessionId: owner.sessionId,
        submissionId: owner.submissionId,
        digest: digest,
        relativePath: relativePath,
      );
}

String? _encodeProgress(AdminSubmissionStagedAsset asset) {
  if (asset.progressInvalid) {
    throw const FormatException('Unreadable receipt cannot be rewritten.');
  }
  final progress = asset.progress;
  if (progress == null) return null;
  if (asset.owner.submissionId == null) {
    throw const FormatException('Uploaded receipt requires adopted target.');
  }
  return jsonEncode({
    'version': 1,
    'accountId': asset.owner.accountId,
    'sessionId': asset.owner.sessionId,
    'submissionId': asset.owner.submissionId,
    'digest': asset.digest,
    'url': progress.upload.secureUrl,
    'width': progress.upload.width,
    'height': progress.upload.height,
    'mimeType': progress.upload.mimeType,
    'durationSeconds': progress.upload.durationSeconds,
    'associationId': progress.associationId,
  });
}

AdminStagedAssetProgress? _decodeProgress(
  String? payload,
  AdminDraftOwner owner,
  String digest,
) {
  if (payload == null) return null;
  final data = jsonDecode(payload);
  if (data is! Map<String, dynamic> ||
      data['version'] != 1 ||
      data['accountId'] != owner.accountId ||
      data['sessionId'] != owner.sessionId ||
      data['submissionId'] != owner.submissionId ||
      owner.submissionId == null ||
      data['digest'] != digest ||
      data['url'] is! String ||
      data['width'] is! int ||
      data['height'] is! int ||
      (data['mimeType'] != null && data['mimeType'] is! String) ||
      (data['durationSeconds'] != null && data['durationSeconds'] is! int) ||
      (data['associationId'] != null && data['associationId'] is! int)) {
    throw const FormatException('Invalid staged receipt.');
  }
  final uri = Uri.tryParse(data['url'] as String);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      (data['width'] as int) <= 0 ||
      (data['height'] as int) <= 0 ||
      (data['associationId'] != null && (data['associationId'] as int) <= 0)) {
    throw const FormatException('Invalid staged receipt.');
  }
  return AdminStagedAssetProgress(
    upload: SubmissionAsset(
      secureUrl: data['url'] as String,
      width: data['width'] as int,
      height: data['height'] as int,
      mimeType: data['mimeType'] as String?,
      durationSeconds: data['durationSeconds'] as int?,
    ),
    associationId: data['associationId'] as int?,
  );
}
