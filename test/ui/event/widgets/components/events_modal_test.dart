import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_modal.dart';

import '../../../../support/fake_repositories.dart';

void main() {
  testWidgets('labels today using the current Europe/Rome calendar date', (
    tester,
  ) async {
    final viewModel = EventViewModel(
      repository: FakeEventRepository(),
      nowUtc: () => DateTime.utc(2026, 1, 10, 23, 30),
    );
    final selectedDate = EventCalendarDate(2026, 1, 11);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventsModal(
            localizedMonths: const ['January'],
            selectedDate: selectedDate,
            viewModel: viewModel,
          ),
        ),
      ),
    );

    expect(find.text('Eventi di oggi 11 January'), findsOneWidget);
  });
}
