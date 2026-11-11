import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../support/admin_editor_interactions.dart';
import '../../../../support/admin_save_route_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';

void main() {
  late AdminSaveRouteHarness harness;
  for (final scenario in [
    (
      'place',
      false,
      null,
      ContentCategory.history,
      null,
      false,
      'Pubblica come luogo',
      true,
    ),
    (
      'event',
      true,
      null,
      ContentCategory.history,
      null,
      false,
      'Pubblica come evento',
      true,
    ),
    (
      'human link without category',
      true,
      42,
      ContentCategory.unknown,
      null,
      false,
      'Collega a evento',
      true,
    ),
    (
      'retained target without start',
      false,
      42,
      ContentCategory.history,
      null,
      false,
      'Pubblica come luogo',
      true,
    ),
    (
      'external create',
      true,
      null,
      ContentCategory.history,
      AdminExternalEventMode.create,
      false,
      'Pubblica come evento',
      true,
    ),
    (
      'external create link',
      true,
      42,
      ContentCategory.history,
      AdminExternalEventMode.create,
      false,
      'Collega a evento',
      true,
    ),
    (
      'external update missing target',
      true,
      null,
      ContentCategory.history,
      AdminExternalEventMode.update,
      false,
      'Anteprima aggiornamento',
      false,
    ),
    (
      'external update',
      true,
      42,
      ContentCategory.history,
      AdminExternalEventMode.update,
      false,
      'Anteprima aggiornamento',
      true,
    ),
    (
      'dirty Event',
      true,
      42,
      ContentCategory.history,
      null,
      true,
      'Salva modifiche',
      true,
    ),
    (
      'missing category',
      false,
      null,
      ContentCategory.unknown,
      null,
      false,
      'Pubblica come luogo',
      false,
    ),
  ]) {
    testOwnerUI('decision matrix: ${scenario.$1}', (tester) async {
      harness = AdminSaveRouteHarness();
      final externalMode = scenario.$5;
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          description: null,
          category: scenario.$4,
          startDate: scenario.$2 ? DateTime.utc(2026, 3, 29, 0, 30) : null,
          targetEventId: scenario.$3,
          externalEvent: externalMode == null
              ? null
              : AdminExternalEvent(
                  recordId: 12,
                  snapshotHash: 'source-v1',
                  snapshotVersion: 1,
                  snapshot: const {'name': 'Private source'},
                  mode: externalMode,
                ),
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        ),
      );
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      if (scenario.$6) {
        harness.owner.setName(
          'Unsaved work',
          activation: harness.owner.activation,
        );
        await tester.pumpAndSettle();
      }
      final primary = find.widgetWithText(FilledButton, scenario.$7);
      expect(primary.hitTestable(), findsOneWidget);
      expect(
        tester.widget<FilledButton>(primary).onPressed != null,
        scenario.$8,
      );
      await showAdminEditorActions(tester);
      expect(find.text(scenario.$7), findsOneWidget);
      if (!scenario.$2) expect(find.text('Collega a evento'), findsNothing);
      if (externalMode == AdminExternalEventMode.update) {
        expect(find.textContaining('Pubblica come'), findsNothing);
      }
      if (scenario.$6) {
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Rifiuta'),
              )
              .onPressed,
          isNull,
        );
      } else {
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Rifiuta'),
              )
              .onPressed,
          isNotNull,
        );
      }
      expect(harness.repository.updateIds, isEmpty);
      expect(harness.repository.promoteCalls, isEmpty);
      expect(harness.repository.linkCalls, isEmpty);
      expect(harness.repository.applyCalls, isEmpty);
      expect(tester.takeException(), isNull);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI('rejected temporal edit retains valid human Event Link', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    final originalStart = DateTime.utc(2026, 3, 29, 0, 30);
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        description: null,
        startDate: originalStart,
        targetEventId: 42,
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
      ),
    );
    await harness.openEditor(tester, target: 1);
    harness.owner.setStartClockTime(
      EventClockTime(2, 30),
      activation: harness.owner.activation,
    );
    await tester.pumpAndSettle();
    expect(harness.owner.eventTimeIssue, EventTimeIssue.nonexistentLocalTime);
    expect(harness.owner.startDate, originalStart);
    expect(harness.owner.isDirty, isFalse);
    final link = find.widgetWithText(FilledButton, 'Collega a evento');
    expect(tester.widget<FilledButton>(link).onPressed, isNotNull);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(harness.repository.linkCalls, hasLength(1));
    expect(harness.repository.linkCalls.single.$2, 42);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'Event converted and saved as Place cannot Link retained target',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          description: null,
          startDate: DateTime.utc(2026, 3, 29, 0, 30),
          targetEventId: 42,
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        ),
      );
      harness.repository.updateResult = Result.success(
        sampleAdminSubmission(
          description: null,
          targetEventId: 42,
          modifiedAtToken: '2026-08-21T00:00:00.123456Z',
        ),
      );
      await harness.openEditor(tester, target: 1);
      final obsoleteLink = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Collega a evento'),
          )
          .onPressed!;
      harness.owner.setEventEnabled(
        enabled: false,
        activation: harness.owner.activation,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, [1]);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.owner.targetEventId, 42);
      expect(harness.owner.startDate, isNull);
      expect(find.text('Collega a evento'), findsNothing);
      obsoleteLink();
      await tester.pumpAndSettle();
      expect(harness.repository.linkCalls, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  for (final offscreenSection in ['content', 'location']) {
    testOwnerUI('valid Save admits once with $offscreenSection off-screen', (
      tester,
    ) async {
      harness = AdminSaveRouteHarness();
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          description: null,
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        ),
      );
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Saved once', activation: harness.owner.activation);
      await tester.pumpAndSettle();
      if (offscreenSection == 'content') {
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('admin_submission_editor_scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        tester
            .state<ScrollableState>(scrollable)
            .position
            .jumpTo(
              tester
                  .state<ScrollableState>(scrollable)
                  .position
                  .maxScrollExtent,
            );
        await tester.pumpAndSettle();
      }
      final fields = tester.widget<ContentSubmissionFields>(
        find.byType(ContentSubmissionFields, skipOffstage: false),
      );
      expect(fields.formKey.currentState, isNotNull);
      final save = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Salva modifiche'),
          )
          .onPressed!;
      save();
      save();
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, [1]);
      expect(harness.router.state.uri.path, endsWith('save-progress'));
      expect(harness.repository.promoteCalls, isEmpty);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI('identity placeholders and metadata keep selective privacy', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    await harness.openEditor(tester);
    expect(find.text('Titolo da inserire'), findsOneWidget);
    expect(find.text('Comune da indicare'), findsOneWidget);
    expect(find.text('Luogo · Nuovo contributo'), findsOneWidget);
    harness.owner.setName(
      'Private identity',
      activation: harness.owner.activation,
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Private identity'),
        matching: find.byType(SentryMask),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Crea contributo'),
        matching: find.byType(SentryMask),
      ),
      findsNothing,
    );
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.repository.createInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());
  for (final status in [
    AdminSubmissionStatus.accepted,
    AdminSubmissionStatus.rejected,
  ]) {
    testOwnerUI(
      'final $status blocks keyboard and pointer editing at normal contrast',
      (tester) async {
        harness = AdminSaveRouteHarness();
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            status: status,
            startDate: DateTime.utc(2026, 3, 29, 0, 30),
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          ),
        );
        await harness.openEditor(tester, target: 1);
        expect(find.text('Contributo concluso · sola lettura'), findsOneWidget);
        final fields = find.byType(
          ContentSubmissionFields,
          skipOffstage: false,
        );
        expect(
          find.ancestor(of: fields, matching: find.byType(Opacity)),
          findsNothing,
        );
        expect(
          find.ancestor(
            of: fields,
            matching: find.byWidgetPredicate(
              (w) => w is IgnorePointer && w.ignoring,
            ),
          ),
          findsOneWidget,
        );
        for (final label in ['Storia', 'Seleziona sulla mappa']) {
          await revealAdminEditorWidget(tester, find.text(label));
          await tester.tap(find.text(label), warnIfMissed: false);
          await tester.pumpAndSettle();
        }
        final date = find.textContaining('Inizia il');
        await revealAdminEditorWidget(tester, date);
        await tester.tap(date, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(find.byType(GeoMap), findsNothing);
        for (var tab = 0; tab < 12; tab++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          for (final field in tester.widgetList<EditableText>(
            find.byType(EditableText, skipOffstage: false),
          )) {
            expect(field.focusNode.hasFocus, isFalse);
          }
        }
        expect(harness.owner.isDirty, isFalse);
        expect(harness.owner.category, ContentCategory.history);
        expect(find.text('Salva modifiche'), findsNothing);
        expect(find.text('Rifiuta'), findsNothing);
        expect(harness.repository.updateIds, isEmpty);
        expect(harness.repository.linkCalls, isEmpty);
        expect(harness.repository.promoteCalls, isEmpty);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => harness.dispose(),
    );
  }
}
