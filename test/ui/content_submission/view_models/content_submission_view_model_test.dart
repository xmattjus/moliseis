import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  ContentSubmissionViewModel buildViewModel({
    FakeImagePicker? imagePicker,
    FakeContentSubmissionRepository? contentSubmissionRepository,
    FakeContentSubmissionDraftRepository? draftRepository,
    MockLogger? logger,
  }) {
    final log = logger ?? MockLogger();
    return ContentSubmissionViewModel(
      logger: log,
      contentSubmissionRepository:
          contentSubmissionRepository ?? FakeContentSubmissionRepository(),
      draftRepository:
          draftRepository ?? FakeContentSubmissionDraftRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    );
  }

  group('ContentSubmissionViewModel', () {
    group('addAsset', () {
      test('adds a new file to assets', () async {
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
        );

        await vm.addAsset.execute();

        expect(vm.assets, hasLength(1));
        expect(vm.addAsset.completed, isTrue);
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
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [small, oversized],
            ),
          );

          await vm.addAsset.execute();

          expect(vm.assets, hasLength(1));
          expect(vm.assets.first.file.name, 'small.jpg');
          expect(vm.addAsset.completed, isTrue);
          expect(vm.addAsset.error, isFalse);

          final result = vm.addAsset.result! as Success<AssetSelectionOutcome>;
          expect(result.value.rejectedNames, ['big.jpg']);
          expect(result.value.hasRejections, isTrue);
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
          expect(result.value.hasRejections, isFalse);
          expect(result.value.rejectedNames, isEmpty);
        },
      );
    });

    group('removeAssetAt', () {
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
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(file: file),
          ),
        );

        await vm.retrieveLostAssets.execute();

        expect(vm.assets, hasLength(1));
        expect(vm.retrieveLostAssets.completed, isTrue);
      });

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
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async =>
                LostDataResponse(file: fileA, files: [fileA, fileB]),
          ),
        );

        await vm.retrieveLostAssets.execute();

        expect(vm.assets, hasLength(2));
        expect(vm.retrieveLostAssets.completed, isTrue);
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
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async =>
                  LostDataResponse(file: small, files: [small, oversized]),
            ),
          );

          await vm.retrieveLostAssets.execute();

          // Oversized file is dropped, the small one survives.
          expect(vm.assets, hasLength(1));
          expect(vm.assets.first.file.name, 'small.jpg');
          expect(vm.retrieveLostAssets.completed, isTrue);
          expect(vm.retrieveLostAssets.error, isFalse);
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
        final vm = buildViewModel();

        vm.setCategory(ContentCategory.history);
        vm.setCity('Rome');
        vm.setName('Colosseum');
        vm.setDescription('Ancient arena');
        vm.setUserEmail('jane@example.com');
        vm.setUserName('Jane');

        expect(vm.state.category, ContentCategory.history);
        expect(vm.state.city, 'Rome');
        expect(vm.state.name, 'Colosseum');
        expect(vm.state.description, 'Ancient arena');
        expect(vm.state.userEmail, 'jane@example.com');
        expect(vm.state.userName, 'Jane');
      });

      test('setting a field does not clear previously set date fields', () {
        final vm = buildViewModel();

        final start = DateTime.utc(2026, 7, 25);
        final end = DateTime.utc(2026, 7, 26);

        vm.setStartDate(start);
        vm.setEndDate(end);
        vm.setCity('Campobasso');

        expect(vm.state.startDate, start);
        expect(vm.state.endDate, end);
        expect(vm.state.city, 'Campobasso');
      });

      test(
        'setting date fields does not clear previously set text fields',
        () {
          final vm = buildViewModel();

          vm.setCity('Rome');
          vm.setName('Colosseum');
          vm.setDescription('Ancient arena');
          vm.setUserEmail('jane@example.com');
          vm.setUserName('Jane');

          final start = DateTime.utc(2026, 7, 25);
          final end = DateTime.utc(2026, 7, 26);

          vm.setStartDate(start);
          vm.setEndDate(end);

          expect(vm.state.startDate, start);
          expect(vm.state.endDate, end);
          expect(vm.state.city, 'Rome');
          expect(vm.state.name, 'Colosseum');
          expect(vm.state.description, 'Ancient arena');
          expect(vm.state.userEmail, 'jane@example.com');
          expect(vm.state.userName, 'Jane');
        },
      );

      test('clearing one field to null preserves other fields', () {
        final vm = buildViewModel();

        vm.setCategory(ContentCategory.history);
        vm.setCity('Rome');
        vm.setName('Colosseum');

        vm.setCategory(null);

        expect(vm.state.category, isNull);
        expect(vm.state.city, 'Rome');
        expect(vm.state.name, 'Colosseum');
      });

      // Regression guard: a previous change removed the only test that
      // asserted emit() schedules _debounced(). If someone deletes the
      // unawaited(_debounced()) line in _emit(), this test catches it:
      // three seconds after a setter fires, the draft repository must
      // have received a saveDraft call carrying the VM's current state.
      testWidgets(
        'schedules a debounced saveDraft 3s after each setter',
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

          vm.setCity('Campobasso');
          vm.setName('Test event');
          await tester.pump();

          // While the debounce window is open, the call has not landed yet.
          expect(draftRepo.saveDraftCalled, isFalse);

          // Crossing the 3s debounce window fires the timer scheduled by
          // _emit() -> unawaited(_debounced()).
          await tester.pump(const Duration(seconds: 3, milliseconds: 100));

          expect(draftRepo.saveDraftCalled, isTrue);
          expect(draftRepo.lastSavedState, vm.state);
        },
      );
    });

    group('submit', () {
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
          final vm = buildViewModel(
            contentSubmissionRepository: submissionRepository,
          );

          vm.setCity('Rome');
          vm.setName('Colosseum');
          vm.setUserEmail('jane@example.com');
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
        final vm = buildViewModel(
          contentSubmissionRepository: submissionRepository,
        );

        vm.setCity('Rome');
        vm.setName('Colosseum');
        vm.setUserEmail('jane@example.com');
        vm.setUserName('Jane');

        await vm.submit.execute();

        expect(vm.submit.completed, isTrue);
        expect(vm.submit.error, isFalse);
        expect(submissionRepository.uploadCalled, isTrue);
      });
    });

    group('setAcceptedTerms', () {
      test('stores the value on the state and emits it to listeners', () {
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(draftRepository: draftRepo);

        vm.setAcceptedTerms(true);

        expect(vm.state.acceptedTerms, isTrue);
      });

      testWidgets('schedules a debounced saveDraft carrying the new value', (
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

        vm.setAcceptedTerms(true);
        await tester.pump();
        expect(draftRepo.saveDraftCalled, isFalse);

        await tester.pump(const Duration(seconds: 3, milliseconds: 100));
        expect(draftRepo.saveDraftCalled, isTrue);
        expect(draftRepo.lastSavedState?.acceptedTerms, isTrue);
      });

      test('passing null resets the field to null', () {
        final vm = buildViewModel();

        vm.setAcceptedTerms(true);
        expect(vm.state.acceptedTerms, isTrue);

        vm.setAcceptedTerms(null);
        expect(vm.state.acceptedTerms, isNull);
      });
    });

    group('clear', () {
      test('clears assets and form state on success', () async {
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
        );

        await vm.addAsset.execute();
        vm.setCity('Campobasso');
        await vm.clear.execute();

        expect(vm.assets, isEmpty);
        expect(vm.state, const ContentSubmissionDraft());
        expect(vm.clear.completed, isTrue);
        expect(vm.clear.error, isFalse);
      });

      test('clears in-memory state even when draft clear fails', () async {
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final draftRepository = FakeContentSubmissionDraftRepository(
          clearDraftResult: Result.error(Exception('disk dead')),
        );
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
          draftRepository: draftRepository,
        );

        await vm.addAsset.execute();
        vm.setCity('Campobasso');
        await vm.clear.execute();

        expect(vm.assets, isEmpty);
        expect(vm.state, const ContentSubmissionDraft());
        expect(draftRepository.clearDraftCalled, isTrue);
        expect(vm.clear.completed, isTrue);
        expect(vm.clear.error, isFalse);
      });

      test(
        'logs StateClearStarted and StateClearSuccess regardless of draft '
        'outcome',
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
            logger.eventsOfType<ContentSubmissionStateClearSuccess>(),
            hasLength(1),
          );
        },
      );

      test(
        'does not emit StateClearFailed when only the draft clear fails',
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
            logger.containsEvent<ContentSubmissionStateClearFailed>(),
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
