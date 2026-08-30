import 'package:objectbox/objectbox.dart';

/// Only one draft can be persisted locally.
const _draftId = 1;

@Entity()
class ContentSubmissionDraftEntity {
  ContentSubmissionDraftEntity({
    this.categoryIndex,
    this.city,
    this.name,
    this.description,
    this.descriptionDelta,
    this.startDate,
    this.endDate,
    this.isEvent,
    this.pendingStartCalendarDate,
    this.authorEmail,
    this.authorName,
    this.acceptedTerms,
  }) : id = _draftId;

  @Id(assignable: true)
  int id;

  final int? categoryIndex;

  final String? city;
  final String? name;
  final String? description;
  final List<Map<String, dynamic>>? descriptionDelta;

  @Property(type: PropertyType.dateNano)
  final DateTime? startDate;

  @Property(type: PropertyType.dateNano)
  final DateTime? endDate;

  final bool? isEvent;

  final String? pendingStartCalendarDate;

  final String? authorEmail;
  final String? authorName;

  final bool? acceptedTerms;
}
