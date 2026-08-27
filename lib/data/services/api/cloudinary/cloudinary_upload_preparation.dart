import 'package:moliseis/domain/models/submission_asset.dart';

sealed class CloudinaryUploadPreparation {
  const CloudinaryUploadPreparation();
}

final class CloudinaryAuthorizedUploadPreparation
    extends CloudinaryUploadPreparation {
  CloudinaryAuthorizedUploadPreparation(Map<String, String> fields)
    : fields = Map.unmodifiable(fields);

  final Map<String, String> fields;
}

final class CloudinaryDuplicateUploadPreparation
    extends CloudinaryUploadPreparation {
  const CloudinaryDuplicateUploadPreparation(this.asset);

  final SubmissionAsset asset;
}
