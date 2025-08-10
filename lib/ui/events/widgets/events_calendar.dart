import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/events/view_,models/event_view_model.dart';
import 'package:moliseis/ui/events/widgets/events_month.dart';

class EventsCalendar extends StatefulWidget {
  const EventsCalendar({super.key, required this.viewModel});

  final EventViewModel viewModel;

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
    return ListenableBuilder(
      listenable: widget.viewModel.load,
      builder: (context, child) {
        final command = widget.viewModel.load;

        if (command.running || command.error) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: command.running
                  ? const EmptyView.loading(
                      text: Text('Caricamento in corso...'),
                    )
                  : EmptyView(
                      text: const Text(
                        'Si è verificato un errore durante il caricamento.',
                      ),
                      action: TextButton(
                        onPressed: command.execute,
                        child: const Text('Riprova'),
                      ),
                    ),
            ),
          );
        }

        return SliverList.builder(
          itemBuilder: (context, index) {
            final i = index + 1;
            final widgets = <Widget>[];

            final date = DateTime(2025, i);

            final displayedEvents = List<Event?>.unmodifiable(
              widget.viewModel.events.map((e) {
                if (e.startDate?.month == i) return e;
              }),
            );

            widgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${_dateSymbols.MONTHS[i - 1]} 2025',
                  style: CustomTextStyles.section(
                    context,
                  )?.copyWith(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            );

            widgets.add(
              EventsMonth(
                displayedMonth: date,
                displayedMonthEvents: displayedEvents,
                onDaySelected: (value) {
                  if (value != null) {
                    print(value.title);
                  }
                },
              ),
            );

            return Column(children: widgets);
          },
          itemCount: 12,
        );
      },
    );
  }
}
