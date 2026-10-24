import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/admin_dashboard_command_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  late DisposalEventProbe probe;
  late List<Object> reports;
  late List<StackTrace> stacks;
  setUp(() {
    probe = DisposalEventProbe();
    addTearDown(probe.dispose);
    reports = [];
    stacks = [];
    final previous = Command.globalExceptionHandler;
    final reportAll = Command.reportAllExceptions;
    Command.reportAllExceptions = false;
    Command.globalExceptionHandler = (failure, stack) {
      reports.add(failure.error);
      stacks.add(stack);
    };
    addTearDown(() {
      Command.globalExceptionHandler = previous;
      Command.reportAllExceptions = reportAll;
    });
  });

  for (final lane in AdminDashboardLane.values) {
    group(lane.name, () {
      for (final inNotification in [false, true]) {
        testWidgets('S2 revoke before entry notification=$inNotification', (
          tester,
        ) async {
          final h = AdminDashboardCommandHarness(lane, probe: probe);
          expect(h.resultNotifiers, hasLength(3));
          if (inNotification) h.owner.addListener(h.owner.dispose);
          h.request();
          h.owner.dispose();
          final state = h.state();
          final notifications = h.notifications;
          await pumpPhysicalCommandDisposal(tester);
          expect(h.calls, 0);
          expect(h.state(), state);
          expect(h.notifications, notifications);
          if (lane != AdminDashboardLane.mutation) {
            await h.original;
            expect(h.completions, 1);
          }
          for (final notifier in h.resultNotifiers) {
            expect(probe.count(notifier), 1);
          }
          expect(reports, isEmpty);
        });
      }

      for (final domain in [false, true]) {
        testWidgets('S1/S3 late ${domain ? 'domain' : 'success'} settlement', (
          tester,
        ) async {
          final h = AdminDashboardCommandHarness(lane, probe: probe)..request();
          await pumpCommandTurns(tester);
          expect(h.calls, 1);
          h.owner.dispose();
          final state = h.state();
          final notifications = h.notifications;
          await pumpPhysicalCommandDisposal(tester);
          if (lane != AdminDashboardLane.mutation) expect(h.completions, 0);
          final active = h.resultNotifiers[lane.index];
          expect(probe.count(active), 0);
          if (domain) {
            h.failDomain();
          } else {
            h.succeed();
          }
          await pumpPhysicalCommandDisposal(tester);
          if (lane != AdminDashboardLane.mutation) {
            await h.original;
            expect(h.completions, 1);
          }
          expect(h.state(), state);
          expect(h.notifications, notifications);
          expect(h.repository.dashboardCalls, hasLength(1));
          expect(probe.count(active), 1);
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        });
      }

      for (final failure in ['StateError', 'TypeError', 'AssertionError']) {
        testWidgets('S4/S6/E1 late $failure preserves original reporting', (
          tester,
        ) async {
          late AdminDashboardCommandHarness h;
          final uncaught = <Object>[];
          final uncaughtStacks = <StackTrace>[];
          runZonedGuarded(
            () {
              h = AdminDashboardCommandHarness(lane, probe: probe)..request();
            },
            (error, stack) {
              uncaught.add(error);
              uncaughtStacks.add(stack);
            },
          );
          await pumpCommandTurns(tester);
          h.owner.dispose();
          final state = h.state();
          final notifications = h.notifications;
          await pumpPhysicalCommandDisposal(tester);
          final error = switch (failure) {
            'StateError' => StateError('original dashboard runtime'),
            'TypeError' => TypeError(),
            _ => AssertionError('original dashboard assertion'),
          };
          final stack = StackTrace.fromString(
            '#0 originalDashboardRead (file:///dashboard_repository.dart:7:3)',
          );
          h.failRuntime(error, stack);
          await pumpPhysicalCommandDisposal(tester);
          if (lane != AdminDashboardLane.mutation) {
            await h.original;
            expect(h.completions, 1);
          }
          if (failure == 'AssertionError') {
            expect(uncaught, [same(error)]);
            expect(
              uncaughtStacks.single.toString(),
              contains('dashboard_repository.dart'),
            );
            expect(reports, isEmpty);
          } else {
            expect(reports, [same(error)]);
            expect(
              stacks.single.toString(),
              contains('dashboard_repository.dart'),
            );
            expect(uncaught, isEmpty);
          }
          expect(h.state(), state);
          expect(h.notifications, notifications);
          for (final notifier in h.resultNotifiers) {
            expect(probe.count(notifier), 1);
          }
          expect(h.repository.dashboardCalls, hasLength(1));
          expect(tester.takeException(), isNull);
        });
      }

      for (final completeFirst in [false, true]) {
        testWidgets('S5 same-turn settlement completeFirst=$completeFirst', (
          tester,
        ) async {
          final h = AdminDashboardCommandHarness(lane, probe: probe)..request();
          await pumpCommandTurns(tester);
          if (completeFirst) h.succeed();
          h.owner.dispose();
          if (!completeFirst) h.succeed();
          await pumpPhysicalCommandDisposal(tester);
          if (lane != AdminDashboardLane.mutation) {
            expect(h.completions, 1);
            await h.original;
          }
          for (final notifier in h.resultNotifiers) {
            expect(probe.count(notifier), 1);
          }
        });
      }

      testWidgets('S5/E3 revoke in terminal result notification', (
        tester,
      ) async {
        final h = AdminDashboardCommandHarness(lane, probe: probe)..request();
        await pumpCommandTurns(tester);
        var terminalObserved = false;
        h.resultNotifiers[lane.index].addListener(() {
          final result = h.resultNotifiers[lane.index].value as CommandResult;
          if (!result.isRunning) {
            terminalObserved = true;
            h.owner.dispose();
          }
        });
        h.succeed();
        await pumpPhysicalCommandDisposal(tester);
        expect(terminalObserved, isTrue);
        if (lane != AdminDashboardLane.mutation) {
          await h.original;
          expect(h.completions, 1);
        }
        for (final notifier in h.resultNotifiers) {
          expect(probe.count(notifier), 1);
        }
        expect(h.repository.dashboardCalls, hasLength(1));
      });

      testWidgets('S7 physical nontermination remains pending after revoke', (
        tester,
      ) async {
        final h = AdminDashboardCommandHarness(lane, probe: probe)..request();
        await pumpCommandTurns(tester);
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
        expect(h.calls, 1);
        expect(h.completions, 0);
        expect(probe.count(h.resultNotifiers[lane.index]), 0);
        // Test cleanup resolves the physical work after proving noncompletion;
        // production supplies no fabricated timeout or cancellation.
        h.succeed();
        await pumpPhysicalCommandDisposal(tester);
      });

      testWidgets('E1 live runtime terminal remains unexpected', (
        tester,
      ) async {
        final h = AdminDashboardCommandHarness(lane, probe: probe)..request();
        await pumpCommandTurns(tester);
        final error = StateError('live dashboard runtime');
        final stack = StackTrace.fromString(
          '#0 originalDashboardRead (file:///dashboard_repository.dart:9:3)',
        );
        h.failRuntime(error, stack);
        await pumpCommandTurns(tester);
        expect(h.snapshot.unexpectedError, same(error));
        expect(h.snapshot.domainError, isNull);
        expect(reports, [same(error)]);
        expect(stacks.single.toString(), contains('dashboard_repository.dart'));
        if (lane != AdminDashboardLane.mutation) {
          await h.original;
          expect(h.completions, 1);
        }
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
      });
    });
  }

  testWidgets('D1/D2/D4 independent lanes reserve before deferred entry', (
    tester,
  ) async {
    final repository = FakeAdminContentSubmissionRepository()
      ..pendingList = Completer<Result<List<AdminSubmission>>>()
      ..pendingIgnoredList = Completer<Result<List<AdminIgnoredSource>>>();
    final owner = AdminSubmissionsViewModel(repository: repository);
    expect(owner.loadSnapshot.idle, isTrue);
    final main = owner.refreshSubmissions();
    final ignored = owner.refreshIgnoredSources();
    expect(owner.loading, isTrue);
    expect(owner.loadIgnoredSnapshot.isRunning, isTrue);
    expect(owner.requestUnIgnore(12), isFalse);
    final mainSnapshot = owner.loadSnapshot;
    final ignoredSnapshot = owner.loadIgnoredSnapshot;
    await owner.refreshSubmissions();
    await owner.refreshIgnoredSources();
    expect(owner.loadSnapshot, same(mainSnapshot));
    expect(owner.loadIgnoredSnapshot, same(ignoredSnapshot));
    expect(repository.dashboardCalls, isEmpty);
    await pumpCommandTurns(tester);
    expect(repository.dashboardCalls, ['list', 'listIgnoredSources']);
    owner
      ..setFilter(AdminSubmissionStatus.accepted)
      ..setIgnoredFilter();
    expect(repository.dashboardCalls, hasLength(2));
    repository.pendingList!.complete(const Result.success([]));
    repository.pendingIgnoredList!.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    await main;
    await ignored;
    expect(owner.canUnIgnore, isTrue);
    expect(owner.items, isEmpty);
    owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  for (final mode in [
    'success',
    'ignored-domain',
    'main-domain',
    'both-domain',
    'ignored-runtime',
    'main-runtime',
    'both-runtime',
  ]) {
    testWidgets('D5/D7/D8 post-commit ordered refresh $mode', (tester) async {
      final h = AdminDashboardCommandHarness(
        AdminDashboardLane.mutation,
        probe: probe,
      );
      const source = AdminIgnoredSource(
        id: 12,
        provider: 'eventimolise',
        externalId: 'a',
        name: 'Old',
        ignoredAt: '2026-10-02T10:00:00Z',
      );
      final old = sampleAdminSubmission();
      h.repository
        ..listResult = Result.success([old])
        ..ignoredSourcesResult = const Result.success([source]);
      final initialMain = h.owner.refreshSubmissions();
      final initialIgnored = h.owner.refreshIgnoredSources();
      await pumpCommandTurns(tester);
      await initialMain;
      await initialIgnored;
      h.repository.dashboardCalls.clear();
      final ignored = Completer<Result<List<AdminIgnoredSource>>>();
      final main = Completer<Result<List<AdminSubmission>>>();
      h.repository
        ..pendingIgnoredList = ignored
        ..pendingList = main;
      h.request();
      expect(h.owner.requestUnIgnore(44), isFalse);
      await h.owner.refreshSubmissions();
      await h.owner.refreshIgnoredSources();
      expect(h.owner.unignoredPendingId, isNull);
      expect(h.owner.canOpenPendingSubmission, isFalse);
      await pumpCommandTurns(tester);
      expect(h.repository.dashboardCalls, ['unIgnoreSource:12']);
      h.succeed();
      await pumpCommandTurns(tester);
      expect(h.repository.dashboardCalls, [
        'unIgnoreSource:12',
        'listIgnoredSources',
      ]);
      expect(h.owner.unIgnoreSnapshot.isRunning, isTrue);
      expect(h.owner.unignoredPendingId, isNull);
      expect(h.owner.canOpenPendingSubmission, isFalse);
      h.owner.setIgnoredFilter();
      await h.owner.refreshIgnoredSources();
      final failIgnored = mode.startsWith('ignored') || mode.startsWith('both');
      final failMain = mode.startsWith('main') || mode.startsWith('both');
      final runtime = mode.endsWith('runtime');
      if (failIgnored && runtime) {
        ignored.completeError(
          StateError('ignored runtime'),
          StackTrace.current,
        );
      } else if (failIgnored) {
        ignored.complete(Result.error(TestException('ignored failed')));
      } else {
        ignored.complete(const Result.success([]));
      }
      await pumpCommandTurns(tester);
      expect(h.repository.dashboardCalls, [
        'unIgnoreSource:12',
        'listIgnoredSources',
        'list',
      ]);
      expect(h.owner.unIgnoreSnapshot.isRunning, isTrue);
      expect(h.owner.isUnIgnoring, isTrue);
      expect(h.owner.unignoredPendingId, isNull);
      expect(h.owner.canOpenPendingSubmission, isFalse);
      expect(h.owner.ignoredSources, failIgnored ? [source] : isEmpty);
      h.owner.setFilter(AdminSubmissionStatus.accepted);
      if (failMain && runtime) {
        main.completeError(StateError('main runtime'), StackTrace.current);
      } else if (failMain) {
        main.complete(Result.error(TestException('main failed')));
      } else {
        main.complete(Result.success([sampleAdminSubmission(id: 8)]));
      }
      await pumpCommandTurns(tester);
      expect(h.owner.unIgnoreSnapshot.completed, isTrue);
      expect(h.owner.isUnIgnoring, isFalse);
      expect(h.owner.canOpenPendingSubmission, isTrue);
      expect(h.owner.unignoredPendingId, 8);
      expect(h.owner.items.single.id, failMain ? 1 : 8);
      expect(h.owner.loadSnapshot.hasFailure, failMain);
      expect(h.owner.loadIgnoredSnapshot.hasFailure, failIgnored);
      expect(
        reports,
        hasLength(runtime ? (failIgnored ? 1 : 0) + (failMain ? 1 : 0) : 0),
      );
      expect(h.repository.unIgnoreCalls, [12]);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
    });
  }

  for (final second in [false, true]) {
    testWidgets(
      'S8/D9 dispose during internal ${second ? 'main' : 'ignored'}',
      (tester) async {
        final h = AdminDashboardCommandHarness(
          AdminDashboardLane.mutation,
          probe: probe,
        );
        final ignored = Completer<Result<List<AdminIgnoredSource>>>();
        final main = Completer<Result<List<AdminSubmission>>>();
        h.repository
          ..pendingIgnoredList = ignored
          ..pendingList = main;
        h.request();
        await pumpCommandTurns(tester);
        h.succeed();
        await pumpCommandTurns(tester);
        if (second) {
          ignored.complete(const Result.success([]));
          await pumpCommandTurns(tester);
          expect(h.repository.listCallCount, 1);
        }
        h.owner.dispose();
        final state = h.state();
        final notifications = h.notifications;
        await pumpPhysicalCommandDisposal(tester);
        if (second) {
          main.complete(Result.success([sampleAdminSubmission(id: 8)]));
        } else {
          ignored.complete(const Result.success([]));
        }
        await pumpPhysicalCommandDisposal(tester);
        expect(h.repository.listCallCount, second ? 1 : 0);
        expect(h.owner.unignoredPendingId, isNull);
        expect(h.owner.canOpenPendingSubmission, isFalse);
        expect(h.state(), state);
        expect(h.notifications, notifications);
        for (final notifier in h.resultNotifiers) {
          expect(probe.count(notifier), 1);
        }
      },
    );
  }

  testWidgets('S6/E2 internal assertion abort never starts second refresh', (
    tester,
  ) async {
    late AdminDashboardCommandHarness h;
    final uncaught = <Object>[];
    late Completer<Result<List<AdminIgnoredSource>>> ignored;
    runZonedGuarded(() {
      ignored = Completer<Result<List<AdminIgnoredSource>>>();
      h = AdminDashboardCommandHarness(
        AdminDashboardLane.mutation,
        probe: probe,
      );
      h.repository.pendingIgnoredList = ignored;
      h.request();
    }, (error, _) => uncaught.add(error));
    await pumpCommandTurns(tester);
    h.succeed();
    await pumpCommandTurns(tester);
    final failure = AssertionError('internal assertion');
    ignored.completeError(failure, StackTrace.current);
    await pumpCommandTurns(tester);
    expect(uncaught, [same(failure)]);
    expect(reports, isEmpty);
    expect(h.repository.listCallCount, 0);
    expect(h.owner.canUnIgnore, isTrue);
    expect(h.owner.isUnIgnoring, isFalse);
    expect(h.owner.unIgnoreSnapshot.completed, isFalse);
    expect(h.owner.unignoredPendingId, isNull);
    expect(h.owner.canOpenPendingSubmission, isFalse);
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
    for (final notifier in h.resultNotifiers) {
      expect(probe.count(notifier), 1);
    }
  });

  for (final lane in [
    AdminDashboardLane.submissions,
    AdminDashboardLane.ignored,
  ]) {
    testWidgets('E3 ${lane.name} reentrant next intent survives old finally', (
      tester,
    ) async {
      final h = AdminDashboardCommandHarness(lane, probe: probe);
      final nextMain = Completer<Result<List<AdminSubmission>>>();
      final nextIgnored = Completer<Result<List<AdminIgnoredSource>>>();
      Future<void>? second;
      var reentered = false;
      h.owner.addListener(() {
        if (!reentered && h.snapshot.completed && h.owner.canUnIgnore) {
          reentered = true;
          h.repository
            ..pendingList = nextMain
            ..pendingIgnoredList = nextIgnored;
          second = lane == AdminDashboardLane.submissions
              ? h.owner.refreshSubmissions()
              : h.owner.refreshIgnoredSources();
        }
      });
      h.request();
      await pumpCommandTurns(tester);
      h.succeed();
      await pumpCommandTurns(tester);
      expect(reentered, isTrue);
      expect(h.calls, 2);
      expect(h.owner.canUnIgnore, isFalse);
      expect(h.snapshot.isRunning, isTrue);
      if (lane == AdminDashboardLane.submissions) {
        await h.owner.refreshSubmissions();
        nextMain.complete(const Result.success([]));
      } else {
        await h.owner.refreshIgnoredSources();
        nextIgnored.complete(const Result.success([]));
      }
      await pumpCommandTurns(tester);
      await h.original;
      await second;
      expect(h.calls, 2);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
    });
  }

  for (final lane in [
    AdminDashboardLane.submissions,
    AdminDashboardLane.ignored,
  ]) {
    testWidgets('S5/E3 ${lane.name} owner terminal notify revokes forwarding', (
      tester,
    ) async {
      final h = AdminDashboardCommandHarness(lane, probe: probe);
      var terminalNotifications = 0;
      h.owner.addListener(() {
        if (h.snapshot.completed) {
          terminalNotifications++;
          h.owner.dispose();
          expectSync(probe.count(h.owner), 0);
          expectSync(probe.count(h.resultNotifiers[lane.index]), 0);
        }
      });
      h.request();
      await pumpCommandTurns(tester);
      h.succeed();
      await pumpPhysicalCommandDisposal(tester);
      await h.original;
      expect(h.completions, 1);
      expect(terminalNotifications, 1);
      expect(h.calls, 1);
      for (final notifier in h.resultNotifiers) {
        expect(probe.count(notifier), 1);
      }
      expect(probe.count(h.owner), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('E3 atomic mutation success notification can revoke owner', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.mutation,
      probe: probe,
    );
    var successes = 0;
    h.owner.addListener(() {
      if (h.owner.unIgnoreSnapshot.completed) {
        successes++;
        expectSync(h.owner.canOpenPendingSubmission, isTrue);
        expectSync(h.owner.unignoredPendingId, 8);
        h.owner.dispose();
        expectSync(probe.count(h.owner), 0);
        for (final notifier in h.resultNotifiers) {
          expectSync(probe.count(notifier), 0);
        }
      }
    });
    h.request();
    await pumpCommandTurns(tester);
    h.succeed();
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    await pumpPhysicalCommandDisposal(tester);
    expect(successes, 1);
    expect(h.owner.canOpenPendingSubmission, isFalse);
    expect(h.repository.dashboardCalls, [
      'unIgnoreSource:12',
      'listIgnoredSources',
      'list',
    ]);
    for (final notifier in h.resultNotifiers) {
      expect(probe.count(notifier), 1);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'E3/D6 final mutation notify admits next exclusive attempt safely',
    (tester) async {
      final h = AdminDashboardCommandHarness(
        AdminDashboardLane.mutation,
        probe: probe,
      );
      final second = Completer<Result<AdminEventResolution>>();
      var reentered = false;
      var successes = 0;
      h.owner.addListener(() {
        if (!reentered && h.owner.unIgnoreSnapshot.completed) {
          successes++;
          expectSync(h.owner.canOpenPendingSubmission, isTrue);
          reentered = true;
          h.repository.pendingUnIgnore = second;
          expectSync(h.owner.requestUnIgnore(44), isTrue);
          expectSync(h.owner.unignoredPendingId, isNull);
          expectSync(h.owner.canOpenPendingSubmission, isFalse);
          expectSync(h.owner.isUnIgnoring, isTrue);
          expectSync(h.owner.requestUnIgnore(99), isFalse);
        }
      });
      h.request();
      await pumpCommandTurns(tester);
      h.succeed();
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      expect(successes, 1);
      expect(h.repository.unIgnoreCalls, [12, 44]);
      expect(h.owner.isUnIgnoring, isTrue);
      expect(h.owner.unIgnoreSnapshot.isRunning, isTrue);
      await h.owner.refreshSubmissions();
      await h.owner.refreshIgnoredSources();
      expect(h.repository.listCallCount, 1);
      expect(h.repository.ignoredListCalls, 1);
      second.complete(Result.error(TestException('second mutation failed')));
      await pumpCommandTurns(tester);
      expect(h.owner.unIgnoreSnapshot.hasFailure, isTrue);
      expect(h.owner.isUnIgnoring, isFalse);
      expect(h.owner.unignoredPendingId, isNull);
      expect(h.owner.canOpenPendingSubmission, isFalse);
      expect(h.repository.listCallCount, 1);
      expect(h.repository.ignoredListCalls, 1);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'F5.1 editor obligation waits for manual read then fetches fresh',
    (tester) async {
      final h = AdminDashboardCommandHarness(
        AdminDashboardLane.submissions,
        probe: probe,
      )..request();
      await pumpCommandTurns(tester);
      final fresh = Completer<Result<List<AdminSubmission>>>();
      var completed = 0;
      final changed = h.owner.refreshAfterEditorChange();
      unawaited(changed.then((_) => completed++));
      await pumpCommandTurns(tester);
      expect(h.calls, 1);
      expect(completed, 0);
      h.repository.pendingList = fresh;
      h.succeed();
      await pumpCommandTurns(tester);
      expect(h.calls, 2);
      expect(completed, 0);
      fresh.complete(Result.success([sampleAdminSubmission(id: 99)]));
      await pumpCommandTurns(tester);
      await changed;
      await h.original;
      expect(h.owner.items.single.id, 99);
      expect(completed, 1);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
    },
  );

  testWidgets('F5.3 same-turn editor events coalesce before admission', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.submissions,
      probe: probe,
    );
    var completed = 0;
    final first = h.owner.refreshAfterEditorChange();
    final second = h.owner.refreshAfterEditorChange();
    final third = h.owner.refreshAfterEditorChange();
    for (final future in [first, second, third]) {
      unawaited(future.then((_) => completed++));
    }
    expect(h.calls, 0);
    await pumpCommandTurns(tester);
    expect(h.calls, 1);
    expect(completed, 0);
    h.succeed();
    await pumpCommandTurns(tester);
    await Future.wait([first, second, third]);
    expect(completed, 3);
    expect(h.calls, 1);
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  testWidgets('F5.3 event during post-editor read requires a newer read', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.submissions,
      probe: probe,
    );
    final first = h.owner.refreshAfterEditorChange();
    var completed = 0;
    unawaited(first.then((_) => completed++));
    await pumpCommandTurns(tester);
    expect(h.calls, 1);
    final fresh = Completer<Result<List<AdminSubmission>>>();
    h.repository.pendingList = fresh;
    final second = h.owner.refreshAfterEditorChange();
    unawaited(second.then((_) => completed++));
    h.succeed();
    await pumpCommandTurns(tester);
    expect(h.calls, 2);
    expect(completed, 1);
    fresh.complete(Result.success([sampleAdminSubmission(id: 99)]));
    await pumpCommandTurns(tester);
    await Future.wait([first, second]);
    expect(completed, 2);
    expect(h.owner.items.single.id, 99);
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  testWidgets('F5.3 captured batch finishes before newer pending changes', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.submissions,
      probe: probe,
    );
    h.owner.setIgnoredFilter();
    var firstDone = false;
    var secondDone = false;
    final first = h.owner.refreshAfterEditorChange();
    unawaited(first.then((_) => firstDone = true));
    await pumpCommandTurns(tester);
    final fresh = Completer<Result<List<AdminSubmission>>>();
    final oldIgnored = Completer<Result<List<AdminIgnoredSource>>>();
    h.repository
      ..pendingList = fresh
      ..pendingIgnoredList = oldIgnored;
    final second = h.owner.refreshAfterEditorChange();
    unawaited(second.then((_) => secondDone = true));
    h.succeed();
    await pumpCommandTurns(tester);
    expect(h.repository.dashboardCalls, ['list', 'listIgnoredSources']);
    expect(firstDone, isFalse);
    expect(secondDone, isFalse);
    oldIgnored.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(firstDone, isTrue);
    expect(secondDone, isFalse);
    expect(h.repository.listCallCount, 2);
    h.repository.pendingIgnoredList = null;
    fresh.complete(Result.success([sampleAdminSubmission(id: 99)]));
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    await Future.wait([first, second]);
    expect(secondDone, isTrue);
    expect(h.repository.dashboardCalls, [
      'list',
      'listIgnoredSources',
      'list',
      'listIgnoredSources',
    ]);
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  for (final phase in ['mutation', 'ignored', 'submissions']) {
    testWidgets('F5.2 editor change survives exclusive $phase phase', (
      tester,
    ) async {
      final h = AdminDashboardCommandHarness(
        AdminDashboardLane.mutation,
        probe: probe,
      );
      final ignored = Completer<Result<List<AdminIgnoredSource>>>();
      final main = Completer<Result<List<AdminSubmission>>>();
      final fresh = Completer<Result<List<AdminSubmission>>>();
      h.repository
        ..pendingIgnoredList = ignored
        ..pendingList = main;
      h.request();
      await pumpCommandTurns(tester);
      Future<void>? changed;
      var completed = 0;
      if (phase == 'mutation') {
        changed = h.owner.refreshAfterEditorChange();
        unawaited(changed.then((_) => completed++));
      }
      h.succeed();
      await pumpCommandTurns(tester);
      expect(h.repository.ignoredListCalls, 1);
      expect(h.repository.listCallCount, 0);
      if (phase == 'ignored') {
        changed = h.owner.refreshAfterEditorChange();
        unawaited(changed.then((_) => completed++));
      }
      ignored.complete(const Result.success([]));
      await pumpCommandTurns(tester);
      expect(h.repository.listCallCount, 1);
      if (phase == 'submissions') {
        changed = h.owner.refreshAfterEditorChange();
        unawaited(changed.then((_) => completed++));
      }
      await pumpCommandTurns(tester);
      expect(completed, 0);
      expect(h.owner.isUnIgnoring, isTrue);
      expect(h.owner.unignoredPendingId, isNull);
      expect(h.owner.canOpenPendingSubmission, isFalse);
      h.repository.pendingList = fresh;
      main.complete(Result.success([sampleAdminSubmission(id: 8)]));
      await pumpCommandTurns(tester);
      expect(h.owner.isUnIgnoring, isFalse);
      expect(h.owner.unIgnoreSnapshot.completed, isTrue);
      expect(h.owner.unignoredPendingId, 8);
      expect(h.owner.canOpenPendingSubmission, isTrue);
      expect(h.repository.listCallCount, 2);
      expect(h.repository.ignoredListCalls, 1);
      expect(completed, 0);
      fresh.complete(Result.success([sampleAdminSubmission(id: 99)]));
      await pumpCommandTurns(tester);
      await changed;
      expect(completed, 1);
      expect(h.owner.items.single.id, 99);
      expect(h.repository.unIgnoreCalls, [12]);
      expect(h.repository.dashboardCalls, [
        'unIgnoreSource:12',
        'listIgnoredSources',
        'list',
        'list',
      ]);
      expect(h.owner.canOpenPendingSubmission, isTrue);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
    });
  }

  testWidgets('F5.4 ignored lane drains before a fresh selected ignored read', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.ignored,
      probe: probe,
    );
    h.owner.setIgnoredFilter();
    h.request();
    await pumpCommandTurns(tester);
    final changed = h.owner.refreshAfterEditorChange();
    var completed = 0;
    unawaited(changed.then((_) => completed++));
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    expect(h.repository.listCallCount, 1);
    expect(h.repository.ignoredListCalls, 1);
    expect(completed, 0);
    final fresh = Completer<Result<List<AdminIgnoredSource>>>();
    h.repository.pendingIgnoredList = fresh;
    h.succeed();
    await pumpCommandTurns(tester);
    expect(h.repository.ignoredListCalls, 2);
    expect(completed, 0);
    fresh.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    await changed;
    await h.original;
    expect(completed, 1);
    expect(h.owner.ignoredSources, isEmpty);
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  for (final showIgnored in [false, true]) {
    testWidgets(
      'F5.5 final filter selection ignored=$showIgnored controls second list',
      (tester) async {
        final h = AdminDashboardCommandHarness(
          AdminDashboardLane.submissions,
          probe: probe,
        );
        if (!showIgnored) h.owner.setIgnoredFilter();
        final changed = h.owner.refreshAfterEditorChange();
        await pumpCommandTurns(tester);
        if (showIgnored) {
          h.owner.setIgnoredFilter();
        } else {
          h.owner.setFilter(null);
        }
        h.succeed();
        await pumpCommandTurns(tester);
        await pumpCommandTurns(tester);
        await changed;
        expect(h.repository.listCallCount, 1);
        expect(h.repository.ignoredListCalls, showIgnored ? 1 : 0);
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
      },
    );
  }

  testWidgets('F5.3 newer event during ignored read restarts ordered refresh', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.ignored,
      probe: probe,
    );
    h.owner.setIgnoredFilter();
    final first = h.owner.refreshAfterEditorChange();
    var completed = 0;
    unawaited(first.then((_) => completed++));
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    expect(h.repository.dashboardCalls, ['list', 'listIgnoredSources']);
    final freshMain = Completer<Result<List<AdminSubmission>>>();
    final freshIgnored = Completer<Result<List<AdminIgnoredSource>>>();
    h.repository
      ..pendingList = freshMain
      ..pendingIgnoredList = freshIgnored;
    final second = h.owner.refreshAfterEditorChange();
    unawaited(second.then((_) => completed++));
    h.succeed();
    await pumpCommandTurns(tester);
    expect(h.repository.listCallCount, 2);
    expect(completed, 1);
    freshMain.complete(Result.success([sampleAdminSubmission(id: 99)]));
    await pumpCommandTurns(tester);
    expect(h.repository.ignoredListCalls, 2);
    expect(completed, 1);
    freshIgnored.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    await Future.wait([first, second]);
    expect(completed, 2);
    expect(h.owner.items.single.id, 99);
    expect(h.owner.ignoredSources, isEmpty);
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  for (final failure in ['domain', 'runtime']) {
    testWidgets(
      'F5.7 $failure settles obligation once without retry or rethrow',
      (tester) async {
        final h = AdminDashboardCommandHarness(
          AdminDashboardLane.submissions,
          probe: probe,
        );
        h.owner.setIgnoredFilter();
        final changed = h.owner.refreshAfterEditorChange();
        var completed = 0;
        unawaited(changed.then((_) => completed++));
        await pumpCommandTurns(tester);
        final error = StateError('post-editor original failure');
        if (failure == 'domain') {
          h.failDomain();
        } else {
          h.failRuntime(
            error,
            StackTrace.fromString(
              '#0 originalEditorRead (file:///editor_repository.dart:7:3)',
            ),
          );
        }
        await pumpCommandTurns(tester);
        await pumpCommandTurns(tester);
        await changed;
        expect(completed, 1);
        expect(h.repository.listCallCount, 1);
        expect(h.repository.ignoredListCalls, 1);
        expect(h.owner.loadSnapshot.hasFailure, isTrue);
        expect(reports, failure == 'runtime' ? [same(error)] : isEmpty);
        if (failure == 'runtime') {
          expect(stacks.single.toString(), contains('editor_repository.dart'));
        }
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
      },
    );
  }

  testWidgets(
    'F5.6 dispose settles coordinator while physical receipt stays pending',
    (tester) async {
      final h = AdminDashboardCommandHarness(
        AdminDashboardLane.submissions,
        probe: probe,
      )..request();
      await pumpCommandTurns(tester);
      final changed = h.owner.refreshAfterEditorChange();
      var completed = 0;
      unawaited(changed.then((_) => completed++));
      h.owner.dispose();
      final state = h.state();
      final notifications = h.notifications;
      await pumpPhysicalCommandDisposal(tester);
      await changed;
      expect(completed, 1);
      expect(h.completions, 0);
      expect(probe.count(h.resultNotifiers.first), 0);
      final replacement = AdminSubmissionsViewModel(
        repository: FakeAdminContentSubmissionRepository(
          listResult: Result.success([sampleAdminSubmission(id: 123)]),
        ),
      );
      final replacementRefresh = replacement.refreshAfterEditorChange();
      await pumpCommandTurns(tester);
      await replacementRefresh;
      expect(replacement.items.single.id, 123);
      expect(h.completions, 0);
      h.succeed();
      await pumpPhysicalCommandDisposal(tester);
      await h.original;
      expect(h.completions, 1);
      expect(h.repository.listCallCount, 1);
      expect(h.state(), state);
      expect(h.notifications, notifications);
      expect(probe.count(h.resultNotifiers.first), 1);
      expect(replacement.items.single.id, 123);
      replacement.dispose();
      await pumpPhysicalCommandDisposal(tester);
    },
  );

  testWidgets('F5.6 dispose before drain entry revokes queued coordination', (
    tester,
  ) async {
    final h = AdminDashboardCommandHarness(
      AdminDashboardLane.submissions,
      probe: probe,
    );
    var completed = 0;
    final changed = h.owner.refreshAfterEditorChange();
    unawaited(changed.then((_) => completed++));
    h.owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
    await changed;
    expect(completed, 1);
    expect(h.repository.dashboardCalls, isEmpty);
    expect(h.owner.isDisposed, isTrue);
  });

  for (final ignored in [false, true]) {
    testWidgets('F5.6 dispose during editor-owned read ignored=$ignored', (
      tester,
    ) async {
      final lane = ignored
          ? AdminDashboardLane.ignored
          : AdminDashboardLane.submissions;
      final h = AdminDashboardCommandHarness(lane, probe: probe);
      h.owner.setIgnoredFilter();
      var completed = 0;
      final changed = h.owner.refreshAfterEditorChange();
      unawaited(changed.then((_) => completed++));
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      expect(h.calls, 1);
      expect(completed, 0);
      final calls = [...h.repository.dashboardCalls];
      h.owner.dispose();
      final state = h.state();
      final notifications = h.notifications;
      await pumpPhysicalCommandDisposal(tester);
      await changed;
      expect(completed, 1);
      expect(probe.count(h.resultNotifiers[lane.index]), 0);
      h.succeed();
      await pumpPhysicalCommandDisposal(tester);
      expect(probe.count(h.resultNotifiers[lane.index]), 1);
      expect(completed, 1);
      expect(h.repository.dashboardCalls, calls);
      expect(h.state(), state);
      expect(h.notifications, notifications);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'F5 assertion abort settles obligation without ignored continuation',
    (tester) async {
      late AdminDashboardCommandHarness h;
      late Future<void> changed;
      final uncaught = <Object>[];
      var completed = 0;
      runZonedGuarded(() {
        h = AdminDashboardCommandHarness(
          AdminDashboardLane.submissions,
          probe: probe,
        );
        h.owner.setIgnoredFilter();
        changed = h.owner.refreshAfterEditorChange();
        unawaited(changed.then((_) => completed++));
      }, (error, _) => uncaught.add(error));
      await pumpCommandTurns(tester);
      final failure = AssertionError('post-editor assertion');
      h.failRuntime(failure, StackTrace.current);
      await pumpCommandTurns(tester);
      await changed;
      expect(completed, 1);
      expect(uncaught, [same(failure)]);
      expect(reports, isEmpty);
      expect(h.repository.listCallCount, 1);
      expect(h.repository.ignoredListCalls, 0);
      expect(h.owner.loadSnapshot.completed, isFalse);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
    },
  );

  for (final failure in ['domain', 'runtime']) {
    testWidgets('F5.7 prior manual $failure still drains into a fresh read', (
      tester,
    ) async {
      final h = AdminDashboardCommandHarness(
        AdminDashboardLane.submissions,
        probe: probe,
      )..request();
      await pumpCommandTurns(tester);
      final fresh = Completer<Result<List<AdminSubmission>>>();
      h.repository.pendingList = fresh;
      final changed = h.owner.refreshAfterEditorChange();
      var completed = 0;
      unawaited(changed.then((_) => completed++));
      final error = StateError('prior read runtime');
      if (failure == 'domain') {
        h.failDomain();
      } else {
        h.failRuntime(error, StackTrace.current);
      }
      await pumpCommandTurns(tester);
      expect(h.repository.listCallCount, 2);
      expect(completed, 0);
      expect(reports, failure == 'runtime' ? [same(error)] : isEmpty);
      fresh.complete(Result.success([sampleAdminSubmission(id: 99)]));
      await pumpCommandTurns(tester);
      await changed;
      await h.original;
      expect(completed, 1);
      expect(h.owner.items.single.id, 99);
      expect(h.repository.unIgnoreCalls, isEmpty);
      h.owner.dispose();
      await pumpPhysicalCommandDisposal(tester);
    });
  }

  for (final phase in ['running', 'terminal', 'safe']) {
    testWidgets(
      'F5.9 reentrant registration from $phase notification is retained',
      (tester) async {
        final h = AdminDashboardCommandHarness(
          AdminDashboardLane.submissions,
          probe: probe,
        );
        final fresh = Completer<Result<List<AdminSubmission>>>();
        Future<void>? changed;
        var registered = false;
        var completed = 0;
        h.owner.addListener(() {
          final reached = switch (phase) {
            'running' => h.owner.loadSnapshot.isRunning,
            'terminal' => h.owner.loadSnapshot.completed && h.owner.loading,
            _ => h.owner.loadSnapshot.completed && h.owner.canUnIgnore,
          };
          if (!registered && reached) {
            registered = true;
            changed = h.owner.refreshAfterEditorChange();
            unawaited(changed!.then((_) => completed++));
          }
        });
        h.request();
        await pumpCommandTurns(tester);
        h.repository.pendingList = fresh;
        h.succeed();
        await pumpCommandTurns(tester);
        expect(registered, isTrue);
        expect(h.repository.listCallCount, 2);
        expect(completed, 0);
        fresh.complete(Result.success([sampleAdminSubmission(id: 99)]));
        await pumpCommandTurns(tester);
        await changed;
        await h.original;
        expect(completed, 1);
        expect(h.repository.listCallCount, 2);
        expect(h.owner.items.single.id, 99);
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
      },
    );
  }
}
