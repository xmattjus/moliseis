import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/core/description_delta.dart';
import 'package:moliseis/domain/models/content_category.dart';

@immutable
class ContentSubmission {
  /// Creates a submission that retains a deeply copied, recursively
  /// unmodifiable snapshot of [descriptionDelta].
  ContentSubmission({
    required this.city,
    required this.name,
    this.description,
    List<Map<String, dynamic>>? descriptionDelta,
    this.latitude,
    this.longitude,
    this.address,
    this.startDate,
    this.endDate,
    this.category,
    required this.userEmail,
    required this.userName,
    this.createdAt,
    this.modifiedAt,
  }) : descriptionDelta = freezeDescriptionDelta(descriptionDelta);

  final String city;

  final String name;

  final String? description;

  final List<Map<String, dynamic>>? descriptionDelta;

  final double? latitude;

  final double? longitude;

  final String? address;

  final DateTime? startDate;

  final DateTime? endDate;

  final ContentCategory? category;

  final String userEmail;

  final String userName;

  final DateTime? createdAt;

  final DateTime? modifiedAt;

  @override
  bool operator ==(Object other) {
    return other is ContentSubmission &&
        other.city == city &&
        other.name == name &&
        other.description == description &&
        const DeepCollectionEquality().equals(
          other.descriptionDelta,
          descriptionDelta,
        ) &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.category == category &&
        other.userEmail == userEmail &&
        other.userName == userName &&
        other.createdAt == createdAt &&
        other.modifiedAt == modifiedAt;
  }

  @override
  int get hashCode => Object.hash(
    city,
    name,
    description,
    const DeepCollectionEquality().hash(descriptionDelta),
    latitude,
    longitude,
    address,
    startDate,
    endDate,
    category,
    userEmail,
    userName,
    createdAt,
    modifiedAt,
  );
}
