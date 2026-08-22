/// A client-safe error returned by the admin content submissions Function.
final class AdminContentSubmissionApiException implements Exception {
  const AdminContentSubmissionApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() =>
      'AdminContentSubmissionApiException('
      'statusCode: $statusCode, code: $code, message: $message)';
}
