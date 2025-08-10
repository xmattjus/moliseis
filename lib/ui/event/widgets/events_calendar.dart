import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/custom_modal_bottom_sheet.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/event_bottom_sheet_content.dart';
import 'package:moliseis/ui/event/widgets/events_month.dart';

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
      listenable: widget.viewModel.loadAll,
      builder: (context, child) {
        final command = widget.viewModel.loadAll;

        if (command.completed) {
          return SliverList.builder(
            itemBuilder: (context, index) {
              final i = index + 1;
              final widgets = <Widget>[];

              final date = DateTime(DateTime.now().year, i);

              final displayedEvents = List<EventContent?>.unmodifiable(
                widget.viewModel.all.map((e) {
                  if (e.startDate.month == i) return e;
                }),
              );

              widgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '${_dateSymbols.MONTHS[i - 1]} 2025',
                    style: CustomTextStyles.section(context)?.copyWith(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );

              widgets.add(
                EventsMonth(
                  displayedMonth: date,
                  displayedMonthEvents: displayedEvents,
                  onDaySelected: (event) async {
                    if (event != null) {
                      widget.viewModel.loadByDate.execute(event.startDate);

                      await showCustomModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return EventBottomSheetContent(
                            localizedMonths: _dateSymbols.MONTHS,
                            selectedDate: event.startDate,
                            viewModel: widget.viewModel,
                          );
                        },
                        isScrollControlled: true,
                      );
                    }
                  },
                ),
              );

              return Column(children: widgets);
            },
            itemCount: 12,
          );
        }

        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: command.running
                ? const EmptyView.loading(text: Text('Caricamento in corso...'))
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
      },
    );
  }
}
