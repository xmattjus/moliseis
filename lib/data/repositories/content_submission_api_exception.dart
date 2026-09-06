/// A public Edge Function failure for Content Submission.
final class ContentSubmissionApiException implements Exception {
  /// Creates a normalized public Content Submission API failure.
  const ContentSubmissionApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  /// HTTP status returned by the Edge Function.
  final int statusCode;

  /// Optional non-empty backend error code.
  final String? code;

  /// Normalized public failure message.
  final String message;

  @override
  String toString() => 'ContentSubmissionApiException($statusCode, $message)';
}
