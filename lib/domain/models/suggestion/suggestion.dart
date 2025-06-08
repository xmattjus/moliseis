import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';

@immutable
class Suggestion {
  const Suggestion({
    this.id,
    this.type,
    this.city,
    this.place,
    this.description,
    this.startDate,
    this.endDate,
    this.images,
    this.authorEmail,
    this.authorName,
    this.createdAt,
    this.modifiedAt,
  });

  final int? id;

  final AttractionType? type;

  final String? city;

  final String? place;

  final String? description;

  final DateTime? startDate;

  final DateTime? endDate;

  final List<String>? images;

  final String? authorEmail;

  final String? authorName;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'modified_at')
  final DateTime? modifiedAt;

  Suggestion copyWith({
    AttractionType? type,
    String? city,
    String? place,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? images,
    String? authorEmail,
    String? authorName,
  }) => Suggestion(
    id: id,
    type: type ?? this.type,
    city: city ?? this.city,
    place: place ?? this.place,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    images: images ?? this.images,
    authorEmail: authorEmail ?? this.authorEmail,
    authorName: authorName ?? this.authorName,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );

  @override
  String toString() =>
      'Suggestion Id: $id, '
      'Suggestion Type: $type, '
      'Suggestion City: $city, '
      'Suggestion Place: $place, '
      'Suggestion Description: $description, '
      'Suggestion Start Date: $startDate, '
      'Suggestion End Date: $endDate, '
      'Suggestion Images length: ${images?.length}, '
      'Suggestion Author Email: $authorEmail, '
      'Suggestion Author Name: $authorName';
}
