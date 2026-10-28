import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';

void main() {
  const version = '2026-08-20T00:00:00.123456Z';
  const nextVersion = '2026-08-21T00:00:00.654321Z';
  late AdminSaveRouteHarness harness;

  testOwnerUI(
    'restored unchanged V offers captured A retry despite incomplete B',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      final original = harness.local.drafts.drafts.values.single;
      final a = original.snapshot.copyWith(name: 'Captured A');
      final b = a.copyWith(name: 'Checkpoint B', latitudeText: '-');
      harness.local.drafts.drafts[original.owner.lookupKey] =
          AdminSubmissionDraft(
            owner: original.owner,
            snapshot: b,
            remoteBaseline: original.remoteBaseline,
            fieldWriteIntent: AdminFieldWriteIntent(
              kind: AdminFieldWriteKind.update,
              attemptId: '11111111-1111-4111-8111-111111111111',
              snapshot: a,
              expectedModifiedAt: version,
            ),
          );
      harness.router.go(
        '/admin/submissions/1?session=${original.owner.sessionId}',
      );
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, isEmpty);
      expect(harness.owner.canRequestSave, isFalse);
      await tester.tap(find.text('Verifica esito remoto'));
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, isEmpty);
      expect(harness.owner.canRequestSave, isFalse);
      expect(find.text('Riprendi salvataggio'), findsOneWidget);
      final pending = Completer<Result<AdminSubmission>>();
      harness.repository.pendingUpdate = pending;
      await tester.tap(find.text('Riprendi salvataggio'));
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      expect(harness.repository.updateIds, [1]);
      expect(harness.repository.updateInputs.single.name, a.name);
      expect(harness.repository.updateExpectedModifiedAt, [version]);
      final confirmed = sampleAdminSubmission(
        name: a.name!,
        description: null,
        modifiedAtToken: nextVersion,
      );
      harness.repository.getByIdResults[1] = Result.success(confirmed);
      pending.complete(Result.success(confirmed));
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, [1]);
      expect(harness.local.session.state!.current, b);
      expect(harness.local.session.state!.physicalCheckpoint!.snapshot, b);
      expect(
        harness.local.session.state!.physicalCheckpoint!.fieldWriteIntent,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'progress local repair sends no HTTP and editor requires fresh authority',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      harness.router.go('/admin/submissions/1');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final activation = harness.owner.activation;
      harness.owner.setName('Changed A', activation: activation);
      harness.repository.updateResult = const Result.error(
        AdminContentSubmissionApiException(
          statusCode: 409,
          code: 'SUBMISSION_CHANGED',
          message: 'Conditional write rejected.',
        ),
      );
      harness.local.drafts.onSave = (draft) async =>
          draft.fieldWriteIntent == null
          ? Result.error(Exception('Local settlement unavailable'))
          : const Result.success(null);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Salva modifiche'),
        500,
        scrollable: find
            .descendant(
              of: find.byType(AdminSubmissionEditorScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Salva modifiche'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      expect(find.text('Ripristina salvataggio locale'), findsOneWidget);
      expect(find.text('Verifica esito remoto'), findsNothing);
      expect(find.text('Riprova'), findsNothing);
      expect(harness.repository.updateIds, [1]);
      harness.local.drafts.onSave = null;
      await tester.tap(find.text('Ripristina salvataggio locale'));
      await tester.pumpAndSettle();
      expect(harness.repository.updateIds, [1]);
      expect(
        harness.local.session.state!.physicalCheckpoint!.fieldWriteIntent,
        isNull,
      );
      expect(harness.owner.canRequestSave, isFalse);
      await tester.tap(find.text('Torna all’editor'));
      await tester.pumpAndSettle();
      await tester.drag(
        find
            .descendant(
              of: find.byType(AdminSubmissionEditorScreen),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, 1800),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ricarica stato remoto'), findsOneWidget);
      expect(harness.owner.canRequestSave, isFalse);
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Target 1',
          description: null,
          modifiedAtToken: nextVersion,
        ),
      );
      await tester.tap(find.text('Ricarica stato remoto'));
      await tester.pumpAndSettle();
      expect(harness.owner.canRequestSave, isTrue);
      expect(
        harness.local.session.state!.remoteBaseline!.modifiedAtToken,
        nextVersion,
      );
      expect(harness.owner.name, 'Changed A');
      expect(harness.repository.updateIds, [1]);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
}
