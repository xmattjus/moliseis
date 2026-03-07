import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_category.dart';

@immutable
class UserContribution {
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

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'modified_at')
  final DateTime? modifiedAt;

  UserContribution copyWith({
    ContentCategory? type,
    String? city,
    String? place,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? media,
    String? authorEmail,
    String? authorName,
  }) => UserContribution(
    id: id,
    type: type ?? this.type,
    city: city ?? this.city,
    place: place ?? this.place,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    media: media ?? this.media,
    authorEmail: authorEmail ?? this.authorEmail,
    authorName: authorName ?? this.authorName,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );

  @override
  String toString() =>
      'UserContribution Id: $id, '
      'UserContribution Type: $type, '
      'UserContribution City: $city, '
      'UserContribution Place: $place, '
      'UserContribution Description: $description, '
      'UserContribution Start Date: $startDate, '
      'UserContribution End Date: $endDate, '
      'UserContribution Media length: ${media?.length}, '
      'UserContribution Author Email: $authorEmail, '
      'UserContribution Author Name: $authorName';
}
