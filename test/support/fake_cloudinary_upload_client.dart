import 'dart:io' show File;

import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';

/// Fail-fast Cloudinary dependency for final-submission repository tests.
final class FakeCloudinaryUploadClient implements CloudinaryUploadClient {
  @override
  ImageUploadTask uploadImageTask(
    File image, {
    CloudinaryUploadOptions options = const CloudinaryUploadOptions(),
  }) => throw UnsupportedError('Image upload is outside this test boundary.');

  @override
  void dispose() {}
}
