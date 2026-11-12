import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_decision_area.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/admin_editor_interactions.dart';
import '../../../../support/admin_save_route_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/typography_measurement_harness.dart';

void main() {
  setUpAll(loadTypographyMeasurementFont);
  late AdminSaveRouteHarness harness;
  for (final keyboard in [100.0, 300.0]) {
    for (final top in [0.0, 24.0, 59.0]) {
      for (final scale in [1.0, 2.0]) {
        testOwnerUI('320x500 keyboard $keyboard top $top scale $scale '
            'retains form, editing focus and reachable decisions/risks', (
          tester,
        ) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          harness = AdminSaveRouteHarness();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 500);
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
          tester.view.padding = FakeViewPadding(top: top);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.view.resetViewPadding);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          harness.repository.getByIdResults[1] = Result.success(
            sampleAdminSubmission(
              description: null,
              latitude: 41,
              longitude: 14,
              startDate: DateTime.utc(2026, 10, 2),
              targetEventId: 42,
              modifiedAtToken: '2026-08-20T00:00:00.123456Z',
              externalEvent: AdminExternalEvent(
                recordId: 12,
                snapshotHash: 'old',
                snapshotVersion: 1,
                snapshot: const {'name': 'Fonte precedente'},
                mode: AdminExternalEventMode.update,
                eventId: 42,
                currentHash: 'new',
                currentSnapshot: const {'name': 'Fonte attuale'},
              ),
            ),
          );
          harness.repository.previewResult = Result.success(
            AdminEventMergePreview(
              targetEventId: 42,
              submissionVersionToken: 'submission-version',
              eventVersionToken: 'event-version',
              currentSourceHash: 'new',
              currentSourceSnapshot: const {'name': 'Fonte attuale'},
              groups: [
                AdminEventMergeGroup(
                  name: 'name',
                  providerChanged: true,
                  moderatorChanged: true,
                  apply: true,
                  overwrite: true,
                  base: const {'name': 'Base'},
                  source: const {'name': 'Proposta'},
                  moderated: const {'name': 'Proposta'},
                  current: const {'name': 'Attuale'},
                ),
              ],
            ),
          );
          harness.router.go('/admin/submissions/1');
          await tester.pumpWidget(
            Builder(
              builder: (context) =>
                  harness.app(theme: AppThemeData.light(context: context)),
            ),
          );
          await tester.pumpAndSettle();
          final form = tester.state<FormState>(
            find.descendant(
              of: find.byType(ContentSubmissionFields, skipOffstage: false),
              matching: find.byType(Form, skipOffstage: false),
            ),
          );
          final contentScroll = find.byKey(
            const ValueKey('admin_submission_editor_scroll'),
          );
          final scrollState = tester.state<ScrollableState>(
            find
                .descendant(
                  of: contentScroll,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final primaryController = PrimaryScrollController.maybeOf(
            tester.element(contentScroll),
          );
          expect(primaryController?.positions.length, 1);
          expect(
            harness.owner.requestPreview(activation: harness.owner.activation),
            isTrue,
          );
          await tester.pumpAndSettle();
          final toggle = find.byKey(const ValueKey('admin_open_decisions'));
          expect(toggle.hitTestable(), findsOneWidget);
          expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
          expect(
            tester.widget<Tooltip>(toggle).message,
            contains('1 sovrascritture'),
          );
          expect(
            tester.widget<Tooltip>(toggle).message,
            contains('Fonte aggiornata'),
          );
          for (final expanded in [false, true]) {
            await openAdminEditorDecisions(tester);
            final apply = find.widgetWithText(
              FilledButton,
              'Applica aggiornamento',
            );
            await tester.ensureVisible(apply);
            await tester.pumpAndSettle();
            expect(apply.hitTestable(), findsOneWidget);
            expect(tester.getSize(apply).height, greaterThanOrEqualTo(48));
            final decisionViewport = tester.getRect(
              find.byKey(const ValueKey('admin_decision_complete_scroll')),
            );
            final primaryRect = tester.getRect(apply);
            if (primaryRect.height <= decisionViewport.height) {
              expect(decisionViewport.contains(primaryRect.topLeft), isTrue);
              expect(
                decisionViewport.contains(
                  primaryRect.bottomRight - const Offset(.01, .01),
                ),
                isTrue,
              );
            }
            if (expanded) {
              await showAdminEditorActions(tester);
              final reject = find.widgetWithText(FilledButton, 'Rifiuta');
              await tester.ensureVisible(reject);
              await tester.pumpAndSettle();
              final viewport = tester.getRect(
                find.byKey(const ValueKey('admin_decision_complete_scroll')),
              );
              final target = tester.getRect(reject);
              expect(target.height, greaterThanOrEqualTo(48));
              expect(viewport.contains(target.topLeft), isTrue);
              expect(
                viewport.contains(target.bottomRight - const Offset(.01, .01)),
                isTrue,
              );
              expect(reject.hitTestable(), findsOneWidget);
              expect(primaryController?.positions.length, 1);
            }
            final risks = find.byKey(const ValueKey('admin_decision_risks'));
            await tester.ensureVisible(risks);
            await tester.pumpAndSettle();
            expect(risks.hitTestable(), findsOneWidget);
            await tester.tap(risks);
            await tester.pumpAndSettle();
            final review = find.text(
              expanded ? 'Esamina fonte aggiornata' : 'Esamina sovrascritture',
            );
            await tester.ensureVisible(review);
            await tester.pumpAndSettle();
            await tester.tap(review);
            await tester.pumpAndSettle();
            expect(find.byType(AdminSubmissionDecisionArea), findsNothing);
            final evidence = find.text(
              expanded ? 'Versione corrente della fonte' : 'Nome',
            );
            expect(evidence.hitTestable(), findsWidgets);
            expect(harness.owner.acknowledgeCurrentSource, isFalse);
            expect(harness.repository.applyCalls, isEmpty);
          }
          // The bottom coordinate field remains in the same finite form tree.
          final coordinates = find.text('Coordinate', skipOffstage: false);
          await tester.ensureVisible(coordinates);
          await tester.pumpAndSettle();
          await tester.tap(coordinates);
          await tester.pumpAndSettle();
          final latitude = find.widgetWithText(
            TextFormField,
            'Latitudine',
            skipOffstage: false,
          );
          await tester.ensureVisible(latitude);
          await tester.pumpAndSettle();
          await tester.enterText(latitude, '41,2');
          await tester.pumpAndSettle();
          final editable = find.descendant(
            of: latitude,
            matching: find.byType(EditableText),
          );
          final focus = tester.widget<EditableText>(editable).focusNode;
          expect(focus.hasFocus, isTrue);
          expect(editable.hitTestable(), findsOneWidget);
          final offset = scrollState.position.pixels;
          await openAdminEditorDecisions(tester);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isTrue);
          expect(tester.widget<EditableText>(editable).controller.text, '41,2');
          expect(
            tester.state<FormState>(
              find.descendant(
                of: find.byType(ContentSubmissionFields, skipOffstage: false),
                matching: find.byType(Form, skipOffstage: false),
              ),
            ),
            same(form),
          );
          expect(scrollState.position.pixels, closeTo(offset, 1));
          expect(primaryController?.positions.length, 1);
          expect(harness.repository.updateIds, isEmpty);
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        }, disposeOwners: () => harness.dispose());
      }
    }
  }
  for (final scale in [1.0, 2.0]) {
    testOwnerUI(
      'long Link identity stays reachable at extreme height scale $scale',
      (tester) async {
        harness = AdminSaveRouteHarness();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1200);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final title = List.filled(8, 'Festa del borgo').join(' ');
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            description: null,
            startDate: DateTime.utc(2026, 10, 2),
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          ),
        );
        harness.repository.candidatesResult = Result.success(
          AdminEventCandidates(
            events: [
              AdminEventCandidate(id: 42, name: title, city: 'Campobasso'),
            ],
            pendingWarnings: const [],
          ),
        );
        harness.router.go('/admin/submissions/1');
        await tester.pumpWidget(
          Builder(
            builder: (context) =>
                harness.app(theme: AppThemeData.light(context: context)),
          ),
        );
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('admin_event_search'));
        await revealAdminEditorWidget(tester, search);
        await tester.enterText(search, 'Festa');
        final findEvents = find.text('Cerca eventi');
        await revealAdminEditorWidget(tester, findEvents);
        await tester.tap(findEvents);
        await tester.pumpAndSettle();
        final candidate = find.byKey(
          const ValueKey('admin_event_candidate_42'),
        );
        await revealAdminEditorWidget(tester, candidate);
        final contentScroll = find.byKey(
          const ValueKey('admin_submission_editor_scroll'),
        );
        final visibleTile = tester
            .getRect(candidate)
            .intersect(tester.getRect(contentScroll));
        await tester.tapAt(visibleTile.center);
        await tester.pumpAndSettle();
        expect(harness.owner.candidates, isNull);
        tester.view.physicalSize = const Size(320, 500);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        tester.view.padding = const FakeViewPadding(top: 59);
        await tester.pumpAndSettle();
        await openAdminEditorDecisions(tester);
        final selectedName = find.descendant(
          of: find.byType(AdminSubmissionDecisionArea),
          matching: find.text(title),
        );
        await tester.ensureVisible(selectedName);
        await tester.pumpAndSettle();
        expect(selectedName.hitTestable(), findsOneWidget);
        final link = find.widgetWithText(FilledButton, 'Collega a evento');
        await tester.ensureVisible(link);
        await tester.pumpAndSettle();
        expect(link.hitTestable(), findsOneWidget);
        expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
        expect(tester.widget<FilledButton>(link).onPressed, isNotNull);
        expect(harness.owner.targetEventId, 42);
        expect(harness.repository.linkCalls, isEmpty);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI(
    'invalid Save reveals a hittable field outside the decision surface',
    (tester) async {
      harness = AdminSaveRouteHarness();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 500);
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await harness.openEditor(tester, target: 1);
      final name = find.widgetWithText(
        TextFormField,
        'Luogo o evento',
        skipOffstage: false,
      );
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      await tester.enterText(name, '');
      await tester.pump();
      await openAdminEditorDecisions(tester);
      final save = find.widgetWithText(FilledButton, 'Salva modifiche');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionDecisionArea), findsNothing);
      expect(name.hitTestable(), findsOneWidget);
      expect(
        find.text('Inserisci il nome di un luogo o di un evento'),
        findsOneWidget,
      );
      expect(harness.repository.updateIds, isEmpty);
      await openAdminEditorDecisions(tester);
      final feedback = find.byKey(const ValueKey('admin_validation_feedback'));
      await tester.ensureVisible(feedback);
      await tester.pumpAndSettle();
      await tester.tap(feedback);
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionDecisionArea), findsNothing);
      expect(name.hitTestable(), findsOneWidget);
      expect(harness.repository.updateIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'keyboard dismissal keeps explicit decisions open until editing resumes',
    (tester) async {
      harness = AdminSaveRouteHarness();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final semantics = tester.ensureSemantics();
      try {
        await harness.openEditor(tester, target: 1);
        final name = find.widgetWithText(TextFormField, 'Luogo o evento');
        await tester.ensureVisible(name);
        await tester.pumpAndSettle();
        await tester.enterText(name, 'Bozza conservata');
        await tester.pumpAndSettle();
        final editable = find.descendant(
          of: name,
          matching: find.byType(EditableText),
        );
        final focus = tester.widget<EditableText>(editable).focusNode;
        await openAdminEditorDecisions(tester);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin_open_decisions')).hitTestable(),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('Contenuto')), findsWidgets);
        expect(
          tester
              .widget<AdminSubmissionDecisionArea>(
                find.byType(AdminSubmissionDecisionArea),
              )
              .scrollAll,
          isTrue,
        );
        await tester.tap(find.byKey(const ValueKey('admin_open_decisions')));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(find.byType(AdminSubmissionDecisionArea), findsNothing);
        expect(
          tester.widget<EditableText>(editable).controller.text,
          'Bozza conservata',
        );
        expect(focus.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    disposeOwners: () => harness.dispose(),
  );

  for (final status in AdminSubmissionStatus.values) {
    for (final hasStart in [false, true]) {
      testOwnerUI('external update guidance $status start $hasStart', (
        tester,
      ) async {
        harness = AdminSaveRouteHarness();
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            status: status,
            description: null,
            startDate: hasStart ? DateTime.utc(2026, 10, 2) : null,
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
            externalEvent: AdminExternalEvent(
              recordId: 12,
              snapshotHash: 'source',
              snapshotVersion: 1,
              snapshot: const {},
              mode: AdminExternalEventMode.update,
            ),
          ),
        );
        await tester.binding.setSurfaceSize(const Size(600, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await harness.openEditor(tester, target: 1);
        await showAdminEditorActions(tester);
        final start = find.text('Completa la data di inizio dell’evento.');
        final target = find.text('Seleziona l’evento da confrontare.');
        expect(
          start,
          status == AdminSubmissionStatus.pending && !hasStart
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          target,
          status == AdminSubmissionStatus.pending && hasStart
              ? findsOneWidget
              : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }, disposeOwners: () => harness.dispose());
    }
  }
}
