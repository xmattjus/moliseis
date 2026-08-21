import 'package:meta/meta.dart';

/// Persisted remote image metadata displayed read-only in the admin editor.
///
/// The backend schema also stores `mime_type` and `duration_seconds`, but
/// those fields are deferred to the backend round because the MVP only renders
/// images.
@immutable
class AdminSubmissionAsset {
  /// Creates read-only metadata for a persisted submission asset.
  const AdminSubmissionAsset({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
  });

  /// Persistent backend identifier for this asset.
  final int id;

  /// Remote URL used to render the asset.
  final String url;

  /// Rendered image width in pixels.
  final int width;

  /// Rendered image height in pixels.
  final int height;

  @override
  bool operator ==(Object other) {
    return other is AdminSubmissionAsset &&
        other.id == id &&
        other.url == url &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(id, url, width, height);
}
