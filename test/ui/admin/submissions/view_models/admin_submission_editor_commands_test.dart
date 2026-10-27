import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/admin_editor_command_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_logger.dart';

void main() {
  late AdminSubmissionEditorViewModel owner;

  testOwnerUI(
    'RF1.1/RF1.3/RF3.1 Save outcomes survive error and equal successes',
    (tester) async {
      final first = Completer<Result<AdminSubmission>>();
      final second = Completer<Result<AdminSubmission>>();
      final third = Completer<Result<AdminSubmission>>();
      final repository = FakeAdminContentSubmissionRepository()
        ..pendingCreate = first;
      owner =
          AdminSubmissionEditorViewModel(
              repository: repository,
              contentSubmissionRepository: FakeContentSubmissionRepository(),
            )
            ..setCity('Campobasso')
            ..setName('Snapshot A');
      final observed = <int>[];
      owner.addListener(() {
        final id = owner.saveExecutionId;
        if (id != null &&
            !owner.saveSnapshot.isRunning &&
            !owner.saveSnapshot.idle &&
            !observed.contains(id)) {
          observed.add(id);
        }
      });
      expect(owner.saveSnapshot.idle, isTrue);
      expect(owner.requestSave(), isTrue);
      final firstId = owner.saveExecutionId;
      expect(owner.requestSave(), isFalse);
      expect(owner.saveExecutionId, firstId);
      await pumpCommandTurns(tester);
      expect(repository.createInputs.single.name, 'Snapshot A');
      final expectedError = TestException('first attempt');
      first.complete(Result.error(expectedError));
      await pumpCommandTurns(tester);
      expect(owner.saveSnapshot.domainError, same(expectedError));
      expect(owner.canRequestSave, isTrue);

      repository.pendingCreate = second;
      expect(owner.requestSave(), isTrue);
      final secondId = owner.saveExecutionId;
      expect(secondId, greaterThan(firstId!));
      await pumpCommandTurns(tester);
      await pumpCommandTurns(tester);
      expect(owner.operationRunning, isTrue);
      expect(owner.saveSnapshot.isRunning, isTrue);
      expect(repository.createInputs, hasLength(2));
      second.complete(Result.success(sampleAdminSubmission(id: 99)));
      await pumpCommandTurns(tester);
      expect(owner.saveSnapshot.completed, isTrue);
      expect(owner.submissionId, isNull);

      repository.pendingCreate = third;
      expect(owner.requestSave(), isTrue);
      final thirdId = owner.saveExecutionId;
      await pumpCommandTurns(tester);
      third.complete(Result.success(sampleAdminSubmission(id: 99)));
      await pumpCommandTurns(tester);
      expect(observed, [firstId, secondId, thirdId]);
    },
    disposeOwners: () => owner.dispose(),
  );

  testOwnerUI('E6 terminal notification admits one new Save '
      'without clearing its busy state', (tester) async {
    final first = Completer<Result<AdminSubmission>>();
    final second = Completer<Result<AdminSubmission>>();
    final repository = FakeAdminContentSubmissionRepository()
      ..pendingCreate = first;
    owner =
        AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
          )
          ..setCity('Campobasso')
          ..setName('Captured draft');
    var admittedNext = false;
    bool? acceptedNext;
    (bool, bool)? atReentrantAdmission;
    int? nextEffect;
    owner.addListener(() {
      if (!owner.saveSnapshot.completed || admittedNext) return;
      admittedNext = true;
      repository.pendingCreate = second;
      acceptedNext = owner.requestSave();
      nextEffect = owner.saveExecutionId;
      atReentrantAdmission = (
        owner.operationRunning,
        owner.saveSnapshot.isRunning,
      );
    });
    expect(owner.requestSave(), isTrue);
    final firstEffect = owner.saveExecutionId;
    await pumpCommandTurns(tester);
    first.complete(Result.success(sampleAdminSubmission()));
    await pumpCommandTurns(tester);
    await pumpCommandTurns(tester);
    expect(admittedNext, isTrue);
    expect(acceptedNext, isTrue);
    expect(atReentrantAdmission, (true, true));
    expect(nextEffect, greaterThan(firstEffect!));
    expect(repository.createInputs, hasLength(2));
    expect(owner.saveExecutionId, nextEffect);
    expect(owner.operationRunning, isTrue);
    expect(owner.saveSnapshot.isRunning, isTrue);
    expect(owner.requestSave(), isFalse);
    second.complete(Result.success(sampleAdminSubmission()));
    await pumpCommandTurns(tester);
    expect(repository.createInputs, hasLength(2));
    expect(owner.operationRunning, isFalse);
    expect(owner.saveSnapshot.completed, isTrue);
  }, disposeOwners: () => owner.dispose());

  testOwnerUI(
    'RF1.4 second Save retains raw reporting beyond upstream teardown',
    (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final repository = FakeAdminContentSubmissionRepository();
      owner =
          AdminSubmissionEditorViewModel(
              repository: repository,
              contentSubmissionRepository: FakeContentSubmissionRepository(),
            )
            ..setCity('Campobasso')
            ..setName('First');
      expect(owner.requestSave(), isTrue);
      await pumpCommandTurns(tester);
      final second = Completer<Result<AdminSubmission>>();
      repository.pendingCreate = second;
      expect(owner.requestSave(), isTrue);
      await pumpCommandTurns(tester);
      final frozen = owner.saveSnapshot;
      var notifications = 0;
      owner
        ..addListener(() => notifications++)
        ..dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 51));
      final error = StateError('original second Save');
      final stack = StackTrace.current;
      second.completeError(error, stack);
      await pumpCommandTurns(tester);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(error));
      expect(
        logger.calls.single.stackTrace.toString(),
        contains('commands_test.dart'),
      );
      expect(owner.saveSnapshot, same(frozen));
      expect(notifications, 0);
      owner.dispose();
      await pumpCommandTurns(tester);
    },
    disposeOwners: () => owner.dispose(),
  );

  for (final aba in [false, true]) {
    for (final outcome in ['success', 'expected', 'runtime']) {
      testOwnerUI(
        'RF1.2/RF2.1/RF2.2 candidate ABA=$aba stale $outcome then retry',
        (tester) async {
          final logger = MockLogger();
          addTearDown(installCommandTestReporting(logger));
          final first = Completer<Result<AdminEventCandidates>>();
          final second = Completer<Result<AdminEventCandidates>>();
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: {
              1: Result.success(
                sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 24)),
              ),
            },
          );
          owner = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            submissionId: 1,
          );
          expect(owner.requestLoad(), isTrue);
          await pumpCommandTurns(tester);
          var calls = 0;
          repository.onEventCandidates = (id, search, target) =>
              ++calls == 1 ? first.future : second.future;
          owner.setCandidateSearch('A');
          expect(owner.requestFindCandidates(), isTrue);
          final firstId = owner.findCandidatesExecutionId;
          await pumpCommandTurns(tester);
          expect(repository.candidateCalls, [(1, 'A', null)]);
          owner.setCandidateSearch('B');
          if (aba) owner.setCandidateSearch('A');
          final afterSetter = owner.findCandidatesSnapshot;
          expect(afterSetter.idle, isTrue);
          expect(owner.requestFindCandidates(), isFalse);
          expect(owner.findCandidatesSnapshot, same(afterSetter));
          expect(owner.findCandidatesExecutionId, firstId);
          expect(repository.candidateCalls, hasLength(1));
          final error = StateError('obsolete candidate');
          switch (outcome) {
            case 'success':
              first.complete(
                Result.success(
                  AdminEventCandidates(
                    events: [
                      const AdminEventCandidate(id: 8, name: 'obsolete'),
                    ],
                    pendingWarnings: [],
                  ),
                ),
              );
            case 'expected':
              first.complete(Result.error(TestException('obsolete')));
            case 'runtime':
              first.completeError(error, StackTrace.current);
          }
          await pumpCommandTurns(tester);
          expect(owner.findCandidatesSnapshot.idle, isTrue);
          expect(owner.candidates, isNull);
          expect(logger.calls, hasLength(outcome == 'runtime' ? 1 : 0));
          if (outcome == 'runtime') {
            expect(logger.calls.single.error, same(error));
          }
          expect(owner.requestFindCandidates(), isTrue);
          expect(owner.findCandidatesExecutionId, greaterThan(firstId!));
          await pumpCommandTurns(tester);
          expect(repository.candidateCalls.last, (1, aba ? 'A' : 'B', null));
          second.complete(
            Result.success(
              AdminEventCandidates(
                events: [const AdminEventCandidate(id: 9, name: 'current')],
                pendingWarnings: [],
              ),
            ),
          );
          await pumpCommandTurns(tester);
          expect(owner.candidates!.events.single.id, 9);
          expect(owner.findCandidatesSnapshot.completed, isTrue);
        },
        disposeOwners: () => owner.dispose(),
      );
    }
  }

  testOwnerUI(
    'RF2.3 desired input under Save stays explicit and blank sends null',
    (tester) async {
      final save = Completer<Result<AdminSubmission>>();
      final candidate = Completer<Result<AdminEventCandidates>>();
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: {
          1: Result.success(
            sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 24)),
          ),
        },
      );
      owner = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      expect(owner.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      repository
        ..pendingUpdate = save
        ..onEventCandidates = (id, search, target) => candidate.future;
      expect(owner.requestSave(), isTrue);
      owner.setCandidateSearch('  ');
      await pumpCommandTurns(tester);
      expect(repository.candidateCalls, isEmpty);
      expect(repository.updateIds, [1]);
      expect(owner.requestFindCandidates(), isTrue);
      await pumpCommandTurns(tester);
      expect(repository.candidateCalls, [(1, null, null)]);
      save.complete(Result.success(sampleAdminSubmission()));
      await pumpCommandTurns(tester);
      candidate.complete(
        Result.success(AdminEventCandidates(events: [], pendingWarnings: [])),
      );
      await pumpCommandTurns(tester);
      expect(owner.findCandidatesSnapshot.idle, isTrue);
      expect(owner.candidates, isNull);
      expect(owner.saveSnapshot.completed, isTrue);
      expect(owner.requestFindCandidates(), isTrue);
      await pumpCommandTurns(tester);
      expect(repository.candidateCalls, [(1, null, null), (1, null, null)]);
      expect(owner.findCandidatesSnapshot.completed, isTrue);
    },
    disposeOwners: () => owner.dispose(),
  );

  for (
    var lane = 0;
    lane < AdminEditorCommandHarness.laneNames.length;
    lane++
  ) {
    for (final kind in ['StateError', 'TypeError', 'AssertionError']) {
      late AdminEditorCommandHarness harness;
      testOwnerUI(
        'A4/L1/L2 ${AdminEditorCommandHarness.laneNames[lane]} late $kind',
        (tester) async {
          final logger = MockLogger();
          addTearDown(installCommandTestReporting(logger));
          final uncaught = <Object>[];
          late Zone operationZone;
          runZonedGuarded(() {
            operationZone = Zone.current;
            harness = AdminEditorCommandHarness();
          }, (error, stack) => uncaught.add(error));
          operationZone.run(() => expect(harness.owner.requestLoad(), isTrue));
          await pumpCommandTurns(tester);
          operationZone.run(
            () => expect(harness.owner.requestPreview(), isTrue),
          );
          await pumpCommandTurns(tester);
          harness.hold();
          operationZone.run(() => expect(harness.requests[lane](), isTrue));
          await pumpCommandTurns(tester);
          expect(harness.calls[lane], 1);
          final snapshots = harness.snapshots;
          var notifications = 0;
          harness.owner.addListener(() => notifications++);
          harness.owner.dispose();
          await pumpCommandTurns(tester);
          await tester.pump(const Duration(milliseconds: 51));
          final error = switch (kind) {
            'StateError' => StateError('late original'),
            'TypeError' => TypeError(),
            _ => AssertionError('fail loud'),
          };
          final stack = StackTrace.fromString('originalEditorRepository:7:3');
          harness.releaseLane(lane, error: error, stackTrace: stack);
          await pumpCommandTurns(tester);
          if (kind == 'AssertionError') {
            expect(uncaught, [same(error)]);
            expect(logger.calls, isEmpty);
          } else {
            expect(uncaught, isEmpty);
            expect(logger.calls, hasLength(1));
            expect(logger.calls.single.error, same(error));
            expect(
              logger.calls.single.stackTrace.toString(),
              contains('originalEditorRepository'),
            );
          }
          expect(harness.snapshots, snapshots);
          expect(notifications, 0);
          expect(harness.calls[lane], 1);
          await tester.pump(const Duration(milliseconds: 51));
          await pumpCommandTurns(tester);
          await pumpCommandTurns(tester);
          expect(harness.snapshots, snapshots);
          expect(notifications, 0);
          expect(tester.takeException(), isNull);
        },
        disposeOwners: () => harness.owner.dispose(),
      );
    }
  }

  for (final create in [true, false]) {
    for (final outcome in ['success', 'expected', 'runtime']) {
      testOwnerUI('A6/S1/S2 immutable Save create=$create outcome=$outcome', (
        tester,
      ) async {
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final gate = Completer<Result<AdminSubmission>>();
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: {1: Result.success(sampleAdminSubmission())},
        );
        owner = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: create ? null : 1,
        );
        if (!create) {
          expect(owner.requestLoad(), isTrue);
          await pumpCommandTurns(tester);
        }
        final attributes = <String, dynamic>{'bold': true};
        final delta = <Map<String, dynamic>>[
          {'insert': 'original', 'attributes': attributes},
        ];
        owner
          ..setCity('Original city')
          ..setName('Original name')
          ..setDescription(description: 'Original', descriptionDelta: delta);
        if (create) {
          repository.pendingCreate = gate;
        } else {
          repository.pendingUpdate = gate;
        }
        expect(owner.requestSave(), isTrue);
        attributes['bold'] = false;
        delta.first['insert'] = 'aliased';
        owner.setName('Newer unsaved name');
        await pumpCommandTurns(tester);
        final persisted = create
            ? repository.createInputs.single
            : repository.updateInputs.single;
        expect(persisted.name, 'Original name');
        expect(persisted.descriptionDelta!.first['insert'], 'original');
        expect(
          (persisted.descriptionDelta!.first['attributes'] as Map)['bold'],
          isTrue,
        );
        expect(
          () => persisted.descriptionDelta!.first['insert'] = 'mutate',
          throwsUnsupportedError,
        );
        final error = StateError('save boundary');
        final stack = StackTrace.fromString('originalSaveBoundary:9:2');
        switch (outcome) {
          case 'success':
            gate.complete(Result.success(sampleAdminSubmission(id: 88)));
          case 'expected':
            gate.complete(Result.error(TestException('expected')));
          case 'runtime':
            gate.completeError(error, stack);
        }
        await pumpCommandTurns(tester);
        expect(owner.name, 'Newer unsaved name');
        expect(owner.isDirty, isTrue);
        expect(owner.submissionId, create ? null : 1);
        expect(logger.calls, hasLength(outcome == 'runtime' ? 1 : 0));
        expect(owner.saveSnapshot.completed, outcome == 'success');
        if (outcome == 'runtime') {
          expect(owner.saveSnapshot.unexpectedError, same(error));
          expect(
            owner.saveSnapshot.stackTrace.toString(),
            allOf(contains('originalSaveBoundary'), contains('9:2')),
          );
          expect(
            owner.saveSnapshot.stackTrace,
            same(logger.calls.single.stackTrace),
          );
          expect(owner.saveSnapshot.errorReaction, isNotNull);
          expect(logger.calls.single.error, same(error));
          expect(
            logger.calls.single.stackTrace.toString(),
            allOf(contains('originalSaveBoundary'), contains('9:2')),
          );
        }
        final firstId = owner.saveExecutionId;
        repository
          ..pendingCreate = null
          ..pendingUpdate = null;
        expect(owner.requestSave(), isTrue);
        await pumpCommandTurns(tester);
        expect(owner.saveExecutionId, greaterThan(firstId!));
        expect(owner.isDirty, isFalse);
        expect(
          (create ? repository.createInputs : repository.updateInputs)
              .last
              .name,
          'Newer unsaved name',
        );
      }, disposeOwners: () => owner.dispose());
    }
  }

  testOwnerUI(
    'S3/S4 public Load is exclusive and refuses field edits and dirty reload',
    (tester) async {
      final gate = Completer<Result<AdminSubmission>>();
      final repository = FakeAdminContentSubmissionRepository()
        ..onGetById = (_) => gate.future;
      owner = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      expect(owner.requestLoad(), isTrue);
      final revision = owner.editorRevision;
      owner
        ..setName('must refuse')
        ..setCoordinates(41, 14)
        ..setDescription(description: 'must refuse', descriptionDelta: null);
      expect(owner.name, isNull);
      expect(owner.latitudeText, '');
      expect(owner.editorRevision, revision);
      expect(owner.isDirty, isFalse);
      expect(owner.requestSave(), isFalse);
      expect(owner.requestPreview(), isFalse);
      owner.setCandidateSearch('allowed desired input');
      expect(owner.requestFindCandidates(), isFalse);
      await pumpCommandTurns(tester);
      gate.complete(Result.success(sampleAdminSubmission(name: 'Loaded')));
      await pumpCommandTurns(tester);
      expect(owner.name, 'Loaded');
      owner.setName('Dirty');
      final snapshot = owner.loadSnapshot;
      expect(owner.requestLoad(), isFalse);
      expect(owner.loadSnapshot, same(snapshot));
      expect(repository.getByIdIds, [1]);
      expect(owner.name, 'Dirty');
    },
    disposeOwners: () => owner.dispose(),
  );

  testOwnerUI(
    'RF3.1 Save Success then Error then equal Success never inherits closure',
    (tester) async {
      final result = Result.success(sampleAdminSubmission(id: 99));
      final repository = FakeAdminContentSubmissionRepository(
        createResult: result,
      );
      owner =
          AdminSubmissionEditorViewModel(
              repository: repository,
              contentSubmissionRepository: FakeContentSubmissionRepository(),
            )
            ..setCity('Campobasso')
            ..setName('Stable draft');
      final runningIds = <int>[];
      final terminals = <int>[];
      owner.addListener(() {
        final id = owner.saveExecutionId;
        if (id == null) return;
        if (owner.saveSnapshot.isRunning && !runningIds.contains(id)) {
          runningIds.add(id);
          expect(owner.requestSave(), isFalse);
        } else if (!owner.saveSnapshot.idle &&
            !owner.saveSnapshot.isRunning &&
            !terminals.contains(id)) {
          terminals.add(id);
        }
      });
      expect(owner.requestSave(), isTrue);
      await pumpCommandTurns(tester);
      final a = owner.saveExecutionId;
      final error = TestException('B expected');
      repository.createResult = Result.error(error);
      expect(owner.requestSave(), isTrue);
      await pumpCommandTurns(tester);
      final b = owner.saveExecutionId;
      expect(owner.saveSnapshot.domainError, same(error));
      expect(owner.isDirty, isFalse);
      repository.createResult = result;
      expect(owner.requestSave(), isTrue);
      await pumpCommandTurns(tester);
      final c = owner.saveExecutionId;
      expect(owner.saveSnapshot.data, isA<Success<void>>());
      expect(runningIds, [a, b, c]);
      expect(terminals, [a, b, c]);
      expect({a, b, c}, hasLength(3));
    },
    disposeOwners: () => owner.dispose(),
  );

  for (
    var lane = 0;
    lane < AdminEditorCommandHarness.laneNames.length;
    lane++
  ) {
    late AdminEditorCommandHarness harness;
    testOwnerUI(
      'E11/A3/L1 ${AdminEditorCommandHarness.laneNames[lane]} revoke inside admission notify',
      (tester) async {
        harness = AdminEditorCommandHarness();
        expect(harness.owner.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        expect(harness.owner.requestPreview(), isTrue);
        await pumpCommandTurns(tester);
        harness.hold();
        var notifications = 0;
        harness.owner.addListener(() {
          notifications++;
          if (harness.snapshots.any((snapshot) => snapshot.isRunning)) {
            harness.owner.dispose();
          }
        });
        expect(harness.requests[lane](), isTrue);
        final frozen = harness.snapshots;
        final atRevocation = notifications;
        expect(frozen[lane].completed, isFalse);
        expect(harness.owner.isDisposed, isTrue);
        await pumpCommandTurns(tester);
        expect(harness.calls, everyElement(0));
        expect(harness.snapshots, frozen);
        await tester.pump(const Duration(milliseconds: 51));
        await pumpCommandTurns(tester);
        await pumpCommandTurns(tester);
        expect(harness.calls, everyElement(0));
        expect(harness.snapshots, frozen);
        expect(harness.owner.operationRunning, isFalse);
        expect(harness.owner.loading, isFalse);
        expect(harness.requests[lane](), isFalse);
        expect(notifications, atRevocation);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => harness.owner.dispose(),
    );
  }

  testOwnerUI(
    'A4/L2 live assertion is fail-loud without synthetic success or retry',
    (tester) async {
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final uncaught = <Object>[];
      late Zone operationZone;
      late AdminEditorCommandHarness harness;
      runZonedGuarded(() {
        operationZone = Zone.current;
        harness = AdminEditorCommandHarness();
        owner = harness.owner;
      }, (error, stack) => uncaught.add(error));
      operationZone.run(() => expect(owner.requestLoad(), isTrue));
      await pumpCommandTurns(tester);
      harness.hold();
      operationZone.run(() => expect(owner.requestSave(), isTrue));
      await pumpCommandTurns(tester);
      final original = AssertionError('original assertion');
      harness.releaseLane(1, error: original);
      await pumpCommandTurns(tester);
      expect(uncaught, [same(original)]);
      expect(logger.calls, isEmpty);
      expect(owner.saveSnapshot.completed, isFalse);
      expect(owner.saveSnapshot.domainError, isNull);
      expect(owner.canRequestSave, isFalse);
      harness.repository.pendingUpdate = null;
      expect(owner.requestSave(), isFalse);
      await pumpCommandTurns(tester);
      expect(owner.saveSnapshot.completed, isFalse);
      expect(harness.repository.updateIds, [1]);
    },
    disposeOwners: () => owner.dispose(),
  );
}
