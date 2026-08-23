/// Derives an image MIME type from Cloudinary's optional format response.
String? cloudinaryImageMimeType(Object? format) {
  if (format is! String) return null;

  final normalizedFormat = format.trim().toLowerCase();
  return switch (normalizedFormat) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'avif' => 'image/avif',
    'bmp' => 'image/bmp',
    'tif' || 'tiff' => 'image/tiff',
    'svg' => 'image/svg+xml',
    _ => null,
  };
}
