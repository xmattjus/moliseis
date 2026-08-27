import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation.dart';
import 'package:moliseis/utils/result.dart';

// Interface isolates the Supabase transport from direct-upload lifecycle code.
// ignore: one_member_abstracts
abstract interface class CloudinaryUploadPreparationClient {
  Future<Result<CloudinaryUploadPreparation>> prepare({
    required String publicId,
    required CloudinaryUploadOptions options,
  });
}
