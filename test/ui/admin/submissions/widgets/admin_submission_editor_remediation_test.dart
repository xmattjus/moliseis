import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_decision_area.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';
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

  testOwnerUI(
    'name feedback survives unrelated changes and clears on correction',
    (tester) async {
      harness = AdminSaveRouteHarness();
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      final name = find.widgetWithText(TextFormField, 'Luogo o evento');
      await revealAdminEditorWidget(tester, name);
      await tester.enterText(name, '');
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'Salva modifiche');
      await revealAdminEditorWidget(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final feedback = find.byKey(const ValueKey('admin_validation_feedback'));
      expect(feedback, findsOneWidget);
      final obsoleteReveal = tester.widget<TextButton>(feedback).onPressed!;
      harness.owner.setCandidateSearch(
        'unrelated search',
        activation: harness.owner.activation,
      );
      await tester.pump();
      expect(feedback, findsOneWidget);
      final city = find.widgetWithText(TextFormField, 'Città');
      await revealAdminEditorWidget(tester, city);
      await tester.enterText(city, 'Isernia');
      await tester.pump();
      expect(feedback, findsOneWidget);
      await revealAdminEditorWidget(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, isEmpty);
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsNothing);
      expect(feedback, findsOneWidget);
      await revealAdminEditorWidget(tester, name);
      await tester.enterText(name, 'Nome corretto');
      await tester.pump();
      expect(harness.owner.name, 'Nome corretto');
      expect(feedback, findsNothing);
      final contentScroll = tester
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
      final correctedOffset = contentScroll.pixels;
      obsoleteReveal();
      await tester.pumpAndSettle();
      expect(contentScroll.pixels, correctedOffset);
      expect(feedback, findsNothing);
      expect(harness.repository.updateIds, isEmpty);
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsNothing);
      await revealAdminEditorWidget(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, [1]);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('coordinate feedback clears after correcting the actual input', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        description: null,
        latitude: 41,
        longitude: 14,
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
      ),
    );
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await harness.openEditor(tester, target: 1);
    await revealAdminEditorWidget(tester, find.text('Coordinate'));
    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    final latitude = find.widgetWithText(TextFormField, 'Latitudine');
    await revealAdminEditorWidget(tester, latitude);
    await tester.enterText(latitude, '91');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Salva modifiche');
    await revealAdminEditorWidget(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Correggi le coordinate della posizione.'),
      findsOneWidget,
    );
    harness.owner.setCandidateSearch(
      'unrelated',
      activation: harness.owner.activation,
    );
    await tester.pump();
    expect(
      find.text('Correggi le coordinate della posizione.'),
      findsOneWidget,
    );
    await revealAdminEditorWidget(tester, latitude);
    await tester.enterText(latitude, '41.2');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('admin_validation_feedback')),
      findsNothing,
    );
    expect(harness.repository.updateIds, isEmpty);
    expect(find.byType(AdminSubmissionSaveProgressScreen), findsNothing);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'rejected DST time preserves start and feedback clears on valid correction',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final start = DateTime.utc(2026, 3, 29, 0, 30);
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          description: null,
          startDate: start,
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        ),
      );
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      tester
          .widget<ContentSubmissionFields>(find.byType(ContentSubmissionFields))
          .onStartTimeChanged(EventClockTime(2, 30));
      await tester.pump();
      expect(harness.owner.startDate, start);
      expect(harness.owner.eventTimeIssue, isNotNull);
      final save = find.widgetWithText(FilledButton, 'Salva modifiche');
      await revealAdminEditorWidget(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final feedback = find.byKey(const ValueKey('admin_validation_feedback'));
      expect(find.text('Controlla data e ora dell’evento.'), findsOneWidget);
      final obsoleteReveal = tester.widget<TextButton>(feedback).onPressed!;
      harness.owner.setCandidateSearch(
        'unrelated',
        activation: harness.owner.activation,
      );
      await tester.pump();
      expect(feedback, findsOneWidget);
      tester
          .widget<ContentSubmissionFields>(find.byType(ContentSubmissionFields))
          .onStartTimeChanged(EventClockTime(3, 30));
      await tester.pump();
      expect(harness.owner.eventTimeIssue, isNull);
      expect(harness.owner.startDate, DateTime.utc(2026, 3, 29, 1, 30));
      expect(feedback, findsNothing);
      expect(harness.repository.updateIds, isEmpty);
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      obsoleteReveal();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('activation replacement revokes pending validation navigation', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.repository.getByIdResults[2] = Result.success(
      sampleAdminSubmission(
        id: 2,
        name: 'Nuovo contributo',
        description: null,
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
      ),
    );
    await harness.openEditor(tester, target: 1);
    final name = find.widgetWithText(TextFormField, 'Luogo o evento');
    await revealAdminEditorWidget(tester, name);
    await tester.enterText(name, '');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Salva modifiche');
    await revealAdminEditorWidget(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final feedback = find.byKey(const ValueKey('admin_validation_feedback'));
    final obsoleteReveal = tester.widget<TextButton>(feedback).onPressed!;
    harness.router.go('/admin/submissions/2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esci senza salvare'));
    await tester.pumpAndSettle();
    expect(harness.owner.submissionId, 2);
    expect(feedback, findsNothing);
    final contentScroll = tester
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
    final offset = contentScroll.pixels;
    obsoleteReveal();
    await tester.pumpAndSettle();
    expect(contentScroll.pixels, offset);
    expect(tester.takeException(), isNull);
    expect(harness.repository.updateIds, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'Link retains tapped identity after invalidation and sends ID 42',
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
      harness.repository.candidatesResult = Result.success(
        AdminEventCandidates(
          events: const [
            AdminEventCandidate(
              id: 42,
              name: 'Festa del borgo',
              city: 'Isernia',
            ),
          ],
          pendingWarnings: const [],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.openEditor(tester, target: 1);
      expect(
        harness.owner.requestFindCandidates(
          activation: harness.owner.activation,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      final candidate = find.byKey(const ValueKey('admin_event_candidate_42'));
      await revealAdminEditorWidget(tester, candidate);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      expect(harness.owner.candidates, isNull);
      expect(harness.owner.targetEventId, 42);
      expect(find.text('Festa del borgo'), findsNWidgets(2));
      expect(find.text('Isernia'), findsNWidgets(2));
      final decision = find.byType(AdminSubmissionDecisionArea);
      expect(
        find.descendant(of: decision, matching: find.text('Festa del borgo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: decision, matching: find.text('Isernia')),
        findsOneWidget,
      );
      harness.owner.setCandidateSearch(
        'different query',
        activation: harness.owner.activation,
      );
      await tester.pump();
      expect(
        find.descendant(of: decision, matching: find.text('Festa del borgo')),
        findsOneWidget,
      );
      harness.repository.candidatesResult = Result.success(
        AdminEventCandidates(
          events: const [AdminEventCandidate(id: 42, name: 'Unrelated result')],
          pendingWarnings: const [],
        ),
      );
      expect(
        harness.owner.requestFindCandidates(
          activation: harness.owner.activation,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: decision, matching: find.text('Festa del borgo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: decision, matching: find.text('Unrelated result')),
        findsNothing,
      );
      expect(find.text('Evento #42 · identità da verificare'), findsNothing);
      final link = find.widgetWithText(FilledButton, 'Collega a evento');
      expect(tester.widget<FilledButton>(link).onPressed, isNotNull);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(harness.repository.linkCalls, [(1, 42)]);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'obsolete candidate response cannot identify a replacement target',
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
      final pending = Completer<Result<AdminEventCandidates>>();
      harness.repository.onEventCandidates = (_, _, _) => pending.future;
      await harness.openEditor(tester, target: 1);
      expect(
        harness.owner.requestFindCandidates(
          activation: harness.owner.activation,
        ),
        isTrue,
      );
      await pumpCommandTurns(tester);
      harness.owner.setCandidateSearch(
        'new query',
        activation: harness.owner.activation,
      );
      harness.owner.selectTargetEvent(43, activation: harness.owner.activation);
      pending.complete(
        Result.success(
          AdminEventCandidates(
            events: const [
              AdminEventCandidate(id: 42, name: 'Obsolete candidate'),
            ],
            pendingWarnings: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final decision = find.byType(AdminSubmissionDecisionArea);
      expect(harness.owner.targetEventId, 43);
      expect(find.text('Obsolete candidate'), findsNothing);
      expect(
        find.descendant(
          of: decision,
          matching: find.text('Evento #43 · identità da verificare'),
        ),
        findsOneWidget,
      );
      final link = find.widgetWithText(FilledButton, 'Collega a evento');
      expect(tester.widget<FilledButton>(link).onPressed, isNotNull);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(harness.repository.linkCalls, [(1, 43)]);
    },
    disposeOwners: () => harness.dispose(),
  );
  for (final scale in [1.0, 2.0]) {
    for (final expanded in [false, true]) {
      testOwnerUI(
        'actual editor pins combined update risks and complete alternatives '
        '${expanded ? 'expanded' : 'compact'} at scale $scale',
        (tester) async {
          harness = AdminSaveRouteHarness();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(expanded ? 1800 : 320, 500);
          tester.view.viewInsets = const FakeViewPadding(bottom: 100);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final proposed = List.filled(
            70,
            'Descrizione proposta completa.',
          ).join(' ');
          final current = List.filled(
            70,
            'Descrizione attuale completa.',
          ).join(' ');
          harness.repository.getByIdResults[1] = Result.success(
            sampleAdminSubmission(
              name: 'Festa del paese',
              description: null,
              startDate: DateTime.utc(2026, 10, 2),
              targetEventId: 42,
              modifiedAtToken: '2026-08-20T00:00:00.123456Z',
              externalEvent: AdminExternalEvent(
                recordId: 12,
                snapshotHash: 'old-source',
                snapshotVersion: 1,
                snapshot: const {'name': 'Fonte precedente'},
                mode: AdminExternalEventMode.update,
                eventId: 42,
                currentHash: 'new-source',
                currentSnapshot: const {'name': 'Fonte aggiornata autorizzata'},
              ),
            ),
          );
          harness.repository.previewResult = Result.success(
            AdminEventMergePreview(
              targetEventId: 42,
              submissionVersionToken: 'submission-version',
              eventVersionToken: 'event-version',
              currentSourceHash: 'new-source',
              currentSourceSnapshot: const {
                'name': 'Fonte aggiornata autorizzata',
              },
              groups: [
                AdminEventMergeGroup(
                  name: 'description',
                  providerChanged: true,
                  moderatorChanged: true,
                  apply: true,
                  overwrite: true,
                  base: const {'description': 'Base completa'},
                  source: {'description': proposed},
                  moderated: {'description': proposed},
                  current: {'description': current},
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
          expect(
            harness.owner.requestPreview(activation: harness.owner.activation),
            isTrue,
          );
          await tester.pumpAndSettle();
          await openAdminEditorDecisions(tester);
          final area = find.byType(AdminSubmissionDecisionArea);
          expect(
            tester.widget<AdminSubmissionDecisionArea>(area).expanded,
            expanded,
          );
          final apply = find.widgetWithText(
            FilledButton,
            'Applica aggiornamento',
          );
          expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
          await tester.ensureVisible(apply);
          await tester.pumpAndSettle();
          expect(apply.hitTestable(), findsOneWidget);
          final risks = find.byKey(const ValueKey('admin_decision_risks'));
          await tester.ensureVisible(risks);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('1 sovrascrittura').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.textContaining('Fonte aggiornata').hitTestable(),
            findsOneWidget,
          );
          await showAdminEditorActions(tester);
          final secondary = find.byKey(
            const ValueKey('admin_decision_complete_scroll'),
          );
          final reject = find.widgetWithText(FilledButton, 'Rifiuta');
          await tester.ensureVisible(reject);
          await tester.pumpAndSettle();
          final target = tester.getRect(reject);
          final viewport = tester.getRect(secondary);
          expect(target.height, greaterThanOrEqualTo(48));
          expect(viewport.contains(target.topLeft), isTrue);
          expect(
            viewport.contains(target.bottomRight - const Offset(.01, .01)),
            isTrue,
          );
          expect(reject.hitTestable(), findsOneWidget);
          expect(tester.widget<FilledButton>(reject).onPressed, isNotNull);
          expect(
            tester.widget<SingleChildScrollView>(secondary).primary,
            isFalse,
          );
          await tester.ensureVisible(apply);
          await tester.pumpAndSettle();
          expect(apply.hitTestable(), findsOneWidget);
          await tester.ensureVisible(risks);
          await tester.pumpAndSettle();
          expect(risks.hitTestable(), findsOneWidget);
          await tester.tap(risks);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Esamina sovrascritture'));
          await tester.pumpAndSettle();
          expect(find.text('Descrizione').hitTestable(), findsOneWidget);
          expect(harness.repository.applyCalls, isEmpty);
          expect(harness.owner.acknowledgeCurrentSource, isFalse);
          expect(
            find.byKey(const ValueKey('admin_open_decisions')).hitTestable(),
            findsOneWidget,
          );
          await openAdminEditorDecisions(tester);
          await tester.ensureVisible(risks);
          await tester.pumpAndSettle();
          await tester.tap(risks);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Esamina fonte aggiornata'));
          await tester.pumpAndSettle();
          expect(
            find.text('Versione corrente della fonte').hitTestable(),
            findsOneWidget,
          );
          final sourceEvidence = find.textContaining(
            'Nome: Fonte aggiornata autorizzata',
          );
          await Scrollable.ensureVisible(
            tester.element(sourceEvidence),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          expect(sourceEvidence.hitTestable(), findsOneWidget);
          final acknowledgement = find.byKey(
            const ValueKey('admin_acknowledge_current_source'),
          );
          await Scrollable.ensureVisible(
            tester.element(acknowledgement),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          expect(acknowledgement.hitTestable(), findsOneWidget);
          expect(harness.owner.acknowledgeCurrentSource, isFalse);
          expect(harness.repository.applyCalls, isEmpty);
          expect(tester.takeException(), isNull);
        },
        disposeOwners: () => harness.dispose(),
      );
    }
  }
  for (final staleExternal in [false, true]) {
    testOwnerUI(
      'long ${staleExternal ? 'stale external' : 'human'} Link identity '
      'leaves the decision and one full alternative accessible',
      (tester) async {
        harness = AdminSaveRouteHarness();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.viewInsets = const FakeViewPadding(bottom: 100);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final title = List.filled(8, 'Festa del borgo').join(' ');
        final city = List.filled(10, 'Campobasso').join(' ').substring(0, 100);
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            description: null,
            startDate: DateTime.utc(2026, 10, 2),
            targetEventId: 42,
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
            externalEvent: staleExternal
                ? AdminExternalEvent(
                    recordId: 12,
                    snapshotHash: 'old',
                    snapshotVersion: 1,
                    snapshot: const {'name': 'Fonte precedente'},
                    mode: AdminExternalEventMode.create,
                    currentHash: 'new',
                    currentSnapshot: const {'name': 'Fonte aggiornata'},
                  )
                : null,
          ),
        );
        harness.repository.candidatesResult = Result.success(
          AdminEventCandidates(
            events: [AdminEventCandidate(id: 42, name: title, city: city)],
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
        expect(
          harness.owner.requestFindCandidates(
            activation: harness.owner.activation,
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        final candidate = find.byKey(
          const ValueKey('admin_event_candidate_42'),
        );
        final contentScroll = find
            .descendant(
              of: find.byKey(const ValueKey('admin_submission_editor_scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(contentScroll).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        await tester.ensureVisible(candidate);
        await tester.pumpAndSettle();
        final contentViewport = tester.getRect(
          find.byKey(const ValueKey('admin_submission_editor_scroll')),
        );
        await tester.tapAt(
          tester.getRect(candidate).intersect(contentViewport).center,
        );
        await tester.pumpAndSettle();
        expect(harness.owner.candidates, isNull);
        final area = find.byType(AdminSubmissionDecisionArea);
        final identity = find.descendant(of: area, matching: find.text(title));
        final link = find.widgetWithText(FilledButton, 'Collega a evento');
        expect(identity.hitTestable(), findsOneWidget);
        expect(link.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(link).onPressed, isNotNull);
        await showAdminEditorActions(tester);
        final save = find.widgetWithText(FilledButton, 'Salva modifiche');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        final viewport = tester.getRect(
          find.byKey(const ValueKey('admin_decision_secondary_scroll')),
        );
        final target = tester.getRect(save);
        expect(target.height, greaterThanOrEqualTo(48));
        expect(viewport.contains(target.topLeft), isTrue);
        expect(
          viewport.contains(target.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        expect(save.hitTestable(), findsOneWidget);
        expect(identity.hitTestable(), findsOneWidget);
        expect(link.hitTestable(), findsOneWidget);
        if (staleExternal) {
          expect(
            find.text('È disponibile una fonte aggiornata').hitTestable(),
            findsOneWidget,
          );
          expect(
            find
                .widgetWithText(TextButton, 'Esamina fonte aggiornata')
                .hitTestable(),
            findsOneWidget,
          );
        }
        expect(harness.repository.linkCalls, isEmpty);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI(
    'pending Preview exposes progress and rejects duplicate admission',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          description: null,
          startDate: DateTime.utc(2026, 10, 2),
          targetEventId: 42,
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          externalEvent: AdminExternalEvent(
            recordId: 12,
            snapshotHash: 'source',
            snapshotVersion: 1,
            snapshot: const {'name': 'Fonte'},
            mode: AdminExternalEventMode.update,
            eventId: 42,
          ),
        ),
      );
      final pending = Completer<Result<AdminEventMergePreview>>();
      harness.repository.pendingPreview = pending;
      await harness.openEditor(tester, target: 1);
      expect(harness.owner.isExternalUpdate, isTrue);
      expect(harness.owner.isDirty, isFalse);
      expect(harness.owner.canRequestPreview, isTrue);
      await showAdminEditorActions(tester);
      final preview = find.widgetWithText(
        FilledButton,
        'Anteprima aggiornamento',
      );
      final obsoleteRequest = tester.widget<FilledButton>(preview).onPressed!;
      await tester.tap(preview);
      await pumpCommandTurns(tester);
      expect(find.text('Preparazione anteprima…'), findsOneWidget);
      expect(harness.repository.previewCalls, [(1, 42)]);
      expect(tester.widget<FilledButton>(preview).onPressed, isNull);
      obsoleteRequest();
      await pumpCommandTurns(tester);
      expect(harness.repository.previewCalls, [(1, 42)]);
      expect(find.text('Preparazione anteprima…'), findsOneWidget);
      pending.complete(
        Result.error(Exception('Preview temporarily unavailable')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Preparazione anteprima…'), findsNothing);
      expect(harness.repository.applyCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
}
