/// Thrown when an upload is cancelled by the caller.
class UploadCancelledException implements Exception {
  /// Creates an upload-cancelled exception.
  const UploadCancelledException();

  @override
  String toString() => 'UploadCancelledException';
}
