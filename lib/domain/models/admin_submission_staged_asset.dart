import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';

/// A private, verified file belonging to one durable Admin owner.
@immutable
final class AdminSubmissionStagedAsset {
  /// Creates a descriptor whose path is canonical for its owner and digest.
  AdminSubmissionStagedAsset({
    required this.owner,
    required this.digest,
    required this.relativePath,
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
      relativePath == other.relativePath;

  @override
  int get hashCode => Object.hash(owner, digest, relativePath);
}
