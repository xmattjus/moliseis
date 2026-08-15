import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/core/description_delta.dart';
import 'package:moliseis/domain/models/content_category.dart';

@immutable
class ContentSubmissionDraft {
  /// Creates a draft that retains a deeply copied, recursively unmodifiable
  /// snapshot of [descriptionDelta].
  ContentSubmissionDraft({
    this.category,
    this.city,
    this.name,
    this.description,
    List<Map<String, dynamic>>? descriptionDelta,
    this.startDate,
    this.endDate,
    this.userEmail,
    this.userName,
    this.acceptedTerms,
  }) : descriptionDelta = freezeDescriptionDelta(descriptionDelta);

  final ContentCategory? category;

  final String? city;
  final String? name;
  final String? description;
  final List<Map<String, dynamic>>? descriptionDelta;

  final DateTime? startDate;
  final DateTime? endDate;

  final String? userName;
  final String? userEmail;

  final bool? acceptedTerms;

  @override
  bool operator ==(Object other) {
    return other is ContentSubmissionDraft &&
        other.category == category &&
        other.city == city &&
        other.name == name &&
        other.description == description &&
        const DeepCollectionEquality().equals(
          other.descriptionDelta,
          descriptionDelta,
        ) &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.userEmail == userEmail &&
        other.userName == userName &&
        other.acceptedTerms == acceptedTerms;
  }

  @override
  int get hashCode => Object.hash(
    category,
    city,
    name,
    description,
    const DeepCollectionEquality().hash(descriptionDelta),
    startDate,
    endDate,
    userEmail,
    userName,
    acceptedTerms,
  );

  @override
  String toString() =>
      'ContentSubmissionDraft: category: $category, city: $city, '
      'name: $name, description (length): ${description?.length}, '
      'descriptionDelta (operation count): ${descriptionDelta?.length}, '
      'startDate: $startDate, endDate: $endDate, '
      'userEmail (length): ${userEmail?.length}, '
      'userName (length): ${userName?.length}, acceptedTerms: $acceptedTerms,';

  static const _unset = Object();

  ContentSubmissionDraft copyWith({
    Object? category = _unset,
    Object? city = _unset,
    Object? name = _unset,
    Object? description = _unset,
    Object? descriptionDelta = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? userEmail = _unset,
    Object? userName = _unset,
    Object? acceptedTerms = _unset,
  }) => ContentSubmissionDraft(
    category: identical(category, _unset)
        ? this.category
        : category as ContentCategory?,
    city: identical(city, _unset) ? this.city : city as String?,
    name: identical(name, _unset) ? this.name : name as String?,
    description: identical(description, _unset)
        ? this.description
        : description as String?,
    descriptionDelta: identical(descriptionDelta, _unset)
        ? this.descriptionDelta
        : descriptionDelta as List<Map<String, dynamic>>?,
    startDate: identical(startDate, _unset)
        ? this.startDate
        : startDate as DateTime?,
    endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
    userEmail: identical(userEmail, _unset)
        ? this.userEmail
        : userEmail as String?,
    userName: identical(userName, _unset) ? this.userName : userName as String?,
    acceptedTerms: identical(acceptedTerms, _unset)
        ? this.acceptedTerms
        : acceptedTerms as bool?,
  );
}
