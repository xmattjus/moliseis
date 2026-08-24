import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
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
    AdminSubmissionEditorViewModel createViewModel({
      FakeAdminContentSubmissionRepository? repository,
      int? submissionId,
    }) {
      return AdminSubmissionEditorViewModel(
        repository: repository ?? FakeAdminContentSubmissionRepository(),
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: submissionId,
      );
    }

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
        expect(viewModel.startDate, DateTime.utc(2026, 8, 20, 10));
        expect(viewModel.startDate!.isUtc, isTrue);
        expect(viewModel.endDate, DateTime.utc(2026, 8, 20, 12));
        expect(viewModel.endDate!.isUtc, isTrue);
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
        viewModel
          ..setCity('Isernia')
          ..setName('Museo del Tartufo')
          ..setDescription(
            description: 'Descrizione',
            descriptionDelta: <Map<String, dynamic>>[
              <String, dynamic>{'insert': 'Descrizione\n'},
            ],
          );
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
        expect(input.startDate, isNull);
        expect(input.endDate, isNull);
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

    group('event date semantics', () {
      test('saving a start-only submission persists it unchanged', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);
        final startDate = DateTime.utc(2026, 8, 20, 10, 30);

        viewModel
          ..setCity('Isernia')
          ..setName('Sagra del Tartufo')
          ..setStartDate(startDate);
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        final input = repository.createInputs.single;
        expect(input.startDate, startDate);
        expect(input.endDate, isNull);
      });

      test(
        'an actively selected end date becomes end of day and saves',
        () async {
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = createViewModel(repository: repository);
          addTearDown(viewModel.dispose);

          viewModel
            ..setCity('Isernia')
            ..setName('Sagra del Tartufo')
            ..setStartDate(DateTime(2026, 8, 20, 15))
            // The date-only picker emits midnight for a same-day selection.
            ..setEndDate(DateTime(2026, 8, 20));

          expect(
            viewModel.endDate,
            DateTime(2026, 8, 20, 23, 59, 59, 999, 999),
          );
          expect(viewModel.endDate!.isUtc, isFalse);

          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(
            repository.createInputs.single.endDate,
            DateTime(2026, 8, 20, 23, 59, 59, 999, 999),
          );
        },
      );

      test('end-only submissions cannot be created', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Sagra del Tartufo')
          ..setEndDate(DateTime(2026, 8, 20));
        await viewModel.save.execute();

        expect(viewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);
        expect(viewModel.isDirty, isTrue);
      });

      test(
        'a normalized previous-day end still cannot precede the start',
        () async {
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = createViewModel(repository: repository);
          addTearDown(viewModel.dispose);

          viewModel
            ..setCity('Isernia')
            ..setName('Sagra del Tartufo')
            ..setStartDate(DateTime(2026, 8, 25, 15))
            ..setEndDate(DateTime(2026, 8, 24));

          expect(
            viewModel.endDate,
            DateTime(2026, 8, 24, 23, 59, 59, 999, 999),
          );

          await viewModel.save.execute();

          expect(viewModel.save.error, isTrue);
          expect(repository.createInputs, isEmpty);
          expect(viewModel.isDirty, isTrue);
        },
      );

      test(
        'a loaded end-only submission cannot update until repaired',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              3: Result.success(
                sampleAdminSubmission(
                  id: 3,
                  endDate: DateTime.utc(2026, 8, 20, 12),
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 3,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();
          viewModel.setName('Museo rinnovato');
          await viewModel.save.execute();

          expect(viewModel.save.error, isTrue);
          expect(repository.updateInputs, isEmpty);
          expect(viewModel.isDirty, isTrue);

          viewModel.setEndDate(null);
          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(viewModel.isDirty, isFalse);
          final input = repository.updateInputs.single;
          expect(input.name, 'Museo rinnovato');
          expect(input.startDate, isNull);
          expect(input.endDate, isNull);
        },
      );

      test(
        'an equal loaded pair round-trips untouched through an update',
        () async {
          final loadedDate = DateTime.utc(2026, 8, 20, 10, 30, 15, 123, 456);
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              5: Result.success(
                sampleAdminSubmission(
                  id: 5,
                  startDate: loadedDate,
                  endDate: loadedDate,
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 5,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();
          expect(viewModel.startDate, loadedDate);
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(viewModel.endDate, loadedDate);

          viewModel.setName('Museo rinnovato');
          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          final input = repository.updateInputs.single;
          expect(input.startDate, loadedDate);
          expect(input.startDate!.isUtc, isTrue);
          expect(input.endDate, loadedDate);
          expect(input.endDate!.isUtc, isTrue);
        },
      );

      test('moving the start date past the end moves the end to that day', () {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setStartDate(DateTime(2026, 8, 20))
          ..setEndDate(DateTime(2026, 8, 22))
          ..setStartDate(DateTime(2026, 8, 25));

        expect(viewModel.endDate, DateTime(2026, 8, 25, 23, 59, 59, 999, 999));
        expect(viewModel.endDate!.isUtc, isFalse);
      });

      test(
        'moving a loaded UTC start past its end produces a UTC end of day',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              7: Result.success(
                sampleAdminSubmission(
                  id: 7,
                  startDate: DateTime.utc(2026, 8, 20, 1),
                  endDate: DateTime.utc(2026, 8, 20, 2),
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 7,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();

          viewModel.setStartTime(DateTime.utc(2026, 8, 20, 5));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 20, 5));
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(
            viewModel.endDate,
            DateTime.utc(2026, 8, 20, 23, 59, 59, 999, 999),
          );
          expect(viewModel.endDate!.isUtc, isTrue);

          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          final input = repository.updateInputs.single;
          expect(input.startDate!.isUtc, isTrue);
          expect(
            input.endDate,
            DateTime.utc(2026, 8, 20, 23, 59, 59, 999, 999),
          );
          expect(input.endDate!.isUtc, isTrue);
        },
      );

      test(
        'a date-only edit of a loaded UTC start keeps its UTC clock',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              11: Result.success(
                sampleAdminSubmission(
                  id: 11,
                  startDate: DateTime.utc(2026, 8, 20, 10, 30, 15, 123, 456),
                  endDate: DateTime.utc(2026, 8, 22, 18),
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 11,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();

          // The picker emits a local-represented calendar day.
          viewModel.setStartDate(DateTime(2026, 8, 21));

          expect(
            viewModel.startDate,
            DateTime.utc(2026, 8, 21, 10, 30, 15, 123, 456),
          );
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(viewModel.endDate, DateTime.utc(2026, 8, 22, 18));
        },
      );

      test(
        'a date-only edit of a loaded local start keeps its local clock',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              12: Result.success(
                sampleAdminSubmission(
                  id: 12,
                  startDate: DateTime(2026, 8, 20, 9, 45),
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 12,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();

          viewModel.setStartDate(DateTime(2026, 8, 25));

          expect(viewModel.startDate, DateTime(2026, 8, 25, 9, 45));
          expect(viewModel.startDate!.isUtc, isFalse);
        },
      );

      test(
        'repairing an overtaken end after a date-only edit stays UTC',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              13: Result.success(
                sampleAdminSubmission(
                  id: 13,
                  startDate: DateTime.utc(2026, 8, 20, 22),
                  endDate: DateTime.utc(2026, 8, 20, 23),
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 13,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();

          viewModel.setStartDate(DateTime(2026, 8, 21));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 21, 22));
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(
            viewModel.endDate,
            DateTime.utc(2026, 8, 21, 23, 59, 59, 999, 999),
          );
          expect(viewModel.endDate!.isUtc, isTrue);
        },
      );

      test(
        'a date-only edit round-trips without shifting the instant',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              14: Result.success(
                sampleAdminSubmission(
                  id: 14,
                  startDate: DateTime.utc(2026, 8, 20, 10),
                  endDate: DateTime.utc(2026, 8, 22, 18),
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 14,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();
          viewModel
            ..setStartDate(DateTime(2026, 8, 21))
            ..setName('Sagra spostata');
          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          final wire = adminSubmissionInputToWireMap(
            repository.updateInputs.single,
          );
          // Only the calendar day changed: the stored instant keeps its 10:00Z
          // clock instead of being shifted by the local UTC offset.
          expect(wire['start_date'], '2026-08-21T10:00:00.000Z');
          expect(wire['end_date'], '2026-08-22T18:00:00.000Z');
        },
      );

      test('an automatic end repair still notifies exactly once', () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            9: Result.success(
              sampleAdminSubmission(
                id: 9,
                startDate: DateTime(2026, 8, 20, 1),
                endDate: DateTime(2026, 8, 20, 2),
              ),
            ),
          },
        );
        final viewModel = createViewModel(
          repository: repository,
          submissionId: 9,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();
        var notifications = 0;
        viewModel
          ..addListener(() => notifications++)
          ..setStartTime(DateTime(2026, 8, 20, 5));

        expect(notifications, 1);
        expect(viewModel.endDate, DateTime(2026, 8, 20, 23, 59, 59, 999, 999));
        expect(viewModel.endDate!.isUtc, isFalse);
      });
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

    group('coordinate draft semantics', () {
      test('create mode starts with an empty coordinate draft', () {
        final viewModel = createViewModel();
        addTearDown(viewModel.dispose);

        expect(viewModel.latitudeText, '');
        expect(viewModel.longitudeText, '');
        expect(viewModel.isDirty, isFalse);
      });

      test(
        'edit load hydrates existing coordinates without marking dirty',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              1: Result.success(
                sampleAdminSubmission(
                  latitude: 41.5575078,
                  longitude: 14.6485406,
                ),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 1,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();

          expect(viewModel.latitudeText, '41.5575078');
          expect(viewModel.longitudeText, '14.6485406');
          expect(viewModel.isDirty, isFalse);
        },
      );

      test('load with null coordinates stays empty', () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(sampleAdminSubmission()),
          },
        );
        final viewModel = createViewModel(
          repository: repository,
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();

        expect(viewModel.latitudeText, '');
        expect(viewModel.longitudeText, '');
        expect(viewModel.isDirty, isFalse);
      });

      test('manual latitude and longitude edits each mark dirty', () {
        final viewModel = createViewModel();
        addTearDown(viewModel.dispose);
        var notifications = 0;

        viewModel
          ..addListener(() => notifications++)
          ..setLatitudeText('41.5');
        expect(viewModel.isDirty, isTrue);
        expect(notifications, 1);

        viewModel.setLongitudeText('14.6');
        expect(viewModel.isDirty, isTrue);
        expect(notifications, 2);
      });

      test('map setCoordinates updates both values in one logical change', () {
        final viewModel = createViewModel();
        addTearDown(viewModel.dispose);
        var notifications = 0;

        viewModel
          ..addListener(() => notifications++)
          ..setCoordinates(41.123456789, 14.987654321);

        expect(viewModel.latitudeText, '41.123457');
        expect(viewModel.longitudeText, '14.987654');
        expect(viewModel.isDirty, isTrue);
        expect(notifications, 1);
      });

      test('both-empty coordinates save as null and null', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo');
        expect(viewModel.isDirty, isTrue);
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        expect(repository.createInputs.single.latitude, isNull);
        expect(repository.createInputs.single.longitude, isNull);
      });

      test('a valid manual pair saves as doubles', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('41.5575078')
          ..setLongitudeText('14.6485406');
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        expect(repository.createInputs.single.latitude, 41.5575078);
        expect(repository.createInputs.single.longitude, 14.6485406);
      });

      test('only one coordinate blocks persistence', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('41.55');
        await viewModel.save.execute();

        expect(viewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);

        viewModel
          ..setLatitudeText('')
          ..setLongitudeText('14.64');
        await viewModel.save.execute();

        expect(viewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);
      });

      test('unparsable coordinates block persistence', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('not-a-number')
          ..setLongitudeText('14.64');
        await viewModel.save.execute();

        expect(viewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);
      });

      test('out-of-range coordinates block persistence', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final latitudeViewModel = createViewModel(repository: repository);
        addTearDown(latitudeViewModel.dispose);
        latitudeViewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('90.000001')
          ..setLongitudeText('0');
        await latitudeViewModel.save.execute();
        expect(latitudeViewModel.save.error, isTrue);

        latitudeViewModel
          ..setLatitudeText('-91')
          ..setLongitudeText('');
        await latitudeViewModel.save.execute();
        expect(latitudeViewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);

        final longitudeViewModel = createViewModel(repository: repository);
        addTearDown(longitudeViewModel.dispose);
        longitudeViewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('0')
          ..setLongitudeText('180.000001');
        await longitudeViewModel.save.execute();
        expect(longitudeViewModel.save.error, isTrue);

        longitudeViewModel.setLongitudeText('-180.5');
        await longitudeViewModel.save.execute();
        expect(longitudeViewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);
      });

      test('coordinates at exact legal boundaries save', () async {
        for (final (latitude, longitude) in const [
          (-90.0, -180.0),
          (90.0, 180.0),
        ]) {
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = createViewModel(repository: repository);
          addTearDown(viewModel.dispose);
          viewModel
            ..setCity('Isernia')
            ..setName('Museo')
            ..setLatitudeText(latitude.toString())
            ..setLongitudeText(longitude.toString());
          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(repository.createInputs.single.latitude, latitude);
          expect(repository.createInputs.single.longitude, longitude);
        }
      });

      test('a location edit keeps moderation blocked while dirty', () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(sampleAdminSubmission()),
          },
        );
        final viewModel = createViewModel(
          repository: repository,
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();
        viewModel.setLatitudeText('41');

        await viewModel.changeStatus.execute(AdminSubmissionStatus.accepted);

        expect(viewModel.changeStatus.error, isTrue);
        expect(repository.changeStatusCalls, isEmpty);
      });

      test('successful save clears dirty exactly like other fields', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setCoordinates(41.5, 14.6);
        expect(viewModel.isDirty, isTrue);

        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        expect(viewModel.isDirty, isFalse);
      });

      test(
        'loaded coordinates survive unrelated field edits and Save',
        () async {
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 3,
          );
          addTearDown(viewModel.dispose);
          repository.getByIdResults[3] = Result.success(
            sampleAdminSubmission(id: 3, latitude: 41.9, longitude: 14.9),
          );
          await viewModel.load.execute();

          viewModel.setName('Nuovo nome');
          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(repository.updateIds, <int>[3]);
          expect(repository.updateInputs.single.latitude, 41.9);
          expect(repository.updateInputs.single.longitude, 14.9);
        },
      );

      test(
        'map-selected coordinates survive unrelated field edits and Save',
        () async {
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = createViewModel(repository: repository);
          addTearDown(viewModel.dispose);

          viewModel
            ..setCity('Isernia')
            ..setName('Museo')
            ..setCoordinates(41.123456789, 14.987654321)
            ..setDescription(description: 'Testo', descriptionDelta: null);
          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(repository.createInputs.single.latitude, 41.123457);
          expect(repository.createInputs.single.longitude, 14.987654);
        },
      );

      test('loaded high-precision coordinates persist bit-exact', () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(
                latitude: 41.5575078123,
                longitude: 14.6485406789,
              ),
            ),
          },
        );
        final viewModel = createViewModel(
          repository: repository,
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();

        viewModel.setName('Solo nome');
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        expect(repository.updateInputs.single.latitude, 41.5575078123);
        expect(repository.updateInputs.single.longitude, 14.6485406789);
      });

      test(
        'legacy half-pair row hydrates asymmetrically and blocks save',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              1: Result.success(sampleAdminSubmission(latitude: 41.5)),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 1,
          );
          addTearDown(viewModel.dispose);
          await viewModel.load.execute();

          expect(viewModel.latitudeText, '41.5');
          expect(viewModel.longitudeText, '');
          expect(viewModel.isDirty, isFalse);

          await viewModel.save.execute();

          expect(viewModel.save.error, isTrue);
          expect(repository.updateIds, isEmpty);
        },
      );

      test('single decimal comma parses and saves', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('41,55')
          ..setLongitudeText('14,62');
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        expect(repository.createInputs.single.latitude, 41.55);
        expect(repository.createInputs.single.longitude, 14.62);
      });

      test('multiple commas block persistence', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        viewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('41,55,5')
          ..setLongitudeText('14,62');
        await viewModel.save.execute();

        expect(viewModel.save.error, isTrue);
        expect(repository.createInputs, isEmpty);
      });
    });
  });
}
