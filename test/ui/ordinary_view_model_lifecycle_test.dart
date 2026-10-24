import 'dart:async';
import 'dart:io';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../support/command_test_support.dart';
import '../support/content_submission_command_harness.dart';
import '../support/fake_repositories.dart';
import '../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  late DisposalEventProbe disposals;
  late List<Object> reports;
  late List<StackTrace> stacks;
  late List<Command<dynamic, dynamic>> reportedCommands;

  setUp(() {
    disposals = DisposalEventProbe();
    addTearDown(disposals.dispose);
    reports = [];
    stacks = [];
    reportedCommands = [];
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
      final command = error.command;
      if (command != null) {
        command.addListener(() {});
        reportedCommands.add(command);
      }
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

  group('Content Submission private ordinary owners D1-D4', () {
    for (final lane in SubmissionOwnerLane.values) {
      group(lane.name, () {
        testSubmissionOwnerLifecycle(
          'D1 revoke before deferred entry starts no phase',
          (tester) async {
            final harness = SubmissionOwnerHarness(lane, probe: disposals);
            await harness.initialize();
            final calls = harness.calls;
            expect(harness.request(), isTrue);
            expect(harness.running, isTrue);
            final state = harness.state();
            final notifications = harness.notifications;
            harness.owner.dispose();
            harness.gate.complete();
            await pumpPhysicalCommandDisposal(tester);
            expect(harness.calls, calls);
            expect(harness.state(), state);
            expect(harness.notifications, notifications);
            expect(harness.request(), isFalse);
            expect(disposals.count(harness.owner), 1);
            expect(reports, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );

        for (final domainError in [false, true]) {
          testSubmissionOwnerLifecycle(
            'D2 late ${domainError ? 'domain error' : 'success'} '
            'retains private settlement beyond 50ms',
            (tester) async {
              final harness = SubmissionOwnerHarness(lane, probe: disposals);
              await harness.initialize();
              expect(harness.request(), isTrue);
              await pumpCommandTurns(tester);
              expect(harness.entered, 1);
              expect(harness.resultNotifiers, hasLength(5));
              final activeNotifier = harness.resultNotifiers.singleWhere(
                (notifier) => identical(notifier.value, harness.snapshot),
              );
              final state = harness.state();
              final calls = harness.calls;
              final notifications = harness.notifications;
              harness.owner.dispose();
              harness.owner.dispose();
              await pumpPhysicalCommandDisposal(tester);
              expect(disposals.count(activeNotifier), 0);
              for (final notifier in harness.resultNotifiers) {
                if (!identical(notifier, activeNotifier)) {
                  expect(disposals.count(notifier), 1);
                }
              }
              harness.expectedError = domainError
                  ? TestException('domain failure')
                  : null;
              harness.gate.complete();
              await pumpPhysicalCommandDisposal(tester);
              for (final notifier in harness.resultNotifiers) {
                expect(disposals.count(notifier), 1);
              }
              expect(harness.calls, calls);
              expect(harness.state(), state);
              expect(harness.notifications, notifications);
              expect(disposals.count(harness.owner), 1);
              expect(harness.request(), isFalse);
              expect(reports, isEmpty);
              expect(tester.takeException(), isNull);
            },
          );
        }

        for (final failure in [
          'StateError',
          'ArgumentError',
          'Object',
          'AssertionError',
        ]) {
          testSubmissionOwnerLifecycle(
            'D2-D4 late $failure preserves original error and stack',
            (tester) async {
              late SubmissionOwnerHarness harness;
              late Zone operationZone;
              final uncaught = <Object>[];
              final uncaughtStacks = <StackTrace>[];
              runZonedGuarded(
                () {
                  operationZone = Zone.current;
                  harness = SubmissionOwnerHarness(lane, probe: disposals);
                },
                (error, stack) {
                  uncaught.add(error);
                  uncaughtStacks.add(stack);
                },
              );
              await operationZone.run(harness.initialize);
              operationZone.run(harness.request);
              await pumpCommandTurns(tester);
              expect(harness.entered, 1);
              expect(harness.resultNotifiers, hasLength(5));
              final activeNotifier = harness.resultNotifiers.singleWhere(
                (notifier) => identical(notifier.value, harness.snapshot),
              );
              final state = harness.state();
              final calls = harness.calls;
              final notifications = harness.notifications;
              harness.owner.dispose();
              await pumpPhysicalCommandDisposal(tester);
              expect(disposals.count(activeNotifier), 0);
              final original = switch (failure) {
                'StateError' => StateError('original late failure'),
                'ArgumentError' => ArgumentError('original late failure'),
                'Object' => Object(),
                _ => AssertionError('original late assertion'),
              };
              final originalStack = StackTrace.fromString(
                '#0 originalSubmissionBoundary (file:///submission_lifecycle.dart:17:3)',
              );
              harness.gate.completeError(original, originalStack);
              await pumpPhysicalCommandDisposal(tester);
              for (final notifier in harness.resultNotifiers) {
                expect(disposals.count(notifier), 1);
              }
              if (failure == 'AssertionError') {
                expect(Command.assertionsAlwaysThrow, isTrue);
                expect(uncaught, [same(original)]);
                expect(
                  uncaughtStacks.single.toString(),
                  contains('submission_lifecycle.dart'),
                );
                expect(reports, isEmpty);
              } else {
                expect(uncaught, isEmpty);
                expect(reports, [same(original)]);
                expect(
                  stacks.single.toString(),
                  contains('submission_lifecycle.dart'),
                );
                expect(reportedCommands, hasLength(1));
                expect(disposals.count(reportedCommands.single), 1);
              }
              expect(harness.calls, calls);
              expect(harness.state(), state);
              expect(harness.notifications, notifications);
              expect(harness.request(), isFalse);
              expect(disposals.count(harness.owner), 1);
              expect(tester.takeException(), isNull);
            },
          );
        }

        for (final completeFirst in [true, false]) {
          testSubmissionOwnerLifecycle(
            'D3 same-turn settlement/dispose completeFirst=$completeFirst',
            (tester) async {
              final harness = SubmissionOwnerHarness(lane, probe: disposals);
              await harness.initialize();
              expect(harness.request(), isTrue);
              await pumpCommandTurns(tester);
              final state = harness.state();
              final calls = harness.calls;
              final notifications = harness.notifications;
              if (completeFirst) harness.gate.complete();
              harness.owner.dispose();
              if (!completeFirst) harness.gate.complete();
              await pumpPhysicalCommandDisposal(tester);
              expect(harness.calls, calls);
              expect(harness.state(), state);
              expect(harness.notifications, notifications);
              expect(disposals.count(harness.owner), 1);
              expect(reports, isEmpty);
              expect(tester.takeException(), isNull);
            },
          );
        }

        testSubmissionOwnerLifecycle(
          'D3 terminal VM observer revokes outside notifier dispatch',
          (tester) async {
            final harness = SubmissionOwnerHarness(lane, probe: disposals)
              ..returnCandidate = false;
            await harness.initialize();
            var revoked = false;
            harness.owner.addListener(() {
              if (harness.snapshot.completed) {
                revoked = true;
                harness.owner.dispose();
                expectSync(disposals.count(harness.owner), 0);
              }
            });
            expect(harness.request(), isTrue);
            await pumpCommandTurns(tester);
            harness.gate.complete();
            await pumpPhysicalCommandDisposal(tester);
            expect(revoked, isTrue);
            expect(disposals.count(harness.owner), 1);
            expect(reports, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );

        testSubmissionOwnerLifecycle(
          'D3 sync idle observer admits then revokes the deferred next request',
          (tester) async {
            final harness = SubmissionOwnerHarness(lane, probe: disposals)
              ..returnCandidate = false;
            await harness.initialize();
            var admittedAgain = false;
            var callsAtRevocation = 0;
            harness.owner.addListener(() {
              if (!admittedAgain &&
                  harness.snapshot.completed &&
                  !harness.running) {
                admittedAgain = true;
                expectSync(harness.request(), isTrue);
                harness.owner.dispose();
                callsAtRevocation = harness.calls;
                expectSync(disposals.count(harness.owner), 0);
              }
            });
            expect(harness.request(), isTrue);
            await pumpCommandTurns(tester);
            harness.gate.complete();
            await pumpPhysicalCommandDisposal(tester);
            expect(admittedAgain, isTrue);
            expect(harness.calls, callsAtRevocation);
            expect(disposals.count(harness.owner), 1);
            for (final notifier in harness.resultNotifiers) {
              expect(disposals.count(notifier), 1);
            }
            expect(harness.request(), isFalse);
            expect(reports, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );

        for (final disposeSecond in [false, true]) {
          testSubmissionOwnerLifecycle(
            'D3 reentrant second request stays single-flight '
            'disposeSecond=$disposeSecond',
            (tester) async {
              final h = SubmissionOwnerHarness(lane, probe: disposals)
                ..returnCandidate = false;
              await h.initialize();
              h.expectedError = TestException('first operation rejected');
              Completer<void>? second;
              var requestedAgain = false;
              h.owner.addListener(() {
                if (!requestedAgain && h.snapshot.data != null && !h.running) {
                  requestedAgain = true;
                  h.expectedError = null;
                  second = h.armNextExecution();
                  expectSync(h.request(), isTrue);
                }
              });
              try {
                expect(h.request(), isTrue);
                await pumpCommandTurns(tester);
                expect(h.entered, 1);
                h.gate.complete();
                await pumpCommandTurns(tester);
                expect(requestedAgain, isTrue);
                expect(h.entered, 2);
                expect(
                  h.running,
                  isTrue,
                  reason: 'request #1 finally cannot clear request #2 busy',
                );
                final pendingSnapshot = h.snapshot;
                expect(
                  h.request(),
                  isFalse,
                  reason: 'request #3 must not overwrite admitted envelope',
                );
                expect(h.snapshot, same(pendingSnapshot));
                expect(h.entered, 2);
                if (disposeSecond) {
                  final state = h.state();
                  final calls = h.calls;
                  final notifications = h.notifications;
                  h.owner.dispose();
                  await pumpPhysicalCommandDisposal(tester);
                  final original = StateError('second execution late raw');
                  final stack = StackTrace.fromString(
                    '#0 secondExecution (file:///second_execution.dart:7:3)',
                  );
                  second!.completeError(original, stack);
                  await pumpPhysicalCommandDisposal(tester);
                  expect(h.state(), state);
                  expect(h.calls, calls);
                  expect(h.notifications, notifications);
                  expect(reports, [same(original)]);
                  expect(
                    stacks.single.toString(),
                    contains('second_execution.dart'),
                  );
                } else {
                  second!.complete();
                  await pumpCommandTurns(tester);
                  expect(h.running, isFalse);
                  expect(h.snapshot.completed, isTrue);
                  expect(reports, isEmpty);
                  h.owner.dispose();
                  await pumpPhysicalCommandDisposal(tester);
                }
                for (final notifier in h.resultNotifiers) {
                  expect(disposals.count(notifier), 1);
                }
                expect(tester.takeException(), isNull);
              } finally {
                h.owner.dispose();
                if (!h.gate.isCompleted) h.gate.complete();
                if (second != null && !second!.isCompleted) second!.complete();
                await pumpPhysicalCommandDisposal(tester);
              }
            },
          );
        }

        for (final runFirst in [false, true]) {
          testSubmissionOwnerLifecycle(
            'D3 ${runFirst ? 'idle' : 'never-run'} all five result notifiers '
            'release once',
            (tester) async {
              final harness = SubmissionOwnerHarness(lane, probe: disposals)
                ..returnCandidate = false;
              final resultNotifiers = harness.resultNotifiers;
              expect(resultNotifiers, hasLength(5));
              await harness.initialize();
              if (runFirst) {
                expect(harness.request(), isTrue);
                await pumpCommandTurns(tester);
                harness.gate.complete();
                await pumpCommandTurns(tester);
                expect(harness.running, isFalse);
              } else {
                harness.gate.complete();
              }
              harness.owner.dispose();
              harness.owner.dispose();
              expectSync(disposals.count(harness.owner), 0);
              for (final notifier in resultNotifiers) {
                expectSync(disposals.count(notifier), 0);
              }
              await pumpPhysicalCommandDisposal(tester);
              expect(disposals.count(harness.owner), 1);
              for (final notifier in resultNotifiers) {
                expect(disposals.count(notifier), 1);
              }
              expect(harness.request(), isFalse);
              expect(reports, isEmpty);
              expect(tester.takeException(), isNull);
            },
          );
        }
      });
    }

    testSubmissionOwnerLifecycle(
      'D1 pending first upload starts neither next upload nor remote submit',
      (tester) async {
        final f = await ContentSubmissionCommandFixture.ready(
          remoteResult: const Result.success(null),
        );
        final upload = FakeImageUploadTask.pending();
        f.repository.uploadImageTaskResults.add(upload);
        var notifications = 0;
        f.vm.addListener(() => notifications++);
        expect(f.vm.requestSubmit(), isTrue);
        await pumpCommandTurns(tester);
        expect(f.repository.uploadedImages, hasLength(1));
        final state = f.vm.state;
        final assets = f.vm.assets.toList();
        final snapshot = f.vm.submitSnapshot;
        final atRevocation = notifications;
        f.vm.dispose();
        await pumpPhysicalCommandDisposal(tester);
        upload.complete(
          const Result.success(
            SubmissionAsset(
              secureUrl: 'https://example.test/first',
              width: 1,
              height: 1,
            ),
          ),
        );
        await pumpPhysicalCommandDisposal(tester);
        expect(f.repository.uploadedImages, hasLength(1));
        expect(f.repository.submitCallCount, 0);
        expect(f.drafts.clearDraftCallCount, 0);
        expect(f.staged.clearedSessions, isEmpty);
        expect(f.vm.state, same(state));
        expect(f.vm.assets, assets);
        expect(f.vm.submitSnapshot, same(snapshot));
        expect(notifications, atRevocation);
        expect(reports, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testSubmissionOwnerLifecycle(
      'D1 post-ack staged cleanup settles without rotation or pending reset',
      (tester) async {
        final f = await ContentSubmissionCommandFixture.ready(
          remoteResult: const Result.success(null),
        );
        final pending = Completer<Result<void>>();
        f.staged.pendingClearSession = pending;
        var notifications = 0;
        f.vm.addListener(() => notifications++);
        expect(f.vm.requestSubmit(), isTrue);
        await pumpCommandTurns(tester);
        expect(f.repository.uploadedImages, hasLength(2));
        expect(f.repository.submitCallCount, 1);
        expect(f.drafts.clearDraftCallCount, 1);
        expect(f.staged.clearedSessions, [
          ContentSubmissionCommandFixture.identity,
        ]);
        expect(f.vm.submissionFinalizationPending, isTrue);
        final state = f.vm.state;
        final assets = f.vm.assets.toList();
        final snapshot = f.vm.submitSnapshot;
        final atRevocation = notifications;
        f.vm.dispose();
        await pumpPhysicalCommandDisposal(tester);
        pending.complete(const Result.success(null));
        await pumpPhysicalCommandDisposal(tester);
        expect(f.vm.state, same(state));
        expect(f.vm.assets, assets);
        expect(f.vm.submissionFinalizationPending, isTrue);
        expect(f.vm.submitSnapshot, same(snapshot));
        expect(notifications, atRevocation);
        expect(f.repository.uploadedImages, hasLength(2));
        expect(f.repository.submitCallCount, 1);
        expect(f.drafts.clearDraftCallCount, 1);
        expect(f.staged.clearedSessions, hasLength(1));
        expect(f.vm.canRetrySubmissionImmediately, isFalse);
        expect(f.vm.isAddingAsset, isFalse);
        expect(f.vm.isRemovingAsset, isFalse);
        expect(f.vm.isSubmitting, isFalse);
        expect(f.vm.isClearing, isFalse);
        expect(f.vm.isRetrievingLostAssets, isFalse);
        expect(f.vm.requestAddAsset(), isFalse);
        expect(f.vm.requestRemoveAssetAt(0), isFalse);
        expect(f.vm.requestSubmit(), isFalse);
        expect(f.vm.requestClear(), isFalse);
        expect(f.vm.requestRetrieveLostAssets(), isFalse);
        expect(reports, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    for (final resolvePending in [false, true]) {
      testSubmissionOwnerLifecycle(
        'D1 bootstrap ${resolvePending ? 'resolve' : 'reconcile'} pending '
        'starts no next resolution or publication',
        (tester) async {
          final h = SubmissionOwnerHarness(
            SubmissionOwnerLane.add,
            probe: disposals,
          );
          final descriptors = [
            for (final digest in [
              ContentSubmissionCommandFixture.firstDigest,
              ContentSubmissionCommandFixture.secondDigest,
            ])
              ContentSubmissionStagedAsset(
                clientSubmissionId: ContentSubmissionCommandFixture.identity,
                digest: digest,
                relativePath:
                    '${ContentSubmissionCommandFixture.identity}/$digest',
              ),
          ];
          final reconcile =
              Completer<Result<List<ContentSubmissionStagedAsset>>>();
          final resolve = Completer<Result<File>>();
          h.staged.reconcileResult = Result.success(descriptors);
          if (resolvePending) {
            h.staged.pendingResolve = resolve;
          } else {
            h.staged.pendingReconcile = reconcile;
          }
          final initialization = h.owner.initialize();
          await pumpCommandTurns(tester);
          expect(h.staged.reconcileCallCount, 1);
          expect(h.staged.resolveCallCount, resolvePending ? 1 : 0);
          final state = h.state();
          final calls = h.calls;
          final notifications = h.notifications;
          h.owner.dispose();
          await pumpPhysicalCommandDisposal(tester);
          if (resolvePending) {
            resolve.complete(Result.success(File('/staged/first.jpg')));
          } else {
            reconcile.complete(Result.success(descriptors));
          }
          await initialization;
          await pumpPhysicalCommandDisposal(tester);
          expect(h.calls, calls);
          expect(h.state(), state);
          expect(h.owner.assets, isEmpty);
          expect(h.notifications, notifications);
          expect(h.staged.resolveCallCount, resolvePending ? 1 : 0);
          expect(h.picker.pickMultipleMediaLimits, isEmpty);
          expect(h.staged.acquired, isEmpty);
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final lane in [
      SubmissionOwnerLane.add,
      SubmissionOwnerLane.recovery,
    ]) {
      testSubmissionOwnerLifecycle(
        'D1 ${lane.name} candidate resolve settles without publishing asset',
        (tester) async {
          final h = SubmissionOwnerHarness(lane, probe: disposals);
          await h.initialize();
          final pending = Completer<Result<File>>();
          h.staged.pendingResolve = pending;
          final resolvesBefore = h.staged.resolveCallCount;
          expect(h.request(), isTrue);
          await pumpCommandTurns(tester);
          h.gate.complete();
          await pumpCommandTurns(tester);
          expect(h.staged.acquired, hasLength(1));
          expect(h.staged.resolveCallCount, resolvesBefore + 1);
          final state = h.state();
          final calls = h.calls;
          final notifications = h.notifications;
          h.owner.dispose();
          await pumpPhysicalCommandDisposal(tester);
          pending.complete(Result.success(File('/staged/new-candidate.jpg')));
          await pumpPhysicalCommandDisposal(tester);
          expect(h.owner.assets, hasLength(1));
          expect(h.state(), state);
          expect(h.calls, calls);
          expect(h.notifications, notifications);
          for (final notifier in h.resultNotifiers) {
            expect(disposals.count(notifier), 1);
          }
          expect(reports, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final lane in [
      SubmissionOwnerLane.add,
      SubmissionOwnerLane.recovery,
    ]) {
      for (final lengthPending in [true, false]) {
        testSubmissionOwnerLifecycle(
          'D1 ${lane.name} direct ${lengthPending ? 'length' : 'hash'} '
          'settlement starts no next file read or staging',
          (tester) async {
            final file = GatedSubmissionFile(gateLength: lengthPending);
            final h = SubmissionOwnerHarness(
              lane,
              probe: disposals,
              pickedCandidate: file,
            );
            await h.initialize();
            expect(h.request(), isTrue);
            await pumpCommandTurns(tester);
            h.gate.complete();
            await pumpCommandTurns(tester);
            expect(file.lengthCalls, 1);
            expect(file.openReadCalls, lengthPending ? 0 : 1);
            final state = h.state();
            final calls = h.calls;
            final notifications = h.notifications;
            h.owner.dispose();
            await pumpPhysicalCommandDisposal(tester);
            if (lengthPending) {
              file.lengthGate.complete(1);
            } else {
              file.readGate.complete([3]);
            }
            await pumpPhysicalCommandDisposal(tester);
            expect(file.lengthCalls, 1);
            expect(file.openReadCalls, lengthPending ? 0 : 1);
            expect(h.staged.acquired, isEmpty);
            expect(h.calls, calls);
            expect(h.state(), state);
            expect(h.notifications, notifications);
            for (final notifier in h.resultNotifiers) {
              expect(disposals.count(notifier), 1);
            }
            expect(reports, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

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
