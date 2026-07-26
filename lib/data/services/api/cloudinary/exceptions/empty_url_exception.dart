/// Thrown when Cloudinary returns a successful response with a missing or
/// invalid URL.
class EmptyUrlException implements Exception {
  /// Creates an empty-URL exception.
  const EmptyUrlException();

  @override
  String toString() => 'EmptyUrlException';
}
