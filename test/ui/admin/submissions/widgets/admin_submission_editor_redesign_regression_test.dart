import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_location_editor.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../support/admin_editor_interactions.dart';
import '../../../../support/admin_save_route_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';

void main() {
  late AdminSaveRouteHarness harness;
  testOwnerUI('forms and drafts survive scrolling and responsive resizing', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await tester.binding.setSurfaceSize(const Size(840, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await harness.openEditor(tester, target: 1);

    expect(find.text('Target 1'), findsWidgets);
    expect(
      find.ancestor(
        of: find.text('Target 1').first,
        matching: find.byType(SentryMask),
      ),
      findsOneWidget,
    );

    final contentForm = find.descendant(
      of: find.byType(ContentSubmissionFields),
      matching: find.byType(Form),
    );
    final locationForm = find.descendant(
      of: find.byType(AdminSubmissionLocationEditor),
      matching: find.byType(Form),
    );
    final contentState = tester.state<FormState>(contentForm);
    final locationState = tester.state<FormState>(locationForm);

    final quill = tester.widget<QuillEditor>(find.byType(QuillEditor));
    quill.controller.replaceText(
      0,
      0,
      'Rich text survives resizing',
      const TextSelection.collapsed(offset: 28),
    );
    quill.controller.updateSelection(
      TextSelection.collapsed(offset: quill.controller.document.length - 1),
      ChangeSource.local,
    );
    final selection = quill.controller.selection;

    final coordinateMode = find.text('Coordinate');
    await tester.ensureVisible(coordinateMode);
    await tester.tap(coordinateMode);
    await tester.pumpAndSettle();
    final latitude = find
        .descendant(
          of: find.byType(AdminSubmissionLocationEditor),
          matching: find.byType(TextFormField),
        )
        .first;
    await tester.enterText(latitude, '-');
    await tester.pump();

    for (final width in [320.0, 600.0, 840.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1600));
      await tester.pumpAndSettle();
      expect(tester.state<FormState>(contentForm), same(contentState));
      expect(tester.state<FormState>(locationForm), same(locationState));
      final currentQuill = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(currentQuill.controller.selection, selection);
      expect(
        harness.owner.description,
        quill.controller.document.toPlainText().trim(),
      );
      expect(harness.owner.latitudeText, '-');
    }

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('admin_submission_editor_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(tester.state<FormState>(contentForm), same(contentState));
    expect(tester.state<FormState>(locationForm), same(locationState));
    expect(harness.owner.latitudeText, '-');
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'unresolved timed start keeps Save blocked with reachable feedback',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          targetEventId: 42,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      harness.owner.setEventEnabled(
        enabled: true,
        activation: harness.owner.activation,
      );
      harness.owner.setStartCalendarDate(
        EventCalendarDate(2026, 3, 29),
        activation: harness.owner.activation,
      );
      await tester.pump();

      final save = find.widgetWithText(FilledButton, 'Salva modifiche');
      await revealAdminEditorWidget(tester, save);
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Controlla data e ora dell’evento'),
        findsOneWidget,
      );
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.owner.startCalendarDate, EventCalendarDate(2026, 3, 29));
      expect(harness.owner.startClockTime, isNull);
      expect(find.text('Collega a evento'), findsNothing);
      expect(harness.router.state.uri.path, '/admin/submissions/1');
      await tester.tap(find.byKey(const ValueKey('admin_validation_feedback')));
      await tester.pumpAndSettle();
      expect(
        find.text('Seleziona un orario di inizio.').hitTestable(),
        findsOneWidget,
      );
      expect(harness.repository.updateInputs, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'valid Save is admitted when the unvisited location section is off-screen',
    (tester) async {
      harness = AdminSaveRouteHarness();
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      final location = tester.widget<AdminSubmissionLocationEditor>(
        find.byType(AdminSubmissionLocationEditor, skipOffstage: false),
      );
      expect(location.formKey.currentState, isNotNull);
      harness.owner.setName(
        'Unvisited location Save',
        activation: harness.owner.activation,
      );
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Salva modifiche');
      await revealAdminEditorWidget(tester, save);
      expect(save, findsOneWidget);
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, contains('save-progress'));
      expect(harness.repository.updateInputs, hasLength(1));
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('rejected Rome DST time edit blocks Save and reveals its error', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        startDate: DateTime.utc(2026, 3, 29, 0, 30),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await harness.openEditor(tester, target: 1);
    expect(harness.owner.isActivationCurrent(harness.owner.activation), isTrue);
    harness.owner.setStartClockTime(
      EventClockTime(2, 30),
      activation: harness.owner.activation,
    );
    await tester.pump();

    expect(harness.owner.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
    expect(harness.owner.startDate, DateTime.utc(2026, 3, 29, 0, 30));
    final save = find.widgetWithText(FilledButton, 'Salva modifiche');
    await revealAdminEditorWidget(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Controlla data e ora dell’evento'),
      findsOneWidget,
    );
    expect(harness.repository.updateInputs, isEmpty);
    await tester.tap(find.byKey(const ValueKey('admin_validation_feedback')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('non esiste in Italia').hitTestable(),
      findsOneWidget,
    );
    expect(harness.owner.startDate, DateTime.utc(2026, 3, 29, 0, 30));
    expect(harness.repository.updateInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('coordinate error action reveals fields hidden by Map mode', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        latitude: 41,
        longitude: 14,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await harness.openEditor(tester, target: 1);
    await revealAdminEditorWidget(
      tester,
      find.byType(AdminSubmissionLocationEditor),
    );
    harness.owner.setLatitudeText('91', activation: harness.owner.activation);
    await tester.pump();
    expect(find.text('Mappa').hitTestable(), findsOneWidget);
    final latitude = find
        .descendant(
          of: find.byType(AdminSubmissionLocationEditor, skipOffstage: false),
          matching: find.byType(TextFormField, skipOffstage: false),
          skipOffstage: false,
        )
        .first;
    expect(latitude.hitTestable(), findsNothing);

    final save = find.widgetWithText(FilledButton, 'Salva modifiche');
    await revealAdminEditorWidget(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Correggi le coordinate della posizione.'),
      findsOneWidget,
    );
    expect(harness.repository.updateInputs, isEmpty);
    await tester.tap(find.byKey(const ValueKey('admin_validation_feedback')));
    await tester.pumpAndSettle();

    await revealAdminEditorWidget(tester, latitude);
    expect(latitude.hitTestable(), findsOneWidget);
    expect(tester.widget<TextFormField>(latitude).controller!.text, '91');
    expect(harness.repository.updateInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());

  for (final width in [320.0, 1200.0]) {
    testOwnerUI(
      'overwrite warning and review action remain hit-testable at $width',
      (tester) async {
        harness = AdminSaveRouteHarness();
        final longValue = List.filled(
          40,
          'proposta lunga da verificare',
        ).join(' ');
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
            startDate: DateTime.utc(2026, 3, 29, 0, 30),
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'source-hash',
              snapshotVersion: 1,
              snapshot: const {'name': 'Proposta non pubblicata'},
              mode: AdminExternalEventMode.update,
              eventId: 42,
            ),
            targetEventId: 42,
          ),
        );
        harness.repository.previewResult = Result.success(
          AdminEventMergePreview(
            targetEventId: 42,
            submissionVersionToken: 'opaque-submission',
            eventVersionToken: 'opaque-event',
            groups: [
              AdminEventMergeGroup(
                name: 'description',
                providerChanged: true,
                moderatorChanged: false,
                apply: true,
                overwrite: true,
                base: {'description': 'base'},
                source: {'description': longValue},
                moderated: {'description': longValue},
                current: {'description': 'current $longValue'},
              ),
            ],
          ),
        );
        await tester.binding.setSurfaceSize(Size(width, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await harness.openEditor(tester, target: 1);
        expect(
          harness.owner.requestPreview(activation: harness.owner.activation),
          isTrue,
        );
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('admin_overwrite_warning')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text('Esamina sovrascritture').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text('Applica aggiornamento').hitTestable(),
          findsOneWidget,
        );
        expect(harness.repository.applyCalls, isEmpty);
        final obsoleteReview = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Esamina sovrascritture'),
            )
            .onPressed!;
        final obsoleteApply = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Applica aggiornamento'),
            )
            .onPressed!;
        await tester.tap(find.text('Esamina sovrascritture'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Sovrascrive modifiche').hitTestable(),
          findsOneWidget,
        );
        final proposed = find.text(longValue, skipOffstage: false);
        final current = find.text('current $longValue', skipOffstage: false);
        expect(proposed, findsOneWidget);
        expect(current, findsOneWidget);
        expect(
          find.ancestor(
            of: proposed,
            matching: find.byType(SentryMask, skipOffstage: false),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: current,
            matching: find.byType(SentryMask, skipOffstage: false),
          ),
          findsNothing,
        );
        await tester.ensureVisible(current);
        await tester.pumpAndSettle();
        final contentBounds = tester.getRect(
          find.byKey(const ValueKey('admin_submission_editor_scroll')),
        );
        expect(
          tester.getTopLeft(current).dy,
          inInclusiveRange(contentBounds.top, contentBounds.bottom),
        );
        Scrollable.ensureVisible(tester.element(current), alignment: 1);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(current).dy,
          lessThanOrEqualTo(contentBounds.bottom + 1),
        );
        expect(harness.repository.applyCalls, isEmpty);
        final body =
            tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey('admin_submission_editor_scroll'),
                        ),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position
              ..jumpTo(0);
        await tester.pumpAndSettle();
        harness.repository.previewResult = Result.success(
          AdminEventMergePreview(
            targetEventId: 42,
            submissionVersionToken: 'new-submission',
            eventVersionToken: 'new-event',
            groups: [
              AdminEventMergeGroup(
                name: 'name',
                providerChanged: false,
                moderatorChanged: false,
                apply: false,
                overwrite: false,
                base: const {'name': 'base'},
                source: const {'name': 'source'},
                moderated: const {'name': 'proposal'},
                current: const {'name': 'Public current'},
              ),
            ],
          ),
        );
        expect(
          harness.owner.requestPreview(activation: harness.owner.activation),
          isTrue,
        );
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(body.pixels, 0);
        expect(
          find.byKey(const ValueKey('admin_overwrite_warning')),
          findsNothing,
        );
        expect(find.text('Esamina sovrascritture'), findsNothing);
        obsoleteReview();
        obsoleteApply();
        await tester.pumpAndSettle();
        expect(body.pixels, 0);
        expect(harness.repository.applyCalls, isEmpty);
        expect(harness.repository.updateInputs, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI('scaled decision panel falls back and save remains reachable', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.openEditor(tester, target: 1);

    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    await revealAdminEditorWidget(tester, find.text('Salva modifiche'));
    expect(find.text('Salva modifiche').hitTestable(), findsOneWidget);
    final layout = find
        .ancestor(
          of: find.byKey(const ValueKey('admin_submission_editor_scroll')),
          matching: find.byType(Flex),
        )
        .first;
    expect(tester.widget<Flex>(layout).direction, Axis.vertical);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());
  for (final width in [600.0, 1200.0]) {
    testOwnerUI(
      'stale source navigation is explicit and revision bound at $width',
      (tester) async {
        harness = AdminSaveRouteHarness();
        final external = AdminExternalEvent(
          recordId: 12,
          snapshotHash: 'h1',
          snapshotVersion: 1,
          snapshot: const {'name': 'Original private source'},
          mode: AdminExternalEventMode.update,
          eventId: 42,
          currentHash: 'h2',
          currentSnapshot: const {'name': 'Private source h2'},
        );
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
            description: null,
            startDate: DateTime.utc(2026, 3, 29, 0, 30),
            externalEvent: external,
            targetEventId: 42,
          ),
        );
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await harness.openEditor(tester, target: 1);
        final review = find.widgetWithText(
          TextButton,
          'Esamina fonte aggiornata',
        );
        expect(review.hitTestable(), findsOneWidget);
        final obsoleteReview = tester.widget<TextButton>(review).onPressed!;
        final oldCheckbox = tester
            .widget<CheckboxListTile>(
              find.byKey(
                const ValueKey('admin_acknowledge_current_source'),
                skipOffstage: false,
              ),
            )
            .onChanged!;
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(
          find.text('Versione corrente della fonte').hitTestable(),
          findsOneWidget,
        );
        expect(harness.owner.acknowledgeCurrentSource, isFalse);
        expect(harness.repository.applyCalls, isEmpty);
        expect(harness.repository.updateInputs, isEmpty);
        expect(
          find.ancestor(
            of: find.text('Nome: Private source h2'),
            matching: find.byType(SentryMask),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text('Esamina fonte aggiornata'),
            matching: find.byType(SentryMask),
          ),
          findsNothing,
        );
        final current = AdminExternalEvent(
          recordId: 12,
          snapshotHash: 'h1',
          snapshotVersion: 1,
          snapshot: external.snapshot,
          mode: AdminExternalEventMode.update,
          eventId: 42,
          currentHash: 'h3',
          currentSnapshot: const {'name': 'Private source h3'},
        );
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
            description: null,
            startDate: DateTime.utc(2026, 3, 29, 0, 30),
            externalEvent: current,
            targetEventId: 42,
          ),
        );
        expect(
          harness.owner.requestLoad(activation: harness.owner.activation),
          isTrue,
        );
        await tester.pumpAndSettle();
        final body =
            tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey('admin_submission_editor_scroll'),
                        ),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position
              ..jumpTo(0);
        await tester.pumpAndSettle();
        obsoleteReview();
        oldCheckbox(true);
        await tester.pumpAndSettle();
        expect(body.pixels, 0);
        expect(harness.owner.acknowledgeCurrentSource, isFalse);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(
          find.text('Nome: Private source h3').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text('Nome: Private source h2', skipOffstage: false),
          findsNothing,
        );
        expect(harness.owner.acknowledgeCurrentSource, isFalse);
        await revealAdminEditorWidget(
          tester,
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.tap(
          find.byKey(const ValueKey('admin_acknowledge_current_source')),
        );
        await tester.pumpAndSettle();
        expect(harness.owner.acknowledgeCurrentSource, isTrue);
        expect(harness.repository.applyCalls, isEmpty);
        expect(harness.repository.updateInputs, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI('invalid off-screen content reveals its field without Save', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await harness.openEditor(tester, target: 1);
    final name = find.widgetWithText(TextFormField, 'Luogo o evento');
    await revealAdminEditorWidget(tester, name);
    await tester.enterText(name, '');
    await tester.pumpAndSettle();
    final body = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey('admin_submission_editor_scroll'),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    body.jumpTo(body.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(name.hitTestable(), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
    await tester.pumpAndSettle();
    expect(
      find.text('Controlla i campi del contributo.').hitTestable(),
      findsOneWidget,
    );
    expect(name.hitTestable(), findsOneWidget);
    expect(harness.router.state.uri.path, '/admin/submissions/1');
    expect(harness.repository.updateIds, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'new validation callbacks cannot scroll a covered or disposed editor',
    (tester) async {
      harness = AdminSaveRouteHarness();
      await harness.openEditor(tester, target: 1);
      harness.owner.setEventEnabled(
        enabled: true,
        activation: harness.owner.activation,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pumpAndSettle();
      final reveal = tester
          .widget<TextButton>(
            find.byKey(const ValueKey('admin_validation_feedback')),
          )
          .onPressed!;
      final editorContext = tester.element(
        find.byType(AdminSubmissionEditorScreen),
      );
      final body =
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byKey(
                        const ValueKey('admin_submission_editor_scroll'),
                      ),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
            ..jumpTo(0);
      await tester.pumpAndSettle();
      final dialog = showDialog<void>(
        context: editorContext,
        builder: (_) => const AlertDialog(content: Text('Cover editor')),
      );
      await tester.pumpAndSettle();
      reveal();
      await tester.pumpAndSettle();
      expect(body.pixels, 0);
      harness.router.pop();
      await dialog;
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      reveal();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(harness.repository.updateInputs, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('local constraints choose compact layout inside a wide window', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    harness.router.go('/admin/submissions/1');
    await tester.pumpWidget(
      Center(child: SizedBox(width: 600, child: harness.app())),
    );
    await tester.pumpAndSettle();
    final layout = find
        .ancestor(
          of: find.byKey(const ValueKey('admin_submission_editor_scroll')),
          matching: find.byType(Flex),
        )
        .first;
    expect(tester.widget<Flex>(layout).direction, Axis.vertical);
    expect(find.text('Pubblica come luogo').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());
  testOwnerUI(
    'narrow editor keeps fields and decisions reachable above keyboard',
    (tester) async {
      harness = AdminSaveRouteHarness();
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.viewInsets = FakeViewPadding(
        bottom: 100 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await harness.openEditor(tester, target: 1);
      final city = find.widgetWithText(TextFormField, 'Città');
      await revealAdminEditorWidget(tester, city);
      await tester.tap(city);
      await tester.enterText(city, 'Isernia');
      await tester.pumpAndSettle();
      expect(city.hitTestable(), findsOneWidget);
      await openAdminEditorDecisions(tester);
      final save = find.widgetWithText(FilledButton, 'Salva modifiche');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(400));
      expect(harness.owner.city, 'Isernia');
      expect(harness.repository.updateIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
}
