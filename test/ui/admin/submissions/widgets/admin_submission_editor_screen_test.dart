import 'dart:async' show Completer, unawaited;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:command_it/command_it.dart' as commands;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_recovery_panel.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../support/admin_moderation_error_cases.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_cache_manager.dart';
import '../../../../support/fake_image_picker.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/recording_tile_http_client.dart';

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'recovery comparison wraps complete field groups at width $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1500));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminSubmissionRecoveryPanel(
                  local: AdminDraftSnapshot(
                    name: 'Local name',
                    description: 'Full local description',
                    descriptionDelta: const [
                      {'insert': 'Full local description\n'},
                    ],
                    eventDates: EventDateDraft.unresolvedStart(
                      EventCalendarDate(2026, 10, 29),
                      endCalendarDate: EventCalendarDate(2026, 10, 30),
                    ),
                    city: 'Campobasso',
                    latitudeText: '-',
                    longitudeText: '14,5',
                  ),
                  remote: AdminDraftSnapshot(
                    name: 'Remote name',
                    description: 'Full remote description',
                    descriptionDelta: const [
                      {
                        'insert': 'Full remote description\n',
                        'attributes': {'bold': true},
                      },
                    ],
                    eventDates: EventDateDraft.exact(
                      startCalendarDate: EventCalendarDate(2026, 10, 31),
                      startInstantUtc: DateTime.utc(
                        2026,
                        10,
                        31,
                        12,
                        15,
                        20,
                        123,
                        456,
                      ),
                    ),
                    city: 'Isernia',
                    latitudeText: '41.0',
                    longitudeText: '14.0',
                  ),
                  status: AdminSubmissionStatus.pending,
                  onAccept: () {},
                  onKeep: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Full local description'), findsOneWidget);
        expect(find.text('Full remote description'), findsOneWidget);
        expect(
          find.text('Descrizione · formattazione differente'),
          findsOneWidget,
        );
        expect(find.textContaining('ora da definire'), findsOneWidget);
        expect(find.textContaining('13:15:20.123456'), findsOneWidget);
        expect(find.textContaining('Latitudine: -'), findsOneWidget);
        expect(find.textContaining('Longitudine: 14,5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('AdminSubmissionEditorScreen', () {
    late FakeAdminContentSubmissionRepository repository;
    late FakeContentSubmissionRepository contentSubmissionRepository;
    late FakeContentSubmissionDraftRepository draftRepository;
    late AdminSubmissionEditorViewModel viewModel;
    late GoRouter router;
    late Widget app;
    late StateSetter rebuildEditor;

    setUp(() {
      repository = FakeAdminContentSubmissionRepository();
      contentSubmissionRepository = FakeContentSubmissionRepository();
      draftRepository = FakeContentSubmissionDraftRepository();
      router = GoRouter(
        initialLocation: '/shell',
        routes: <RouteBase>[
          GoRoute(
            path: '/shell',
            builder: (_, _) => const Scaffold(body: Text('SHELL_MARKER')),
          ),
          GoRoute(
            path: '/editor',
            builder: (_, _) => StatefulBuilder(
              builder: (_, setState) {
                rebuildEditor = setState;
                return AdminSubmissionEditorScreen(viewModel: viewModel);
              },
            ),
          ),
        ],
      );
      app = MultiProvider(
        providers: <SingleChildWidget>[
          Provider<CacheManager>.value(value: FakeCacheManager()),
          Provider<http.Client>.value(value: RecordingTileHttpClient()),
          Provider<ContentSubmissionDraftRepository>.value(
            value: draftRepository,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          scaffoldMessengerKey: $scaffoldMessengerKey,
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('en'), Locale('it')],
        ),
      );
    });

    tearDown(() {
      router.dispose();
    });

    testOwnerUI(
      'manual lookup shows canonical targets and nonblocking warnings',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.update,
              eventId: 42,
            ),
          ),
        );
        repository.candidatesResult = Result.success(
          AdminEventCandidates(
            events: [const AdminEventCandidate(id: 43, name: 'Canonical')],
            pendingWarnings: [
              const AdminEventCandidate(id: 9, name: 'Pending'),
            ],
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('admin_event_search')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('admin_event_search')),
          'festa',
        );
        await tester.ensureVisible(find.text('Cerca eventi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cerca eventi'));
        await tester.pumpAndSettle();
        expect(repository.candidateCalls.single, (1, 'festa', null));
        expect(
          find.textContaining('Altro contributo in attesa: Pending'),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('admin_event_candidate_43')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('admin_event_candidate_43')),
        );
        await tester.pumpAndSettle();
        expect(viewModel.targetEventId, 43);
        final targetField = find.byKey(const ValueKey('admin_event_target'));
        expect(
          tester.widget<TextFormField>(targetField).controller!.text,
          '43',
        );
        await tester.enterText(targetField, '0044');
        expect(viewModel.targetEventId, 44);
        expect(
          tester.widget<TextFormField>(targetField).controller!.text,
          '0044',
        );
        expect(viewModel.isDirty, isFalse);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI(
      'merge shows overwrite and keep-current saves/reloads in place',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final group = AdminEventMergeGroup(
          name: 'location',
          providerChanged: true,
          moderatorChanged: false,
          apply: true,
          overwrite: true,
          base: {'city': 'Campobasso'},
          source: {'city': 'Campobasso'},
          moderated: {'city': 'Campobasso'},
          current: {'city': 'Termoli', 'latitude': '41.2', 'longitude': '14.3'},
        );
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.update,
              eventId: 42,
            ),
          ),
        );
        repository.previewResult = Result.success(
          AdminEventMergePreview(
            targetEventId: 42,
            submissionVersionToken: 's',
            eventVersionToken: 'e',
            groups: [group],
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        expect(viewModel.requestPreview(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        expect(find.text('location: applicato'), findsOneWidget);
        expect(find.textContaining('Sovrascrive modifiche'), findsOneWidget);
        await tester.ensureVisible(find.text('Mantieni valore attuale'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mantieni valore attuale'));
        await tester.pumpAndSettle();
        expect(repository.updateInputs.single.city, 'Termoli');
        final cityInput = find.descendant(
          of: find.widgetWithText(TextFormField, 'Città'),
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(cityInput).controller.text,
          'Termoli',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Luogo o evento'),
          'Edited after keep',
        );
        expect(viewModel.city, 'Termoli');
        expect(viewModel.name, 'Edited after keep');
        expect(viewModel.requestSave(), isTrue);
        await pumpCommandTurns(tester);
        expect(repository.updateInputs.last.city, 'Termoli');
        expect(repository.updateInputs.last.name, 'Edited after keep');
        expect(repository.previewCalls, hasLength(2));
      },
      disposeOwners: () => viewModel.dispose(),
    );

    for (final (code, status, text) in adminModerationErrorCases) {
      testOwnerUI('Link $code displays actionable feedback', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 2)),
        );
        repository.linkResult = Result.error(
          AdminContentSubmissionApiException(
            statusCode: status,
            code: code,
            message: 'Backend',
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        viewModel.selectTargetEvent(42);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Collega a evento'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Collega a evento'));
        await tester.pumpAndSettle();
        expect(find.textContaining(text), findsOneWidget);
        expect(find.text('SHELL_MARKER'), findsNothing);
      }, disposeOwners: () => viewModel.dispose());
    }

    for (final currentCity in <String?>[null, 'Isernia']) {
      testOwnerUI(
        'keep-current rehydrates city $currentCity without old form text',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 3000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final group = AdminEventMergeGroup(
            name: 'location',
            providerChanged: true,
            moderatorChanged: false,
            apply: true,
            overwrite: true,
            base: {},
            source: {},
            moderated: {},
            current: {'city': currentCity, 'latitude': null, 'longitude': null},
          );
          repository.getByIdResults[1] = Result.success(
            sampleAdminSubmission(
              startDate: DateTime.utc(2026, 10, 2),
              externalEvent: AdminExternalEvent(
                recordId: 12,
                snapshotHash: 'x',
                snapshotVersion: 1,
                snapshot: const {},
                mode: AdminExternalEventMode.update,
                eventId: 42,
              ),
            ),
          );
          repository.previewResult = Result.success(
            AdminEventMergePreview(
              targetEventId: 42,
              submissionVersionToken: 's',
              eventVersionToken: 'e',
              groups: [group],
            ),
          );
          viewModel = AdminSubmissionEditorViewModel(
            repository: repository,
            contentSubmissionRepository: contentSubmissionRepository,
            submissionId: 1,
          );
          expect(viewModel.requestLoad(), isTrue);
          await pumpCommandTurns(tester);
          expect(viewModel.requestPreview(), isTrue);
          await pumpCommandTurns(tester);
          await tester.pumpWidget(app);
          unawaited(router.push('/editor'));
          await tester.pumpAndSettle();
          expect(viewModel.requestKeepCurrent(group), isTrue);
          await pumpCommandTurns(tester);
          await tester.pumpAndSettle();
          final input = find.descendant(
            of: find.widgetWithText(TextFormField, 'Città'),
            matching: find.byType(EditableText),
          );
          expect(
            tester.widget<EditableText>(input).controller.text,
            currentCity ?? '',
          );
          expect(viewModel.city, currentCity);
          expect(repository.updateInputs.length, currentCity == null ? 0 : 1);
          expect(find.text('SHELL_MARKER'), findsNothing);
          if (currentCity != null) {
            final nameGroup = AdminEventMergeGroup(
              name: 'name',
              providerChanged: true,
              moderatorChanged: false,
              apply: true,
              overwrite: true,
              base: {},
              source: {},
              moderated: {},
              current: {'name': 'Canonical title'},
            );
            repository.previewResult = Result.success(
              AdminEventMergePreview(
                targetEventId: 42,
                submissionVersionToken: 'new',
                eventVersionToken: 'new',
                groups: [nameGroup],
              ),
            );
            expect(viewModel.requestPreview(), isTrue);
            await pumpCommandTurns(tester);
            expect(viewModel.requestKeepCurrent(nameGroup), isTrue);
            await pumpCommandTurns(tester);
            await tester.pumpAndSettle();
            final title = find.descendant(
              of: find.widgetWithText(TextFormField, 'Luogo o evento'),
              matching: find.byType(EditableText),
            );
            expect(
              tester.widget<EditableText>(title).controller.text,
              'Canonical title',
            );
            await tester.enterText(
              find.widgetWithText(TextFormField, 'Luogo o evento'),
              'New edit',
            );
            expect(viewModel.name, 'New edit');
            expect(viewModel.requestSave(), isTrue);
            await pumpCommandTurns(tester);
            expect(repository.updateInputs.last.name, 'New edit');
            expect(repository.updateInputs.last.city, currentCity);
          }
        },
        disposeOwners: () => viewModel.dispose(),
      );
    }

    testOwnerUI(
      'failed Link cannot mask the current Apply failure or start feedback',
      (tester) async {
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.update,
              eventId: 42,
              currentHash: 'y',
              currentSnapshot: const {},
            ),
          ),
        );
        repository
          ..linkResult = const Result.error(
            AdminContentSubmissionApiException(
              statusCode: 409,
              code: 'SOURCE_CHANGED',
              message: 'Changed source',
            ),
          )
          ..previewResult = Result.success(
            AdminEventMergePreview(
              targetEventId: 42,
              submissionVersionToken: 's',
              eventVersionToken: 'e',
              groups: [],
            ),
          );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        expect(viewModel.requestLink(42), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('La fonte è cambiata'), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(viewModel.requestPreview(), isTrue);
        await pumpCommandTurns(tester);
        final pending = Completer<Result<AdminEventResolution>>();
        repository.pendingApply = pending;
        expect(viewModel.requestApply(), isTrue);
        await tester.pump();
        expect(find.textContaining('La fonte è cambiata'), findsNothing);
        pending.complete(
          const Result.error(
            AdminContentSubmissionApiException(
              statusCode: 409,
              code: 'EVENT_CHANGED',
              message: 'Changed Event',
            ),
          ),
        );
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('I dati sono cambiati'), findsOneWidget);
        expect(find.textContaining('La fonte è cambiata'), findsNothing);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI(
      'imported Reject explains revision discard and forwards ignore plus '
      'stale acknowledgement',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {'name': 'X'},
              mode: AdminExternalEventMode.create,
              currentHash: 'y',
              currentSnapshot: const {'name': 'Current Y'},
            ),
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        expect(find.text('Nome: Current Y'), findsOneWidget);
        expect(find.textContaining('La proposta è precedente'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Rifiuta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rifiuta'));
        await tester.pumpAndSettle();
        expect(find.textContaining('esaminata e scartata'), findsOneWidget);
        expect(find.textContaining('soppresse finché'), findsOneWidget);
        await tester.tap(
          find.text('Ignora anche le revisioni future della fonte'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
        await tester.pumpAndSettle();
        expect(repository.sourceOptions.single, ('reject', true, true, 'y'));
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI(
      'source_changed displays fresh source and requires a new explicit '
      'selection',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.create,
              currentHash: 'y',
              currentSnapshot: const {'name': 'Y'},
            ),
          ),
        );
        repository.linkResult = const Result.error(
          AdminContentSubmissionApiException(
            statusCode: 409,
            code: 'SOURCE_CHANGED',
            message: 'Changed',
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        viewModel.selectTargetEvent(42);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.create,
              currentHash: 'z',
              currentSnapshot: const {'name': 'Z'},
            ),
          ),
        );
        await tester.ensureVisible(find.text('Collega a evento'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Collega a evento'));
        await tester.pumpAndSettle();
        expect(repository.sourceOptions.single.$4, 'y');
        expect(find.text('Nome: Z'), findsOneWidget);
        expect(find.textContaining('La fonte è cambiata'), findsOneWidget);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('admin_acknowledge_current_source')),
              )
              .value,
          isFalse,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        repository.linkResult = const Result.success(
          AdminEventResolution(outcome: 'linked', eventId: 42),
        );
        viewModel.selectTargetEvent(42);
        expect(viewModel.requestLink(42), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(repository.sourceOptions.last.$4, 'z');
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI('non-stale imported Event cannot remove Event mode and has no '
        'acknowledgement action', (tester) async {
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          startDate: DateTime.utc(2026, 10, 2),
          externalEvent: AdminExternalEvent(
            recordId: 12,
            snapshotHash: 'x',
            snapshotVersion: 1,
            snapshot: const {},
            mode: AdminExternalEventMode.create,
            currentHash: 'x',
            currentSnapshot: const {},
          ),
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin_acknowledge_current_source')),
        findsNothing,
      );
      final row = find
          .ancestor(of: find.text('È un evento?'), matching: find.byType(Row))
          .first;
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .onChanged,
        isNull,
      );
      viewModel.setEventEnabled(enabled: false);
      expect(viewModel.startDate, isNotNull);
      expect(viewModel.isDirty, isFalse);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI(
      'imported Save backend Event-readiness rejection preserves editor and '
      'shows action',
      (tester) async {
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.create,
            ),
          ),
        );
        repository.updateResult = const Result.error(
          AdminContentSubmissionApiException(
            statusCode: 422,
            code: 'START_DATE_REQUIRED',
            message: 'Start required',
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        viewModel.setName('Edited');
        expect(viewModel.requestSave(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Imposta una data di inizio'),
          findsOneWidget,
        );
        expect(find.text('SHELL_MARKER'), findsNothing);
        expect(viewModel.isDirty, isTrue);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    for (final mode in AdminExternalEventMode.values) {
      testOwnerUI('imported $mode offers correct resolution choices', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            startDate: DateTime.utc(2026, 10, 2),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'x',
              snapshotVersion: 1,
              snapshot: const {'name': 'Source'},
              mode: mode,
              eventId: mode == AdminExternalEventMode.update ? 42 : null,
            ),
          ),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        expect(find.text('Collega a evento'), findsOneWidget);
        expect(
          find.text('Pubblica come evento'),
          mode == AdminExternalEventMode.create ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Anteprima aggiornamento'),
          mode == AdminExternalEventMode.update ? findsOneWidget : findsNothing,
        );
      }, disposeOwners: () => viewModel.dispose());
    }

    testOwnerUI('rehydrates date-only and toggle off requests a new clock', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          allDay: true,
          startDate: DateTime.utc(2026, 3, 28, 23),
          endDate: DateTime.utc(2026, 3, 30, 21, 59, 59, 999, 999),
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      expect(viewModel.allDay, isTrue);
      expect(viewModel.isDirty, isFalse);
      expect(find.text('Senza orario'), findsOneWidget);
      expect(find.textContaining('Inizia alle'), findsNothing);
      final toggle = find.descendant(
        of: find.widgetWithText(Row, 'Senza orario'),
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(viewModel.allDay, isFalse);
      expect(viewModel.startClockTime, isNull);
      expect(viewModel.endCalendarDate, EventCalendarDate(2026, 3, 30));
      expect(find.text('Seleziona ora di inizio'), findsOneWidget);
      expect(find.textContaining('00:00'), findsNothing);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI(
      'renders the shared create fields with the local asset section',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          creatorName: 'Redattore',
          creatorEmail: 'redattore@example.com',
        );
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();

        expect(find.text('Nuovo contributo'), findsOneWidget);
        expect(find.text('Categoria'), findsOneWidget);
        expect(find.text('Dettagli'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Città'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Luogo o evento'),
          findsOneWidget,
        );
        expect(find.text('È un evento?'), findsOneWidget);
        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, 'Crea contributo'),
          200,
          scrollable: scrollable,
        );
        expect(
          find.widgetWithText(FilledButton, 'Crea contributo'),
          findsOneWidget,
        );
        expect(find.text('Foto'), findsOneWidget);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI('shows creator identity read-only without public fields', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        creatorName: 'Redattore',
        creatorEmail: 'redattore@example.com',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Creato come Redattore · redattore@example.com'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.text('Creato come Redattore · redattore@example.com'),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Creato come Redattore · redattore@example.com'),
          matching: find.byType(SentryMask),
        ),
        findsNothing,
      );
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Autore'), findsNothing);
      expect(find.byType(CheckboxFormField), findsNothing);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('shows loaded edit details, assets, count, and add control', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          userName: 'Anna Bianchi',
          userEmail: 'anna@example.com',
          assets: <AdminSubmissionAsset>[asset],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Modifica contributo'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Foto'),
        200,
        scrollable: scrollable,
      );
      expect(find.byType(AppNetworkImage), findsOneWidget);
      final renderedAsset = tester.widget<AppNetworkImage>(
        find.byType(AppNetworkImage),
      );
      expect(renderedAsset.imageWidth, asset.width);
      expect(renderedAsset.imageHeight, asset.height);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_asset_2')),
        findsOneWidget,
      );
      expect(find.text('1 / 5'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsOneWidget,
      );
      expect(find.byTooltip('Rimuovi foto'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('anna@example.com'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Proposto da'), findsOneWidget);
      expect(find.text('Anna Bianchi'), findsOneWidget);
      expect(find.text('anna@example.com'), findsOneWidget);
      for (final value in ['Anna Bianchi', 'anna@example.com']) {
        expect(
          find.ancestor(
            of: find.text(value),
            matching: find.byType(SentryMask),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.ancestor(
          of: find.byType(AppNetworkImage),
          matching: find.byType(SentryMask),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Proposto da'),
          matching: find.byType(SentryMask),
        ),
        findsNothing,
      );
    }, disposeOwners: () => viewModel.dispose());

    for (final status in [
      AdminSubmissionStatus.accepted,
      AdminSubmissionStatus.rejected,
    ]) {
      testOwnerUI('finalized $status keeps contributor identities masked', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(status: status),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('mario@example.com'),
          200,
          scrollable: scrollable,
        );
        for (final identity in ['Mario Rossi', 'mario@example.com']) {
          expect(
            find.ancestor(
              of: find.text(identity),
              matching: find.byType(SentryMask),
            ),
            findsOneWidget,
          );
        }
        expect(find.text('Proposto da'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, disposeOwners: () => viewModel.dispose());
    }

    testOwnerUI('unfocuses the editor before opening the asset picker', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingPicker = Completer<XFile?>();
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        imagePicker: FakeImagePicker(onPickImage: () => pendingPicker.future),
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final cityField = find.widgetWithText(TextFormField, 'Città');
      await tester.tap(cityField);
      await tester.pump();
      final cityEditable = find.descendant(
        of: cityField,
        matching: find.byType(EditableText),
      );
      final cityFocusNode = tester.widget<EditableText>(cityEditable).focusNode;
      expect(FocusManager.instance.primaryFocus, same(cityFocusNode));

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final addAsset = find.byKey(
        const ValueKey<String>('admin_submission_add_asset'),
      );
      await tester.scrollUntilVisible(addAsset, 200, scrollable: scrollable);
      expect(FocusManager.instance.primaryFocus, same(cityFocusNode));

      await tester.tap(addAsset);
      await tester.pump();

      expect(viewModel.addAssetSnapshot.isRunning, isTrue);
      expect(FocusManager.instance.primaryFocus, isNot(same(cityFocusNode)));
      // A keyboard event arriving after the picker starts cannot mutate the
      // draft while the editor's focus barrier is active.
      await tester.enterText(cityField, 'Changed while picking');
      expect(viewModel.city, 'Campobasso');

      pendingPicker.complete(null);
      await tester.pumpAndSettle();
      expect(viewModel.addAssetSnapshot.completed, isTrue);

      final restoredFocusNode =
          tester.widget<EditableText>(cityEditable).focusNode..requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(restoredFocusNode));
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('never loads or saves the public draft after field edits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        'Museo del Tartufo',
      );
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));

      expect(draftRepository.loadDraftCallCount, 0);
      expect(draftRepository.saveDraftCallCount, 0);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('shows an empty pending photo section with an add control', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsOneWidget,
      );
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('hides add control at the pending asset limit', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          assets: List<AdminSubmissionAsset>.generate(
            5,
            (index) => AdminSubmissionAsset(
              id: index + 1,
              url: 'https://example.com/photo-$index.jpg',
              width: 640,
              height: 480,
            ),
          ),
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNWidgets(5));
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('confirms deletion before removing an asset association', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final deleteAsset = find.byTooltip('Rimuovi foto');
      await tester.tap(deleteAsset);
      await tester.pumpAndSettle();
      expect(
        find.text('Rimuovere questa foto dal suggerimento?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();
      expect(repository.deleteAssetCalls, isEmpty);

      await tester.tap(deleteAsset);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.deleteAssetCalls, <(int, int)>[(1, 2)]);
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNothing);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('shows a generic error snackbar for add and delete failures', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.accepted,
          assets: const <AdminSubmissionAsset>[asset],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(viewModel.requestAddAsset(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pump();
      expect(viewModel.addAssetSnapshot.hasFailure, isTrue);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();

      expect(viewModel.requestDeleteAsset(2), isTrue);
      await pumpCommandTurns(tester);
      await tester.pump();
      expect(viewModel.deleteAssetSnapshot.hasFailure, isTrue);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI(
      'disables asset, save, and moderation controls while deleting',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pendingDelete = Completer<Result<void>>();
        const asset = AdminSubmissionAsset(
          id: 2,
          url: 'https://example.com/photo.jpg',
          width: 640,
          height: 480,
        );
        repository
          ..getByIdResults[1] = Result.success(
            sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
          )
          ..pendingDeleteAsset = pendingDelete;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();

        expect(viewModel.requestDeleteAsset(2), isTrue);
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('admin_submission_add_asset')),
          findsNothing,
        );
        expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
        final removeControl = find.descendant(
          of: find.byType(ContentSubmissionAssetListItem),
          matching: find.byType(InkWell),
        );
        expect(tester.widget<InkWell>(removeControl).onTap, isNull);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Salva modifiche'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pubblica come luogo'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Rifiuta'),
              )
              .onPressed,
          isNull,
        );

        pendingDelete.complete(const Result.success(null));
        await tester.pumpAndSettle();
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI('keeps entered text after an asset mutation rebuild', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );

      expect(viewModel.requestDeleteAsset(2), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();

      expect(find.text('Isernia'), findsOneWidget);
      expect(viewModel.city, 'Isernia');
      expect(viewModel.isDirty, isTrue);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('disables publish and reject after edits and saves '
        'separately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        200,
        scrollable: scrollable,
      );
      final publishButton = find.widgetWithText(
        FilledButton,
        'Pubblica come luogo',
      );
      final rejectButton = find.widgetWithText(FilledButton, 'Rifiuta');
      expect(tester.widget<FilledButton>(publishButton).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNotNull);
      expect(find.text('Accetta'), findsNothing);

      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Città'),
        200,
        scrollable: scrollable,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        publishButton,
        200,
        scrollable: scrollable,
      );
      expect(tester.widget<FilledButton>(publishButton).onPressed, isNull);
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNull);
      expect(
        find.text('Salva le modifiche prima di pubblicare o rifiutare.'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pumpAndSettle();

      expect(repository.updateIds, <int>[1]);
      expect(find.text('SHELL_MARKER'), findsNothing);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('requires a concrete saved category before publication', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(category: ContentCategory.unknown),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final publish = find.widgetWithText(FilledButton, 'Pubblica come luogo');
      await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);

      final reject = find.widgetWithText(FilledButton, 'Rifiuta');
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);
      expect(tester.widget<FilledButton>(reject).onPressed, isNotNull);
      expect(
        find.text('Seleziona una categoria e salva prima di pubblicare.'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(InputChip, 'Natura'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(InputChip, 'Natura'));
      await tester.pump();

      await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);
      expect(tester.widget<FilledButton>(reject).onPressed, isNull);
      expect(
        find.text('Salva le modifiche prima di pubblicare o rifiutare.'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pumpAndSettle();

      expect(repository.updateInputs.single.category, ContentCategory.nature);
      expect(viewModel.isDirty, isFalse);
      expect(find.text('SHELL_MARKER'), findsNothing);

      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);
      expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(reject).onPressed, isNotNull);
      expect(
        find.text('Seleziona una categoria e salva prima di pubblicare.'),
        findsNothing,
      );
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('disables moderation while a save request is pending', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingUpdate = Completer<Result<AdminSubmission>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingUpdate = pendingUpdate;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Pubblica come luogo'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Rifiuta'))
            .onPressed,
        isNull,
      );
      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await tester.pumpAndSettle();
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('does not auto-confirm publication when save completes '
        'during confirmation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingUpdate = Completer<Result<AdminSubmission>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingUpdate = pendingUpdate;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final publish = find.widgetWithText(FilledButton, 'Pubblica come luogo');
      await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);

      await tester.tap(publish);
      await tester.pump();
      expect(
        find.text('Confermi di voler pubblicare questo contributo come luogo?'),
        findsOneWidget,
      );

      expect(viewModel.requestSave(), isTrue);
      await tester.pump();
      expect(viewModel.saveSnapshot.isRunning, isTrue);
      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await tester.pumpAndSettle();

      expect(
        find.text('Confermi di voler pubblicare questo contributo come luogo?'),
        findsOneWidget,
      );
      expect(repository.promoteCalls, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();

      // Save completes under the dialog without closing the editor:
      // refreshes the dashboard instead of running a stale moderation.
      expect(repository.promoteCalls, isEmpty);
      expect(find.text('SHELL_MARKER'), findsNothing);
    }, disposeOwners: () => viewModel.dispose());

    for (final dialogAction in ['Annulla', 'Conferma']) {
      testOwnerUI('does not run a stale rejection when save completes '
          'during its confirmation ($dialogAction)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pendingUpdate = Completer<Result<AdminSubmission>>();
        repository
          ..getByIdResults[1] = Result.success(sampleAdminSubmission())
          ..pendingUpdate = pendingUpdate;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        final reject = find.widgetWithText(FilledButton, 'Rifiuta');
        await tester.scrollUntilVisible(reject, 200, scrollable: scrollable);

        await tester.tap(reject);
        await tester.pump();
        expect(
          find.text('Confermi di voler rifiutare questo contributo?'),
          findsOneWidget,
        );

        expect(viewModel.requestSave(), isTrue);
        await tester.pump();
        expect(viewModel.saveSnapshot.isRunning, isTrue);
        pendingUpdate.complete(Result.success(sampleAdminSubmission()));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(
            dialogAction == 'Conferma' ? FilledButton : TextButton,
            dialogAction,
          ),
        );
        await tester.pumpAndSettle();

        expect(repository.rejectIds, isEmpty);
        expect(find.text('SHELL_MARKER'), findsNothing);
      }, disposeOwners: () => viewModel.dispose());
    }

    testOwnerUI('rechecks busy state before confirming publication', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingPick = Completer<XFile?>();
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        imagePicker: FakeImagePicker(onPickImage: () => pendingPick.future),
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final publish = find.widgetWithText(FilledButton, 'Pubblica come luogo');
      await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);
      await tester.tap(publish);
      await tester.pumpAndSettle();

      expect(viewModel.requestAddAsset(), isTrue);
      await tester.pump();
      expect(viewModel.addAssetSnapshot.isRunning, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pump();

      expect(repository.promoteCalls, isEmpty);
      pendingPick.complete(null);
      await tester.pumpAndSettle();
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('disables save while a rejection request is pending', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingReject = Completer<Result<void>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingReject = pendingReject;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(viewModel.requestReject(), isTrue);
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salva modifiche'),
            )
            .onPressed,
        isNull,
      );
      pendingReject.complete(const Result.success(null));
      await tester.pumpAndSettle();
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI(
      'keeps edited data on save failure and shows an error snackbar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository
          ..getByIdResults[1] = Result.success(sampleAdminSubmission())
          ..updateResult = Result.error(TestException('update failed'));
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Città'),
          'Isernia',
        );
        await tester.pump();

        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, 'Salva modifiche'),
          200,
          scrollable: scrollable,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
        await tester.pumpAndSettle();

        expect(
          find.text('Si è verificato un errore, riprova più tardi'),
          findsOneWidget,
        );
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(viewModel.city, 'Isernia');
        $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
      },
      disposeOwners: () => viewModel.dispose(),
    );

    testOwnerUI('rejects a clean submission only after confirmation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Rifiuta'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Rifiuta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Confermi di voler rifiutare questo contributo?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();

      expect(repository.rejectIds, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Rifiuta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.rejectIds, <int>[1]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('publishes a place draft after explicit confirmation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        200,
        scrollable: scrollable,
      );
      // A place draft offers exactly one publication CTA.
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        findsNothing,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Confermi di voler pubblicare questo contributo come luogo?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
        (1, AdminPromotionTarget.place),
      ]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('publishes an event draft as an event', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          startDate: DateTime.utc(2026, 9, 20, 10),
          endDate: DateTime.utc(2026, 9, 20, 12),
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Confermi di voler pubblicare questo contributo come evento?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
        (1, AdminPromotionTarget.event),
      ]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('keeps event publication CTA and renders a temporal issue', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(startDate: DateTime.utc(2026, 3, 29, 0, 30)),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      viewModel.setStartClockTime(EventClockTime(2, 30));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.textContaining('non esiste in Italia'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        findsNothing,
      );
    }, disposeOwners: () => viewModel.dispose());

    group('promotion error messages', () {
      Future<void> pumpPendingEditor(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
      }

      testOwnerUI('maps readiness codes to actionable Italian copy', (
        tester,
      ) async {
        for (final entry in <(String?, String)>[
          (
            'PROMOTION_COORDINATES_REQUIRED',
            'Imposta coordinate valide e salva prima di pubblicare.',
          ),
          (
            'PROMOTION_CITY_NOT_FOUND',
            'La città non corrisponde a una località disponibile. '
                'Correggila e salva.',
          ),
          (
            'PROMOTION_START_DATE_REQUIRED',
            "Imposta una data di inizio e salva prima di pubblicare l'evento.",
          ),
          (
            'PROMOTION_TARGET_CONFLICT',
            'Il contributo è già stato pubblicato con un tipo diverso.',
          ),
          (
            'PROMOTION_CATEGORY_REQUIRED',
            'Seleziona una categoria e salva prima di pubblicare.',
          ),
        ]) {
          await pumpPendingEditor(tester);
          repository.promoteResults
            ..clear()
            ..add(
              Result.error(
                AdminContentSubmissionApiException(
                  statusCode: entry.$1 == 'PROMOTION_TARGET_CONFLICT'
                      ? 409
                      : 422,
                  code: entry.$1,
                  message: 'API failure',
                ),
              ),
            );

          expect(viewModel.requestPromote(AdminPromotionTarget.place), isTrue);
          await pumpCommandTurns(tester);
          await tester.pump();

          expect(find.text(entry.$2), findsOneWidget);
          $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
          router.go('/shell');
          await tester.pumpAndSettle();
        }
      }, disposeOwners: () => viewModel.dispose());
    });

    testOwnerUI('renders promoted accepted rows read-only with linkage', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.accepted,
          promotion: const AdminSubmissionPromotion(
            target: AdminPromotionTarget.event,
            entityId: 123,
          ),
          assets: const <AdminSubmissionAsset>[
            AdminSubmissionAsset(
              id: 2,
              url: 'https://example.com/photo.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Accettato'), findsOneWidget);
      expect(find.text('Pubblicato come evento · ID 123'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
      expect(find.byTooltip('Rimuovi foto'), findsNothing);
      // No moderation or Save controls remain.
      expect(find.widgetWithText(FilledButton, 'Accetta'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Rifiuta'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        findsNothing,
      );

      // Attempted interaction leaves the ViewModel untouched: the tap is
      // suppressed by the pointer barrier, so no state can change.
      final cityField = find.widgetWithText(TextFormField, 'Città');
      expect(cityField, findsOneWidget);
      await tester.tap(cityField, warnIfMissed: false);
      await tester.pump();

      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');
      // Requesting focus on the locked field cannot make it primary.
      final lockedNode = _requestFocusOn(tester, cityField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(equals(lockedNode)));
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('excludes keyboard focus from locked fields while busy', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingDelete = Completer<Result<void>>();
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository
        ..getByIdResults[1] = Result.success(
          sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
        )
        ..pendingDeleteAsset = pendingDelete;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(viewModel.requestDeleteAsset(2), isTrue);
      await tester.pump();
      expect(viewModel.deleteAssetSnapshot.isRunning, isTrue);

      final cityField = find.widgetWithText(TextFormField, 'Città');
      // While locked, requesting focus on an inner field never makes it the
      // primary focus.
      final lockedNode = _requestFocusOn(tester, cityField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(equals(lockedNode)));
      expect(viewModel.isDirty, isFalse);

      pendingDelete.complete(const Result.success(null));
      await tester.pumpAndSettle();

      // Unlocked again, the same request focuses the field normally.
      final unlockedNode = _requestFocusOn(tester, cityField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, equals(unlockedNode));
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('keeps drafts locked while a save is running and restores '
        'interaction afterwards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingUpdate = Completer<Result<AdminSubmission>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingUpdate = pendingUpdate;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );

      expect(viewModel.requestSave(), isTrue);
      await tester.pump();

      // Tapping the city field while saving cannot dirty the editor.
      await tester.tap(
        find.widgetWithText(TextFormField, 'Città'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');

      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await tester.pumpAndSettle();
      // Save keeps the editor open for further edits.
      expect(find.text('SHELL_MARKER'), findsNothing);
    }, disposeOwners: () => viewModel.dispose());
    testOwnerUI('renders historical accepted rows read-only without Save', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.accepted,
          assets: const <AdminSubmissionAsset>[
            AdminSubmissionAsset(
              id: 2,
              url: 'https://example.com/photo.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Accettato'), findsOneWidget);
      // Historical accepted rows carry no durable link and none is invented.
      expect(find.text('Pubblicato come evento · ID 123'), findsNothing);
      expect(find.textContaining('Pubblicato come'), findsNothing);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
      expect(find.byTooltip('Rimuovi foto'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Accetta'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Rifiuta'), findsNothing);
      // The Save control is hidden entirely for read-only rows.
      expect(find.text('Salva modifiche'), findsNothing);

      // Attempted interaction leaves the ViewModel untouched.
      await tester.tap(
        find.widgetWithText(TextFormField, 'Città'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('renders rejected rows read-only without Save', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.rejected,
          assets: const <AdminSubmissionAsset>[
            AdminSubmissionAsset(
              id: 2,
              url: 'https://example.com/photo.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      expect(viewModel.requestLoad(), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Rifiutato'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
      expect(find.byTooltip('Rimuovi foto'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Accetta'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Rifiuta'), findsNothing);
      expect(find.text('Salva modifiche'), findsNothing);

      // Attempted interaction leaves the ViewModel untouched.
      await tester.tap(
        find.widgetWithText(TextFormField, 'Città'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('shows the profile-specific create failure message', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.createResult = const Result.error(
        AdminContentSubmissionApiException(
          statusCode: 422,
          code: 'ADMIN_PROFILE_INCOMPLETE',
          message: 'Profile is incomplete.',
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
      );
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        'Palazzo',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crea contributo'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Il profilo amministratore richiede un nome e un'email validi.",
        ),
        findsOneWidget,
      );
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI('blocks an incomplete event save with a date-section issue', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel =
          AdminSubmissionEditorViewModel(
              repository: repository,
              contentSubmissionRepository: contentSubmissionRepository,
            )
            ..setCity('Isernia')
            ..setName('Sagra del Tartufo')
            ..setEventEnabled(enabled: true);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Crea contributo'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crea contributo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Seleziona una data di inizio.'),
        -200,
        scrollable: scrollable,
      );

      expect(find.text('Seleziona una data di inizio.'), findsOneWidget);
      expect(viewModel.eventTimeIssue, EventTimeIssue.missingStartDate);
      expect(repository.createInputs, isEmpty);
      expect(viewModel.saveSnapshot.data, isNull);
    }, disposeOwners: () => viewModel.dispose());

    testOwnerUI(
      'cancelling an inverted end-date picker preserves the invalid draft',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final originalStart = DateTime.utc(2027, 1, 1, 10);
        final originalEnd = DateTime.utc(2026, 12, 31, 22, 59, 59, 999, 999);
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(startDate: originalStart, endDate: originalEnd),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();

        final endDateChip = find.textContaining('Finisce il');
        await tester.tap(endDateChip);
        await tester.pump();
        expect(find.byType(DatePickerDialog), findsOneWidget);

        var pickerActions = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextButton),
        );
        expect(pickerActions, findsNWidgets(2));
        await tester.tap(pickerActions.first);
        await tester.pumpAndSettle();

        expect(viewModel.startDate, originalStart);
        expect(viewModel.endDate, originalEnd);
        expect(viewModel.isDirty, isFalse);
        expect(repository.updateInputs, isEmpty);
        expect(viewModel.validateEventTimeForSave(), isFalse);
        expect(viewModel.eventTimeIssue, EventTimeIssue.invalidRange);
        expect(viewModel.requestSave(), isTrue);
        await pumpCommandTurns(tester);
        expect(repository.updateInputs, isEmpty);

        await tester.tap(endDateChip);
        await tester.pump();
        pickerActions = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextButton),
        );
        await tester.tap(pickerActions.last);
        await tester.pumpAndSettle();

        expect(viewModel.endCalendarDate, EventCalendarDate(2027, 1, 1));
        expect(viewModel.endDate!.isBefore(viewModel.startDate!), isFalse);
        expect(viewModel.eventTimeIssue, isNull);
        expect(viewModel.isDirty, isTrue);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    for (final retrySucceeds in [false, true]) {
      testOwnerUI('Save receipts isolate dialog effects across success/error'
          '${retrySucceeds ? '/success' : ' on a clean draft (DF1)'}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        final routeResult = router.push<bool>('/editor');
        var pops = 0;
        bool? returned;
        unawaited(
          routeResult.then((value) {
            pops++;
            returned = value;
          }),
        );
        await tester.pumpAndSettle();
        final publish = find.widgetWithText(
          FilledButton,
          'Pubblica come luogo',
        );
        await tester.ensureVisible(publish);
        await tester.tap(publish);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        final first = Completer<Result<AdminSubmission>>();
        repository.pendingUpdate = first;
        expect(viewModel.requestSave(), isTrue);
        final firstId = viewModel.saveExecutionId;
        await pumpCommandTurns(tester);
        first.complete(Result.success(sampleAdminSubmission()));
        await tester.pumpAndSettle();
        expect(pops, 0);

        if (retrySucceeds) viewModel.setCity('Termoli');
        final second = Completer<Result<AdminSubmission>>();
        repository.pendingUpdate = second;
        expect(viewModel.requestSave(), isTrue);
        final secondId = viewModel.saveExecutionId;
        expect(secondId, greaterThan(firstId!));
        await pumpCommandTurns(tester);
        second.complete(Result.error(TestException('second save failed')));
        await tester.pumpAndSettle();
        expect(viewModel.saveSnapshot.hasFailure, isTrue);
        expect(pops, 0);
        expect(
          find.text('Si è verificato un errore, riprova più tardi'),
          findsOneWidget,
        );
        $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
        await tester.pumpAndSettle();
        viewModel.setCandidateSearch('unrelated notification');
        await tester.pumpAndSettle();
        expect(
          find.text('Si è verificato un errore, riprova più tardi'),
          findsNothing,
        );

        if (retrySucceeds) {
          final third = Completer<Result<AdminSubmission>>();
          repository.pendingUpdate = third;
          expect(viewModel.requestSave(), isTrue);
          expect(viewModel.saveExecutionId, greaterThan(secondId!));
          await pumpCommandTurns(tester);
          third.complete(Result.success(sampleAdminSubmission()));
          await tester.pumpAndSettle();
          expect(pops, 0);
        } else {
          expect(viewModel.isDirty, isFalse);
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
        await tester.pumpAndSettle();
        expect(repository.promoteCalls, isEmpty);
        expect(repository.rejectIds, isEmpty);
        expect(pops, 0);
        expect(returned, isNull);
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        await pumpCommandTurns(tester);
        expect(pops, 0);
        expect(tester.takeException(), isNull);
      }, disposeOwners: () => viewModel.dispose());
    }

    testOwnerUI(
      'candidate input survives same-owner rebuild and rebinds to new owner',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(startDate: DateTime.utc(2026, 10, 2)),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('admin_event_search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'query A');
        expect(viewModel.candidateSearch, 'query A');
        viewModel.selectTargetEvent(42);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: search, matching: find.text('query A')),
          findsOneWidget,
        );
        final oldOwner = viewModel;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        viewModel.setCandidateSearch('query B');
        oldOwner.dispose();
        rebuildEditor(() {});
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: search, matching: find.text('query B')),
          findsOneWidget,
        );
        expect(viewModel.candidateSearch, 'query B');
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => viewModel.dispose(),
    );

    for (final outcome in ['success', 'expected error', 'raw error']) {
      testOwnerUI('binding seeds old terminal and replacement ignores '
          'late owner $outcome completion', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final detailedStackTraces = commands.Command.detailedStackTraces;
        commands.Command.detailedStackTraces = false;
        addTearDown(() {
          commands.Command.detailedStackTraces = detailedStackTraces;
        });
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        expect(viewModel.requestSave(), isTrue);
        await pumpCommandTurns(tester);
        expect(viewModel.saveSnapshot.completed, isTrue);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        final oldOwner = viewModel;
        final oldUpdate = Completer<Result<AdminSubmission>>();
        repository.pendingUpdate = oldUpdate;
        expect(oldOwner.requestSave(), isTrue);
        await pumpCommandTurns(tester);
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        oldOwner.dispose();
        rebuildEditor(() {});
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 50));
        final runtimeError = StateError('old owner runtime');
        final runtimeStack = StackTrace.fromString('old owner stack');
        switch (outcome) {
          case 'success':
            oldUpdate.complete(Result.success(sampleAdminSubmission()));
          case 'expected error':
            oldUpdate.complete(Result.error(TestException('old owner failed')));
          case 'raw error':
            oldUpdate.completeError(runtimeError, runtimeStack);
        }
        await tester.pumpAndSettle();
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(viewModel.saveSnapshot.idle, isTrue);
        expect(logger.calls, hasLength(outcome == 'raw error' ? 1 : 0));
        if (outcome == 'raw error') {
          expect(logger.calls.single.error, same(runtimeError));
          expect(logger.calls.single.stackTrace, same(runtimeStack));
        }
        expect(
          find.text('Si è verificato un errore, riprova più tardi'),
          findsNothing,
        );
        repository.pendingUpdate = null;
        expect(viewModel.requestSave(), isTrue);
        await tester.pumpAndSettle();
        expect(find.text('SHELL_MARKER'), findsNothing);
        expect(tester.takeException(), isNull);
      }, disposeOwners: () => viewModel.dispose());
    }

    for (final action in ['Pubblica come luogo', 'Rifiuta']) {
      testOwnerUI('owner replacement invalidates an open $action dialog', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        final control = find.widgetWithText(FilledButton, action);
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final obsoleteConfirmation = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Conferma'))
            .onPressed!;
        final oldOwner = viewModel;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        oldOwner.dispose();
        rebuildEditor(() {});
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        obsoleteConfirmation();
        await tester.pumpAndSettle();
        expect(repository.promoteCalls, isEmpty);
        expect(repository.rejectIds, isEmpty);
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(viewModel.saveSnapshot.idle, isTrue);
        expect(tester.takeException(), isNull);
      }, disposeOwners: () => viewModel.dispose());
    }

    group('location section', () {
      Finder scrollableOf(WidgetTester tester) => find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;

      Future<void> pushEditor(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
      }

      Future<void> scrollTo(WidgetTester tester, Finder finder) => tester
          .scrollUntilVisible(finder, 200, scrollable: scrollableOf(tester));

      testOwnerUI('create screen exposes the Posizione section', (
        tester,
      ) async {
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          creatorName: 'Redattore',
          creatorEmail: 'redattore@example.com',
        );
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        expect(find.text('Posizione'), findsOneWidget);
        expect(find.text('Mappa'), findsOneWidget);
        expect(find.text('Coordinate'), findsOneWidget);
        expect(find.byType(GeoMap), findsOneWidget);
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('edit screen exposes the Posizione section after load', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        expect(find.text('Posizione'), findsOneWidget);
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('loaded coordinates reach the location editor fields', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(latitude: 41.5575078, longitude: 14.6485406),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await pushEditor(tester);

        final latitudeField = find.widgetWithText(
          TextFormField,
          '41.5575078',
          skipOffstage: false,
        );
        final longitudeField = find.widgetWithText(
          TextFormField,
          '14.6485406',
          skipOffstage: false,
        );
        expect(latitudeField, findsOneWidget);
        expect(longitudeField, findsOneWidget);
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('mode switching alone does not dirty the editor', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mappa'));
        await tester.pumpAndSettle();

        expect(viewModel.isDirty, isFalse);
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('a coordinate edit makes the editor dirty and disables '
          'moderation', (tester) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitudine'),
          '41.55',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitudine'),
          '14.64',
        );
        await tester.pump();
        expect(viewModel.isDirty, isTrue);

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pubblica come luogo'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Rifiuta'),
              )
              .onPressed,
          isNull,
        );
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('an invalid location prevents Save', (tester) async {
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(latitude: 12.5, longitude: -3),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await pushEditor(tester);

        // Break the loaded pair into a half-location.
        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitudine'),
          '',
        );
        await tester.pump();

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Salva modifiche'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
        await tester.pumpAndSettle();

        expect(repository.updateIds, isEmpty);
        expect(viewModel.isDirty, isTrue);
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('valid blank drafts permit Save directly from Map mode', (
        tester,
      ) async {
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          creatorName: 'Redattore',
          creatorEmail: 'redattore@example.com',
        );
        await pushEditor(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Città'),
          'Isernia',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Luogo o evento'),
          'Museo',
        );
        await tester.pump();

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Crea contributo'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Crea contributo'));
        await tester.pumpAndSettle();

        expect(repository.createInputs, isNotEmpty);
        expect(repository.createInputs.single.latitude, isNull);
        expect(repository.createInputs.single.longitude, isNull);
        expect(find.text('SHELL_MARKER'), findsNothing);
      }, disposeOwners: () => viewModel.dispose());

      testOwnerUI('successful Save persists the updated coordinate pair', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        expect(viewModel.requestLoad(), isTrue);
        await pumpCommandTurns(tester);
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitudine'),
          '41.55',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitudine'),
          '14,64',
        );
        await tester.pump();

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Salva modifiche'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
        await tester.pumpAndSettle();

        expect(repository.updateIds, <int>[1]);
        expect(repository.updateInputs.single.latitude, 41.55);
        expect(repository.updateInputs.single.longitude, 14.64);
        expect(find.text('SHELL_MARKER'), findsNothing);
      }, disposeOwners: () => viewModel.dispose());
    });
  });
}

/// Requests keyboard focus on the editable text inside [fieldFinder].
///
/// Returns the field's own [FocusNode] so callers can assert whether the
/// request made it the manager's primary focus.
FocusNode _requestFocusOn(WidgetTester tester, Finder fieldFinder) {
  final fieldNode = Focus.of(
    tester.element(
      find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
    ),
  )..requestFocus();
  return fieldNode;
}
