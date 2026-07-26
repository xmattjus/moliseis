import 'package:dart_mappable/dart_mappable.dart';

part 'generated/submission_asset_dto.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods:
      GenerateMethods.decode |
      GenerateMethods.encode |
      GenerateMethods.stringify,
)
class SubmissionAssetDto with SubmissionAssetDtoMappable {
  const SubmissionAssetDto({
    required this.url,
    required this.width,
    required this.height,
    this.mimeType,
    this.durationSeconds,
  });

  final String url;

  final int width;

  final int height;

  final String? mimeType;

  final int? durationSeconds;
}
