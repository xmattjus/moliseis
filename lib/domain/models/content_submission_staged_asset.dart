import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

/// A locally staged asset owned by one durable content-submission draft.
@immutable
class ContentSubmissionStagedAsset {
  /// Creates a descriptor for a staged asset with validated ownership and path.
  ContentSubmissionStagedAsset({
    required this.clientSubmissionId,
    required this.digest,
    required this.relativePath,
  }) {
    if (!_isValidClientSubmissionId(clientSubmissionId)) {
      throw ArgumentError.value(
        clientSubmissionId,
        'clientSubmissionId',
        'must be a canonical UUID v4',
      );
    }
    if (!isValidDigest(digest)) {
      throw ArgumentError.value(
        digest,
        'digest',
        'must be a lowercase SHA-1 digest',
      );
    }
    if (!isValidRelativePath(relativePath, clientSubmissionId, digest)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must match the staged asset ownership and digest',
      );
    }
  }

  /// The UUID-v4 draft identity that owns this asset.
  final String clientSubmissionId;

  /// The lowercase SHA-1 digest that names the staged file.
  final String digest;

  /// The feature-root-relative final file path.
  final String relativePath;

  static final RegExp _sha1Pattern = RegExp(r'^[0-9a-f]{40}$');

  /// Whether [value] is a lowercase SHA-1 digest.
  static bool isValidDigest(String value) => _sha1Pattern.hasMatch(value);

  /// Whether [value] is the one permitted relative path for
  /// [clientSubmissionId] and [digest].
  static bool isValidRelativePath(
    String value,
    String clientSubmissionId,
    String digest,
  ) => value == '$clientSubmissionId/$digest';

  static bool _isValidClientSubmissionId(String value) =>
      ContentSubmissionDraft.isValidClientSubmissionId(value);

  @override
  bool operator ==(Object other) =>
      other is ContentSubmissionStagedAsset &&
      other.clientSubmissionId == clientSubmissionId &&
      other.digest == digest &&
      other.relativePath == relativePath;

  @override
  int get hashCode => Object.hash(clientSubmissionId, digest, relativePath);
}
