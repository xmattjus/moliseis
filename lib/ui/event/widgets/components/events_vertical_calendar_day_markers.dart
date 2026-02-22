import 'package:flutter/material.dart';
import 'package:flutter_randomcolor/flutter_randomcolor.dart';
import 'package:moliseis/domain/models/event_content.dart';

class EventsVerticalCalendarDayMarkers extends StatefulWidget {
  final List<EventContent> events;

  const EventsVerticalCalendarDayMarkers({super.key, required this.events});

  @override
  State<EventsVerticalCalendarDayMarkers> createState() =>
      _EventsVerticalCalendarDayMarkersState();
}

class _EventsVerticalCalendarDayMarkersState
    extends State<EventsVerticalCalendarDayMarkers> {
  late final int markers;
  late final List<Color> colors;

  @override
  void initState() {
    super.initState();

    // Show at most 5 markers for a day.
    markers = widget.events.length.clamp(0, 5);

    colors = List.generate(
      markers,
      (_) => RandomColor.getColorObject(Options()),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 2.0,
    children: <Widget>[
      for (var i = 0; i < markers; i++)
        SizedBox(
          width: 6.0,
          height: 6.0,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
          ),
        ),
    ],
  );
}
