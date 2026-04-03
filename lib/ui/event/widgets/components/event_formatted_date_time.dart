import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Displays a localized date and time summary for an event.
///
/// This widget normalizes the event range and renders compact labels for
/// card and list surfaces where space is limited.
class EventFormattedDateTime extends StatefulWidget {
  /// Creates a date and time summary for the provided [event].
  const EventFormattedDateTime({
    super.key,
    required this.event,
    this.iconColor,
    this.textColor,
  });

  /// The event used to build the date and time labels.
  final EventContent event;

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

  String _localizeMonth(DateTime date) {
    final dateSymbols = intl.DateFormat.MMMM(_currentLocale.toLanguageTag());
    return dateSymbols.format(date);
  }

  String _localizeTimeOfDay(DateTime date, bool alwaysUse24HourFormat) {
    // intl.DateFormat.jm localizes the time format based on the locale (e.g., 5:08 PM or 17:08).
    final timeFormat = alwaysUse24HourFormat
        ? intl.DateFormat.Hm(_currentLocale.toLanguageTag())
        : intl.DateFormat.jm(_currentLocale.toLanguageTag());
    return timeFormat.format(date);
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = widget.event.startDate;
    DateTime endDate = widget.event.endDate ?? widget.event.startDate;

    final color = widget.iconColor ?? context.colorScheme.primary;

    final textStyle = AppTextStyles.subtitle(
      context,
    )?.copyWith(color: widget.textColor);

    // Normalize the event range to ensure startDate is before endDate.
    if (startDate.isAfter(endDate)) {
      final temp = startDate;
      startDate = endDate;
      endDate = temp;
    }

    // Whether the event spans multiple years or not.
    final isMultipleYears = endDate.year != startDate.year;

    // Whether the event spans multiple months or not.
    final isMultipleMonths =
        isMultipleYears || endDate.month != startDate.month;

    // Whether the event spans multiple days or not.
    final isMultipleDays = isMultipleMonths || endDate.day != startDate.day;

    // Whether the event start and end times are the same instant or not.
    final isMultipleHours =
        isMultipleDays ||
        endDate.hour != startDate.hour ||
        endDate.minute != startDate.minute;

    String startMonth = _localizeMonth(startDate);
    String? endMonth;

    if (isMultipleMonths) {
      endMonth = _localizeMonth(endDate);
    }

    if (isMultipleYears) {
      startMonth = "$startMonth ${startDate.year}";
      endMonth = "$endMonth ${endDate.year}";
    }

    String date = "";

    if (isMultipleDays) {
      if (isMultipleMonths) {
        date = "${startDate.day} $startMonth - ${endDate.day} $endMonth";
      } else {
        date = "${startDate.day} - ${endDate.day} $startMonth";
      }
    } else {
      date = "${startDate.day} $startMonth";
    }

    final alwaysUse24HourFormat =
        MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false;

    String time = _localizeTimeOfDay(startDate, alwaysUse24HourFormat);

    if (isMultipleHours) {
      time += " - ${_localizeTimeOfDay(endDate, alwaysUse24HourFormat)}";
    }

    return Flex(
      direction: Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: <Widget>[
        Icon(Symbols.calendar_month, size: 18.0, color: color),
        Flexible(
          flex: 2,
          child: Text(
            date,
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
        const SizedBox(width: 4.0),
        Icon(Symbols.schedule, size: 18.0, color: color),
        Flexible(
          flex: 2,
          child: Text(
            time,
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
      ],
    );
  }
}
