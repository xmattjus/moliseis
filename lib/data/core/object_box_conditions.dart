import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ObjectBoxConditions {
  // Private constructor to prevent class instantiation.
  ObjectBoxConditions._();

  /// A [Condition] representing whether an event starts and ends in the current
  /// year or not.
  ///
  /// Multi-day events (non-null [EventEntity_.endDate]) must both start on or
  /// after January 1st and end on or before December 31st 23:59:59.999.
  /// Single-day events (null [EventEntity_.endDate]) are matched when their
  /// [EventEntity_.startDate] falls within the same range.
  static Condition<EventEntity> get eventStartsEndsCurrentYear {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year);
    final endOfYear = DateTime(now.year, 12, 31).endOfDay;

    final multiDay = EventEntity_.startDate
        .greaterOrEqualDate(startOfYear)
        .and(EventEntity_.endDate.lessOrEqualDate(endOfYear));

    // Single-day events have a null endDate; match them by startDate alone.
    final singleDay = EventEntity_.endDate.isNull().and(
      EventEntity_.startDate.betweenDate(startOfYear, endOfYear),
    );

    return multiDay.or(singleDay);
  }
}
