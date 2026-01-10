import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/detail/widgets/components/pulse_painter.dart';
import 'package:moliseis/utils/extensions.dart';

/// A widget that displays event date information with visual indicators.
///
/// This widget shows start and end dates for an event in a card format.
/// When the current date is within the event date range, it displays
/// a pulsing animation to indicate the event is currently active.
///
/// The widget automatically determines if an event is currently ongoing
/// by comparing the current date with the provided start and end dates.
/// In debug mode, the pulsing animation is always shown for testing purposes.
class EventDatesInformation extends StatefulWidget {
  /// Callback function executed when the card is tapped.
  /// If null, the card will not be interactive.
  final void Function()? onPressed;

  final DateTime? startDate;
  final DateTime? endDate;

  const EventDatesInformation({
    super.key,
    this.onPressed,
    this.startDate,
    this.endDate,
  });

  @override
  State<EventDatesInformation> createState() => _EventDatesInformationState();
}

/// State class for [EventDatesInformation] that manages the pulsing animation.
///
/// This class handles the animation controller lifecycle and determines
/// when to show the pulsing effect based on whether the event is currently
/// active. The animation runs continuously when the event is ongoing.
class _EventDatesInformationState extends State<EventDatesInformation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isCurrentDateWithinEventRange = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    // Whether the current date is within the event date range.
    _isCurrentDateWithinEventRange =
        now.isAfter(widget.startDate!) &&
        (now.isBefore(
          widget.endDate ??
              widget.startDate!.copyWith(hour: 23, minute: 59, second: 59),
        ));

    _controller = AnimationController(vsync: this)
      ..stop()
      ..reset();

    if (_isCurrentDateWithinEventRange || kDebugMode) {
      _controller.repeat(period: const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startDate == null) {
      return const EmptyBox();
    }

    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.bodyMedium;
    final backgroundColor = theme.colorScheme.secondaryContainer;
    final foregroundColor = theme.colorScheme.onSecondaryContainer;

    return CustomPaint(
      painter: PulsePainter(animation: _controller, color: backgroundColor),
      child: CardBase.filled(
        onPressed: widget.onPressed,
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundColor, backgroundColor.darken(0.1)!],
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DateRangeComponent(
                  color: foregroundColor,
                  date: widget.startDate!,
                  header: const Text('Data di inizio'),
                  icon: Icons.event_available_rounded,
                  textStyle: defaultTextStyle,
                ),
                if (widget.endDate != null) const Icon(Icons.arrow_right_alt),
                if (widget.endDate != null)
                  _DateRangeComponent(
                    color: foregroundColor,
                    date: widget.endDate!,
                    header: const Text('Data di fine'),
                    icon: Icons.event_busy_rounded,
                    textStyle: defaultTextStyle,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A component that displays a single date with its corresponding header and icon.
///
/// This widget is used internally by [EventDatesInformation] to show individual
/// start and end dates. It displays the date in a formatted way including
/// both the full date and time, along with an optional icon and header text.
class _DateRangeComponent extends StatelessWidget {
  final Color? color;
  final DateTime date;

  /// Widget displayed at the top of the card, typically used for category or type information.
  /// This content is styled with bold text and limited to a single line.
  final Widget header;

  final IconData? icon;
  final TextStyle? textStyle;

  const _DateRangeComponent({
    this.color,
    required this.date,
    this.icon,
    required this.header,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    final timeOfDay = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DefaultTextStyle.merge(
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            child: header,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 4.0,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: IconTheme.merge(
                  data: IconThemeData(color: color),
                  child: Icon(icon ?? Icons.question_mark),
                ),
              ),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                  child: Text(
                    '${localizations.formatFullDate(date)} $timeOfDay',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
