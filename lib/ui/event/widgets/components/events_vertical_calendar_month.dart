import 'package:intl/date_symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class EventsVerticalCalendarMonth extends StatelessWidget {
  const EventsVerticalCalendarMonth({
    required this.dateSymbols,
    required this.month,
    required this.year,
    super.key,
  });

  final DateSymbols dateSymbols;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context) {
    final monthName = '${dateSymbols.MONTHS[month - 1]} $year';
    final capitalizedMonthName = monthName.capitalize();
    // Shift the list of week days to start with Monday instead of Sunday.
    final shiftedWeekDays = dateSymbols.SHORTWEEKDAYS.shift(1);
    return Column(
      children: <Widget>[
        Text(
          capitalizedMonthName,
          style: _calendarMonthSection(context),
          textAlign: TextAlign.center,
        ),
        GridView.builder(
          addRepaintBoundaries: false,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 7,
          itemBuilder: (context, index) {
            return Center(
              child: Text(
                shiftedWeekDays[index],
                style: _calendarWeekDay(context),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Keeps weekday typography aligned with the Material date picker.
  TextStyle? _calendarWeekDay(BuildContext context) =>
      DatePickerTheme.defaults(context).weekdayStyle?.copyWith(
        color: context.theme.brightness == Brightness.light
            ? Colors.black45
            : Colors.white54,
      );

  /// Applies the calendar's local month-heading contrast to titleMedium.
  TextStyle? _calendarMonthSection(BuildContext context) =>
      context.textTheme.titleMedium?.copyWith(
        color: context.theme.brightness == Brightness.light
            ? Colors.black87
            : Colors.white70,
      );
}
