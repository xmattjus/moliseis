import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('EventViewModel', () {
    group('loadAll', () {
      test('populates all events on success', () async {
        final event1 = makeEvent(remoteId: 1, name: 'Festival');
        final vm = await buildLoaded(
          FakeEventRepository(
            getByCurrentYearResult: Result.success([event1]),
          ),
        );

        expect(vm.loadAll.completed, isTrue);
        expect(vm.all, hasLength(1));
        expect(vm.all.first.remoteId, 1);
        expect(vm.all.first.name, 'Festival');
      });

      test('leaves all empty and surfaces error on failure', () async {
        final vm = await buildLoaded(
          FakeEventRepository(
            getByCurrentYearResult: Result.error(
              TestException('year fetch failed'),
            ),
          ),
        );

        expect(vm.loadAll.error, isTrue);
        expect(vm.all, isEmpty);
      });
    });

    group('loadNextIds', () {
      test('does not trigger loadNext when getNextEventIds fails', () async {
        final vm = await buildLoaded(
          FakeEventRepository(
            getNextEventIdsResult: Result.error(
              TestException('ids fetch failed'),
            ),
          ),
        );

        await vm.loadNextIds.execute();

        expect(vm.loadNextIds.error, isTrue);
        // loadNext must not have been triggered by the failed loadNextIds.
        expect(vm.loadNext.completed, isFalse);
        expect(vm.loadNext.error, isFalse);
      });

      test('triggers loadNext when getNextEventIds succeeds', () async {
        // Default repo has getNextEventIdsResult = Result.success([]).
        final vm = await buildLoaded(FakeEventRepository());

        await vm.loadNextIds.execute();
        await pumpEventQueue(times: 10);

        expect(vm.loadNextIds.completed, isTrue);
        // loadNext ran over an empty list and completed without error.
        expect(vm.loadNext.completed, isTrue);
      });
    });

    group('isEventOnDay', () {
      late EventViewModel vm;

      setUp(() async {
        vm = await buildLoaded(FakeEventRepository());
      });

      test('returns true for a single-day event on its start date', () {
        final event = _eventContent(startDate: DateTime(2026, 4, 7));
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 7, 12)), isTrue);
      });

      test('returns false for a single-day event on a different date', () {
        final event = _eventContent(startDate: DateTime(2026, 4, 7));
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 8)), isFalse);
      });

      test('returns true on the first day of a multi-day event', () {
        final event = _eventContent(
          startDate: DateTime(2026, 4, 7),
          endDate: DateTime(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 7)), isTrue);
      });

      test('returns true on the last day of a multi-day event', () {
        final event = _eventContent(
          startDate: DateTime(2026, 4, 7),
          endDate: DateTime(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 9)), isTrue);
      });

      test('returns false on the day after a multi-day event ends', () {
        final event = _eventContent(
          startDate: DateTime(2026, 4, 7),
          endDate: DateTime(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, DateTime(2026, 4, 10)), isFalse);
      });

      test(
        'treats malformed event (end before start) as single-day on startDate',
        () {
          final event = _eventContent(
            startDate: DateTime(2026, 4, 9),
            endDate: DateTime(2026, 4, 7),
          );
          // Falls back to single-day on startDate.
          expect(vm.isEventOnDay(event, DateTime(2026, 4, 9)), isTrue);
          expect(vm.isEventOnDay(event, DateTime(2026, 4, 7)), isFalse);
        },
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

/// Builds a fully-loaded [EventViewModel] and drains the constructor's
/// auto-fired [EventViewModel.loadAll] command.
Future<EventViewModel> buildLoaded(FakeEventRepository repo) async {
  final vm = EventViewModel(repository: repo);
  await pumpEventQueue(times: 10);
  assert(
    vm.loadAll.completed || vm.loadAll.error,
    'buildLoaded returned before loadAll finished',
  );
  return vm;
}

Event _eventContent({required DateTime startDate, DateTime? endDate}) {
  final now = DateTime(2026, 4);
  return Event(
    remoteId: 1,
    name: 'Event',
    description: '',
    category: ContentCategory.unknown,
    city: testCity(),
    coordinates: const LatLng(0, 0),
    createdAt: now,
    modifiedAt: now,
    media: const [],
    startDate: startDate,
    endDate: endDate,
    isSaved: false,
  );
}
