import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/generated/objectbox.g.dart';

class ObjectBoxConditions {
  // Private constructor to prevent class instantiation.
  ObjectBoxConditions._();

  /// A [Condition] for events that are visible and happen entirely within the
  /// current year.
  ///
  /// The event must be visible — [EventEntity.isDeleted] equals `false`.
  ///
  /// Multi-day events (non-null [EventEntity_.endDate]) must both start on or
  /// after January 1st and end on or before December 31st 23:59:59.999.
  /// Single-day events (null [EventEntity_.endDate]) are matched when their
  /// [EventEntity_.startDate] falls within the same range.
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
        .greaterOrEqualDate(startOfYear)
        .and(EventEntity_.endDate.lessOrEqualDate(endOfYear));

    // Single-day events have a null endDate; match them by startDate alone.
    final singleDay = EventEntity_.endDate.isNull().and(
      EventEntity_.startDate.betweenDate(startOfYear, endOfYear),
    );

    return multiDay.or(singleDay).and(EventEntity_.isDeleted.equals(false));
  }
}
