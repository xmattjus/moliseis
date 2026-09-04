import 'package:objectbox/objectbox.dart';

/// ObjectBox descriptor for one Content Submission staged asset.
@Entity()
class ContentSubmissionStagedAssetEntity {
  ContentSubmissionStagedAssetEntity({
    required this.clientSubmissionId,
    required this.digest,
    required this.relativePath,
    this.id = 0,
  });

  /// Auto-increment technical persistence identity used for stable ordering.
  @Id()
  int id;

  final String clientSubmissionId;
  final String digest;
  final String relativePath;
}
