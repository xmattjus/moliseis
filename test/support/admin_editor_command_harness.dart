import 'dart:async';

import 'package:command_it/command_it.dart' as commands;
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';

import 'command_test_support.dart';
import 'fake_image_picker.dart';
import 'fake_repositories.dart';

/// Controlled real editor owner shared by admission and receipt regressions.
final class AdminEditorCommandHarness {
  AdminEditorCommandHarness() {
    group = AdminEventMergeGroup(
      name: 'name',
      providerChanged: true,
      moderatorChanged: false,
      apply: true,
      overwrite: true,
      base: const {},
      source: const {},
      moderated: const {},
      current: const {'name': 'Canonical name'},
    );
    submission = sampleAdminSubmission(
      startDate: DateTime.utc(2026, 10, 2),
      targetEventId: 42,
      externalEvent: AdminExternalEvent(
        recordId: 5,
        snapshotHash: 'source-hash',
        snapshotVersion: 1,
        snapshot: const {},
        mode: AdminExternalEventMode.update,
        eventId: 42,
      ),
      assets: const [
        AdminSubmissionAsset(
          id: 7,
          url: 'https://example.com/asset.jpg',
          width: 1,
          height: 1,
        ),
      ],
    );
    preview = AdminEventMergePreview(
      targetEventId: 42,
      submissionVersionToken: 'opaque-submission',
      eventVersionToken: 'opaque-event',
      groups: [group],
    );
    repository = FakeAdminContentSubmissionRepository(
      getByIdResults: {1: Result.success(submission)},
    )..previewResult = Result.success(preview);
    content = FakeContentSubmissionRepository();
    picker = FakeImagePicker(onPickImage: () => pickerGate.future);
    owner = AdminSubmissionEditorViewModel(
      repository: repository,
      contentSubmissionRepository: content,
      imagePicker: picker,
      submissionId: 1,
    );
  }

  static const laneNames = [
    'Ld',
    'Sv',
    'Rj',
    'Pr',
    'Ln',
    'Ap',
    'Kc',
    'Aa',
    'Da',
    'Pv',
    'Fc',
  ];

  late final AdminSubmissionEditorViewModel owner;
  late final FakeAdminContentSubmissionRepository repository;
  late final FakeContentSubmissionRepository content;
  late final FakeImagePicker picker;
  late final AdminSubmission submission;
  late final AdminEventMergeGroup group;
  late final AdminEventMergePreview preview;
  final loadGate = Completer<Result<AdminSubmission>>();
  final saveGate = Completer<Result<AdminSubmission>>();
  final rejectGate = Completer<Result<void>>();
  final promoteGate = Completer<Result<AdminSubmissionPromotion>>();
  final linkGate = Completer<Result<AdminEventResolution>>();
  final applyGate = Completer<Result<AdminEventResolution>>();
  final previewGate = Completer<Result<AdminEventMergePreview>>();
  final candidatesGate = Completer<Result<AdminEventCandidates>>();
  final deleteGate = Completer<Result<void>>();
  final pickerGate = Completer<XFile?>();

  /// Hydrates and installs a valid preview before barriers are attached.
  Future<void> initialize() async {
    await settleEditorRequest(admitted: owner.requestLoad());
    await settleEditorRequest(admitted: owner.requestPreview());
  }

  /// Installs independent physical barriers without replacing repository fakes.
  void hold() {
    repository.onGetById = (_) => loadGate.future;
    repository.pendingUpdate = saveGate;
    repository.pendingReject = rejectGate;
    repository.pendingPromote = promoteGate;
    repository.onLink =
        (_, _, {acknowledgeCurrentSource, expectedSourceHash}) =>
            linkGate.future;
    repository.pendingApply = applyGate;
    repository.pendingPreview = previewGate;
    repository.onEventCandidates = (_, _, _) => candidatesGate.future;
    repository.pendingDeleteAsset = deleteGate;
  }

  List<bool Function()> get requests => [
    owner.requestLoad,
    owner.requestSave,
    owner.requestReject,
    () => owner.requestPromote(AdminPromotionTarget.event),
    () => owner.requestLink(42),
    owner.requestApply,
    () => owner.requestKeepCurrent(group),
    owner.requestAddAsset,
    () => owner.requestDeleteAsset(7),
    owner.requestPreview,
    owner.requestFindCandidates,
  ];

  List<commands.CommandResult<void, Result<dynamic>?>> get snapshots => [
    owner.loadSnapshot,
    owner.saveSnapshot,
    owner.rejectSnapshot,
    owner.promoteSnapshot,
    owner.linkSnapshot,
    owner.applySnapshot,
    owner.keepCurrentSnapshot,
    owner.addAssetSnapshot,
    owner.deleteAssetSnapshot,
    owner.previewSnapshot,
    owner.findCandidatesSnapshot,
  ];

  List<int?> get executionIds => [
    owner.loadExecutionId,
    owner.saveExecutionId,
    owner.rejectExecutionId,
    owner.promoteExecutionId,
    owner.linkExecutionId,
    owner.applyExecutionId,
    owner.keepCurrentExecutionId,
    owner.addAssetExecutionId,
    owner.deleteAssetExecutionId,
    owner.previewExecutionId,
    owner.findCandidatesExecutionId,
  ];

  /// Physical calls in matrix order; excludes initialization already completed.
  List<int> get calls => [
    repository.getByIdIds.length - 1,
    repository.updateIds.length,
    repository.rejectIds.length,
    repository.promoteCalls.length,
    repository.linkCalls.length,
    repository.applyCalls.length,
    repository.updateIds.length,
    picker.pickImageSources.length,
    repository.deleteAssetCalls.length,
    repository.previewCalls.length - 1,
    repository.candidateCalls.length,
  ];

  /// Releases one lane with an expected failure unless a raw failure is given.
  /// KeepCurrent shares its private Save phase's barrier.
  void releaseLane(int lane, {Object? error, StackTrace? stackTrace}) {
    void complete<T>(Completer<Result<T>> gate) {
      if (gate.isCompleted) return;
      if (error != null) {
        gate.completeError(error, stackTrace ?? StackTrace.current);
      } else {
        gate.complete(Result.error(TestException('controlled matrix result')));
      }
    }

    switch (lane) {
      case 0:
        complete(loadGate);
      case 1 || 6:
        complete(saveGate);
      case 2:
        complete(rejectGate);
      case 3:
        complete(promoteGate);
      case 4:
        complete(linkGate);
      case 5:
        complete(applyGate);
      case 7:
        if (!pickerGate.isCompleted) {
          if (error == null) {
            pickerGate.complete(null);
          } else {
            pickerGate.completeError(error, stackTrace ?? StackTrace.current);
          }
        }
      case 8:
        complete(deleteGate);
      case 9:
        complete(previewGate);
      case 10:
        complete(candidatesGate);
    }
  }

  /// Releases all gates for cleanup; this never manufactures remote rollback.
  /// Raw failures go only to physically entered gates with attached consumers.
  void release({Object? error, StackTrace? stackTrace}) {
    final entered = calls;
    for (var lane = 0; lane < laneNames.length; lane++) {
      releaseLane(
        lane,
        error: entered[lane] > 0 ? error : null,
        stackTrace: stackTrace,
      );
    }
  }
}
