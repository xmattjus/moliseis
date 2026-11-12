import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_decision_area.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/admin_editor_interactions.dart';
import '../../../../support/admin_save_route_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';

void main() {
  late AdminSaveRouteHarness harness;

  for (final change in [
    'manual ID',
    'target replacement',
    'new activation',
    'Place conversion',
    'obsolete search response',
  ]) {
    testOwnerUI(
      'selected candidate identity respects $change',
      (tester) async {
        harness = AdminSaveRouteHarness();
        await tester.binding.setSurfaceSize(const Size(600, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final id in [1, 2]) {
          harness.repository.getByIdResults[id] = Result.success(
            sampleAdminSubmission(
              id: id,
              description: null,
              startDate: DateTime.utc(2026, 10, 2),
              targetEventId: 42,
              modifiedAtToken: '2026-08-20T00:00:00.123456Z',
            ),
          );
        }
        harness.repository.candidatesResult = Result.success(
          AdminEventCandidates(
            events: const [
              AdminEventCandidate(
                id: 42,
                name: 'Festa scelta',
                city: 'Isernia',
              ),
              AdminEventCandidate(
                id: 43,
                name: 'Altro evento',
                city: 'Termoli',
              ),
            ],
            pendingWarnings: const [],
          ),
        );
        await harness.openEditor(tester, target: 1);
        final search = find.byKey(const ValueKey('admin_event_search'));
        await revealAdminEditorWidget(tester, search);
        await tester.enterText(search, 'Festa');
        await revealAdminEditorWidget(tester, find.text('Cerca eventi'));
        await tester.tap(find.text('Cerca eventi'));
        await tester.pumpAndSettle();
        final candidate = find.byKey(
          const ValueKey('admin_event_candidate_42'),
        );
        await revealAdminEditorWidget(tester, candidate);
        final obsoleteSelection = tester.widget<ListTile>(candidate).onTap!;
        await tester.tap(candidate);
        await tester.pumpAndSettle();
        expect(harness.owner.candidates, isNull);
        expect(find.text('Festa scelta'), findsNWidgets(2));
        final decision = find.byType(AdminSubmissionDecisionArea);

        if (change == 'manual ID') {
          final target = find.byKey(const ValueKey('admin_event_target'));
          await revealAdminEditorWidget(tester, target);
          // Even the same manually entered ID no longer claims a selected name.
          await tester.enterText(target, '0042');
          await tester.pumpAndSettle();
          expect(find.text('Festa scelta'), findsNothing);
          expect(
            find.text('Evento #42 · identità da verificare'),
            findsNWidgets(2),
          );
          await tester.enterText(target, '43');
          await tester.pumpAndSettle();
          obsoleteSelection();
          await tester.pumpAndSettle();
          expect(harness.owner.targetEventId, 43);
          final link = find.widgetWithText(FilledButton, 'Collega a evento');
          await tester.tap(link);
          await tester.pumpAndSettle();
          expect(harness.repository.linkCalls, [(1, 43)]);
        } else if (change == 'target replacement') {
          expect(
            harness.owner.requestFindCandidates(
              activation: harness.owner.activation,
            ),
            isTrue,
          );
          await tester.pumpAndSettle();
          final next = find.byKey(const ValueKey('admin_event_candidate_43'));
          await revealAdminEditorWidget(tester, next);
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(harness.owner.targetEventId, 43);
          expect(harness.owner.candidates, isNull);
          expect(find.text('Festa scelta'), findsNothing);
          expect(find.text('Altro evento'), findsNWidgets(2));
          expect(find.text('Termoli'), findsNWidgets(2));
          obsoleteSelection();
          await tester.pumpAndSettle();
          expect(harness.owner.targetEventId, 43);
          expect(find.text('Altro evento'), findsNWidgets(2));
        } else if (change == 'new activation') {
          final activation = harness.owner.activation;
          harness.router.go('/admin/submissions/2');
          await tester.pumpAndSettle();
          expect(harness.owner.isActivationCurrent(activation), isFalse);
          expect(harness.owner.submissionId, 2);
          obsoleteSelection();
          await tester.pumpAndSettle();
          expect(find.text('Festa scelta'), findsNothing);
          expect(
            find.descendant(
              of: decision,
              matching: find.text('Evento #42 · identità da verificare'),
            ),
            findsOneWidget,
          );
          await revealAdminEditorWidget(
            tester,
            find.byKey(const ValueKey('admin_event_target')),
          );
          expect(
            find.text('Evento #42 · identità da verificare'),
            findsNWidgets(2),
          );
        } else if (change == 'Place conversion') {
          harness.repository.updateResult = Result.success(
            sampleAdminSubmission(
              description: null,
              targetEventId: 42,
              modifiedAtToken: '2026-08-21T00:00:00.123456Z',
            ),
          );
          harness.owner.setEventEnabled(
            enabled: false,
            activation: harness.owner.activation,
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(FilledButton, 'Salva modifiche'),
          );
          await tester.pumpAndSettle();
          expect(harness.repository.updateIds, [1]);
          harness.router.pop();
          await tester.pumpAndSettle();
          expect(harness.owner.targetEventId, 42);
          expect(harness.owner.startDate, isNull);
          expect(find.text('Collega a evento'), findsNothing);
          expect(
            find.descendant(of: decision, matching: find.text('Festa scelta')),
            findsNothing,
          );
          expect(harness.repository.linkCalls, isEmpty);
        } else {
          final pending = Completer<Result<AdminEventCandidates>>();
          harness.repository.onEventCandidates = (_, _, _) => pending.future;
          harness.owner.setCandidateSearch(
            'older query',
            activation: harness.owner.activation,
          );
          expect(
            harness.owner.requestFindCandidates(
              activation: harness.owner.activation,
            ),
            isTrue,
          );
          await pumpCommandTurns(tester);
          harness.owner.setCandidateSearch(
            'newer query',
            activation: harness.owner.activation,
          );
          pending.complete(
            Result.success(
              AdminEventCandidates(
                events: const [
                  AdminEventCandidate(id: 42, name: 'Obsolete label'),
                ],
                pendingWarnings: const [],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(harness.owner.candidates, isNull);
          expect(find.text('Obsolete label'), findsNothing);
          expect(find.text('Festa scelta'), findsNWidgets(2));
          expect(find.text('Isernia'), findsNWidgets(2));
        }
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () {
        harness.dispose();
      },
    );
  }
}
