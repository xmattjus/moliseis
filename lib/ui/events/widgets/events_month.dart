import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';

const double _dayPickerRowHeight = 42.0;
const int _maxDayPickerRowCount = 6; // A 31 day month that starts on Saturday.

const double _monthPickerHorizontalPadding = 8.0;

// The max scale factor of the day picker grid. This affects the size of the
// individual days in calendar view. Due to them filling a majority of the modal,
// which covers most of the screen, there's a limit in how large they can grow.
// There is also less room vertically in landscape orientation.
const double _kDayPickerGridPortraitMaxScaleFactor = 2.0;
const double _kDayPickerGridLandscapeMaxScaleFactor = 1.5;

// 14 is a common font size used to compute the effective text scale.
const double _fontSizeToScale = 14.0;

class EventsMonth extends StatefulWidget {
  /// [CalendarDatePicker]
  const EventsMonth({
    super.key,
    this.calendarDelegate = const GregorianCalendarDelegate(),
    required this.displayedMonth,
    required this.displayedMonthEvents,
    required this.onDaySelected,
  });

  final CalendarDelegate calendarDelegate;

  /// The month whose days are displayed by this .
  final DateTime displayedMonth;

  /// The events of the month whose days are displayed by this .
  final List<Event?> displayedMonthEvents;

  final ValueChanged<Event?> onDaySelected;

  @override
  State<EventsMonth> createState() => _EventsMonthState();
}

class _EventsMonthState extends State<EventsMonth> {
  late DateSymbols _dateSymbols;

  /// List of [FocusNode]s, one for each day of the month.
  late List<FocusNode> _dayFocusNodes;

