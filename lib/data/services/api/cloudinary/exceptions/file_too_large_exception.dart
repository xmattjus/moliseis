/// Thrown when an image exceeds Cloudinary's maximum upload size and would be
/// rejected by the API with an HTTP 400 `"File size too large"` response.
///
/// Checked client-side before any bytes are transferred so the upload is
/// short-circuited without opening an HTTP connection.
class FileTooLargeException implements Exception {
  /// Creates a file-too-large exception.
  const FileTooLargeException({
    required this.actualBytes,
    required this.maxBytes,
  });

  /// The size of the rejected file, in bytes.
  final int actualBytes;

  /// The upload size limit, in bytes.
  final int maxBytes;

  @override
  String toString() =>
      'FileTooLargeException: file is $actualBytes bytes, '
      'maximum is $maxBytes bytes';
}
