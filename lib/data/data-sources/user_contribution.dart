import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_category.dart';

part 'generated/user_contribution.mapper.dart';

@immutable
@MappableClass(caseStyle: CaseStyle.snakeCase)
class UserContribution with UserContributionMappable {
  const UserContribution({
    this.id,
    this.type,
    this.city,
    this.place,
    this.description,
    this.startDate,
    this.endDate,
    this.media,
    this.authorEmail,
    this.authorName,
    this.createdAt,
    this.modifiedAt,
  });

  final int? id;

  final ContentCategory? type;

  final String? city;

  final String? place;

  final String? description;

  final DateTime? startDate;

  final DateTime? endDate;

  final List<String>? media;

  final String? authorEmail;

  final String? authorName;

  final DateTime? createdAt;

  final DateTime? modifiedAt;
}
