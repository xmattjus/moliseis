import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/admin_moderation_error_cases.dart';
import '../../../../support/command_test_support.dart';
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

    test('human Event link accepts without a promotion', () async {
      final repository =
          FakeAdminContentSubmissionRepository(
              getByIdResults: {
                1: Result.success(
                  sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 2)),
                ),
              },
            )
            ..linkResult = const Result.success(
              AdminEventResolution(outcome: 'linked', eventId: 42),
            );
      final vm = createViewModel(repository: repository, submissionId: 1);
      addTearDown(vm.dispose);
      await settleEditorRequest(admitted: vm.requestLoad());
      await settleEditorRequest(admitted: vm.requestLink(42));
      expect(repository.linkCalls, [(1, 42)]);
      expect(vm.status, AdminSubmissionStatus.accepted);
      expect(vm.promotion, isNull);
    });

    test('imported update uses linked Event preview for Apply', () async {
      final repository =
          FakeAdminContentSubmissionRepository(
              getByIdResults: {
                1: Result.success(
                  sampleAdminSubmission(
                    startDate: DateTime.utc(2026, 10, 2),
                    externalEvent: AdminExternalEvent(
                      recordId: 5,
                      snapshotHash: 'x',
                      snapshotVersion: 1,
                      snapshot: const {'name': 'X'},
                      mode: AdminExternalEventMode.update,
                      eventId: 42,
                    ),
                  ),
                ),
              },
            )
            ..previewResult = Result.success(
              AdminEventMergePreview(
                targetEventId: 42,
                submissionVersionToken: 's',
                eventVersionToken: 'e',
                groups: [],
              ),
            )
            ..applyResult = const Result.success(
              AdminEventResolution(outcome: 'applied', eventId: 42),
            );
      final vm = createViewModel(repository: repository, submissionId: 1);
      addTearDown(vm.dispose);
      await settleEditorRequest(admitted: vm.requestLoad());
      expect(vm.isExternalUpdate, isTrue);
      await settleEditorRequest(admitted: vm.requestPreview());
      await settleEditorRequest(admitted: vm.requestApply());
      expect(repository.applyCalls.single.$2.submissionVersionToken, 's');
      expect(vm.status, AdminSubmissionStatus.accepted);
    });

    test('manual candidate search keeps pending warnings advisory', () async {
      final repository =
          FakeAdminContentSubmissionRepository(
              getByIdResults: {
                1: Result.success(
                  sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 2)),
                ),
              },
            )
            ..candidatesResult = Result.success(
              AdminEventCandidates(
                events: [const AdminEventCandidate(id: 42, name: 'Canonical')],
                pendingWarnings: [
                  const AdminEventCandidate(id: 9, name: 'Pending'),
                ],
              ),
            )
            ..linkResult = const Result.success(
              AdminEventResolution(outcome: 'linked', eventId: 42),
            );
      final vm = createViewModel(repository: repository, submissionId: 1);
      addTearDown(vm.dispose);
      await settleEditorRequest(admitted: vm.requestLoad());
      vm.setCandidateSearch('  festa  ');
      await settleEditorRequest(admitted: vm.requestFindCandidates());
      expect(repository.candidateCalls.single, (1, 'festa', null));
      expect(vm.candidates!.pendingWarnings.single.id, 9);
      expect(vm.isDirty, isFalse);
      vm.selectTargetEvent(42);
      await settleEditorRequest(admitted: vm.requestLink(42));
      expect(vm.linkSnapshot.completed, isTrue);
    });

    test(
      'keep-current saves the complete location and reloads preview',
      () async {
        final group = AdminEventMergeGroup(
          name: 'location',
          providerChanged: true,
          moderatorChanged: false,
          apply: true,
          overwrite: true,
          base: {},
          source: {},
          moderated: {},
          current: {
            'city': 'Termoli',
            'latitude': '41.123456789',
            'longitude': '14.555555555',
          },
        );
        final repository =
            FakeAdminContentSubmissionRepository(
                getByIdResults: {
                  1: Result.success(
                    sampleAdminSubmission(
                      startDate: DateTime.utc(2026, 10, 2),
                      externalEvent: AdminExternalEvent(
                        recordId: 5,
                        snapshotHash: 'x',
                        snapshotVersion: 1,
                        snapshot: const {},
                        mode: AdminExternalEventMode.update,
                        eventId: 42,
                      ),
                    ),
                  ),
                },
              )
              ..previewResult = Result.success(
                AdminEventMergePreview(
                  targetEventId: 42,
                  submissionVersionToken: 's',
                  eventVersionToken: 'e',
                  groups: [group],
                ),
              );
        final vm = createViewModel(repository: repository, submissionId: 1);
        addTearDown(vm.dispose);
        await settleEditorRequest(admitted: vm.requestLoad());
        await settleEditorRequest(admitted: vm.requestPreview());
        await settleEditorRequest(admitted: vm.requestKeepCurrent(group));
        expect(vm.keepCurrentSnapshot.completed, isTrue);
        expect(repository.updateInputs.single.city, 'Termoli');
        expect(repository.updateInputs.single.latitude, 41.123456789);
        expect(repository.updateInputs.single.longitude, 14.555555555);
        expect(repository.previewCalls, hasLength(2));
        expect(vm.isDirty, isFalse);
        vm.setName('changed');
        expect(vm.mergePreview, isNull);
      },
    );

    test(
      'keep-current null city remains null and fails ordinary Save',
      () async {
        final group = AdminEventMergeGroup(
          name: 'location',
          providerChanged: true,
          moderatorChanged: false,
          apply: true,
          overwrite: true,
          base: {},
          source: {},
          moderated: {},
          current: {'city': null, 'latitude': null, 'longitude': null},
        );
        final repository =
            FakeAdminContentSubmissionRepository(
                getByIdResults: {
                  1: Result.success(
                    sampleAdminSubmission(
                      startDate: DateTime.utc(2026, 10, 2),
                      externalEvent: AdminExternalEvent(
                        recordId: 5,
                        snapshotHash: 'x',
                        snapshotVersion: 1,
                        snapshot: const {},
                        mode: AdminExternalEventMode.update,
                        eventId: 42,
                      ),
                    ),
                  ),
                },
              )
              ..previewResult = Result.success(
                AdminEventMergePreview(
                  targetEventId: 42,
                  submissionVersionToken: 's',
                  eventVersionToken: 'e',
                  groups: [group],
                ),
              );
        final vm = createViewModel(repository: repository, submissionId: 1);
        addTearDown(vm.dispose);
        await settleEditorRequest(admitted: vm.requestLoad());
        await settleEditorRequest(admitted: vm.requestPreview());
        await settleEditorRequest(admitted: vm.requestKeepCurrent(group));
        expect(vm.keepCurrentSnapshot.hasFailure, isTrue);
        expect(vm.city, isNull);
        expect(vm.latitudeText, isEmpty);
        expect(repository.updateInputs, isEmpty);
        expect(vm.mergePreview, isNull);
      },
    );

    for (final entry in <String, Map<String, dynamic>>{
      'description': {
        'description': 'Current',
        'description_delta': [
          {
            'insert': 'Current',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
      },
      'schedule': {
        'start_date': '2026-10-02T10:00:00.123456Z',
        'end_date': '2026-10-02T11:00:00.654321Z',
        'all_day': false,
      },
    }.entries) {
      test('keep-current ${entry.key} saves every atomic field', () async {
        final group = AdminEventMergeGroup(
          name: entry.key,
          providerChanged: true,
          moderatorChanged: false,
          apply: true,
          overwrite: true,
          base: {},
          source: {},
          moderated: {},
          current: entry.value,
        );
        final repository =
            FakeAdminContentSubmissionRepository(
                getByIdResults: {
                  1: Result.success(
                    sampleAdminSubmission(
                      startDate: DateTime.utc(2026, 10, 2),
                      externalEvent: AdminExternalEvent(
                        recordId: 5,
                        snapshotHash: 'x',
                        snapshotVersion: 1,
                        snapshot: const {},
                        mode: AdminExternalEventMode.update,
                        eventId: 42,
                      ),
                    ),
                  ),
                },
              )
              ..previewResult = Result.success(
                AdminEventMergePreview(
                  targetEventId: 42,
                  submissionVersionToken: 's',
                  eventVersionToken: 'e',
                  groups: [group],
                ),
              );
        final vm = createViewModel(repository: repository, submissionId: 1);
        addTearDown(vm.dispose);
        await settleEditorRequest(admitted: vm.requestLoad());
        await settleEditorRequest(admitted: vm.requestPreview());
        await settleEditorRequest(admitted: vm.requestKeepCurrent(group));
        expect(vm.keepCurrentSnapshot.completed, isTrue);
        final input = repository.updateInputs.single;
        if (entry.key == 'description') {
          expect(input.description, 'Current');
          expect(input.descriptionDelta, entry.value['description_delta']);
        } else {
          expect(
            input.startDate,
            DateTime.parse(entry.value['start_date'] as String),
          );
          expect(
            input.endDate,
            DateTime.parse(entry.value['end_date'] as String),
          );
          expect(input.allDay, isFalse);
        }
        expect(repository.previewCalls, hasLength(2));
      });
    }

    test(
      'Save while preview is in flight cannot restore old preview tokens',
      () async {
        final pending = Completer<Result<AdminEventMergePreview>>();
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: {
            1: Result.success(
              sampleAdminSubmission(
                startDate: DateTime.utc(2026, 10, 2),
                externalEvent: AdminExternalEvent(
                  recordId: 5,
                  snapshotHash: 'x',
                  snapshotVersion: 1,
                  snapshot: const {},
                  mode: AdminExternalEventMode.update,
                  eventId: 42,
                ),
              ),
            ),
          },
        )..pendingPreview = pending;
        final vm = createViewModel(repository: repository, submissionId: 1);
        addTearDown(vm.dispose);
        await settleEditorRequest(admitted: vm.requestLoad());
        vm
          ..requestPreview()
          ..setName('saved change');
        await settleEditorRequest(admitted: vm.requestSave());
        pending.complete(
          Result.success(
            AdminEventMergePreview(
              targetEventId: 42,
              submissionVersionToken: 'old',
              eventVersionToken: 'old',
              groups: [],
            ),
          ),
        );
        await pumpEventQueue();
        expect(vm.isDirty, isFalse);
        expect(vm.mergePreview, isNull);
        expect(repository.updateInputs, hasLength(1));
      },
    );

    for (final (code, status, _) in adminModerationErrorCases) {
      test(
        'Link preserves typed $code and makes no success mutation',
        () async {
          final error = AdminContentSubmissionApiException(
            statusCode: status,
            code: code,
            message: 'Backend',
          );
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: {
              1: Result.success(
                sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 2)),
              ),
            },
          )..linkResult = Result.error(error);
          final vm = createViewModel(repository: repository, submissionId: 1);
          addTearDown(vm.dispose);
          await settleEditorRequest(admitted: vm.requestLoad());
          await settleEditorRequest(admitted: vm.requestLink(42));
          expect(
            (vm.linkSnapshot.data! as Error<AdminEventResolution>).error,
            same(error),
          );
          expect(vm.status, AdminSubmissionStatus.pending);
        },
      );
    }

    for (final operation in ['reject', 'promote', 'link', 'apply']) {
      test(
        '$operation forwards only the explicitly displayed stale source hash',
        () async {
          final external = AdminExternalEvent(
            recordId: 5,
            snapshotHash: 'x',
            snapshotVersion: 1,
            snapshot: const {'name': 'X'},
            mode: AdminExternalEventMode.update,
            eventId: 42,
            currentHash: 'y',
            currentSnapshot: const {'name': 'Y'},
          );
          final repository =
              FakeAdminContentSubmissionRepository(
                  getByIdResults: {
                    1: Result.success(
                      sampleAdminSubmission(
                        startDate: DateTime.utc(2026, 10, 2),
                        externalEvent: external,
                      ),
                    ),
                  },
                )
                ..previewResult = Result.success(
                  AdminEventMergePreview(
                    targetEventId: 42,
                    submissionVersionToken: 's',
                    eventVersionToken: 'e',
                    groups: [],
                  ),
                )
                ..linkResult = const Result.success(
                  AdminEventResolution(outcome: 'linked', eventId: 42),
                )
                ..applyResult = const Result.success(
                  AdminEventResolution(outcome: 'applied', eventId: 42),
                );
          final vm = createViewModel(repository: repository, submissionId: 1);
          addTearDown(vm.dispose);
          await settleEditorRequest(admitted: vm.requestLoad());
          if (operation == 'apply') {
            await settleEditorRequest(admitted: vm.requestPreview());
          }
          vm.setAcknowledgeCurrentSource(selected: true);
          switch (operation) {
            case 'reject':
              await settleEditorRequest(admitted: vm.requestReject());
            case 'promote':
              await settleEditorRequest(
                admitted: vm.requestPromote(AdminPromotionTarget.event),
              );
            case 'link':
              await settleEditorRequest(admitted: vm.requestLink(42));
            case 'apply':
              await settleEditorRequest(admitted: vm.requestApply());
          }
          expect(repository.sourceOptions.single.$3, isTrue);
          expect(repository.sourceOptions.single.$4, 'y');
          expect(vm.acknowledgeCurrentSource, isFalse);
          expect(repository.getByIdIds, [1, 1]);
        },
      );
    }

    test('source_changed refetches current source and requires renewed '
        'acknowledgement', () async {
      final repository =
          FakeAdminContentSubmissionRepository(
              getByIdResults: {
                1: Result.success(
                  sampleAdminSubmission(
                    startDate: DateTime.utc(2026, 10, 2),
                    externalEvent: AdminExternalEvent(
                      recordId: 5,
                      snapshotHash: 'x',
                      snapshotVersion: 1,
                      snapshot: const {},
                      mode: AdminExternalEventMode.update,
                      eventId: 42,
                      currentHash: 'y',
                      currentSnapshot: const {'name': 'Y'},
                    ),
                  ),
                ),
              },
            )
            ..linkResult = const Result.error(
              AdminContentSubmissionApiException(
                statusCode: 409,
                code: 'SOURCE_CHANGED',
                message: 'Review',
              ),
            );
      final vm = createViewModel(repository: repository, submissionId: 1);
      addTearDown(vm.dispose);
      await settleEditorRequest(admitted: vm.requestLoad());
      vm.setAcknowledgeCurrentSource(selected: true);
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          startDate: DateTime.utc(2026, 10, 2),
          externalEvent: AdminExternalEvent(
            recordId: 5,
            snapshotHash: 'x',
            snapshotVersion: 1,
            snapshot: const {},
            mode: AdminExternalEventMode.update,
            eventId: 42,
            currentHash: 'z',
            currentSnapshot: const {'name': 'Z'},
          ),
        ),
      );
      await settleEditorRequest(admitted: vm.requestLink(42));
      expect(repository.sourceOptions.single.$4, 'y');
      expect(vm.externalEvent!.currentHash, 'z');
      expect(vm.externalEvent!.currentSnapshot!['name'], 'Z');
      expect(vm.acknowledgeCurrentSource, isFalse);
      expect(vm.linkSnapshot.hasFailure, isTrue);
      vm.setAcknowledgeCurrentSource(selected: true);
      await settleEditorRequest(admitted: vm.requestLink(42));
      expect(repository.sourceOptions.last.$4, 'z');
    });

    test('preview newer current source replaces display and clears prior '
        'selection', () async {
      final repository =
          FakeAdminContentSubmissionRepository(
              getByIdResults: {
                1: Result.success(
                  sampleAdminSubmission(
                    startDate: DateTime.utc(2026, 10, 2),
                    externalEvent: AdminExternalEvent(
                      recordId: 5,
                      snapshotHash: 'x',
                      snapshotVersion: 1,
                      snapshot: const {},
                      mode: AdminExternalEventMode.update,
                      eventId: 42,
                      currentHash: 'y',
                      currentSnapshot: const {'name': 'Y'},
                    ),
                  ),
                ),
              },
            )
            ..previewResult = Result.success(
              AdminEventMergePreview(
                targetEventId: 42,
                submissionVersionToken: 's',
                eventVersionToken: 'e',
                groups: [],
                currentSourceHash: 'z',
                currentSourceSnapshot: {'name': 'Z'},
              ),
            );
      final vm = createViewModel(repository: repository, submissionId: 1);
      addTearDown(vm.dispose);
      await settleEditorRequest(admitted: vm.requestLoad());
      vm.setAcknowledgeCurrentSource(selected: true);
      await settleEditorRequest(admitted: vm.requestPreview());
      expect(vm.externalEvent!.currentHash, 'z');
      expect(vm.externalEvent!.currentSnapshot!['name'], 'Z');
      expect(vm.acknowledgeCurrentSource, isFalse);
    });

    test('non-stale source cannot select acknowledgement', () async {
      final repository =
          FakeAdminContentSubmissionRepository(
              getByIdResults: {
                1: Result.success(
                  sampleAdminSubmission(
                    startDate: DateTime.utc(2026, 10, 2),
                    externalEvent: AdminExternalEvent(
                      recordId: 5,
                      snapshotHash: 'x',
                      snapshotVersion: 1,
                      snapshot: const {},
                      mode: AdminExternalEventMode.create,
                      currentHash: 'x',
                      currentSnapshot: const {},
                    ),
                  ),
                ),
              },
            )
            ..linkResult = const Result.success(
              AdminEventResolution(outcome: 'linked', eventId: 42),
            );
      final vm = createViewModel(repository: repository, submissionId: 1);
      addTearDown(vm.dispose);
      await settleEditorRequest(admitted: vm.requestLoad());
      vm.setAcknowledgeCurrentSource(selected: true);
      expect(vm.isSourceStale, isFalse);
      expect(vm.acknowledgeCurrentSource, isFalse);
      await settleEditorRequest(admitted: vm.requestLink(42));
      expect(repository.sourceOptions.single.$3, isNull);
      expect(repository.sourceOptions.single.$4, isNull);
    });

    test(
      'successful stale rejection reloads resolved and follow-up pending',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          getByIdResults: {
            1: Result.success(
              sampleAdminSubmission(
                startDate: DateTime.utc(2026, 10, 2),
                externalEvent: AdminExternalEvent(
                  recordId: 5,
                  snapshotHash: 'x',
                  snapshotVersion: 1,
                  snapshot: const {},
                  mode: AdminExternalEventMode.create,
                  currentHash: 'y',
                  currentSnapshot: const {},
                ),
              ),
            ),
            2: Result.success(sampleAdminSubmission(id: 2, name: 'Follow-up')),
          },
        )..rejectPendingId = 2;
        final vm = createViewModel(repository: repository, submissionId: 1);
        addTearDown(vm.dispose);
        await settleEditorRequest(admitted: vm.requestLoad());
        await settleEditorRequest(admitted: vm.requestReject());
        expect(repository.getByIdIds, [1, 1, 2]);
        expect(vm.followupSubmission!.id, 2);
        expect(vm.status, AdminSubmissionStatus.rejected);
      },
    );

    test('all-day create captures mode and Rome bounds', () async {
      final repository = FakeAdminContentSubmissionRepository();
      final vm = createViewModel(repository: repository);
      addTearDown(vm.dispose);
      vm
        ..setCity('Campobasso')
        ..setName('Event')
        ..setEventEnabled(enabled: true)
        ..setAllDay(allDay: true)
        ..setStartCalendarDate(EventCalendarDate(2026, 3, 29));
      expect(vm.startClockTime, isNull);
      await settleEditorRequest(admitted: vm.requestSave());
      expect(vm.saveSnapshot.completed, isTrue);
      expect(repository.createInputs.single.allDay, isTrue);
      expect(
        repository.createInputs.single.startDate,
        DateTime.utc(2026, 3, 28, 23),
      );
    });

    for (final initiallyAllDay in [false, true]) {
      test(
        'update switches mode from $initiallyAllDay without old clock',
        () async {
          final repository = FakeAdminContentSubmissionRepository(
            getByIdResults: {
              1: Result.success(
                sampleAdminSubmission(
                  allDay: initiallyAllDay,
                  startDate: DateTime.utc(2026, 10, 24, 22),
                  endDate: DateTime.utc(2026, 10, 26, 22, 59, 59, 999, 999),
                ),
              ),
            },
          );
          final vm = createViewModel(repository: repository, submissionId: 1);
          addTearDown(vm.dispose);
          await settleEditorRequest(admitted: vm.requestLoad());
          expect(vm.allDay, initiallyAllDay);
          expect(vm.isDirty, isFalse);
          vm.setAllDay(allDay: !initiallyAllDay);
          expect(vm.isDirty, isTrue);
          expect(vm.startClockTime, isNull);
          expect(vm.endCalendarDate, EventCalendarDate(2026, 10, 26));
          if (initiallyAllDay) {
            await settleEditorRequest(admitted: vm.requestSave());
            expect(repository.updateInputs, isEmpty);
            expect(vm.eventTimeIssue, EventTimeIssue.missingStartTime);
            vm.setStartClockTime(EventClockTime(10, 30));
          }
          await settleEditorRequest(admitted: vm.requestSave());
          expect(vm.saveSnapshot.completed, isTrue);
          expect(repository.updateInputs.single.allDay, !initiallyAllDay);
          expect(vm.isDirty, isFalse);
        },
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

        await settleEditorRequest(admitted: viewModel.requestLoad());

        expect(viewModel.loadSnapshot.completed, isTrue);
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

      await settleEditorRequest(admitted: viewModel.requestLoad());

      expect(viewModel.loadSnapshot.hasFailure, isTrue);
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
      await settleEditorRequest(admitted: viewModel.requestSave());

      expect(viewModel.saveSnapshot.hasFailure, isTrue);
      expect(repository.createInputs, isEmpty);

      final missingNameViewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
      );
      addTearDown(missingNameViewModel.dispose);
      missingNameViewModel.setCity('Isernia');
      await settleEditorRequest(admitted: missingNameViewModel.requestSave());

      expect(missingNameViewModel.saveSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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
      await settleEditorRequest(admitted: viewModel.requestLoad());
      expect(viewModel.isEditable, isTrue);

      viewModel
        ..setCategory(ContentCategory.nature)
        ..setCity('Termoli')
        ..setName('Spiaggia');
      await settleEditorRequest(admitted: viewModel.requestSave());

      expect(viewModel.saveSnapshot.completed, isTrue);
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
      await settleEditorRequest(admitted: viewModel.requestSave());

      expect(viewModel.saveSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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

          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.hasFailure, isTrue);
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

          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.hasFailure, isTrue);
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

          await settleEditorRequest(admitted: viewModel.requestLoad());
          expect(viewModel.startDate, loadedDate);
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(viewModel.endDate, loadedDate);

          viewModel.setName('Museo rinnovato');
          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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

          await settleEditorRequest(admitted: viewModel.requestLoad());

          viewModel.setStartClockTime(EventClockTime(5, 0));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 20, 3));
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(
            viewModel.endDate,
            DateTime.utc(2026, 8, 20, 21, 59, 59, 999, 999),
          );
          expect(viewModel.endDate!.isUtc, isTrue);

          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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

          await settleEditorRequest(admitted: viewModel.requestLoad());

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

          await settleEditorRequest(admitted: viewModel.requestLoad());

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

          await settleEditorRequest(admitted: viewModel.requestLoad());

          viewModel.setStartCalendarDate(EventCalendarDate(2026, 8, 21));

          expect(viewModel.startDate, DateTime.utc(2026, 8, 20, 22));
          expect(viewModel.startDate!.isUtc, isTrue);
          expect(viewModel.endDate, DateTime.utc(2026, 8, 20, 23));
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

          await settleEditorRequest(admitted: viewModel.requestLoad());
          viewModel
            ..setStartCalendarDate(EventCalendarDate(2026, 8, 21))
            ..setName('Sagra spostata');
          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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

        await settleEditorRequest(admitted: viewModel.requestLoad());
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

          await settleEditorRequest(admitted: viewModel.requestLoad());
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

          await settleEditorRequest(admitted: viewModel.requestLoad());
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
            ..setEventEnabled(enabled: true)
            ..setStartCalendarDate(EventCalendarDate(2026, 3, 29));

          await settleEditorRequest(admitted: viewModel.requestSave());
          expect(viewModel.saveSnapshot.hasFailure, isTrue);
          expect(repository.createInputs, isEmpty);

          viewModel
            ..setStartClockTime(EventClockTime(1, 30))
            ..setStartClockTime(EventClockTime(2, 30));
          final prior = viewModel.startDate;
          expect(viewModel.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
          expect(viewModel.startDate, prior);

          await settleEditorRequest(admitted: viewModel.requestSave());
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

        await settleEditorRequest(admitted: viewModel.requestLoad());

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
          await settleEditorRequest(admitted: promotedPlace.requestLoad());

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
          await settleEditorRequest(admitted: promotedEvent.requestLoad());

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

        await settleEditorRequest(admitted: viewModel.requestLoad());

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
        final states = <(bool, AdminSubmissionStatus?)>[];
        viewModel.addListener(
          () => states.add((viewModel.operationRunning, viewModel.status)),
        );

        await settleEditorRequest(admitted: viewModel.requestLoad());
        states.clear();

        expect(viewModel.hasPublishableCategory, isTrue);

        await settleEditorRequest(
          admitted: viewModel.requestPromote(AdminPromotionTarget.place),
        );

        expect(viewModel.promoteSnapshot.completed, isTrue);
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
        expect(states.any((state) => state.$1), isTrue);
        expect(states.last, (false, AdminSubmissionStatus.accepted));

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
        await settleEditorRequest(admitted: rejectingViewModel.requestLoad());
        await settleEditorRequest(admitted: rejectingViewModel.requestReject());

        expect(rejectingViewModel.rejectSnapshot.completed, isTrue);
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
        );
        final unknown = createViewModel(
          repository: repository,
          submissionId: 1,
        );
        final unset = createViewModel(repository: repository, submissionId: 2);
        addTearDown(unknown.dispose);
        addTearDown(unset.dispose);

        await settleEditorRequest(admitted: unknown.requestLoad());
        expect(unknown.hasPublishableCategory, isFalse);
        await settleEditorRequest(
          admitted: unknown.requestPromote(AdminPromotionTarget.place),
        );

        expect(unknown.promoteSnapshot.hasFailure, isTrue);
        expect(repository.promoteCalls, isEmpty);

        await settleEditorRequest(admitted: unknown.requestReject());

        expect(unknown.rejectSnapshot.completed, isTrue);
        expect(repository.rejectIds, <int>[1]);

        await settleEditorRequest(admitted: unset.requestLoad());
        unset.setCategory(null);
        expect(unset.hasPublishableCategory, isFalse);

        await settleEditorRequest(admitted: unset.requestSave());

        expect(unset.saveSnapshot.completed, isTrue);
        expect(
          repository.updateInputs.single.category,
          ContentCategory.unknown,
        );
        expect(unset.isDirty, isFalse);

        await settleEditorRequest(
          admitted: unset.requestPromote(AdminPromotionTarget.place),
        );

        expect(unset.promoteSnapshot.hasFailure, isTrue);
        expect(
          (unset.promoteSnapshot.data! as Error<AdminSubmissionPromotion>).error
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

        await settleEditorRequest(admitted: viewModel.requestLoad());
        await settleEditorRequest(
          admitted: viewModel.requestPromote(AdminPromotionTarget.event),
        );

        expect(viewModel.promoteSnapshot.completed, isTrue);
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

    test('blocks event promotion without dates after moderation eligibility '
        'passes', () async {
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

      await settleEditorRequest(admitted: viewModel.requestLoad());
      await settleEditorRequest(
        admitted: viewModel.requestPromote(AdminPromotionTarget.event),
      );

      expect(viewModel.promoteSnapshot.hasFailure, isTrue);
      expect(
        viewModel.promoteSnapshot.data,
        isA<Error<AdminSubmissionPromotion>>(),
      );
      expect(viewModel.eventTimeIssue, EventTimeIssue.missingStartDate);
      expect(repository.promoteCalls, isEmpty);
    });

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

        await settleEditorRequest(admitted: viewModel.requestLoad());
        viewModel.setName('Edited submission');
        await settleEditorRequest(
          admitted: viewModel.requestPromote(AdminPromotionTarget.event),
        );

        expect(viewModel.promoteSnapshot.hasFailure, isTrue);
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

        await settleEditorRequest(admitted: viewModel.requestLoad());
        await settleEditorRequest(
          admitted: viewModel.requestPromote(AdminPromotionTarget.place),
        );
        expect(viewModel.status, AdminSubmissionStatus.accepted);
        expect(viewModel.promotion?.entityId, 42);
      },
    );

    test('does not moderate accepted or rejected submissions', () async {
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

      await settleEditorRequest(admitted: accepted.requestLoad());
      await settleEditorRequest(admitted: rejected.requestLoad());
      await settleEditorRequest(
        admitted: accepted.requestPromote(AdminPromotionTarget.place),
      );
      await settleEditorRequest(admitted: accepted.requestReject());
      await settleEditorRequest(
        admitted: rejected.requestPromote(AdminPromotionTarget.place),
      );
      await settleEditorRequest(admitted: rejected.requestReject());

      expect(accepted.promoteSnapshot.hasFailure, isTrue);
      expect(accepted.rejectSnapshot.hasFailure, isTrue);
      expect(rejected.promoteSnapshot.hasFailure, isTrue);
      expect(rejected.rejectSnapshot.hasFailure, isTrue);
      expect(repository.promoteCalls, isEmpty);
      expect(repository.rejectIds, isEmpty);
    });

    test('blocks moderation when dirty, unloaded, or in create mode', () async {
      final repository = FakeAdminContentSubmissionRepository(
        getByIdResults: <int, Result<AdminSubmission>>{
          1: Result.success(sampleAdminSubmission()),
        },
      );

      // Create mode has no persisted ID.
      final createMode = createViewModel(repository: repository);
      addTearDown(createMode.dispose);
      await settleEditorRequest(
        admitted: createMode.requestPromote(AdminPromotionTarget.place),
      );
      await settleEditorRequest(admitted: createMode.requestReject());
      expect(createMode.promoteSnapshot.hasFailure, isTrue);
      expect(createMode.rejectSnapshot.hasFailure, isTrue);

      // Detail not loaded yet.
      final unloaded = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      addTearDown(unloaded.dispose);
      await settleEditorRequest(
        admitted: unloaded.requestPromote(AdminPromotionTarget.place),
      );
      await settleEditorRequest(admitted: unloaded.requestReject());
      expect(unloaded.promoteSnapshot.hasFailure, isTrue);
      expect(unloaded.rejectSnapshot.hasFailure, isTrue);

      // Dirty editor.
      final dirty = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: FakeContentSubmissionRepository(),
        submissionId: 1,
      );
      addTearDown(dirty.dispose);
      await settleEditorRequest(admitted: dirty.requestLoad());
      dirty.setCity('Isernia');
      await settleEditorRequest(
        admitted: dirty.requestPromote(AdminPromotionTarget.place),
      );
      await settleEditorRequest(admitted: dirty.requestReject());
      expect(dirty.promoteSnapshot.hasFailure, isTrue);
      expect(dirty.rejectSnapshot.hasFailure, isTrue);

      expect(repository.promoteCalls, isEmpty);
      expect(repository.rejectIds, isEmpty);
    });

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

      await settleEditorRequest(admitted: accepted.requestLoad());
      await settleEditorRequest(admitted: rejected.requestLoad());
      accepted.setCity('Isernia');
      rejected.setCity('Termoli');
      await settleEditorRequest(admitted: accepted.requestSave());
      await settleEditorRequest(admitted: rejected.requestSave());

      expect(accepted.saveSnapshot.hasFailure, isTrue);
      expect(rejected.saveSnapshot.hasFailure, isTrue);
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
      await settleEditorRequest(admitted: viewModel.requestLoad());
      viewModel
        ..setCity('Isernia')
        ..requestSave();
      expect(viewModel.saveSnapshot.isRunning, isTrue);
      expect(repository.updateIds, isEmpty);
      await pumpEventQueue();
      expect(repository.updateIds, <int>[1]);

      await settleEditorRequest(
        admitted: viewModel.requestPromote(AdminPromotionTarget.place),
      );
      await settleEditorRequest(admitted: viewModel.requestReject());

      expect(viewModel.promoteSnapshot.idle, isTrue);
      expect(viewModel.rejectSnapshot.idle, isTrue);
      expect(repository.promoteCalls, isEmpty);
      expect(repository.rejectIds, isEmpty);
      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await pumpEventQueue();
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
      await settleEditorRequest(admitted: viewModel.requestLoad());

      viewModel.requestPromote(AdminPromotionTarget.place);
      expect(viewModel.promoteSnapshot.isRunning, isTrue);
      await pumpEventQueue();
      expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
        (1, AdminPromotionTarget.place),
      ]);

      await settleEditorRequest(admitted: viewModel.requestSave());

      expect(viewModel.saveSnapshot.idle, isTrue);
      expect(repository.updateIds, isEmpty);
      pendingPromote.complete(
        const Result.success(
          AdminSubmissionPromotion(
            target: AdminPromotionTarget.place,
            entityId: 9,
          ),
        ),
      );
      await pumpEventQueue();
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
        await settleEditorRequest(admitted: viewModel.requestLoad());
        viewModel.setCity('Termoli');

        await settleEditorRequest(admitted: viewModel.requestAddAsset());

        expect(viewModel.addAssetSnapshot.completed, isTrue);
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

        await settleEditorRequest(admitted: viewModel.requestSave());

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
      await settleEditorRequest(admitted: viewModel.requestLoad());

      await settleEditorRequest(admitted: viewModel.requestAddAsset());

      expect(viewModel.addAssetSnapshot.completed, isTrue);
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
      await settleEditorRequest(admitted: viewModel.requestLoad());

      await settleEditorRequest(admitted: viewModel.requestAddAsset());

      expect(viewModel.addAssetSnapshot.hasFailure, isTrue);
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
      await settleEditorRequest(
        admitted: backendFailureViewModel.requestLoad(),
      );

      await settleEditorRequest(
        admitted: backendFailureViewModel.requestAddAsset(),
      );

      expect(backendFailureViewModel.addAssetSnapshot.hasFailure, isTrue);
      expect(backendFailureViewModel.assets, const <AdminSubmissionAsset>[
        initialAsset,
      ]);
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
        await settleEditorRequest(admitted: viewModel.requestLoad());

        await settleEditorRequest(admitted: viewModel.requestAddAsset());

        expect(viewModel.addAssetSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestLoad());
        viewModel.setName('Modifica non salvata');

        await settleEditorRequest(
          admitted: viewModel.requestDeleteAsset(asset.id),
        );

        expect(viewModel.deleteAssetSnapshot.completed, isTrue);
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
          await settleEditorRequest(admitted: viewModel.requestLoad());

          await settleEditorRequest(
            admitted: viewModel.requestDeleteAsset(asset.id),
          );

          expect(viewModel.deleteAssetSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestLoad());

        viewModel.requestReject();
        expect(viewModel.rejectSnapshot.isRunning, isTrue);

        await settleEditorRequest(
          admitted: viewModel.requestPromote(AdminPromotionTarget.place),
        );
        await settleEditorRequest(admitted: viewModel.requestSave());
        await settleEditorRequest(admitted: viewModel.requestAddAsset());
        await settleEditorRequest(
          admitted: viewModel.requestDeleteAsset(asset.id),
        );

        expect(viewModel.promoteSnapshot.idle, isTrue);
        expect(viewModel.saveSnapshot.idle, isTrue);
        expect(viewModel.addAssetSnapshot.idle, isTrue);
        expect(viewModel.deleteAssetSnapshot.idle, isTrue);
        expect(repository.promoteCalls, isEmpty);
        expect(repository.updateIds, isEmpty);
        expect(repository.addAssetCalls, isEmpty);
        expect(repository.deleteAssetCalls, isEmpty);

        pendingReject.complete(const Result.success(null));
        await pumpEventQueue();
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
        await settleEditorRequest(admitted: viewModel.requestLoad());

        viewModel.requestPromote(AdminPromotionTarget.place);
        expect(viewModel.promoteSnapshot.isRunning, isTrue);

        await settleEditorRequest(admitted: viewModel.requestReject());
        await settleEditorRequest(admitted: viewModel.requestSave());
        await settleEditorRequest(admitted: viewModel.requestAddAsset());
        await settleEditorRequest(
          admitted: viewModel.requestDeleteAsset(asset.id),
        );

        expect(viewModel.rejectSnapshot.idle, isTrue);
        expect(viewModel.saveSnapshot.idle, isTrue);
        expect(viewModel.addAssetSnapshot.idle, isTrue);
        expect(viewModel.deleteAssetSnapshot.idle, isTrue);
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
        await pumpEventQueue();
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
        await settleEditorRequest(admitted: viewModel.requestLoad());

        await settleEditorRequest(admitted: viewModel.requestAddAsset());
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
        await pumpEventQueue();

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
        await settleEditorRequest(admitted: viewModel.requestLoad());

        await settleEditorRequest(admitted: viewModel.requestAddAsset());
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
        await pumpEventQueue();

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

          await settleEditorRequest(admitted: viewModel.requestLoad());

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

        await settleEditorRequest(admitted: viewModel.requestLoad());

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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.hasFailure, isTrue);
        expect(repository.createInputs, isEmpty);

        viewModel
          ..setLatitudeText('')
          ..setLongitudeText('14.64');
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: latitudeViewModel.requestSave());
        expect(latitudeViewModel.saveSnapshot.hasFailure, isTrue);

        latitudeViewModel
          ..setLatitudeText('-91')
          ..setLongitudeText('');
        await settleEditorRequest(admitted: latitudeViewModel.requestSave());
        expect(latitudeViewModel.saveSnapshot.hasFailure, isTrue);
        expect(repository.createInputs, isEmpty);

        final longitudeViewModel = createViewModel(repository: repository);
        addTearDown(longitudeViewModel.dispose);
        longitudeViewModel
          ..setCity('Isernia')
          ..setName('Museo')
          ..setLatitudeText('0')
          ..setLongitudeText('180.000001');
        await settleEditorRequest(admitted: longitudeViewModel.requestSave());
        expect(longitudeViewModel.saveSnapshot.hasFailure, isTrue);

        longitudeViewModel.setLongitudeText('-180.5');
        await settleEditorRequest(admitted: longitudeViewModel.requestSave());
        expect(longitudeViewModel.saveSnapshot.hasFailure, isTrue);
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
          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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
          await settleEditorRequest(admitted: viewModel.requestLoad());
          viewModel.setLatitudeText('41');

          await settleEditorRequest(
            admitted: viewModel.requestPromote(AdminPromotionTarget.place),
          );
          await settleEditorRequest(admitted: viewModel.requestReject());

          expect(viewModel.promoteSnapshot.hasFailure, isTrue);
          expect(viewModel.rejectSnapshot.hasFailure, isTrue);
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

        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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
          await settleEditorRequest(admitted: viewModel.requestLoad());

          viewModel.setName('Nuovo nome');
          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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
          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.completed, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestLoad());

        viewModel.setName('Solo nome');
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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
          await settleEditorRequest(admitted: viewModel.requestLoad());

          expect(viewModel.latitudeText, '41.5');
          expect(viewModel.longitudeText, '');
          expect(viewModel.isDirty, isFalse);

          await settleEditorRequest(admitted: viewModel.requestSave());

          expect(viewModel.saveSnapshot.hasFailure, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.completed, isTrue);
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
        await settleEditorRequest(admitted: viewModel.requestSave());

        expect(viewModel.saveSnapshot.hasFailure, isTrue);
        expect(repository.createInputs, isEmpty);
      });
    });
  });
}
