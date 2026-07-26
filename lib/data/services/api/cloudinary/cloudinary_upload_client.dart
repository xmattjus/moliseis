import 'dart:io' show File;

import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';

/// Uploads images to Cloudinary.
abstract interface class CloudinaryUploadClient {
  /// Uploads [image] and returns a task handle.
  ImageUploadTask uploadImageTask(
    File image, {
    CloudinaryUploadOptions options = const CloudinaryUploadOptions(),
  });

  /// Releases resources owned by this client.
  void dispose();
}
