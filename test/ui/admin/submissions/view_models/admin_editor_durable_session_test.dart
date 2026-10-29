import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/admin_draft_repositories.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_image_picker.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_logger.dart';

void main() {
  late AdminDraftSessionHarness local;
  late FakeAdminContentSubmissionRepository remote;
  late FakeContentSubmissionRepository content;
  late AdminSubmissionEditorViewModel vm;
  final pickerResults = <Completer<XFile?>>[];
  const account = AdminDraftSessionHarness.accountA;
  const token = '2026-10-27T12:30:00.123456+00:00';

  setUp(() {
    addTearDown(installCommandTestReporting(MockLogger()));
    local = AdminDraftSessionHarness();
    remote = FakeAdminContentSubmissionRepository();
    content = FakeContentSubmissionRepository();
    pickerResults.clear();
    vm = AdminSubmissionEditorViewModel(
      repository: remote,
      contentSubmissionRepository: content,
      draftSession: local.session,
      imagePicker: FakeImagePicker(
        onPickImage: () {
          final completion = Completer<XFile?>();
          pickerResults.add(completion);
          return completion.future;
        },
      ),
    );
  });
  tearDown(() {
    vm.dispose();
    for (final result in pickerResults) {
      if (!result.isCompleted) result.complete(null);
    }
  });

  group('local exit review', () {
    test('local field dirtiness is separate from moderation work', () async {
      await vm.activate(accountId: account);
      expect(vm.hasUncheckpointedChanges, isFalse);
      expect(vm.isDirty, isTrue);
      final activation = vm.activation;
      vm.setName('incomplete', activation: activation);
      expect(vm.hasUncheckpointedChanges, isTrue);
      await vm.checkpointLocal();
      expect(vm.hasUncheckpointedChanges, isFalse);
      expect(vm.isDirty, isTrue);
    });

    for (final stagedOnly in [true, false]) {
      test('${stagedOnly ? 'staged receipt' : 'unresolved write'} '
          'alone is locally clean', () async {
        local.seed();
        final old = local.drafts.drafts[local.owner.lookupKey]!;
        if (stagedOnly) {
          final digest = 'a' * 40;
          local.staged.assets[local.owner] = [
            AdminSubmissionStagedAsset(
              owner: local.owner,
              digest: digest,
              relativePath:
                  '${local.owner.accountId}/${local.owner.sessionId}/$digest',
              progress: AdminStagedAssetProgress(
                upload: const SubmissionAsset(
                  secureUrl: 'https://example.com/photo',
                  width: 10,
                  height: 10,
                ),
              ),
            ),
          ];
        } else {
          local.drafts.drafts[local.owner.lookupKey] = AdminSubmissionDraft(
            owner: local.owner,
            snapshot: old.snapshot,
            remoteBaseline: old.remoteBaseline,
            fieldWriteIntent: AdminFieldWriteIntent(
              kind: AdminFieldWriteKind.update,
              attemptId: '22222222-2222-4222-8222-222222222222',
              snapshot: old.snapshot,
              expectedModifiedAt: token,
            ),
          );
        }
        await vm.activate(accountId: account, submissionId: 7);
        expect(vm.hasUncheckpointedChanges, isFalse);
        expect(vm.isDirty, isTrue);
        expect(vm.canRequestExit, isTrue);
        expect(remote.updateInputs, isEmpty);
        expect(content.uploadedImages, isEmpty);
      });
    }

    test(
      'review reserves mutations and only its own release can clear it',
      () async {
        await vm.activate(accountId: account);
        final activation = vm.activation;
        vm.setName('A', activation: activation);
        final review = vm.beginExitDecision(activation)!;
        expect(vm.beginExitDecision(activation), isNull);
        expect(vm.canRequestExit, isFalse);
        expect(vm.requestSave(activation: activation), isFalse);
        expect(vm.requestLoad(activation: activation), isFalse);
        expect(vm.requestAddAsset(activation: activation), isFalse);
        expect(await vm.checkpointLocal(), isA<Error<void>>());
        vm.endExitDecision(review);
        final next = vm.beginExitDecision(activation)!;
        vm.endExitDecision(review);
        expect(vm.exitDecisionPending, isTrue);
        vm.endExitDecision(next);
        expect(vm.canRequestExit, isTrue);
        expect(local.drafts.saves, isEmpty);
        expect(remote.createInputs, isEmpty);
        expect(content.uploadedImages, isEmpty);
      },
    );

    test('queued checkpoint refuses unreviewed B before writing', () async {
      local.seed();
      final digest = 'b' * 40;
      final asset = AdminSubmissionStagedAsset(
        owner: local.owner,
        digest: digest,
        relativePath:
            '${local.owner.accountId}/${local.owner.sessionId}/$digest',
      );
      local.staged.assets[local.owner] = [asset];
      await vm.activate(accountId: account, submissionId: 7);
      final activation = vm.activation;
      vm.setName('reviewed A', activation: activation);
      final review = vm.beginExitDecision(activation)!;
      final entered = Completer<void>();
      final released = Completer<Result<void>>();
      local.staged.onRemove = (_, _) {
        entered.complete();
        return released.future;
      };
      final blocker = local.session.remove(asset);
      await entered.future;
      final checkpoint = vm.checkpointForExit(review);
      vm.setName('newer B', activation: activation);
      released.complete(const Result.success(null));
      await blocker;
      expect(await checkpoint, isA<Error<void>>());
      expect(local.drafts.saves, isEmpty);
      expect(vm.name, 'newer B');
      expect(vm.hasUncheckpointedChanges, isTrue);
      expect(vm.isExitCheckpointConfirmed(review), isFalse);
      vm.endExitDecision(review);
    });

    test(
      'checkpoint preserves review A while typing B remains dirty',
      () async {
        await vm.activate(accountId: account);
        final activation = vm.activation;
        vm.setName('A', activation: activation);
        final review = vm.beginExitDecision(activation)!;
        final entered = Completer<void>();
        final released = Completer<Result<void>>();
        local.drafts.onSave = (_) {
          entered.complete();
          return released.future;
        };
        final checkpoint = vm.checkpointForExit(review);
        await entered.future;
        vm.setName('B', activation: activation);
        released.complete(const Result.success(null));
        expect(await checkpoint, isA<Success<void>>());
        expect(local.drafts.saves.single.snapshot.name, 'A');
        expect(vm.name, 'B');
        expect(vm.hasUncheckpointedChanges, isTrue);
        expect(vm.isExitCheckpointConfirmed(review), isFalse);
        vm.endExitDecision(review);
      },
    );

    test(
      'discard invalidates old review and keeps effective local fields',
      () async {
        local.seed();
        await vm.activate(accountId: account, submissionId: 7);
        final activation = vm.activation;
        vm.setName('B', activation: activation);
        final review = vm.beginExitDecision(activation)!;
        expect(await vm.discardForExit(review), isA<Success<void>>());
        expect(vm.name, 'A');
        expect(vm.hasUncheckpointedChanges, isFalse);
        expect(vm.isExitDiscardConfirmed(review), isTrue);
        expect(vm.isExitReviewCurrent(review), isFalse);
        expect(local.drafts.saves, isEmpty);
        expect(remote.updateInputs, isEmpty);
        vm.endExitDecision(review);
      },
    );

    test(
      'revocation during write retains original owner but no A2 permission',
      () async {
        await vm.activate(accountId: account);
        final activation = vm.activation;
        final owner = local.session.state!.owner;
        vm.setName('A', activation: activation);
        final review = vm.beginExitDecision(activation)!;
        final entered = Completer<void>();
        final released = Completer<Result<void>>();
        local.drafts.onSave = (_) {
          entered.complete();
          return released.future;
        };
        final checkpoint = vm.checkpointForExit(review);
        await entered.future;
        vm.revoke();
        expect(vm.exitDecisionPending, isFalse);
        released.complete(const Result.success(null));
        expect(await checkpoint, isA<Error<void>>());
        local.drafts.onSave = null;
        await vm.activate(accountId: account, sessionId: owner.sessionId);
        expect(vm.name, 'A');
        expect(vm.isExitCheckpointConfirmed(review), isFalse);
        final next = vm.beginExitDecision(vm.activation)!;
        vm.endExitDecision(review);
        expect(vm.exitDecisionPending, isTrue);
        vm.endExitDecision(next);
      },
    );
  });

  test(
    'same-target activation retains C and rejects unowned setters',
    () async {
      await vm.activate(accountId: account);
      final authority = vm.activation;
      vm
        ..setName('Incomplete', activation: authority)
        ..setCity('must be rejected');
      expect(vm.city, isNull);
      expect(await vm.activate(accountId: account), isA<Success<void>>());
      expect(vm.name, 'Incomplete');
      expect(vm.isActivationCurrent(authority), isTrue);
      expect(
        await vm.activate(accountId: account, submissionId: 7),
        isA<Error<void>>(),
      );
      expect(vm.name, 'Incomplete');
    },
  );

  test('checkpoint permits switch but A1 cannot mutate restored A2', () async {
    await vm.activate(accountId: account);
    final a1 = vm.activation;
    final session = vm.sessionId;
    vm.setName('A', activation: a1);
    await vm.checkpointLocal();
    await vm.activate(accountId: account, submissionId: 7);
    await vm.activate(accountId: account, sessionId: session);
    expect(vm.name, 'A');
    vm.setName('obsolete', activation: a1);
    expect(vm.name, 'A');
    expect(vm.requestSave(activation: a1), isFalse);
  });

  test(
    'Create adopts same UUID and next Save performs exact-token Update',
    () async {
      final initial = sampleAdminSubmission(
        name: 'A',
        description: null,
        modifiedAtToken: token,
      );
      remote.createResult = Result.success(initial);
      remote.getByIdResults[1] = Result.success(initial);
      await vm.activate(accountId: account);
      final uuid = vm.sessionId;
      var authority = vm.activation;
      vm
        ..setName('A', activation: authority)
        ..setCity('Campobasso', activation: authority)
        ..setCategory(ContentCategory.history, activation: authority);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      expect(vm.savePhase, AdminSavePhase.completed);
      expect(vm.submissionId, 1);
      expect(vm.sessionId, uuid);
      expect(remote.createClientSubmissionIds, [uuid]);
      expect(vm.isActivationCurrent(authority), isFalse);
      expect(vm.isDirty, isFalse);
      authority = vm.activation;
      vm.setName('B', activation: authority);
      final next = sampleAdminSubmission(
        name: 'B',
        description: null,
        modifiedAtToken: token,
      );
      remote.updateResult = Result.success(next);
      remote.getByIdResults[1] = Result.success(next);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      expect(remote.createInputs, hasLength(1));
      expect(remote.updateIds, [1]);
      expect(remote.updateExpectedModifiedAt, [token]);
      expect(vm.savePhase, AdminSavePhase.completed);
    },
  );

  test(
    'restored Create A replays valid intent while incomplete B stays local',
    () async {
      final owner = AdminDraftOwner(accountId: account);
      final captured = AdminDraftSnapshot(
        category: ContentCategory.history,
        city: 'Campobasso',
        name: 'A',
      );
      final newer = captured.copyWith(city: null, name: 'Incomplete B');
      final intent = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: AdminDraftOwner(accountId: account).sessionId,
        snapshot: captured,
      );
      local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
        owner: owner,
        snapshot: newer,
        fieldWriteIntent: intent,
      );
      final created = sampleAdminSubmission(
        name: 'A',
        description: null,
        modifiedAtToken: token,
      );
      remote.createResult = Result.success(created);
      remote.getByIdResults[1] = Result.success(created);
      await vm.activate(accountId: account);
      expect(vm.city, isNull);
      expect(vm.canResumeCapturedSave, isTrue);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: vm.activation),
      );
      expect(remote.createClientSubmissionIds, [owner.sessionId]);
      expect(remote.createInputs.single.city, 'Campobasso');
      expect(remote.createInputs.single.name, 'A');
      expect(vm.name, 'Incomplete B');
      expect(vm.city, isNull);
      expect(vm.isDirty, isTrue);
      expect(vm.submissionId, 1);
      expect(vm.savePhase, AdminSavePhase.completed);
    },
  );

  test('server-normalized Create and Update confirm '
      'raw whitespace and null category', () async {
    const nextToken = '2026-10-27T12:31:00.123457+00:00';
    final created = sampleAdminSubmission(
      name: 'A',
      description: null,
      category: ContentCategory.unknown,
      modifiedAtToken: token,
    );
    remote.createResult = Result.success(created);
    remote.getByIdResults[1] = Result.success(created);
    await vm.activate(accountId: account);
    var authority = vm.activation;
    vm
      ..setCity(' Campobasso ', activation: authority)
      ..setName(' A ', activation: authority);
    await settleEditorRequest(admitted: vm.requestSave(activation: authority));
    expect(vm.savePhase, AdminSavePhase.completed);
    expect(vm.isDirty, isFalse);
    expect(vm.category, isNull);
    expect(vm.city, ' Campobasso ');
    expect(vm.name, ' A ');
    expect(local.session.state!.physicalCheckpoint!.snapshot.category, isNull);
    expect(
      local.session.state!.physicalCheckpoint!.snapshot.city,
      ' Campobasso ',
    );
    expect(local.session.state!.physicalCheckpoint!.snapshot.name, ' A ');
    expect(remote.createInputs.single.category, ContentCategory.unknown);
    authority = vm.activation;
    vm.setName(' B ', activation: authority);
    final updated = sampleAdminSubmission(
      name: 'B',
      description: null,
      category: ContentCategory.unknown,
      modifiedAtToken: nextToken,
    );
    remote.updateResult = Result.success(updated);
    remote.getByIdResults[1] = Result.success(updated);
    await settleEditorRequest(admitted: vm.requestSave(activation: authority));
    expect(vm.savePhase, AdminSavePhase.completed);
    expect(vm.isDirty, isFalse);
    expect(remote.createInputs, hasLength(1));
    expect(remote.updateExpectedModifiedAt, [token]);
    expect(vm.name, ' B ');
    expect(vm.category, isNull);
    expect(local.session.state!.physicalCheckpoint!.snapshot.name, ' B ');
    expect(local.session.state!.physicalCheckpoint!.snapshot.category, isNull);
    expect(local.session.state!.remoteBaseline!.modifiedAtToken, nextToken);
  });

  test(
    'blank trimmed required fields cannot persist an invalid remote intent',
    () async {
      await vm.activate(accountId: account);
      final authority = vm.activation;
      vm
        ..setCity('   ', activation: authority)
        ..setName(' A ', activation: authority);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      expect(vm.savePhase, AdminSavePhase.failed);
      expect(remote.createInputs, isEmpty);
      expect(local.session.state!.physicalCheckpoint?.fieldWriteIntent, isNull);
      expect(vm.city, '   ');
    },
  );

  test('captured continuation after intent write failure '
      'preserves newer checkpoint B', () async {
    final original = sampleAdminSubmission(
      name: 'Original',
      description: null,
      modifiedAtToken: token,
    );
    remote.getByIdResults[1] = Result.success(original);
    await vm.activate(accountId: account, submissionId: 1);
    final authority = vm.activation;
    await settleEditorRequest(admitted: vm.requestLoad(activation: authority));
    await local.session.acquire(
      File('/local.jpg'),
      capacity: local.session.capacityContext,
    );
    vm.setName('A', activation: authority);
    var failIntent = true;
    local.drafts.onSave = (draft) async {
      if (draft.fieldWriteIntent != null && failIntent) {
        failIntent = false;
        return Result.error(Exception('intent checkpoint failed'));
      }
      return const Result.success(null);
    };
    await settleEditorRequest(admitted: vm.requestSave(activation: authority));
    expect(vm.savePhase, AdminSavePhase.failed);
    expect(remote.updateIds, isEmpty);
    expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
    vm
      ..setName('B', activation: authority)
      ..setCity(null, activation: authority);
    await vm.checkpointLocal();
    local.staged.onResolve = (_) async => Result.success(File('/local.jpg'));
    const receipt = SubmissionAsset(
      secureUrl: 'https://example.com/photo.jpg',
      width: 1,
      height: 1,
    );
    const association = AdminSubmissionAsset(
      id: 3,
      url: 'https://example.com/photo.jpg',
      width: 1,
      height: 1,
    );
    content.uploadImageTaskResult = FakeImageUploadTask.completed(
      const Result.success(receipt),
    );
    remote
      ..updateResult = Result.success(
        sampleAdminSubmission(
          name: 'A',
          description: null,
          modifiedAtToken: token,
        ),
      )
      ..addAssetResult = const Result.success(association);
    remote.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'A',
        description: null,
        modifiedAtToken: token,
        assets: [association],
      ),
    );
    expect(vm.canResumeCapturedSave, isTrue);
    await settleEditorRequest(
      admitted: vm.requestSave(activation: authority, resumeCaptured: true),
    );
    expect(vm.savePhase, AdminSavePhase.completed);
    expect(remote.updateInputs.single.name, 'A');
    expect(vm.name, 'B');
    expect(vm.city, isNull);
    expect(local.session.state!.physicalCheckpoint!.snapshot.name, 'B');
    expect(local.session.state!.physicalCheckpoint!.snapshot.city, isNull);
    expect(
      local.drafts.drafts[local.session.state!.owner.lookupKey]!.snapshot.name,
      'B',
    );
    expect(local.session.state!.remoteBaseline!.snapshot.name, 'A');
    expect(vm.isDirty, isTrue);
  });

  test('durable Save leaves repeated Keep-current eligible', () async {
    final group = AdminEventMergeGroup(
      name: 'name',
      providerChanged: true,
      moderatorChanged: false,
      apply: true,
      overwrite: true,
      base: const {},
      source: const {},
      moderated: const {},
      current: const {'name': 'Canonical'},
    );
    remote.previewResult = Result.success(
      AdminEventMergePreview(
        targetEventId: 99,
        submissionVersionToken: 'opaque-submission',
        eventVersionToken: 'opaque-event',
        groups: [group],
      ),
    );
    final initial = sampleAdminSubmission(
      name: 'A',
      description: null,
      modifiedAtToken: token,
      targetEventId: 42,
    );
    remote.getByIdResults[1] = Result.success(initial);
    await vm.activate(accountId: account, submissionId: 1);
    final authority = vm.activation;
    await settleEditorRequest(admitted: vm.requestLoad(activation: authority));
    vm
      ..selectTargetEvent(99, activation: authority)
      ..setName('B', activation: authority);
    final edited = sampleAdminSubmission(
      name: 'B',
      description: null,
      modifiedAtToken: token,
      targetEventId: 42,
    );
    remote.updateResult = Result.success(edited);
    remote.getByIdResults[1] = Result.success(edited);
    await settleEditorRequest(admitted: vm.requestSave(activation: authority));
    expect(vm.isDirty, isFalse);
    expect(vm.targetEventId, 99);
    await settleEditorRequest(
      admitted: vm.requestPreview(activation: authority),
    );
    final canonical = sampleAdminSubmission(
      name: 'Canonical',
      description: null,
      modifiedAtToken: token,
      targetEventId: 42,
    );
    remote.updateResult = Result.success(canonical);
    remote.getByIdResults[1] = Result.success(canonical);
    await settleEditorRequest(
      admitted: vm.requestKeepCurrent(group, activation: authority),
    );
    expect(vm.name, 'Canonical');
    expect(vm.isDirty, isFalse);
    expect(vm.targetEventId, 99);
    expect(vm.keepCurrentSnapshot.data, isA<Success<void>>());
    await settleEditorRequest(
      admitted: vm.requestKeepCurrent(group, activation: authority),
    );
    expect(vm.keepCurrentSnapshot.data, isA<Success<void>>());
    expect(vm.isDirty, isFalse);
    expect(vm.targetEventId, 99);
  });

  test('old Save presentation cannot revive after A1 to B to A2', () async {
    final initial = sampleAdminSubmission(
      name: 'A',
      description: null,
      modifiedAtToken: token,
    );
    remote.getByIdResults[1] = Result.success(initial);
    await vm.activate(accountId: account, submissionId: 1);
    final session = vm.sessionId;
    await settleEditorRequest(
      admitted: vm.requestLoad(activation: vm.activation),
    );
    await settleEditorRequest(
      admitted: vm.requestSave(activation: vm.activation),
    );
    final oldAttempt = vm.saveExecutionId;
    expect(oldAttempt, isNotNull);
    await vm.activate(accountId: account, submissionId: 2);
    await vm.activate(accountId: account, sessionId: session);
    expect(vm.saveExecutionId, isNull);
    expect(vm.saveSessionId, isNull);
    expect(vm.savePhase, AdminSavePhase.idle);
    await settleEditorRequest(
      admitted: vm.requestLoad(activation: vm.activation),
    );
    await settleEditorRequest(
      admitted: vm.requestSave(activation: vm.activation),
    );
    expect(vm.saveExecutionId, greaterThan(oldAttempt!));
  });

  test(
    'ambiguous Update requires explicit readback without blind resend',
    () async {
      final initial = sampleAdminSubmission(
        name: 'A',
        description: null,
        modifiedAtToken: token,
      );
      remote.getByIdResults[1] = Result.success(initial);
      await vm.activate(accountId: account, submissionId: 1);
      final authority = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: authority),
      );
      vm.setName('B', activation: authority);
      remote.updateResult = Result.error(Exception('response lost'));
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      expect(vm.savePhase, AdminSavePhase.unknownOutcome);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canRequestSaveReadBack, isTrue);
      await settleEditorRequest(
        admitted: vm.requestAddAsset(activation: authority),
      );
      await settleEditorRequest(
        admitted: vm.requestDeleteAsset(3, activation: authority),
      );
      expect(pickerResults, isEmpty);
      expect(content.uploadedImages, isEmpty);
      expect(remote.deleteAssetCalls, isEmpty);
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'B',
          description: null,
          modifiedAtToken: token,
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: authority),
      );
      expect(remote.updateIds, [1]);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(vm.canRequestSave, isTrue);
    },
  );

  test(
    'matching Update readback leaves staged work explicitly partial',
    () async {
      final initial = sampleAdminSubmission(
        name: 'A',
        description: null,
        modifiedAtToken: token,
      );
      remote.getByIdResults[1] = Result.success(initial);
      await vm.activate(accountId: account, submissionId: 1);
      final authority = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: authority),
      );
      await local.session.acquire(
        File('/local.jpg'),
        capacity: local.session.capacityContext,
      );
      vm.setName('B', activation: authority);
      remote.updateResult = Result.error(Exception('response lost'));
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      final saved = sampleAdminSubmission(
        name: 'B',
        description: null,
        modifiedAtToken: token,
      );
      remote.getByIdResults[1] = Result.success(saved);
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: authority),
      );
      expect(vm.savePhase, AdminSavePhase.partialFailure);
      expect(vm.stagedAssets, hasLength(1));
      expect(vm.canRequestSave, isTrue);
      local.staged.onResolve = (_) async => Result.success(File('/local.jpg'));
      const receipt = SubmissionAsset(
        secureUrl: 'https://example.com/photo.jpg',
        width: 1,
        height: 1,
      );
      content.uploadImageTaskResult = FakeImageUploadTask.completed(
        const Result.success(receipt),
      );
      const association = AdminSubmissionAsset(
        id: 3,
        url: 'https://example.com/photo.jpg',
        width: 1,
        height: 1,
      );
      remote.addAssetResult = const Result.success(association);
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'B',
          description: null,
          modifiedAtToken: token,
          assets: [association],
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      expect(remote.updateIds, [1]);
      expect(content.uploadedImages, hasLength(1));
      expect(vm.savePhase, AdminSavePhase.completed);
    },
  );

  test(
    'confirmed association retained for cleanup counts only one capacity slot',
    () async {
      final owner = AdminDraftOwner(accountId: account, submissionId: 1);
      final fields = AdminDraftSnapshot(
        category: ContentCategory.history,
        city: 'Campobasso',
        name: 'A',
      );
      local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
        owner: owner,
        snapshot: fields,
        remoteBaseline: AdminRemoteBaseline(
          snapshot: fields,
          status: AdminSubmissionStatus.pending,
          modifiedAt: DateTime.utc(2026, 10, 27),
          modifiedAtToken: token,
        ),
      );
      final associations = List.generate(
        4,
        (index) => AdminSubmissionAsset(
          id: index + 1,
          url: 'https://example.com/${index + 1}.jpg',
          width: 1,
          height: 1,
        ),
      );
      final retained = AdminSubmissionStagedAsset(
        owner: owner,
        digest: 'a' * 40,
        relativePath: '${owner.accountId}/${owner.sessionId}/${'a' * 40}',
        progress: AdminStagedAssetProgress(
          upload: const SubmissionAsset(
            secureUrl: 'https://example.com/1.jpg',
            width: 1,
            height: 1,
          ),
          associationId: 1,
        ),
      );
      local.staged.assets[owner] = [retained];
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'A',
          description: null,
          modifiedAtToken: token,
          assets: associations,
        ),
      );
      await vm.activate(accountId: account, submissionId: 1);
      final authority = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: authority),
      );
      expect(vm.imageCount, 4);
      await settleEditorRequest(
        admitted: vm.requestAddAsset(activation: authority),
      );
      expect(pickerResults, hasLength(1));
      pickerResults.single.complete(null);
      await settleEditorRequest(admitted: true);
      expect(content.uploadedImages, isEmpty);
      expect(vm.stagedAssets, hasLength(1));
    },
  );

  for (final phase in [
    AdminSavePhase.checkpoint,
    AdminSavePhase.fields,
    AdminSavePhase.adoption,
    AdminSavePhase.upload,
    AdminSavePhase.association,
  ]) {
    test('reentrant revoke at Save $phase starts no later phase', () async {
      final initial = sampleAdminSubmission(
        name: 'A',
        description: null,
        modifiedAtToken: token,
      );
      remote.getByIdResults[1] = Result.success(initial);
      await vm.activate(accountId: account, submissionId: 1);
      final authority = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: authority),
      );
      final assetPhase =
          phase == AdminSavePhase.upload || phase == AdminSavePhase.association;
      if (assetPhase) {
        await local.session.acquire(
          File('/local.jpg'),
          capacity: local.session.capacityContext,
        );
        local.staged.onResolve = (_) async =>
            Result.success(File('/local.jpg'));
        content.uploadImageTaskResult = FakeImageUploadTask.completed(
          const Result.success(
            SubmissionAsset(
              secureUrl: 'https://example.com/photo.jpg',
              width: 1,
              height: 1,
            ),
          ),
        );
      } else {
        vm.setName('B', activation: authority);
        remote.updateResult = Result.success(
          sampleAdminSubmission(
            name: 'B',
            description: null,
            modifiedAtToken: token,
          ),
        );
      }
      var revoked = false;
      vm.addListener(() {
        if (!revoked && vm.savePhase == phase) {
          revoked = true;
          vm.revoke();
        }
      });
      await settleEditorRequest(
        admitted: vm.requestSave(activation: authority),
      );
      expect(revoked, isTrue);
      expect(
        remote.updateIds,
        hasLength(phase == AdminSavePhase.adoption ? 1 : 0),
      );
      expect(
        content.uploadedImages,
        hasLength(phase == AdminSavePhase.association ? 1 : 0),
      );
      expect(remote.addAssetCalls, isEmpty);
      expect(remote.getByIdIds, [1]);
      expect(vm.accountId, isNull);
      expect(vm.name, isNull);
    });
  }

  for (final phase in ['before launch', 'before upload']) {
    test(
      'reentrant picker notification revoke $phase starts no later work',
      () async {
        final initial = sampleAdminSubmission(
          name: 'A',
          description: null,
          modifiedAtToken: token,
        );
        remote.getByIdResults[1] = Result.success(initial);
        await vm.activate(accountId: account, submissionId: 1);
        final authority = vm.activation;
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: authority),
        );
        var entered = false;
        var revoked = false;
        vm.addListener(() {
          if (vm.pickerWaiting) {
            entered = true;
            if (phase == 'before launch' && !revoked) {
              revoked = true;
              vm.revoke();
            }
          } else if (phase == 'before upload' && entered && !revoked) {
            revoked = true;
            vm.revoke();
          }
        });
        await settleEditorRequest(
          admitted: vm.requestAddAsset(activation: authority),
        );
        if (phase == 'before upload') {
          expect(pickerResults, hasLength(1));
          pickerResults.single.complete(XFile('/native.jpg'));
          await settleEditorRequest(admitted: true);
        } else {
          expect(pickerResults, isEmpty);
        }
        expect(revoked, isTrue);
        expect(content.uploadedImages, isEmpty);
        expect(remote.addAssetCalls, isEmpty);
        expect(vm.accountId, isNull);
      },
    );
  }

  for (final boundary in ['fields', 'upload']) {
    test(
      'raw $boundary error settles terminal presentation and safe continuation',
      () async {
        final initial = sampleAdminSubmission(
          name: 'A',
          description: null,
          modifiedAtToken: token,
        );
        remote.getByIdResults[1] = Result.success(initial);
        await vm.activate(accountId: account, submissionId: 1);
        final authority = vm.activation;
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: authority),
        );
        final pending = Completer<Result<AdminSubmission>>();
        final failure = StateError('unexpected $boundary failure');
        if (boundary == 'fields') {
          vm.setName('B', activation: authority);
          remote.pendingUpdate = pending;
        } else {
          await local.session.acquire(
            File('/local.jpg'),
            capacity: local.session.capacityContext,
          );
          local.staged.onResolve = (_) async =>
              Result.success(File('/local.jpg'));
          content.uploadImageTaskResult = FakeImageUploadTask.throwing(failure);
        }
        expect(vm.requestSave(activation: authority), isTrue);
        await settleEditorRequest(admitted: true);
        if (boundary == 'fields') {
          pending.completeError(failure);
          await settleEditorRequest(admitted: true);
        }
        expect(vm.isSaveRunning, isFalse);
        expect(vm.saveSnapshot.unexpectedError, same(failure));
        expect(
          vm.savePhase,
          boundary == 'fields'
              ? AdminSavePhase.unknownOutcome
              : AdminSavePhase.failed,
        );
        expect(
          boundary == 'fields' ? vm.canRequestSaveReadBack : vm.canRequestSave,
          isTrue,
        );
      },
    );
  }

  test('Save A confirmation preserves newer typing B and checkpoint', () async {
    final initial = sampleAdminSubmission(
      name: 'Original',
      description: null,
      modifiedAtToken: token,
    );
    remote.getByIdResults[1] = Result.success(initial);
    await vm.activate(accountId: account, submissionId: 1);
    final authority = vm.activation;
    await settleEditorRequest(admitted: vm.requestLoad(activation: authority));
    vm.setName('A', activation: authority);
    final pending = Completer<Result<AdminSubmission>>();
    remote.pendingUpdate = pending;
    expect(vm.requestSave(activation: authority), isTrue);
    await settleEditorRequest(admitted: true);
    vm.setName('B', activation: authority);
    await vm.checkpointLocal();
    final saved = sampleAdminSubmission(
      name: 'A',
      description: null,
      modifiedAtToken: token,
    );
    remote.getByIdResults[1] = Result.success(saved);
    pending.complete(Result.success(saved));
    await settleEditorRequest(admitted: true);
    expect(vm.name, 'B');
    expect(local.session.state!.physicalCheckpoint!.snapshot.name, 'B');
    expect(local.session.state!.remoteBaseline!.snapshot.name, 'A');
    expect(vm.isDirty, isTrue);
  });

  test('revoked hydration cannot publish into another account', () async {
    final pending = Completer<Result<AdminSubmission>>();
    remote.onGetById = (_) => pending.future;
    await vm.activate(accountId: account, submissionId: 1);
    expect(vm.requestLoad(activation: vm.activation), isTrue);
    await settleEditorRequest(admitted: true);
    vm.revoke();
    await vm.activate(accountId: AdminDraftSessionHarness.accountB);
    final b = vm.activation;
    vm.setName('B', activation: b);
    pending.complete(Result.success(sampleAdminSubmission(name: 'private A')));
    await settleEditorRequest(admitted: true);
    expect(vm.name, 'B');
    expect(vm.accountId, AdminDraftSessionHarness.accountB);
    expect(vm.hasLoadedDetail, isFalse);
  });

  for (final failure in [
    'upload receipt',
    'association response',
    'association receipt',
    'descriptor cleanup',
    'ASSET_METADATA_CONFLICT',
    'ASSET_LIMIT_REACHED',
    'INVALID_STATUS_TRANSITION',
  ]) {
    test(
      'staged retry preserves confirmed work after $failure failure',
      () async {
        final owner = AdminDraftOwner(accountId: account, submissionId: 1);
        final fields = AdminDraftSnapshot(
          category: ContentCategory.history,
          city: 'Campobasso',
          name: 'A',
        );
        local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
          owner: owner,
          snapshot: fields,
          remoteBaseline: AdminRemoteBaseline(
            snapshot: fields,
            status: AdminSubmissionStatus.pending,
            modifiedAt: DateTime.utc(2026, 10, 27),
            modifiedAtToken: token,
          ),
        );
        final asset = AdminSubmissionStagedAsset(
          owner: owner,
          digest: '1' * 40,
          relativePath: '${owner.accountId}/${owner.sessionId}/${'1' * 40}',
        );
        local.staged.assets[owner] = [asset];
        local.staged.onResolve = (_) async =>
            Result.success(File('/private/staged.jpg'));
        const receipt = SubmissionAsset(
          secureUrl: 'https://example.com/staged.jpg',
          width: 100,
          height: 100,
        );
        const associated = AdminSubmissionAsset(
          id: 3,
          url: 'https://example.com/staged.jpg',
          width: 100,
          height: 100,
        );
        content.uploadImageTaskResult = FakeImageUploadTask.completed(
          const Result.success(receipt),
        );
        final initial = sampleAdminSubmission(
          name: 'A',
          description: null,
          modifiedAtToken: token,
        );
        remote.getByIdResults[1] = Result.success(initial);
        remote.addAssetResult = const Result.success(associated);
        await vm.activate(accountId: account, submissionId: 1);
        final authority = vm.activation;
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: authority),
        );
        var failed = false;
        local.staged.onSaveProgress = (asset, progress) async {
          if (!failed &&
              ((failure == 'upload receipt' &&
                      progress.associationId == null) ||
                  (failure == 'association receipt' &&
                      progress.associationId != null))) {
            failed = true;
            return Result.error(Exception('local write failed'));
          }
          return const Result.success(null);
        };
        local.staged.onRemove = (_, _) async {
          if (failure == 'descriptor cleanup' && !failed) {
            failed = true;
            return Result.error(Exception('descriptor write failed'));
          }
          return const Result.success(null);
        };
        if (failure == 'association response') {
          remote.addAssetResult = Result.error(Exception('response lost'));
        }
        final terminal =
            failure.startsWith('ASSET_') ||
            failure == 'INVALID_STATUS_TRANSITION';
        if (terminal) {
          remote.addAssetResult = Result.error(
            AdminContentSubmissionApiException(
              statusCode: 409,
              message: 'Reload required',
              code: failure,
            ),
          );
        }
        await settleEditorRequest(
          admitted: vm.requestSave(activation: authority),
        );
        expect(
          vm.savePhase,
          terminal ? AdminSavePhase.conflict : AdminSavePhase.partialFailure,
        );
        expect(content.uploadedImages, hasLength(1));
        if (terminal) {
          expect(vm.canRequestSave, isFalse);
          expect(vm.stagedAssets, hasLength(1));
          expect(vm.canRequestLoad, isTrue);
          return;
        }
        expect(vm.stagedAssets, hasLength(1));
        vm.setCity(null, activation: authority);
        await vm.checkpointLocal();
        expect(vm.canResumeCapturedSave, isTrue);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: authority),
        );
        expect(vm.savePhase, AdminSavePhase.failed);
        expect(content.uploadedImages, hasLength(1));
        remote.addAssetResult = const Result.success(associated);
        remote.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            name: 'A',
            description: null,
            modifiedAtToken: token,
            assets: [associated],
          ),
        );
        await settleEditorRequest(
          admitted: vm.requestSave(activation: authority, resumeCaptured: true),
        );
        expect(vm.savePhase, AdminSavePhase.completed);
        expect(vm.city, isNull);
        expect(vm.isDirty, isTrue);
        expect(local.session.state!.physicalCheckpoint!.snapshot.city, isNull);
        expect(content.uploadedImages, hasLength(1));
        expect(
          remote.addAssetCalls,
          hasLength(failure == 'association response' ? 2 : 1),
        );
        expect(remote.updateIds, isEmpty);
        expect(vm.stagedAssets, isEmpty);
        expect(vm.assets.single.id, 3);
      },
    );
  }

  for (final outcome in ['image', 'cancel', 'error']) {
    test('resume before $outcome preserves valid native completion', () async {
      await vm.activate(accountId: account);
      expect(vm.requestAddAsset(activation: vm.activation), isTrue);
      await settleEditorRequest(admitted: true);
      expect(local.session.state!.currentMatchesDisk, isTrue);
      expect(
        local.session.state!.physicalCheckpoint!.navigationIntent,
        isNotNull,
      );
      // No VM lifecycle transition revokes this request on normal resume.
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(vm.pickerWaiting, isTrue);
      if (outcome == 'error') {
        pickerResults.single.completeError(Exception('native picker error'));
      } else {
        pickerResults.single.complete(
          outcome == 'image' ? XFile('/unused.jpg') : null,
        );
      }
      await settleEditorRequest(admitted: true);
      expect(vm.pickerWaiting, isFalse);
      expect(vm.canRequestAddAsset, isTrue);
      expect(vm.stagedAssets, hasLength(outcome == 'image' ? 1 : 0));
      expect(remote.addAssetCalls, isEmpty);
    });
  }

  test(
    'explicit abandonment releases admission and late A cannot clear B nonce',
    () async {
      await vm.activate(accountId: account);
      final authority = vm.activation;
      vm.requestAddAsset(activation: authority);
      await settleEditorRequest(admitted: true);
      final aNonce = local
          .session
          .state!
          .physicalCheckpoint!
          .navigationIntent!
          .requestNonce;
      vm.abandonPicker(requestNonce: vm.pickerRequestNonce!);
      await settleEditorRequest(admitted: true);
      expect(vm.canRequestAddAsset, isTrue);
      expect(
        local.session.state!.physicalCheckpoint!.navigationIntent!.requestNonce,
        aNonce,
      );
      vm.requestAddAsset(activation: authority);
      await settleEditorRequest(admitted: true);
      final bNonce = local
          .session
          .state!
          .physicalCheckpoint!
          .navigationIntent!
          .requestNonce;
      expect(bNonce, isNot(aNonce));
      pickerResults.first.complete(XFile('/late-A.jpg'));
      await settleEditorRequest(admitted: true);
      expect(vm.stagedAssets, isEmpty);
      expect(vm.pickerWaiting, isTrue);
      expect(
        local.session.state!.physicalCheckpoint!.navigationIntent!.requestNonce,
        bNonce,
      );
      pickerResults.last.complete(XFile('/B.jpg'));
      await settleEditorRequest(admitted: true);
      expect(vm.stagedAssets, hasLength(1));
      expect(local.session.state!.physicalCheckpoint!.navigationIntent, isNull);
    },
  );

  test(
    'logout while picker pending releases local wait without upload',
    () async {
      await vm.activate(accountId: account);
      vm.requestAddAsset(activation: vm.activation);
      await settleEditorRequest(admitted: true);
      vm.revoke();
      await vm.activate(accountId: AdminDraftSessionHarness.accountB);
      pickerResults.single.complete(XFile('/late-private-A.jpg'));
      await settleEditorRequest(admitted: true);
      expect(vm.stagedAssets, isEmpty);
      expect(remote.addAssetCalls, isEmpty);
      expect(vm.canRequestAddAsset, isTrue);
    },
  );
}
