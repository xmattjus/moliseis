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
          FakeEventRepository(getByCurrentYearResult: Result.success([event1])),
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

      test('replaces a date-first empty fallback when the initial yearly load '
          'completes', () async {
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
      });

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

    group('loadNext', () {
      test('publishes direct repository order without per-ID lookup', () async {
        final events = [makeEvent(remoteId: 2), makeEvent()];
        final repo = FakeEventRepository(
          getNextEventsResult: Result.success(events),
        );
        final vm = await buildLoaded(repo);
        await vm.loadNext.execute(DateTime.utc(2026, 4, 1, 1));
        expect(vm.next, events);
        expect(vm.loadNext.completed, isTrue);
        expect(repo.getNextEventsCallCount, 1);
        expect(repo.getByIdCallCount, 0);
      });

      test('owns discovery error and retries the query', () async {
        final failure = TestException('discovery failed');
        final repo = FakeEventRepository(
          getNextEventsResult: Result.error(failure),
        );
        final vm = await buildLoaded(repo);
        await vm.loadNext.execute(DateTime.utc(2026, 4, 1, 1));
        expect(vm.loadNext.error, isTrue);
        expect((vm.loadNext.result! as Error<void>).error, same(failure));
        repo.getNextEventsResult = Result.success([makeEvent()]);
        await vm.loadNext.execute(DateTime.utc(2026, 4, 1, 1));
        expect(repo.getNextEventsCallCount, 2);
        expect(vm.loadNext.completed, isTrue);
        expect(vm.next, hasLength(1));
      });

      test('retains prior state while pending and on error, '
          'clears on empty success', () async {
        final first = makeEvent();
        final repo = FakeEventRepository(
          getNextEventsResult: Result.success([first]),
        );
        final vm = await buildLoaded(repo);
        await vm.loadNext.execute(DateTime.utc(2026, 4, 1, 1));
        final pending = Completer<Result<List<Event>>>();
        repo.pendingGetNextEvents = pending;
        final load = vm.loadNext.execute(DateTime.utc(2026, 4, 1, 1));
        expect(vm.next, [first]);
        pending.complete(Result.error(TestException('query failed')));
        await load;
        expect(vm.next, [first]);
        expect(vm.loadNext.error, isTrue);
        repo
          ..pendingGetNextEvents = null
          ..getNextEventsResult = const Result.success([]);
        await vm.loadNext.execute(DateTime.utc(2026, 4, 1, 1));
        expect(vm.next, isEmpty);
        expect(vm.loadNext.completed, isTrue);
      });
    });

    group('direct discovery state', () {
      for (final ongoing in [true, false]) {
        test('${ongoing ? 'ongoing' : 'next'} publishes atomically, '
            'retains errors and exposes read-only state', () async {
          final original = [makeEvent(remoteId: 2), makeEvent()];
          final replacement = [makeEvent(remoteId: 3), makeEvent(remoteId: 4)];
          final repo = FakeEventRepository(
            getOngoingEventsResult: Result.success(original),
            getNextEventsResult: Result.success(original),
          );
          final vm = await buildLoaded(repo);
          addTearDown(vm.dispose);
          final command = ongoing ? vm.loadOngoing : vm.loadNext;
          final snapshot = DateTime.utc(2026, 4, 1, 1);
          var notifications = 0;
          vm.addListener(() => notifications++);
          await command.execute(snapshot);
          expect(ongoing ? vm.ongoing : vm.next, original);
          expect(notifications, 1);
          expect(
            () => (ongoing ? vm.ongoing : vm.next).add(makeEvent()),
            throwsUnsupportedError,
          );
          final pending = Completer<Result<List<Event>>>();
          if (ongoing) {
            repo.pendingGetOngoingEvents = pending;
          } else {
            repo.pendingGetNextEvents = pending;
          }
          final load = command.execute(snapshot);
          expect(command.running, isTrue);
          expect(ongoing ? vm.ongoing : vm.next, original);
          expect(notifications, 1);
          pending.complete(Result.success(replacement));
          await load;
          expect(command.completed, isTrue);
          expect(ongoing ? vm.ongoing : vm.next, replacement);
          expect(notifications, 2);
          final failure = TestException('materialization failed');
          if (ongoing) {
            repo
              ..pendingGetOngoingEvents = null
              ..getOngoingEventsResult = Result.error(failure);
          } else {
            repo
              ..pendingGetNextEvents = null
              ..getNextEventsResult = Result.error(failure);
          }
          await command.execute(snapshot);
          expect((command.result! as Error<void>).error, same(failure));
          expect(ongoing ? vm.ongoing : vm.next, replacement);
          expect(notifications, 2);
          repo
            ..getOngoingEventsResult = const Result.success([])
            ..getNextEventsResult = const Result.success([]);
          await command.execute(snapshot);
          expect(ongoing ? vm.ongoing : vm.next, isEmpty);
          expect(command.completed, isTrue);
          expect(notifications, 3);
          expect(repo.getByIdCallCount, 0);
          expect(
            ongoing
                ? repo.receivedOngoingSnapshots
                : repo.receivedNextSnapshots,
            everyElement(same(snapshot)),
          );
        });
      }
    });

    group('refreshHomeDiscovery', () {
      test('shares one advancing-clock snapshot across delayed queries, '
          'then moves the newly started event on the next pass', () async {
        var now = DateTime.parse('2026-04-01T10:59:59.900Z');
        var clockReads = 0;
        final events = [
          makeEvent(
            startDate: DateTime.utc(2026, 4, 1, 10),
            endDate: DateTime.utc(2026, 4, 1, 12),
          ),
          makeEvent(
            remoteId: 2,
            startDate: DateTime.utc(2026, 4, 1, 11),
            endDate: DateTime.utc(2026, 4, 1, 12),
          ),
        ];
        final held = Completer<void>();
        final repo = FakeEventRepository();
        repo.getOngoingEventsHandler = (snapshot) async {
          if (repo.getOngoingEventsCallCount == 1) await held.future;
          return Result.success(
            events
                .where(
                  (event) =>
                      !event.startDate.isAfter(snapshot) &&
                      !event.endDate!.isBefore(snapshot),
                )
                .toList(),
          );
        };
        repo.getNextEventsHandler = (snapshot) async => Result.success(
          events.where((event) => event.startDate.isAfter(snapshot)).toList(),
        );
        final vm = EventViewModel(
          repository: repo,
          nowUtc: () {
            clockReads++;
            return now;
          },
        );
        addTearDown(vm.dispose);
        await pumpEventQueue();
        clockReads = 0;
        final before = now;
        final pass = vm.refreshHomeDiscovery();
        await pumpEventQueue();
        expect(repo.getNextEventsCallCount, 0);
        now = DateTime.parse('2026-04-01T11:00:00.200Z');
        held.complete();
        await pass;
        expect(clockReads, 1);
        expect(repo.receivedOngoingSnapshots, [before]);
        expect(repo.receivedNextSnapshots, [before]);
        expect(vm.ongoing.map((event) => event.remoteId), [1]);
        expect(vm.next.map((event) => event.remoteId), [2]);
        expect(vm.ongoing.toSet().intersection(vm.next.toSet()), isEmpty);
        await vm.refreshHomeDiscovery();
        expect(clockReads, 2);
        expect(repo.receivedOngoingSnapshots, [before, now]);
        expect(repo.receivedNextSnapshots, [before, now]);
        expect(vm.ongoing.map((event) => event.remoteId), [1, 2]);
        expect(vm.next, isEmpty);
      });

      test('coalesces overlapping requests and captures a fresh clock '
          'only when the subsequent pass starts', () async {
        var now = DateTime.utc(2026, 4, 1, 10);
        var reads = 0;
        final held = Completer<void>();
        final repo = FakeEventRepository();
        repo.getOngoingEventsHandler = (snapshot) async {
          if (repo.getOngoingEventsCallCount == 1) await held.future;
          return Result.success([makeEvent(remoteId: snapshot.hour)]);
        };
        final vm = EventViewModel(
          repository: repo,
          nowUtc: () {
            reads++;
            return now;
          },
        );
        addTearDown(vm.dispose);
        await pumpEventQueue();
        reads = 0;
        final firstSnapshot = now;
        final first = vm.refreshHomeDiscovery();
        await pumpEventQueue();
        now = DateTime.utc(2026, 4, 1, 11);
        final second = vm.refreshHomeDiscovery();
        final third = vm.refreshHomeDiscovery();
        expect(second, same(first));
        expect(third, same(first));
        expect(reads, 1);
        now = DateTime.utc(2026, 4, 1, 12);
        held.complete();
        await first;
        expect(reads, 2);
        expect(repo.receivedOngoingSnapshots, [firstSnapshot, now]);
        expect(repo.receivedNextSnapshots, [firstSnapshot, now]);
        expect(vm.ongoing.single.remoteId, 12);
        expect(repo.getOngoingEventsCallCount, 2);
        expect(repo.getNextEventsCallCount, 2);
      });

      test(
        'retains the captured Rome day and window across midnight',
        () async {
          final policy = EventTimePolicy();
          final day = EventCalendarDate(2026, 4, 1);
          final range = policy.utcRangeForCalendarDate(day);
          final following = policy.utcRangeForCalendarDate(
            EventCalendarDate(2026, 4, 2),
          );
          final upper = policy.utcRangeForCalendarDate(
            EventCalendarDate(2026, 5, 1),
          );
          var now = range.endUtc;
          var reads = 0;
          final events = [
            makeEvent(startDate: range.startUtc),
            makeEvent(remoteId: 2, startDate: following.startUtc),
            makeEvent(remoteId: 3, startDate: upper.endUtc),
            makeEvent(
              remoteId: 4,
              startDate: upper.endUtc.add(const Duration(microseconds: 1)),
            ),
          ];
          final held = Completer<void>();
          final ongoingDays = <EventCalendarDate>[];
          final nextDays = <EventCalendarDate>[];
          final repo = FakeEventRepository();
          repo.getOngoingEventsHandler = (snapshot) async {
            final capturedDay = policy.currentCalendarDate(snapshot);
            ongoingDays.add(capturedDay);
            if (repo.getOngoingEventsCallCount == 1) await held.future;
            return Result.success(
              events
                  .where(
                    (event) =>
                        policy.calendarDateForUtc(event.startDate) ==
                            capturedDay &&
                        !event.startDate.isAfter(snapshot),
                  )
                  .toList(),
            );
          };
          repo.getNextEventsHandler = (snapshot) async {
            final capturedDay = policy.currentCalendarDate(snapshot);
            nextDays.add(capturedDay);
            final endDay = DateTime.utc(
              capturedDay.year,
              capturedDay.month,
              capturedDay.day + 30,
            );
            final end = policy
                .utcRangeForCalendarDate(
                  EventCalendarDate(endDay.year, endDay.month, endDay.day),
                )
                .endUtc;
            return Result.success(
              events
                  .where(
                    (event) =>
                        event.startDate.isAfter(snapshot) &&
                        !event.startDate.isAfter(end),
                  )
                  .toList(),
            );
          };
          final vm = EventViewModel(
            repository: repo,
            nowUtc: () {
              reads++;
              return now;
            },
          );
          addTearDown(vm.dispose);
          await pumpEventQueue();
          reads = 0;
          final before = now;
          final pass = vm.refreshHomeDiscovery();
          await pumpEventQueue();
          now = following.startUtc;
          held.complete();
          await pass;
          expect(reads, 1);
          expect(repo.receivedOngoingSnapshots, [before]);
          expect(repo.receivedNextSnapshots, [before]);
          expect(ongoingDays, [day]);
          expect(nextDays, [day]);
          expect(vm.ongoing.map((event) => event.remoteId), [1]);
          expect(vm.next.map((event) => event.remoteId), [2, 3]);
          await vm.refreshHomeDiscovery();
          expect(reads, 2);
          expect(ongoingDays.last, EventCalendarDate(2026, 4, 2));
          expect(nextDays.last, EventCalendarDate(2026, 4, 2));
          expect(vm.ongoing.map((event) => event.remoteId), [2]);
          expect(vm.next.map((event) => event.remoteId), [3, 4]);
        },
      );

      for (final ongoing in [true, false]) {
        test('waits for an already-running ${ongoing ? 'ongoing' : 'next'} '
            'command before taking a pass snapshot', () async {
          final held = Completer<Result<List<Event>>>();
          final repo = FakeEventRepository();
          final vm = await buildLoaded(repo);
          addTearDown(vm.dispose);
          if (ongoing) {
            repo.pendingGetOngoingEvents = held;
          } else {
            repo.pendingGetNextEvents = held;
          }
          final command = ongoing ? vm.loadOngoing : vm.loadNext;
          final directSnapshot = DateTime.utc(2026, 4);
          final direct = command.execute(directSnapshot);
          final pass = vm.refreshHomeDiscovery();
          var completed = false;
          unawaited(pass.then((_) => completed = true));
          await pumpEventQueue();
          expect(completed, isFalse);
          // Verify the coordinator removes its internal one-shot listener.
          // ignore: invalid_use_of_protected_member
          expect(command.hasListeners, isTrue);
          repo
            ..pendingGetOngoingEvents = null
            ..pendingGetNextEvents = null;
          held.complete(Result.success([makeEvent()]));
          await direct;
          await pass;
          // Verify the coordinator removes its internal one-shot listener.
          // ignore: invalid_use_of_protected_member
          expect(command.hasListeners, isFalse);
          expect(repo.getOngoingEventsCallCount, ongoing ? 2 : 1);
          expect(repo.getNextEventsCallCount, ongoing ? 1 : 2);
          expect(
            repo.receivedOngoingSnapshots.last,
            repo.receivedNextSnapshots.last,
          );
        });
      }

      test(
        'keeps independent command errors and does not retry automatically',
        () async {
          final ongoingFailure = TestException('ongoing failure');
          final nextFailure = TestException('next failure');
          final repo = FakeEventRepository(
            getOngoingEventsResult: Result.error(ongoingFailure),
            getNextEventsResult: Result.success([makeEvent()]),
          );
          final vm = await buildLoaded(repo);
          addTearDown(vm.dispose);
          await vm.refreshHomeDiscovery();
          expect(
            (vm.loadOngoing.result! as Error<void>).error,
            same(ongoingFailure),
          );
          expect(vm.loadNext.completed, isTrue);
          expect(vm.next, hasLength(1));
          await pumpEventQueue();
          expect(repo.getOngoingEventsCallCount, 1);
          expect(repo.getNextEventsCallCount, 1);
          repo
            ..getOngoingEventsResult = Result.success([makeEvent(remoteId: 2)])
            ..getNextEventsResult = Result.error(nextFailure);
          await vm.refreshHomeDiscovery();
          expect(vm.loadOngoing.completed, isTrue);
          expect(vm.ongoing.single.remoteId, 2);
          expect((vm.loadNext.result! as Error<void>).error, same(nextFailure));
          expect(vm.next.single.remoteId, 1);
        },
      );
    });

    group('dispose', () {
      for (final ongoing in [true, false]) {
        test('prevents ${ongoing ? 'ongoing' : 'next'} publication and '
            'coalesced continuations after disposal', () async {
          final held = Completer<Result<List<Event>>>();
          final repo = FakeEventRepository();
          final vm = await buildLoaded(repo);
          var notifications = 0;
          vm.addListener(() => notifications++);
          if (ongoing) {
            repo.pendingGetOngoingEvents = held;
          } else {
            repo.pendingGetNextEvents = held;
          }
          final pass = vm.refreshHomeDiscovery();
          await pumpEventQueue();
          unawaited(vm.refreshHomeDiscovery());
          final before = notifications;
          vm.dispose();
          held.complete(Result.success([makeEvent()]));
          await pass;
          expect(notifications, before);
          expect(ongoing ? vm.ongoing : vm.next, isEmpty);
          expect(repo.getOngoingEventsCallCount, 1);
          expect(repo.getNextEventsCallCount, ongoing ? 0 : 1);
          await vm.refreshHomeDiscovery();
          expect(repo.getOngoingEventsCallCount, 1);
        });
      }

      test(
        'stops and removes one-shot waits without cancelling a direct query',
        () async {
          final held = Completer<Result<List<Event>>>();
          final repo = FakeEventRepository()..pendingGetNextEvents = held;
          final vm = await buildLoaded(repo);
          final direct = vm.loadNext.execute(DateTime.utc(2026, 4));
          final pass = vm.refreshHomeDiscovery();
          await pumpEventQueue();
          // Verify wait cleanup without adding a production inspection API.
          // ignore: invalid_use_of_protected_member
          expect(vm.loadNext.hasListeners, isTrue);
          vm.dispose();
          await pass;
          // Verify wait cleanup without adding a production inspection API.
          // ignore: invalid_use_of_protected_member
          expect(vm.loadNext.hasListeners, isFalse);
          expect(vm.loadNext.running, isTrue);
          expect(repo.getOngoingEventsCallCount, 0);
          held.complete(Result.success([makeEvent()]));
          await direct;
          expect(vm.next, isEmpty);
        },
      );

      test('ignores late constructor annual publication', () async {
        final held = Completer<Result<List<Event>>>();
        final repo = FakeEventRepository()..pendingGetByCurrentYear = held;
        final vm = EventViewModel(
          repository: repo,
          nowUtc: () => DateTime.utc(2026, 4),
        );
        var notifications = 0;
        vm
          ..addListener(() => notifications++)
          ..dispose();
        held.complete(Result.success([makeEvent()]));
        await pumpEventQueue();
        expect(vm.all, isEmpty);
        expect(vm.byMonth, isEmpty);
        expect(notifications, 0);
        expect(vm.loadAll.completed, isTrue);
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
