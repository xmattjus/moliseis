import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_category.dart';

@immutable
class ContentSubmissionDraft {
  const ContentSubmissionDraft({
    this.category,
    this.city,
    this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.userEmail,
    this.userName,
    this.acceptedTerms,
  });

  final ContentCategory? category;

  final String? city;
  final String? name;
  final String? description;

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
      'startDate: $startDate, endDate: $endDate, '
      'userEmail (length): ${userEmail?.length}, '
      'userName (length): ${userName?.length}, acceptedTerms: $acceptedTerms,';

  static const _unset = Object();

  ContentSubmissionDraft copyWith({
    Object? category = _unset,
    Object? city = _unset,
    Object? name = _unset,
    Object? description = _unset,
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
