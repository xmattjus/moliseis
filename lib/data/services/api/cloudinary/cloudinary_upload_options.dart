/// Options controlling a single Cloudinary upload.
class CloudinaryUploadOptions {
  /// Creates upload options.
  const CloudinaryUploadOptions({
    this.publicId,
    this.tags = const [],
    this.context = const {},
    this.maxWidth = 2048,
    this.maxHeight = 2048,
    this.overwrite = false,
  });

  /// Optional explicit public ID. When omitted, a SHA-256 based ID is used.
  final String? publicId;

  /// Tags to attach to the uploaded asset.
  final List<String> tags;

  /// Structured metadata context key-value pairs.
  final Map<String, String> context;

  /// Maximum width for the uploaded image (incoming transformation).
  /// Defaults to 2048 px.
  final int? maxWidth;

  /// Maximum height for the uploaded image (incoming transformation).
  /// Defaults to 2048 px.
  final int? maxHeight;

  /// Whether to overwrite an existing asset with the same public ID.
  final bool overwrite;
}
