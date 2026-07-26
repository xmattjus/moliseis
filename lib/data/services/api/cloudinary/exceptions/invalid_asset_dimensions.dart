/// Thrown when Cloudinary returns a successful response with an invalid width
/// or height.
class InvalidAssetDimensions implements Exception {
  /// Creates an invalid asset dimensions exception.
  const InvalidAssetDimensions();

  @override
  String toString() => 'InvalidAssetDimensions';
}
