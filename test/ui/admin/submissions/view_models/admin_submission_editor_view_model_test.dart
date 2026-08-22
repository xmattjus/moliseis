import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';

void main() {
  group('AdminSubmissionEditorViewModel', () {
    test('create mode starts with empty clean state', () {
      final viewModel = AdminSubmissionEditorViewModel(
        repository: FakeAdminContentSubmissionRepository(),
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
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load.execute();

      expect(viewModel.load.error, isTrue);
      expect(viewModel.hasLoadedDetail, isFalse);
    });

    test('does not save incomplete required fields', () async {
      final repository = FakeAdminContentSubmissionRepository();
      final viewModel = AdminSubmissionEditorViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      viewModel.setName('Museo');
      await viewModel.save.execute();

      expect(viewModel.save.error, isTrue);
      expect(repository.createInputs, isEmpty);

      final missingNameViewModel = AdminSubmissionEditorViewModel(
        repository: repository,
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
      final viewModel = AdminSubmissionEditorViewModel(repository: repository);
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
          submissionId: 1,
        );
        final rejected = AdminSubmissionEditorViewModel(
          repository: repository,
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
        submissionId: 1,
      );
      final rejected = AdminSubmissionEditorViewModel(
        repository: repository,
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
  });
}
