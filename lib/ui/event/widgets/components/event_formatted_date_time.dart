import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Displays a localized date and time summary for an event.
///
/// This widget normalizes the event range and renders compact labels for
/// card and list surfaces where space is limited.
class EventFormattedDateTime extends StatefulWidget {
  /// Creates a date and time summary for the provided [event].
  const EventFormattedDateTime({
    required this.event,
    this.iconColor,
    this.textColor,
    super.key,
  });

  /// The event used to build the date and time labels.
  final Event event;

  /// Optional color for the calendar and clock icons.
  final Color? iconColor;

  /// Optional color for date and time text.
  final Color? textColor;

  @override
  State<EventFormattedDateTime> createState() => _EventFormattedDateTimeState();
}

class _EventFormattedDateTimeState extends State<EventFormattedDateTime> {
  Locale _currentLocale = const Locale('it', 'IT');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _currentLocale = Localizations.localeOf(context);
  }

  @override
  Widget build(BuildContext context) {
    var startInstant = widget.event.startDate;
    var endInstant = widget.event.endDate ?? widget.event.startDate;

    final color = widget.iconColor ?? context.colorScheme.primary;

    final textStyle = AppTextStyles.subtitle(
      context,
    )?.copyWith(color: widget.textColor);

    // Normalize the event range to ensure startDate is before endDate.
    if (startInstant.isAfter(endInstant)) {
      final temp = startInstant;
      startInstant = endInstant;
      endInstant = temp;
    }

    final policy = EventTimePolicy();
    final startCalendar = policy.calendarDateForUtc(startInstant);
    final endCalendar = policy.calendarDateForUtc(endInstant);
    final startClock = policy.clockTimeForUtc(startInstant);
    final startDate = DateTime.utc(
      startCalendar.year,
      startCalendar.month,
      startCalendar.day,
      startClock.hour,
      startClock.minute,
    );
    final endDate = DateTime.utc(
      endCalendar.year,
      endCalendar.month,
      endCalendar.day,
    );

    // Whether the event spans multiple years or not.
    final isMultipleYears = endDate.year != startDate.year;

    // Whether the event spans multiple months or not.
    final isMultipleMonths =
        isMultipleYears || endDate.month != startDate.month;

    // Whether the event spans multiple days or not.
    final isMultipleDays = isMultipleMonths || endDate.day != startDate.day;

    var startMonth = startDate.localizeMonth(_currentLocale);
    String? endMonth;

    if (isMultipleMonths) {
      endMonth = endDate.localizeMonth(_currentLocale);
    }

    if (isMultipleYears) {
      startMonth = '$startMonth ${startDate.year}';
      endMonth = '$endMonth ${endDate.year}';
    }

    var date = '';

    if (isMultipleDays) {
      if (isMultipleMonths) {
        date = '${startDate.day} $startMonth - ${endDate.day} $endMonth';
      } else {
        date = '${startDate.day} - ${endDate.day} $startMonth';
      }
    } else {
      date = '${startDate.day} $startMonth';
    }

    final force24HourFormat =
        MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false;

    final startTime = isMultipleDays
        ? null
        : startDate.formatTime(
            _currentLocale,
            alwaysUse24HourFormat: force24HourFormat,
          );

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runAlignment: WrapAlignment.end,
      runSpacing: 4,
      children: [
        Icon(Symbols.calendar_month, size: 18, color: color),
        Text(
          date,
          style: textStyle,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
        if (startTime != null) const SizedBox(width: 4),
        if (startTime != null) Icon(Symbols.schedule, size: 18, color: color),
        if (startTime != null)
          Text(
            startTime,
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
      ],
    );
  }
}
