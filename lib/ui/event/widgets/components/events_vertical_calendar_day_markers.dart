import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  static const _maxMarkers = 5;

  static const List<Color> _palette = <Color>[
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
  ];

  var _markers = 0;
  var _colors = <Color>[];

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  @override
  void didUpdateWidget(covariant EventsVerticalCalendarDayMarkers oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!listEquals(oldWidget.events, widget.events)) {
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    // Keep marker colors deterministic for the app lifecycle.
    final visibleEvents = widget.events
        .take(_maxMarkers)
        .toList(growable: false);

    _markers = visibleEvents.length;
    _colors = visibleEvents
        .map((event) => _palette[event.remoteId.abs() % _palette.length])
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 2.0,
    children: <Widget>[
      for (var i = 0; i < _markers; i++)
        SizedBox(
          width: 6.0,
          height: 6.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _colors[i],
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );
}
