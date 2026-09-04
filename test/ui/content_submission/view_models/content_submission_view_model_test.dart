import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/objectbox_test_store.dart';

void main() {
  ContentSubmissionViewModel buildViewModel({
    FakeImagePicker? imagePicker,
    FakeContentSubmissionRepository? contentSubmissionRepository,
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
    test(
      'shares one draft load and staged reconciliation '
      'across initialization callers',
      () async {
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
        await Future<void>.value();
        pendingReconcile.complete(const Result.success([]));
        await Future.wait([first, second]);

        expect(draftRepository.loadDraftCallCount, 1);
        expect(stagedRepository.reconcileCallCount, 1);
      },
    );

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
        await Future<void>.value();

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
        expect(
          vm.assets.map((asset) => asset.file.path),
          ['/staged/$identity/$secondDigest', '/staged/$identity/$firstDigest'],
        );
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

    test(
      'preserves unknown staged ownership and blocks asset addition after a '
      'draft-load failure',
      () async {
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
        final stagedSource = File(
          '${supportDirectory.path}/persisted-source.jpg',
        )..writeAsBytesSync(stagedBytes);
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
        await vm.addAsset.execute();

        expect(vm.state.clientSubmissionId, freshIdentity);
        expect(vm.assets, isEmpty);
        expect(vm.addAsset.error, isTrue);
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
        await vm.addAsset.execute();
        await vm.submit.execute();

        expect(vm.loadState, ContentSubmissionDraftLoadState.ready);
        expect(vm.assets, isEmpty);
        expect(vm.addAsset.error, isTrue);
        expect(vm.submit.error, isTrue);
        expect(pickerCalled, isFalse);
        expect(submissionRepository.uploadCalled, isFalse);
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
        await vm.addAsset.execute();
        await vm.submit.execute();

        expect(vm.assets, isEmpty);
        expect(pickerCalled, isFalse);
        expect(vm.submit.error, isTrue);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.uploadCalled, isFalse);
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
          stagedAssetRepository: ContentSubmissionStagedAssetRepositoryImpl(
            logger: logger,
            objectBoxI: objectBox,
            getSupportDirectory: () async => supportDirectory,
            beforeReconcile: () async =>
                throw const FileSystemException('reconciliation failed'),
          ),
          imagePicker: FakeImagePicker(),
        );

        await vm.submit.execute();

        expect(vm.submit.error, isTrue);
        expect(vm.assets, isEmpty);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.uploadCalled, isFalse);
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
          stagedAssetRepository: ContentSubmissionStagedAssetRepositoryImpl(
            logger: logger,
            objectBoxI: objectBox,
            getSupportDirectory: () async => supportDirectory,
            beforeResolve: (_) async =>
                throw const FileSystemException('path resolution failed'),
          ),
          imagePicker: FakeImagePicker(),
        );

        await vm.submit.execute();

        expect(vm.submit.error, isTrue);
        expect(vm.assets, isEmpty);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.uploadCalled, isFalse);
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
      'quarantines a post-acquisition resolution failure until reconciliation '
      'restores the committed asset',
      () async {
        final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
        final supportDirectory = await Directory.systemTemp.createTemp(
          'moliseis_content_submission_candidate_resolve_error_',
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
        var failNextResolution = true;
        final staged = ContentSubmissionStagedAssetRepositoryImpl(
          logger: logger,
          objectBoxI: objectBox,
          getSupportDirectory: () async => supportDirectory,
          beforeResolve: (_) async {
            if (failNextResolution) {
              failNextResolution = false;
              throw const FileSystemException('path resolution failed');
            }
          },
        );
        final source = File('${supportDirectory.path}/picker-source.jpg');
        final bytes = <int>[1, 2, 3];
        await source.writeAsBytes(bytes);
        final digest = sha1.convert(bytes).toString();
        var pickerCallCount = 0;
        final submissionRepository = FakeContentSubmissionRepository();
        final vm =
            ContentSubmissionViewModel(
                logger: logger,
                contentSubmissionRepository: submissionRepository,
                draftRepository: drafts,
                stagedAssetRepository: staged,
                imagePicker: FakeImagePicker(
                  onPickMultipleMedia: () async {
                    pickerCallCount++;
                    return pickerCallCount == 1 ? [XFile(source.path)] : [];
                  },
                ),
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane');
        addTearDown(vm.dispose);

        await vm.addAsset.execute();

        final identity = vm.state.clientSubmissionId;
        final stagedPath =
            '${supportDirectory.path}/content_submission/staged/$identity/'
            '$digest';
        expect(vm.addAsset.error, isTrue);
        expect(vm.assets, isEmpty);
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          1,
        );
        expect(File(stagedPath).existsSync(), isTrue);
        expect(
          (await staged.reconcileAndLoad(identity)).getOrNull(),
          hasLength(1),
        );

        await vm.submit.execute();

        expect(vm.submit.error, isTrue);
        expect(submissionRepository.uploadedImages, isEmpty);
        expect(submissionRepository.uploadCalled, isFalse);
        expect(File(stagedPath).existsSync(), isTrue);

        await vm.addAsset.execute();

        expect(vm.addAsset.completed, isTrue);
        expect(vm.assets, hasLength(1));
        expect(vm.assets.single.digest, digest);
        expect(vm.assets.single.file.path, stagedPath);

        await vm.submit.execute();

        expect(vm.submit.completed, isTrue);
        expect(submissionRepository.uploadedImages.single.path, stagedPath);
        expect(submissionRepository.uploadCalled, isTrue);
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
        await vm.addAsset.execute();

        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount),
        );
        expect(imagePicker.pickMultipleMediaLimits.single, 1);
        expect(staged.acquired, hasLength(1));
        expect(vm.addAsset.result, isA<Success<AssetSelectionOutcome>>());
        expect(
          (vm.addAsset.result! as Success<AssetSelectionOutcome>)
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

        final add = vm.addAsset.execute();
        await Future<void>.value();
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
        await Future<void>.value();
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
        final clear = vm.clear.execute();
        await Future<void>.value();
        expect(repository.clearDraftCallCount, 0);
        pendingLoad.complete(
          Result.success(
            ContentSubmissionDraft(clientSubmissionId: restoredId),
          ),
        );
        while (repository.clearDraftCallCount == 0) {
          await Future<void>.value();
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
          await Future<void>.value();
        }
        final add = vm.addAsset.execute();
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

        await vm.addAsset.execute();

        expect(vm.addAsset.error, isTrue);
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

      final add = vm.addAsset.execute();
      while (imagePicker.pickMultipleMediaLimits.isEmpty) {
        await Future<void>.value();
      }
      await vm.clear.execute();
      pendingPicker.complete([XFile(lateSource.path)]);
      await add;

      expect(vm.state.clientSubmissionId, isNot(oldIdentity));
      expect(vm.assets, isEmpty);
      expect(vm.addAsset.error, isFalse);
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

      final add = vm.addAsset.execute();
      while (stagedRepository.acquired.isEmpty) {
        await Future<void>.value();
      }
      final clear = vm.clear.execute();
      await Future<void>.value();
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
          await Future<void>.value();
        }
        final clear = vm.clear.execute();
        expect(drafts.clearDraftCallCount, 0);
        pendingSave.complete(const Result.success(null));
        while (drafts.clearDraftCallCount == 0) {
          await Future<void>.value();
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

        final clear = vm.clear.execute();
        while (drafts.clearDraftCallCount == 0) {
          await Future<void>.value();
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

        final add = vm.addAsset.execute();
        while (staged.acquired.isEmpty) {
          await Future<void>.value();
        }
        pendingAcquire.completeError(StateError('staging threw'));
        await add;
        await vm.clear.execute();

        expect(vm.addAsset.error, isTrue);
        expect(vm.clear.completed, isTrue);
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

        final add = vm.addAsset.execute();
        while (draftRepository.saveDraftCallCount == 0) {
          await Future<void>.value();
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

          await vm.addAsset.execute();

          expect(pickerCalled, isFalse);
          expect(stagedRepository.acquired, isEmpty);
          expect(vm.assets, isEmpty);
          expect(vm.addAsset.error, isTrue);
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

          await vm.addAsset.execute();

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
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
        );

        await vm.addAsset.execute();

        expect(vm.assets, hasLength(1));
        expect(vm.assets.single.file.path, isNot(source.path));
        expect(
          vm.assets.single.file.path.startsWith('${stagingDirectory.path}/'),
          isTrue,
        );
        expect(await File(vm.assets.single.file.path).readAsBytes(), [1, 2, 3]);
        expect(vm.addAsset.completed, isTrue);
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

        await vm.addAsset.execute();

        final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
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
        expect(
          picker.pickMultipleMediaLimits,
          [ContentSubmissionViewModel.maximumAssetCount],
        );
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

        await vm.addAsset.execute();

        final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
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
          picker.pickMultipleMediaLimits,
          [ContentSubmissionViewModel.maximumAssetCount],
        );
        expect(result.value.rejectedForLimitCount, 1);
        expect(result.value.hasOversizedRejections, isFalse);
        expect(result.value.hasAssetLimitRejections, isTrue);
        expect(result.value.hasRejections, isTrue);
        expect(vm.addAsset.completed, isTrue);
        expect(vm.addAsset.error, isFalse);
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

          await vm.addAsset.execute();
          await vm.addAsset.execute();

          final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
          expect(
            vm.assets,
            hasLength(ContentSubmissionViewModel.maximumAssetCount),
          );
          expect(
            vm.assets.map((asset) => asset.digest).toList(),
            [
              sha1.convert([0]).toString(),
              sha1.convert([1]).toString(),
              sha1.convert([2]).toString(),
              sha1.convert([3]).toString(),
              sha1.convert([4]).toString(),
            ],
          );
          expect(
            picker.pickMultipleMediaLimits,
            [ContentSubmissionViewModel.maximumAssetCount, 2],
          );
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

          await vm.addAsset.execute();
          await vm.addAsset.execute();

          final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
          expect(
            vm.assets,
            hasLength(ContentSubmissionViewModel.maximumAssetCount),
          );
          expect(
            picker.pickMultipleMediaLimits,
            [ContentSubmissionViewModel.maximumAssetCount],
          );
          expect(result.value.hasRejections, isFalse);
          expect(vm.addAsset.completed, isTrue);
          expect(vm.addAsset.error, isFalse);
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

        await vm.addAsset.execute();
        await vm.addAsset.execute();

        final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
        expect(vm.assets, hasLength(4));
        expect(
          vm.assets.map((asset) => asset.digest).toList(),
          [
            sha1.convert([1]).toString(),
            sha1.convert([2]).toString(),
            sha1.convert([3]).toString(),
            sha1.convert([4]).toString(),
          ],
        );
        expect(
          picker.pickMultipleMediaLimits,
          [ContentSubmissionViewModel.maximumAssetCount, 1],
        );
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

        await vm.addAsset.execute();

        final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
        expect(
          vm.assets,
          hasLength(ContentSubmissionViewModel.maximumAssetCount - 1),
        );
        expect(result.value.rejectedNames, ['oversized.jpg']);
        expect(result.value.rejectedForLimitCount, 1);
        expect(result.value.hasOversizedRejections, isTrue);
        expect(result.value.hasAssetLimitRejections, isTrue);
        expect(result.value.hasRejections, isTrue);
        expect(vm.addAsset.completed, isTrue);
        expect(vm.addAsset.error, isFalse);
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

          await vm.addAsset.execute();

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

        await vm.addAsset.execute();
        await vm.addAsset.execute(); // same content, second session

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

        await vm.addAsset.execute();
        await vm.addAsset.execute();

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

          await vm.addAsset.execute();

          expect(vm.assets, hasLength(1));
          expect(vm.assets.first.digest, sha1.convert([1, 2, 3]).toString());
          expect(vm.assets.first.file.path, startsWith('/staged/'));
          expect(vm.addAsset.completed, isTrue);
          expect(vm.addAsset.error, isFalse);

          final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
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
                XFile.fromData(
                  Uint8List.fromList([1, 2, 3]),
                  name: 'a.jpg',
                ),
              ],
            ),
          );

          await vm.addAsset.execute();

          final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
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
          await vm.addAsset.execute();
          final asset = vm.assets.single;

          await vm.removeAssetAt.execute(-1);

          expect(vm.removeAssetAt.error, isTrue);
          expect(
            (vm.removeAssetAt.result! as Error<void>).error.toString(),
            contains('RangeError'),
          );

          await vm.removeAssetAt.execute(1);

          expect(vm.removeAssetAt.error, isTrue);
          expect(
            (vm.removeAssetAt.result! as Error<void>).error.toString(),
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
            await Future<void>.value();
          }
          var removalCompleted = false;
          final removal = vm.removeAssetAt.execute(0).whenComplete(() {
            removalCompleted = true;
          });
          for (var i = 0; i < 5; i++) {
            await Future<void>.value();
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
          expect(vm.removeAssetAt.error, isTrue);
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

        await vm.addAsset.execute();
        await vm.addAsset.execute();
        final nameAtIndex1 = vm.assets[1].file.name;

        await vm.removeAssetAt.execute(0);

        expect(vm.assets, hasLength(1));
        expect(vm.assets.first.file.name, nameAtIndex1);
        expect(vm.removeAssetAt.completed, isTrue);
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

        await vm.addAsset.execute();
        expect(vm.assets, hasLength(1));

        await vm.removeAssetAt.execute(0);
        expect(vm.assets, isEmpty);

        // Same content must now be accepted because the digest was removed.
        await vm.addAsset.execute();
        expect(vm.assets, hasLength(1));
      });

      test(
        'persists the captured identity and digest before removing runtime '
        'asset',
        () async {
          final staged = FakeContentSubmissionStagedAssetRepository();
          final vm = buildViewModel(
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg'),
              ],
            ),
          );
          await vm.addAsset.execute();
          final identity = vm.state.clientSubmissionId;
          final digest = vm.assets.single.digest;

          await vm.removeAssetAt.execute(0);

          expect(staged.removed, [
            (clientSubmissionId: identity, digest: digest),
          ]);
          expect(vm.assets, isEmpty);
        },
      );

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
        await vm.addAsset.execute();
        final asset = vm.assets.single;

        await vm.removeAssetAt.execute(0);

        expect(vm.removeAssetAt.error, isTrue);
        expect(vm.assets, [asset]);
        expect(staged.removed, hasLength(1));
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
          await vm.addAsset.execute();
          final first = vm.assets.single;
          staged.pendingAcquire = pendingAcquire;

          final add = vm.addAsset.execute();
          while (staged.acquired.length < 2) {
            await Future<void>.value();
          }
          final remove = vm.removeAssetAt.execute(0);
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
          await vm.addAsset.execute();
          final oldIdentity = vm.state.clientSubmissionId;

          final clear = vm.clear.execute();
          while (drafts.clearDraftCallCount == 0) {
            await Future<void>.value();
          }
          final remove = vm.removeAssetAt.execute(0);
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

          final add = vm.addAsset.execute();
          while (imagePicker.pickMultipleMediaLimits.isEmpty) {
            await Future<void>.value();
          }
          notifications = 0;
          vm.dispose();
          pendingPicker.complete([
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'late.jpg'),
          ]);
          await add;

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

        final add = vm.addAsset.execute();
        while (stagedRepository.acquired.isEmpty) {
          await Future<void>.value();
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

        expect(vm.assets, isEmpty);
        expect(stagedRepository.acquired, hasLength(1));
        expect(notifications, 0);
      });

      test(
        'restores a real commit completed before disposal during resolution',
        () async {
          final objectBoxEnvironment = await TestObjectBoxEnvironment.create();
          final supportDirectory = await Directory.systemTemp.createTemp(
            'moliseis_content_submission_disposed_resolution_',
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
          final resolutionStarted = Completer<void>();
          final releaseResolution = Completer<void>();
          final staged = ContentSubmissionStagedAssetRepositoryImpl(
            logger: logger,
            objectBoxI: objectBox,
            getSupportDirectory: () async => supportDirectory,
            beforeResolve: (_) async {
              resolutionStarted.complete();
              await releaseResolution.future;
            },
          );
          final bytes = <int>[7, 8, 9];
          final digest = sha1.convert(bytes).toString();
          final source = File('${supportDirectory.path}/picker-source.jpg')
            ..writeAsBytesSync(bytes);
          final vm = ContentSubmissionViewModel(
            logger: logger,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            draftRepository: drafts,
            stagedAssetRepository: staged,
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [XFile(source.path)],
            ),
          );
          await vm.initialize();
          var notifications = 0;
          vm.addListener(() => notifications++);

          final add = vm.addAsset.execute();
          await resolutionStarted.future;
          final identity = vm.state.clientSubmissionId;
          final stagedPath =
              '${supportDirectory.path}/content_submission/staged/$identity/'
              '$digest';
          expect(
            objectBoxEnvironment.store
                .box<ContentSubmissionStagedAssetEntity>()
                .count(),
            1,
          );
          expect(File(stagedPath).existsSync(), isTrue);
          notifications = 0;
          vm.dispose();
          releaseResolution.complete();
          await add;

          expect(vm.assets, isEmpty);
          expect(notifications, 0);
          expect(File(stagedPath).existsSync(), isTrue);

          final restored = ContentSubmissionViewModel(
            logger: logger,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            draftRepository: drafts,
            stagedAssetRepository: ContentSubmissionStagedAssetRepositoryImpl(
              logger: logger,
              objectBoxI: objectBox,
              getSupportDirectory: () async => supportDirectory,
            ),
            imagePicker: FakeImagePicker(),
          );
          addTearDown(restored.dispose);

          await restored.initialize();

          expect(restored.state.clientSubmissionId, identity);
          expect(restored.assets, hasLength(1));
          expect(restored.assets.single.digest, digest);
          expect(restored.assets.single.file.path, stagedPath);
          expect(await File(stagedPath).readAsBytes(), bytes);
        },
      );

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
        await vm.addAsset.execute();
        stagedRepository.pendingRemove = pendingRemove;
        var notifications = 0;
        vm.addListener(() => notifications++);

        final removal = vm.removeAssetAt.execute(0);
        while (stagedRepository.removed.isEmpty) {
          await Future<void>.value();
        }
        vm.dispose();
        pendingRemove.complete(const Result.success(null));
        await removal;

        expect(vm.assets, hasLength(1));
        expect(stagedRepository.removed, hasLength(1));
        expect(notifications, 0);
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

        await vm.retrieveLostAssets.execute();

        expect(retrieveLostDataCalled, isFalse);
        expect(vm.assets, isEmpty);
        expect(vm.retrieveLostAssets.completed, isTrue);
        expect(vm.retrieveLostAssets.error, isFalse);
      });

      test('does not modify assets when response is empty', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse.empty(),
          ),
        );

        await vm.retrieveLostAssets.execute();

        expect(vm.assets, isEmpty);
        expect(vm.retrieveLostAssets.completed, isTrue);
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

        await vm.retrieveLostAssets.execute();

        expect(vm.assets, hasLength(1));
        expect(vm.retrieveLostAssets.completed, isTrue);
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
              ..pendingAcquire!.complete(
                Result.error(recoveryError),
              );
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

        await vm.retrieveLostAssets.execute();

        expect(vm.retrieveLostAssets.error, isFalse);
        expect(vm.assets.map((asset) => asset.digest), [restoredDigest]);
        expect(
          vm.assets.single.file.path,
          '/staged/$identity/$restoredDigest',
        );
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

        await vm.retrieveLostAssets.execute();

        expect(vm.assets, isEmpty);
        expect(stagedRepository.acquired, isEmpty);
      });

      test(
        'preserves existing staged state when Android recovery follows a '
        'draft-load failure',
        () async {
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
              loadDraftResult: Result.error(
                TestException('draft load failed'),
              ),
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

          await vm.retrieveLostAssets.execute();

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
        },
      );

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

          await vm.retrieveLostAssets.execute();

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
          final recovery = vm.retrieveLostAssets.execute();
          await Future<void>.value();
          expect(retrieveCalled, isTrue);
          expect(stagedRepository.acquired, isEmpty);

          pendingLoad.complete(
            Result.success(
              ContentSubmissionDraft(clientSubmissionId: identity),
            ),
          );
          await Future<void>.value();
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
                throw TestException('lost-data plugin failed'),
          ),
        );

        await vm.retrieveLostAssets.execute();

        expect(vm.retrieveLostAssets.error, isFalse);
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

          final clear = vm.clear.execute();
          while (draftRepository.clearDraftCallCount == 0) {
            await Future<void>.value();
          }
          final recovery = vm.retrieveLostAssets.execute();
          await Future<void>.value();
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

        await vm.retrieveLostAssets.execute();

        expect(vm.assets, hasLength(2));
        expect(vm.retrieveLostAssets.completed, isTrue);
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
            onRetrieveLostData: () async => LostDataResponse(
              files: [fileA, fileB],
            ),
          ),
        );

        await vm.retrieveLostAssets.execute();

        expect(vm.retrieveLostAssets.completed, isTrue);
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

        await vm.retrieveLostAssets.execute();

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
        expect(vm.retrieveLostAssets.completed, isTrue);
        expect(vm.retrieveLostAssets.error, isFalse);
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

          await vm.retrieveLostAssets.execute();

          // Oversized file is dropped, the small one survives.
          expect(vm.assets, hasLength(1));
          expect(vm.assets.first.file.path, startsWith('/staged/'));
          expect(vm.retrieveLostAssets.completed, isTrue);
          expect(vm.retrieveLostAssets.error, isFalse);
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

          await vm.retrieveLostAssets.execute();

          expect(
            vm.assets.map((asset) => asset.digest),
            [
              ...restored.map((asset) => asset.digest),
              sha1.convert(<int>[5]).toString(),
            ],
          );
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

          await vm.addAsset.execute();
          expect(vm.assets, hasLength(1));

          await vm.retrieveLostAssets.execute();
          expect(vm.assets, hasLength(1)); // no duplicate
        },
      );

      test(
        'returns success and clears error state when picker reports an '
        'exception',
        () async {
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

          await vm.retrieveLostAssets.execute();

          expect(vm.assets, isEmpty);
          expect(vm.retrieveLostAssets.error, isFalse);
          expect(vm.retrieveLostAssets.completed, isTrue);
        },
      );
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

      test(
        'setting date fields does not clear previously set text fields',
        () {
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
        },
      );

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

      testWidgets(
        'does not save after the former debounce interval',
        (tester) async {
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
        },
      );

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

      testWidgets(
        'persists and restores an enabled incomplete event draft',
        (tester) async {
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
            ..setEventEnabled(true)
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
        },
      );

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
          await Future<void>.value();
        }
        vm.setCity('Isernia');
        pendingSave.complete(const Result.success(null));

        expect(await checkpoint, isA<Success<void>>());
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

      test(
        'falls back from an unsupported legacy projection and checkpoints '
        'the fresh identity',
        () async {
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
        },
      );
    });

    group('submit', () {
      test(
        'blocks enabled incomplete events before any upload begins',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissionRepository,
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com')
                ..setUserName('Jane')
                ..setEventEnabled(true)
                ..setStartCalendarDate(EventCalendarDate(2026, 7, 25));

          await vm.submit.execute();

          expect(vm.submit.error, isTrue);
          expect(submissionRepository.uploadCalled, isFalse);
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
            buildViewModel(
                contentSubmissionRepository: submissionRepository,
              )
              ..setCity('Rome')
              ..setName('Colosseum')
              ..setUserEmail('jane@example.com')
              ..setUserName('Jane')
              ..setStartCalendarDate(EventCalendarDate(2025, 3, 30))
              ..setStartClockTime(EventClockTime(1, 30))
              ..setStartClockTime(EventClockTime(2, 30));

        await vm.submit.execute();

        expect(vm.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
        expect(submissionRepository.uploadCalled, isFalse);
        expect(submissionRepository.uploadedImages, isEmpty);
      });

      test(
        'fails without calling upload when all required fields are missing',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm = buildViewModel(
            contentSubmissionRepository: submissionRepository,
          );

          await vm.submit.execute();

          expect(vm.submit.completed, isFalse);
          expect(vm.submit.error, isTrue);
          expect(submissionRepository.uploadCalled, isFalse);

          final result = vm.submit.result;
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
              buildViewModel(
                  contentSubmissionRepository: submissionRepository,
                )
                ..setCity('Rome')
                ..setName('Colosseum')
                ..setUserEmail('jane@example.com');
          // userName intentionally left null

          await vm.submit.execute();

          expect(vm.submit.error, isTrue);
          expect(submissionRepository.uploadCalled, isFalse);

          final error = (vm.submit.result! as Error<void>).error;
          expect(error.toString(), contains('userName'));
          expect(error.toString(), isNot(contains('city')));
          expect(error.toString(), isNot(contains('name')));
          expect(error.toString(), isNot(contains('userEmail')));
        },
      );

      test('calls upload when all required fields are present', () async {
        final submissionRepository = FakeContentSubmissionRepository();
        final vm =
            buildViewModel(
                contentSubmissionRepository: submissionRepository,
              )
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

        await vm.submit.execute();

        expect(vm.submit.completed, isTrue);
        expect(vm.submit.error, isFalse);
        expect(submissionRepository.uploadCalled, isTrue);
        expect(
          submissionRepository.lastUploadedSubmission?.description,
          'Ancient arena',
        );
        expect(
          submissionRepository.lastUploadedSubmission?.descriptionDelta,
          descriptionDelta,
        );
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

          await vm.addAsset.execute();
          final stagedPath = vm.assets.single.file.path;
          expect(stagedPath, isNot(source.path));
          expect(stagedPath, startsWith('${temporaryDirectory.path}/staged/'));
          await source.delete();

          await vm.submit.execute();

          expect(vm.submit.completed, isTrue);
          expect(submissionRepository.uploadedImages.single.path, stagedPath);
          expect(
            await submissionRepository.uploadedImages.single.readAsBytes(),
            [
              4,
              5,
              6,
            ],
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
            uploadResult: Result.error(Exception('submission failed')),
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

          await vm.addAsset.execute();
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

          await vm.submit.execute();
          expect(vm.submit.error, isTrue);
          expect(submissionRepository.uploadCalled, isFalse);
          expect(
            submissionRepository.uploadedImages.map((file) => file.path),
            [stagedPaths.first],
          );
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

          await vm.submit.execute();
          expect(vm.submit.error, isTrue);
          expect(submissionRepository.uploadCalled, isFalse);
          expect(vm.assets.map((asset) => asset.file.path), stagedPaths);
          expect(
            await Future.wait(
              stagedPaths.map((path) => File(path).readAsBytes()),
            ),
            [firstBytes, secondBytes],
          );
          expect(stagedRepository.clearedSessions, isEmpty);

          await vm.submit.execute();
          expect(vm.submit.error, isTrue);
          expect(submissionRepository.uploadCalled, isTrue);
          expect(vm.assets.map((asset) => asset.file.path), stagedPaths);
          expect(stagedRepository.clearedSessions, isEmpty);

          submissionRepository.uploadResult = const Result.success(null);
          await vm.submit.execute();

          expect(vm.submit.completed, isTrue);
          expect(
            submissionRepository.uploadedImages.map((file) => file.path),
            [
              stagedPaths.first,
              ...stagedPaths,
              ...stagedPaths,
              ...stagedPaths,
            ],
          );
          expect(stagedRepository.clearedSessions, isEmpty);
        },
      );

      test(
        'retains description projections after a failed submission',
        () async {
          final submissionRepository = FakeContentSubmissionRepository(
            uploadResult: Result.error(Exception('upload failed')),
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

          await vm.submit.execute();

          expect(vm.submit.error, isTrue);
          expect(vm.state.description, 'Da ritentare');
          expect(vm.state.descriptionDelta, descriptionDelta);
        },
      );
    });

    group('setAcceptedTerms', () {
      test('stores the value on the state and emits it to listeners', () {
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepo)
          ..setAcceptedTerms(true);

        expect(vm.state.acceptedTerms, isTrue);
      });

      test('does not save accepted terms implicitly', () {
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepo)
          ..setAcceptedTerms(true);

        expect(draftRepo.saveDraftCalled, isFalse);
        expect(vm.hasUnsavedChanges, isTrue);
      });

      test('passing null resets the field to null', () {
        final vm = buildViewModel()..setAcceptedTerms(true);
        expect(vm.state.acceptedTerms, isTrue);

        vm.setAcceptedTerms(null);
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
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
        );
        await vm.addAsset.execute();
        vm.setCity('Rome');
        final oldIdentity = vm.state.clientSubmissionId;
        final oldAsset = vm.assets.single;

        final clear = vm.clear.execute();
        await Future<void>.delayed(Duration.zero);

        expect(vm.clear.running, isTrue);
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
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
          logger: logger,
        );

        await vm.addAsset.execute();
        vm.setCity('Campobasso');
        await vm.clear.execute();

        expect(vm.assets, isEmpty);
        expect(vm.state.city, isNull);
        expect(vm.clear.completed, isTrue);
        expect(vm.clear.error, isFalse);
        expect(
          logger.eventsOfType<ContentSubmissionStateClearStarted>(),
          hasLength(1),
        );
        expect(
          logger.eventsOfType<ContentSubmissionStateClearSuccess>(),
          hasLength(1),
        );
        expect(
          logger.eventsOfType<ContentSubmissionStateClearFailed>(),
          isEmpty,
        );
      });

      test(
        'requires the first checkpoint after clear for the fresh identity',
        () async {
          final draftRepository = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(draftRepository: draftRepository);
          await vm.clear.execute();

          await vm.checkpointDraft();

          expect(draftRepository.saveDraftCallCount, 1);
        },
      );

      test(
        'clears a live event-time issue before a place submission',
        () async {
          final submissionRepository = FakeContentSubmissionRepository();
          final vm =
              buildViewModel(
                  contentSubmissionRepository: submissionRepository,
                )
                ..setStartCalendarDate(EventCalendarDate(2025, 3, 30))
                ..setStartClockTime(EventClockTime(1, 30))
                ..setStartClockTime(EventClockTime(2, 30));
          expect(vm.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);

          await vm.clear.execute();
          vm
            ..setCity('Rome')
            ..setName('Colosseum')
            ..setUserEmail('jane@example.com')
            ..setUserName('Jane');
          await vm.submit.execute();

          expect(vm.eventTimeIssue, isNull);
          expect(vm.submit.completed, isTrue);
          expect(submissionRepository.uploadCalled, isTrue);
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
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
          draftRepository: draftRepository,
          stagedAssetRepository: stagedRepository,
        );

        await vm.addAsset.execute();
        vm.setCity('Campobasso');
        final identity = vm.state.clientSubmissionId;
        await vm.clear.execute();

        expect(vm.assets, hasLength(1));
        expect(vm.state.city, 'Campobasso');
        expect(vm.state.clientSubmissionId, identity);
        expect(vm.hasUnsavedChanges, isTrue);
        expect(draftRepository.clearDraftCalled, isTrue);
        expect(vm.clear.completed, isFalse);
        expect(vm.clear.error, isTrue);
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
          await vm.addAsset.execute();
          final oldIdentity = vm.state.clientSubmissionId;

          await vm.clear.execute();

          expect(vm.clear.completed, isTrue);
          expect(vm.state.clientSubmissionId, isNot(oldIdentity));
          expect(vm.assets, isEmpty);
          expect(staged.clearedSessions, [oldIdentity]);
        },
      );

      test(
        'logs StateClearStarted and StateClearFailed on draft clear failure',
        () async {
          final draftRepository = FakeContentSubmissionDraftRepository(
            clearDraftResult: Result.error(Exception('disk dead')),
          );
          final logger = MockLogger();
          final vm = buildViewModel(
            draftRepository: draftRepository,
            logger: logger,
          );

          await vm.clear.execute();

          expect(
            logger.eventsOfType<ContentSubmissionStateClearStarted>(),
            hasLength(1),
          );
          expect(
            logger.eventsOfType<ContentSubmissionStateClearFailed>(),
            hasLength(1),
          );
        },
      );

      test(
        'does not emit StateClearSuccess when the draft clear fails',
        () async {
          final draftRepository = FakeContentSubmissionDraftRepository(
            clearDraftResult: Result.error(Exception('disk dead')),
          );
          final logger = MockLogger();
          final vm = buildViewModel(
            draftRepository: draftRepository,
            logger: logger,
          );

          await vm.clear.execute();

          expect(
            logger.containsEvent<ContentSubmissionStateClearSuccess>(),
            isFalse,
          );
        },
      );

      test('invokes clearDraft exactly once', () async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepository);

        await vm.clear.execute();

        expect(draftRepository.clearDraftCalled, isTrue);
      });
    });
  });
}
