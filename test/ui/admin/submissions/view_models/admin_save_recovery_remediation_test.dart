import 'dart:async';

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
  const account = AdminDraftSessionHarness.accountA;
  const version = '2026-10-27T12:30:00.123456+00:00';
  const nextVersion = '2026-10-27T12:30:01.654321+00:00';
  const attempt = '11111111-1111-4111-8111-111111111111';
  const changed = AdminContentSubmissionApiException(
    statusCode: 409,
    code: 'SUBMISSION_CHANGED',
    message: 'The conditional write updated no row.',
  );
  const validation = AdminContentSubmissionApiException(
    statusCode: 400,
    code: 'VALIDATION_ERROR',
    message: 'Rejected before dispatch.',
  );
  final a = AdminDraftSnapshot(
    category: ContentCategory.history,
    city: 'Campobasso',
    name: 'Captured A',
  );
  final b = a.copyWith(name: 'Checkpoint B', latitudeText: '-');
  final intent = AdminFieldWriteIntent(
    kind: AdminFieldWriteKind.update,
    attemptId: attempt,
    snapshot: a,
    expectedModifiedAt: version,
  );
  late AdminDraftSessionHarness local;
  late FakeAdminContentSubmissionRepository remote;
  late FakeContentSubmissionRepository content;
  late AdminSubmissionEditorViewModel vm;
  late AdminDraftOwner owner;
  late AdminSubmissionDraft restored;
  late AdminRemoteBaseline baseline;

  setUp(() {
    addTearDown(installCommandTestReporting(MockLogger()));
    local = AdminDraftSessionHarness();
    remote = FakeAdminContentSubmissionRepository();
    content = FakeContentSubmissionRepository();
    owner = AdminDraftOwner(accountId: account, submissionId: 1);
    baseline = AdminRemoteBaseline(
      snapshot: a.copyWith(name: 'Original'),
      status: AdminSubmissionStatus.pending,
      modifiedAt: DateTime.utc(2026, 10, 27),
      modifiedAtToken: version,
    );
    local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
      owner: owner,
      snapshot: baseline.snapshot,
      remoteBaseline: baseline,
    );
    restored = AdminSubmissionDraft(
      owner: owner,
      snapshot: b,
      remoteBaseline: baseline,
      fieldWriteIntent: intent,
    );
    remote.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'Original',
        description: null,
        modifiedAtToken: version,
      ),
    );
    vm = AdminSubmissionEditorViewModel(
      repository: remote,
      contentSubmissionRepository: content,
      draftSession: local.session,
    );
  });
  tearDown(() => vm.dispose());

  group('explicit stale recovery', () {
    setUp(() {
      local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
        owner: owner,
        snapshot: a,
        remoteBaseline: baseline,
      );
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Remote W',
          description: null,
          modifiedAtToken: nextVersion,
        ),
      );
    });

    test(
      'historical association is unavailable before complete evidence',
      () async {
        final digest = 'a' * 40;
        final staged = AdminSubmissionStagedAsset(
          owner: owner,
          digest: digest,
          relativePath: '$account/${owner.sessionId}/$digest',
          progress: AdminStagedAssetProgress(
            upload: const SubmissionAsset(
              secureUrl: 'https://example.com/confirmed.jpg',
              width: 10,
              height: 20,
            ),
            associationId: 77,
          ),
        );
        local.staged.assets[owner] = [staged];
        await vm.activate(accountId: account, submissionId: 1);
        expect(vm.isStagedAssociationUnavailable(staged), isTrue);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: vm.activation),
        );
        expect(local.staged.progressSaves, isEmpty);
        expect(local.staged.removals, isEmpty);
        expect(remote.getByIdIds, isEmpty);
        expect(remote.addAssetCalls, isEmpty);
        expect(content.uploadedImages, isEmpty);
      },
    );

    test(
      'Keep changes only R and new Save captures W, never display metadata',
      () async {
        await vm.activate(accountId: account, submissionId: 1);
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        final observation = vm.recoveryObservation!;
        expect(vm.canRequestSave, isFalse);
        expect(
          vm.requestReconcile(
            observation,
            acceptRemote: false,
            activation: vm.activation,
          ),
          isTrue,
        );
        await settleEditorRequest(admitted: true);
        expect(local.session.state!.current, a);
        expect(local.session.state!.physicalCheckpoint!.snapshot, a);
        expect(
          local.session.state!.remoteBaseline!.modifiedAtToken,
          nextVersion,
        );
        expect(remote.updateIds, isEmpty);
        remote.updateResult = Result.success(
          sampleAdminSubmission(
            name: a.name!,
            description: null,
            modifiedAtToken: nextVersion,
          ),
        );
        remote.getByIdResults[1] = remote.updateResult;
        await settleEditorRequest(
          admitted: vm.requestSave(activation: vm.activation),
        );
        expect(remote.updateExpectedModifiedAt, [nextVersion]);
        expect(remote.updateInputs.single.name, a.name);
      },
    );

    test('Accept creates F1 obligation; failed then successful '
        'checkpoint gates switch', () async {
      await vm.activate(accountId: account, submissionId: 1);
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: vm.activation),
      );
      final observation = vm.recoveryObservation!;
      await settleEditorRequest(
        admitted: vm.requestReconcile(
          observation,
          acceptRemote: true,
          activation: vm.activation,
        ),
      );
      expect(vm.name, 'Remote W');
      expect(vm.pendingRecoveryCheckpoint, isTrue);
      expect(remote.updateIds, isEmpty);
      expect(local.drafts.saves, isEmpty);
      expect(
        await vm.activate(accountId: account, submissionId: 2),
        isA<Error<void>>(),
      );
      local.drafts.onSave = (_) async => Result.error(Exception('disk'));
      expect(await vm.checkpointLocal(), isA<Error<void>>());
      expect(vm.pendingRecoveryCheckpoint, isTrue);
      expect(
        await vm.activate(accountId: account, submissionId: 2),
        isA<Error<void>>(),
      );
      local.drafts.onSave = null;
      expect(await vm.checkpointLocal(), isA<Success<void>>());
      expect(vm.pendingRecoveryCheckpoint, isFalse);
      expect(
        await vm.activate(accountId: account, submissionId: 2),
        isA<Success<void>>(),
      );
      await vm.activate(accountId: account, submissionId: 1);
      expect(vm.name, 'Remote W');
    });

    test(
      'unresolved A/V cannot use observed W until existing read-back settlement',
      () async {
        local.drafts.drafts[owner.lookupKey] = restored;
        await vm.activate(accountId: account, submissionId: 1);
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        final observation = vm.recoveryObservation!;
        expect(
          vm.requestReconcile(
            observation,
            acceptRemote: false,
            activation: vm.activation,
          ),
          isFalse,
        );
        expect(vm.requestSave(activation: vm.activation), isFalse);
        expect(remote.updateIds, isEmpty);
        await settleEditorRequest(
          admitted: vm.requestSaveReadBack(activation: vm.activation),
        );
        expect(
          local.session.state!.physicalCheckpoint!.fieldWriteIntent,
          isNull,
        );
        expect(vm.canRequestSave, isFalse);
      },
    );

    test('typing and replacement invalidate observations '
        'including A1 B A2', () async {
      await vm.activate(accountId: account, submissionId: 1);
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: vm.activation),
      );
      final first = vm.recoveryObservation!;
      final activation = vm.activation;
      vm.setName('new local', activation: activation);
      expect(
        vm.requestReconcile(first, acceptRemote: true, activation: activation),
        isFalse,
      );
      await vm.checkpointLocal();
      await vm.activate(accountId: account, submissionId: 2);
      await vm.activate(accountId: account, submissionId: 1);
      expect(
        vm.requestReconcile(first, acceptRemote: true, activation: activation),
        isFalse,
      );
      expect(vm.name, 'new local');
    });

    test(
      'W to X conditional rejection preserves local fields without retry',
      () async {
        await vm.activate(accountId: account, submissionId: 1);
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        await settleEditorRequest(
          admitted: vm.requestReconcile(
            vm.recoveryObservation!,
            acceptRemote: false,
            activation: vm.activation,
          ),
        );
        remote.updateResult = const Result.error(changed);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: vm.activation),
        );
        expect(remote.updateExpectedModifiedAt, [nextVersion]);
        expect(vm.name, a.name);
        expect(vm.canRequestSave, isFalse);
        expect(local.session.state!.physicalCheckpoint!.snapshot, a);
      },
    );

    test('Accept then no-op Save checkpoints without field Update', () async {
      await vm.activate(accountId: account, submissionId: 1);
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: vm.activation),
      );
      await settleEditorRequest(
        admitted: vm.requestReconcile(
          vm.recoveryObservation!,
          acceptRemote: true,
          activation: vm.activation,
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestSave(activation: vm.activation),
      );
      expect(remote.updateIds, isEmpty);
      expect(vm.pendingRecoveryCheckpoint, isFalse);
      expect(
        local.session.state!.physicalCheckpoint!.snapshot.name,
        'Remote W',
      );
    });

    test(
      'new observation admission invalidates W before choice or Save entry',
      () async {
        await vm.activate(accountId: account, submissionId: 1);
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        final observation = vm.recoveryObservation!;
        final read = Completer<Result<AdminSubmission>>();
        remote.onGetById = (_) => read.future;
        expect(vm.requestLoad(activation: vm.activation), isTrue);
        expect(
          vm.requestReconcile(
            observation,
            acceptRemote: false,
            activation: vm.activation,
          ),
          isFalse,
        );
        read.complete(Result.error(Exception('offline')));
        await settleEditorRequest(admitted: true);
        expect(vm.recoveryObservation, isNull);
        expect(vm.canRequestSave, isFalse);
        expect(vm.name, a.name);
        expect(remote.updateIds, isEmpty);
      },
    );

    test(
      'accepted W is rechecked after synchronous Save notification',
      () async {
        await vm.activate(accountId: account, submissionId: 1);
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        await settleEditorRequest(
          admitted: vm.requestReconcile(
            vm.recoveryObservation!,
            acceptRemote: false,
            activation: vm.activation,
          ),
        );
        final writesBefore = local.drafts.saves.length;
        var revoked = false;
        void supersede() {
          if (!revoked && vm.isSaveRunning) {
            revoked = true;
            local.session.admitHydration();
          }
        }

        vm.addListener(supersede);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: vm.activation),
        );
        vm.removeListener(supersede);
        expect(revoked, isTrue);
        expect(remote.updateIds, isEmpty);
        expect(local.drafts.saves, hasLength(writesBefore));
        expect(vm.name, a.name);
      },
    );

    test('changed Create adoption requires deliberate choice '
        'even when R already equals remote', () async {
      local.drafts.drafts.clear();
      await vm.activate(accountId: account);
      final activation = vm.activation;
      vm
        ..setName(a.name, activation: activation)
        ..setCity(a.city, activation: activation);
      remote.createResult = remote.getByIdResults[1]!;
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(vm.submissionId, 1);
      expect(vm.name, a.name);
      expect(vm.canRequestSave, isFalse);
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: vm.activation),
      );
      expect(vm.recoveryObservation, isNotNull);
      expect(vm.canRequestSave, isFalse);
      expect(remote.createInputs, hasLength(1));
      expect(remote.updateIds, isEmpty);
      await settleEditorRequest(
        admitted: vm.requestReconcile(
          vm.recoveryObservation!,
          acceptRemote: false,
          activation: vm.activation,
        ),
      );
      expect(vm.canRequestSave, isTrue);
      expect(local.session.state!.remoteBaseline!.modifiedAtToken, nextVersion);
    });

    for (final invalid in ['token', 'target', 'missingToken']) {
      test(
        'invalid $invalid detail grants no recovery or Save authority',
        () async {
          await vm.activate(accountId: account, submissionId: 1);
          remote.getByIdResults[1] = Result.success(
            sampleAdminSubmission(
              id: invalid == 'target' ? 2 : 1,
              modifiedAtToken: invalid == 'token'
                  ? 'invalid'
                  : (invalid == 'missingToken' ? null : nextVersion),
            ),
          );
          await settleEditorRequest(
            admitted: vm.requestLoad(activation: vm.activation),
          );
          expect(vm.recoveryObservation, isNull);
          expect(vm.recoveryState, AdminEditorRecoveryState.incompatible);
          expect(vm.canRequestSave, isFalse);
          expect(vm.name, a.name);
          expect(remote.updateIds, isEmpty);
        },
      );
    }

    test(
      'authorization loss after field dispatch retains uncertain intent',
      () async {
        await vm.activate(accountId: account, submissionId: 1);
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        await settleEditorRequest(
          admitted: vm.requestReconcile(
            vm.recoveryObservation!,
            acceptRemote: false,
            activation: vm.activation,
          ),
        );
        remote.updateResult = const Result.error(
          AdminContentSubmissionApiException(
            statusCode: 403,
            code: 'FORBIDDEN',
            message: 'Denied',
          ),
        );
        await settleEditorRequest(
          admitted: vm.requestSave(activation: vm.activation),
        );
        final original =
            local.session.state!.physicalCheckpoint!.fieldWriteIntent;
        expect(original, isNotNull);
        expect(original!.expectedModifiedAt, nextVersion);
        expect(vm.recoveryState, AdminEditorRecoveryState.denied);
        expect(vm.canRequestSave, isFalse);
        await settleEditorRequest(
          admitted: vm.requestSaveReadBack(activation: vm.activation),
        );
        expect(vm.recoveryState, AdminEditorRecoveryState.unresolvedIntent);
        expect(
          local.session.state!.physicalCheckpoint!.fieldWriteIntent,
          original,
        );
        expect(remote.updateExpectedModifiedAt, [nextVersion]);
      },
    );

    for (final statusCode in [401, 403, 404]) {
      test('classified $statusCode read keeps fields '
          'and never settles unknown intent', () async {
        local.drafts.drafts[owner.lookupKey] = restored;
        await vm.activate(accountId: account, submissionId: 1);
        remote.getByIdResults[1] = Result.error(
          AdminContentSubmissionApiException(
            statusCode: statusCode,
            code: statusCode == 404 ? 'NOT_FOUND' : 'FORBIDDEN',
            message: 'Unavailable',
          ),
        );
        await settleEditorRequest(
          admitted: vm.requestLoad(activation: vm.activation),
        );
        expect(
          vm.recoveryState,
          statusCode == 404
              ? AdminEditorRecoveryState.missing
              : AdminEditorRecoveryState.denied,
        );
        expect(vm.canRequestSave, isFalse);
        expect(
          local.session.state!.physicalCheckpoint!.fieldWriteIntent,
          intent,
        );
        expect(vm.name, b.name);
        expect(remote.updateIds, isEmpty);
      });
    }

    for (final receiptState in [
      'missing',
      'contradicted',
      'present',
      'uploadOnly',
      'deletedLocally',
      'addedImmediately',
      'associatedEarlier',
    ]) {
      test(
        '$receiptState association preserves exact receipt semantics',
        () async {
          final digest = 'a' * 40;
          final staged = AdminSubmissionStagedAsset(
            owner: owner,
            digest: digest,
            relativePath: '$account/${owner.sessionId}/$digest',
            progress: AdminStagedAssetProgress(
              upload: const SubmissionAsset(
                secureUrl: 'https://example.com/confirmed.jpg',
                width: 10,
                height: 20,
              ),
              associationId: receiptState == 'uploadOnly' ? null : 77,
            ),
          );
          local.staged.assets[owner] = [staged];
          const uploadB = SubmissionAsset(
            secureUrl: 'https://example.com/new.jpg',
            width: 30,
            height: 40,
          );
          const associationB = AdminSubmissionAsset(
            id: 88,
            url: 'https://example.com/new.jpg',
            width: 30,
            height: 40,
          );
          final addsAnother =
              receiptState == 'addedImmediately' ||
              receiptState == 'associatedEarlier';
          if (receiptState == 'addedImmediately') {
            vm.dispose();
            vm = AdminSubmissionEditorViewModel(
              repository: remote,
              contentSubmissionRepository: content,
              draftSession: local.session,
              imagePicker: FakeImagePicker(
                onPickImage: () async => XFile('selected-b.jpg'),
              ),
            );
            content.uploadImageTaskResult = FakeImageUploadTask.completed(
              const Result.success(uploadB),
            );
          }
          if (receiptState == 'associatedEarlier') {
            final digestB = 'b' * 40;
            local.staged.assets[owner]!.insert(
              0,
              AdminSubmissionStagedAsset(
                owner: owner,
                digest: digestB,
                relativePath: '$account/${owner.sessionId}/$digestB',
                progress: AdminStagedAssetProgress(upload: uploadB),
              ),
            );
          }
          final association = AdminSubmissionAsset(
            id: 77,
            url: 'https://example.com/confirmed.jpg',
            width: receiptState == 'contradicted' ? 11 : 10,
            height: 20,
          );
          remote.getByIdResults[1] = Result.success(
            sampleAdminSubmission(
              name: 'Remote W',
              description: null,
              modifiedAtToken: nextVersion,
              assets: receiptState == 'missing' || addsAnother
                  ? []
                  : [association],
            ),
          );
          remote.addAssetResult = Result.success(
            addsAnother ? associationB : association,
          );
          await vm.activate(accountId: account, submissionId: 1);
          await settleEditorRequest(
            admitted: vm.requestLoad(activation: vm.activation),
          );
          await settleEditorRequest(
            admitted: vm.requestReconcile(
              vm.recoveryObservation!,
              acceptRemote: true,
              activation: vm.activation,
            ),
          );
          if (receiptState == 'deletedLocally') {
            await settleEditorRequest(
              admitted: vm.requestDeleteAsset(77, activation: vm.activation),
            );
          }
          if (receiptState == 'addedImmediately') {
            await settleEditorRequest(
              admitted: vm.requestAddAsset(activation: vm.activation),
            );
            expect(vm.assets.map((asset) => asset.id), contains(88));
          }
          await settleEditorRequest(
            admitted: vm.requestSave(activation: vm.activation),
          );
          if (receiptState == 'missing' ||
              receiptState == 'contradicted' ||
              receiptState == 'deletedLocally' ||
              addsAnother) {
            expect(vm.stagedAssets.single, staged);
            expect(local.staged.assets[owner]!.single, staged);
            expect(
              local.staged.removals.map((entry) => entry.digest),
              isNot(contains(digest)),
            );
            expect(remote.addAssetCalls, hasLength(addsAnother ? 1 : 0));
            if (addsAnother) {
              expect(remote.addAssetCalls.single.$2, uploadB);
              expect(vm.isStagedAssociationUnavailable(staged), isTrue);
            }
            // Explicit local removal remains independent of remote proof.
            await settleEditorRequest(
              admitted: vm.requestRemoveStagedAsset(
                staged,
                activation: vm.activation,
              ),
            );
            expect(vm.stagedAssets, isEmpty);
            expect(local.drafts.drafts[owner.lookupKey], isNotNull);
            expect(
              remote.deleteAssetCalls,
              hasLength(receiptState == 'deletedLocally' ? 1 : 0),
            );
          } else {
            expect(vm.stagedAssets, isEmpty);
            expect(local.staged.removals, hasLength(1));
            expect(
              remote.addAssetCalls,
              hasLength(receiptState == 'uploadOnly' ? 1 : 0),
            );
          }
          expect(
            content.uploadedImages,
            hasLength(receiptState == 'addedImmediately' ? 1 : 0),
          );
        },
      );
    }
  });

  test(
    'fresh conditional rejection settles only A and preserves newer B',
    () async {
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      vm.setName(a.name, activation: activation);
      final request = Completer<Result<AdminSubmission>>();
      remote.pendingUpdate = request;
      expect(vm.requestSave(activation: activation), isTrue);
      await settleEditorRequest(admitted: true);
      vm
        ..setName(b.name, activation: activation)
        ..setLatitudeText(b.latitudeText, activation: activation);
      expect(await vm.checkpointLocal(), isA<Success<void>>());
      request.complete(const Result.error(changed));
      await settleEditorRequest(admitted: true);

      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(local.session.state!.current, b);
      expect(local.session.state!.remoteBaseline!.modifiedAtToken, version);
      expect(vm.savePhase, AdminSavePhase.conflict);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(vm.requestSave(activation: activation), isFalse);
      expect(remote.updateExpectedModifiedAt, [version]);

      // Compatible fresh authority, rather than settlement, permits later B.
      remote.pendingUpdate = null;
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Original',
          description: null,
          modifiedAtToken: nextVersion,
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      expect(vm.name, b.name);
      expect(vm.canRequestSave, isTrue);
      vm.setLatitudeText('', activation: activation);
      final savedB = sampleAdminSubmission(
        name: b.name!,
        description: null,
        modifiedAtToken: nextVersion,
      );
      remote.updateResult = Result.success(savedB);
      remote.getByIdResults[1] = Result.success(savedB);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(remote.updateInputs.map((input) => input.name), [a.name, b.name]);
      expect(remote.updateExpectedModifiedAt, [version, nextVersion]);
    },
  );

  for (final failure in [
    validation,
    const AdminContentSubmissionApiException(
      statusCode: 422,
      code: 'START_DATE_REQUIRED',
      message: 'No dispatch.',
    ),
    const AdminContentSubmissionApiException(
      statusCode: 409,
      code: 'INVALID_STATUS_TRANSITION',
      message: 'No pending row.',
    ),
    const AdminContentSubmissionApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'No matching parent.',
    ),
  ]) {
    test('fresh ${failure.code} settles without borrowing stale V', () async {
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      vm.setName(a.name, activation: activation);
      remote.updateResult = Result.error(failure);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(vm.name, a.name);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(vm.requestSave(activation: activation), isFalse);
      expect(remote.updateIds, [1]);
    });
  }

  for (final failure in [
    validation,
    const AdminContentSubmissionApiException(
      statusCode: 422,
      code: 'ADMIN_PROFILE_INCOMPLETE',
      message: 'Profile rejected before Create.',
    ),
  ]) {
    test(
      'fresh Create ${failure.code} permits correction under same UUID',
      () async {
        local.drafts.drafts.remove(owner.lookupKey);
        await vm.activate(accountId: account);
        final activation = vm.activation;
        final uuid = vm.sessionId;
        vm
          ..setName(a.name, activation: activation)
          ..setCity(a.city, activation: activation)
          ..setCategory(a.category, activation: activation);
        remote.createResult = Result.error(failure);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: activation),
        );
        expect(
          local.session.state!.physicalCheckpoint!.fieldWriteIntent,
          isNull,
        );
        expect(vm.canRequestSave, isTrue);
        expect(vm.canResumeCapturedSave, isFalse);
        expect(vm.sessionId, uuid);
        vm.setName('Corrected B', activation: activation);
        final saved = sampleAdminSubmission(
          name: 'Corrected B',
          description: null,
          modifiedAtToken: nextVersion,
        );
        remote.createResult = Result.success(saved);
        remote.getByIdResults[1] = Result.success(saved);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: activation),
        );
        expect(remote.createClientSubmissionIds, [uuid, uuid]);
        expect(remote.createInputs.map((input) => input.name), [
          a.name,
          'Corrected B',
        ]);
        expect(vm.submissionId, 1);
        expect(vm.savePhase, AdminSavePhase.completed);
      },
    );
  }

  test(
    'settlement write failure is a local-only explicit retry preserving B',
    () async {
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      vm.setName(a.name, activation: activation);
      remote.updateResult = const Result.error(changed);
      local.drafts.onSave = (draft) async => draft.fieldWriteIntent == null
          ? Result.error(TestException('settlement unavailable'))
          : const Result.success(null);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(
        local.session.state!.physicalCheckpoint!.fieldWriteIntent,
        isNotNull,
      );
      expect(vm.savePhase, AdminSavePhase.partialFailure);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canRequestFieldSettlement, isTrue);
      vm
        ..setName(b.name, activation: activation)
        ..setLatitudeText(b.latitudeText, activation: activation);
      expect(await vm.checkpointLocal(), isA<Success<void>>());
      local.drafts.onSave = null;
      expect(vm.requestFieldSettlement(activation: activation), isTrue);
      expect(vm.requestFieldSettlement(activation: activation), isFalse);
      await settleEditorRequest(admitted: true);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(local.session.state!.current, b);
      expect(vm.canRequestFieldSettlement, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(vm.savePhase, AdminSavePhase.conflict);
      expect(vm.saveSnapshot.hasFailure, isTrue);
      expect(remote.updateIds, [1]);
    },
  );

  test('safely settled intent cannot reappear on VM reconstruction', () async {
    await vm.activate(accountId: account, submissionId: 1);
    final activation = vm.activation;
    await settleEditorRequest(admitted: vm.requestLoad(activation: activation));
    vm.setName(a.name, activation: activation);
    remote.updateResult = const Result.error(changed);
    await settleEditorRequest(admitted: vm.requestSave(activation: activation));
    expect(local.drafts.drafts[owner.lookupKey]!.fieldWriteIntent, isNull);
    vm.dispose();
    vm = AdminSubmissionEditorViewModel(
      repository: remote,
      contentSubmissionRepository: content,
      draftSession: local.session,
    );
    await vm.activate(accountId: account, sessionId: owner.sessionId);
    expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
    expect(vm.canResumeCapturedSave, isFalse);
    expect(remote.updateIds, [1]);
    expect(vm.name, a.name);
  });

  for (final failure in <Exception>[
    TimeoutException('transport deadline'),
    Exception('network failure'),
    const FormatException('malformed response after possible commit'),
    const AdminContentSubmissionApiException(
      statusCode: 400,
      code: 'UNRECOGNIZED_ERROR',
      message: 'Not proven.',
    ),
    const AdminContentSubmissionApiException(
      statusCode: 409,
      code: 'UNRECOGNIZED_ERROR',
      message: 'Not proven.',
    ),
    const AdminContentSubmissionApiException(
      statusCode: 500,
      code: 'VALIDATION_ERROR',
      message: 'Wrong endpoint semantics.',
    ),
  ]) {
    test('ambiguous $failure retains the durable original Update', () async {
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      vm.setName(a.name, activation: activation);
      remote.updateResult = Result.error(failure);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(
        local.session.state!.physicalCheckpoint!.fieldWriteIntent!.snapshot,
        a,
      );
      expect(
        local
            .session
            .state!
            .physicalCheckpoint!
            .fieldWriteIntent!
            .expectedModifiedAt,
        version,
      );
      expect(vm.savePhase, AdminSavePhase.unknownOutcome);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canRequestSaveReadBack, isTrue);
    });
  }

  for (final failure in [changed, validation]) {
    test('restored Update current ${failure.code} '
        'does not prove older non-application', () async {
      local.drafts.drafts[owner.lookupKey] = restored;
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: activation),
      );
      expect(vm.canResumeCapturedSave, isTrue);
      remote.updateResult = Result.error(failure);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation, resumeCaptured: true),
      );
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
      expect(local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(vm.canRequestSaveReadBack, isTrue);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(vm.savePhase, AdminSavePhase.unknownOutcome);
    });
  }

  test(
    'restored Create correction retains UUID when an old commit can exist',
    () async {
      local.drafts.drafts.remove(owner.lookupKey);
      final newOwner = AdminDraftOwner(accountId: account);
      final createIntent = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.create,
        attemptId: attempt,
        snapshot: a,
      );
      local.drafts.drafts[newOwner.lookupKey] = AdminSubmissionDraft(
        owner: newOwner,
        snapshot: b.copyWith(latitudeText: ''),
        fieldWriteIntent: createIntent,
      );
      await vm.activate(accountId: account, sessionId: newOwner.sessionId);
      final activation = vm.activation;
      remote.createResult = const Result.error(validation);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation, resumeCaptured: true),
      );
      expect(
        local.session.state!.physicalCheckpoint!.fieldWriteIntent,
        createIntent,
      );
      expect(remote.createInputs.single.name, a.name);
      remote.createResult = Result.success(
        sampleAdminSubmission(
          name: a.name!,
          description: null,
          modifiedAtToken: nextVersion,
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(remote.createInputs.map((input) => input.name), [a.name, b.name]);
      expect(remote.createClientSubmissionIds, [
        newOwner.sessionId,
        newOwner.sessionId,
      ]);
      expect(vm.submissionId, 1);
      expect(vm.name, b.name);
      expect(local.session.state!.physicalCheckpoint!.snapshot.name, b.name);
      expect(vm.savePhase, AdminSavePhase.conflict);
      expect(remote.updateIds, isEmpty);
    },
  );

  test('Create transport ambiguity replays A with the same UUID', () async {
    local.drafts.drafts.remove(owner.lookupKey);
    await vm.activate(accountId: account);
    final activation = vm.activation;
    final uuid = vm.sessionId;
    vm
      ..setName(a.name, activation: activation)
      ..setCity(a.city, activation: activation)
      ..setCategory(a.category, activation: activation);
    remote.createResult = Result.error(
      TimeoutException('response may be lost'),
    );
    await settleEditorRequest(admitted: vm.requestSave(activation: activation));
    final pending = local.session.state!.physicalCheckpoint!.fieldWriteIntent;
    expect(pending, isNotNull);
    vm
      ..setName(b.name, activation: activation)
      ..setLatitudeText('-', activation: activation);
    await vm.checkpointLocal();
    final savedA = sampleAdminSubmission(
      name: a.name!,
      description: null,
      modifiedAtToken: nextVersion,
    );
    remote.createResult = Result.success(savedA);
    remote.getByIdResults[1] = Result.success(savedA);
    await settleEditorRequest(
      admitted: vm.requestSave(activation: activation, resumeCaptured: true),
    );
    expect(remote.createClientSubmissionIds, [uuid, uuid]);
    expect(remote.createInputs.map((input) => input.name), [a.name, a.name]);
    expect(vm.name, b.name);
    expect(vm.latitudeText, '-');
    expect(vm.submissionId, 1);
  });

  test(
    'rejected fields preserve staged receipts, associations and navigation',
    () async {
      const upload = SubmissionAsset(
        secureUrl: 'https://example.com/photo.jpg',
        width: 2,
        height: 3,
      );
      final assets = [
        for (var index = 0; index < 3; index++)
          AdminSubmissionStagedAsset(
            owner: owner,
            digest: '${index + 1}' * 40,
            relativePath:
                '${owner.accountId}/${owner.sessionId}/${'${index + 1}' * 40}',
            progress: index == 0
                ? null
                : AdminStagedAssetProgress(
                    upload: upload,
                    associationId: index == 2 ? 9 : null,
                  ),
          ),
      ];
      final navigation = AdminNavigationIntent(requestNonce: attempt);
      local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
        owner: owner,
        snapshot: baseline.snapshot,
        remoteBaseline: baseline,
        navigationIntent: navigation,
      );
      local.staged.assets[owner] = assets;
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Original',
          description: null,
          modifiedAtToken: version,
          assets: [
            const AdminSubmissionAsset(
              id: 9,
              url: 'https://example.com/photo.jpg',
              width: 2,
              height: 3,
            ),
          ],
        ),
      );
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      vm.setName(a.name, activation: activation);
      remote.updateResult = const Result.error(validation);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(vm.stagedAssets, assets);
      expect(vm.assets.single.id, 9);
      expect(
        local.session.state!.physicalCheckpoint!.navigationIntent,
        navigation,
      );
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.staged.progressSaves, isEmpty);
      expect(local.staged.removals, isEmpty);
      expect(content.uploadedImages, isEmpty);
      expect(remote.addAssetCalls, isEmpty);
    },
  );

  test(
    'unchanged V read-back allows one explicit original A/V retry',
    () async {
      local.drafts.drafts[owner.lookupKey] = restored;
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      final activation = vm.activation;
      expect(remote.updateIds, isEmpty);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: activation),
      );
      expect(remote.updateIds, isEmpty);
      expect(vm.canResumeCapturedSave, isTrue);
      expect(vm.requestSave(activation: activation), isFalse);
      final savedA = sampleAdminSubmission(
        name: a.name!,
        description: null,
        modifiedAtToken: nextVersion,
      );
      remote.updateResult = Result.success(savedA);
      remote.getByIdResults[1] = Result.success(savedA);
      expect(
        vm.requestSave(activation: activation, resumeCaptured: true),
        isTrue,
      );
      expect(
        vm.requestSave(activation: activation, resumeCaptured: true),
        isFalse,
      );
      await settleEditorRequest(admitted: true);
      expect(remote.updateInputs.single.name, a.name);
      expect(remote.updateExpectedModifiedAt, [version]);
      expect(local.session.state!.current, b);
      expect(local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.session.state!.remoteBaseline!.modifiedAtToken, nextVersion);
      expect(vm.savePhase, AdminSavePhase.completed);
    },
  );

  test(
    'retry conflict reads back an original winning A without resending B',
    () async {
      local.drafts.drafts[owner.lookupKey] = restored;
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: activation),
      );
      remote.updateResult = const Result.error(changed);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation, resumeCaptured: true),
      );
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: a.name!,
          description: null,
          modifiedAtToken: nextVersion,
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: activation),
      );
      expect(remote.updateIds, [1]);
      expect(remote.updateExpectedModifiedAt, [version]);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(vm.name, b.name);
      expect(local.session.state!.remoteBaseline!.snapshot, a);
      expect(local.session.state!.remoteBaseline!.modifiedAtToken, nextVersion);
    },
  );

  test('read-back of A preserves newer C/P and uses observed token', () async {
    local.drafts.drafts[owner.lookupKey] = restored;
    await vm.activate(accountId: account, sessionId: owner.sessionId);
    remote.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: a.name!,
        description: null,
        modifiedAtToken: nextVersion,
      ),
    );
    await settleEditorRequest(
      admitted: vm.requestSaveReadBack(activation: vm.activation),
    );
    expect(local.session.state!.current, b);
    expect(local.session.state!.physicalCheckpoint!.snapshot, b);
    expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
    expect(local.session.state!.remoteBaseline!.modifiedAtToken, nextVersion);
    expect(remote.updateIds, isEmpty);
  });

  test('different advanced projection fences A '
      'without enabling fresh-token overwrite', () async {
    local.drafts.drafts[owner.lookupKey] = restored;
    await vm.activate(accountId: account, sessionId: owner.sessionId);
    final activation = vm.activation;
    remote.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'Other moderator',
        description: null,
        modifiedAtToken: nextVersion,
      ),
    );
    await settleEditorRequest(
      admitted: vm.requestSaveReadBack(activation: activation),
    );
    expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
    expect(vm.canRequestSave, isFalse);
    expect(vm.canResumeCapturedSave, isFalse);
    expect(vm.savePhase, AdminSavePhase.conflict);
    expect(vm.name, b.name);
    expect(await vm.checkpointLocal(), isA<Success<void>>());
    expect(local.session.state!.physicalCheckpoint!.snapshot, b);
    expect(remote.updateIds, isEmpty);
  });

  for (final status in [
    AdminSubmissionStatus.accepted,
    AdminSubmissionStatus.rejected,
  ]) {
    test('finalized ${status.name} read-back cannot mutate', () async {
      local.drafts.drafts[owner.lookupKey] = restored;
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      final activation = vm.activation;
      remote.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: a.name!,
          description: null,
          modifiedAtToken: version,
          status: status,
        ),
      );
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: activation),
      );
      expect(vm.canRequestSave, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
      expect(vm.name, b.name);
      expect(remote.updateIds, isEmpty);
    });
  }

  for (final failure in <Exception>[
    Exception('read transport failure'),
    const AdminContentSubmissionApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'Read target missing',
    ),
  ]) {
    test('read-back $failure retains the unresolved intent', () async {
      local.drafts.drafts[owner.lookupKey] = restored;
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      remote.getByIdResults[1] = Result.error(failure);
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: vm.activation),
      );
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(
        vm.savePhase,
        failure is AdminContentSubmissionApiException
            ? AdminSavePhase.conflict
            : AdminSavePhase.unknownOutcome,
      );
      expect(local.session.state!.current, b);
      expect(remote.updateIds, isEmpty);
    });
  }

  test('incompatible imported provenance cannot authorize A/V retry', () async {
    local.drafts.drafts[owner.lookupKey] = restored;
    await vm.activate(accountId: account, sessionId: owner.sessionId);
    remote.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'Original',
        description: null,
        modifiedAtToken: version,
        externalEvent: AdminExternalEvent(
          recordId: 1,
          snapshotHash: 'source',
          snapshotVersion: 1,
          snapshot: const {},
          mode: AdminExternalEventMode.create,
        ),
      ),
    );
    await settleEditorRequest(
      admitted: vm.requestSaveReadBack(activation: vm.activation),
    );
    expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
    expect(vm.canResumeCapturedSave, isFalse);
    expect(vm.canRequestSave, isFalse);
    expect(vm.savePhase, AdminSavePhase.conflict);
    expect(remote.updateIds, isEmpty);
  });

  test(
    'observing no-op A at V permits subsequent changed B only under V',
    () async {
      final noOp = AdminFieldWriteIntent(
        kind: AdminFieldWriteKind.update,
        attemptId: attempt,
        snapshot: baseline.snapshot,
        expectedModifiedAt: version,
      );
      local.drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
        owner: owner,
        snapshot: a,
        remoteBaseline: baseline,
        fieldWriteIntent: noOp,
      );
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: activation),
      );
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.session.state!.remoteBaseline!.modifiedAtToken, version);
      final savedB = sampleAdminSubmission(
        name: a.name!,
        description: null,
        modifiedAtToken: nextVersion,
      );
      remote.updateResult = Result.success(savedB);
      remote.getByIdResults[1] = Result.success(savedB);
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      expect(remote.updateExpectedModifiedAt, [version]);
      expect(remote.updateInputs.single.name, a.name);
      expect(vm.savePhase, AdminSavePhase.completed);
    },
  );

  test(
    'reconstruction loses retry observation and never automatically dispatches',
    () async {
      local.drafts.drafts[owner.lookupKey] = restored;
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: vm.activation),
      );
      expect(vm.canResumeCapturedSave, isTrue);
      vm.dispose();
      vm = AdminSubmissionEditorViewModel(
        repository: remote,
        contentSubmissionRepository: content,
        draftSession: local.session,
      );
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      expect(vm.canRequestSave, isFalse);
      expect(vm.canResumeCapturedSave, isFalse);
      expect(remote.updateIds, isEmpty);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, intent);
    },
  );

  test('stale A1 local-settlement callback cannot act in B or A2', () async {
    await vm.activate(accountId: account, submissionId: 1);
    final a1 = vm.activation;
    await settleEditorRequest(admitted: vm.requestLoad(activation: a1));
    vm.setName(a.name, activation: a1);
    remote.updateResult = const Result.error(changed);
    local.drafts.onSave = (draft) async => draft.fieldWriteIntent == null
        ? Result.error(TestException('settlement unavailable'))
        : const Result.success(null);
    await settleEditorRequest(admitted: vm.requestSave(activation: a1));
    expect(vm.canRequestFieldSettlement, isTrue);
    final pending = local.drafts.drafts[owner.lookupKey]!.fieldWriteIntent;
    local.drafts.onSave = null;
    vm.revoke();
    await vm.activate(accountId: AdminDraftSessionHarness.accountB);
    final beforeB = local.session.state;
    expect(vm.requestFieldSettlement(activation: a1), isFalse);
    expect(local.session.state, same(beforeB));
    await vm.activate(accountId: account, sessionId: owner.sessionId);
    final beforeA2 = local.session.state;
    expect(vm.isActivationCurrent(a1), isFalse);
    expect(vm.requestFieldSettlement(activation: a1), isFalse);
    expect(local.session.state, same(beforeA2));
    expect(local.drafts.drafts[owner.lookupKey]!.fieldWriteIntent, pending);
    expect(remote.updateIds, [1]);
  });

  for (final originalWins in [false, true]) {
    test('explicit retry with physically outstanding original A: '
        'original wins=$originalWins', () async {
      await vm.activate(accountId: account, submissionId: 1);
      final activation = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestLoad(activation: activation),
      );
      vm.setName(a.name, activation: activation);
      final original = Completer<Result<AdminSubmission>>();
      remote.pendingUpdate = original;
      await settleEditorRequest(
        admitted: vm.requestSave(activation: activation),
      );
      vm
        ..setName(b.name, activation: activation)
        ..setLatitudeText(b.latitudeText, activation: activation);
      await vm.checkpointLocal();
      vm.dispose();
      vm = AdminSubmissionEditorViewModel(
        repository: remote,
        contentSubmissionRepository: content,
        draftSession: local.session,
      );
      await vm.activate(accountId: account, sessionId: owner.sessionId);
      final resumed = vm.activation;
      await settleEditorRequest(
        admitted: vm.requestSaveReadBack(activation: resumed),
      );
      expect(vm.canResumeCapturedSave, isTrue);
      final appliedA = sampleAdminSubmission(
        name: a.name!,
        description: null,
        modifiedAtToken: nextVersion,
      );
      remote.pendingUpdate = null;
      if (originalWins) {
        original.complete(Result.success(appliedA));
        await settleEditorRequest(admitted: true);
        remote.updateResult = const Result.error(changed);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: resumed, resumeCaptured: true),
        );
        expect(vm.canRequestSaveReadBack, isTrue);
        remote.getByIdResults[1] = Result.success(appliedA);
        await settleEditorRequest(
          admitted: vm.requestSaveReadBack(activation: resumed),
        );
      } else {
        remote.updateResult = Result.success(appliedA);
        remote.getByIdResults[1] = Result.success(appliedA);
        await settleEditorRequest(
          admitted: vm.requestSave(activation: resumed, resumeCaptured: true),
        );
        original.complete(const Result.error(changed));
        await settleEditorRequest(admitted: true);
      }
      // The repository fake models delivery order only. Real PostgreSQL
      // contract tests establish which conditional write can actually win.
      expect(remote.updateInputs.map((input) => input.name), [a.name, a.name]);
      expect(remote.updateExpectedModifiedAt, [version, version]);
      expect(local.session.state!.current, b);
      expect(local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(local.session.state!.physicalCheckpoint!.fieldWriteIntent, isNull);
      expect(local.session.state!.remoteBaseline!.modifiedAtToken, nextVersion);
      expect(vm.isActivationCurrent(resumed), isTrue);
      expect(vm.savePhase, AdminSavePhase.completed);
    });
  }
}
