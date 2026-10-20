import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result_command.dart';

import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  late DisposalEventProbe disposals;
  late List<Object> reports;
  late List<StackTrace> stacks;

  setUp(() {
    disposals = DisposalEventProbe();
    addTearDown(disposals.dispose);
    reports = [];
    stacks = [];
    final previous = Command.globalExceptionHandler;
    final reportAll = Command.reportAllExceptions;
    addTearDown(() {
      Command.globalExceptionHandler = previous;
      Command.reportAllExceptions = reportAll;
    });
    Command.reportAllExceptions = false;
    Command.globalExceptionHandler = (error, stack) {
      reports.add(error.error);
      stacks.add(stack);
    };
  });

  for (final lane in OrdinaryOwnerLane.values) {
    group(lane.name, () {
      testWidgets(
        'revocation before deferred entry starts no repository phase',
        (tester) async {
          final harness = OrdinaryOwnerHarness(lane)..begin();
          final state = harness.state();
          final notifications = harness.notifications;
          harness.owner.dispose();
          harness.gate.complete();
          await pumpPhysicalCommandDisposal(tester);
          expect(harness.repositoryCalls(), 0);
          expect(harness.state(), state);
          expect(harness.notifications, notifications);
          expect(disposals.count(harness.owner), 1);
          expect(disposals.count(harness.command), 1);
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );

      for (final error in [false, true]) {
        testWidgets('pending ${error ? 'domain error' : 'success'} '
            'retains command until settlement', (tester) async {
          final harness = OrdinaryOwnerHarness(lane)..begin();
          await pumpCommandTurns(tester);
          expect(harness.command.isRunningSync.value, isTrue);
          final state = harness.state();
          final notifications = harness.notifications;
          harness.owner.dispose();
          harness.owner.dispose();
          expectSync(disposals.count(harness.command), 0);
          await pumpPhysicalCommandDisposal(tester);
          expect(disposals.count(harness.owner), 1);
          expectSync(disposals.count(harness.command), 0);
          if (harness.otherCommand != null) {
            expect(disposals.count(harness.otherCommand!), 1);
          }
          harness.expectedError = error
              ? TestException('late domain error')
              : null;
          harness.gate.complete();
          await pumpPhysicalCommandDisposal(tester);
          expect(harness.state(), state);
          expect(harness.notifications, notifications);
          expect(disposals.count(harness.command), 1);
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        });
      }

      for (final source in ['results', 'value']) {
        testWidgets(
          'terminal $source listener disposes without reentrant teardown',
          (tester) async {
            final harness = OrdinaryOwnerHarness(lane);
            var observed = false;
            void terminal() {
              if (source == 'results' &&
                  !harness.command.results.value.completed) {
                return;
              }
              if (source == 'value') {
                expectSync(harness.command.isRunningSync.value, isFalse);
              }
              observed = true;
              harness.owner.dispose();
              expectSync(disposals.count(harness.owner), 0);
              expectSync(disposals.count(harness.command), 0);
            }

            if (source == 'results') {
              harness.command.results.addListener(terminal);
            } else {
              harness.command.addListener(terminal);
            }
            harness.begin();
            await pumpCommandTurns(tester);
            harness.gate.complete();
            await pumpPhysicalCommandDisposal(tester);
            expect(observed, isTrue);
            expect(disposals.count(harness.owner), 1);
            expect(disposals.count(harness.command), 1);
            expect(reports, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );
      }

      for (final completeFirst in [true, false]) {
        testWidgets(
          'settlement and dispose in same turn: completeFirst=$completeFirst',
          (tester) async {
            final harness = OrdinaryOwnerHarness(lane)..begin();
            await pumpCommandTurns(tester);
            if (completeFirst) {
              harness.gate.complete();
            }
            harness.owner.dispose();
            if (!completeFirst) {
              harness.gate.complete();
            }
            await pumpPhysicalCommandDisposal(tester);
            expect(disposals.count(harness.command), 1);
            expect(reports, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );
      }

      for (final failure in ['StateError', 'ArgumentError', 'AssertionError']) {
        testWidgets('late $failure preserves upstream reporting policy', (
          tester,
        ) async {
          late OrdinaryOwnerHarness harness;
          final uncaught = <Object>[];
          final uncaughtStacks = <StackTrace>[];
          runZonedGuarded(
            () {
              harness = OrdinaryOwnerHarness(lane)..begin();
            },
            (error, stack) {
              uncaught.add(error);
              uncaughtStacks.add(stack);
            },
          );
          await pumpCommandTurns(tester);
          harness.owner.dispose();
          await pumpPhysicalCommandDisposal(tester);
          final error = switch (failure) {
            'StateError' => StateError('original late failure'),
            'ArgumentError' => ArgumentError('original late failure'),
            _ => AssertionError('original late assertion'),
          };
          final stack = StackTrace.fromString(
            '#0 originalRepositoryWrite (file:///ordinary_repository.dart:7:3)',
          );
          harness.gate.completeError(error, stack);
          await pumpPhysicalCommandDisposal(tester);
          if (failure == 'AssertionError') {
            expect(Command.assertionsAlwaysThrow, isTrue);
            expect(uncaught, [same(error)]);
            expect(
              uncaughtStacks.single.toString(),
              contains('ordinary_repository.dart'),
            );
            expect(harness.command.results.value.domainError, isNull);
            expect(reports, isEmpty);
          } else {
            expect(uncaught, isEmpty);
            expect(reports, [same(error)]);
            expect(
              stacks.single.toString(),
              contains('ordinary_repository.dart'),
            );
          }
          expect(disposals.count(harness.command), 1);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets(
        'transition after revocation invalidates queued idle barrier',
        (tester) async {
          final harness = OrdinaryOwnerHarness(lane)..begin();
          harness.gate.complete();
          await pumpCommandTurns(tester);
          final calls = harness.repositoryCalls();
          final state = harness.state();
          final notifications = harness.notifications;
          harness.owner.dispose();
          final transitions = <bool>[];
          harness.command.isRunningSync.addListener(() {
            transitions.add(harness.command.isRunningSync.value);
            expectSync(disposals.count(harness.command), 0);
          });
          harness.start();
          expectSync(disposals.count(harness.command), 0);
          await pumpPhysicalCommandDisposal(tester);
          expect(harness.repositoryCalls(), calls);
          expect(transitions, [true, false]);
          expect(harness.state(), state);
          expect(harness.notifications, notifications);
          expect(disposals.count(harness.command), 1);
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'completed owner releases exactly once outside dispose stack',
        (tester) async {
          final harness = OrdinaryOwnerHarness(lane)..begin();
          harness.gate.complete();
          await pumpCommandTurns(tester);
          expect(harness.command.isRunningSync.value, isFalse);
          harness.owner.dispose();
          expectSync(disposals.count(harness.command), 0);
          harness.owner.dispose();
          await pumpPhysicalCommandDisposal(tester);
          expect(disposals.count(harness.owner), 1);
          expect(disposals.count(harness.command), 1);
          expect(tester.takeException(), isNull);
        },
      );

      if ([
        OrdinaryOwnerLane.categorySort,
        OrdinaryOwnerLane.settings,
        OrdinaryOwnerLane.brightness,
        OrdinaryOwnerLane.themeType,
      ].contains(lane)) {
        testWidgets('optimistic notification revokes before persistence', (
          tester,
        ) async {
          final harness = OrdinaryOwnerHarness(lane);
          harness.owner.addListener(harness.owner.dispose);
          harness.begin();
          await pumpPhysicalCommandDisposal(tester);
          expect(harness.repositoryCalls(), 0);
          expect(harness.notifications, 1);
          expect(disposals.count(harness.owner), 1);
          expect(disposals.count(harness.command), 1);
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        });

        testWidgets('never-run owner releases outside dispose stack', (
          tester,
        ) async {
          final harness = OrdinaryOwnerHarness(lane);
          expect(harness.command.results.value.idle, isTrue);
          harness.owner.dispose();
          expectSync(disposals.count(harness.command), 0);
          await pumpPhysicalCommandDisposal(tester);
          expect(disposals.count(harness.command), 1);
          expect(disposals.count(harness.owner), 1);
        });
      }
    });
  }

  testWidgets('Favourite forwarding can revoke owner during VM notification', (
    tester,
  ) async {
    final harness = OrdinaryOwnerHarness(OrdinaryOwnerLane.favourite);
    var revoked = false;
    harness.owner.addListener(() {
      if (harness.command.results.value.completed) {
        revoked = true;
        harness.owner.dispose();
        expectSync(disposals.count(harness.owner), 0);
      }
    });
    await pumpCommandTurns(tester);
    harness.gate.complete();
    await pumpPhysicalCommandDisposal(tester);
    expect(revoked, isTrue);
    expect(disposals.count(harness.owner), 1);
    expect(disposals.count(harness.command), 1);
    expect(reports, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
