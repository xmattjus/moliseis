import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AnimatedPostEventDates extends StatefulWidget {
  final EventContent event;

  const AnimatedPostEventDates({super.key, required this.event});

  @override
  State<AnimatedPostEventDates> createState() => _AnimatedPostEventDatesState();
}

class _AnimatedPostEventDatesState extends State<AnimatedPostEventDates>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final style = context.textTheme.bodyLarge;

    final isOngoing =
        now.isAfter(widget.event.startDate) &&
        now.isBefore(widget.event.endDate ?? DateTime.now());

    if (isOngoing) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text("L'evento è in corso", style: style),
        ],
      );
    }

    return Text(
      "L'evento si svolgerà il ${widget.event.startDate}",
      style: style,
    );
  }
}
