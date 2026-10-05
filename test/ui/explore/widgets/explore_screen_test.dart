import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/events_harness.dart';
import '../../../support/fake_repositories.dart';

void main() {
  testWidgets('Home shows direct discovery errors and retries both queries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final placeRepository = FakePlaceRepository(
      getLatestResult: Result.error(TestException('latest failed')),
    );
    final eventRepository = FakeEventRepository(
      getNextEventsResult: Result.error(TestException('upcoming failed')),
    );
    final harness = EventsRouteHarness(
      eventRepository: eventRepository,
      placeRepository: placeRepository,
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Riprova'), findsNWidgets(2));
    expect(placeRepository.getLatestCallCount, 1);
    expect(eventRepository.getNextEventsCallCount, 1);
    placeRepository.getLatestResult = const Result.success([]);
    eventRepository.getNextEventsResult = const Result.success([]);

    await tester.tap(find.text('Riprova').first);
    await tester.pumpAndSettle();
    expect(eventRepository.getNextEventsCallCount, 2);
    expect(find.text('Riprova'), findsOneWidget);

    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(placeRepository.getLatestCallCount, 2);
    expect(find.text('Riprova'), findsNothing);
    expect(eventRepository.getByIdCallCount, 0);
    expect(placeRepository.getByIdCallCount, 0);
    expect(tester.takeException(), isNull);
  });
}
