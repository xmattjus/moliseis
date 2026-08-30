import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
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
        expect(viewModel.authoritativeEditableStateRevision, 0);

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
        expect(viewModel.authoritativeEditableStateRevision, 1);
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
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          3: Result.success(sampleAdminSubmission(id: 3)),
        },
      );
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 3,
      );
      addTearDown(viewModel.dispose);

      // Editorial updates are pending-only, so the detail must load first.
      await viewModel.load.execute();
      expect(viewModel.isEditable, isTrue);

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
        ..setStartCalendarDate(EventCalendarDate(2026, 8, 20))
        ..setStartClockTime(EventClockTime(9, 30))
        ..setEndCalendarDate(EventCalendarDate(2026, 8, 20));

      expect(viewModel.isDirty, isTrue);
      expect(notifications, 7);
    });

    group('event date semantics', () {
      test('saving a start-only submission persists it unchanged', () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = createViewModel(repository: repository);
        addTearDown(viewModel.dispose);
        viewModel
          ..setCity('Isernia')
          ..setName('Sagra del Tartufo')
          ..setStartCalendarDate(EventCalendarDate(2026, 8, 20))
          ..setStartClockTime(EventClockTime(10, 30));
        await viewModel.save.execute();

        expect(viewModel.save.completed, isTrue);
        final input = repository.createInputs.single;
        expect(input.startDate, DateTime.utc(2026, 8, 20, 8, 30));
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
            ..setStartCalendarDate(EventCalendarDate(2026, 8, 20))
            ..setStartClockTime(EventClockTime(15, 0))
            // The date-only picker emits midnight for a same-day selection.
            ..setEndCalendarDate(EventCalendarDate(2026, 8, 20));

          expect(
            viewModel.endDate,
            DateTime.utc(2026, 8, 20, 21, 59, 59, 999, 999),
          );
          expect(viewModel.endDate!.isUtc, isTrue);

          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(
            repository.createInputs.single.endDate,
            DateTime.utc(2026, 8, 20, 21, 59, 59, 999, 999),
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
          ..setEndCalendarDate(EventCalendarDate(2026, 8, 20));
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
            ..setStartCalendarDate(EventCalendarDate(2026, 8, 25))
            ..setStartClockTime(EventClockTime(15, 0))
            ..setEndCalendarDate(EventCalendarDate(2026, 8, 24));

          expect(viewModel.endDate, isNull);
          expect(viewModel.eventTimeIssue, EventTimeIssue.invalidRange);

          await viewModel.save.execute();

          expect(viewModel.save.error, isTrue);
          expect(repository.createInputs, isEmpty);
          expect(viewModel.isDirty, isTrue);
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
          ..setStartCalendarDate(EventCalendarDate(2026, 8, 20))
          ..setStartClockTime(EventClockTime(0, 0))
          ..setEndCalendarDate(EventCalendarDate(2026, 8, 22))
          ..setStartCalendarDate(EventCalendarDate(2026, 8, 25));

        expect(
          viewModel.endDate,
          DateTime.utc(2026, 8, 25, 21, 59, 59, 999, 999),
        );
        expect(viewModel.endDate!.isUtc, isTrue);
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

          viewModel.setStartClockTime(EventClockTime(5, 0));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 20, 3));
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(
            viewModel.endDate,
            DateTime.utc(2026, 8, 20, 21, 59, 59, 999, 999),
          );
          expect(viewModel.endDate!.isUtc, isTrue);

          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          final input = repository.updateInputs.single;
          expect(input.startDate!.isUtc, isTrue);
          expect(
            input.endDate,
            DateTime.utc(2026, 8, 20, 21, 59, 59, 999, 999),
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
          viewModel.setStartCalendarDate(EventCalendarDate(2026, 8, 21));

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

          viewModel.setStartCalendarDate(EventCalendarDate(2026, 8, 25));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 25, 7, 45));
          expect(viewModel.startDate!.isUtc, isTrue);
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

          viewModel.setStartCalendarDate(EventCalendarDate(2026, 8, 21));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 20, 22));
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(
            viewModel.endDate,
            DateTime.utc(2026, 8, 20, 23),
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
            ..setStartCalendarDate(EventCalendarDate(2026, 8, 21))
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
          ..setStartClockTime(EventClockTime(5, 0));

        expect(notifications, 1);
        expect(
          viewModel.endDate,
          DateTime.utc(2026, 8, 20, 21, 59, 59, 999, 999),
        );
        expect(viewModel.endDate!.isUtc, isTrue);
      });
    });

    group('Rome event-time policy', () {
      test(
        'date edit across the CET/CEST transition preserves Rome precision',
        () async {
          final loaded = DateTime.utc(2026, 3, 28, 9, 30, 15, 123, 456);
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              31: Result.success(
                sampleAdminSubmission(id: 31, startDate: loaded),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 31,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();
          viewModel.setStartCalendarDate(EventCalendarDate(2026, 4, 1));

          expect(
            viewModel.startDate,
            DateTime.utc(2026, 4, 1, 8, 30, 15, 123, 456),
          );
        },
      );

      test(
        'time edit preserves Rome date and existing sub-minute precision',
        () async {
          final loaded = DateTime.utc(2026, 8, 20, 8, 30, 15, 123, 456);
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              32: Result.success(
                sampleAdminSubmission(id: 32, startDate: loaded),
              ),
            },
          );
          final viewModel = createViewModel(
            repository: repository,
            submissionId: 32,
          );
          addTearDown(viewModel.dispose);

          await viewModel.load.execute();
          viewModel.setStartClockTime(EventClockTime(14, 45));

          expect(
            viewModel.startDate,
            DateTime.utc(2026, 8, 20, 12, 45, 15, 123, 456),
          );
        },
      );

      test(
        'enabled incomplete event and live DST issue block repository writes',
        () async {
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = createViewModel(repository: repository);
          addTearDown(viewModel.dispose);
          viewModel
            ..setCity('Isernia')
            ..setName('Sagra')
            ..setEventEnabled(true)
            ..setStartCalendarDate(EventCalendarDate(2026, 3, 29));

          await viewModel.save.execute();
          expect(viewModel.save.error, isTrue);
          expect(repository.createInputs, isEmpty);

          viewModel
            ..setStartClockTime(EventClockTime(1, 30))
            ..setStartClockTime(EventClockTime(2, 30));
          final prior = viewModel.startDate;
          expect(viewModel.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
          expect(viewModel.startDate, prior);

          await viewModel.save.execute();
          expect(repository.createInputs, isEmpty);
        },
      );

      test(
        'DST overlap marks dirty once and a valid edit clears its issue',
        () {
          final viewModel = createViewModel();
          addTearDown(viewModel.dispose);
          viewModel
            ..setStartCalendarDate(EventCalendarDate(2026, 10, 25))
            ..setStartClockTime(EventClockTime(1, 30));
          final prior = viewModel.startDate;
          var notifications = 0;
          viewModel
            ..addListener(() => notifications++)
            ..setStartClockTime(EventClockTime(2, 30));
          expect(viewModel.startDate, prior);
          expect(viewModel.eventTimeIssue, EventTimeIssue.ambiguousLocalTime);
          expect(viewModel.isDirty, isTrue);
          expect(notifications, 1);

          viewModel.setStartClockTime(EventClockTime(3, 30));
          expect(viewModel.eventTimeIssue, isNull);
        },
      );
    });

    group('moderation hydration and editability', () {
      test('hydrates a null promotion for a pending submission', () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(sampleAdminSubmission()),
          },
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();

        expect(viewModel.promotion, isNull);
        expect(viewModel.isEditable, isTrue);
        expect(viewModel.isDirty, isFalse);
      });

      test(
        'hydrates place and event promotions without disturbing state',
        () async {
          const placePromotion = AdminSubmissionPromotion(
            target: AdminPromotionTarget.place,
            entityId: 42,
          );
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: <int, Result<AdminSubmission>>{
              1: Result.success(
                sampleAdminSubmission(
                  status: AdminSubmissionStatus.accepted,
                  promotion: placePromotion,
                ),
              ),
              2: Result.success(
                sampleAdminSubmission(
                  id: 2,
                  status: AdminSubmissionStatus.accepted,
                  promotion: const AdminSubmissionPromotion(
                    target: AdminPromotionTarget.event,
                    entityId: 43,
                  ),
                ),
              ),
            },
          );

          final promotedPlace = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            submissionId: 1,
          );
          addTearDown(promotedPlace.dispose);
          await promotedPlace.load.execute();

          expect(promotedPlace.promotion, placePromotion);
          expect(promotedPlace.status, AdminSubmissionStatus.accepted);
          expect(promotedPlace.isEditable, isFalse);
          expect(promotedPlace.isDirty, isFalse);

          final promotedEvent = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: FakeContentSubmissionRepository(),
            submissionId: 2,
          );
          addTearDown(promotedEvent.dispose);
          await promotedEvent.load.execute();

          expect(
            promotedEvent.promotion,
            const AdminSubmissionPromotion(
              target: AdminPromotionTarget.event,
              entityId: 43,
            ),
          );
        },
      );

      test('accepted historical rows keep a null promotion', () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(status: AdminSubmissionStatus.accepted),
            ),
          },
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();

        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(viewModel.promotion, isNull);
        expect(viewModel.isEditable, isFalse);
      });

      test('create mode is editable', () {
        final viewModel = createViewModel();
        addTearDown(viewModel.dispose);

        expect(viewModel.isEditMode, isFalse);
        expect(viewModel.isEditable, isTrue);
      });
    });

    test(
      'delegates promote and reject for a clean pending submission',
      () async {
        final repository = FakeAdminContentSubmissionRepository();
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        await viewModel.load.execute();
        notifications = 0;

        expect(viewModel.hasPublishableCategory, isTrue);

        await viewModel.promote.execute(AdminPromotionTarget.place);

        expect(viewModel.promote.completed, isTrue);
        expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
          (1, AdminPromotionTarget.place),
        ]);
        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(
          viewModel.promotion,
          const AdminSubmissionPromotion(
            target: AdminPromotionTarget.place,
            entityId: 1,
          ),
        );
        // One logical notification for the moderation success.
        expect(notifications, 1);

        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        final rejectingViewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 2,
        );
        addTearDown(rejectingViewModel.dispose);
        repository.getByIdResults[2] = Result.success(
          sampleAdminSubmission(id: 2),
        );
        await rejectingViewModel.load.execute();
        await rejectingViewModel.reject.execute();

        expect(rejectingViewModel.reject.completed, isTrue);
        expect(repository.rejectIds, <int>[2]);
        expect(rejectingViewModel.status, AdminSubmissionStatus.rejected);
      },
    );

    test(
      'blocks unknown or unset categories locally without blocking rejection',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(
              sampleAdminSubmission(category: ContentCategory.unknown),
            ),
            2: Result.success(sampleAdminSubmission(id: 2)),
          },
          updateResult: Result.success(
            sampleAdminSubmission(
              id: 2,
              category: ContentCategory.unknown,
            ),
          ),
        );
        final unknown = createViewModel(
          repository: repository,
          submissionId: 1,
        );
        final unset = createViewModel(
          repository: repository,
          submissionId: 2,
        );
        addTearDown(unknown.dispose);
        addTearDown(unset.dispose);

        await unknown.load.execute();
        expect(unknown.hasPublishableCategory, isFalse);
        await unknown.promote.execute(AdminPromotionTarget.place);

        expect(unknown.promote.error, isTrue);
        expect(repository.promoteCalls, isEmpty);

        await unknown.reject.execute();

        expect(unknown.reject.completed, isTrue);
        expect(repository.rejectIds, <int>[1]);

        await unset.load.execute();
        unset.setCategory(null);
        expect(unset.hasPublishableCategory, isFalse);

        await unset.save.execute();

        expect(unset.save.completed, isTrue);
        expect(
          repository.updateInputs.single.category,
          ContentCategory.unknown,
        );
        expect(unset.isDirty, isFalse);

        await unset.promote.execute(AdminPromotionTarget.place);

        expect(unset.promote.error, isTrue);
        expect(
          (unset.promote.result! as Error<AdminSubmissionPromotion>).error
              .toString(),
          'Exception: Seleziona una categoria e salva prima di pubblicare.',
        );
        expect(repository.promoteCalls, isEmpty);
      },
    );

    test(
      'promotes with an explicit event target and keeps its result',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          promoteResults: <Result<AdminSubmissionPromotion>>[
            const Result.success(
              AdminSubmissionPromotion(
                target: AdminPromotionTarget.event,
                entityId: 77,
              ),
            ),
          ],
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 4,
        );
        addTearDown(viewModel.dispose);
        repository.getByIdResults[4] = Result.success(
          sampleAdminSubmission(startDate: DateTime.utc(2026, 8, 20, 10)),
        );

        await viewModel.load.execute();
        await viewModel.promote.execute(AdminPromotionTarget.event);

        expect(viewModel.promote.completed, isTrue);
        expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
          (4, AdminPromotionTarget.event),
        ]);
        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(
          viewModel.promotion,
          const AdminSubmissionPromotion(
            target: AdminPromotionTarget.event,
            entityId: 77,
          ),
        );
      },
    );

    test(
      'blocks event promotion without dates after moderation eligibility '
      'passes',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            6: Result.success(sampleAdminSubmission(id: 6)),
          },
        );
        final viewModel = createViewModel(
          repository: repository,
          submissionId: 6,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();
        await viewModel.promote.execute(AdminPromotionTarget.event);

        expect(viewModel.promote.error, isTrue);
        expect(
          viewModel.promote.result,
          isA<Error<AdminSubmissionPromotion>>(),
        );
        expect(viewModel.eventTimeIssue, EventTimeIssue.missingStartDate);
        expect(repository.promoteCalls, isEmpty);
      },
    );

    test(
      'applies moderation eligibility before event-target validation',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            7: Result.success(sampleAdminSubmission(id: 7)),
          },
        );
        final viewModel = createViewModel(
          repository: repository,
          submissionId: 7,
        );
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();
        viewModel.setName('Edited submission');
        await viewModel.promote.execute(AdminPromotionTarget.event);

        expect(viewModel.promote.error, isTrue);
        expect(viewModel.eventTimeIssue, isNull);
        expect(repository.promoteCalls, isEmpty);
      },
    );

    test(
      'a same-target idempotent retry behaves like a first success',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          promoteResults: <Result<AdminSubmissionPromotion>>[
            const Result.success(
              AdminSubmissionPromotion(
                target: AdminPromotionTarget.place,
                entityId: 42,
              ),
            ),
          ],
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 5,
        );
        addTearDown(viewModel.dispose);
        repository.getByIdResults[5] = Result.success(sampleAdminSubmission());

        await viewModel.load.execute();
        await viewModel.promote.execute(AdminPromotionTarget.place);
        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(
          viewModel.promotion?.entityId,
          42,
        );
      },
    );

    test(
      'does not moderate accepted or rejected submissions',
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
        await accepted.promote.execute(AdminPromotionTarget.place);
        await accepted.reject.execute();
        await rejected.promote.execute(AdminPromotionTarget.place);
        await rejected.reject.execute();

        expect(accepted.promote.error, isTrue);
        expect(accepted.reject.error, isTrue);
        expect(rejected.promote.error, isTrue);
        expect(rejected.reject.error, isTrue);
        expect(repository.promoteCalls, isEmpty);
        expect(repository.rejectIds, isEmpty);
      },
    );

    test(
      'blocks moderation when dirty, unloaded, or in create mode',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: <int, Result<AdminSubmission>>{
            1: Result.success(sampleAdminSubmission()),
          },
        );

        // Create mode has no persisted ID.
        final createMode = createViewModel(repository: repository);
        addTearDown(createMode.dispose);
        await createMode.promote.execute(AdminPromotionTarget.place);
        await createMode.reject.execute();
        expect(createMode.promote.error, isTrue);
        expect(createMode.reject.error, isTrue);

        // Detail not loaded yet.
        final unloaded = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(unloaded.dispose);
        await unloaded.promote.execute(AdminPromotionTarget.place);
        await unloaded.reject.execute();
        expect(unloaded.promote.error, isTrue);
        expect(unloaded.reject.error, isTrue);

        // Dirty editor.
        final dirty = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(dirty.dispose);
        await dirty.load.execute();
        dirty.setCity('Isernia');
        await dirty.promote.execute(AdminPromotionTarget.place);
        await dirty.reject.execute();
        expect(dirty.promote.error, isTrue);
        expect(dirty.reject.error, isTrue);

        expect(repository.promoteCalls, isEmpty);
        expect(repository.rejectIds, isEmpty);
      },
    );

    test('cannot save accepted or rejected content', () async {
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

      expect(accepted.save.error, isTrue);
      expect(rejected.save.error, isTrue);
      // A failed non-pending save never reaches the repository.
      expect(repository.updateIds, isEmpty);
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

      await viewModel.promote.execute(AdminPromotionTarget.place);
      await viewModel.reject.execute();

      expect(viewModel.promote.error, isTrue);
      expect(viewModel.reject.error, isTrue);
      expect(repository.promoteCalls, isEmpty);
      expect(repository.rejectIds, isEmpty);
      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await saving;
    });

    test('blocks saving while a moderation request is pending', () async {
      final pendingPromote = Completer<Result<AdminSubmissionPromotion>>();
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(sampleAdminSubmission()),
        },
      )..pendingPromote = pendingPromote;
      final viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load.execute();

      final publishing = viewModel.promote.execute(AdminPromotionTarget.place);
      expect(viewModel.promote.running, isTrue);
      expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
        (1, AdminPromotionTarget.place),
      ]);

      await viewModel.save.execute();

      expect(viewModel.save.error, isTrue);
      expect(repository.updateIds, isEmpty);
      pendingPromote.complete(
        const Result.success(
          AdminSubmissionPromotion(
            target: AdminPromotionTarget.place,
            entityId: 9,
          ),
        ),
      );
      await publishing;
      expect(viewModel.status, AdminSubmissionStatus.accepted);
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
      'a pending rejection excludes promotion, save, and asset mutations',
      () async {
        final pendingReject = Completer<Result<void>>();
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
          },
        )..pendingReject = pendingReject;
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();

        final rejecting = viewModel.reject.execute();
        expect(viewModel.reject.running, isTrue);

        await viewModel.promote.execute(AdminPromotionTarget.place);
        await viewModel.save.execute();
        await viewModel.addAsset.execute();
        await viewModel.deleteAsset.execute(asset.id);

        expect(viewModel.promote.error, isTrue);
        expect(viewModel.save.error, isTrue);
        expect(viewModel.addAsset.error, isTrue);
        expect(viewModel.deleteAsset.error, isTrue);
        expect(repository.promoteCalls, isEmpty);
        expect(repository.updateIds, isEmpty);
        expect(repository.addAssetCalls, isEmpty);
        expect(repository.deleteAssetCalls, isEmpty);

        pendingReject.complete(const Result.success(null));
        await rejecting;
        expect(viewModel.status, AdminSubmissionStatus.rejected);
        expect(repository.rejectIds, <int>[1]);
      },
    );

    test(
      'a pending promotion excludes rejection, save, and asset mutations',
      () async {
        final pendingPromote = Completer<Result<AdminSubmissionPromotion>>();
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
          },
        )..pendingPromote = pendingPromote;
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(),
          submissionId: 1,
        );
        addTearDown(viewModel.dispose);
        await viewModel.load.execute();

        final publishing = viewModel.promote.execute(
          AdminPromotionTarget.place,
        );
        expect(viewModel.promote.running, isTrue);

        await viewModel.reject.execute();
        await viewModel.save.execute();
        await viewModel.addAsset.execute();
        await viewModel.deleteAsset.execute(asset.id);

        expect(viewModel.reject.error, isTrue);
        expect(viewModel.save.error, isTrue);
        expect(viewModel.addAsset.error, isTrue);
        expect(viewModel.deleteAsset.error, isTrue);
        expect(repository.rejectIds, isEmpty);
        expect(repository.updateIds, isEmpty);
        expect(repository.addAssetCalls, isEmpty);
        expect(repository.deleteAssetCalls, isEmpty);

        pendingPromote.complete(
          const Result.success(
            AdminSubmissionPromotion(
              target: AdminPromotionTarget.place,
              entityId: 9,
            ),
          ),
        );
        await publishing;
        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(viewModel.promotion?.entityId, 9);
        expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
          (1, AdminPromotionTarget.place),
        ]);
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

    group('create adoption and staged assets', () {
      test(
        'adopts the authoritative create response in the same editor',
        () async {
          final created = sampleAdminSubmission(
            id: 42,
            city: 'Isernia',
            name: 'Server name',
            category: ContentCategory.nature,
            userName: 'Server editor',
            userEmail: 'server@example.com',
          );
          final repository = FakeAdminContentSubmissionRepository(
            createResult: Result.success(created),
            updateResult: Result.success(sampleAdminSubmission(id: 42)),
          );
          final viewModel = createViewModel(repository: repository);
          addTearDown(viewModel.dispose);
          viewModel
            ..setCity(' Isernia ')
            ..setName(' Server name ');

          expect(viewModel.authoritativeEditableStateRevision, 0);

          await viewModel.save.execute();

          expect(viewModel.submissionId, 42);
          expect(viewModel.isEditMode, isTrue);
          expect(viewModel.hasLoadedDetail, isTrue);
          expect(viewModel.city, 'Isernia');
          expect(viewModel.name, 'Server name');
          expect(viewModel.category, ContentCategory.nature);
          expect(viewModel.contributorEmail, 'server@example.com');
          expect(repository.getByIdIds, isEmpty);
          expect(viewModel.isDirty, isFalse);
          expect(viewModel.authoritativeEditableStateRevision, 1);

          viewModel.setName('Updated in place');
          expect(viewModel.authoritativeEditableStateRevision, 1);
          await viewModel.save.execute();

          expect(repository.createInputs, hasLength(1));
          expect(repository.updateIds, <int>[42]);
          expect(viewModel.authoritativeEditableStateRevision, 2);
        },
      );

      test(
        'stages and removes create-mode images without remote mutations',
        () async {
          var picks = 0;
          final picker = FakeImagePicker(
            onPickImage: () async => XFile('/tmp/staged-${picks++}.jpg'),
          );
          final uploads = FakeContentSubmissionRepository();
          final repository = FakeAdminContentSubmissionRepository();
          final viewModel = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: uploads,
            imagePicker: picker,
          );
          addTearDown(viewModel.dispose);

          await viewModel.addAsset.execute();
          expect(viewModel.stagedAssetFiles.single.path, '/tmp/staged-0.jpg');
          expect(viewModel.isDirty, isTrue);
          expect(uploads.uploadedImages, isEmpty);
          expect(repository.addAssetCalls, isEmpty);
          expect(repository.deleteAssetCalls, isEmpty);

          viewModel.removeStagedAssetAt(0);
          expect(viewModel.stagedAssetFiles, isEmpty);
          expect(viewModel.isDirty, isFalse);

          for (var index = 0; index < 5; index++) {
            await viewModel.addAsset.execute();
          }
          await viewModel.addAsset.execute();
          expect(viewModel.assetCount, 5);
          expect(picker.pickImageSources, hasLength(6));
          expect(viewModel.addAsset.error, isTrue);
        },
      );

      test(
        'preserves confirmed work through a middle association failure and '
        'retries in order',
        () async {
          const firstUpload = SubmissionAsset(
            secureUrl: 'https://example.com/one.jpg',
            width: 100,
            height: 100,
          );
          const secondUpload = SubmissionAsset(
            secureUrl: 'https://example.com/two.jpg',
            width: 200,
            height: 200,
          );
          const thirdUpload = SubmissionAsset(
            secureUrl: 'https://example.com/three.jpg',
            width: 300,
            height: 300,
          );
          final callLog = <String>[];
          var picks = 0;
          final repository = FakeAdminContentSubmissionRepository(
            createResult: Result.success(sampleAdminSubmission(id: 9)),
            addAssetResults: <Result<AdminSubmissionAsset>>[
              const Result.success(
                AdminSubmissionAsset(
                  id: 1,
                  url: 'https://example.com/one.jpg',
                  width: 100,
                  height: 100,
                ),
              ),
              Result.error(TestException('association failed')),
              const Result.success(
                AdminSubmissionAsset(
                  id: 2,
                  url: 'https://example.com/two.jpg',
                  width: 200,
                  height: 200,
                ),
              ),
              const Result.success(
                AdminSubmissionAsset(
                  id: 3,
                  url: 'https://example.com/three.jpg',
                  width: 300,
                  height: 300,
                ),
              ),
            ],
            callLog: callLog,
          );
          final uploads = FakeContentSubmissionRepository(
            uploadImageTaskResults: <ImageUploadTask>[
              FakeImageUploadTask.completed(const Result.success(firstUpload)),
              FakeImageUploadTask.completed(const Result.success(secondUpload)),
              FakeImageUploadTask.completed(const Result.success(thirdUpload)),
            ],
            callLog: callLog,
          );
          final viewModel = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: uploads,
            imagePicker: FakeImagePicker(
              onPickImage: () async => XFile('/tmp/${picks++}.jpg'),
            ),
          );
          addTearDown(viewModel.dispose);
          viewModel
            ..setCity('Isernia')
            ..setName('Museo');
          await viewModel.addAsset.execute();
          await viewModel.addAsset.execute();
          await viewModel.addAsset.execute();

          await viewModel.save.execute();
          expect(viewModel.save.error, isTrue);
          expect(viewModel.submissionId, 9);
          expect(viewModel.assets.map((asset) => asset.id), <int>[1]);
          expect(
            viewModel.stagedAssetFiles.map((file) => file.path),
            <String>['/tmp/1.jpg', '/tmp/2.jpg'],
          );
          expect(viewModel.isDirty, isTrue);
          expect(viewModel.authoritativeEditableStateRevision, 1);
          expect(callLog, <String>[
            'create',
            'upload:/tmp/0.jpg',
            'addAsset:9',
            'upload:/tmp/1.jpg',
            'addAsset:9',
          ]);
          await viewModel.reject.execute();
          expect(viewModel.reject.error, isTrue);

          await viewModel.save.execute();

          expect(viewModel.save.completed, isTrue);
          expect(repository.createInputs, hasLength(1));
          expect(repository.updateIds, isEmpty);
          expect(uploads.uploadedImages.map((file) => file.path), <String>[
            '/tmp/0.jpg',
            '/tmp/1.jpg',
            '/tmp/2.jpg',
          ]);
          expect(callLog, <String>[
            'create',
            'upload:/tmp/0.jpg',
            'addAsset:9',
            'upload:/tmp/1.jpg',
            'addAsset:9',
            'addAsset:9',
            'upload:/tmp/2.jpg',
            'addAsset:9',
          ]);
          expect(viewModel.stagedAssetFiles, isEmpty);
          expect(viewModel.assets.map((asset) => asset.id), <int>[1, 2, 3]);
          expect(viewModel.isDirty, isFalse);
          expect(viewModel.authoritativeEditableStateRevision, 1);
        },
      );

      test('a create failure retains staging and starts no upload', () async {
        final uploads = FakeContentSubmissionRepository();
        final repository = FakeAdminContentSubmissionRepository(
          createResult: Result.error(TestException('create failed')),
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: uploads,
          imagePicker: FakeImagePicker(
            onPickImage: () async => XFile('/tmp/staged.jpg'),
          ),
        );
        addTearDown(viewModel.dispose);
        viewModel
          ..setCity('Isernia')
          ..setName('Museo');
        await viewModel.addAsset.execute();

        await viewModel.save.execute();

        expect(viewModel.save.error, isTrue);
        expect(viewModel.submissionId, isNull);
        expect(viewModel.stagedAssetFiles, hasLength(1));
        expect(uploads.uploadedImages, isEmpty);
        expect(repository.addAssetCalls, isEmpty);
      });

      test(
        'an upload failure preserves adopted identity and staging',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            createResult: Result.success(sampleAdminSubmission(id: 21)),
          );
          final uploads = FakeContentSubmissionRepository(
            uploadImageTaskResult: FakeImageUploadTask.completed(
              Result.error(TestException('upload failed')),
            ),
          );
          final viewModel =
              AdminSubmissionEditorViewModel(
                  repository: repository,
                  contentSubmissionRepository: uploads,
                  imagePicker: FakeImagePicker(
                    onPickImage: () async => XFile('/tmp/staged.jpg'),
                  ),
                )
                ..setCity('Isernia')
                ..setName('Museo');
          addTearDown(viewModel.dispose);
          await viewModel.addAsset.execute();

          await viewModel.save.execute();

          expect(viewModel.save.error, isTrue);
          expect(viewModel.submissionId, 21);
          expect(viewModel.stagedAssetFiles, hasLength(1));
          expect(viewModel.isDirty, isTrue);
          expect(repository.addAssetCalls, isEmpty);
          await viewModel.reject.execute();
          expect(viewModel.reject.error, isTrue);
        },
      );

      test(
        'disposal before create adoption starts no staged persistence',
        () async {
          final pendingCreate = Completer<Result<AdminSubmission>>();
          final uploads = FakeContentSubmissionRepository();
          final repository = FakeAdminContentSubmissionRepository()
            ..pendingCreate = pendingCreate;
          final viewModel =
              AdminSubmissionEditorViewModel(
                  repository: repository,
                  contentSubmissionRepository: uploads,
                  imagePicker: FakeImagePicker(
                    onPickImage: () async => XFile('/tmp/staged.jpg'),
                  ),
                )
                ..setCity('Isernia')
                ..setName('Museo');
          await viewModel.addAsset.execute();

          final saving = viewModel.save.execute();
          await pumpEventQueue();
          viewModel.dispose();
          pendingCreate.complete(Result.success(sampleAdminSubmission(id: 33)));
          await saving;

          expect(viewModel.submissionId, isNull);
          expect(uploads.uploadedImages, isEmpty);
          expect(repository.addAssetCalls, isEmpty);
        },
      );

      test(
        'disposal during staged upload cancels it and starts no association',
        () async {
          final uploadTask = FakeImageUploadTask.pending();
          final repository = FakeAdminContentSubmissionRepository(
            createResult: Result.success(sampleAdminSubmission(id: 33)),
          );
          final uploads = FakeContentSubmissionRepository(
            uploadImageTaskResult: uploadTask,
          );
          final viewModel =
              AdminSubmissionEditorViewModel(
                  repository: repository,
                  contentSubmissionRepository: uploads,
                  imagePicker: FakeImagePicker(
                    onPickImage: () async => XFile('/tmp/staged.jpg'),
                  ),
                )
                ..setCity('Isernia')
                ..setName('Museo');
          await viewModel.addAsset.execute();

          final saving = viewModel.save.execute();
          await pumpEventQueue();
          viewModel.dispose();
          uploadTask.complete(
            const Result.success(
              SubmissionAsset(
                secureUrl: 'https://example.com/staged.jpg',
                width: 100,
                height: 100,
              ),
            ),
          );
          await saving;

          expect(uploadTask.cancelCallCount, 1);
          expect(repository.addAssetCalls, isEmpty);
        },
      );

      test(
        'disposal during staged association starts no later image work',
        () async {
          final pendingAssociation = Completer<Result<AdminSubmissionAsset>>();
          var picks = 0;
          final repository = FakeAdminContentSubmissionRepository(
            createResult: Result.success(sampleAdminSubmission(id: 33)),
          )..pendingAddAsset = pendingAssociation;
          final uploads = FakeContentSubmissionRepository(
            uploadImageTaskResults: <ImageUploadTask>[
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(
                    secureUrl: 'https://example.com/one.jpg',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),
              FakeImageUploadTask.completed(
                const Result.success(
                  SubmissionAsset(
                    secureUrl: 'https://example.com/two.jpg',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),
            ],
          );
          final viewModel =
              AdminSubmissionEditorViewModel(
                  repository: repository,
                  contentSubmissionRepository: uploads,
                  imagePicker: FakeImagePicker(
                    onPickImage: () async => XFile('/tmp/${picks++}.jpg'),
                  ),
                )
                ..setCity('Isernia')
                ..setName('Museo');
          await viewModel.addAsset.execute();
          await viewModel.addAsset.execute();

          final saving = viewModel.save.execute();
          await pumpEventQueue();
          expect(repository.addAssetCalls, hasLength(1));
          viewModel.dispose();
          pendingAssociation.complete(
            const Result.success(
              AdminSubmissionAsset(
                id: 1,
                url: 'https://example.com/one.jpg',
                width: 100,
                height: 100,
              ),
            ),
          );
          await saving;

          expect(uploads.uploadedImages, hasLength(1));
          expect(repository.addAssetCalls, hasLength(1));
        },
      );

      test('update results cannot clear confirmed staged assets', () async {
        const upload = SubmissionAsset(
          secureUrl: 'https://example.com/staged.jpg',
          width: 100,
          height: 100,
        );
        const confirmed = AdminSubmissionAsset(
          id: 2,
          url: 'https://example.com/staged.jpg',
          width: 100,
          height: 100,
        );
        final repository = FakeAdminContentSubmissionRepository(
          createResult: Result.success(sampleAdminSubmission(id: 5)),
          addAssetResult: const Result.success(confirmed),
          updateResult: Result.success(
            sampleAdminSubmission(
              id: 5,
              city: 'Isernia',
              name: 'Museo aggiornato',
            ),
          ),
        );
        final viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: FakeContentSubmissionRepository(
            uploadImageTaskResult: FakeImageUploadTask.completed(
              const Result.success(upload),
            ),
          ),
          imagePicker: FakeImagePicker(
            onPickImage: () async => XFile('/tmp/staged.jpg'),
          ),
        );
        addTearDown(viewModel.dispose);
        viewModel
          ..setCity('Isernia')
          ..setName('Museo');
        await viewModel.addAsset.execute();
        await viewModel.save.execute();
        viewModel.setName('Updated name');
        expect(viewModel.authoritativeEditableStateRevision, 1);

        await viewModel.save.execute();

        expect(repository.updateIds, <int>[5]);
        expect(viewModel.assets, const <AdminSubmissionAsset>[confirmed]);
        expect(viewModel.city, 'Isernia');
        expect(viewModel.name, 'Museo aggiornato');
        expect(viewModel.authoritativeEditableStateRevision, 2);
      });
    });

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

      test(
        'a location edit keeps promotion and rejection blocked while dirty',
        () async {
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

          await viewModel.promote.execute(AdminPromotionTarget.place);
          await viewModel.reject.execute();

          expect(viewModel.promote.error, isTrue);
          expect(viewModel.reject.error, isTrue);
          expect(repository.promoteCalls, isEmpty);
          expect(repository.rejectIds, isEmpty);
        },
      );

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
