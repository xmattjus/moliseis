import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_month.dart';
import 'package:paged_vertical_calendar/paged_vertical_calendar.dart';

class EventsCalendar extends StatefulWidget {
  const EventsCalendar({
    required this.onDayPressed,
    required this.viewModel,
    super.key,
  });

  final void Function(DateTime date) onDayPressed;
  final EventViewModel viewModel;

  /// Converts an event calendar date into calendar-package date carriers.
  static ({DateTime startDate, DateTime endDate, DateTime initialDate})
  calendarDateBounds(
    EventCalendarDate currentDate,
  ) => (
    startDate: DateTime.utc(currentDate.year),
    endDate: DateTime.utc(currentDate.year, 12, 31),
    initialDate: DateTime.utc(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    ),
  );

  @override
  State<EventsCalendar> createState() => _EventsCalendarState();
}

class _EventsCalendarState extends State<EventsCalendar> {
  late DateSymbols _dateSymbols;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentLocale = Localizations.localeOf(context);

    _dateSymbols = intl.DateFormat(
      null,
      currentLocale.languageCode,
    ).dateSymbols;
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = widget.viewModel.currentCalendarDate;
    final (:startDate, :endDate, :initialDate) =
        EventsCalendar.calendarDateBounds(currentDate);
    return ListenableBuilder(
      listenable: widget.viewModel.loadAll,
      builder: (context, child) {
        if (widget.viewModel.loadAll.completed) {
          return SliverFillRemaining(
            child: _buildCalendar(
              minDate: startDate,
              maxDate: endDate,
              initialDate: initialDate,
              monthBuilder: (_, month, year) => EventsVerticalCalendarMonth(
                dateSymbols: _dateSymbols,
                month: month,
                year: year,
              ),
              dayBuilder: (_, date) => EventsVerticalCalendarDay(
                date: date,
                events: widget.viewModel.getEventsOnDay(_calendarDate(date)),
                onPressed: () => widget.onDayPressed(date),
                isSelected:
                    _calendarDate(date) == widget.viewModel.selectedDate,
              ),
            ),
          );
        }

        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: widget.viewModel.loadAll.running
                ? const EmptyView.loading(text: Text('Caricamento in corso...'))
                : EmptyView(
                    text: const Text(
                      'Si è verificato un errore durante il caricamento.',
                    ),
                    action: TextButton(
                      onPressed: widget.viewModel.loadAll.execute,
                      child: const Text('Riprova'),
                    ),
                  ),
          ),
        );
      },
    );
  }

  EventCalendarDate _calendarDate(DateTime carrier) => EventCalendarDate(
    carrier.year,
    carrier.month,
    carrier.day,
  );

  static Widget _buildCalendar({
    required DateTime minDate,
    required DateTime maxDate,
    required DateTime initialDate,
    required MonthBuilder monthBuilder,
    required DayBuilder dayBuilder,
  }) => PagedVerticalCalendar(
    minDate: minDate,
    maxDate: maxDate,
    initialDate: initialDate,
    monthBuilder: monthBuilder,
    dayBuilder: dayBuilder,
  );
}
