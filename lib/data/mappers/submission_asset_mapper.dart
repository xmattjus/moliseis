import 'package:moliseis/data/dtos/submission_asset_dto.dart';
import 'package:moliseis/domain/models/submission_asset.dart';

/// Conversion extensions from [SubmissionAsset] to [SubmissionAssetDto].
extension SubmissionAssetMapper on SubmissionAsset {
  SubmissionAssetDto toDto() => SubmissionAssetDto(
    url: secureUrl,
    width: width,
    height: height,
    mimeType: mimeType,
    durationSeconds: durationSeconds,
  );
}