  @override
  void initState() {
    super.initState();
    final int daysInMonth = widget.calendarDelegate.getDaysInMonth(
      widget.displayedMonth.year,
      widget.displayedMonth.month,
    );
    _dayFocusNodes = List<FocusNode>.generate(
      daysInMonth,
      (int index) =>
          FocusNode(skipTraversal: true, debugLabel: 'Day ${index + 1}'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check to see if the focused date is in this month, if so focus it.
    final DateTime? focusedDate = _FocusedDate.maybeOf(context);
    if (focusedDate != null &&
        widget.calendarDelegate.isSameMonth(
          widget.displayedMonth,
          focusedDate,
        )) {
      _dayFocusNodes[focusedDate.day - 1].requestFocus();
    }

    final currentLocale = Localizations.localeOf(context);

    _dateSymbols = intl.DateFormat(
      null,
      currentLocale.languageCode,
    ).dateSymbols;
  }

  @override
  void dispose() {
    for (final FocusNode node in _dayFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  List<Widget> _dayHeaders(
    TextStyle? headerStyle,
    MaterialLocalizations localizations,
  ) {
    final List<Widget> result = <Widget>[];
    for (
      int i = localizations.firstDayOfWeekIndex;
      result.length < DateTime.daysPerWeek;
      i = (i + 1) % DateTime.daysPerWeek
    ) {
      // TODO(xmattjus): change to NARROWWEEKDAYS when there isn't enough space to show SHORTWEEKDAYS.
      final String weekday = _dateSymbols.SHORTWEEKDAYS[i].toLowerCase();
      result.add(
        ExcludeSemantics(
          child: Center(child: Text(weekday, style: headerStyle)),
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );

    final TextStyle? weekdayStyle = CustomTextStyles.weekday(context);

    final Orientation orientation = MediaQuery.orientationOf(context);
    final bool isLandscapeOrientation = orientation == Orientation.landscape;

    final int year = widget.displayedMonth.year;
    final int month = widget.displayedMonth.month;

    final int daysInMonth = widget.calendarDelegate.getDaysInMonth(year, month);
    final int dayOffset = widget.calendarDelegate.firstDayOffset(
      year,
      month,
      localizations,
    );

    final List<Widget> dayItems = _dayHeaders(weekdayStyle, localizations);
    // 1-based day of month, e.g. 1-31 for January, and 1-29 for February on
    // a leap year.
    int day = -dayOffset;
    while (day < daysInMonth) {
      day++;
      if (day < 1) {
        dayItems.add(const SizedBox.shrink());
      } else {
        final DateTime dayToBuild = widget.calendarDelegate.getDay(
          year,
          month,
          day,
        );
        var isDisabled = true;
        final bool isSelectedDay = false;
        final bool isToday = false;

        if (widget.displayedMonthEvents.any(
          (element) => element?.startDate?.day == day,
        )) {
          isDisabled = false;
        }

        dayItems.add(
          _Day(
            dayToBuild,
            key: ValueKey<DateTime>(dayToBuild),
            isDisabled: isDisabled,
            isSelectedDay: isSelectedDay,
            isToday: isToday,
            onChanged: (value) {
              final event = widget.displayedMonthEvents.where(
                (element) =>
                    element?.startDate?.month == value.month &&
                    element?.startDate?.day == value.day,
              );
              widget.onDaySelected(event.firstOrNull);
            },
            focusNode: _dayFocusNodes[day - 1],
            calendarDelegate: widget.calendarDelegate,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _monthPickerHorizontalPadding,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: isLandscapeOrientation
            ? _kDayPickerGridLandscapeMaxScaleFactor
            : _kDayPickerGridPortraitMaxScaleFactor,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 250.0, maxHeight: 285.0),
          child: GridView.custom(
            physics: const ClampingScrollPhysics(),
            gridDelegate: _DayPickerGridDelegate(context),
            childrenDelegate: SliverChildListDelegate(
              dayItems,
              addRepaintBoundaries: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPickerGridDelegate extends SliverGridDelegate {
  const _DayPickerGridDelegate(this.context);

  final BuildContext context;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 3.0).scale(_fontSizeToScale) /
        _fontSizeToScale;
    final double scaledRowHeight = textScaleFactor > 1.3
        ? ((textScaleFactor - 1) * 30) + _dayPickerRowHeight
        : _dayPickerRowHeight;
    const int columnCount = DateTime.daysPerWeek;
    final double tileWidth = constraints.crossAxisExtent / columnCount;
    final double tileHeight = math.min(
      scaledRowHeight,
      constraints.viewportMainAxisExtent / (_maxDayPickerRowCount + 1),
    );
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: tileHeight,
      crossAxisCount: columnCount,
      crossAxisStride: tileWidth,
      mainAxisStride: tileHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_DayPickerGridDelegate oldDelegate) => false;
}

/// InheritedWidget indicating what the current focused date is for its children.
///
/// This is used by the [_MonthPicker] to let its children [_DayPicker]s know
/// what the currently focused date (if any) should be.
class _FocusedDate extends InheritedWidget {
  const _FocusedDate({
    required super.child,
    required this.calendarDelegate,
    this.date,
  });

  final CalendarDelegate<DateTime> calendarDelegate;
  final DateTime? date;

  @override
  bool updateShouldNotify(_FocusedDate oldWidget) {
    return !calendarDelegate.isSameDay(date, oldWidget.date);
  }

  static DateTime? maybeOf(BuildContext context) {
    final _FocusedDate? focusedDate = context
        .dependOnInheritedWidgetOfExactType<_FocusedDate>();
    return focusedDate?.date;
  }
}

class _Day extends StatefulWidget {
  const _Day(
    this.day, {
    super.key,
    required this.isDisabled,
    required this.isSelectedDay,
    required this.isToday,
    required this.onChanged,
    required this.focusNode,
    required this.calendarDelegate,
  });

  final DateTime day;
  final bool isDisabled;
  final bool isSelectedDay;
  final bool isToday;
  final ValueChanged<DateTime> onChanged;
  final FocusNode focusNode;
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  State<_Day> createState() => _DayState();
}

class _DayState extends State<_Day> {
  final MaterialStatesController _statesController = MaterialStatesController();

  @override
  Widget build(BuildContext context) {
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final TextStyle? dayStyle = datePickerTheme.dayStyle ?? defaults.dayStyle;
    T? effectiveValue<T>(T? Function(DatePickerThemeData? theme) getProperty) {
      return getProperty(datePickerTheme) ?? getProperty(defaults);
    }

    T? resolve<T>(
      MaterialStateProperty<T>? Function(DatePickerThemeData? theme)
      getProperty,
      Set<MaterialState> states,
    ) {
      return effectiveValue((DatePickerThemeData? theme) {
        return getProperty(theme)?.resolve(states);
      });
    }

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String semanticLabelSuffix = widget.isToday
        ? ', ${localizations.currentDateLabel}'
        : '';

    final Set<MaterialState> states = <MaterialState>{
      if (widget.isDisabled) MaterialState.disabled,
      if (widget.isSelectedDay) MaterialState.selected,
    };

    _statesController.value = states;

    final Color? dayForegroundColor = resolve<Color?>(
      (DatePickerThemeData? theme) => widget.isToday
          ? theme?.todayForegroundColor
          : theme?.dayForegroundColor,
      states,
    );
    final Color? dayBackgroundColor = resolve<Color?>(
      (DatePickerThemeData? theme) => widget.isToday
          ? theme?.todayBackgroundColor
          : theme?.dayBackgroundColor,
      states,
    );
    final MaterialStateProperty<Color?> dayOverlayColor =
        MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) => effectiveValue(
            (DatePickerThemeData? theme) =>
                theme?.dayOverlayColor?.resolve(states),
          ),
        );
    final OutlinedBorder dayShape = resolve<OutlinedBorder?>(
      (DatePickerThemeData? theme) => theme?.dayShape,
      states,
    )!;
    final ShapeDecoration decoration = widget.isToday
        ? ShapeDecoration(
            color: dayBackgroundColor,
            shape: dayShape.copyWith(
              side: (datePickerTheme.todayBorder ?? defaults.todayBorder!)
                  .copyWith(color: dayForegroundColor),
            ),
          )
        : ShapeDecoration(color: dayBackgroundColor, shape: dayShape);

    Widget dayWidget = Ink(
      decoration: decoration,
      child: Center(
        child: Text(
          localizations.formatDecimal(widget.day.day),
          style: dayStyle?.apply(color: dayForegroundColor),
        ),
      ),
    );

    if (widget.isDisabled) {
      dayWidget = ExcludeSemantics(child: dayWidget);
    } else {
      dayWidget = InkResponse(
        focusNode: widget.focusNode,
        onTap: () => widget.onChanged(widget.day),
        statesController: _statesController,
        overlayColor: dayOverlayColor,
        customBorder: dayShape,
        containedInkWell: true,
        child: Semantics(
          // We want the day of month to be spoken first irrespective of the
          // locale-specific preferences or TextDirection. This is because
          // an accessibility user is more likely to be interested in the
          // day of month before the rest of the date, as they are looking
          // for the day of month. To do that we prepend day of month to the
          // formatted full date.
          label:
              '${localizations.formatDecimal(widget.day.day)}, ${widget.calendarDelegate.formatFullDate(widget.day, localizations)}$semanticLabelSuffix',
          // Set button to true to make the date selectable.
          button: true,
          selected: widget.isSelectedDay,
          excludeSemantics: true,
          child: dayWidget,
        ),
      );
    }

    return dayWidget;
  }

  @override
  void dispose() {
    _statesController.dispose();
    super.dispose();
  }
}
