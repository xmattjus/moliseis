import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/domain/models/content_category.dart';

part 'generated/content_submission_dto.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods:
      GenerateMethods.decode |
      GenerateMethods.encode |
      GenerateMethods.stringify,
  includeCustomMappers: [ContentCategoryMapper()],
)
class ContentSubmissionDto with ContentSubmissionDtoMappable {
  const ContentSubmissionDto({
    required this.city,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.address,
    this.startDate,
    this.endDate,
    this.category,
    required this.userEmail,
    required this.userName,
    required this.userId,
    this.createdAt,
    this.modifiedAt,
  });

  final String city;

  final String name;

  final String? description;

  final double? latitude;

  final double? longitude;

  final String? address;

  final DateTime? startDate;

  final DateTime? endDate;

  final ContentCategory? category;

  final String userEmail;

  final String userName;

  final String userId;

  final DateTime? createdAt;

  final DateTime? modifiedAt;
}
