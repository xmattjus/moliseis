import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/generated/objectbox.g.dart';

class ObjectBoxConditions {
  // Private constructor to prevent class instantiation.
  ObjectBoxConditions._();

  /// A [Condition] for events that are visible and overlap the current
  /// Europe/Rome calendar year.
  ///
  /// The event must be visible — [EventEntity.isDeleted] equals `false`.
  ///
  /// Multi-day events (non-null [EventEntity_.endDate]) match when their
  /// interval overlaps the inclusive year range. Single-day events (null
  /// [EventEntity_.endDate]) are matched when their [EventEntity_.startDate]
  /// falls within the same range.
  static Condition<EventEntity> visibleEventInCurrentYear(
    DateTime nowUtc, {
    EventTimePolicy? policy,
  }) {
    final eventTimePolicy = policy ?? EventTimePolicy();
    final year = eventTimePolicy.currentCalendarDate(nowUtc.toUtc()).year;
    final startOfYear = eventTimePolicy
        .utcRangeForCalendarDate(EventCalendarDate(year, 1, 1))
        .startUtc;
    final endOfYear = eventTimePolicy
        .utcRangeForCalendarDate(EventCalendarDate(year, 12, 31))
        .endUtc;

    final multiDay = EventEntity_.startDate
        .lessOrEqualDate(endOfYear)
        .and(EventEntity_.endDate.greaterOrEqualDate(startOfYear));

    // Single-day events have a null endDate; match them by startDate alone.
    final singleDay = EventEntity_.endDate.isNull().and(
      EventEntity_.startDate.betweenDate(startOfYear, endOfYear),
    );

    return multiDay.or(singleDay).and(EventEntity_.isDeleted.equals(false));
  }
}
