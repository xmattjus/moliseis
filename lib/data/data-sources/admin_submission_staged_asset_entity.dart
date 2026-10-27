import 'package:objectbox/objectbox.dart';

/// Independent descriptor commit for one account/session-owned private file.
@Entity()
class AdminSubmissionStagedAssetEntity {
  /// Creates a descriptor row; auto IDs define explicit acquisition order.
  AdminSubmissionStagedAssetEntity({
    required this.accountId,
    required this.sessionId,
    required this.submissionId,
    required this.digest,
    required this.relativePath,
    this.id = 0,
  });

  /// Technical order and identity, distinct from the session UUID.
  @Id()
  int id;

  /// Editing account, independent of the original remote contributor.
  final String accountId;

  /// Stable local UUID-v4 owner.
  final String sessionId;

  /// Null represents the genuine new-submission target.
  final int? submissionId;

  /// Lowercase SHA-1 accidental content key within this owner.
  final String digest;

  /// Canonical account/session/digest path relative to Admin staging.
  final String relativePath;
}
