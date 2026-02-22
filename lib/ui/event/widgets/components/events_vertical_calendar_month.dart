import 'package:flutter/widgets.dart';
import 'package:intl/date_symbols.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class EventsVerticalCalendarMonth extends StatelessWidget {
  final DateSymbols dateSymbols;
  final int month;
  final int year;

  const EventsVerticalCalendarMonth({
    super.key,
    required this.dateSymbols,
    required this.month,
    required this.year,
  });

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
          style: AppTextStyles.calendarMonthSection(context),
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
                style: AppTextStyles.calendarWeekDay(context),
              ),
            );
          },
        ),
      ],
    );
  }
}
