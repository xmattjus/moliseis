import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('EventViewModel', () {
    group('loadAll', () {
      test('populates all events on success', () async {
        final event1 = makeEvent(name: 'Festival');
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

      test(
        'replaces a date-first empty fallback when the initial yearly load '
        'completes',
        () async {
          final date = EventCalendarDate(2026, 4, 2);
          final yearly = Completer<Result<List<Event>>>();
          final fallback = Completer<Result<List<Event>>>();
          final repository = FakeEventRepository()
            ..pendingGetByCurrentYear = yearly
            ..pendingGetByDate = fallback;
          final vm = EventViewModel(
            repository: repository,
            nowUtc: () => DateTime.utc(2026, 4, 2),
          );

          await pumpEventQueue();
          final dateLoad = vm.loadByDate.execute(date);
          await pumpEventQueue();
          fallback.complete(const Result.success([]));
          await dateLoad;

          yearly.complete(
            Result.success([
              makeEvent(remoteId: 22, startDate: DateTime.utc(2026, 4, 2, 10)),
            ]),
          );
          await pumpEventQueue(times: 10);

          expect(vm.byMonth.map((event) => event.remoteId), [22]);
          expect(repository.getByDateCallCount, 1);
        },
      );

      test(
        'does not let a stale date fallback overwrite newer yearly data',
        () async {
          final date = EventCalendarDate(2026, 4, 2);
          final yearly = Completer<Result<List<Event>>>();
          final fallback = Completer<Result<List<Event>>>();
          final repository = FakeEventRepository()
            ..pendingGetByCurrentYear = yearly
            ..pendingGetByDate = fallback;
          final vm = EventViewModel(
            repository: repository,
            nowUtc: () => DateTime.utc(2026, 4, 2),
          );

          await pumpEventQueue();
          final dateLoad = vm.loadByDate.execute(date);
          await pumpEventQueue();
          yearly.complete(
            Result.success([
              makeEvent(remoteId: 23, startDate: DateTime.utc(2026, 4, 2, 10)),
            ]),
          );
          await pumpEventQueue(times: 10);
          fallback.complete(const Result.success([]));
          await dateLoad;

          expect(vm.byMonth.map((event) => event.remoteId), [23]);
        },
      );

      test(
        'recomputes and invalidates the selected-day cache after reloads',
        () async {
          final date = EventCalendarDate(2026, 4, 2);
          final repository = FakeEventRepository();
          final vm = await buildLoaded(repository);

          await vm.loadByDate.execute(date);
          expect(repository.getByDateCallCount, 1);

          repository.getByCurrentYearResult = Result.success([
            makeEvent(remoteId: 24, startDate: DateTime.utc(2026, 4, 2, 10)),
          ]);
          await vm.loadAll.execute();
          expect(vm.byMonth.map((event) => event.remoteId), [24]);

          repository.getByCurrentYearResult = Result.success([
            makeEvent(remoteId: 25, startDate: DateTime.utc(2026, 4, 2, 11)),
          ]);
          await vm.loadAll.execute();
          expect(vm.byMonth.map((event) => event.remoteId), [25]);

          repository.getByCurrentYearResult = const Result.success([]);
          await vm.loadAll.execute();
          expect(vm.byMonth, isEmpty);

          repository.getByDateResult = Result.success([
            makeEvent(remoteId: 26, startDate: DateTime.utc(2026, 4, 2, 12)),
          ]);
          await vm.loadByDate.execute(date);
          expect(repository.getByDateCallCount, 2);
          expect(vm.byMonth.map((event) => event.remoteId), [26]);
        },
      );
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
        final event = makeEvent(startDate: DateTime.utc(2026, 4, 7));
        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 4, 7)), isTrue);
      });

      test('returns false for a single-day event on a different date', () {
        final event = makeEvent(startDate: DateTime.utc(2026, 4, 7));
        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 4, 8)), isFalse);
      });

      test('returns true on the first day of a multi-day event', () {
        final event = makeEvent(
          startDate: DateTime.utc(2026, 4, 7),
          endDate: DateTime.utc(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 4, 7)), isTrue);
      });

      test('returns true on the last day of a multi-day event', () {
        final event = makeEvent(
          startDate: DateTime.utc(2026, 4, 7),
          endDate: DateTime.utc(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 4, 9)), isTrue);
      });

      test('returns false on the day after a multi-day event ends', () {
        final event = makeEvent(
          startDate: DateTime.utc(2026, 4, 7),
          endDate: DateTime.utc(2026, 4, 9),
        );
        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 4, 10)), isFalse);
      });

      test('uses the next Rome day for a late previous UTC-day instant', () {
        final event = makeEvent(startDate: DateTime.utc(2026, 1, 10, 23, 30));

        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 1, 11)), isTrue);
        expect(vm.isEventOnDay(event, EventCalendarDate(2026, 1, 10)), isFalse);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

/// Builds a fully-loaded [EventViewModel] and drains the constructor's
/// auto-fired [EventViewModel.loadAll] command.
Future<EventViewModel> buildLoaded(FakeEventRepository repo) async {
  final vm = EventViewModel(
    repository: repo,
    nowUtc: () => DateTime.utc(2026, 4, 1, 1),
  );
  await pumpEventQueue(times: 10);
  assert(
    vm.loadAll.completed || vm.loadAll.error,
    'buildLoaded returned before loadAll finished',
  );
  return vm;
}
