import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/utils/result.dart';

import 'fake_image_picker.dart';
import 'fake_repositories.dart';
import 'mock_logger.dart';

/// Admits immediately and waits through upstream deferred action turns.
///
/// The returned bool describes admission only. Domain/runtime results remain on
/// the owner's frozen public snapshots; this helper never executes a Command.
Future<bool> requestAndWait(
  bool Function() request,
  bool Function() isRunning,
) async {
  final admitted = request();
  if (!admitted) return false;
  while (isRunning()) {
    await Future<void>.delayed(Duration.zero);
  }
  return true;
}

/// The ordered, durable P/Q fixture shared by the F2 race scenarios.
final class ContentSubmissionCommandFixture {
  ContentSubmissionCommandFixture._(
    this.vm,
    this.drafts,
    this.staged,
    this.repository,
    this.remoteFailure,
  );

  static const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
  static const firstDigest = '1111111111111111111111111111111111111111';
  static const secondDigest = '2222222222222222222222222222222222222222';
  final ContentSubmissionViewModel vm;
  final FakeContentSubmissionDraftRepository drafts;
  final FakeContentSubmissionStagedAssetRepository staged;
  final FakeContentSubmissionRepository repository;
  final Exception remoteFailure;

  /// Restores D0 and P/Q once; candidate bytes identify X (3), then Z (4).
  static Future<ContentSubmissionCommandFixture> ready({
    List<XFile>? candidates,
    FakeImagePicker? imagePicker,
    Result<void>? remoteResult,
  }) async {
    final failure = Exception('remote rejected');
    final drafts = FakeContentSubmissionDraftRepository(
      loadDraftResult: Result.success(
        ContentSubmissionDraft(
          clientSubmissionId: identity,
          city: 'Rome',
          name: 'D0',
          userEmail: 'anna@example.test',
          userName: 'Anna',
        ),
      ),
    );
    final staged = FakeContentSubmissionStagedAssetRepository(
      reconcileResult: Result.success([
        for (final digest in [firstDigest, secondDigest])
          ContentSubmissionStagedAsset(
            clientSubmissionId: identity,
            digest: digest,
            relativePath: '$identity/$digest',
          ),
      ]),
    );
    final repository = FakeContentSubmissionRepository(
      submitResult: remoteResult ?? Result.error(failure),
    );
    final vm = ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: repository,
      draftRepository: drafts,
      stagedAssetRepository: staged,
      imagePicker:
          imagePicker ??
          FakeImagePicker(
            onPickMultipleMedia: () async =>
                candidates ??
                [
                  XFile.fromData(Uint8List.fromList([3]), name: 'X.jpg'),
                ],
          ),
    );
    await vm.initialize();
    return ContentSubmissionCommandFixture._(
      vm,
      drafts,
      staged,
      repository,
      failure,
    );
  }
}

/// Drains deferred private continuations after public owner revocation.
Future<void> settleContentSubmissionTurns() async {
  for (var turn = 0; turn < 4; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Admits immediately and drives only virtual event turns for a fixture action.
Future<bool> requestAndPump(
  WidgetTester tester,
  bool Function() request,
  bool Function() isRunning,
) async {
  final admitted = request();
  if (!admitted) return false;
  for (var turn = 0; isRunning() && turn < 1000; turn++) {
    await tester.pump(Duration.zero);
  }
  if (isRunning()) {
    throw StateError('Fixture action did not settle in 1000 turns');
  }
  return true;
}

/// Releases owners registered by the existing feature test builders.
void disposeContentSubmissionOwners(List<VoidCallback> disposers) {
  for (final dispose in disposers.reversed) {
    dispose();
  }
  disposers.clear();
}
