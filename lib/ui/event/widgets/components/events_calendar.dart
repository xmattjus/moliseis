import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_month.dart';
import 'package:paged_vertical_calendar/paged_vertical_calendar.dart';
import 'package:paged_vertical_calendar/utils/date_utils.dart';

class EventsCalendar extends StatefulWidget {
  final Function(DateTime date) onDayPressed;
  final EventViewModel viewModel;

  const EventsCalendar({
    super.key,
    required this.onDayPressed,
    required this.viewModel,
  });

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
    final now = DateTime.now();
    final minDate = DateTime(now.year);
    return ListenableBuilder(
      listenable: widget.viewModel.loadAll,
      builder: (context, child) {
        if (widget.viewModel.loadAll.completed) {
          return SliverFillRemaining(
            child: PagedVerticalCalendar(
              minDate: minDate,
              maxDate: minDate.copyWith(month: 12, day: 31),
              monthBuilder: (_, month, year) => EventsVerticalCalendarMonth(
                dateSymbols: _dateSymbols,
                month: month,
                year: year,
              ),
              dayBuilder: (_, date) => EventsVerticalCalendarDay(
                date: date,
                events: UnmodifiableListView(
                  widget.viewModel.all.where((event) {
                    return event.startDate.isSameDay(date);
                  }),
                ),
                onPressed: () => widget.onDayPressed(date),
                isSelected: date.isSameDay(widget.viewModel.selectedDate),
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
}
