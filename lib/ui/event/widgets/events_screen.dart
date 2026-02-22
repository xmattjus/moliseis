import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/ui/core/ui/responsive_scaffold.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_calendar.dart';
import 'package:moliseis/ui/event/widgets/components/events_modal.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.viewModel});

  final EventViewModel viewModel;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late DraggableScrollableController draggableScrollableController;
  late DateSymbols dateSymbols;

  ValueNotifier<double> bottomPaddingExtent = ValueNotifier(16.0);

  @override
  void initState() {
    super.initState();

    draggableScrollableController = DraggableScrollableController();
    draggableScrollableController.addListener(_draggableScrollableListener);

    widget.viewModel.loadByDate.execute(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentLocale = Localizations.localeOf(context);

    dateSymbols = intl.DateFormat(null, currentLocale.languageCode).dateSymbols;
  }

  @override
  void dispose() {
    draggableScrollableController.removeListener(_draggableScrollableListener);
    draggableScrollableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAtMostMedium = context.windowSizeClass.isAtMost(
      WindowSizeClass.medium,
    );
    return ResponsiveScaffold(
      draggableScrollableController: draggableScrollableController,
      modalBuilder: (context, scrollController) => EventsModal(
        localizedMonths: dateSymbols.MONTHS,
        selectedDate: widget.viewModel.selectedDate,
        viewModel: widget.viewModel,
        scrollController: scrollController,
      ),
      child: isAtMostMedium
          ? AnimatedBuilder(
              animation: bottomPaddingExtent,
              builder: (context, child) {
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomPaddingExtent.value),
                  child: child,
                );
              },
              child: _CalendarWidget(
                viewModel: widget.viewModel,
                onDayPressed: (date) =>
                    widget.viewModel.loadByDate.execute(date),
              ),
            )
          : _CalendarWidget(
              viewModel: widget.viewModel,
              onDayPressed: (date) => widget.viewModel.loadByDate.execute(date),
            ),
    );
  }

  void _draggableScrollableListener() {
    if (draggableScrollableController.isAttached) {
      final extent = clampDouble(draggableScrollableController.size, 0.0, 0.5);
      final test = draggableScrollableController.sizeToPixels(extent);
      bottomPaddingExtent.value = test;
    }
  }
}

class _CalendarWidget extends StatelessWidget {
  final EventViewModel viewModel;
  final void Function(DateTime date)? onDayPressed;
  const _CalendarWidget({required this.viewModel, this.onDayPressed});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar(title: Text('Eventi')),
        EventsCalendar(
          onDayPressed: (date) {
            onDayPressed?.call(date);
          },
          viewModel: viewModel,
        ),
      ],
    );
  }
}
