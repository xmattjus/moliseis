import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/domain/core/description_delta.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

extension ContentSubmissionDraftEntityMapper on ContentSubmissionDraftEntity {
  ContentSubmissionDraft toModel() => ContentSubmissionDraft(
    category: categoryIndex != null
        ? contentCategoryFromIndex(categoryIndex!)
        : null,
    city: city,
    name: name,
    description: description,
    descriptionDelta: freezeDescriptionDelta(descriptionDelta),
    eventDates: _eventDatesFromEntity(),
    userEmail: authorEmail,
    userName: authorName,
    acceptedTerms: acceptedTerms,
  );
}

extension on ContentSubmissionDraftEntity {
  EventDateDraft _eventDatesFromEntity() {
    final start = startDate?.toUtc();
    final end = endDate?.toUtc();
    final pending = pendingStartCalendarDate;
    if (isEvent != true) {
      if (start != null || end != null || pending != null) {
        throw StateError(
          'Persisted content-submission draft has invalid dates.',
        );
      }
      return const EventDateDraft.disabled();
    }

    if (start != null) {
      return EventDateDraft.exact(
        startCalendarDate: EventTimePolicy().calendarDateForUtc(start),
        startInstantUtc: start,
        endInstantUtc: end,
      );
    }
    if (end != null) {
      throw StateError(
        'Persisted content-submission draft has an end date without a '
        'start date.',
      );
    }

    if (pending == null) return const EventDateDraft.enabledEmpty();
    final date = _parseCalendarDate(pending);
    if (date == null) {
      throw StateError(
        'Persisted content-submission draft has an invalid pending start date.',
      );
    }
    return EventDateDraft.unresolvedStart(date);
  }

  EventCalendarDate? _parseCalendarDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      return null;
    }
    return EventCalendarDate(year, month, day);
  }
}

extension ContentSubmissionDraftMapper on ContentSubmissionDraft {
  ContentSubmissionDraftEntity toEntity() => ContentSubmissionDraftEntity(
    categoryIndex: category?.index,
    city: city,
    name: name,
    description: description,
    descriptionDelta: freezeDescriptionDelta(descriptionDelta),
    startDate: eventDates.startInstantUtc?.toUtc(),
    endDate: eventDates.endInstantUtc?.toUtc(),
    isEvent: eventDates.enabled,
    pendingStartCalendarDate:
        eventDates.enabled && eventDates.startInstantUtc == null
        ? eventDates.startCalendarDate?.toString()
        : null,
    authorEmail: userEmail,
    authorName: userName,
    acceptedTerms: acceptedTerms,
  );
}
