import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';

/// A handle to an in-flight image upload.
///
/// Provides the eventual [result] and a [progress] stream, and allows the
/// caller to [cancel] the upload at any time.
abstract interface class ImageUploadTask {
  /// The upload result, completing with the public CDN URL and other asset
  /// info on success.
  Future<Result<SubmissionAsset>> get result;

  /// Emits values in the range [0.0, 1.0] as bytes are uploaded.
  ///
  /// The stream is monotonically non-decreasing across retries: a restarted
  /// attempt never re-emits a value lower than the last one produced by a
  /// previous (possibly aborted) attempt.
  Stream<double> get progress;

  /// Cancels the upload as soon as possible.
  void cancel();
}
