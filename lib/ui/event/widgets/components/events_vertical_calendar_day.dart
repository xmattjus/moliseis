import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day_markers.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class EventsVerticalCalendarDay extends StatelessWidget {
  final DateTime date;
  final List<EventContent> events;
  final Function() onPressed;
  final bool isSelected;

  const EventsVerticalCalendarDay({
    super.key,
    required this.date,
    this.events = const [],
    required this.onPressed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    final style = TextButton.styleFrom(
      backgroundColor: isSelected
          ? colorScheme.primary.withValues(alpha: 0.1)
          : null,
      shape: RoundedRectangleBorder(
        side: isSelected
            ? BorderSide(
                color: colorScheme.onSurfaceVariant,
                width: context.appSizes.borderSide.extraLarge,
              )
            : BorderSide.none,
        borderRadius: context.appShapes.circular.cornerLarge,
      ),
    );

    final dayNumber = Text('${date.day}');

    final child = events.isEmpty
        ? dayNumber
        : Stack(
            alignment: AlignmentGeometry.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              dayNumber,
              Positioned(
                top: 24,
                child: EventsVerticalCalendarDayMarkers(
                  key: ValueKey('markers_${date.toIso8601String()}'),
                  events: events,
                ),
              ),
            ],
          );

    return TextButton(
      key: ValueKey('day_${date.toIso8601String()}'),
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}
