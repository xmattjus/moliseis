import 'dart:async';
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/domain/core/event_time.dart';
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
  late DraggableScrollableController _draggableScrollableController;
  late DateSymbols _dateSymbols;

  final _bottomPaddingAnimation = ValueNotifier<double>(0);
  double get _bottomPadding => _bottomPaddingAnimation.value;

  @override
  void initState() {
    super.initState();

    unawaited(
      widget.viewModel.loadByDate.execute(widget.viewModel.currentCalendarDate),
    );

    _draggableScrollableController = DraggableScrollableController();
    _draggableScrollableController.addListener(_draggableScrollableListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentLocale = Localizations.localeOf(context);

    _dateSymbols = intl.DateFormat(
      null,
      currentLocale.languageCode,
    ).dateSymbols;

    _bottomPaddingAnimation.value =
        (MediaQuery.maybeSizeOf(context)?.height ?? 0) *
        context.appSizes.bottomSheetInitialSnapSize;

    if (context.windowSizeClass.isLargerThan(WindowSizeClass.medium)) {
      _bottomPaddingAnimation.value = 0.0;
    }
  }

  @override
  void dispose() {
    _draggableScrollableController
      ..removeListener(_draggableScrollableListener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
    draggableScrollableController: _draggableScrollableController,
    modalBuilder: (_, scrollController) => EventsModal(
      localizedMonths: _dateSymbols.MONTHS,
      selectedDate: widget.viewModel.selectedDate,
      viewModel: widget.viewModel,
      scrollController: scrollController,
    ),
    child: AnimatedBuilder(
      animation: _bottomPaddingAnimation,
      builder: (_, child) {
        return Padding(
          padding: EdgeInsets.only(bottom: _bottomPadding),
          child: child,
        );
      },
      child: _CalendarWidget(
        viewModel: widget.viewModel,
        onDayPressed: (date) => widget.viewModel.loadByDate.execute(
          EventCalendarDate(date.year, date.month, date.day),
        ),
      ),
    ),
  );

  void _draggableScrollableListener() {
    if (_draggableScrollableController.isAttached) {
      final clampedSize = clampDouble(
        _draggableScrollableController.size,
        0,
        0.5,
      );
      final extent = _draggableScrollableController.sizeToPixels(clampedSize);
      _bottomPaddingAnimation.value = extent;
    }
  }
}

class _CalendarWidget extends StatelessWidget {
  const _CalendarWidget({required this.viewModel, this.onDayPressed});

  final EventViewModel viewModel;
  final void Function(DateTime date)? onDayPressed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        if (context.windowSizeClass.isAtMost(WindowSizeClass.medium))
          const SliverAppBar(title: Text('Eventi')),
        if (context.windowSizeClass.isLargerThan(WindowSizeClass.medium))
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
