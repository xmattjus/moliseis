import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ObjectBoxConditions {
  // Private constructor to prevent class instantiation.
  ObjectBoxConditions._();

  /// A [Condition] representing whether an event starts and ends in the current
  /// year or not.
  ///
  /// Multi-day events (non-null [Event_.endDate]) must both start on or after
  /// January 1st and end on or before December 31st 23:59:59.999. Single-day
  /// events (null [Event_.endDate]) are matched when their [Event_.startDate]
  /// falls within the same range.
  static Condition<Event> get eventStartsEndsCurrentYear {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year);
    final endOfYear = DateTime(now.year, 12, 31).endOfDay;

    final multiDay = Event_.startDate
        .greaterOrEqualDate(startOfYear)
        .and(Event_.endDate.lessOrEqualDate(endOfYear));

    // Single-day events have a null endDate; match them by startDate alone.
    final singleDay = Event_.endDate.isNull().and(
      Event_.startDate.betweenDate(startOfYear, endOfYear),
    );

    return multiDay.or(singleDay);
  }
}
