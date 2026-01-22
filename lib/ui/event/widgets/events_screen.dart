import 'package:flutter/material.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_calendar.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.viewModel});

  final EventViewModel viewModel;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(title: Text('Eventi')),
            EventsCalendar(viewModel: widget.viewModel),
          ],
        ),
      ),
    );
  }
}
