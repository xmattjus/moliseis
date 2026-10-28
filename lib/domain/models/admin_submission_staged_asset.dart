import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/submission_asset.dart';

/// A private, verified file belonging to one durable Admin owner.
@immutable
final class AdminSubmissionStagedAsset {
  /// Creates a descriptor whose path is canonical for its owner and digest.
  AdminSubmissionStagedAsset({
    required this.owner,
    required this.digest,
    required this.relativePath,
    this.progress,
    this.progressInvalid = false,
  }) {
    if (!isValidDigest(digest) ||
        !isValidRelativePath(relativePath, owner, digest)) {
      throw ArgumentError('Invalid Admin staged descriptor.');
    }
  }

  /// The account/session/target that must remain durable for recovery.
  final AdminDraftOwner owner;

  /// Lowercase SHA-1 used for accidental content deduplication only.
  final String digest;

  /// Path relative to the private Admin staging root.
  final String relativePath;

  /// Confirmed upload and, separately, confirmed database association.
  final AdminStagedAssetProgress? progress;

  /// Valid bytes with unreadable receipt must not be blindly uploaded again.
  final bool progressInvalid;

  /// Whether a digest has the established SHA-1 representation.
  static bool isValidDigest(String digest) =>
      RegExp(r'^[0-9a-f]{40}$').hasMatch(digest);

  /// Whether the path is the single canonical path for this descriptor.
  static bool isValidRelativePath(
    String path,
    AdminDraftOwner owner,
    String digest,
  ) => path == '${owner.accountId}/${owner.sessionId}/$digest';

  @override
  bool operator ==(Object other) =>
      other is AdminSubmissionStagedAsset &&
      owner == other.owner &&
      digest == other.digest &&
      relativePath == other.relativePath &&
      progress == other.progress &&
      progressInvalid == other.progressInvalid;

  @override
  int get hashCode =>
      Object.hash(owner, digest, relativePath, progress, progressInvalid);
}

/// Confirmed remote progress, stored separately from the private file path.
@immutable
final class AdminStagedAssetProgress {
  /// Requires an HTTPS upload receipt and a positive optional association ID.
  AdminStagedAssetProgress({required this.upload, this.associationId}) {
    final uri = Uri.tryParse(upload.secureUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        upload.width <= 0 ||
        upload.height <= 0 ||
        (associationId != null && associationId! <= 0)) {
      throw ArgumentError('Invalid staged upload receipt.');
    }
  }

  /// Confirmed Cloudinary response, independent of database association.
  final SubmissionAsset upload;

  /// Confirmed database row, absent until association is acknowledged.
  final int? associationId;

  @override
  bool operator ==(Object other) =>
      other is AdminStagedAssetProgress &&
      upload == other.upload &&
      associationId == other.associationId;

  @override
  int get hashCode => Object.hash(upload, associationId);
}
