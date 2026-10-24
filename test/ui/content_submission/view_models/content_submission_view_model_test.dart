import 'dart:async';
import 'dart:io';

import 'package:command_it/command_it.dart' as commands;
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/content_submission_command_harness.dart';
import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/mock_objectbox.dart';
import '../../../support/objectbox_test_store.dart';
import '../../../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  late MockLogger commandLogger;
  setUp(() {
    commandLogger = MockLogger();
    addTearDown(installCommandTestReporting(commandLogger));
  });
  ContentSubmissionViewModel buildViewModel({
    FakeImagePicker? imagePicker,
    ContentSubmissionRepository? contentSubmissionRepository,
    FakeContentSubmissionDraftRepository? draftRepository,
    FakeContentSubmissionStagedAssetRepository? stagedAssetRepository,
    MockLogger? logger,
  }) {
    final log = logger ?? MockLogger();
    return ContentSubmissionViewModel(
      logger: log,
      contentSubmissionRepository:
          contentSubmissionRepository ?? FakeContentSubmissionRepository(),
      draftRepository:
          draftRepository ?? FakeContentSubmissionDraftRepository(),
      stagedAssetRepository:
          stagedAssetRepository ?? FakeContentSubmissionStagedAssetRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    );
  }

  group('ContentSubmissionViewModel', () {
    group('OpenSpec 5 gates', () {
      test('A3 captured issue preserves a later valid temporal edit', () async {
        final repository = FakeContentSubmissionRepository(
          submitResult: Result.error(Exception('remote rejected')),
        );
        final vm = buildViewModel(contentSubmissionRepository: repository);
        addTearDown(vm.dispose);
        await vm.initialize();
        vm
          ..setCity('Rome')
          ..setName('Draft')
          ..setUserEmail('anna@example.test')
          ..setUserName('Anna')
          ..setEventEnabled(enabled: true);
        expect(vm.validateEventTimeForSubmission(), isFalse);
        final capturedIssue = vm.eventTimeIssue;
        expect(capturedIssue, isNotNull);
        expect(vm.requestSubmit(), isTrue);
        vm.setEventEnabled(enabled: false);
        expect(vm.eventTimeIssue, isNull);
        await settleContentSubmissionTurns();
        while (vm.isSubmitting) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(vm.submitSnapshot.domainError, isNotNull);
        expect(repository.submitCallCount, 0);
        expect(vm.isEvent, isFalse);
        expect(
          vm.eventTimeIssue,
          isNull,
          reason: 'captured failure must not republish an obsolete issue',
        );
        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
        expect(repository.submitCallCount, 1);
        expect(repository.submittedContentSubmissions.single.allDay, isFalse);
      });

      test(
        'S10 runtime finalization permits local retry without a second send',
        () async {
          final f = await ContentSubmissionCommandFixture.ready(
            remoteResult: const Result.success(null),
          );
          addTearDown(f.vm.dispose);
          final pending = Completer<Result<void>>();
          f.drafts.pendingClearDraft = pending;
          final submit = requestAndWait(
            f.vm.requestSubmit,
            () => f.vm.isSubmitting,
          );
          while (f.drafts.clearDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(f.vm.submissionFinalizationPending, isTrue);
          expect(f.vm.submitSnapshot.completed, isFalse);
          expect(f.vm.canRetrySubmissionImmediately, isFalse);
          final original = Exception('unexpected local retirement');
          final stack = StackTrace.fromString(
            '#0 localRetirement (file:///local_retirement.dart:8:2)',
          );
          pending.completeError(original, stack);
          await submit;
          expect(f.vm.submitSnapshot.unexpectedError, same(original));
          expect(f.vm.submitSnapshot.domainError, isNull);
          expect(f.vm.submissionFinalizationPending, isTrue);
          expect(f.vm.canRetrySubmissionImmediately, isTrue);
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(f.vm.assets, hasLength(2));
          expect(f.repository.uploadedImages, hasLength(2));
          expect(f.repository.submitCallCount, 1);
          expect(f.drafts.saveDraftCallCount, 0);
          expect(f.staged.clearedSessions, isEmpty);
          expect(
            commandLogger.eventsOfType<CommandExecutionFailed>(),
            hasLength(1),
          );
          expect(
            commandLogger.firstCallOfType<CommandExecutionFailed>()!.error,
            same(original),
          );
          expect(
            commandLogger
                .firstCallOfType<CommandExecutionFailed>()!
                .stackTrace
                .toString(),
            contains('local_retirement.dart'),
          );
          final retryPending = Completer<Result<void>>();
          f.drafts.pendingClearDraft = retryPending;
          expect(f.vm.requestSubmit(), isTrue);
          expect(f.vm.requestSubmit(), isFalse);
          expect(f.vm.canRetrySubmissionImmediately, isFalse);
          while (f.drafts.clearDraftCallCount < 2) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(f.repository.uploadedImages, hasLength(2));
          expect(f.repository.submitCallCount, 1);
          expect(f.drafts.saveDraftCallCount, 0);
          retryPending.complete(const Result.success(null));
          while (f.vm.isSubmitting) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(f.vm.submitSnapshot.completed, isTrue);
          expect(f.vm.submissionFinalizationPending, isFalse);
          expect(f.vm.canRetrySubmissionImmediately, isFalse);
          expect(
            f.vm.state.clientSubmissionId,
            isNot(ContentSubmissionCommandFixture.identity),
          );
          expect(f.vm.assets, isEmpty);
          expect(f.vm.hasUnsavedChanges, isFalse);
          expect(f.drafts.clearDraftCallCount, 2);
          expect(f.staged.clearedSessions, [
            ContentSubmissionCommandFixture.identity,
          ]);
          expect(f.repository.uploadedImages, hasLength(2));
          expect(f.repository.submitCallCount, 1);
          expect(f.repository.submittedContentSubmissions.single.name, 'D0');
          expect(f.repository.submittedClientSubmissionIds, [
            ContentSubmissionCommandFixture.identity,
          ]);
        },
      );

      for (final kind in [
        'domain',
        'exception',
        'state',
        'object',
        'assertion',
      ]) {
        testWidgets('E3 $kind primary survives release and stops uploads', (
          tester,
        ) async {
          final f = await ContentSubmissionCommandFixture.ready();
          final original = switch (kind) {
            'domain' || 'exception' => Exception('primary upload failure'),
            'state' => StateError('primary upload failure'),
            'assertion' => AssertionError('primary upload failure'),
            _ => Object(),
          };
          final stack = StackTrace.fromString(
            '#0 originalUpload (file:///original_upload.dart:12:3)',
          );
          final uncaught = <Object>[];
          final stacks = <StackTrace>[];
          runZonedGuarded(
            () {
              f.repository.uploadImageTaskResult = kind == 'domain'
                  ? FakeImageUploadTask.completed(
                      Result.error(original as Exception),
                    )
                  : FakeImageUploadTask.throwing(original, stackTrace: stack);
              expect(f.vm.requestSubmit(), isTrue);
            },
            (error, stack) {
              uncaught.add(error);
              stacks.add(stack);
            },
          );
          await pumpCommandTurns(tester);
          expect(f.vm.isSubmitting, isFalse);
          expect(f.vm.submissionFinalizationPending, isFalse);
          expect(f.vm.canRetrySubmissionImmediately, isFalse);
          expect(f.repository.uploadedImages, hasLength(1));
          expect(
            f.repository.uploadedImages.single.path,
            '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.firstDigest}',
          );
          expect(f.repository.submitCallCount, 0);
          expect(f.drafts.saveDraftCallCount, 0);
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(f.vm.assets, hasLength(2));
          if (kind == 'assertion') {
            expect(uncaught, [same(original)]);
            expect(stacks.single.toString(), contains('original_upload.dart'));
            expect(f.vm.submitSnapshot.domainError, isNull);
            expect(f.vm.submitSnapshot.unexpectedError, isNull);
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              isEmpty,
            );
          } else if (kind == 'domain') {
            expect(uncaught, isEmpty);
            expect(f.vm.submitSnapshot.domainError, same(original));
            expect(f.vm.submitSnapshot.unexpectedError, isNull);
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              isEmpty,
            );
          } else {
            expect(uncaught, isEmpty);
            expect(f.vm.submitSnapshot.unexpectedError, same(original));
            expect(f.vm.submitSnapshot.domainError, isNull);
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              hasLength(1),
            );
            expect(
              commandLogger.firstCallOfType<CommandExecutionFailed>()!.error,
              same(original),
            );
            expect(
              commandLogger
                  .firstCallOfType<CommandExecutionFailed>()!
                  .stackTrace
                  .toString(),
              contains('original_upload.dart'),
            );
          }
          expect(f.vm.requestClear(), isTrue);
          await pumpCommandTurns(tester);
          expect(f.vm.clearSnapshot.completed, isTrue);
          expect(f.drafts.clearDraftCallCount, 1);
          expect(f.staged.clearedSessions, [
            ContentSubmissionCommandFixture.identity,
          ]);
          f.vm.dispose();
          await pumpPhysicalCommandDisposal(tester);
          expect(tester.takeException(), isNull);
        });
      }

      for (final recovery in [false, true]) {
        test(
          'L3 ${recovery ? 'recovery' : 'add'} raw repo file throw is runtime',
          () async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
            final featureLogger = MockLogger();
            final pending = Completer<Result<ContentSubmissionStagedAsset>>();
            final staged = FakeContentSubmissionStagedAssetRepository()
              ..pendingAcquire = pending;
            const identity = ContentSubmissionCommandFixture.identity;
            final drafts = FakeContentSubmissionDraftRepository(
              loadDraftResult: Result.success(
                ContentSubmissionDraft(clientSubmissionId: identity),
              ),
            );
            final candidate = XFile.fromData(
              Uint8List.fromList([3]),
              name: 'X.jpg',
            );
            final vm = buildViewModel(
              logger: featureLogger,
              draftRepository: drafts,
              stagedAssetRepository: staged,
              imagePicker: FakeImagePicker(
                onPickMultipleMedia: () async => [candidate],
                onRetrieveLostData: () async =>
                    LostDataResponse(file: candidate, type: RetrieveType.image),
              ),
            );
            addTearDown(vm.dispose);
            await vm.initialize();
            const original = FileSystemException('unexpected repository throw');
            final request = requestAndWait(
              recovery ? vm.requestRetrieveLostAssets : vm.requestAddAsset,
              () => recovery ? vm.isRetrievingLostAssets : vm.isAddingAsset,
            );
            while (staged.acquired.isEmpty) {
              await Future<void>.delayed(Duration.zero);
            }
            pending.completeError(original, StackTrace.current);
            await request;
            final snapshot = recovery
                ? vm.retrieveLostAssetsSnapshot
                : vm.addAssetSnapshot;
            expect(snapshot.unexpectedError, same(original));
            expect(snapshot.domainError, isNull);
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              hasLength(1),
            );
            expect(
              commandLogger.firstCallOfType<CommandExecutionFailed>()!.error,
              same(original),
            );
            expect(
              featureLogger.eventsOfType<ContentSubmissionAssetAddFailed>(),
              isEmpty,
            );
            expect(
              featureLogger
                  .eventsOfType<ContentSubmissionAssetRetrievalFailed>(),
              isEmpty,
            );
            expect(vm.assets, isEmpty);
            await requestAndWait(vm.requestClear, () => vm.isClearing);
            expect(vm.clearSnapshot.completed, isTrue);
          },
        );

        test(
          'L3 ${recovery ? 'recovery' : 'add'} direct file error is expected',
          () async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
            final featureLogger = MockLogger();
            final staged = FakeContentSubmissionStagedAssetRepository();
            const identity = ContentSubmissionCommandFixture.identity;
            final drafts = FakeContentSubmissionDraftRepository(
              loadDraftResult: Result.success(
                ContentSubmissionDraft(clientSubmissionId: identity),
              ),
            );
            final directory = await Directory.systemTemp.createTemp(
              'moliseis_missing_candidate_',
            );
            addTearDown(() => directory.delete(recursive: true));
            final candidate = XFile('${directory.path}/missing.jpg');
            final vm = buildViewModel(
              logger: featureLogger,
              draftRepository: drafts,
              stagedAssetRepository: staged,
              imagePicker: FakeImagePicker(
                onPickMultipleMedia: () async => [candidate],
                onRetrieveLostData: () async =>
                    LostDataResponse(file: candidate, type: RetrieveType.image),
              ),
            );
            addTearDown(vm.dispose);
            await vm.initialize();
            await requestAndWait(
              recovery ? vm.requestRetrieveLostAssets : vm.requestAddAsset,
              () => recovery ? vm.isRetrievingLostAssets : vm.isAddingAsset,
            );
            final snapshot = recovery
                ? vm.retrieveLostAssetsSnapshot
                : vm.addAssetSnapshot;
            expect(snapshot.unexpectedError, isNull);
            if (recovery) {
              expect(snapshot.completed, isTrue);
              expect(
                featureLogger
                    .eventsOfType<ContentSubmissionAssetRetrievalFailed>(),
                hasLength(1),
              );
            } else {
              expect(snapshot.domainError, isA<FileSystemException>());
              expect(
                featureLogger.eventsOfType<ContentSubmissionAssetAddFailed>(),
                hasLength(1),
              );
              expect(
                featureLogger
                    .firstCallOfType<ContentSubmissionAssetAddFailed>()!
                    .error,
                same(snapshot.domainError),
              );
            }
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              isEmpty,
            );
            expect(staged.acquired, isEmpty);
            expect(vm.assets, isEmpty);
          },
        );
      }

      test(
        'L3 picker PlatformException remains domain with feature logging',
        () async {
          final featureLogger = MockLogger();
          final original = PlatformException(code: 'selection-unavailable');
          final vm = buildViewModel(
            logger: featureLogger,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => throw original,
            ),
          );
          addTearDown(vm.dispose);
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          expect(vm.addAssetSnapshot.domainError, same(original));
          expect(vm.addAssetSnapshot.unexpectedError, isNull);
          expect(
            featureLogger.eventsOfType<ContentSubmissionAssetAddFailed>(),
            hasLength(1),
          );
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
        },
      );

      test(
        'L3 unexpected recovery plugin exception does not pretend success',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final original = Exception('unexpected plugin throw');
          final featureLogger = MockLogger();
          final drafts = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(
            logger: featureLogger,
            draftRepository: drafts,
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async => throw original,
            ),
          );
          addTearDown(vm.dispose);
          await requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );
          expect(vm.retrieveLostAssetsSnapshot.unexpectedError, same(original));
          expect(vm.retrieveLostAssetsSnapshot.domainError, isNull);
          expect(vm.retrieveLostAssetsSnapshot.completed, isFalse);
          expect(drafts.loadDraftCallCount, 0);
          expect(
            featureLogger.eventsOfType<ContentSubmissionAssetRetrievalFailed>(),
            isEmpty,
          );
          expect(
            commandLogger.eventsOfType<CommandExecutionFailed>(),
            hasLength(1),
          );
        },
      );

      testWidgets(
        'E4 bootstrap assertion settles its ticket and remains fail loud',
        (tester) async {
          late Completer<Result<ContentSubmissionDraft?>> pending;
          late FakeContentSubmissionDraftRepository drafts;
          final staged = FakeContentSubmissionStagedAssetRepository();
          final repository = FakeContentSubmissionRepository();
          final uncaught = <Object>[];
          final stacks = <StackTrace>[];
          late ContentSubmissionViewModel vm;
          runZonedGuarded(
            () {
              pending = Completer<Result<ContentSubmissionDraft?>>();
              drafts = FakeContentSubmissionDraftRepository()
                ..pendingLoadDraft = pending;
              vm = buildViewModel(
                draftRepository: drafts,
                stagedAssetRepository: staged,
                contentSubmissionRepository: repository,
              );
              expect(vm.requestSubmit(), isTrue);
            },
            (error, stack) {
              uncaught.add(error);
              stacks.add(stack);
            },
          );
          await pumpCommandTurns(tester);
          expect(drafts.loadDraftCallCount, 1);
          final original = AssertionError('bootstrap assertion');
          final stack = StackTrace.fromString(
            '#0 bootstrapLoad (file:///bootstrap_load.dart:7:3)',
          );
          pending.completeError(original, stack);
          await pumpCommandTurns(tester);
          expect(uncaught, [same(original)]);
          expect(stacks.single.toString(), contains('bootstrap_load.dart'));
          expect(vm.isSubmitting, isFalse);
          expect(vm.submitSnapshot.domainError, isNull);
          expect(vm.submitSnapshot.unexpectedError, isNull);
          expect(staged.reconcileCallCount, 0);
          expect(staged.acquired, isEmpty);
          expect(drafts.saveDraftCallCount, 0);
          expect(repository.uploadedImages, isEmpty);
          expect(repository.submitCallCount, 0);
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
          vm.dispose();
          await pumpPhysicalCommandDisposal(tester);
          expect(tester.takeException(), isNull);
        },
      );

      test(
        'S14 add admitted after submit cannot enter captured membership',
        () async {
          final f = await ContentSubmissionCommandFixture.ready();
          addTearDown(f.vm.dispose);
          expect(f.vm.requestSubmit(), isTrue);
          expect(f.vm.requestAddAsset(), isTrue);
          while (f.vm.isSubmitting || f.vm.isAddingAsset) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(f.repository.uploadedImages.map((file) => file.path), [
            '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.firstDigest}',
            '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.secondDigest}',
          ]);
          expect(f.repository.uploadedImages, hasLength(2));
          expect(f.repository.submitCallCount, 1);
          expect(f.repository.submittedContentSubmissions.single.name, 'D0');
          expect(f.repository.submittedClientSubmissionIds, [
            ContentSubmissionCommandFixture.identity,
          ]);
          expect(f.vm.assets, hasLength(3));
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(f.vm.addAssetSnapshot.completed, isTrue);
          expect(f.vm.submitSnapshot.domainError, same(f.remoteFailure));
          expect(f.drafts.saveDraftCallCount, 0);
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
        },
      );

      test('S13 dirty D0 checkpoints once before ordered uploads', () async {
        final f = await ContentSubmissionCommandFixture.ready();
        addTearDown(f.vm.dispose);
        final staging = Completer<Result<ContentSubmissionStagedAsset>>();
        f.staged.pendingAcquire = staging;
        final add = requestAndWait(
          f.vm.requestAddAsset,
          () => f.vm.isAddingAsset,
        );
        while (f.staged.acquired.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        f.vm.setName('dirty D0');
        final pending = Completer<Result<void>>();
        f.drafts.pendingSaveDraft = pending;
        final submit = requestAndWait(
          f.vm.requestSubmit,
          () => f.vm.isSubmitting,
        );
        f.vm.setName('D1');
        final acquired = f.staged.acquired.single;
        staging.complete(
          Result.success(
            ContentSubmissionStagedAsset(
              clientSubmissionId: acquired.clientSubmissionId,
              digest: acquired.digest,
              relativePath: '${acquired.clientSubmissionId}/${acquired.digest}',
            ),
          ),
        );
        while (f.drafts.saveDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(f.drafts.lastSavedState!.name, 'dirty D0');
        expect(f.repository.uploadedImages, isEmpty);
        pending.complete(const Result.success(null));
        await Future.wait([add, submit]);
        expect(f.drafts.saveDraftCallCount, 1);
        expect(f.repository.uploadedImages.map((file) => file.path), [
          '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.firstDigest}',
          '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.secondDigest}',
          '/staged/${acquired.clientSubmissionId}/${acquired.digest}',
        ]);
        expect(f.repository.submitCallCount, 1);
        expect(
          f.repository.submittedContentSubmissions.single.name,
          'dirty D0',
        );
        expect(f.repository.submittedClientSubmissionIds, [
          ContentSubmissionCommandFixture.identity,
        ]);
        expect(f.vm.state.name, 'D1');
        expect(f.vm.hasUnsavedChanges, isTrue);
        expect(f.vm.submitSnapshot.domainError, same(f.remoteFailure));
      });

      test(
        'S15 failed anterior acquire preserves available P Q for submit',
        () async {
          final f = await ContentSubmissionCommandFixture.ready();
          addTearDown(f.vm.dispose);
          final pending = Completer<Result<ContentSubmissionStagedAsset>>();
          f.staged.pendingAcquire = pending;
          final add = requestAndWait(
            f.vm.requestAddAsset,
            () => f.vm.isAddingAsset,
          );
          while (f.staged.acquired.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          final submit = requestAndWait(
            f.vm.requestSubmit,
            () => f.vm.isSubmitting,
          );
          f.vm.setName('D1');
          final acquireFailure = Exception('acquire X rejected');
          pending.complete(Result.error(acquireFailure));
          await Future.wait([add, submit]);
          expect(f.vm.addAssetSnapshot.domainError, same(acquireFailure));
          expect(f.vm.submitSnapshot.domainError, same(f.remoteFailure));
          expect(f.vm.assets.map((a) => a.digest), [
            ContentSubmissionCommandFixture.firstDigest,
            ContentSubmissionCommandFixture.secondDigest,
          ]);
          expect(
            f.repository.uploadedImages.map((file) => file.path),
            f.vm.assets.map((a) => a.file.path),
          );
          expect(f.repository.uploadedImages, hasLength(2));
          expect(f.repository.submitCallCount, 1);
          expect(f.repository.submittedContentSubmissions.single.name, 'D0');
          expect(f.repository.submittedClientSubmissionIds, [
            ContentSubmissionCommandFixture.identity,
          ]);
          expect(f.vm.state.name, 'D1');
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(f.drafts.saveDraftCallCount, 0);
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
        },
      );

      test(
        'S16 acquired but unresolved predecessor makes submit unavailable',
        () async {
          final f = await ContentSubmissionCommandFixture.ready();
          addTearDown(f.vm.dispose);
          final pending = Completer<Result<File>>();
          f.staged.pendingResolve = pending;
          final resolveBefore = f.staged.resolveCallCount;
          final add = requestAndWait(
            f.vm.requestAddAsset,
            () => f.vm.isAddingAsset,
          );
          while (f.staged.resolveCallCount == resolveBefore) {
            await Future<void>.delayed(Duration.zero);
          }
          final submit = requestAndWait(
            f.vm.requestSubmit,
            () => f.vm.isSubmitting,
          );
          final failure = Exception('resolve X failed');
          pending.complete(Result.error(failure));
          await Future.wait([add, submit]);
          expect(f.vm.addAssetSnapshot.domainError, same(failure));
          expect(f.vm.submitSnapshot.domainError, isNotNull);
          expect(f.vm.assets, isEmpty);
          expect(f.repository.uploadedImages, isEmpty);
          expect(f.repository.submitCallCount, 0);
          expect(f.drafts.saveDraftCallCount, 0);
          expect(f.drafts.clearDraftCallCount, 0);
          expect(f.staged.clearedSessions, isEmpty);
          expect(f.vm.state.name, 'D0');
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
        },
      );

      test('S17 clear rotates before prepare without adopting J', () async {
        final f = await ContentSubmissionCommandFixture.ready();
        addTearDown(f.vm.dispose);
        final pending = Completer<Result<ContentSubmissionStagedAsset>>();
        f.staged.pendingAcquire = pending;
        final add = requestAndWait(
          f.vm.requestAddAsset,
          () => f.vm.isAddingAsset,
        );
        while (f.staged.acquired.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final submit = requestAndWait(
          f.vm.requestSubmit,
          () => f.vm.isSubmitting,
        );
        final clear = requestAndWait(f.vm.requestClear, () => f.vm.isClearing);
        for (var turn = 0; turn < 4; turn++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(f.drafts.clearDraftCallCount, 0);
        final acquired = f.staged.acquired.single;
        pending.complete(
          Result.success(
            ContentSubmissionStagedAsset(
              clientSubmissionId: acquired.clientSubmissionId,
              digest: acquired.digest,
              relativePath: '${acquired.clientSubmissionId}/${acquired.digest}',
            ),
          ),
        );
        await Future.wait([add, submit, clear]);
        expect(f.vm.addAssetSnapshot.completed, isTrue);
        expect(f.vm.clearSnapshot.completed, isTrue);
        expect(f.vm.submitSnapshot.domainError, isNotNull);
        expect(f.repository.uploadedImages, isEmpty);
        expect(f.repository.submitCallCount, 0);
        expect(f.drafts.saveDraftCallCount, 0);
        expect(f.drafts.clearDraftCallCount, 1);
        expect(f.staged.clearedSessions, [
          ContentSubmissionCommandFixture.identity,
        ]);
        expect(
          f.vm.state.clientSubmissionId,
          isNot(ContentSubmissionCommandFixture.identity),
        );
        expect(f.vm.state.name, isNull);
        expect(f.vm.assets, isEmpty);
      });

      testWidgets(
        'S18 disposal drains capture without resolve or subsequent I O',
        (tester) async {
          final f = await ContentSubmissionCommandFixture.ready();
          final pending = Completer<Result<ContentSubmissionStagedAsset>>();
          f.staged.pendingAcquire = pending;
          final resolveBefore = f.staged.resolveCallCount;
          expect(f.vm.requestAddAsset(), isTrue);
          await pumpCommandTurns(tester);
          expect(f.staged.acquired, hasLength(1));
          expect(f.vm.requestSubmit(), isTrue);
          var notifications = 0;
          f.vm.addListener(() => notifications++);
          f.vm.dispose();
          final frozen = f.vm.submitSnapshot;
          final atDisposal = notifications;
          await tester.pump(const Duration(milliseconds: 51));
          final acquired = f.staged.acquired.single;
          pending.complete(
            Result.success(
              ContentSubmissionStagedAsset(
                clientSubmissionId: acquired.clientSubmissionId,
                digest: acquired.digest,
                relativePath:
                    '${acquired.clientSubmissionId}/${acquired.digest}',
              ),
            ),
          );
          await pumpPhysicalCommandDisposal(tester);
          expect(f.staged.resolveCallCount, resolveBefore);
          expect(f.drafts.saveDraftCallCount, 0);
          expect(f.drafts.clearDraftCallCount, 0);
          expect(f.staged.clearedSessions, isEmpty);
          expect(f.repository.uploadedImages, isEmpty);
          expect(f.repository.submitCallCount, 0);
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(f.vm.assets, hasLength(2));
          expect(f.vm.submitSnapshot, same(frozen));
          expect(notifications, atDisposal);
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
        },
      );

      test('S19 prior removal is reflected by sealed membership', () async {
        final f = await ContentSubmissionCommandFixture.ready();
        addTearDown(f.vm.dispose);
        final pending = Completer<Result<void>>();
        f.staged.pendingRemove = pending;
        final remove = requestAndWait(
          () => f.vm.requestRemoveAssetAt(0),
          () => f.vm.isRemovingAsset,
        );
        while (f.staged.removed.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final submit = requestAndWait(
          f.vm.requestSubmit,
          () => f.vm.isSubmitting,
        );
        f.vm.setName('D1');
        pending.complete(const Result.success(null));
        await Future.wait([remove, submit]);
        expect(f.vm.removeAssetAtSnapshot.completed, isTrue);
        expect(f.vm.submitSnapshot.domainError, same(f.remoteFailure));
        expect(f.repository.uploadedImages.map((file) => file.path), [
          '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.secondDigest}',
        ]);
        expect(f.repository.submitCallCount, 1);
        expect(f.repository.submittedContentSubmissions.single.name, 'D0');
        expect(f.repository.submittedClientSubmissionIds, [
          ContentSubmissionCommandFixture.identity,
        ]);
        expect(
          f.vm.assets.single.digest,
          ContentSubmissionCommandFixture.secondDigest,
        );
        expect(f.vm.state.name, 'D1');
        expect(f.drafts.saveDraftCallCount, 0);
      });

      for (final restored in [false, true]) {
        test(
          'S20 ${restored ? 'restored' : 'absent'} ticket excludes later Y',
          () async {
            const identity = ContentSubmissionCommandFixture.identity;
            final pending = Completer<Result<ContentSubmissionDraft?>>();
            final drafts = FakeContentSubmissionDraftRepository()
              ..pendingLoadDraft = pending;
            final staged = FakeContentSubmissionStagedAssetRepository(
              reconcileResult: Result.success(
                restored
                    ? [
                        for (final digest in [
                          ContentSubmissionCommandFixture.firstDigest,
                          ContentSubmissionCommandFixture.secondDigest,
                        ])
                          ContentSubmissionStagedAsset(
                            clientSubmissionId: identity,
                            digest: digest,
                            relativePath: '$identity/$digest',
                          ),
                      ]
                    : [],
              ),
            );
            final remoteFailure = Exception('remote rejected');
            final repository = FakeContentSubmissionRepository(
              submitResult: Result.error(remoteFailure),
            );
            final vm = buildViewModel(
              draftRepository: drafts,
              stagedAssetRepository: staged,
              contentSubmissionRepository: repository,
              imagePicker: FakeImagePicker(
                onPickMultipleMedia: () async => [
                  XFile.fromData(Uint8List.fromList([3]), name: 'Y.jpg'),
                ],
              ),
            );
            addTearDown(vm.dispose);
            vm
              ..setCity('Rome')
              ..setName('Provisional D0')
              ..setUserEmail('anna@example.test')
              ..setUserName('Anna');
            final provisional = vm.state.clientSubmissionId;
            final submit = requestAndWait(
              vm.requestSubmit,
              () => vm.isSubmitting,
            );
            while (drafts.loadDraftCallCount == 0) {
              await Future<void>.delayed(Duration.zero);
            }
            pending.complete(
              Result.success(
                restored
                    ? ContentSubmissionDraft(
                        clientSubmissionId: identity,
                        city: 'Rome',
                        name: 'Restored DR',
                        userEmail: 'anna@example.test',
                        userName: 'Anna',
                      )
                    : null,
              ),
            );
            // Initialize seals its ticket before the later add is admitted.
            await vm.initialize();
            final add = requestAndWait(
              vm.requestAddAsset,
              () => vm.isAddingAsset,
            );
            await Future.wait([submit, add]);
            expect(repository.uploadedImages, hasLength(restored ? 2 : 0));
            if (restored) {
              expect(repository.uploadedImages.map((file) => file.path), [
                '/staged/$identity/${ContentSubmissionCommandFixture.firstDigest}',
                '/staged/$identity/${ContentSubmissionCommandFixture.secondDigest}',
              ]);
            }
            expect(repository.submitCallCount, 1);
            expect(
              repository.submittedContentSubmissions.single.name,
              restored ? 'Restored DR' : 'Provisional D0',
            );
            expect(repository.submittedClientSubmissionIds, [
              if (restored) identity else provisional,
            ]);
            expect(
              vm.state.clientSubmissionId,
              restored ? identity : provisional,
            );
            expect(vm.submitSnapshot.domainError, same(remoteFailure));
            expect(vm.addAssetSnapshot.completed, isTrue);
            expect(vm.assets, hasLength(restored ? 3 : 1));
            expect(drafts.loadDraftCallCount, 1);
            expect(staged.reconcileCallCount, 1);
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              isEmpty,
            );
          },
        );
      }

      testWidgets(
        'S20 loading disposal before deferred entry reserves no bootstrap wait',
        (tester) async {
          final drafts = FakeContentSubmissionDraftRepository();
          final staged = FakeContentSubmissionStagedAssetRepository();
          final repository = FakeContentSubmissionRepository();
          final vm = buildViewModel(
            draftRepository: drafts,
            stagedAssetRepository: staged,
            contentSubmissionRepository: repository,
          );
          expect(vm.requestSubmit(), isTrue);
          vm.dispose();
          final frozen = vm.submitSnapshot;
          await pumpPhysicalCommandDisposal(tester);
          expect(drafts.loadDraftCallCount, 0);
          expect(staged.reconcileCallCount, 0);
          expect(drafts.saveDraftCallCount, 0);
          expect(repository.uploadedImages, isEmpty);
          expect(repository.submitCallCount, 0);
          expect(vm.submitSnapshot, same(frozen));
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );

      test(
        'S21 earlier batch keeps committed X when following Z acquire fails',
        () async {
          final f = await ContentSubmissionCommandFixture.ready(
            candidates: [
              XFile.fromData(Uint8List.fromList([3]), name: 'X.jpg'),
              XFile.fromData(Uint8List.fromList([4]), name: 'Z.jpg'),
            ],
          );
          addTearDown(f.vm.dispose);
          final pendingX = Completer<Result<ContentSubmissionStagedAsset>>();
          final pendingZ = Completer<Result<ContentSubmissionStagedAsset>>();
          f.staged.pendingAcquire = pendingX;
          final add = requestAndWait(
            f.vm.requestAddAsset,
            () => f.vm.isAddingAsset,
          );
          while (f.staged.acquired.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          final submit = requestAndWait(
            f.vm.requestSubmit,
            () => f.vm.isSubmitting,
          );
          final x = f.staged.acquired.single;
          f.staged.pendingAcquire = pendingZ;
          pendingX.complete(
            Result.success(
              ContentSubmissionStagedAsset(
                clientSubmissionId: x.clientSubmissionId,
                digest: x.digest,
                relativePath: '${x.clientSubmissionId}/${x.digest}',
              ),
            ),
          );
          while (f.staged.acquired.length < 2) {
            await Future<void>.delayed(Duration.zero);
          }
          final failure = Exception('Z acquire failed');
          pendingZ.complete(Result.error(failure));
          await Future.wait([add, submit]);
          expect(f.vm.addAssetSnapshot.domainError, same(failure));
          expect(f.vm.submitSnapshot.domainError, same(f.remoteFailure));
          expect(f.repository.uploadedImages.map((file) => file.path), [
            '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.firstDigest}',
            '/staged/${ContentSubmissionCommandFixture.identity}/${ContentSubmissionCommandFixture.secondDigest}',
            '/staged/${x.clientSubmissionId}/${x.digest}',
          ]);
          expect(f.repository.uploadedImages, hasLength(3));
          expect(f.repository.submitCallCount, 1);
          expect(f.repository.submittedClientSubmissionIds, [
            ContentSubmissionCommandFixture.identity,
          ]);
          expect(f.repository.submittedContentSubmissions.single.name, 'D0');
          expect(
            f.vm.state.clientSubmissionId,
            ContentSubmissionCommandFixture.identity,
          );
          expect(f.vm.assets, hasLength(3));
          expect(f.drafts.saveDraftCallCount, 0);
          expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
        },
      );

      for (final lane in ['add', 'remove', 'submit', 'clear', 'recovery']) {
        test(
          'A1 rejects duplicate $lane admission without replacing snapshot',
          () async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
            var recoveries = 0;
            final picker = FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1]), name: 'asset.jpg'),
              ],
              onRetrieveLostData: () async {
                recoveries++;
                return LostDataResponse.empty();
              },
            );
            final drafts = FakeContentSubmissionDraftRepository();
            final staged = FakeContentSubmissionStagedAssetRepository();
            final repository = FakeContentSubmissionRepository(
              submitResult: Result.error(Exception('remote rejected')),
            );
            final vm = buildViewModel(
              imagePicker: picker,
              draftRepository: drafts,
              stagedAssetRepository: staged,
              contentSubmissionRepository: repository,
            );
            addTearDown(vm.dispose);
            await vm.initialize();
            vm
              ..setCity('Rome')
              ..setName('A')
              ..setUserEmail('anna@example.test')
              ..setUserName('Anna');
            if (lane == 'remove') {
              await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
            }
            final request = switch (lane) {
              'add' => vm.requestAddAsset,
              'remove' => () => vm.requestRemoveAssetAt(0),
              'submit' => vm.requestSubmit,
              'clear' => vm.requestClear,
              _ => vm.requestRetrieveLostAssets,
            };
            final running = switch (lane) {
              'add' => () => vm.isAddingAsset,
              'remove' => () => vm.isRemovingAsset,
              'submit' => () => vm.isSubmitting,
              'clear' => () => vm.isClearing,
              _ => () => vm.isRetrievingLostAssets,
            };
            final snapshot = switch (lane) {
              'add' => () => vm.addAssetSnapshot,
              'remove' => () => vm.removeAssetAtSnapshot,
              'submit' => () => vm.submitSnapshot,
              'clear' => () => vm.clearSnapshot,
              _ => () => vm.retrieveLostAssetsSnapshot,
            };
            expect(request(), isTrue);
            expect(running(), isTrue);
            final admittedSnapshot = snapshot();
            expect(request(), isFalse);
            expect(snapshot(), same(admittedSnapshot));
            while (running()) {
              await Future<void>.delayed(Duration.zero);
            }
            switch (lane) {
              case 'add':
                expect(picker.pickMultipleMediaLimits, hasLength(1));
              case 'remove':
                expect(staged.removed, hasLength(1));
              case 'submit':
                expect(repository.submitCallCount, 1);
              case 'clear':
                expect(drafts.clearDraftCallCount, 1);
              case 'recovery':
                expect(recoveries, 1);
            }
          },
        );
      }

      testWidgets('A2 disposal in admission observer prevents deferred I/O', (
        tester,
      ) async {
        final drafts = FakeContentSubmissionDraftRepository();
        final picker = FakeImagePicker();
        final repository = FakeContentSubmissionRepository();
        final vm = buildViewModel(
          draftRepository: drafts,
          imagePicker: picker,
          contentSubmissionRepository: repository,
        );
        vm.addListener(() {
          if (vm.isSubmitting) vm.dispose();
        });
        expect(vm.requestSubmit(), isTrue);
        final frozen = vm.submitSnapshot;
        await pumpCommandTurns(tester);
        await pumpPhysicalCommandDisposal(tester);
        expect(drafts.loadDraftCallCount, 0);
        expect(drafts.saveDraftCallCount, 0);
        expect(repository.submitCallCount, 0);
        expect(picker.pickMultipleMediaLimits, isEmpty);
        expect(vm.submitSnapshot, same(frozen));
        expect(vm.requestSubmit(), isFalse);
      });

      test(
        'A4 loading ticket never adopts the session rotated before prepare',
        () async {
          const restored = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final pending = Completer<Result<ContentSubmissionDraft?>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingLoadDraft = pending;
          final repository = FakeContentSubmissionRepository();
          final vm = buildViewModel(
            draftRepository: drafts,
            contentSubmissionRepository: repository,
          );
          addTearDown(vm.dispose);
          final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
          final submit = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (drafts.loadDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          pending.complete(
            Result.success(
              ContentSubmissionDraft(
                clientSubmissionId: restored,
                city: 'Rome',
                name: 'Restored',
                userEmail: 'anna@example.test',
                userName: 'Anna',
              ),
            ),
          );
          await Future.wait([clear, submit]);
          expect(vm.clearSnapshot.completed, isTrue);
          expect(vm.state.clientSubmissionId, isNot(restored));
          expect(vm.submitSnapshot.domainError, isNotNull);
          expect(repository.uploadedImages, isEmpty);
          expect(repository.submitCallCount, 0);
        },
      );

      test(
        'A5 absent initialization preserves each admitted provisional draft',
        () async {
          final pending = Completer<Result<ContentSubmissionDraft?>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingLoadDraft = pending;
          final repository = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('remote rejected')),
          );
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            draftRepository: drafts,
            stagedAssetRepository: staged,
            contentSubmissionRepository: repository,
          );
          addTearDown(vm.dispose);
          vm
            ..setCity('Rome')
            ..setName('A')
            ..setUserEmail('anna@example.test')
            ..setUserName('Anna');
          final identity = vm.state.clientSubmissionId;
          final submit = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (drafts.loadDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          vm.setName('B');
          pending.complete(const Result.success(null));
          await submit;
          expect(repository.submittedContentSubmissions.single.name, 'A');
          expect(repository.submittedClientSubmissionIds, [identity]);
          expect(vm.state.name, 'B');
          expect(vm.hasUnsavedChanges, isTrue);
          expect(drafts.loadDraftCallCount, 1);
          expect(staged.reconcileCallCount, 1);
        },
      );

      test(
        'A6 restored ticket freezes loaded draft during staged reconciliation',
        () async {
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final pending =
              Completer<Result<List<ContentSubmissionStagedAsset>>>();
          final staged = FakeContentSubmissionStagedAssetRepository()
            ..pendingReconcile = pending;
          final restored = ContentSubmissionDraft(
            clientSubmissionId: identity,
            city: 'Rome',
            name: 'Restored',
            userEmail: 'anna@example.test',
            userName: 'Anna',
          );
          final drafts = FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(restored),
          );
          final repository = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('remote rejected')),
          );
          final vm = buildViewModel(
            draftRepository: drafts,
            stagedAssetRepository: staged,
            contentSubmissionRepository: repository,
          );
          addTearDown(vm.dispose);
          final submit = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (staged.reconcileCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          vm.setName('Edited during reconciliation');
          pending.complete(const Result.success([]));
          await submit;
          expect(
            repository.submittedContentSubmissions.single.name,
            'Restored',
          );
          expect(repository.submittedClientSubmissionIds, [identity]);
          expect(vm.state.name, 'Edited during reconciliation');
          expect(vm.hasUnsavedChanges, isTrue);
          expect(drafts.loadDraftCallCount, 1);
          expect(staged.reconcileCallCount, 1);
        },
      );

      test(
        'L6 raw clear failure releases the sole arbiter unchanged',
        () async {
          final pending = Completer<Result<void>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingClearDraft = pending;
          final vm = buildViewModel(draftRepository: drafts);
          addTearDown(vm.dispose);
          await vm.initialize();
          final original = StateError('unexpected clear');
          final stack = StackTrace.fromString('sentinel clear stack');
          final previousDetailed = commands.Command.detailedStackTraces;
          commands.Command.detailedStackTraces = false;
          addTearDown(
            () => commands.Command.detailedStackTraces = previousDetailed,
          );
          final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
          while (drafts.clearDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          pending.completeError(original, stack);
          await clear;
          expect(vm.clearSnapshot.unexpectedError, same(original));
          expect(vm.clearSnapshot.domainError, isNull);
          expect(
            commandLogger.eventsOfType<CommandExecutionFailed>(),
            hasLength(1),
          );
          expect(
            commandLogger
                .firstCallOfType<CommandExecutionFailed>()!
                .stackTrace
                .toString(),
            stack.toString(),
          );
          vm.setName('independent checkpoint');
          expect(await vm.checkpointDraft(), isA<Success<void>>());
          expect(drafts.saveDraftCallCount, 1);
        },
      );

      testWidgets('E2 late removal runtime settles privately after disposal', (
        tester,
      ) async {
        final probe = DisposalEventProbe();
        addTearDown(probe.dispose);
        final logger = MockLogger();
        final restoreReporting = installCommandTestReporting(logger);
        addTearDown(restoreReporting);
        final reporting = commands.Command.globalExceptionHandler;
        commands.Command<dynamic, dynamic>? settledCommand;
        commands.Command.globalExceptionHandler = (error, stack) {
          // Register memory observation before deferred physical cleanup.
          settledCommand = error.command;
          settledCommand!.addListener(() {});
          reporting!(error, stack);
        };
        addTearDown(() => commands.Command.globalExceptionHandler = reporting);
        final featureLogger = MockLogger();
        final staged = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          stagedAssetRepository: staged,
          logger: featureLogger,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1]), name: 'A.jpg'),
            ],
          ),
        );
        expect(vm.requestAddAsset(), isTrue);
        await pumpCommandTurns(tester);
        expect(vm.assets, hasLength(1));
        final asset = vm.assets.single;
        final pending = Completer<Result<void>>();
        staged.pendingRemove = pending;
        expect(vm.requestRemoveAssetAt(0), isTrue);
        await pumpCommandTurns(tester);
        expect(staged.removed, hasLength(1));
        var notifications = 0;
        vm
          ..addListener(() => notifications++)
          ..dispose();
        final frozen = vm.removeAssetAtSnapshot;
        final atDisposal = notifications;
        await tester.pump(const Duration(milliseconds: 51));
        final original = Exception('late direct removal');
        final stack = StackTrace.fromString(
          '#0 sentinelLateRemoval (file:///sentinel_late_removal.dart:42:7)',
        );
        pending.completeError(original, stack);
        await pumpCommandTurns(tester);
        await pumpPhysicalCommandDisposal(tester);
        expect(vm.removeAssetAtSnapshot, same(frozen));
        expect(vm.assets, [asset]);
        expect(
          featureLogger.eventsOfType<ContentSubmissionAssetRemovalFailed>(),
          isEmpty,
        );
        expect(notifications, atDisposal);
        expect(logger.eventsOfType<CommandExecutionFailed>(), hasLength(1));
        expect(
          logger.firstCallOfType<CommandExecutionFailed>()!.error,
          same(original),
        );
        expect(
          logger
              .firstCallOfType<CommandExecutionFailed>()!
              .stackTrace
              .toString(),
          contains('sentinel_late_removal.dart'),
        );
        expect(vm.requestRemoveAssetAt(0), isFalse);
        expect(settledCommand, isNotNull);
        expect(probe.count(settledCommand!), 1);
        expect(probe.count(vm), 1);
      });

      test('A3 captures the draft before deferred action entry', () async {
        final repository = FakeContentSubmissionRepository(
          submitResult: Result.error(Exception('remote rejected')),
        );
        final vm = buildViewModel(contentSubmissionRepository: repository);
        addTearDown(vm.dispose);
        await vm.initialize();
        vm
          ..setCity('Rome')
          ..setName('Draft A')
          ..setUserEmail('anna@example.test')
          ..setUserName('Anna');
        final identity = vm.state.clientSubmissionId;
        final submission = requestAndWait(
          vm.requestSubmit,
          () => vm.isSubmitting,
        );
        vm.setName('Draft B');
        await submission;

        expect(repository.submitCallCount, 1);
        expect(repository.submittedClientSubmissionIds, [identity]);
        expect(repository.submittedContentSubmissions.single.name, 'Draft A');
        expect(vm.state.name, 'Draft B');
        expect(vm.hasUnsavedChanges, isTrue);
      });

      test(
        'D5 late acknowledgement starts no local retirement after disposal',
        () async {
          final repository = ControllableSubmissionRepository();
          final drafts = FakeContentSubmissionDraftRepository();
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            contentSubmissionRepository: repository,
            draftRepository: drafts,
            stagedAssetRepository: staged,
          );
          await vm.initialize();
          vm
            ..setCity('Rome')
            ..setName('Draft A')
            ..setUserEmail('anna@example.test')
            ..setUserName('Anna');
          final identity = vm.state.clientSubmissionId;
          var notifications = 0;
          vm.addListener(() => notifications++);
          final submission = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (repository.submitCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          vm.dispose();
          final notificationsAtDisposal = notifications;
          repository.completeSubmission(const Result.success(null));
          await submission;
          await settleContentSubmissionTurns();

          expect(repository.submitCallCount, 1);
          expect(drafts.clearDraftCallCount, 0);
          expect(staged.clearedSessions, isEmpty);
          expect(vm.state.clientSubmissionId, identity);
          expect(notifications, notificationsAtDisposal);
        },
      );

      test(
        'E1 direct removal exception reaches reporting unchanged once',
        () async {
          final featureLogger = MockLogger();
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            stagedAssetRepository: staged,
            logger: featureLogger,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1]), name: 'asset.jpg'),
              ],
            ),
          );
          addTearDown(vm.dispose);
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final asset = vm.assets.single;
          final pending = Completer<Result<void>>();
          staged.pendingRemove = pending;
          final exception = Exception('unexpected removal');
          final stack = StackTrace.fromString('sentinel removal stack');
          final previousDetailed = commands.Command.detailedStackTraces;
          commands.Command.detailedStackTraces = false;
          addTearDown(
            () => commands.Command.detailedStackTraces = previousDetailed,
          );
          final removal = requestAndWait(
            () => vm.requestRemoveAssetAt(0),
            () => vm.isRemovingAsset,
          );
          while (staged.removed.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          pending.completeError(exception, stack);
          await removal;
          expect(vm.assets, [asset]);
          expect(
            featureLogger.eventsOfType<ContentSubmissionAssetRemovalFailed>(),
            isEmpty,
          );
          expect(await vm.checkpointDraft(), isA<Success<void>>());
          expect(vm.removeAssetAtSnapshot.unexpectedError, same(exception));
          expect(vm.removeAssetAtSnapshot.domainError, isNull);
          expect(
            commandLogger.eventsOfType<CommandExecutionFailed>(),
            hasLength(1),
          );
          final report = commandLogger
              .firstCallOfType<CommandExecutionFailed>()!;
          expect(report.error, same(exception));
          expect(report.stackTrace.toString(), stack.toString());
        },
      );

      test(
        'S13 staging already in the arbiter belongs to the submit payload',
        () async {
          final pending = Completer<Result<ContentSubmissionStagedAsset>>();
          final staged = FakeContentSubmissionStagedAssetRepository();
          final repository = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('remote rejected')),
          );
          var selection = 0;
          final vm = buildViewModel(
            contentSubmissionRepository: repository,
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(
                  Uint8List.fromList([++selection]),
                  name: 'asset-$selection.jpg',
                ),
              ],
            ),
          );
          addTearDown(vm.dispose);
          await vm.initialize();
          vm
            ..setCity('Rome')
            ..setName('Draft A')
            ..setUserEmail('anna@example.test')
            ..setUserName('Anna');
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final identity = vm.state.clientSubmissionId;
          final predecessors = vm.assets
              .map((asset) => asset.file.path)
              .toList();
          staged.pendingAcquire = pending;
          final addition = requestAndWait(
            vm.requestAddAsset,
            () => vm.isAddingAsset,
          );
          while (staged.acquired.length < 3) {
            await Future<void>.delayed(Duration.zero);
          }
          final submission = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          final digest = sha1.convert([3]).toString();
          pending.complete(
            Result.success(
              ContentSubmissionStagedAsset(
                clientSubmissionId: identity,
                digest: digest,
                relativePath: '$identity/$digest',
              ),
            ),
          );
          await Future.wait([addition, submission]);

          expect(repository.uploadedImages.map((file) => file.path), [
            ...predecessors,
            '/staged/$identity/$digest',
          ]);
          expect(repository.uploadedImages, hasLength(3));
          expect(repository.submitCallCount, 1);
          expect(repository.submittedClientSubmissionIds, [identity]);
          expect(repository.submittedContentSubmissions.single.name, 'Draft A');
          expect(vm.assets, hasLength(3));
        },
      );

      for (final acknowledged in [false, true]) {
        test(
          'S14 ${acknowledged ? 'success' : 'failure'} excludes later staging',
          () async {
            final pendingPicker = Completer<List<XFile>>();
            final pendingCheckpoint = Completer<Result<void>>();
            final drafts = FakeContentSubmissionDraftRepository();
            final staged = FakeContentSubmissionStagedAssetRepository();
            final repository = FakeContentSubmissionRepository(
              submitResult: acknowledged
                  ? const Result.success(null)
                  : Result.error(Exception('remote rejected')),
            );
            var selection = 0;
            final vm = buildViewModel(
              draftRepository: drafts,
              stagedAssetRepository: staged,
              contentSubmissionRepository: repository,
              imagePicker: FakeImagePicker(
                onPickMultipleMedia: () async {
                  selection++;
                  if (selection == 3) return await pendingPicker.future;
                  return [
                    XFile.fromData(
                      Uint8List.fromList([selection]),
                      name: 'asset-$selection.jpg',
                    ),
                  ];
                },
              ),
            );
            addTearDown(vm.dispose);
            await vm.initialize();
            vm
              ..setCity('Rome')
              ..setName('Draft A')
              ..setUserEmail('anna@example.test')
              ..setUserName('Anna');
            await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
            await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
            final predecessorPaths = vm.assets.map((a) => a.file.path).toList();
            final identity = vm.state.clientSubmissionId;
            final addition = requestAndWait(
              vm.requestAddAsset,
              () => vm.isAddingAsset,
            );
            while (selection < 3) {
              await Future<void>.delayed(Duration.zero);
            }
            vm.setDescription(
              description: 'Captured D0',
              descriptionDelta: null,
            );
            drafts.pendingSaveDraft = pendingCheckpoint;
            final checkpoint = vm.checkpointDraft();
            while (drafts.pendingSaveDraft != null) {
              await Future<void>.delayed(Duration.zero);
            }
            final durableSaves = drafts.saveDraftCallCount;
            var yPublishedBeforeUpload = false;
            vm.addListener(() {
              if (vm.assets.length == 3 && repository.uploadedImages.isEmpty) {
                yPublishedBeforeUpload = true;
              }
              if (vm.isSubmitting && !pendingPicker.isCompleted) {
                pendingPicker.complete([
                  XFile.fromData(Uint8List.fromList([3]), name: 'Y.jpg'),
                ]);
              }
            });
            final submission = requestAndWait(
              vm.requestSubmit,
              () => vm.isSubmitting,
            );
            vm.setName('D1');
            // Register Y behind the pending checkpoint before its release.
            for (var turn = 0; turn < 8; turn++) {
              await Future<void>.delayed(Duration.zero);
            }
            pendingCheckpoint.complete(const Result.success(null));
            await Future.wait([checkpoint, addition, submission]);

            expect(staged.acquired, hasLength(3));
            expect(yPublishedBeforeUpload, isTrue);
            expect(drafts.saveDraftCallCount, durableSaves);
            expect(
              repository.submittedContentSubmissions.single.name,
              'Draft A',
            );
            expect(vm.state.name, acknowledged ? isNull : 'D1');
            expect(vm.hasUnsavedChanges, !acknowledged);
            expect(vm.assets, hasLength(acknowledged ? 0 : 3));
            expect(
              repository.uploadedImages.map((file) => file.path),
              predecessorPaths,
            );
            expect(repository.uploadedImages, hasLength(2));
            expect(repository.submitCallCount, 1);
            expect(repository.submittedClientSubmissionIds, [identity]);
            expect(drafts.clearDraftCallCount, acknowledged ? 1 : 0);
            expect(staged.clearedSessions, acknowledged ? [identity] : isEmpty);
            expect(
              vm.state.clientSubmissionId,
              acknowledged ? isNot(identity) : identity,
            );
            expect(vm.submitSnapshot.completed, acknowledged);
            expect(vm.submissionFinalizationPending, isFalse);
            expect(
              commandLogger.eventsOfType<CommandExecutionFailed>(),
              isEmpty,
            );
            expect(
              repository.submittedContentSubmissions.single.description,
              'Captured D0',
            );
          },
        );
      }
    });

    test('all-day submission captures bounds without a chosen clock', () async {
      final repository = FakeContentSubmissionRepository();
      final vm = buildViewModel(contentSubmissionRepository: repository);
      addTearDown(vm.dispose);
      vm
        ..setCity('Campobasso')
        ..setName('Event')
        ..setUserName('Anna')
        ..setUserEmail('anna@example.test')
        ..setEventEnabled(enabled: true)
        ..setAllDay(allDay: true)
        ..setStartCalendarDate(EventCalendarDate(2026, 3, 29))
        ..setEndCalendarDate(EventCalendarDate(2026, 3, 30));
      expect(vm.startClockTime, isNull);
      await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
      expect(vm.submitSnapshot.completed, isTrue);
      final submitted = repository.submittedContentSubmissions.single;
      expect(submitted.allDay, isTrue);
      expect(submitted.startDate, DateTime.utc(2026, 3, 28, 23));
      expect(
        submitted.endDate,
        DateTime.utc(2026, 3, 30, 21, 59, 59, 999, 999),
      );
    });

    test('toggle off retains final day and requires a new clock', () async {
      final repository = FakeContentSubmissionRepository();
      final vm = buildViewModel(contentSubmissionRepository: repository);
      addTearDown(vm.dispose);
      vm
        ..setCity('Campobasso')
        ..setName('Event')
        ..setUserName('Anna')
        ..setUserEmail('anna@example.test')
        ..setStartCalendarDate(EventCalendarDate(2026, 10, 25))
        ..setStartClockTime(EventClockTime(1, 30))
        ..setEndCalendarDate(EventCalendarDate(2026, 10, 26))
        ..setAllDay(allDay: true)
        ..setAllDay(allDay: false);
      expect(vm.startClockTime, isNull);
      expect(vm.endCalendarDate, EventCalendarDate(2026, 10, 26));
      await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
      expect(vm.eventTimeIssue, EventTimeIssue.missingStartTime);
      expect(repository.submittedContentSubmissions, isEmpty);
      vm.setStartClockTime(EventClockTime(10, 30));
      await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
      expect(repository.submittedContentSubmissions.single.allDay, isFalse);
    });

    test('shares one draft load and staged reconciliation '
        'across initialization callers', () async {
      final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
      final pendingReconcile =
          Completer<Result<List<ContentSubmissionStagedAsset>>>();
      final draftRepository = FakeContentSubmissionDraftRepository()
        ..pendingLoadDraft = pendingLoad;
      final stagedRepository = FakeContentSubmissionStagedAssetRepository()
        ..pendingReconcile = pendingReconcile;
      final vm = buildViewModel(
        draftRepository: draftRepository,
        stagedAssetRepository: stagedRepository,
      );

      final first = vm.initialize();
      final second = vm.initialize();
      pendingLoad.complete(const Result.success(null));
      await Future<void>.delayed(Duration.zero);
      pendingReconcile.complete(const Result.success([]));
      await Future.wait([first, second]);

      expect(draftRepository.loadDraftCallCount, 1);
      expect(stagedRepository.reconcileCallCount, 1);
    });

    test(
      'keeps restoration loading until ordered staged assets resolve',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        const firstDigest = '1111111111111111111111111111111111111111';
        const secondDigest = '2222222222222222222222222222222222222222';
        final pendingReconcile =
            Completer<Result<List<ContentSubmissionStagedAsset>>>();
        final stagedRepository = FakeContentSubmissionStagedAssetRepository()
          ..pendingReconcile = pendingReconcile;
        final vm = buildViewModel(
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          ),
          stagedAssetRepository: stagedRepository,
        );

        final initialization = vm.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(vm.loadState, ContentSubmissionDraftLoadState.loading);
        expect(vm.assets, isEmpty);
        pendingReconcile.complete(
          Result.success([
            ContentSubmissionStagedAsset(
              clientSubmissionId: identity,
              digest: secondDigest,
              relativePath: '$identity/$secondDigest',
            ),
            ContentSubmissionStagedAsset(
              clientSubmissionId: identity,
              digest: firstDigest,
              relativePath: '$identity/$firstDigest',
            ),
          ]),
        );
        await initialization;

        expect(vm.loadState, ContentSubmissionDraftLoadState.ready);
        expect(vm.assets.map((asset) => asset.digest), [
          secondDigest,
          firstDigest,
        ]);
        expect(vm.assets.map((asset) => asset.file.path), [
          '/staged/$identity/$secondDigest',
          '/staged/$identity/$firstDigest',
        ]);
        expect(vm.hasUnsavedChanges, isFalse);
      },
    );

    test(
      'recreates a durable staged session in real descriptor-ID order',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_restore_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final logger = MockLogger();
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final drafts = ContentSubmissionDraftRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
        );
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        await drafts.saveDraft(
          ContentSubmissionDraft(clientSubmissionId: identity),
        );
        final firstBytes = <int>[2, 2, 2];
        final secondBytes = <int>[1, 1, 1];
        final firstSource = File('${supportDirectory.path}/first-source.jpg')
          ..writeAsBytesSync(firstBytes);
        final secondSource = File('${supportDirectory.path}/second-source.jpg')
          ..writeAsBytesSync(secondBytes);
        final firstDigest = sha1.convert(firstBytes).toString();
        final secondDigest = sha1.convert(secondBytes).toString();
        await staged.acquire(
          clientSubmissionId: identity,
          digest: firstDigest,
          source: firstSource,
        );
        await staged.acquire(
          clientSubmissionId: identity,
          digest: secondDigest,
          source: secondSource,
        );
        final vm = ContentSubmissionViewModel(
          logger: logger,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          draftRepository: drafts,
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(),
        );

        await vm.initialize();

        expect(vm.state.clientSubmissionId, identity);
        expect(vm.assets.map((asset) => asset.digest), [
          firstDigest,
          secondDigest,
        ]);
        expect(
          await Future.wait(
            vm.assets.map((asset) => File(asset.file.path).readAsBytes()),
          ),
          [firstBytes, secondBytes],
        );
        expect(
          vm.assets.map((asset) => asset.file.path),
          everyElement(
            startsWith(
              '${supportDirectory.path}/content_submission/staged/$identity/',
            ),
          ),
        );
      },
    );

    test('cleans unknown staged ownership only after an explicit successful '
        'draft clear', () async {
      const persistedIdentity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
      final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
      final supportDirectory = await Directory.systemTemp.createTemp(
        'moliseis_content_submission_draft_load_failure_',
      );
      addTearDown(() async {
        await objectBoxEnvironment.dispose();
        await supportDirectory.delete(recursive: true);
      });
      final objectBox = TestObjectBox(objectBoxEnvironment.store);
      final logger = MockLogger();
      final staged = ContentSubmissionStagedAssetRepositoryImpl(
        logger: logger,
        objectBoxI: objectBox,
        getSupportDirectory: () async => supportDirectory,
      );
      final stagedBytes = <int>[1, 2, 3];
      final stagedDigest = sha1.convert(stagedBytes).toString();
      final stagedSource = File('${supportDirectory.path}/persisted-source.jpg')
        ..writeAsBytesSync(stagedBytes);
      await staged.acquire(
        clientSubmissionId: persistedIdentity,
        digest: stagedDigest,
        source: stagedSource,
      );
      var pickerCalled = false;
      final drafts = FakeContentSubmissionDraftRepository(
        loadDraftResult: Result.error(TestException('draft read failed')),
      );
      final vm = ContentSubmissionViewModel(
        logger: logger,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        draftRepository: drafts,
        stagedAssetRepository: staged,
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () async {
            pickerCalled = true;
            return [XFile('${supportDirectory.path}/picker-source.jpg')];
          },
        ),
      );
      final freshIdentity = vm.state.clientSubmissionId;
      final persistedPath =
          '${supportDirectory.path}/content_submission/staged/'
          '$persistedIdentity/$stagedDigest';

      await vm.initialize();
      await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

      expect(vm.state.clientSubmissionId, freshIdentity);
      expect(vm.assets, isEmpty);
      expect(vm.addAssetSnapshot.hasFailure, isTrue);
      expect(pickerCalled, isFalse);
      expect(drafts.saveDraftCallCount, 0);
      expect(File(persistedPath).existsSync(), isTrue);
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        1,
      );
      expect(
        Directory(
          '${supportDirectory.path}/content_submission/staged/$freshIdentity',
        ).existsSync(),
        isFalse,
      );

      await requestAndWait(vm.requestClear, () => vm.isClearing);

      final postClearIdentity = vm.state.clientSubmissionId;
      expect(drafts.clearDraftCallCount, 1);
      expect(vm.clearSnapshot.completed, isTrue);
      expect(postClearIdentity, isNot(freshIdentity));
      expect(postClearIdentity, isNot(persistedIdentity));
      expect(vm.assets, isEmpty);
      expect(File(persistedPath).existsSync(), isFalse);
      expect(
        Directory(
          '${supportDirectory.path}/content_submission/staged/$persistedIdentity',
        ).existsSync(),
        isFalse,
      );
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
      expect(
        Directory(
          '${supportDirectory.path}/content_submission/staged/$freshIdentity',
        ).existsSync(),
        isFalse,
      );

      await vm.checkpointDraft();

      expect(drafts.saveDraftCallCount, 1);
    });

    test(
      'preserves unknown staged ownership when its draft clear fails',
      () async {
        const persistedIdentity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_unknown_clear_failure_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        final stagedBytes = <int>[1, 2, 3];
        final stagedDigest = sha1.convert(stagedBytes).toString();
        final stagedSource = File(
          '${supportDirectory.path}/persisted-source.jpg',
        )..writeAsBytesSync(stagedBytes);
        await staged.acquire(
          clientSubmissionId: persistedIdentity,
          digest: stagedDigest,
          source: stagedSource,
        );
        final clearError = TestException('draft clear failed');
        final drafts = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.error(TestException('draft read failed')),
          clearDraftResult: Result.error(clearError),
        );
        final vm = ContentSubmissionViewModel(
          logger: MockLogger(),
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          draftRepository: drafts,
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(),
        );
        final freshIdentity = vm.state.clientSubmissionId;
        final persistedPath =
            '${supportDirectory.path}/content_submission/staged/'
            '$persistedIdentity/$stagedDigest';

        await vm.initialize();
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(drafts.clearDraftCallCount, 1);
        expect(vm.clearSnapshot.hasFailure, isTrue);
        expect(vm.state.clientSubmissionId, freshIdentity);
        expect(vm.assets, isEmpty);
        expect(drafts.saveDraftCallCount, 0);
        expect(File(persistedPath).existsSync(), isTrue);
        expect(
          Directory(
            '${supportDirectory.path}/content_submission/staged/$persistedIdentity',
          ).existsSync(),
          isTrue,
        );
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          1,
        );
      },
    );

    test(
      'rotates after path-safe global cleanup failure from unknown ownership',
      () async {
        const persistedIdentity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        const privatePath =
            '/Users/example/private/content_submission/staged/secret-file';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_unknown_clear_cleanup_failure_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final logger = MockLogger();
        final setupStaged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/persisted-source.jpg')
          ..writeAsBytesSync(bytes);
        await setupStaged.acquire(
          clientSubmissionId: persistedIdentity,
          digest: digest,
          source: source,
        );
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => throw const FileSystemException(
            'cannot remove staged file',
            privatePath,
          ),
        );
        final drafts = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.error(TestException('draft read failed')),
        );
        final vm = ContentSubmissionViewModel(
          logger: logger,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          draftRepository: drafts,
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(),
        );
        final freshIdentity = vm.state.clientSubmissionId;

        await vm.initialize();
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(drafts.clearDraftCallCount, 1);
        expect(vm.clearSnapshot.completed, isTrue);
        expect(vm.state.clientSubmissionId, isNot(freshIdentity));
        expect(vm.assets, isEmpty);
        expect(
          logger.eventsOfType<ContentSubmissionAssetRemovalFailed>(),
          hasLength(1),
        );
        final cleanupDiagnostic = logger
            .firstCallOfType<ContentSubmissionAssetRemovalFailed>();
        expect(cleanupDiagnostic?.error, isNull);
        expect(cleanupDiagnostic?.stackTrace, isNull);
        expect(cleanupDiagnostic?.extra, {
          'operation': 'clear_orphans',
          'errorType': 'FileSystemException',
          'reason': 'staged cleanup failed',
        });
        for (final call in logger.calls) {
          expect(call.event.data.toString(), isNot(contains(privatePath)));
          expect(call.error?.toString(), isNot(contains(privatePath)));
          expect(call.stackTrace?.toString(), isNot(contains(privatePath)));
          expect(call.extra.toString(), isNot(contains(privatePath)));
        }
      },
    );

    test(
      'does not checkpoint a fresh draft after a draft-load failure',
      () async {
        final loadError = TestException('draft read failed');
        final drafts = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.error(loadError),
        );
        final vm = buildViewModel(draftRepository: drafts);
        final freshIdentity = vm.state.clientSubmissionId;

        final checkpoint = await vm.checkpointDraft();

        expect(checkpoint, isA<Error<void>>());
        expect((checkpoint as Error<void>).error, same(loadError));
        expect(drafts.saveDraftCallCount, 0);
        expect(vm.state.clientSubmissionId, freshIdentity);
      },
    );

    test(
      'cleans staged orphans only when draft absence is authoritative',
      () async {
        const persistedIdentity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_known_absence_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/orphaned-source.jpg')
          ..writeAsBytesSync(bytes);
        await staged.acquire(
          clientSubmissionId: persistedIdentity,
          digest: digest,
          source: source,
        );
        final vm = ContentSubmissionViewModel(
          logger: MockLogger(),
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          draftRepository: FakeContentSubmissionDraftRepository(),
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(),
        );

        await vm.initialize();

        expect(vm.assets, isEmpty);
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/'
            '$persistedIdentity/$digest',
          ).existsSync(),
          isFalse,
        );
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
      },
    );

    test(
      'quarantines over-capacity restored descriptors without opening picker',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final descriptors = List<ContentSubmissionStagedAsset>.generate(
          ContentSubmissionViewModel.maximumAssetCount + 1,
          (index) {
            final digest = index.toString().padLeft(40, '0');
            return ContentSubmissionStagedAsset(
              clientSubmissionId: identity,
              digest: digest,
              relativePath: '$identity/$digest',
            );
          },
        );
        var pickerCalled = false;
        final submissionRepository = FakeContentSubmissionRepository();
        final vm =
            buildViewModel(
                contentSubmissionRepository: submissionRepository,
                draftRepository: FakeContentSubmissionDraftRepository(
                  loadDraftResult: Result.success(
                    ContentSubmissionDraft(clientSubmissionId: identity),
                  ),
                ),
                stagedAssetRepository:
                    FakeContentSubmissionStagedAssetRepository(
                      reconcileResult: Result.success(descriptors),
                    ),
                imagePicker: FakeImagePicker(
                  onPickMultipleMedia: () async {
                    pickerCalled = true;
                    return [];
                  },
                ),
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');

        await vm.initialize();
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.loadState, ContentSubmissionDraftLoadState.ready);
        expect(vm.assets, isEmpty);
        expect(vm.addAssetSnapshot.hasFailure, isTrue);
        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(pickerCalled, isFalse);
        expect(submissionRepository.submitCalled, isFalse);
        expect(submissionRepository.uploadedImages, isEmpty);
      },
    );

    test(
      'quarantines over-capacity restored descriptors from the real store',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_over_capacity_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final logger = MockLogger();
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final drafts = ContentSubmissionDraftRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
        );
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        await drafts.saveDraft(
          ContentSubmissionDraft(
            clientSubmissionId: identity,
            city: 'Rome',
            name: 'Colosseum',
            userEmail: 'jane@example.com',
            userName: 'Jane',
          ),
        );
        final digests = <String>[];
        for (
          var index = 0;
          index <= ContentSubmissionViewModel.maximumAssetCount;
          index++
        ) {
          final bytes = <int>[index];
          final digest = sha1.convert(bytes).toString();
          digests.add(digest);
          final source = File('${supportDirectory.path}/source-$index.jpg')
            ..writeAsBytesSync(bytes);
          await staged.acquire(
            clientSubmissionId: identity,
            digest: digest,
            source: source,
          );
        }
        var pickerCalled = false;
        final submissionRepository = FakeContentSubmissionRepository();
        final vm = ContentSubmissionViewModel(
          logger: logger,
          contentSubmissionRepository: submissionRepository,
          draftRepository: drafts,
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              pickerCalled = true;
              return [];
            },
          ),
        );

        await vm.initialize();
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.assets, isEmpty);
        expect(pickerCalled, isFalse);
        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.submitCalled, isFalse);
        expect(
          (await staged.reconcileAndLoad(identity)).getOrNull(),
          hasLength(6),
        );
        expect(
          digests.map(
            (digest) => File(
              '${supportDirectory.path}/content_submission/staged/$identity/'
              '$digest',
            ).existsSync(),
          ),
          everyElement(isTrue),
        );
      },
    );

    test(
      'blocks submit and preserves staged state after reconciliation error',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_submit_reconcile_error_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final logger = MockLogger();
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final drafts = ContentSubmissionDraftRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
        );
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        await drafts.saveDraft(
          ContentSubmissionDraft(
            clientSubmissionId: identity,
            city: 'Rome',
            name: 'Colosseum',
            userEmail: 'jane@example.com',
            userName: 'Jane',
          ),
        );
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/source.jpg')
          ..writeAsBytesSync(bytes);
        await staged.acquire(
          clientSubmissionId: identity,
          digest: digest,
          source: source,
        );
        final submissionRepository = FakeContentSubmissionRepository();
        final vm = ContentSubmissionViewModel(
          logger: logger,
          contentSubmissionRepository: submissionRepository,
          draftRepository: drafts,
          stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(
            reconcileResult: const Result.error(
              FileSystemException('reconciliation failed'),
            ),
          ),
          imagePicker: FakeImagePicker(),
        );

        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(vm.assets, isEmpty);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.submitCalled, isFalse);
        expect(
          (await staged.reconcileAndLoad(identity)).getOrNull(),
          hasLength(1),
        );
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/$identity/'
            '$digest',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'blocks submit and preserves staged state after path resolution error',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_submit_resolve_error_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final logger = MockLogger();
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final drafts = ContentSubmissionDraftRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
        );
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        await drafts.saveDraft(
          ContentSubmissionDraft(
            clientSubmissionId: identity,
            city: 'Rome',
            name: 'Colosseum',
            userEmail: 'jane@example.com',
            userName: 'Jane',
          ),
        );
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/source.jpg')
          ..writeAsBytesSync(bytes);
        await staged.acquire(
          clientSubmissionId: identity,
          digest: digest,
          source: source,
        );
        final submissionRepository = FakeContentSubmissionRepository();
        final vm = ContentSubmissionViewModel(
          logger: logger,
          contentSubmissionRepository: submissionRepository,
          draftRepository: drafts,
          stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(
            reconcileResult: Result.success([
              ContentSubmissionStagedAsset(
                clientSubmissionId: identity,
                digest: digest,
                relativePath: '$identity/$digest',
              ),
            ]),
            resolveResult: const Result.error(
              FileSystemException('path resolution failed'),
            ),
          ),
          imagePicker: FakeImagePicker(),
        );

        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(vm.assets, isEmpty);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.submitCalled, isFalse);
        expect(
          (await staged.reconcileAndLoad(identity)).getOrNull(),
          hasLength(1),
        );
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/$identity/'
            '$digest',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'restored assets consume capacity before a new picker commit',
      () async {
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final restored = List<ContentSubmissionStagedAsset>.generate(4, (
          index,
        ) {
          final digest = (index + 1).toString().padLeft(40, '0');
          return ContentSubmissionStagedAsset(
            clientSubmissionId: identity,
            digest: digest,
            relativePath: '$identity/$digest',
          );
        });
        final staged = FakeContentSubmissionStagedAssetRepository(
          reconcileResult: Result.success(restored),
        );
        final imagePicker = FakeImagePicker(
          onPickMultipleMedia: () async => [
            XFile.fromData(Uint8List.fromList([7]), name: 'fifth.jpg'),
            XFile.fromData(Uint8List.fromList([8]), name: 'overflow.jpg'),
          ],
        );
        final vm = buildViewModel(
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          ),
          stagedAssetRepository: staged,
          imagePicker: imagePicker,
        );

        await vm.initialize();
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount),
        );
        expect(imagePicker.pickMultipleMediaLimits.single, 1);
        expect(staged.acquired, hasLength(1));
        expect(vm.addAssetSnapshot.data, isA<Success<AssetSelectionOutcome>>());
        expect(
          (vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>)
              .value
              .rejectedForLimitCount,
          1,
        );
      },
    );

    test(
      'awaits a pending restored draft before checkpointing or picking',
      () async {
        const restoredId = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingLoadDraft = pendingLoad;
        var pickerCalled = false;
        final vm = buildViewModel(
          draftRepository: draftRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              pickerCalled = true;
              return [];
            },
          ),
        );

        final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await Future<void>.delayed(Duration.zero);
        expect(draftRepository.saveDraftCallCount, 0);
        expect(pickerCalled, isFalse);

        pendingLoad.complete(
          Result.success(
            ContentSubmissionDraft(clientSubmissionId: restoredId),
          ),
        );
        await add;

        expect(vm.state.clientSubmissionId, restoredId);
        expect(draftRepository.saveDraftCallCount, 0);
        expect(pickerCalled, isTrue);
      },
    );

    test(
      'early checkpoint awaits restoration without saving the fresh draft',
      () async {
        const restoredId = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
        final repository = FakeContentSubmissionDraftRepository()
          ..pendingLoadDraft = pendingLoad;
        final vm = buildViewModel(draftRepository: repository);

        final checkpoint = vm.checkpointDraft();
        await Future<void>.delayed(Duration.zero);
        expect(repository.saveDraftCallCount, 0);
        pendingLoad.complete(
          Result.success(
            ContentSubmissionDraft(clientSubmissionId: restoredId),
          ),
        );
        await checkpoint;

        expect(vm.state.clientSubmissionId, restoredId);
        expect(vm.hasUnsavedChanges, isFalse);
        expect(repository.saveDraftCallCount, 0);
        expect(repository.loadDraftCallCount, 1);
      },
    );

    test(
      'clear waits for restoration before discarding the restored session',
      () async {
        const restoredId = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
        final pendingClear = Completer<Result<void>>();
        final repository = FakeContentSubmissionDraftRepository()
          ..pendingLoadDraft = pendingLoad
          ..pendingClearDraft = pendingClear;
        final vm = buildViewModel(draftRepository: repository);

        final initialization = vm.initialize();
        final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
        await Future<void>.delayed(Duration.zero);
        expect(repository.clearDraftCallCount, 0);
        pendingLoad.complete(
          Result.success(
            ContentSubmissionDraft(clientSubmissionId: restoredId),
          ),
        );
        while (repository.clearDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(vm.state.clientSubmissionId, restoredId);
        expect(repository.clearDraftCallCount, 1);
        pendingClear.complete(const Result.success(null));
        await Future.wait([initialization, clear]);

        expect(vm.state.clientSubmissionId, isNot(restoredId));
        expect(vm.hasUnsavedChanges, isFalse);
        expect(repository.loadDraftCallCount, 1);
        expect(repository.clearDraftCallCount, 1);
      },
    );

    test(
      'a failed checkpoint releases lifecycle arbitration for asset add',
      () async {
        final pendingSave = Completer<Result<void>>();
        final repository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = pendingSave;
        var pickerCalled = false;
        final vm = buildViewModel(
          draftRepository: repository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              pickerCalled = true;
              return [];
            },
          ),
        );

        final checkpoint = vm.checkpointDraft();
        while (repository.saveDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        pendingSave.complete(Result.error(Exception('save failed')));
        await checkpoint;
        await add;

        expect(repository.saveDraftCallCount, 2);
        expect(pickerCalled, isTrue);
      },
    );

    test(
      'does not open the picker when staged reconciliation retry fails',
      () async {
        var pickerCalled = false;
        final stagedRepository = FakeContentSubmissionStagedAssetRepository()
          ..reconcileResult = Result.error(Exception('reconcile failed'));
        final vm = buildViewModel(
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              pickerCalled = true;
              return [];
            },
          ),
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        expect(vm.addAssetSnapshot.hasFailure, isTrue);
        expect(pickerCalled, isFalse);
        expect(stagedRepository.reconcileCallCount, 2);
        expect(vm.loadState, ContentSubmissionDraftLoadState.ready);
        expect(vm.assets, isEmpty);
      },
    );

    test('discards picker results after clear rotates the draft', () async {
      final pendingPicker = Completer<List<XFile>>();
      final supportDirectory = await Directory.systemTemp.createTemp(
        'moliseis_content_submission_stale_picker_',
      );
      addTearDown(() => supportDirectory.delete(recursive: true));
      final stagedRepository = FakeContentSubmissionStagedAssetRepository(
        stagingDirectory: supportDirectory,
      );
      final imagePicker = FakeImagePicker(
        onPickMultipleMedia: () => pendingPicker.future,
      );
      final vm = buildViewModel(
        stagedAssetRepository: stagedRepository,
        imagePicker: imagePicker,
      );
      final oldIdentity = vm.state.clientSubmissionId;
      final lateSource = File(
        '${supportDirectory.path}/late-picker-source.jpg',
      );

      final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
      while (imagePicker.pickMultipleMediaLimits.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await requestAndWait(vm.requestClear, () => vm.isClearing);
      pendingPicker.complete([XFile(lateSource.path)]);
      await add;

      expect(vm.state.clientSubmissionId, isNot(oldIdentity));
      expect(vm.assets, isEmpty);
      expect(vm.addAssetSnapshot.hasFailure, isFalse);
      expect(lateSource.existsSync(), isFalse);
      expect(stagedRepository.acquired, isEmpty);
      expect(
        Directory('${supportDirectory.path}/$oldIdentity').existsSync(),
        isFalse,
      );
      expect(
        Directory(
          '${supportDirectory.path}/${vm.state.clientSubmissionId}',
        ).existsSync(),
        isFalse,
      );
    });

    test('clear waits for an in-flight staging commit', () async {
      final pendingAcquire = Completer<Result<ContentSubmissionStagedAsset>>();
      final stagedRepository = FakeContentSubmissionStagedAssetRepository()
        ..pendingAcquire = pendingAcquire;
      final draftRepository = FakeContentSubmissionDraftRepository();
      final vm = buildViewModel(
        draftRepository: draftRepository,
        stagedAssetRepository: stagedRepository,
        imagePicker: FakeImagePicker(
          onPickMultipleMedia: () async => [
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'asset.jpg'),
          ],
        ),
      );
      final oldIdentity = vm.state.clientSubmissionId;

      final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
      while (stagedRepository.acquired.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
      await Future<void>.delayed(Duration.zero);
      expect(draftRepository.clearDraftCallCount, 0);
      pendingAcquire.complete(
        Result.success(
          ContentSubmissionStagedAsset(
            clientSubmissionId: oldIdentity,
            digest: sha1.convert([1, 2, 3]).toString(),
            relativePath: '$oldIdentity/${sha1.convert([1, 2, 3])}',
          ),
        ),
      );
      await Future.wait([add, clear]);

      expect(stagedRepository.clearedSessions, [oldIdentity]);
      expect(vm.state.clientSubmissionId, isNot(oldIdentity));
      expect(vm.assets, isEmpty);
    });

    test(
      'checkpoint ordered before clear cannot resurrect the old identity',
      () async {
        final pendingSave = Completer<Result<void>>();
        final pendingClear = Completer<Result<void>>();
        final drafts = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = pendingSave
          ..pendingClearDraft = pendingClear;
        final vm = buildViewModel(draftRepository: drafts);
        final oldIdentity = vm.state.clientSubmissionId;

        final checkpoint = vm.checkpointDraft();
        while (drafts.saveDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
        expect(drafts.clearDraftCallCount, 0);
        pendingSave.complete(const Result.success(null));
        while (drafts.clearDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        pendingClear.complete(const Result.success(null));
        await Future.wait([checkpoint, clear]);

        expect(drafts.lastSavedState?.clientSubmissionId, oldIdentity);
        expect(vm.state.clientSubmissionId, isNot(oldIdentity));
        expect(drafts.clearDraftCallCount, 1);
      },
    );

    test(
      'checkpoint ordered after clear saves only the fresh identity',
      () async {
        final pendingClear = Completer<Result<void>>();
        final drafts = FakeContentSubmissionDraftRepository()
          ..pendingClearDraft = pendingClear;
        final vm = buildViewModel(draftRepository: drafts);
        final oldIdentity = vm.state.clientSubmissionId;

        final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
        while (drafts.clearDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final checkpoint = vm.checkpointDraft();
        pendingClear.complete(const Result.success(null));
        await Future.wait([clear, checkpoint]);

        expect(vm.state.clientSubmissionId, isNot(oldIdentity));
        expect(
          drafts.lastSavedState?.clientSubmissionId,
          vm.state.clientSubmissionId,
        );
      },
    );

    test(
      'a thrown staged commit releases lifecycle arbitration for clear',
      () async {
        final pendingAcquire =
            Completer<Result<ContentSubmissionStagedAsset>>();
        final staged = FakeContentSubmissionStagedAssetRepository()
          ..pendingAcquire = pendingAcquire;
        final vm = buildViewModel(
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'asset.jpg'),
            ],
          ),
        );

        final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        while (staged.acquired.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        pendingAcquire.completeError(StateError('staging threw'));
        await add;
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.addAssetSnapshot.hasFailure, isTrue);
        expect(vm.clearSnapshot.completed, isTrue);
        expect(staged.clearedSessions, hasLength(1));
      },
    );

    group('addAsset', () {
      test('checkpoints a fresh draft before opening the picker', () async {
        final pendingSave = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = pendingSave;
        var pickerCalled = false;
        final vm = buildViewModel(
          draftRepository: draftRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              pickerCalled = true;
              return [];
            },
          ),
        );

        final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        while (draftRepository.saveDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(pickerCalled, isFalse);
        pendingSave.complete(const Result.success(null));
        await add;

        expect(pickerCalled, isTrue);
        expect(
          draftRepository.lastSavedState?.clientSubmissionId,
          vm.state.clientSubmissionId,
        );
      });

      test(
        'does not open the picker when the first checkpoint fails',
        () async {
          final stagedRepository = FakeContentSubmissionStagedAssetRepository();
          var pickerCalled = false;
          final vm = buildViewModel(
            stagedAssetRepository: stagedRepository,
            draftRepository: FakeContentSubmissionDraftRepository(
              saveDraftResult: Result.error(Exception('disk full')),
            ),
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async {
                pickerCalled = true;
                return [];
              },
            ),
          );

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          expect(pickerCalled, isFalse);
          expect(stagedRepository.acquired, isEmpty);
          expect(vm.assets, isEmpty);
          expect(vm.addAssetSnapshot.hasFailure, isTrue);
        },
      );

      test(
        'does not rewrite an unchanged durable draft before picking',
        () async {
          final draftRepository = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(
            draftRepository: draftRepository,
            imagePicker: FakeImagePicker(onPickMultipleMedia: () async => []),
          );
          await vm.checkpointDraft();

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          expect(draftRepository.saveDraftCallCount, 1);
        },
      );

      test('adds a staged copy rather than the picker source path', () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'content-submission-view-model-test-',
        );
        addTearDown(() => temporaryDirectory.delete(recursive: true));
        final source = File('${temporaryDirectory.path}/picker-source.jpg');
        await source.writeAsBytes([1, 2, 3]);
        final stagingDirectory = Directory('${temporaryDirectory.path}/staged');
        final file = XFile(source.path, name: 'a.jpg');
        final stagedRepository = FakeContentSubmissionStagedAssetRepository(
          stagingDirectory: stagingDirectory,
        );
        final vm = buildViewModel(
          stagedAssetRepository: stagedRepository,
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(ContentSubmissionDraft()),
          ),
          imagePicker: FakeImagePicker(onPickMultipleMedia: () async => [file]),
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        expect(vm.assets, hasLength(1));
        expect(vm.assets.single.file.path, isNot(source.path));
        expect(
          vm.assets.single.file.path.startsWith('${stagingDirectory.path}/'),
          isTrue,
        );
        expect(await File(vm.assets.single.file.path).readAsBytes(), [1, 2, 3]);
        expect(vm.addAssetSnapshot.completed, isTrue);
      });

      test('accepts exactly the maximum number of assets', () async {
        final picker = FakeImagePicker(
          onPickMultipleMedia: () async => List<XFile>.generate(
            ContentSubmissionViewModel.maximumAssetCount,
            (index) => XFile.fromData(
              Uint8List.fromList([index]),
              path: '/tmp/exact-$index.jpg',
            ),
          ),
        );
        final vm = buildViewModel(imagePicker: picker);

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        final result =
            vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount),
        );
        expect(
          vm.assets.map((asset) => asset.digest).toList(),
          List<String>.generate(
            ContentSubmissionViewModel.maximumAssetCount,
            (index) => sha1.convert([index]).toString(),
          ),
        );
        expect(
          vm.assets.every((asset) => asset.file.path.startsWith('/staged/')),
          isTrue,
        );
        expect(picker.pickMultipleMediaLimits, [
          ContentSubmissionViewModel.maximumAssetCount,
        ]);
        expect(result.value.rejectedForLimitCount, 0);
        expect(result.value.hasOversizedRejections, isFalse);
        expect(result.value.hasAssetLimitRejections, isFalse);
        expect(result.value.hasRejections, isFalse);
      });

      test('caps picker results and reports selection overflow', () async {
        final picker = FakeImagePicker(
          onPickMultipleMedia: () async => List<XFile>.generate(
            ContentSubmissionViewModel.maximumAssetCount + 1,
            (index) => XFile.fromData(
              Uint8List.fromList([index]),
              path: '/tmp/overflow-$index.jpg',
            ),
          ),
        );
        final logger = MockLogger();
        final vm = buildViewModel(imagePicker: picker, logger: logger);

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        final result =
            vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount),
        );
        expect(
          vm.assets.map((asset) => asset.digest).toList(),
          List<String>.generate(
            ContentSubmissionViewModel.maximumAssetCount,
            (index) => sha1.convert([index]).toString(),
          ),
        );
        expect(picker.pickMultipleMediaLimits, [
          ContentSubmissionViewModel.maximumAssetCount,
        ]);
        expect(result.value.rejectedForLimitCount, 1);
        expect(result.value.hasOversizedRejections, isFalse);
        expect(result.value.hasAssetLimitRejections, isTrue);
        expect(result.value.hasRejections, isTrue);
        expect(vm.addAssetSnapshot.completed, isTrue);
        expect(vm.addAssetSnapshot.hasFailure, isFalse);
        expect(logger.eventsOfType<ContentSubmissionAssetAddFailed>(), isEmpty);
      });

      test(
        'uses remaining capacity and reports later selection overflow',
        () async {
          var pickRound = 0;
          final picker = FakeImagePicker(
            onPickMultipleMedia: () async {
              pickRound++;
              return pickRound == 1
                  ? List<XFile>.generate(
                      3,
                      (index) => XFile.fromData(
                        Uint8List.fromList([index]),
                        path: '/tmp/first-round-$index.jpg',
                      ),
                    )
                  : List<XFile>.generate(
                      3,
                      (index) => XFile.fromData(
                        Uint8List.fromList([index + 3]),
                        path: '/tmp/second-round-$index.jpg',
                      ),
                    );
            },
          );
          final vm = buildViewModel(imagePicker: picker);

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          final result =
              vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
          expect(
            vm.assets,
            hasLength(ContentSubmissionViewModel.maximumAssetCount),
          );
          expect(vm.assets.map((asset) => asset.digest).toList(), [
            sha1.convert([0]).toString(),
            sha1.convert([1]).toString(),
            sha1.convert([2]).toString(),
            sha1.convert([3]).toString(),
            sha1.convert([4]).toString(),
          ]);
          expect(picker.pickMultipleMediaLimits, [
            ContentSubmissionViewModel.maximumAssetCount,
            2,
          ]);
          expect(result.value.rejectedForLimitCount, 1);
          expect(result.value.hasOversizedRejections, isFalse);
          expect(result.value.hasAssetLimitRejections, isTrue);
        },
      );

      test(
        'does not open the picker when assets already reach the limit',
        () async {
          final picker = FakeImagePicker(
            onPickMultipleMedia: () async => List<XFile>.generate(
              ContentSubmissionViewModel.maximumAssetCount,
              (index) => XFile.fromData(
                Uint8List.fromList([index]),
                path: '/tmp/full-$index.jpg',
              ),
            ),
          );
          final vm = buildViewModel(imagePicker: picker);

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          final result =
              vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
          expect(
            vm.assets,
            hasLength(ContentSubmissionViewModel.maximumAssetCount),
          );
          expect(picker.pickMultipleMediaLimits, [
            ContentSubmissionViewModel.maximumAssetCount,
          ]);
          expect(result.value.hasRejections, isFalse);
          expect(vm.addAssetSnapshot.completed, isTrue);
          expect(vm.addAssetSnapshot.hasFailure, isFalse);
        },
      );

      test('does not backfill overflow after a retained duplicate', () async {
        var pickRound = 0;
        final picker = FakeImagePicker(
          onPickMultipleMedia: () async {
            pickRound++;
            return pickRound == 1
                ? List<XFile>.generate(
                    4,
                    (index) => XFile.fromData(
                      Uint8List.fromList([index + 1]),
                      path: '/tmp/original-$index.jpg',
                    ),
                  )
                : [
                    XFile.fromData(
                      Uint8List.fromList([1]),
                      path: '/tmp/duplicate.jpg',
                    ),
                    XFile.fromData(
                      Uint8List.fromList([99]),
                      path: '/tmp/overflow.jpg',
                    ),
                  ];
          },
        );
        final vm = buildViewModel(imagePicker: picker);

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        final result =
            vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
        expect(vm.assets, hasLength(4));
        expect(vm.assets.map((asset) => asset.digest).toList(), [
          sha1.convert([1]).toString(),
          sha1.convert([2]).toString(),
          sha1.convert([3]).toString(),
          sha1.convert([4]).toString(),
        ]);
        expect(picker.pickMultipleMediaLimits, [
          ContentSubmissionViewModel.maximumAssetCount,
          1,
        ]);
        expect(result.value.rejectedForLimitCount, 1);
        expect(result.value.hasOversizedRejections, isFalse);
        expect(result.value.hasAssetLimitRejections, isTrue);
      });

      test('reports oversized and asset-limit rejections together', () async {
        final picker = FakeImagePicker(
          onPickMultipleMedia: () async => [
            XFile.fromData(
              Uint8List.fromList([1]),
              path: '/tmp/oversized.jpg',
              length: kCloudinaryMaxUploadBytes + 1,
            ),
            ...List<XFile>.generate(
              ContentSubmissionViewModel.maximumAssetCount,
              (index) => XFile.fromData(
                Uint8List.fromList([index + 2]),
                path: '/tmp/combined-$index.jpg',
              ),
            ),
          ],
        );
        final vm = buildViewModel(imagePicker: picker);

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        final result =
            vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount - 1),
        );
        expect(result.value.rejectedNames, ['oversized.jpg']);
        expect(result.value.rejectedForLimitCount, 1);
        expect(result.value.hasOversizedRejections, isTrue);
        expect(result.value.hasAssetLimitRejections, isTrue);
        expect(result.value.hasRejections, isTrue);
        expect(vm.addAssetSnapshot.completed, isTrue);
        expect(vm.addAssetSnapshot.hasFailure, isFalse);
      });

      test(
        'deduplicates files with the same content in a single pick',
        () async {
          final bytes = Uint8List.fromList([1, 2, 3]);
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(bytes, name: 'a.jpg'),
                XFile.fromData(bytes, name: 'a_copy.jpg'),
              ],
            ),
          );

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          expect(vm.assets, hasLength(1));
        },
      );

      test('does not add a file whose content was already added', () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final vm = buildViewModel(
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(ContentSubmissionDraft()),
          ),
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(bytes, name: 'a.jpg'),
            ],
          ),
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(
          vm.requestAddAsset,
          () => vm.isAddingAsset,
        ); // same content, second session

        expect(vm.assets, hasLength(1));
      });

      test('adds two files with different content', () async {
        var callCount = 0;
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              callCount++;
              return callCount == 1
                  ? [
                      XFile.fromData(
                        Uint8List.fromList([1, 2, 3]),
                        name: 'a.jpg',
                      ),
                    ]
                  : [
                      XFile.fromData(
                        Uint8List.fromList([4, 5, 6]),
                        name: 'b.jpg',
                      ),
                    ];
            },
          ),
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

        expect(vm.assets, hasLength(2));
      });
      test(
        'skips files exceeding the Cloudinary size limit and keeps the rest',
        () async {
          // XFile.fromData ignores the `name` parameter on IO (name is derived
          // from `path`), so we set `path` to make `.name` resolve to the
          // basename. `length:` overrides the stored size without forcing a
          // full 10 MiB allocation.
          final small = XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: '/tmp/small.jpg',
          );
          final oversized = XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: '/tmp/big.jpg',
            length: kCloudinaryMaxUploadBytes + 1,
          );
          final logger = MockLogger();
          final vm = buildViewModel(
            logger: logger,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [small, oversized],
            ),
          );

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          expect(vm.assets, hasLength(1));
          expect(vm.assets.first.digest, sha1.convert([1, 2, 3]).toString());
          expect(vm.assets.first.file.path, startsWith('/staged/'));
          expect(vm.addAssetSnapshot.completed, isTrue);
          expect(vm.addAssetSnapshot.hasFailure, isFalse);

          final result =
              vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
          expect(result.value.rejectedNames, ['big.jpg']);
          expect(result.value.rejectedForLimitCount, 0);
          expect(result.value.hasOversizedRejections, isTrue);
          expect(result.value.hasAssetLimitRejections, isFalse);
          expect(result.value.hasRejections, isTrue);
          expect(
            logger.eventsOfType<ContentSubmissionAssetSkippedTooLarge>(),
            hasLength(1),
          );
          expect(
            logger
                .eventsOfType<ContentSubmissionAssetSkippedTooLarge>()
                .single
                .rejectedNames,
            ['big.jpg'],
          );
        },
      );

      test(
        'reports no rejections when every selected file is within the limit',
        () async {
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
              ],
            ),
          );

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          final result =
              vm.addAssetSnapshot.data! as Success<AssetSelectionOutcome>;
          expect(result.value.rejectedForLimitCount, 0);
          expect(result.value.hasOversizedRejections, isFalse);
          expect(result.value.hasAssetLimitRejections, isFalse);
          expect(result.value.hasRejections, isFalse);
          expect(result.value.rejectedNames, isEmpty);
        },
      );

      test(
        'keeps the fresh clean session when no draft is recoverable',
        () async {
          final repository = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(draftRepository: repository);
          final identity = vm.state.clientSubmissionId;

          await vm.initialize();

          expect(vm.state.clientSubmissionId, identity);
          expect(vm.hasUnsavedChanges, isFalse);
          expect(repository.saveDraftCallCount, 0);
          expect(repository.clearDraftCallCount, 0);
        },
      );
    });

    group('removeAssetAt', () {
      test(
        'rejects negative and upper-bound indexes without removal',
        () async {
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(
                  Uint8List.fromList([1, 2, 3]),
                  name: 'asset.jpg',
                ),
              ],
            ),
          );
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final asset = vm.assets.single;

          await requestAndWait(
            () => vm.requestRemoveAssetAt(-1),
            () => vm.isRemovingAsset,
          );

          expect(vm.removeAssetAtSnapshot.hasFailure, isTrue);
          expect(
            (vm.removeAssetAtSnapshot.data! as Error<void>).error.toString(),
            contains('RangeError'),
          );

          await requestAndWait(
            () => vm.requestRemoveAssetAt(1),
            () => vm.isRemovingAsset,
          );

          expect(vm.removeAssetAtSnapshot.hasFailure, isTrue);
          expect(
            (vm.removeAssetAtSnapshot.data! as Error<void>).error.toString(),
            contains('RangeError'),
          );
          expect(staged.removed, isEmpty);
          expect(vm.assets, [asset]);
        },
      );

      test(
        'invalid early removal cannot delete an asset restored later',
        () async {
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
          final supportDirectory = await Directory.systemTemp.createTemp(
            'moliseis_content_submission_early_remove_',
          );
          addTearDown(() async {
            await objectBoxEnvironment.dispose();
            await supportDirectory.delete(recursive: true);
          });
          final logger = MockLogger();
          final objectBox = TestObjectBox(objectBoxEnvironment.store);
          final staged = ContentSubmissionStagedAssetRepositoryImpl(
            logger: logger,
            objectBoxI: objectBox,
            getSupportDirectory: () async => supportDirectory,
          );
          final bytes = <int>[4, 5, 6];
          final digest = sha1.convert(bytes).toString();
          final source = File('${supportDirectory.path}/source.jpg')
            ..writeAsBytesSync(bytes);
          await staged.acquire(
            clientSubmissionId: identity,
            digest: digest,
            source: source,
          );
          final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingLoadDraft = pendingLoad;
          final vm = ContentSubmissionViewModel(
            logger: logger,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            draftRepository: drafts,
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(),
          );
          addTearDown(vm.dispose);

          final initialization = vm.initialize();
          while (drafts.loadDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          var removalCompleted = false;
          final removal =
              requestAndWait(
                () => vm.requestRemoveAssetAt(0),
                () => vm.isRemovingAsset,
              ).whenComplete(() {
                removalCompleted = true;
              });
          for (var i = 0; i < 5; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          final completedBeforeRestoration = removalCompleted;

          pendingLoad.complete(
            Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          );
          await Future.wait([initialization, removal]);

          final stagedPath =
              '${supportDirectory.path}/content_submission/staged/$identity/'
              '$digest';
          expect(completedBeforeRestoration, isTrue);
          expect(vm.removeAssetAtSnapshot.hasFailure, isTrue);
          expect(vm.assets, hasLength(1));
          expect(vm.assets.single.digest, digest);
          expect(vm.assets.single.file.path, stagedPath);
          expect(File(stagedPath).existsSync(), isTrue);
          expect(
            (await staged.reconcileAndLoad(identity)).getOrNull(),
            hasLength(1),
          );
        },
      );

      test('removes the file at the specified index', () async {
        var callCount = 0;
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              callCount++;
              return callCount == 1
                  ? [
                      XFile.fromData(
                        Uint8List.fromList([1, 2, 3]),
                        name: 'a.jpg',
                      ),
                    ]
                  : [
                      XFile.fromData(
                        Uint8List.fromList([4, 5, 6]),
                        name: 'b.jpg',
                      ),
                    ];
            },
          ),
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        final nameAtIndex1 = vm.assets[1].file.name;

        await requestAndWait(
          () => vm.requestRemoveAssetAt(0),
          () => vm.isRemovingAsset,
        );

        expect(vm.assets, hasLength(1));
        expect(vm.assets.first.file.name, nameAtIndex1);
        expect(vm.removeAssetAtSnapshot.completed, isTrue);
      });

      test('allows a removed file to be added again', () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(bytes, name: 'a.jpg'),
            ],
          ),
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        expect(vm.assets, hasLength(1));

        await requestAndWait(
          () => vm.requestRemoveAssetAt(0),
          () => vm.isRemovingAsset,
        );
        expect(vm.assets, isEmpty);

        // Same content must now be accepted because the digest was removed.
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        expect(vm.assets, hasLength(1));
      });

      test('persists the captured identity and digest before removing runtime '
          'asset', () async {
        final staged = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
            ],
          ),
        );
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        final identity = vm.state.clientSubmissionId;
        final digest = vm.assets.single.digest;

        await requestAndWait(
          () => vm.requestRemoveAssetAt(0),
          () => vm.isRemovingAsset,
        );

        expect(staged.removed, [
          (clientSubmissionId: identity, digest: digest),
        ]);
        expect(vm.assets, isEmpty);
      });

      test('preserves runtime state when persistent removal fails', () async {
        final staged = FakeContentSubmissionStagedAssetRepository()
          ..removeResult = Result.error(Exception('remove failed'));
        final vm = buildViewModel(
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
            ],
          ),
        );
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        final asset = vm.assets.single;

        await requestAndWait(
          () => vm.requestRemoveAssetAt(0),
          () => vm.isRemovingAsset,
        );

        expect(vm.removeAssetAtSnapshot.hasFailure, isTrue);
        expect(vm.assets, [asset]);
        expect(staged.removed, hasLength(1));
        expect(commandLogger.eventsOfType<CommandExecutionFailed>(), isEmpty);
      });

      test(
        'removal queued behind staging removes its captured predecessor',
        () async {
          final pendingAcquire =
              Completer<Result<ContentSubmissionStagedAsset>>();
          var pickCount = 0;
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async {
                pickCount++;
                return [
                  XFile.fromData(
                    Uint8List.fromList(pickCount == 1 ? [1] : [2]),
                    name: 'asset-$pickCount.jpg',
                  ),
                ];
              },
            ),
          );
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final first = vm.assets.single;
          staged.pendingAcquire = pendingAcquire;

          final add = requestAndWait(
            vm.requestAddAsset,
            () => vm.isAddingAsset,
          );
          while (staged.acquired.length < 2) {
            await Future<void>.delayed(Duration.zero);
          }
          final remove = requestAndWait(
            () => vm.requestRemoveAssetAt(0),
            () => vm.isRemovingAsset,
          );
          pendingAcquire.complete(
            Result.success(
              ContentSubmissionStagedAsset(
                clientSubmissionId: vm.state.clientSubmissionId,
                digest: sha1.convert(<int>[2]).toString(),
                relativePath:
                    '${vm.state.clientSubmissionId}/${sha1.convert(<int>[2])}',
              ),
            ),
          );
          await Future.wait([add, remove]);

          expect(staged.removed.single.digest, first.digest);
          expect(vm.assets.map((asset) => asset.digest), [
            sha1.convert(<int>[2]).toString(),
          ]);
        },
      );

      test(
        'removal queued behind clear cannot target the replacement session',
        () async {
          final pendingClear = Completer<Result<void>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingClearDraft = pendingClear;
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            draftRepository: drafts,
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
              ],
            ),
          );
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final oldIdentity = vm.state.clientSubmissionId;

          final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
          while (drafts.clearDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          final remove = requestAndWait(
            () => vm.requestRemoveAssetAt(0),
            () => vm.isRemovingAsset,
          );
          pendingClear.complete(const Result.success(null));
          await Future.wait([clear, remove]);

          expect(vm.state.clientSubmissionId, isNot(oldIdentity));
          expect(staged.removed, isEmpty);
          expect(staged.clearedSessions, [oldIdentity]);
        },
      );
    });

    group('disposal', () {
      test(
        'does not publish initialization completed after disposal',
        () async {
          const restoredIdentity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingLoadDraft = pendingLoad;
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            draftRepository: drafts,
            stagedAssetRepository: staged,
          );
          final initialIdentity = vm.state.clientSubmissionId;
          var notifications = 0;
          vm.addListener(() => notifications++);

          final initialization = vm.initialize();
          while (drafts.loadDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          vm.dispose();
          pendingLoad.complete(
            Result.success(
              ContentSubmissionDraft(clientSubmissionId: restoredIdentity),
            ),
          );
          await initialization;
          await settleContentSubmissionTurns();

          expect(vm.state.clientSubmissionId, initialIdentity);
          expect(vm.assets, isEmpty);
          expect(vm.loadState, ContentSubmissionDraftLoadState.loading);
          expect(staged.reconcileCallCount, 0);
          expect(notifications, 0);
        },
      );

      test('does not start user operations after disposal', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        var retrieveLostDataCalled = false;
        final picker = FakeImagePicker(
          onPickMultipleMedia: () async => [
            XFile.fromData(Uint8List.fromList([1]), name: 'late.jpg'),
          ],
          onRetrieveLostData: () async {
            retrieveLostDataCalled = true;
            return LostDataResponse.empty();
          },
        );
        final drafts = FakeContentSubmissionDraftRepository();
        final staged = FakeContentSubmissionStagedAssetRepository();
        final submissions = FakeContentSubmissionRepository();
        final vm =
            buildViewModel(
                imagePicker: picker,
                contentSubmissionRepository: submissions,
                draftRepository: drafts,
                stagedAssetRepository: staged,
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        await vm.initialize();
        final reconcileCallCount = staged.reconcileCallCount;

        vm.dispose();
        await vm.checkpointDraft();
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        await requestAndWait(vm.requestClear, () => vm.isClearing);
        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(drafts.saveDraftCallCount, 0);
        expect(drafts.clearDraftCallCount, 0);
        expect(staged.reconcileCallCount, reconcileCallCount);
        expect(picker.pickMultipleMediaLimits, isEmpty);
        expect(retrieveLostDataCalled, isFalse);
        expect(submissions.uploadedImages, isEmpty);
        expect(submissions.submitCalled, isFalse);
      });

      test('finishes in-flight clear durably without publishing a new identity '
          'after disposal', () async {
        final pendingClear = Completer<Result<void>>();
        final drafts = FakeContentSubmissionDraftRepository()
          ..pendingClearDraft = pendingClear;
        final staged = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          draftRepository: drafts,
          stagedAssetRepository: staged,
        );
        await vm.initialize();
        final oldIdentity = vm.state.clientSubmissionId;

        final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
        while (drafts.clearDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        vm.dispose();
        pendingClear.complete(const Result.success(null));
        await clear;
        await settleContentSubmissionTurns();

        expect(staged.clearedSessions, isEmpty);
        expect(vm.state.clientSubmissionId, oldIdentity);
        expect(vm.assets, isEmpty);
      });

      test(
        'does not publish a picker result received after disposal',
        () async {
          final pendingPicker = Completer<List<XFile>>();
          final stagedRepository = FakeContentSubmissionStagedAssetRepository();
          final imagePicker = FakeImagePicker(
            onPickMultipleMedia: () => pendingPicker.future,
          );
          final vm = buildViewModel(
            stagedAssetRepository: stagedRepository,
            imagePicker: imagePicker,
          );
          await vm.initialize();
          var notifications = 0;
          vm.addListener(() => notifications++);

          final add = requestAndWait(
            vm.requestAddAsset,
            () => vm.isAddingAsset,
          );
          while (imagePicker.pickMultipleMediaLimits.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          notifications = 0;
          vm.dispose();
          pendingPicker.complete([
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'late.jpg'),
          ]);
          await add;
          await settleContentSubmissionTurns();

          expect(vm.assets, isEmpty);
          expect(stagedRepository.acquired, isEmpty);
          expect(notifications, 0);
        },
      );

      test('does not publish a staged candidate after disposal', () async {
        final pendingAcquire =
            Completer<Result<ContentSubmissionStagedAsset>>();
        final stagedRepository = FakeContentSubmissionStagedAssetRepository()
          ..pendingAcquire = pendingAcquire;
        final vm = buildViewModel(
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'late.jpg'),
            ],
          ),
        );
        await vm.initialize();
        var notifications = 0;
        vm.addListener(() => notifications++);

        final add = requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        while (stagedRepository.acquired.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final acquired = stagedRepository.acquired.single;
        notifications = 0;
        vm.dispose();
        pendingAcquire.complete(
          Result.success(
            ContentSubmissionStagedAsset(
              clientSubmissionId: acquired.clientSubmissionId,
              digest: acquired.digest,
              relativePath: '${acquired.clientSubmissionId}/${acquired.digest}',
            ),
          ),
        );
        await add;
        await settleContentSubmissionTurns();

        expect(vm.assets, isEmpty);
        expect(stagedRepository.acquired, hasLength(1));
        expect(notifications, 0);
      });

      test('does not publish a persistent removal after disposal', () async {
        final pendingRemove = Completer<Result<void>>();
        final stagedRepository = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'asset.jpg'),
            ],
          ),
        );
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        stagedRepository.pendingRemove = pendingRemove;
        var notifications = 0;
        vm.addListener(() => notifications++);

        final removal = requestAndWait(
          () => vm.requestRemoveAssetAt(0),
          () => vm.isRemovingAsset,
        );
        while (stagedRepository.removed.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final notificationsAtDisposal = notifications;
        vm.dispose();
        pendingRemove.complete(const Result.success(null));
        await removal;
        await settleContentSubmissionTurns();

        expect(vm.assets, hasLength(1));
        expect(stagedRepository.removed, hasLength(1));
        expect(notifications, notificationsAtDisposal);
      });
    });

    group('retrieveLostAssets', () {
      test('is a no-op on non-Android platforms', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        var retrieveLostDataCalled = false;
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async {
              retrieveLostDataCalled = true;
              return LostDataResponse.empty();
            },
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(retrieveLostDataCalled, isFalse);
        expect(vm.assets, isEmpty);
        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
        expect(vm.retrieveLostAssetsSnapshot.hasFailure, isFalse);
      });

      test('does not modify assets when response is empty', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse.empty(),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.assets, isEmpty);
        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
      });

      test('recovers a single lost file', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'lost.jpg',
        );
        final vm = buildViewModel(
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(ContentSubmissionDraft()),
          ),
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(file: file),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.assets, hasLength(1));
        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
      });

      test('preserves restored assets when recovered staging fails', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final restoredBytes = <int>[1, 2, 3];
        final restoredDigest = sha1.convert(restoredBytes).toString();
        final recoveryError = TestException('recovered staging failed');
        final logger = MockLogger();
        final stagedRepository =
            FakeContentSubmissionStagedAssetRepository(
                reconcileResult: Result.success([
                  ContentSubmissionStagedAsset(
                    clientSubmissionId: identity,
                    digest: restoredDigest,
                    relativePath: '$identity/$restoredDigest',
                  ),
                ]),
              )
              ..pendingAcquire =
                  Completer<Result<ContentSubmissionStagedAsset>>()
              ..pendingAcquire!.complete(Result.error(recoveryError));
        final vm = buildViewModel(
          logger: logger,
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          ),
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(
              file: XFile.fromData(Uint8List.fromList(<int>[4, 5, 6])),
            ),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.retrieveLostAssetsSnapshot.hasFailure, isFalse);
        expect(vm.assets.map((asset) => asset.digest), [restoredDigest]);
        expect(vm.assets.single.file.path, '/staged/$identity/$restoredDigest');
        expect(stagedRepository.acquired, hasLength(1));
        expect(
          logger.eventsOfType<ContentSubmissionAssetRetrievalFailed>(),
          hasLength(1),
        );
        final diagnostic = logger
            .firstCallOfType<ContentSubmissionAssetRetrievalFailed>();
        expect(diagnostic, isNotNull);
        expect(diagnostic?.error, same(recoveryError));
      });

      test('does not attach lost media to a fresh non-durable draft', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final stagedRepository = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(
              file: XFile.fromData(Uint8List.fromList([1, 2, 3])),
            ),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.assets, isEmpty);
        expect(stagedRepository.acquired, isEmpty);
      });

      test('preserves existing staged state when Android recovery follows a '
          'draft-load failure', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const persistedIdentity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_lost_data_load_failure_',
        );
        addTearDown(() async {
          await objectBoxEnvironment.dispose();
          await supportDirectory.delete(recursive: true);
        });
        final objectBox = TestObjectBox(objectBoxEnvironment.store);
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
        );
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/persisted-source.jpg')
          ..writeAsBytesSync(bytes);
        await staged.acquire(
          clientSubmissionId: persistedIdentity,
          digest: digest,
          source: source,
        );
        var lostDataRetrieved = false;
        final vm = ContentSubmissionViewModel(
          logger: MockLogger(),
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.error(TestException('draft load failed')),
          ),
          stagedAssetRepository: staged,
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async {
              lostDataRetrieved = true;
              return LostDataResponse(
                file: XFile.fromData(Uint8List.fromList([4, 5, 6])),
              );
            },
          ),
        );
        final freshIdentity = vm.state.clientSubmissionId;

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(lostDataRetrieved, isTrue);
        expect(vm.assets, isEmpty);
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/'
            '$persistedIdentity/$digest',
          ).existsSync(),
          isTrue,
        );
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          1,
        );
        expect(
          Directory(
            '${supportDirectory.path}/content_submission/staged/$freshIdentity',
          ).existsSync(),
          isFalse,
        );
      });

      test(
        'does not attach lost media after staged reconciliation fails',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final stagedRepository = FakeContentSubmissionStagedAssetRepository(
            reconcileResult: Result.error(
              TestException('reconciliation failed'),
            ),
          );
          final vm = buildViewModel(
            draftRepository: FakeContentSubmissionDraftRepository(
              loadDraftResult: Result.success(
                ContentSubmissionDraft(clientSubmissionId: identity),
              ),
            ),
            stagedAssetRepository: stagedRepository,
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async => LostDataResponse(
                file: XFile.fromData(Uint8List.fromList([1, 2, 3])),
              ),
            ),
          );

          await requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );

          expect(vm.assets, isEmpty);
          expect(stagedRepository.acquired, isEmpty);
        },
      );

      test(
        'acquires lost media early and stages it after draft restoration',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final pendingLoad = Completer<Result<ContentSubmissionDraft?>>();
          final pendingReconcile =
              Completer<Result<List<ContentSubmissionStagedAsset>>>();
          final draftRepository = FakeContentSubmissionDraftRepository()
            ..pendingLoadDraft = pendingLoad;
          final stagedRepository = FakeContentSubmissionStagedAssetRepository()
            ..pendingReconcile = pendingReconcile;
          var retrieveCalled = false;
          final vm = buildViewModel(
            draftRepository: draftRepository,
            stagedAssetRepository: stagedRepository,
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async {
                retrieveCalled = true;
                return LostDataResponse(
                  file: XFile.fromData(Uint8List.fromList([1, 2, 3])),
                );
              },
            ),
          );

          final initialization = vm.initialize();
          final recovery = requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );
          await Future<void>.delayed(Duration.zero);
          expect(retrieveCalled, isTrue);
          expect(stagedRepository.acquired, isEmpty);

          pendingLoad.complete(
            Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(stagedRepository.acquired, isEmpty);
          pendingReconcile.complete(const Result.success([]));
          await initialization;
          await recovery;

          expect(stagedRepository.acquired.single.clientSubmissionId, identity);
          expect(vm.assets.single.file.path, startsWith('/staged/$identity/'));
        },
      );

      test('starts initialization after retrieveLostData throws', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final stagedRepository = FakeContentSubmissionStagedAssetRepository(
          reconcileResult: Result.success([
            ContentSubmissionStagedAsset(
              clientSubmissionId: identity,
              digest: digest,
              relativePath: '$identity/$digest',
            ),
          ]),
        );
        final draftRepository = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.success(
            ContentSubmissionDraft(clientSubmissionId: identity),
          ),
        );
        final vm = buildViewModel(
          draftRepository: draftRepository,
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async =>
                throw PlatformException(code: 'lost-data-plugin-failed'),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.retrieveLostAssetsSnapshot.hasFailure, isFalse);
        expect(draftRepository.loadDraftCallCount, 1);
        expect(stagedRepository.reconcileCallCount, 1);
        expect(vm.loadState, ContentSubmissionDraftLoadState.ready);
        expect(vm.assets.map((asset) => asset.digest), [digest]);
        expect(stagedRepository.acquired, isEmpty);
      });

      test(
        'drops recovered media when clear rotates the restored session',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final pendingClear = Completer<Result<void>>();
          final draftRepository = FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          )..pendingClearDraft = pendingClear;
          final stagedRepository = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            draftRepository: draftRepository,
            stagedAssetRepository: stagedRepository,
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async => LostDataResponse(
                file: XFile.fromData(Uint8List.fromList([1, 2, 3])),
              ),
            ),
          );
          await vm.initialize();

          final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
          while (draftRepository.clearDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          final recovery = requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );
          await Future<void>.delayed(Duration.zero);
          pendingClear.complete(const Result.success(null));
          await Future.wait([clear, recovery]);

          expect(vm.state.clientSubmissionId, isNot(identity));
          expect(stagedRepository.acquired, isEmpty);
          expect(vm.assets, isEmpty);
        },
      );

      test('recovers multiple lost files', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final fileA = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final fileB = XFile.fromData(
          Uint8List.fromList([4, 5, 6]),
          name: 'b.jpg',
        );
        final vm = buildViewModel(
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(ContentSubmissionDraft()),
          ),
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async =>
                LostDataResponse(file: fileA, files: [fileA, fileB]),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.assets, hasLength(2));
        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
      });

      test('recovers a files-only lost-data response', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final fileA = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final fileB = XFile.fromData(
          Uint8List.fromList([4, 5, 6]),
          name: 'b.jpg',
        );
        final vm = buildViewModel(
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(ContentSubmissionDraft()),
          ),
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async =>
                LostDataResponse(files: [fileA, fileB]),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
        expect(vm.assets.map((asset) => asset.digest), [
          sha1.convert(<int>[1, 2, 3]).toString(),
          sha1.convert(<int>[4, 5, 6]).toString(),
        ]);
      });

      test('caps recovered Android files at the total asset limit', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final recoveredFiles = List<XFile>.generate(
          ContentSubmissionViewModel.maximumAssetCount + 1,
          (index) => XFile.fromData(
            Uint8List.fromList([index]),
            path: '/tmp/recovered-$index.jpg',
          ),
        );
        final logger = MockLogger();
        final vm = buildViewModel(
          logger: logger,
          draftRepository: FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(ContentSubmissionDraft()),
          ),
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(
              file: recoveredFiles.first,
              files: recoveredFiles,
            ),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount),
        );
        expect(
          vm.assets.map((asset) => asset.digest).toList(),
          List<String>.generate(
            ContentSubmissionViewModel.maximumAssetCount,
            (index) => sha1.convert([index]).toString(),
          ),
        );
        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
        expect(vm.retrieveLostAssetsSnapshot.hasFailure, isFalse);
        expect(
          logger.eventsOfType<ContentSubmissionAssetSkippedTooLarge>(),
          isEmpty,
        );
        expect(
          logger.eventsOfType<ContentSubmissionAssetRetrievalFailed>(),
          isEmpty,
        );
      });

      test(
        'silently drops oversized recovered files without erroring',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);

          final small = XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: '/tmp/small.jpg',
          );
          final oversized = XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: '/tmp/big.jpg',
            length: kCloudinaryMaxUploadBytes + 1,
          );
          final logger = MockLogger();
          final vm = buildViewModel(
            logger: logger,
            draftRepository: FakeContentSubmissionDraftRepository(
              loadDraftResult: Result.success(ContentSubmissionDraft()),
            ),
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async =>
                  LostDataResponse(file: small, files: [small, oversized]),
            ),
          );

          await requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );

          // Oversized file is dropped, the small one survives.
          expect(vm.assets, hasLength(1));
          expect(vm.assets.first.file.path, startsWith('/staged/'));
          expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
          expect(vm.retrieveLostAssetsSnapshot.hasFailure, isFalse);
        },
      );

      test(
        'uses only remaining capacity after restoring four assets',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final restoredBytes = List<List<int>>.generate(
            4,
            (index) => [index + 1],
          );
          final restored = restoredBytes.map((bytes) {
            final digest = sha1.convert(bytes).toString();
            return ContentSubmissionStagedAsset(
              clientSubmissionId: identity,
              digest: digest,
              relativePath: '$identity/$digest',
            );
          }).toList();
          final duplicate = XFile.fromData(
            Uint8List.fromList(restoredBytes.first),
            name: 'duplicate.jpg',
          );
          final oversized = XFile.fromData(
            Uint8List.fromList([9]),
            name: 'oversized.jpg',
            length: kCloudinaryMaxUploadBytes + 1,
          );
          final accepted = XFile.fromData(
            Uint8List.fromList([5]),
            name: 'accepted.jpg',
          );
          final excess = XFile.fromData(
            Uint8List.fromList([6]),
            name: 'excess.jpg',
          );
          final stagedRepository = FakeContentSubmissionStagedAssetRepository(
            reconcileResult: Result.success(restored),
          );
          final vm = buildViewModel(
            draftRepository: FakeContentSubmissionDraftRepository(
              loadDraftResult: Result.success(
                ContentSubmissionDraft(clientSubmissionId: identity),
              ),
            ),
            stagedAssetRepository: stagedRepository,
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async => LostDataResponse(
                files: [duplicate, oversized, accepted, excess],
              ),
            ),
          );

          await requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );

          expect(vm.assets.map((asset) => asset.digest), [
            ...restored.map((asset) => asset.digest),
            sha1.convert(<int>[5]).toString(),
          ]);
          expect(stagedRepository.acquired, hasLength(1));
          expect(
            stagedRepository.acquired.single.digest,
            sha1.convert(<int>[5]).toString(),
          );
        },
      );

      test(
        'deduplicates recovered files against already-added files',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);

          final bytes = Uint8List.fromList([1, 2, 3]);
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(bytes, name: 'a.jpg'),
              ],
              onRetrieveLostData: () async => LostDataResponse(
                // Same bytes as the already-added file — should be rejected.
                file: XFile.fromData(bytes, name: 'a_recovered.jpg'),
              ),
            ),
          );

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          expect(vm.assets, hasLength(1));

          await requestAndWait(
            vm.requestRetrieveLostAssets,
            () => vm.isRetrievingLostAssets,
          );
          expect(vm.assets, hasLength(1)); // no duplicate
        },
      );

      test('returns success and clears error state when picker reports an '
          'exception', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(
              exception: PlatformException(
                code: 'MEDIA_ERROR',
                message: 'test error',
              ),
            ),
          ),
        );

        await requestAndWait(
          vm.requestRetrieveLostAssets,
          () => vm.isRetrievingLostAssets,
        );

        expect(vm.assets, isEmpty);
        expect(vm.retrieveLostAssetsSnapshot.hasFailure, isFalse);
        expect(vm.retrieveLostAssetsSnapshot.completed, isTrue);
      });
    });

    group('form state field isolation', () {
      test('setting one field preserves all previously set fields', () {
        final vm = buildViewModel()
          ..setCategory(ContentCategory.history)
          ..setCity('Rome')
          ..setName('Colosseum');
        const descriptionDelta = <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Ancient arena\n'},
        ];
        vm
          ..setDescription(
            description: 'Ancient arena',
            descriptionDelta: descriptionDelta,
          )
          ..setUserEmail('jane@example.com')
          ..setUserName('Jane');

        expect(vm.state.category, ContentCategory.history);
        expect(vm.state.city, 'Rome');
        expect(vm.state.name, 'Colosseum');
        expect(vm.state.description, 'Ancient arena');
        expect(vm.state.descriptionDelta, descriptionDelta);
        expect(vm.state.userEmail, 'jane@example.com');
        expect(vm.state.userName, 'Jane');
      });

      test('sets description projections atomically', () {
        final vm = buildViewModel();
        const descriptionDelta = <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Descrizione\n'},
        ];

        vm
          ..setCity('Isernia')
          ..setDescription(
            description: 'Descrizione',
            descriptionDelta: descriptionDelta,
          );

        expect(vm.state.city, 'Isernia');
        expect(vm.state.description, 'Descrizione');
        expect(vm.state.descriptionDelta, descriptionDelta);
      });

      test('setting a field does not clear previously set date fields', () {
        final vm = buildViewModel()
          ..setStartCalendarDate(EventCalendarDate(2026, 7, 25))
          ..setStartClockTime(EventClockTime(10, 30))
          ..setEndCalendarDate(EventCalendarDate(2026, 7, 26))
          ..setCity('Campobasso');

        expect(vm.startCalendarDate, EventCalendarDate(2026, 7, 25));
        expect(vm.endCalendarDate, EventCalendarDate(2026, 7, 26));
        expect(vm.state.city, 'Campobasso');
      });

      test('setting date fields does not clear previously set text fields', () {
        final vm = buildViewModel()
          ..setCity('Rome')
          ..setName('Colosseum')
          ..setDescription(
            description: 'Ancient arena',
            descriptionDelta: const <Map<String, dynamic>>[
              <String, dynamic>{'insert': 'Ancient arena\n'},
            ],
          )
          ..setUserEmail('jane@example.com')
          ..setUserName('Jane')
          ..setStartCalendarDate(EventCalendarDate(2026, 7, 25))
          ..setStartClockTime(EventClockTime(10, 30))
          ..setEndCalendarDate(EventCalendarDate(2026, 7, 26));

        expect(vm.startCalendarDate, EventCalendarDate(2026, 7, 25));
        expect(vm.endCalendarDate, EventCalendarDate(2026, 7, 26));
        expect(vm.state.city, 'Rome');
        expect(vm.state.name, 'Colosseum');
        expect(vm.state.description, 'Ancient arena');
        expect(vm.state.userEmail, 'jane@example.com');
        expect(vm.state.userName, 'Jane');
      });

      test('clearing one field to null preserves other fields', () {
        final vm = buildViewModel()
          ..setCategory(ContentCategory.history)
          ..setCity('Rome')
          ..setName('Colosseum')
          ..setCategory(null);

        expect(vm.state.category, isNull);
        expect(vm.state.city, 'Rome');
        expect(vm.state.name, 'Colosseum');
      });

      testWidgets('does not save after the former debounce interval', (
        tester,
      ) async {
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepo);

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        );

        expect(draftRepo.saveDraftCalled, isFalse);

        vm
          ..setCity('Campobasso')
          ..setName('Test event');
        await tester.pump();

        expect(draftRepo.saveDraftCalled, isFalse);
        await tester.pump(const Duration(seconds: 3, milliseconds: 100));

        expect(draftRepo.saveDraftCalled, isFalse);
        expect(vm.hasUnsavedChanges, isTrue);
      });

      testWidgets(
        'checkpoints both description projections only when requested',
        (tester) async {
          final draftRepo = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(draftRepository: draftRepo);
          addTearDown(vm.dispose);
          const descriptionDelta = <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'Descrizione\n'},
          ];

          await tester.pumpWidget(
            const Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox.shrink(),
            ),
          );

          vm.setDescription(
            description: 'Descrizione',
            descriptionDelta: descriptionDelta,
          );
          await tester.pump();
          expect(draftRepo.saveDraftCallCount, 0);

          final result = await vm.checkpointDraft();

          expect(result, isA<Success<void>>());
          expect(draftRepo.saveDraftCallCount, 1);
          expect(draftRepo.lastSavedState?.description, 'Descrizione');
          expect(draftRepo.lastSavedState?.descriptionDelta, descriptionDelta);
        },
      );

      testWidgets('persists and restores an enabled incomplete event draft', (
        tester,
      ) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepository);
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        );

        vm
          ..setEventEnabled(enabled: true)
          ..setStartCalendarDate(EventCalendarDate(2026, 7, 25));
        await vm.checkpointDraft();

        final saved = draftRepository.lastSavedState;
        expect(saved?.eventDates.startInstantUtc, isNull);
        expect(
          saved?.eventDates.startCalendarDate,
          EventCalendarDate(2026, 7, 25),
        );

        final restoredRepository = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.success(saved),
        );
        final restored = buildViewModel(draftRepository: restoredRepository);
        addTearDown(restored.dispose);

        await restored.initialize();

        expect(restored.isEvent, isTrue);
        expect(restored.startCalendarDate, EventCalendarDate(2026, 7, 25));
        expect(restored.startClockTime, isNull);
      });

      test('repairs end day when a start edit overtakes it', () {
        final vm = buildViewModel()
          ..setStartCalendarDate(EventCalendarDate(2026, 7, 25))
          ..setStartClockTime(EventClockTime(10, 30))
          ..setEndCalendarDate(EventCalendarDate(2026, 7, 26))
          ..setStartCalendarDate(EventCalendarDate(2026, 7, 27));

        expect(vm.startCalendarDate, EventCalendarDate(2026, 7, 27));
        expect(vm.endCalendarDate, EventCalendarDate(2026, 7, 27));
      });

      test('clearing description clears both projections', () {
        final vm = buildViewModel()
          ..setDescription(
            description: 'Descrizione',
            descriptionDelta: const <Map<String, dynamic>>[
              <String, dynamic>{'insert': 'Descrizione\n'},
            ],
          )
          ..setDescription(description: null, descriptionDelta: null);

        expect(vm.state.description, isNull);
        expect(vm.state.descriptionDelta, isNull);
      });
    });

    group('draft checkpoints', () {
      test(
        'starts clean and writes only after an explicit checkpoint',
        () async {
          final repository = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(draftRepository: repository);
          final identity = vm.state.clientSubmissionId;

          expect(vm.hasUnsavedChanges, isFalse);
          expect(repository.saveDraftCallCount, 0);

          vm.setCity('Campobasso');
          expect(vm.hasUnsavedChanges, isTrue);
          expect(vm.state.clientSubmissionId, identity);

          expect(await vm.checkpointDraft(), isA<Success<void>>());
          expect(repository.saveDraftCallCount, 1);
          expect(repository.lastSavedState?.city, 'Campobasso');
          expect(repository.lastSavedState?.clientSubmissionId, identity);
          expect(vm.hasUnsavedChanges, isFalse);

          expect(await vm.checkpointDraft(), isA<Success<void>>());
          expect(repository.saveDraftCallCount, 1);
        },
      );

      test(
        'keeps dirty state scoped to draft fields across asset mutations',
        () async {
          final secondPickerResult = Completer<List<XFile>>();
          var pickerInvocation = 0;
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async {
                if (pickerInvocation++ == 0) {
                  return [
                    XFile.fromData(
                      Uint8List.fromList([1, 2, 3]),
                      name: 'first.jpg',
                    ),
                  ];
                }
                return await secondPickerResult.future;
              },
            ),
          );

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          expect(vm.assets, hasLength(1));
          expect(vm.hasUnsavedChanges, isFalse);

          await requestAndWait(
            () => vm.requestRemoveAssetAt(0),
            () => vm.isRemovingAsset,
          );
          expect(vm.assets, isEmpty);
          expect(vm.hasUnsavedChanges, isFalse);

          vm.setCity('Campobasso');
          expect(vm.hasUnsavedChanges, isTrue);

          final addition = requestAndWait(
            vm.requestAddAsset,
            () => vm.isAddingAsset,
          );
          while (pickerInvocation != 2) {
            await Future<void>.delayed(Duration.zero);
          }
          vm.setName('Test event');
          secondPickerResult.complete([
            XFile.fromData(Uint8List.fromList([4, 5, 6]), name: 'second.jpg'),
          ]);
          await addition;
          expect(vm.assets, hasLength(1));
          expect(vm.hasUnsavedChanges, isTrue);

          await requestAndWait(
            () => vm.requestRemoveAssetAt(0),
            () => vm.isRemovingAsset,
          );
          expect(vm.assets, isEmpty);
          expect(vm.hasUnsavedChanges, isTrue);
        },
      );

      test('a no-op setter preserves derived dirty state without a save', () {
        final repository = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: repository)..setCity(null);

        expect(vm.hasUnsavedChanges, isFalse);
        expect(repository.saveDraftCallCount, 0);

        vm
          ..setCity('Rome')
          ..setCity('Rome');
        expect(vm.hasUnsavedChanges, isTrue);
        expect(repository.saveDraftCallCount, 0);
      });

      test(
        'preserves the dirty baseline after a failed checkpoint and retry',
        () async {
          final repository = FakeContentSubmissionDraftRepository(
            saveDraftResult: Result.error(Exception('disk full')),
          );
          final vm = buildViewModel(draftRepository: repository)
            ..setCity('Rome');
          final identity = vm.state.clientSubmissionId;

          expect(await vm.checkpointDraft(), isA<Error<void>>());
          expect(vm.hasUnsavedChanges, isTrue);
          expect(vm.state.clientSubmissionId, identity);

          repository.saveDraftResult = const Result.success(null);
          expect(await vm.checkpointDraft(), isA<Success<void>>());
          expect(repository.saveDraftCallCount, 2);
          expect(vm.hasUnsavedChanges, isFalse);
        },
      );

      test('keeps a mutation made during a checkpoint dirty', () async {
        final pendingSave = Completer<Result<void>>();
        final repository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = pendingSave;
        final vm = buildViewModel(draftRepository: repository);
        await vm.initialize();
        vm.setCity('Rome');

        final checkpoint = vm.checkpointDraft();
        while (repository.saveDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        vm.setCity('Isernia');
        pendingSave.complete(const Result.success(null));

        expect(await checkpoint, isA<Success<void>>());
        expect(repository.saveDraftCallCount, 1);
        expect(repository.lastSavedState?.city, 'Rome');
        expect(vm.state.city, 'Isernia');
        expect(vm.hasUnsavedChanges, isTrue);
      });

      test(
        'recovers a valid identity as a clean session without a write',
        () async {
          const identity = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
          final repository = FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(
              ContentSubmissionDraft(
                clientSubmissionId: identity,
                city: 'Rome',
              ),
            ),
          );
          final vm = buildViewModel(draftRepository: repository);

          await vm.initialize();

          expect(vm.state.clientSubmissionId, identity);
          expect(vm.state.city, 'Rome');
          expect(vm.hasUnsavedChanges, isFalse);
          expect(repository.saveDraftCallCount, 0);
        },
      );

      test('falls back from an unsupported legacy projection and checkpoints '
          'the fresh identity', () async {
        const unsupportedLegacyIdentity = 'not-a-valid-legacy-identity';
        // The mapper/repository project unsupported stored identities to
        // `Success(null)` rather than exposing a domain draft.
        final repository = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: repository);

        await vm.initialize();

        final freshIdentity = vm.state.clientSubmissionId;
        expect(freshIdentity, isNot(unsupportedLegacyIdentity));
        expect(
          ContentSubmissionDraft.isValidClientSubmissionId(freshIdentity),
          isTrue,
        );
        expect(vm.state.city, isNull);
        expect(vm.hasUnsavedChanges, isFalse);
        expect(repository.saveDraftCallCount, 0);
        expect(repository.clearDraftCallCount, 0);

        vm.setCity('Isernia');
        expect(vm.hasUnsavedChanges, isTrue);

        expect(await vm.checkpointDraft(), isA<Success<void>>());
        expect(repository.lastSavedState?.city, 'Isernia');
        expect(repository.lastSavedState?.clientSubmissionId, freshIdentity);
        expect(repository.clearDraftCallCount, 0);
      });

      test(
        'restores only dirty form fields to the durable checkpoint',
        () async {
          final drafts = FakeContentSubmissionDraftRepository();
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            draftRepository: drafts,
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
              ],
            ),
          );
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          vm.setCity('Campobasso');
          await vm.checkpointDraft();
          final checkpoint = vm.state;
          final identity = vm.state.clientSubmissionId;
          final asset = vm.assets.single;
          vm
            ..setCity('Isernia')
            ..setStartCalendarDate(EventCalendarDate(2025, 3, 30))
            ..setStartClockTime(EventClockTime(2, 30));

          expect(vm.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
          expect(await vm.restoreCheckpointDraft(), isA<Success<void>>());

          expect(vm.state, checkpoint);
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.assets, [asset]);
          expect(vm.eventTimeIssue, isNull);
          expect(vm.hasUnsavedChanges, isFalse);
          expect(drafts.saveDraftCallCount, 2);
          expect(drafts.clearDraftCallCount, 0);
          expect(staged.clearedSessions, isEmpty);

          expect(await vm.restoreCheckpointDraft(), isA<Success<void>>());
          expect(drafts.saveDraftCallCount, 2);

          final reopened = buildViewModel(
            draftRepository: FakeContentSubmissionDraftRepository(
              loadDraftResult: Result.success(drafts.lastSavedState),
            ),
          );
          await reopened.initialize();
          expect(reopened.state.city, 'Campobasso');
          expect(reopened.state.clientSubmissionId, identity);
        },
      );

      test(
        'refuses checkpoint restoration when persisted ownership is unknown',
        () async {
          final loadError = TestException('draft load failed');
          final drafts = FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.error(loadError),
          );
          final vm = buildViewModel(draftRepository: drafts)
            ..setCity('Isernia');
          final state = vm.state;
          final identity = state.clientSubmissionId;

          final result = await vm.restoreCheckpointDraft();

          expect(result, isA<Error<void>>());
          expect((result as Error<void>).error, same(loadError));
          expect(vm.state, state);
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.assets, isEmpty);
          expect(drafts.saveDraftCallCount, 0);
          expect(drafts.clearDraftCallCount, 0);
        },
      );
    });

    group('submit', () {
      test(
        'derives immediate retry as false for idle, running, and success',
        () async {
          final repository = ControllableSubmissionRepository();
          final vm = buildViewModel(contentSubmissionRepository: repository)
            ..setCity('Rome')
            ..setName('Colosseum')
            ..setUserEmail('jane@example.com')
            ..setUserName('Jane');

          expect(vm.canRetrySubmissionImmediately, isFalse);

          final submission = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (repository.submitCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }

          expect(vm.isSubmitting, isTrue);
          expect(vm.canRetrySubmissionImmediately, isFalse);

          repository.completeSubmission(const Result.success(null));
          await submission;

          expect(vm.submitSnapshot.completed, isTrue);
          expect(vm.canRetrySubmissionImmediately, isFalse);
        },
      );

      test(
        'derives immediate retry as false for local submit failures',
        () async {
          final eligibility = buildViewModel();

          await requestAndWait(
            eligibility.requestSubmit,
            () => eligibility.isSubmitting,
          );

          expect(eligibility.submitSnapshot.hasFailure, isTrue);
          expect(eligibility.canRetrySubmissionImmediately, isFalse);

          final staged =
              buildViewModel(
                  stagedAssetRepository:
                      FakeContentSubmissionStagedAssetRepository(
                        reconcileResult: Result.error(
                          TestException('staged state unavailable'),
                        ),
                      ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          await requestAndWait(staged.requestSubmit, () => staged.isSubmitting);

          expect(staged.submitSnapshot.hasFailure, isTrue);
          expect(staged.canRetrySubmissionImmediately, isFalse);

          final checkpoint =
              buildViewModel(
                  draftRepository: FakeContentSubmissionDraftRepository(
                    saveDraftResult: Result.error(
                      TestException('checkpoint failed'),
                    ),
                  ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          await requestAndWait(
            checkpoint.requestSubmit,
            () => checkpoint.isSubmitting,
          );

          expect(checkpoint.submitSnapshot.hasFailure, isTrue);
          expect(checkpoint.canRetrySubmissionImmediately, isFalse);
        },
      );

      test(
        'derives immediate retry as false for upload terminal failures',
        () async {
          final repository = FakeContentSubmissionRepository(
            uploadImageTaskResults: <ImageUploadTask>[
              FakeImageUploadTask.completed(
                Result.error(TestException('preparation failed')),
              ),
              FakeImageUploadTask.completed(
                Result.error(TestException('direct upload failed')),
              ),
            ],
          );
          final vm =
              buildViewModel(
                  contentSubmissionRepository: repository,
                  imagePicker: FakeImagePicker(
                    onPickMultipleMedia: () async => <XFile>[
                      XFile.fromData(
                        Uint8List.fromList(<int>[1]),
                        name: 'a.jpg',
                      ),
                    ],
                  ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(vm.canRetrySubmissionImmediately, isFalse);

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(vm.canRetrySubmissionImmediately, isFalse);
          expect(repository.submitCallCount, 0);
        },
      );

      for (final failure in <({String name, Exception error})>[
        (name: 'final submit error', error: TestException('submit failed')),
        (
          name: 'malformed acknowledgement',
          error: const FormatException('malformed acknowledgement'),
        ),
        (
          name: 'final submit timeout',
          error: TimeoutException('final submit timed out'),
        ),
        (
          name: 'final submit socket error',
          error: const SocketException('final submit transport failed'),
        ),
        (name: 'unknown error', error: TestException('unknown failure')),
      ]) {
        test('derives immediate retry as false for ${failure.name}', () async {
          final vm =
              buildViewModel(
                  contentSubmissionRepository: FakeContentSubmissionRepository(
                    submitResult: Result.error(failure.error),
                  ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(vm.canRetrySubmissionImmediately, isFalse);
        });
      }

      test(
        'blocks enabled incomplete events before any upload begins',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(contentSubmissionRepository: submissionRepository)
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane')
                ..setEventEnabled(enabled: true)
                ..setStartCalendarDate(EventCalendarDate(2026, 7, 25));

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(submissionRepository.submitCalled, isFalse);
          expect(submissionRepository.uploadedImages, isEmpty);
        },
      );

      test('rejects DST-gap edits without replacing the valid event draft', () {
        final vm = buildViewModel()
          ..setStartCalendarDate(EventCalendarDate(2025, 3, 30))
          ..setStartClockTime(EventClockTime(1, 30));
        final prior = vm.state.eventDates;
        var notifications = 0;
        vm
          ..addListener(() => notifications++)
          ..setStartClockTime(EventClockTime(2, 30));

        expect(vm.state.eventDates, prior);
        expect(vm.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
        expect(notifications, 1);
      });

      test(
        'rejects DST-overlap edits without replacing the valid event draft',
        () {
          final vm = buildViewModel()
            ..setStartCalendarDate(EventCalendarDate(2025, 10, 26))
            ..setStartClockTime(EventClockTime(1, 30));
          final prior = vm.state.eventDates;

          vm.setStartClockTime(EventClockTime(2, 30));

          expect(vm.state.eventDates, prior);
          expect(vm.eventTimeIssue, EventTimeIssue.ambiguousLocalTime);
        },
      );

      test('blocks upload while a live DST issue remains', () async {
        final submissionRepository = FakeContentSubmissionRepository();
        final vm =
            buildViewModel(contentSubmissionRepository: submissionRepository)
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane')
              ..setStartCalendarDate(EventCalendarDate(2025, 3, 30))
              ..setStartClockTime(EventClockTime(1, 30))
              ..setStartClockTime(EventClockTime(2, 30));

        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
        expect(submissionRepository.submitCalled, isFalse);
        expect(submissionRepository.uploadedImages, isEmpty);
      });

      test(
        'fails without calling upload when all required fields are missing',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm = buildViewModel(
            contentSubmissionRepository: submissionRepository,
          );

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.completed, isFalse);
          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(submissionRepository.submitCalled, isFalse);

          final result = vm.submitSnapshot.data;
          expect(result, isA<Error<void>>());
          final error = (result! as Error<void>).error;
          expect(error.toString(), contains('city'));
          expect(error.toString(), contains('name'));
          expect(error.toString(), contains('userEmail'));
          expect(error.toString(), contains('userName'));
        },
      );

      test(
        'reports only the specific missing field when one is left null',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(contentSubmissionRepository: submissionRepository)
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com');
          // userName intentionally left null

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(submissionRepository.submitCalled, isFalse);

          final error = (vm.submitSnapshot.data! as Error<void>).error;
          expect(error.toString(), contains('userName'));
          expect(error.toString(), isNot(contains('city')));
          expect(error.toString(), isNot(contains('name')));
          expect(error.toString(), isNot(contains('userEmail')));
        },
      );

      test('calls upload when all required fields are present', () async {
        final submissionRepository = FakeContentSubmissionRepository();
        final vm =
            buildViewModel(contentSubmissionRepository: submissionRepository)
              ..setCity('Rome')
              ..setName('Colosseum');
        const descriptionDelta = <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Ancient arena\n'},
        ];
        vm
          ..setDescription(
            description: 'Ancient arena',
            descriptionDelta: descriptionDelta,
          )
          ..setUserEmail('jane@example.com')
          ..setUserName('Jane');

        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.submitSnapshot.completed, isTrue);
        expect(vm.submitSnapshot.hasFailure, isFalse);
        expect(submissionRepository.submitCalled, isTrue);
        expect(
          submissionRepository.submittedContentSubmissions.last.description,
          'Ancient arena',
        );
        expect(
          submissionRepository
              .submittedContentSubmissions
              .last
              .descriptionDelta,
          descriptionDelta,
        );
      });

      test(
        'submits the captured checkpoint snapshot when live fields change',
        () async {
          final pendingSave = Completer<Result<void>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingSaveDraft = pendingSave;
          final submissions = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('remote failure')),
          );
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissions,
                  draftRepository: drafts,
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          final identity = vm.state.clientSubmissionId;

          final submit = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (drafts.saveDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          vm
            ..setCity('Isernia')
            ..setName('Castello')
            ..setUserEmail('other@example.com')
            ..setUserName('Other');
          pendingSave.complete(const Result.success(null));
          await submit;

          expect(drafts.lastSavedState?.city, 'Rome');
          expect(drafts.saveDraftCallCount, 1);
          expect(submissions.submittedClientSubmissionIds, [identity]);
          expect(submissions.submittedContentSubmissions.single.city, 'Rome');
          expect(
            submissions.submittedContentSubmissions.single.name,
            'Colosseum',
          );
          expect(
            submissions.submittedContentSubmissions.single.userEmail,
            'jane@example.com',
          );
          expect(vm.state.city, 'Isernia');
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.hasUnsavedChanges, isTrue);

          await requestAndWait(vm.requestClear, () => vm.isClearing);
          expect(vm.clearSnapshot.completed, isTrue);
          expect(vm.state.clientSubmissionId, isNot(identity));
        },
      );

      test(
        'uses captured ordered assets and payload after a Cloudinary gap',
        () async {
          final uploadTask = FakeImageUploadTask.pending();
          final submissions = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('remote failure')),
            uploadImageTaskResult: uploadTask,
          );
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissions,
                  imagePicker: FakeImagePicker(
                    onPickMultipleMedia: () async => <XFile>[
                      XFile.fromData(
                        Uint8List.fromList(<int>[1, 2, 3]),
                        name: 'captured.jpg',
                      ),
                    ],
                  ),
                )
                ..setCategory(ContentCategory.history)
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setDescription(
                  description: 'Captured description',
                  descriptionDelta: const <Map<String, dynamic>>[
                    <String, dynamic>{'insert': 'Captured description\n'},
                  ],
                )
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final identity = vm.state.clientSubmissionId;

          final submit = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (submissions.uploadedImages.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          vm
            ..setCity('Isernia')
            ..setName('Castello')
            ..setUserEmail('other@example.com')
            ..setUserName('Other');
          await requestAndWait(
            () => vm.requestRemoveAssetAt(0),
            () => vm.isRemovingAsset,
          );
          uploadTask.complete(
            const Result.success(
              SubmissionAsset(
                secureUrl: 'https://assets.example/captured.jpg',
                width: 1,
                height: 1,
              ),
            ),
          );
          await submit;

          expect(submissions.submittedClientSubmissionIds, [identity]);
          final captured = submissions.submittedContentSubmissions.single;
          expect(captured.category, ContentCategory.history);
          expect(captured.city, 'Rome');
          expect(captured.name, 'Colosseum');
          expect(captured.description, 'Captured description');
          expect(captured.descriptionDelta, const <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'Captured description\n'},
          ]);
          expect(captured.userEmail, 'jane@example.com');
          expect(captured.userName, 'Jane');
          expect(
            submissions.submittedSubmissionAssets.single.single.secureUrl,
            'https://assets.example/captured.jpg',
          );
          expect(vm.assets, isEmpty);
          expect(vm.state.city, 'Isernia');
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.hasUnsavedChanges, isTrue);
        },
      );

      test(
        'does not save an already-durable snapshot before remote work',
        () async {
          final drafts = FakeContentSubmissionDraftRepository();
          final submissions = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('remote failure')),
          );
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissions,
                  draftRepository: drafts,
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');

          await vm.checkpointDraft();
          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(drafts.saveDraftCallCount, 1);
          expect(submissions.submitCallCount, 1);
        },
      );

      test(
        'keeps submit running through local finalization and retires once',
        () async {
          final pendingClear = Completer<Result<void>>();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingClearDraft = pendingClear;
          final staged = FakeContentSubmissionStagedAssetRepository();
          final repository = FakeContentSubmissionRepository();
          final logger = MockLogger();
          final vm =
              buildViewModel(
                  contentSubmissionRepository: repository,
                  draftRepository: drafts,
                  stagedAssetRepository: staged,
                  logger: logger,
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          final identity = vm.state.clientSubmissionId;

          final submission = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (drafts.clearDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }

          expect(vm.isSubmitting, isTrue);
          expect(vm.submissionFinalizationPending, isTrue);
          expect(repository.submitCallCount, 1);
          expect(vm.state.clientSubmissionId, identity);
          pendingClear.complete(const Result.success(null));
          await submission;

          expect(vm.submitSnapshot.completed, isTrue);
          expect(vm.submissionFinalizationPending, isFalse);
          expect(vm.state.clientSubmissionId, isNot(identity));
          expect(drafts.clearDraftCallCount, 1);
          expect(staged.clearedSessions, [identity]);
          expect(logger.calls, isEmpty);
        },
      );

      test(
        'retries failed local finalization without resending remote content',
        () async {
          final finalizationError = TestException('clear failed');
          final drafts = FakeContentSubmissionDraftRepository(
            clearDraftResult: Result.error(finalizationError),
          );
          final staged = FakeContentSubmissionStagedAssetRepository();
          final repository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(
                  contentSubmissionRepository: repository,
                  draftRepository: drafts,
                  stagedAssetRepository: staged,
                  imagePicker: FakeImagePicker(
                    onPickMultipleMedia: () async => <XFile>[
                      XFile.fromData(
                        Uint8List.fromList(<int>[1, 2, 3]),
                        name: 'staged.jpg',
                      ),
                    ],
                  ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final identity = vm.state.clientSubmissionId;
          final state = vm.state;

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(vm.submissionFinalizationPending, isTrue);
          expect(vm.canRetrySubmissionImmediately, isTrue);
          expect(vm.state, state);
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.assets, hasLength(1));
          expect(repository.submitCallCount, 1);
          expect(repository.uploadedImages, hasLength(1));
          expect(drafts.saveDraftCallCount, 1);
          expect(drafts.clearDraftCallCount, 1);
          expect(staged.clearedSessions, isEmpty);

          await requestAndWait(vm.requestClear, () => vm.isClearing);
          expect(vm.clearSnapshot.hasFailure, isTrue);
          expect(drafts.clearDraftCallCount, 1);

          final pendingRetry = Completer<Result<void>>();
          drafts.pendingClearDraft = pendingRetry;
          final retry = requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
          while (drafts.clearDraftCallCount < 2) {
            await Future<void>.delayed(Duration.zero);
          }

          expect(vm.isSubmitting, isTrue);
          expect(vm.submitSnapshot.data, isNull);
          expect(vm.canRetrySubmissionImmediately, isFalse);
          expect(vm.state, state);
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.assets, hasLength(1));
          expect(staged.clearedSessions, isEmpty);

          pendingRetry.complete(Result.error(finalizationError));
          await retry;

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(vm.canRetrySubmissionImmediately, isTrue);
          expect(repository.submitCallCount, 1);
          expect(repository.uploadedImages, hasLength(1));
          expect(drafts.saveDraftCallCount, 1);
          expect(drafts.clearDraftCallCount, 2);
          expect(vm.state, state);
          expect(vm.state.clientSubmissionId, identity);
          expect(vm.assets, hasLength(1));
          expect(staged.clearedSessions, isEmpty);

          drafts.clearDraftResult = const Result.success(null);
          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.completed, isTrue);
          expect(vm.submissionFinalizationPending, isFalse);
          expect(vm.canRetrySubmissionImmediately, isFalse);
          expect(repository.submitCallCount, 1);
          expect(repository.uploadedImages, hasLength(1));
          expect(drafts.saveDraftCallCount, 1);
          expect(drafts.clearDraftCallCount, 3);
          expect(staged.clearedSessions, [identity]);
          expect(vm.assets, isEmpty);
          expect(vm.state.clientSubmissionId, isNot(identity));
        },
      );

      test('rejects clear during a pending Cloudinary attempt then releases '
          'the session after its failure', () async {
        final uploadTask = FakeImageUploadTask.pending();
        final drafts = FakeContentSubmissionDraftRepository();
        final staged = FakeContentSubmissionStagedAssetRepository();
        final repository = FakeContentSubmissionRepository(
          uploadImageTaskResult: uploadTask,
        );
        final vm =
            buildViewModel(
                contentSubmissionRepository: repository,
                draftRepository: drafts,
                stagedAssetRepository: staged,
                imagePicker: FakeImagePicker(
                  onPickMultipleMedia: () async => [
                    XFile.fromData(Uint8List.fromList([1]), name: 'a.jpg'),
                  ],
                ),
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        final identity = vm.state.clientSubmissionId;

        final submission = requestAndWait(
          vm.requestSubmit,
          () => vm.isSubmitting,
        );
        while (repository.uploadedImages.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.clearSnapshot.hasFailure, isTrue);
        expect(drafts.clearDraftCallCount, 0);
        expect(staged.clearedSessions, isEmpty);
        expect(vm.state.clientSubmissionId, identity);
        uploadTask.complete(Result.error(Exception('Cloudinary failed')));
        await submission;

        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(repository.submitCallCount, 0);
        await requestAndWait(vm.requestClear, () => vm.isClearing);
        expect(vm.clearSnapshot.completed, isTrue);
        expect(drafts.clearDraftCallCount, 1);
        expect(staged.clearedSessions, [identity]);
        expect(vm.state.clientSubmissionId, isNot(identity));
      });

      test('rejects clear during a pending final request then releases the '
          'session after its failure', () async {
        final repository = ControllableSubmissionRepository();
        final drafts = FakeContentSubmissionDraftRepository();
        final staged = FakeContentSubmissionStagedAssetRepository();
        final vm =
            buildViewModel(
                contentSubmissionRepository: repository,
                draftRepository: drafts,
                stagedAssetRepository: staged,
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        final identity = vm.state.clientSubmissionId;

        final submission = requestAndWait(
          vm.requestSubmit,
          () => vm.isSubmitting,
        );
        while (repository.submitCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.clearSnapshot.hasFailure, isTrue);
        expect(drafts.clearDraftCallCount, 0);
        expect(staged.clearedSessions, isEmpty);
        expect(vm.state.clientSubmissionId, identity);
        repository.completeSubmission(Result.error(Exception('submit failed')));
        await submission;

        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(repository.submittedClientSubmissionIds, [identity]);
        await requestAndWait(vm.requestClear, () => vm.isClearing);
        expect(vm.clearSnapshot.completed, isTrue);
        expect(drafts.clearDraftCallCount, 1);
        expect(staged.clearedSessions, [identity]);
      });

      test(
        'claims ownership before a clear queued behind preparation can run',
        () async {
          final pendingSave = Completer<Result<void>>();
          final repository = ControllableSubmissionRepository();
          final drafts = FakeContentSubmissionDraftRepository()
            ..pendingSaveDraft = pendingSave;
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm =
              buildViewModel(
                  contentSubmissionRepository: repository,
                  draftRepository: drafts,
                  stagedAssetRepository: staged,
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');
          final identity = vm.state.clientSubmissionId;

          final submission = requestAndWait(
            vm.requestSubmit,
            () => vm.isSubmitting,
          );
          while (drafts.saveDraftCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
          pendingSave.complete(const Result.success(null));
          await clear;

          expect(vm.clearSnapshot.hasFailure, isTrue);
          expect(drafts.clearDraftCallCount, 0);
          expect(staged.clearedSessions, isEmpty);
          expect(vm.state.clientSubmissionId, identity);
          while (repository.submitCallCount == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          repository.completeSubmission(
            Result.error(Exception('submit failed')),
          );
          await submission;
        },
      );

      test(
        'releases ownership when Cloudinary throws an Exception or Error',
        () async {
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (_) {};
          addTearDown(() => FlutterError.onError = originalOnError);

          for (final error in <Object>[
            Exception('unexpected exception'),
            StateError('unexpected error'),
          ]) {
            final repository = FakeContentSubmissionRepository(
              uploadImageTaskResult: FakeImageUploadTask.throwing(error),
            );
            final vm =
                buildViewModel(
                    contentSubmissionRepository: repository,
                    imagePicker: FakeImagePicker(
                      onPickMultipleMedia: () async => [
                        XFile.fromData(Uint8List.fromList([1]), name: 'a.jpg'),
                      ],
                    ),
                  )
                  ..setCity('Rome')
                  ..setName('Colosseum')
                  ..setUserEmail('jane@example.com')
                  ..setUserName('Jane');
            await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
            final identity = vm.state.clientSubmissionId;

            await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

            expect(vm.submitSnapshot.hasFailure, isTrue);
            expect(vm.state.clientSubmissionId, identity);
            await requestAndWait(vm.requestClear, () => vm.isClearing);
            expect(vm.clearSnapshot.completed, isTrue);
            expect(vm.state.clientSubmissionId, isNot(identity));
          }
        },
      );

      test('releases ownership when final submit throws an Object', () async {
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (_) {};
        addTearDown(() => FlutterError.onError = originalOnError);
        final repository = FakeContentSubmissionRepository(
          submitThrownError: Object(),
        );
        final drafts = FakeContentSubmissionDraftRepository();
        final vm =
            buildViewModel(
                contentSubmissionRepository: repository,
                draftRepository: drafts,
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        final state = vm.state;
        final identity = state.clientSubmissionId;

        await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

        expect(vm.submitSnapshot.hasFailure, isTrue);
        expect(vm.submissionFinalizationPending, isFalse);
        expect(repository.submitCallCount, 1);
        expect(vm.state, state);
        expect(vm.state.clientSubmissionId, identity);
        expect(vm.assets, isEmpty);
        expect(drafts.clearDraftCallCount, 0);

        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.clearSnapshot.completed, isTrue);
        expect(drafts.clearDraftCallCount, 1);
        expect(vm.state.clientSubmissionId, isNot(identity));
      });

      test('retires exactly the acknowledged session after rejecting a '
          'concurrent clear', () async {
        final pendingClear = Completer<Result<void>>();
        final repository = ControllableSubmissionRepository();
        final drafts = FakeContentSubmissionDraftRepository()
          ..pendingClearDraft = pendingClear;
        final staged = FakeContentSubmissionStagedAssetRepository();
        final vm =
            buildViewModel(
                contentSubmissionRepository: repository,
                draftRepository: drafts,
                stagedAssetRepository: staged,
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        final identity = vm.state.clientSubmissionId;

        final submission = requestAndWait(
          vm.requestSubmit,
          () => vm.isSubmitting,
        );
        while (repository.submitCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        await requestAndWait(vm.requestClear, () => vm.isClearing);
        expect(vm.clearSnapshot.hasFailure, isTrue);
        expect(drafts.clearDraftCallCount, 0);
        repository.completeSubmission(const Result.success(null));
        while (drafts.clearDraftCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(repository.submittedClientSubmissionIds, [identity]);
        expect(vm.state.clientSubmissionId, identity);
        pendingClear.complete(const Result.success(null));
        await submission;

        expect(vm.submitSnapshot.completed, isTrue);
        expect(drafts.clearDraftCallCount, 1);
        expect(staged.clearedSessions, [identity]);
        expect(vm.state.clientSubmissionId, isNot(identity));
      });

      test('retires same-session B after A is acknowledged without copying B '
          'into the fresh session', () async {
        final repository = ControllableSubmissionRepository();
        final drafts = FakeContentSubmissionDraftRepository();
        final staged = FakeContentSubmissionStagedAssetRepository();
        final vm =
            buildViewModel(
                contentSubmissionRepository: repository,
                draftRepository: drafts,
                stagedAssetRepository: staged,
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        final identity = vm.state.clientSubmissionId;

        final submission = requestAndWait(
          vm.requestSubmit,
          () => vm.isSubmitting,
        );
        while (repository.submitCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        vm
          ..setCity('Isernia')
          ..setName('Castello')
          ..setUserEmail('other@example.com')
          ..setUserName('Other');
        repository.completeSubmission(const Result.success(null));
        await submission;

        expect(repository.submittedClientSubmissionIds, [identity]);
        expect(repository.submittedContentSubmissions.single.city, 'Rome');
        expect(vm.submitSnapshot.completed, isTrue);
        expect(vm.state.clientSubmissionId, isNot(identity));
        expect(vm.state.city, isNull);
        expect(vm.state.name, isNull);
        expect(vm.state.userEmail, isNull);
        expect(vm.state.userName, isNull);
        expect(vm.hasUnsavedChanges, isFalse);
        expect(drafts.clearDraftCallCount, 1);
        expect(staged.clearedSessions, [identity]);
      });

      test(
        'uploads the staged copy after the picker source is deleted',
        () async {
          final temporaryDirectory = await Directory.systemTemp.createTemp(
            'content-submission-submit-source-test-',
          );
          addTearDown(() => temporaryDirectory.delete(recursive: true));
          final source = File('${temporaryDirectory.path}/picker-source.jpg');
          await source.writeAsBytes([4, 5, 6]);
          final stagedRepository = FakeContentSubmissionStagedAssetRepository(
            stagingDirectory: Directory('${temporaryDirectory.path}/staged'),
          );
          final submissionRepository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissionRepository,
                  stagedAssetRepository: stagedRepository,
                  imagePicker: FakeImagePicker(
                    onPickMultipleMedia: () async => [XFile(source.path)],
                  ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final stagedPath = vm.assets.single.file.path;
          expect(stagedPath, isNot(source.path));
          expect(stagedPath, startsWith('${temporaryDirectory.path}/staged/'));
          await source.delete();

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.completed, isTrue);
          expect(submissionRepository.uploadedImages.single.path, stagedPath);
          expect(
            await submissionRepository.uploadedImages.single.readAsBytes(),
            [4, 5, 6],
          );
        },
      );

      test(
        'keeps ordered staged sources across partial upload and final-submit '
        'retries',
        () async {
          final temporaryDirectory = await Directory.systemTemp.createTemp(
            'content-submission-retry-source-test-',
          );
          addTearDown(() => temporaryDirectory.delete(recursive: true));
          final firstBytes = <int>[7, 8, 9];
          final secondBytes = <int>[4, 5, 6];
          final firstSource = File(
            '${temporaryDirectory.path}/first-picker-source.jpg',
          )..writeAsBytesSync(firstBytes);
          final secondSource = File(
            '${temporaryDirectory.path}/second-picker-source.jpg',
          )..writeAsBytesSync(secondBytes);
          final submissionRepository = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('submission failed')),
            uploadImageTaskResults: [
              FakeImageUploadTask.completed(
                Result.error(Exception('first cloudinary failure')),
              ),
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(secureUrl: 'first', width: 1, height: 1),
                ),
              ),
              FakeImageUploadTask.completed(
                Result.error(Exception('cloudinary failed')),
              ),
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(secureUrl: 'first', width: 1, height: 1),
                ),
              ),
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(secureUrl: 'second', width: 1, height: 1),
                ),
              ),
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(secureUrl: 'first', width: 1, height: 1),
                ),
              ),
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(secureUrl: 'second', width: 1, height: 1),
                ),
              ),
            ],
          );
          final stagedRepository = FakeContentSubmissionStagedAssetRepository(
            stagingDirectory: Directory('${temporaryDirectory.path}/staged'),
          );
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissionRepository,
                  stagedAssetRepository: stagedRepository,
                  imagePicker: FakeImagePicker(
                    onPickMultipleMedia: () async => [
                      XFile(firstSource.path),
                      XFile(secondSource.path),
                    ],
                  ),
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane');

          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final submittedIdentity = vm.state.clientSubmissionId;
          final stagedPaths = vm.assets
              .map((asset) => asset.file.path)
              .toList();
          expect(stagedPaths, hasLength(2));
          expect(stagedRepository.acquired, hasLength(2));
          expect(
            stagedRepository.acquired.map((asset) => asset.clientSubmissionId),
            everyElement(vm.state.clientSubmissionId),
          );
          expect(
            stagedRepository.acquired.map((asset) => asset.digest),
            vm.assets.map((asset) => asset.digest),
          );
          await firstSource.delete();
          await secondSource.delete();

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(submissionRepository.submitCalled, isFalse);
          expect(vm.state.clientSubmissionId, submittedIdentity);
          expect(submissionRepository.uploadedImages.map((file) => file.path), [
            stagedPaths.first,
          ]);
          expect(
            await Future.wait(
              submissionRepository.uploadedImages.map(
                (file) => file.readAsBytes(),
              ),
            ),
            [firstBytes],
          );
          expect(vm.assets.map((asset) => asset.file.path), stagedPaths);
          expect(stagedRepository.clearedSessions, isEmpty);

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(submissionRepository.submitCalled, isFalse);
          expect(vm.state.clientSubmissionId, submittedIdentity);
          expect(vm.assets.map((asset) => asset.file.path), stagedPaths);
          expect(
            await Future.wait(
              stagedPaths.map((path) => File(path).readAsBytes()),
            ),
            [firstBytes, secondBytes],
          );
          expect(stagedRepository.clearedSessions, isEmpty);

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);
          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(submissionRepository.submitCalled, isTrue);
          expect(submissionRepository.submitCallCount, 1);
          expect(submissionRepository.submittedClientSubmissionIds, [
            submittedIdentity,
          ]);
          expect(vm.assets.map((asset) => asset.file.path), stagedPaths);
          expect(stagedRepository.clearedSessions, isEmpty);

          submissionRepository.submitResult = const Result.success(null);
          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.completed, isTrue);
          expect(submissionRepository.submitCallCount, 2);
          expect(submissionRepository.submittedClientSubmissionIds, [
            submittedIdentity,
            submittedIdentity,
          ]);
          expect(
            submissionRepository.submittedSubmissionAssets.last.map(
              (asset) => asset.secureUrl,
            ),
            ['first', 'second'],
          );
          expect(submissionRepository.uploadedImages.map((file) => file.path), [
            stagedPaths.first,
            ...stagedPaths,
            ...stagedPaths,
            ...stagedPaths,
          ]);
          expect(stagedRepository.clearedSessions, [submittedIdentity]);
        },
      );

      test(
        'retains description projections after a failed submission',
        () async {
          final submissionRepository = FakeContentSubmissionRepository(
            submitResult: Result.error(Exception('upload failed')),
          );
          final vm = buildViewModel(
            contentSubmissionRepository: submissionRepository,
          );
          const descriptionDelta = <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'Da ritentare\n'},
          ];

          vm
            ..setCity('Rome')
            ..setName('Colosseum')
            ..setDescription(
              description: 'Da ritentare',
              descriptionDelta: descriptionDelta,
            )
            ..setUserEmail('jane@example.com')
            ..setUserName('Jane');

          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.submitSnapshot.hasFailure, isTrue);
          expect(vm.state.description, 'Da ritentare');
          expect(vm.state.descriptionDelta, descriptionDelta);
        },
      );
    });

    group('setAcceptedTerms', () {
      test('stores the value on the state and emits it to listeners', () {
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepo)
          ..setAcceptedTerms(value: true);

        expect(vm.state.acceptedTerms, isTrue);
      });

      test('does not save accepted terms implicitly', () {
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepo)
          ..setAcceptedTerms(value: true);

        expect(draftRepo.saveDraftCalled, isFalse);
        expect(vm.hasUnsavedChanges, isTrue);
      });

      test('passing null resets the field to null', () {
        final vm = buildViewModel()..setAcceptedTerms(value: true);
        expect(vm.state.acceptedTerms, isTrue);

        vm.setAcceptedTerms(value: null);
        expect(vm.state.acceptedTerms, isNull);
      });
    });

    group('clear', () {
      test('retains the session until a pending clear succeeds', () async {
        final pendingClear = Completer<Result<void>>();
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final repository = FakeContentSubmissionDraftRepository()
          ..pendingClearDraft = pendingClear;
        final vm = buildViewModel(
          draftRepository: repository,
          imagePicker: FakeImagePicker(onPickMultipleMedia: () async => [file]),
        );
        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        vm.setCity('Rome');
        final oldIdentity = vm.state.clientSubmissionId;
        final oldAsset = vm.assets.single;

        final clear = requestAndWait(vm.requestClear, () => vm.isClearing);
        await Future<void>.delayed(Duration.zero);

        expect(vm.isClearing, isTrue);
        expect(vm.state.city, 'Rome');
        expect(vm.state.clientSubmissionId, oldIdentity);
        expect(vm.hasUnsavedChanges, isTrue);
        expect(vm.assets, [oldAsset]);

        pendingClear.complete(const Result.success(null));
        await clear;

        expect(vm.state.city, isNull);
        expect(vm.state.clientSubmissionId, isNot(oldIdentity));
        expect(vm.hasUnsavedChanges, isFalse);
        expect(vm.assets, isEmpty);
      });

      test('clears assets and form state on success', () async {
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final logger = MockLogger();
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(onPickMultipleMedia: () async => [file]),
          logger: logger,
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        vm.setCity('Campobasso');
        logger.reset();
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.assets, isEmpty);
        expect(vm.state.city, isNull);
        expect(vm.clearSnapshot.completed, isTrue);
        expect(vm.clearSnapshot.hasFailure, isFalse);
        expect(logger.calls, isEmpty);
      });

      test(
        'requires the first checkpoint after clear for the fresh identity',
        () async {
          final draftRepository = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(draftRepository: draftRepository);
          await requestAndWait(vm.requestClear, () => vm.isClearing);

          await vm.checkpointDraft();

          expect(draftRepository.saveDraftCallCount, 1);
        },
      );

      test(
        'clears a live event-time issue before a place submission',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(contentSubmissionRepository: submissionRepository)
                ..setStartCalendarDate(EventCalendarDate(2025, 3, 30))
                ..setStartClockTime(EventClockTime(1, 30))
                ..setStartClockTime(EventClockTime(2, 30));
          expect(vm.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);

          await requestAndWait(vm.requestClear, () => vm.isClearing);
          vm
            ..setCity('Rome')
            ..setName('Colosseum')
            ..setUserEmail('jane@example.com')
            ..setUserName('Jane');
          await requestAndWait(vm.requestSubmit, () => vm.isSubmitting);

          expect(vm.eventTimeIssue, isNull);
          expect(vm.submitSnapshot.completed, isTrue);
          expect(submissionRepository.submitCalled, isTrue);
        },
      );

      test('preserves in-memory state when draft clear fails', () async {
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final draftRepository = FakeContentSubmissionDraftRepository(
          clearDraftResult: Result.error(Exception('disk dead')),
        );
        final stagedRepository = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(onPickMultipleMedia: () async => [file]),
          draftRepository: draftRepository,
          stagedAssetRepository: stagedRepository,
        );

        await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
        vm.setCity('Campobasso');
        final identity = vm.state.clientSubmissionId;
        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.assets, hasLength(1));
        expect(vm.state.city, 'Campobasso');
        expect(vm.state.clientSubmissionId, identity);
        expect(vm.hasUnsavedChanges, isTrue);
        expect(draftRepository.clearDraftCalled, isTrue);
        expect(vm.clearSnapshot.completed, isFalse);
        expect(vm.clearSnapshot.hasFailure, isTrue);
        expect(stagedRepository.clearedSessions, isEmpty);
      });

      test(
        'rotates after staged cleanup failure following draft deletion',
        () async {
          final staged = FakeContentSubmissionStagedAssetRepository()
            ..clearSessionResult = Result.error(Exception('cleanup failed'));
          final vm = buildViewModel(
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
              ],
            ),
          );
          await requestAndWait(vm.requestAddAsset, () => vm.isAddingAsset);
          final oldIdentity = vm.state.clientSubmissionId;

          await requestAndWait(vm.requestClear, () => vm.isClearing);

          expect(vm.clearSnapshot.completed, isTrue);
          expect(vm.state.clientSubmissionId, isNot(oldIdentity));
          expect(vm.assets, isEmpty);
          expect(staged.clearedSessions, [oldIdentity]);
        },
      );

      test('surfaces a draft clear failure with one repository log', () async {
        final logger = MockLogger();
        final clearError = TestException('draft clear failed');
        final box = MockEntityBox<ContentSubmissionDraftEntity>();
        when(() => box.getAsync(1)).thenAnswer((_) async => null);
        when(() => box.removeAsync(1)).thenThrow(clearError);
        final drafts = ContentSubmissionDraftRepositoryImpl(
          logger: logger,
          objectBoxI: MockObjectBox(
            MockObjectBoxStore<ContentSubmissionDraftEntity>(box),
          ),
        );
        final vm = ContentSubmissionViewModel(
          logger: logger,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          draftRepository: drafts,
          stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
          imagePicker: FakeImagePicker(),
        );
        await vm.initialize();
        vm.setCity('Campobasso');
        final identity = vm.state.clientSubmissionId;
        logger.reset();

        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(vm.clearSnapshot.hasFailure, isTrue);
        expect(
          vm.clearSnapshot.data,
          isA<Error<void>>().having(
            (result) => result.error,
            'error',
            same(clearError),
          ),
        );
        expect(vm.state.city, 'Campobasso');
        expect(vm.state.clientSubmissionId, identity);
        expect(
          logger.eventsOfType<ContentSubmissionDraftClearFailed>(),
          hasLength(1),
        );
        expect(
          logger.calls.where((call) => call.event.level == AppLogLevel.error),
          hasLength(1),
        );
      });

      test('invokes clearDraft exactly once', () async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepository);

        await requestAndWait(vm.requestClear, () => vm.isClearing);

        expect(draftRepository.clearDraftCalled, isTrue);
      });
    });
  });
}
