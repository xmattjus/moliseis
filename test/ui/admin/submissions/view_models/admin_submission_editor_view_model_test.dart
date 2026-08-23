import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_image_picker.dart';
import '../../../../support/fake_repositories.dart';

void main() {
  group('AdminSubmissionEditorViewModel', () {
    test('create mode starts with empty clean state', () {
      final viewModel = AdminSubmissionEditorViewModel(
        repository: FakeAdminContentSubmissionRepository(),
        contentSubmissionRepository: FakeContentSubmissionRepository(),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.city, isNull);
      expect(viewModel.name, isNull);
      expect(viewModel.status, isNull);
      expect(viewModel.isDirty, isFalse);
    });

    test(
      'loads editable and read-only state for an existing submission',
      () async {
        const asset = AdminSubmissionAsset(
          id: 2,
          url: 'https://example.com/photo.jpg',
          width: 640,
          height: 480,
        );
        final submission = sampleAdminSubmission(
          city: 'Isernia',
          name: 'Museo',
          description: 'Dettagli',
          descriptionDelta: <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'Dettagli\n'},
          ],
          startDate: DateTime.utc(2026, 8, 20, 10),
          endDate: DateTime.utc(2026, 8, 20, 12),
          userName: 'Anna Bianchi',
          userEmail: 'anna@example.com',
          status: AdminSubmissionStatus.accepted,
          assets: <AdminSubmissionAsset>[asset],
        );
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(submission),
          },
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();

        expect(viewModel.load.completed, isTrue);
        expect(repository.getByIdIds, <int>[1]);
        expect(viewModel.city, 'Isernia');
        expect(viewModel.name, 'Museo');
        expect(viewModel.description, 'Dettagli');
        expect(viewModel.isEvent, isTrue);
        expect(viewModel.contributorName, 'Anna Bianchi');
        expect(viewModel.contributorEmail, 'anna@example.com');
        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(viewModel.assets, <AdminSubmissionAsset>[asset]);
        expect(viewModel.hasLoadedDetail, isTrue);
        expect(viewModel.isDirty, isFalse);
      },
    );

    test('surfaces a missing edit detail as a load error', () async {
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.error(TestException('detail unavailable')),
        },
      );
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load.execute();

      expect(viewModel.load.error, isTrue);
      expect(viewModel.hasLoadedDetail, isFalse);
    });

    test('does not save incomplete required fields', () async {
      final repository = FakeAdminContentSubmissionRepository();
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
      );
      addTearDown(viewModel.dispose);

      viewModel.setName('Museo');
      await viewModel.save.execute();

      expect(viewModel.save.error, isTrue);
      expect(repository.createInputs, isEmpty);

      final missingNameViewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
      );
      addTearDown(missingNameViewModel.dispose);
      missingNameViewModel.setCity('Isernia');
      await missingNameViewModel.save.execute();

      expect(missingNameViewModel.save.error, isTrue);
      expect(repository.createInputs, isEmpty);
    });

    test(
      'creates with an unknown category when no category is selected',
      () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          creatorName: 'Redattore',
          creatorEmail: 'redattore@example.com',
        );
        addTearDown(viewModel.dispose);
        final startDate = DateTime.utc(2026, 8, 20, 10);
        final endDate = DateTime.utc(2026, 8, 20, 12);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo del Tartufo')
          ..setDescription(
            description: 'Descrizione',
            descriptionDelta: <Map<String, dynamic>>[
              <String, dynamic>{'insert': 'Descrizione\n'},
            ],
          )
          ..setStartDate(startDate)
          ..setEndDate(endDate);
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        expect(repository.createInputs, hasLength(1));
        final input = repository.createInputs.single;
        expect(input.category, ContentCategory.unknown);
        expect(input.city, 'Isernia');
        expect(input.name, 'Museo del Tartufo');
        expect(input.description, 'Descrizione');
        expect(input.descriptionDelta, <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Descrizione\n'},
        ]);
        expect(input.startDate, startDate);
        expect(input.endDate, endDate);
        expect(viewModel.isDirty, isFalse);
      },
    );

    test('updates an existing submission with the editor input', () async {
      final repository = FakeAdminContentSubmissionRepository();
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 3,
      );
      addTearDown(viewModel.dispose);

      viewModel
        ..setCategory(ContentCategory.nature)
        ..setCity('Termoli')
        ..setName('Spiaggia');
      await viewModel.save.execute();

      expect(viewModel.save.completed, isTrue);
      expect(repository.updateIds, <int>[3]);
      expect(repository.updateInputs.single.category, ContentCategory.nature);
      expect(repository.updateInputs.single.city, 'Termoli');
      expect(repository.updateInputs.single.name, 'Spiaggia');
    });

    test('keeps edits dirty when a save fails', () async {
      final repository = FakeAdminContentSubmissionRepository(
        createResult: Result.error(TestException('create failed')),
      );
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
      );
      addTearDown(viewModel.dispose);

      viewModel
        ..setCity('Isernia')
        ..setName('Museo');
      await viewModel.save.execute();

      expect(viewModel.save.error, isTrue);
      expect(viewModel.city, 'Isernia');
      expect(viewModel.name, 'Museo');
      expect(viewModel.isDirty, isTrue);
    });

    test('marks the editor dirty and notifies when fields change', () {
      final viewModel = AdminSubmissionEditorViewModel(
        repository: FakeAdminContentSubmissionRepository(),
        contentSubmissionRepository: FakeContentSubmissionRepository(),
      );
      addTearDown(viewModel.dispose);
      var notifications = 0;
      viewModel
        ..addListener(() => notifications++)
        ..setCategory(ContentCategory.food)
        ..setCity('Agnone')
        ..setName('Fonderia')
        ..setDescription(description: 'Dettagli', descriptionDelta: null)
        ..setStartDate(DateTime.utc(2026, 8, 20))
        ..setStartTime(DateTime.utc(2026, 8, 20, 9, 30))
        ..setEndDate(DateTime.utc(2026, 8, 20, 12));

      expect(viewModel.isDirty, isTrue);
      expect(notifications, 7);
    });

    test(
      'delegates both final statuses for a clean pending submission',
      () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());

        await viewModel.load.execute();

        await viewModel.changeStatus.execute(AdminSubmissionStatus.accepted);

        expect(viewModel.changeStatus.completed, isTrue);
        expect(
          repository.changeStatusCalls,
          <(int, AdminSubmissionStatus)>[
            (1, AdminSubmissionStatus.accepted),
          ],
        );
        expect(viewModel.status, AdminSubmissionStatus.accepted);

        final rejectedViewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 2,
        );
        addTearDown(rejectedViewModel.dispose);
        repository.getByIdResults[2] = Result.success(
          sampleAdminSubmission(id: 2),
        );
        await rejectedViewModel.load.execute();
        await rejectedViewModel.changeStatus.execute(
          AdminSubmissionStatus.rejected,
        );

        expect(rejectedViewModel.changeStatus.completed, isTrue);
        expect(
          repository.changeStatusCalls,
          <(int, AdminSubmissionStatus)>[
            (1, AdminSubmissionStatus.accepted),
            (2, AdminSubmissionStatus.rejected),
          ],
        );

        rejectedViewModel.setCity('Isernia');
        await rejectedViewModel.changeStatus.execute(
          AdminSubmissionStatus.accepted,
        );

        expect(rejectedViewModel.changeStatus.error, isTrue);
        expect(repository.changeStatusCalls, hasLength(2));
      },
    );

    test(
      'does not delegate status changes for accepted or rejected submissions',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(status: AdminSubmissionStatus.accepted),
            ),
            2: Result.success(
              sampleAdminSubmission(
                id: 2,
                status: AdminSubmissionStatus.rejected,
              ),
            ),
          },
        );
        final accepted = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        final rejected = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 2,
        );
        addTearDown(accepted.dispose);
        addTearDown(rejected.dispose);

        await accepted.load.execute();
        await rejected.load.execute();
        await accepted.changeStatus.execute(AdminSubmissionStatus.rejected);
        await rejected.changeStatus.execute(AdminSubmissionStatus.accepted);

        expect(accepted.changeStatus.error, isTrue);
        expect(rejected.changeStatus.error, isTrue);
        expect(repository.changeStatusCalls, isEmpty);
      },
    );

    test('saves accepted and rejected content', () async {
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(
            sampleAdminSubmission(status: AdminSubmissionStatus.accepted),
          ),
          2: Result.success(
            sampleAdminSubmission(
              id: 2,
              status: AdminSubmissionStatus.rejected,
            ),
          ),
        },
      );
      final accepted = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      final rejected = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 2,
      );
      addTearDown(accepted.dispose);
      addTearDown(rejected.dispose);

      await accepted.load.execute();
      await rejected.load.execute();
      accepted.setCity('Isernia');
      rejected.setCity('Termoli');
      await accepted.save.execute();
      await rejected.save.execute();

      expect(accepted.save.completed, isTrue);
      expect(rejected.save.completed, isTrue);
      expect(repository.updateIds, <int>[1, 2]);
    });

    test('blocks moderation while a save request is pending', () async {
      final pendingUpdate = Completer<Result<AdminSubmission>>();
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(sampleAdminSubmission()),
        },
      )..pendingUpdate = pendingUpdate;
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load.execute();
      viewModel.setCity('Isernia');

      final saving = viewModel.save.execute();
      expect(viewModel.save.running, isTrue);
      expect(repository.updateIds, <int>[1]);

      await viewModel.changeStatus.execute(AdminSubmissionStatus.accepted);

      expect(viewModel.changeStatus.error, isTrue);
      expect(repository.changeStatusCalls, isEmpty);
      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await saving;
    });

    test('blocks saving while a moderation request is pending', () async {
      final pendingChangeStatus = Completer<Result<void>>();
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(sampleAdminSubmission()),
        },
      )..pendingChangeStatus = pendingChangeStatus;
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load.execute();

      final changingStatus = viewModel.changeStatus.execute(
        AdminSubmissionStatus.accepted,
      );
      expect(viewModel.changeStatus.running, isTrue);
      expect(repository.changeStatusCalls, <(int, AdminSubmissionStatus)>[
        (1, AdminSubmissionStatus.accepted),
      ]);

      await viewModel.save.execute();

      expect(viewModel.save.error, isTrue);
      expect(repository.updateIds, isEmpty);
      pendingChangeStatus.complete(const Result.success(null));
      await changingStatus;
    });

    test(
      'adds a confirmed asset without reloading or changing unsaved edits',
      () async {
        const uploadedAsset = SubmissionAsset(
          secureUrl:
              'https://res.cloudinary.com/moliseis/image/upload/new-image.webp',
          width: 1600,
          height: 1200,
          mimeType: 'image/webp',
        );
        final confirmedAsset = AdminSubmissionAsset(
          id: 8,
          url: uploadedAsset.secureUrl,
          width: 1600,
          height: 1200,
        );
        final picker = FakeImagePicker(
          onPickImage: () async => XFile('/tmp/new-image.webp'),
        );
        final uploadRepository = FakeContentSubmissionRepository(
          uploadImageTaskResult: FakeImageUploadTask.completed(
            const Result.success(uploadedAsset),
          ),
        );
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(
                assets: const <AdminSubmissionAsset>[
                  AdminSubmissionAsset(
                    id: 2,
                    url: 'https://example.com/existing.jpg',
                    width: 640,
                    height: 480,
                  ),
                ],
              ),
            ),
          },
          addAssetResult: Result.success(confirmedAsset),
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: uploadRepository,
          imagePicker: picker,
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();
        viewModel.setCity('Termoli');

        await viewModel.addAsset.execute();

        expect(viewModel.addAsset.completed, isTrue);
        expect(picker.pickImageSources, <ImageSource>[ImageSource.gallery]);
        expect(
          uploadRepository.uploadedImages.single.path,
          '/tmp/new-image.webp',
        );
        expect(repository.addAssetCalls, <(int, SubmissionAsset)>[
          (1, uploadedAsset),
        ]);
        expect(viewModel.assets, <AdminSubmissionAsset>[
          const AdminSubmissionAsset(
            id: 2,
            url: 'https://example.com/existing.jpg',
            width: 640,
            height: 480,
          ),
          confirmedAsset,
        ]);
        expect(repository.getByIdIds, <int>[1]);
        expect(viewModel.city, 'Termoli');
        expect(viewModel.isDirty, isTrue);

        await viewModel.save.execute();

        expect(repository.updateInputs.single.city, 'Termoli');
      },
    );

    test('picker cancellation does not upload or persist an asset', () async {
      final picker = FakeImagePicker(onPickImage: () async => null);
      final uploadRepository = FakeContentSubmissionRepository();
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(sampleAdminSubmission()),
        },
      );
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: uploadRepository,
        imagePicker: picker,
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load.execute();

      await viewModel.addAsset.execute();

      expect(viewModel.addAsset.completed, isTrue);
      expect(picker.pickImageSources, <ImageSource>[ImageSource.gallery]);
      expect(uploadRepository.uploadedImages, isEmpty);
      expect(repository.addAssetCalls, isEmpty);
    });

    test('upload or backend add failure leaves local assets '
        'unchanged', () async {
      const initialAsset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/existing.jpg',
        width: 640,
        height: 480,
      );
      final uploadFailureRepository = FakeContentSubmissionRepository(
        uploadImageTaskResult: FakeImageUploadTask.completed(
          Result.error(TestException('upload failed')),
        ),
      );
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(
            sampleAdminSubmission(
              assets: const <AdminSubmissionAsset>[initialAsset],
            ),
          ),
        },
      );
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: uploadFailureRepository,
        imagePicker: FakeImagePicker(
          onPickImage: () async => XFile('/tmp/image.jpg'),
        ),
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load.execute();

      await viewModel.addAsset.execute();

      expect(viewModel.addAsset.error, isTrue);
      expect(repository.addAssetCalls, isEmpty);
      expect(viewModel.assets, const <AdminSubmissionAsset>[initialAsset]);

      final backendFailureViewModel = AdminSubmissionEditorViewModel(
        repository: repository
          ..addAssetResult = Result.error(TestException('persistence failed')),
        contentSubmissionRepository: FakeContentSubmissionRepository(
          uploadImageTaskResult: FakeImageUploadTask.completed(
            const Result.success(
              SubmissionAsset(
                secureUrl:
                    'https://res.cloudinary.com/moliseis/image/upload/image.jpg',
                width: 1200,
                height: 800,
              ),
            ),
          ),
        ),
        imagePicker: FakeImagePicker(
          onPickImage: () async => XFile('/tmp/image.jpg'),
        ),
        submissionId: 1,
      );
      addTearDown(backendFailureViewModel.dispose);
      await backendFailureViewModel.load.execute();

      await backendFailureViewModel.addAsset.execute();

      expect(backendFailureViewModel.addAsset.error, isTrue);
      expect(
        backendFailureViewModel.assets,
        const <AdminSubmissionAsset>[initialAsset],
      );
    });

    test('blocks adding at the limit and for final statuses', () async {
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(
            sampleAdminSubmission(
              assets: List<AdminSubmissionAsset>.generate(
                5,
                (index) => AdminSubmissionAsset(
                  id: index + 1,
                  url: 'https://example.com/$index.jpg',
                  width: 640,
                  height: 480,
                ),
              ),
            ),
          ),
          2: Result.success(
            sampleAdminSubmission(
              id: 2,
              status: AdminSubmissionStatus.accepted,
            ),
          ),
          3: Result.success(
            sampleAdminSubmission(
              id: 3,
              status: AdminSubmissionStatus.rejected,
            ),
          ),
        },
      );
      for (final id in <int>[1, 2, 3]) {
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          imagePicker: FakeImagePicker(
            onPickImage: () async => XFile('/tmp/image.jpg'),
          ),
          submissionId: id,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();

        await viewModel.addAsset.execute();

        expect(viewModel.addAsset.error, isTrue);
      }
      expect(repository.addAssetCalls, isEmpty);
    });

    test(
      'deletes only confirmed pending assets without uploading or reloading',
      () async {
        const asset = AdminSubmissionAsset(
          id: 2,
          url: 'https://example.com/existing.jpg',
          width: 640,
          height: 480,
        );
        final uploadRepository = FakeContentSubmissionRepository();
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(
                assets: const <AdminSubmissionAsset>[asset],
              ),
            ),
          },
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: uploadRepository,
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();
        viewModel.setName('Modifica non salvata');

        await viewModel.deleteAsset.execute(asset.id);

        expect(viewModel.deleteAsset.completed, isTrue);
        expect(repository.deleteAssetCalls, <(int, int)>[(1, 2)]);
        expect(viewModel.assets, isEmpty);
        expect(uploadRepository.uploadedImages, isEmpty);
        expect(repository.getByIdIds, <int>[1]);
        expect(viewModel.name, 'Modifica non salvata');
        expect(viewModel.isDirty, isTrue);
      },
    );

    test(
      'delete errors and final statuses leave local assets unchanged',
      () async {
        const asset = AdminSubmissionAsset(
          id: 2,
          url: 'https://example.com/existing.jpg',
          width: 640,
          height: 480,
        );
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(
                assets: const <AdminSubmissionAsset>[asset],
              ),
            ),
            2: Result.success(
              sampleAdminSubmission(
                id: 2,
                status: AdminSubmissionStatus.accepted,
                assets: const <AdminSubmissionAsset>[asset],
              ),
            ),
            3: Result.success(
              sampleAdminSubmission(
                id: 3,
                status: AdminSubmissionStatus.rejected,
                assets: const <AdminSubmissionAsset>[asset],
              ),
            ),
          },
          deleteAssetResult: Result.error(TestException('delete failed')),
        );
        for (final id in <int>[1, 2, 3]) {
          final viewModel = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            submissionId: id,
          );
          addTearDown(viewModel.dispose);
          await viewModel.load.execute();

          await viewModel.deleteAsset.execute(asset.id);

          expect(viewModel.deleteAsset.error, isTrue);
          expect(viewModel.assets, const <AdminSubmissionAsset>[asset]);
        }
        expect(repository.deleteAssetCalls, <(int, int)>[(1, 2)]);
      },
    );

    test(
      'mutual exclusion covers picker, upload, persistence, save, '
      'and moderation',
      () async {
        final pickerResult = Completer<XFile?>();
        final uploadTask = FakeImageUploadTask.pending();
        final pendingAdd = Completer<Result<AdminSubmissionAsset>>();
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(
                assets: const <AdminSubmissionAsset>[
                  AdminSubmissionAsset(
                    id: 2,
                    url: 'https://example.com/existing.jpg',
                    width: 640,
                    height: 480,
                  ),
                ],
              ),
            ),
          },
        )..pendingAddAsset = pendingAdd;
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(
            uploadImageTaskResult: uploadTask,
          ),
          imagePicker: FakeImagePicker(onPickImage: () => pickerResult.future),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();

        final adding = viewModel.addAsset.execute();
        expect(viewModel.operationRunning, isTrue);
        await viewModel.save.execute();
        await viewModel.changeStatus.execute(AdminSubmissionStatus.accepted);
        await viewModel.deleteAsset.execute(2);
        expect(viewModel.save.error, isTrue);
        expect(viewModel.changeStatus.error, isTrue);
        expect(viewModel.deleteAsset.error, isTrue);

        pickerResult.complete(XFile('/tmp/image.jpg'));
        await pumpEventQueue();
        expect(viewModel.addAsset.running, isTrue);
        uploadTask.complete(
          const Result.success(
            SubmissionAsset(
              secureUrl:
                  'https://res.cloudinary.com/moliseis/image/upload/image.jpg',
              width: 1200,
              height: 800,
            ),
          ),
        );
        await pumpEventQueue();
        expect(repository.addAssetCalls, hasLength(1));
        expect(viewModel.operationRunning, isTrue);
        await viewModel.save.execute();
        await viewModel.changeStatus.execute(AdminSubmissionStatus.accepted);
        await viewModel.deleteAsset.execute(2);
        expect(viewModel.save.error, isTrue);
        expect(viewModel.changeStatus.error, isTrue);
        expect(viewModel.deleteAsset.error, isTrue);

        pendingAdd.complete(
          const Result.success(
            AdminSubmissionAsset(
              id: 3,
              url: 'https://example.com/new.jpg',
              width: 1200,
              height: 800,
            ),
          ),
        );
        await adding;

        final pendingUpdate = Completer<Result<AdminSubmission>>();
        repository.pendingUpdate = pendingUpdate;
        final saving = viewModel.save.execute();
        await viewModel.addAsset.execute();
        await viewModel.deleteAsset.execute(2);
        expect(viewModel.addAsset.error, isTrue);
        expect(viewModel.deleteAsset.error, isTrue);
        pendingUpdate.complete(Result.success(sampleAdminSubmission()));
        await saving;

        final pendingStatus = Completer<Result<void>>();
        repository.pendingChangeStatus = pendingStatus;
        final changing = viewModel.changeStatus.execute(
          AdminSubmissionStatus.accepted,
        );
        await viewModel.addAsset.execute();
        await viewModel.deleteAsset.execute(2);
        expect(viewModel.addAsset.error, isTrue);
        expect(viewModel.deleteAsset.error, isTrue);
        pendingStatus.complete(const Result.success(null));
        await changing;
      },
    );

    test(
      'disposal cancels uploads and prevents later persistence or mutation',
      () async {
        final uploadTask = FakeImageUploadTask.pending();
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(sampleAdminSubmission()),
          },
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(
            uploadImageTaskResult: uploadTask,
          ),
          imagePicker: FakeImagePicker(
            onPickImage: () async => XFile('/tmp/image.jpg'),
          ),
          submissionId: 1,
        );
        await viewModel.load.execute();

        final adding = viewModel.addAsset.execute();
        await pumpEventQueue();
        viewModel.dispose();
        uploadTask.complete(
          const Result.success(
            SubmissionAsset(
              secureUrl:
                  'https://res.cloudinary.com/moliseis/image/upload/image.jpg',
              width: 1200,
              height: 800,
            ),
          ),
        );
        await adding;

        expect(uploadTask.cancelCallCount, 1);
        expect(repository.addAssetCalls, isEmpty);
        expect(viewModel.assets, isEmpty);
      },
    );

    test(
      'in-flight asset persistence cannot mutate state after disposal',
      () async {
        final pendingAdd = Completer<Result<AdminSubmissionAsset>>();
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(sampleAdminSubmission()),
          },
        )..pendingAddAsset = pendingAdd;
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(
            uploadImageTaskResult: FakeImageUploadTask.completed(
              const Result.success(
                SubmissionAsset(
                  secureUrl:
                      'https://res.cloudinary.com/moliseis/image/upload/image.jpg',
                  width: 1200,
                  height: 800,
                ),
              ),
            ),
          ),
          imagePicker: FakeImagePicker(
            onPickImage: () async => XFile('/tmp/image.jpg'),
          ),
          submissionId: 1,
        );
        await viewModel.load.execute();

        final adding = viewModel.addAsset.execute();
        await pumpEventQueue();
        expect(repository.addAssetCalls, hasLength(1));
        viewModel.dispose();
        pendingAdd.complete(
          const Result.success(
            AdminSubmissionAsset(
              id: 3,
              url: 'https://example.com/new.jpg',
              width: 1200,
              height: 800,
            ),
          ),
        );
        await adding;

        expect(viewModel.assets, isEmpty);
      },
    );
  });
}
