import 'package:meta/meta.dart';

@immutable
class SubmissionAsset {
  const SubmissionAsset({
    required this.secureUrl,
    required this.width,
    required this.height,
    this.mimeType,
    this.durationSeconds,
  });

  /// HTTPS URL of the uploaded asset.
  final String secureUrl;

  /// The width of the uploaded asset, which might not be equal to the
  /// original asset.
  final int width;

  /// The height of the uploaded asset, which might not be equal to the
  /// original asset.
  final int height;

  /// The mime type of the uploaded asset.
  final String? mimeType;

  /// Video assets duration in seconds. Equals null for pictures.
  final int? durationSeconds;

  @override
  bool operator ==(Object other) {
    return other is SubmissionAsset &&
        other.secureUrl == secureUrl &&
        other.width == width &&
        other.height == height &&
        other.mimeType == mimeType &&
        other.durationSeconds == durationSeconds;
  }

  @override
  int get hashCode => Object.hash(
    secureUrl,
    width,
    height,
    mimeType,
    durationSeconds,
  );
}
