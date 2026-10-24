import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/admin_editor_command_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_logger.dart';

void main() {
  for (final failingPhase in ['original', 'followup']) {
    for (final failure in ['expected', 'raw']) {
      test('M4 $failure $failingPhase refresh after committed Link', () async {
        final harness = AdminEditorCommandHarness();
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final original = Completer<Result<AdminSubmission>>();
        final followup = Completer<Result<AdminSubmission>>();
        final error = StateError('refresh $failingPhase');
        try {
          await harness.initialize();
          harness.repository
            ..linkResult = const Result.success(
              AdminEventResolution(
                outcome: 'linked',
                eventId: 42,
                pendingId: 2,
              ),
            )
            ..onGetById = (id) => id == 1 ? original.future : followup.future;
          expect(harness.owner.requestLink(42), isTrue);
          await pumpEventQueue(times: 4);
          expect(harness.repository.getByIdIds, [1, 1]);
          if (failingPhase == 'original') {
            if (failure == 'raw') {
              original.completeError(error, StackTrace.current);
            } else {
              original.complete(
                Result.error(TestException('detail unavailable')),
              );
            }
          } else {
            original.complete(Result.success(harness.submission));
          }
          await pumpEventQueue(times: 4);
          final rawOriginal = failingPhase == 'original' && failure == 'raw';
          expect(
            harness.repository.getByIdIds,
            rawOriginal ? [1, 1] : [1, 1, 2],
          );
          if (!rawOriginal) {
            if (failingPhase == 'followup' && failure == 'raw') {
              followup.completeError(error, StackTrace.current);
            } else if (failingPhase == 'followup') {
              followup.complete(
                Result.error(TestException('followup unavailable')),
              );
            } else {
              followup.complete(Result.success(sampleAdminSubmission(id: 2)));
            }
          }
          await pumpEventQueue(times: 4);
          expect(harness.repository.linkCalls, [(1, 42)]);
          expect(
            harness.owner.linkSnapshot.unexpectedError != null,
            failure == 'raw',
          );
          expect(harness.owner.linkSnapshot.completed, failure == 'expected');
          expect(
            logger.calls.where((call) => identical(call.error, error)),
            hasLength(failure == 'raw' ? 1 : 0),
          );
          expect(
            harness.owner.followupSubmission?.id,
            failingPhase == 'original' && failure == 'expected' ? 2 : null,
          );
        } finally {
          harness.owner.dispose();
          if (!original.isCompleted) {
            original.complete(Result.success(harness.submission));
          }
          if (!followup.isCompleted) {
            followup.complete(Result.success(sampleAdminSubmission(id: 2)));
          }
          await pumpEventQueue(times: 4);
        }
      });
    }
  }

  for (final phase in [
    'copy notify',
    'save pending',
    'saved notify',
    'preview pending',
  ]) {
    test('K4 revocation during $phase starts no later private phase', () async {
      final harness = AdminEditorCommandHarness();
      try {
        await harness.initialize();
        harness.hold();
        final saveId = harness.owner.saveExecutionId;
        final previewId = harness.owner.previewExecutionId;
        harness.owner.addListener(() {
          if (phase == 'copy notify' && harness.owner.isDirty ||
              phase == 'saved notify' &&
                  harness.repository.updateIds.isNotEmpty &&
                  !harness.owner.isDirty) {
            harness.owner.dispose();
          }
        });
        expect(harness.owner.requestKeepCurrent(harness.group), isTrue);
        await pumpEventQueue(times: 4);
        if (phase == 'save pending') harness.owner.dispose();
        if (phase == 'saved notify' || phase == 'preview pending') {
          harness.saveGate.complete(Result.success(harness.submission));
          await pumpEventQueue(times: 4);
        }
        if (phase == 'preview pending') {
          expect(harness.repository.previewCalls, [(1, 42), (1, 42)]);
          harness.owner.dispose();
        }
        expect(harness.owner.isDisposed, isTrue);
        final frozen = harness.owner.keepCurrentSnapshot;
        harness.release();
        await pumpEventQueue(times: 4);
        expect(identical(harness.owner.keepCurrentSnapshot, frozen), isTrue);
        expect(harness.owner.saveExecutionId, saveId);
        expect(harness.owner.previewExecutionId, previewId);
        expect(
          harness.repository.updateIds,
          phase == 'copy notify' ? isEmpty : [1],
        );
        expect(
          harness.repository.previewCalls.length,
          phase == 'preview pending' ? 2 : 1,
        );
      } finally {
        harness.owner.dispose();
        harness.release();
        await pumpEventQueue(times: 4);
      }
    });
  }

  for (final phase in ['picker', 'upload', 'association']) {
    test(
      'U3 dispose during $phase respects remote cancellation limits',
      () async {
        final harness = AdminEditorCommandHarness();
        final upload = FakeImageUploadTask.pending();
        final association = Completer<Result<AdminSubmissionAsset>>();
        const asset = SubmissionAsset(
          secureUrl: 'https://example.com/upload.jpg',
          width: 2,
          height: 3,
        );
        try {
          await harness.initialize();
          harness.content.uploadImageTaskResult = upload;
          harness.repository.pendingAddAsset = association;
          expect(harness.owner.requestAddAsset(), isTrue);
          await pumpEventQueue(times: 4);
          if (phase != 'picker') {
            harness.pickerGate.complete(XFile('/controlled/image.jpg'));
            await pumpEventQueue(times: 4);
            expect(harness.content.uploadedImages, hasLength(1));
          }
          if (phase == 'association') {
            upload.complete(const Result.success(asset));
            await pumpEventQueue(times: 4);
            expect(harness.repository.addAssetCalls, [(1, asset)]);
          }
          final assets = harness.owner.assets.toList();
          harness.owner.dispose();
          await pumpEventQueue(times: 4);
          expect(upload.cancelCallCount, phase == 'picker' ? 0 : 1);
          expect(harness.owner.debugCommandDisposalCounts[7], 0);
          if (phase == 'picker') {
            harness.pickerGate.complete(XFile('/controlled/image.jpg'));
          } else if (phase == 'upload') {
            // cancel() deliberately did not complete this physical Future.
            upload.complete(const Result.success(asset));
          } else {
            association.complete(
              const Result.success(
                AdminSubmissionAsset(id: 9, url: 'remote', width: 2, height: 3),
              ),
            );
          }
          await pumpEventQueue(times: 4);
          expect(harness.owner.assets, assets);
          expect(
            harness.repository.addAssetCalls,
            phase == 'association' ? [(1, asset)] : isEmpty,
          );
          expect(
            harness.content.uploadedImages,
            phase == 'picker' ? isEmpty : hasLength(1),
          );
          expect(harness.repository.deleteAssetCalls, isEmpty);
          expect(harness.owner.debugCommandDisposalCounts[7], 1);
          expect(upload.cancelCallCount, phase == 'picker' ? 0 : 1);
        } finally {
          harness.owner.dispose();
          if (!harness.pickerGate.isCompleted) {
            harness.pickerGate.complete(null);
          }
          if (!association.isCompleted) {
            association.complete(Result.error(TestException('unused')));
          }
          await pumpEventQueue(times: 4);
        }
      },
    );
  }

  test('Q3 Preview target ABA requires a fresh explicit attempt', () async {
    final harness = AdminEditorCommandHarness();
    try {
      await harness.initialize();
      harness.hold();
      expect(harness.owner.requestPreview(), isTrue);
      final first = harness.owner.previewExecutionId;
      await pumpEventQueue(times: 4);
      harness.owner
        ..selectTargetEvent(43)
        ..selectTargetEvent(42);
      expect(harness.owner.requestPreview(), isFalse);
      harness.previewGate.complete(Result.success(harness.preview));
      await pumpEventQueue(times: 4);
      expect(harness.owner.mergePreview, isNull);
      expect(harness.owner.previewSnapshot.completed, isFalse);
      harness.repository.pendingPreview = null;
      expect(harness.owner.requestPreview(), isTrue);
      await pumpEventQueue(times: 4);
      expect(harness.owner.previewExecutionId, isNot(first));
      expect(harness.owner.mergePreview, same(harness.preview));
      expect(harness.repository.previewCalls, [(1, 42), (1, 42), (1, 42)]);
    } finally {
      harness.owner.dispose();
      harness.release();
      await pumpEventQueue(times: 4);
    }
  });

  for (final first in ['preview', 'save']) {
    test(
      'Q4 Preview then Save succeeds with $first completing first',
      () async {
        final harness = AdminEditorCommandHarness();
        try {
          await harness.initialize();
          harness.hold();
          expect(harness.owner.requestPreview(), isTrue);
          await pumpEventQueue(times: 4);
          expect(harness.owner.requestSave(), isTrue);
          await pumpEventQueue(times: 4);
          if (first == 'preview') {
            harness.previewGate.complete(Result.success(harness.preview));
          } else {
            harness.saveGate.complete(Result.success(harness.submission));
          }
          await pumpEventQueue(times: 4);
          expect(harness.owner.mergePreview, isNull);
          if (first == 'preview') {
            harness.saveGate.complete(Result.success(harness.submission));
          } else {
            harness.previewGate.complete(Result.success(harness.preview));
          }
          await pumpEventQueue(times: 4);
          expect(harness.owner.mergePreview, isNull);
          expect(harness.owner.previewSnapshot.completed, isFalse);
          expect(harness.owner.saveSnapshot.completed, isTrue);
          expect(harness.owner.canCloseAfterSave, isTrue);
          expect(harness.repository.updateIds, [1]);
        } finally {
          harness.owner.dispose();
          harness.release();
          await pumpEventQueue(times: 4);
        }
      },
    );
  }

  test('K3 old KeepCurrent group cannot use a replacement preview', () async {
    final harness = AdminEditorCommandHarness();
    try {
      await harness.initialize();
      final replacement = AdminEventMergePreview(
        targetEventId: 42,
        submissionVersionToken: 'new-submission',
        eventVersionToken: 'new-event',
        groups: [
          AdminEventMergeGroup(
            name: 'name',
            providerChanged: true,
            moderatorChanged: false,
            apply: true,
            overwrite: true,
            base: const {},
            source: const {},
            moderated: const {},
            current: const {'name': 'Replacement canonical name'},
          ),
        ],
      );
      harness.repository.previewResult = Result.success(replacement);
      await settleEditorRequest(admitted: harness.owner.requestPreview());
      expect(harness.owner.mergePreview, same(replacement));
      await settleEditorRequest(
        admitted: harness.owner.requestKeepCurrent(harness.group),
      );
      expect(harness.owner.keepCurrentSnapshot.hasFailure, isTrue);
      expect(harness.repository.updateIds, isEmpty);
      expect(harness.owner.name, harness.submission.name);
    } finally {
      harness.owner.dispose();
      await pumpEventQueue(times: 4);
    }
  });

  for (final code in ['EVENT_CHANGED', 'SUBMISSION_CHANGED']) {
    test(
      'M5 Apply $code revokes tokens until a fresh explicit preview',
      () async {
        final harness = AdminEditorCommandHarness();
        final error = AdminContentSubmissionApiException(
          statusCode: 409,
          message: 'Conflict',
          code: code,
        );
        try {
          await harness.initialize();
          harness.repository.applyResult = Result.error(error);
          await settleEditorRequest(admitted: harness.owner.requestApply());
          expect(harness.owner.applySnapshot.domainError, same(error));
          expect(harness.owner.mergePreview, isNull);
          expect(harness.repository.applyCalls, [(1, harness.preview)]);
          await settleEditorRequest(admitted: harness.owner.requestApply());
          expect(harness.owner.applySnapshot.hasFailure, isTrue);
          expect(harness.repository.applyCalls, hasLength(1));
          await settleEditorRequest(admitted: harness.owner.requestPreview());
          harness.repository.applyResult = const Result.success(
            AdminEventResolution(outcome: 'applied', eventId: 42),
          );
          await settleEditorRequest(admitted: harness.owner.requestApply());
          expect(harness.repository.applyCalls, [
            (1, harness.preview),
            (1, harness.preview),
          ]);
          expect(harness.owner.applySnapshot.completed, isTrue);
        } finally {
          harness.owner.dispose();
          await pumpEventQueue(times: 4);
        }
      },
    );
  }

  for (final failure in ['expected', 'raw']) {
    test(
      'K2 private Preview $failure after a committed KeepCurrent Save',
      () async {
        final harness = AdminEditorCommandHarness();
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final raw = StateError('private Preview');
        final expected = TestException('private Preview unavailable');
        try {
          await harness.initialize();
          harness.hold();
          expect(harness.owner.requestKeepCurrent(harness.group), isTrue);
          await pumpEventQueue(times: 4);
          expect(harness.repository.updateIds, [1]);
          harness.saveGate.complete(Result.success(harness.submission));
          await pumpEventQueue(times: 4);
          expect(harness.repository.previewCalls, [(1, 42), (1, 42)]);
          if (failure == 'raw') {
            harness.previewGate.completeError(raw, StackTrace.current);
          } else {
            harness.previewGate.complete(Result.error(expected));
          }
          await pumpEventQueue(times: 4);
          expect(harness.owner.isDirty, isFalse);
          expect(harness.owner.keepCurrentSnapshot.completed, isFalse);
          expect(harness.owner.keepCurrentSnapshot.hasFailure, isTrue);
          expect(harness.owner.saveExecutionId, isNull);
          expect(harness.owner.saveSnapshot.idle, isTrue);
          expect(harness.owner.canCloseAfterSave, isFalse);
          expect(harness.owner.previewSnapshot.hasFailure, isFalse);
          expect(harness.owner.mergePreview, isNull);
          if (failure == 'expected') {
            expect(
              harness.owner.keepCurrentSnapshot.domainError,
              same(expected),
            );
          } else {
            expect(
              harness.owner.keepCurrentSnapshot.unexpectedError,
              same(raw),
            );
          }
          expect(
            logger.calls.where((call) => identical(call.error, raw)),
            hasLength(failure == 'raw' ? 1 : 0),
          );
        } finally {
          harness.owner.dispose();
          harness.release();
          await pumpEventQueue(times: 4);
        }
      },
    );
  }

  for (final phase in [
    'invalidation notify',
    'original pending',
    'followup pending',
  ]) {
    test('M6 Link revocation during $phase starts no later refresh', () async {
      final harness = AdminEditorCommandHarness();
      final followup = Completer<Result<AdminSubmission>>();
      try {
        await harness.initialize();
        harness.hold();
        harness.repository.onGetById = (id) =>
            id == 1 ? harness.loadGate.future : followup.future;
        expect(harness.owner.requestLink(42), isTrue);
        await pumpEventQueue(times: 4);
        if (phase == 'invalidation notify') {
          harness.owner.addListener(harness.owner.dispose);
        }
        harness.linkGate.complete(
          const Result.success(
            AdminEventResolution(outcome: 'linked', eventId: 42, pendingId: 2),
          ),
        );
        await pumpEventQueue(times: 4);
        if (phase == 'original pending') harness.owner.dispose();
        if (phase == 'followup pending') {
          expect(harness.repository.getByIdIds, [1, 1]);
          harness.loadGate.complete(Result.success(harness.submission));
          await pumpEventQueue(times: 4);
          expect(harness.repository.getByIdIds, [1, 1, 2]);
          harness.owner.dispose();
        }
        expect(harness.owner.isDisposed, isTrue);
        final frozen = harness.owner.linkSnapshot;
        if (!harness.loadGate.isCompleted) {
          harness.loadGate.complete(Result.success(harness.submission));
        }
        followup.complete(Result.success(sampleAdminSubmission(id: 2)));
        await pumpEventQueue(times: 4);
        expect(harness.repository.getByIdIds, switch (phase) {
          'invalidation notify' => [1],
          'original pending' => [1, 1],
          _ => [1, 1, 2],
        });
        expect(harness.owner.followupSubmission, isNull);
        expect(identical(harness.owner.linkSnapshot, frozen), isTrue);
        expect(harness.repository.linkCalls, [(1, 42)]);
      } finally {
        harness.owner.dispose();
        harness.release();
        if (!followup.isCompleted) {
          followup.complete(Result.error(TestException('unused')));
        }
        await pumpEventQueue(times: 4);
      }
    });
  }

  for (
    var lane = 0;
    lane < AdminEditorCommandHarness.laneNames.length;
    lane++
  ) {
    for (final revoke in ['after request']) {
      test(
        'L1 ${AdminEditorCommandHarness.laneNames[lane]} revoke $revoke',
        () async {
          final harness = AdminEditorCommandHarness();
          try {
            await harness.initialize();
            harness.hold();
            expect(harness.requests[lane](), isTrue);
            harness.owner.dispose();
            await pumpEventQueue(times: 4);
            expect(harness.calls, everyElement(0));
            expect(harness.owner.debugCommandDisposalCounts, everyElement(1));
            expect(harness.requests[lane](), isFalse);
          } finally {
            harness.owner.dispose();
            harness.release();
            await pumpEventQueue(times: 4);
          }
        },
      );
    }
  }
}
