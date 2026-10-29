import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';

void main() {
  const version = '2026-08-20T00:00:00.123456Z';
  const nextVersion = '2026-08-21T00:00:00.654321Z';
  late AdminSaveRouteHarness harness;

  testOwnerUI('Accept is local-only and route hints cannot bypass F1 refusal', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
    final original = harness.local.drafts.drafts.values.firstWhere(
      (draft) => draft.owner.submissionId == 1,
    );
    final local = original.snapshot.copyWith(name: 'Local fields');
    harness.local.drafts.drafts[original.owner.lookupKey] =
        AdminSubmissionDraft(
          owner: original.owner,
          snapshot: local,
          remoteBaseline: original.remoteBaseline,
        );
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'Remote fields',
        description: null,
        modifiedAtToken: nextVersion,
      ),
    );
    harness.router.go('/admin/submissions/1');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin_recovery_comparison')),
      findsOneWidget,
    );
    expect(find.text('Local fields'), findsWidgets);
    expect(find.text('Remote fields'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin_accept_remote')),
    );
    await tester.tap(find.byKey(const ValueKey('admin_accept_remote')));
    await tester.pumpAndSettle();
    expect(harness.owner.name, 'Remote fields');
    expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
    expect(harness.local.session.state!.hasUncheckpointedChanges, isFalse);
    expect(harness.local.session.state!.physicalCheckpoint!.snapshot, local);
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.repository.updateIds, isEmpty);
    expect(harness.repository.rejectIds, isEmpty);
    final session = harness.owner.sessionId;
    harness.router.go('/admin/submissions/1?session=$session');
    await tester.pumpAndSettle();
    expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
    expect(harness.owner.name, 'Remote fields');
    final otherOwner = harness.local.drafts.drafts.values
        .firstWhere((draft) => draft.owner.submissionId == 2)
        .owner;
    harness.router.go('/admin/submissions/2?session=${otherOwner.sessionId}');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('prima di aprire un altro contributo.'),
      findsOneWidget,
    );
    expect(harness.owner.submissionId, 1);
    await tester.tap(find.byKey(const ValueKey('admin_return_active_editor')));
    await tester.pumpAndSettle();
    expect(harness.owner.sessionId, session);
    expect(harness.owner.name, 'Remote fields');
    harness.local.drafts.onSave = (_) async =>
        Result.error(Exception('disk failure'));
    await tester.ensureVisible(find.text('Salva bozza locale'));
    await tester.tap(find.text('Salva bozza locale'));
    await tester.pumpAndSettle();
    expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
    expect(harness.local.session.state!.physicalCheckpoint!.snapshot, local);
    harness.router.go('/admin/submissions/2');
    await tester.pumpAndSettle();
    expect(harness.owner.submissionId, 1);
    await tester.tap(find.byKey(const ValueKey('admin_return_active_editor')));
    await tester.pumpAndSettle();
    harness.local.drafts.onSave = null;
    await tester.ensureVisible(find.text('Salva bozza locale'));
    await tester.tap(find.text('Salva bozza locale'));
    await tester.pumpAndSettle();
    expect(harness.owner.pendingRecoveryCheckpoint, isFalse);
    harness.router.go('/admin/submissions/2');
    await tester.pumpAndSettle();
    expect(harness.owner.submissionId, 2);
    harness.router.go('/admin/submissions/1');
    await tester.pumpAndSettle();
    expect(harness.owner.name, 'Remote fields');
    expect(harness.repository.updateIds, isEmpty);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'Keep performs no Update and obsolete Accept cannot act in A2 or logout',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
      final original = harness.local.drafts.drafts.values.firstWhere(
        (draft) => draft.owner.submissionId == 1,
      );
      final local = original.snapshot.copyWith(name: 'Retained local');
      harness.local.drafts.drafts[original.owner.lookupKey] =
          AdminSubmissionDraft(
            owner: original.owner,
            snapshot: local,
            remoteBaseline: original.remoteBaseline,
          );
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Remote W',
          description: null,
          modifiedAtToken: nextVersion,
        ),
      );
      harness.router.go('/admin/submissions/1');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final obsoleteAccept = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('admin_accept_remote')),
          )
          .onPressed!;
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin_keep_local')),
      );
      await tester.tap(find.byKey(const ValueKey('admin_keep_local')));
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Retained local');
      expect(
        find.textContaining('Impossibile caricare il contributo.'),
        findsNothing,
      );
      expect(harness.owner.canRequestSave, isTrue);
      expect(
        harness.local.session.state!.remoteBaseline!.modifiedAtToken,
        nextVersion,
      );
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.repository.updateIds, isEmpty);
      obsoleteAccept();
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Retained local');
      final other = harness.local.drafts.drafts.values.firstWhere(
        (draft) => draft.owner.submissionId == 2,
      );
      harness.router.go(
        '/admin/submissions/2?session=${other.owner.sessionId}',
      );
      await tester.pumpAndSettle();
      harness.router.go('/admin/submissions/1');
      await tester.pumpAndSettle();
      obsoleteAccept();
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Retained local');
      final currentAccept = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('admin_accept_remote')),
          )
          .onPressed!;
      harness.auth.setUser(makeAuthUser(isAnonymous: true));
      harness.auth.emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();
      currentAccept();
      obsoleteAccept();
      await tester.pumpAndSettle();
      expect(harness.owner.accountId, isNull);
      expect(
        harness.local.drafts.drafts[original.owner.lookupKey]!.snapshot,
        local,
      );
      expect(harness.repository.updateIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('unmounted recovery button cannot change retained editor', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    final original = harness.local.drafts.drafts.values.single;
    harness.local.drafts.drafts[original.owner.lookupKey] =
        AdminSubmissionDraft(
          owner: original.owner,
          snapshot: original.snapshot.copyWith(name: 'Local to preserve'),
          remoteBaseline: original.remoteBaseline,
        );
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'Observed remote',
        description: null,
        modifiedAtToken: nextVersion,
      ),
    );
    harness.router.go('/admin/submissions/1');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final accept = tester
        .widget<FilledButton>(find.byKey(const ValueKey('admin_accept_remote')))
        .onPressed!;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    accept();
    await tester.pumpAndSettle();
    expect(harness.owner.name, 'Local to preserve');
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.repository.updateIds, isEmpty);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

  for (final failure in [
    const AdminContentSubmissionApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'missing',
    ),
    const AdminContentSubmissionApiException(
      statusCode: 401,
      code: 'UNAUTHORIZED',
      message: 'unauthorized',
    ),
    const AdminContentSubmissionApiException(
      statusCode: 403,
      code: 'FORBIDDEN',
      message: 'forbidden',
    ),
    TestException('network unavailable'),
  ]) {
    testOwnerUI(
      'initial $failure settles with checkpoint return and explicit retry',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [1]);
        final original = harness.local.drafts.drafts.values.single;
        harness.repository.getByIdResults[1] = Result.error(failure);
        harness.router.go('/admin/submissions/1');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.text('Modifica contributo'), findsOneWidget);
        expect(find.text('Salva bozza locale'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('admin_recovery_return')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('admin_recovery_reload')),
          findsOneWidget,
        );
        expect(harness.owner.canRequestSave, isFalse);
        expect(harness.local.session.state!.physicalCheckpoint, original);
        final reads = harness.repository.getByIdIds.length;
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            name: 'Target 1',
            description: null,
            modifiedAtToken: nextVersion,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('admin_recovery_reload')));
        await tester.pumpAndSettle();
        expect(harness.repository.getByIdIds.length, reads + 1);
        expect(harness.owner.recoveryState, AdminEditorRecoveryState.none);
        expect(harness.repository.updateIds, isEmpty);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  for (final status in [
    AdminSubmissionStatus.accepted,
    AdminSubmissionStatus.rejected,
  ]) {
    testOwnerUI(
      'final ${status.name} retains local fields and local photo removal',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [1]);
        final original = harness.local.drafts.drafts.values.single;
        final local = original.snapshot.copyWith(name: 'Local unfinished');
        harness.local.drafts.drafts[original.owner.lookupKey] =
            AdminSubmissionDraft(
              owner: original.owner,
              snapshot: local,
              remoteBaseline: original.remoteBaseline,
            );
        final asset = AdminSubmissionStagedAsset(
          owner: original.owner,
          digest: 'a' * 40,
          relativePath:
              '${original.owner.accountId}/${original.owner.sessionId}/${'a' * 40}',
          progress: AdminStagedAssetProgress(
            upload: const SubmissionAsset(
              secureUrl: 'https://example.com/upload.jpg',
              width: 10,
              height: 20,
            ),
            associationId: 77,
          ),
        );
        harness.local.staged.assets[original.owner] = [asset];
        harness.local.staged.onResolve = (_) async =>
            Result.error(Exception('preview unavailable'));
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(
            status: status,
            name: 'Final remote',
            description: null,
            modifiedAtToken: nextVersion,
          ),
        );
        harness.router.go('/admin/submissions/1');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.text('Stato remoto: ${status.label}'), findsOneWidget);
        expect(harness.owner.name, 'Local unfinished');
        expect(harness.owner.canRequestSave, isFalse);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('admin_keep_local')),
              )
              .onPressed,
          isNull,
        );
        final item = find.byKey(ValueKey('admin_staged_${asset.digest}'));
        await tester.scrollUntilVisible(
          item,
          400,
          scrollable: find
              .descendant(
                of: find.byType(AdminSubmissionEditorScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: item, matching: find.byType(InkWell)),
        );
        await tester.pumpAndSettle();
        expect(harness.owner.stagedAssets, isEmpty);
        expect(harness.repository.deleteAssetCalls, isEmpty);
        expect(
          harness.local.drafts.drafts[original.owner.lookupKey],
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI('recovery invalidates an already-open moderation confirmation', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    harness.router.go('/admin/submissions/1');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Rifiuta'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(AdminSubmissionEditorScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Rifiuta'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    harness.owner.setName('Later local', activation: harness.owner.activation);
    await harness.owner.checkpointLocal();
    harness.repository.getByIdResults[1] = Result.success(
      sampleAdminSubmission(
        name: 'Remote changed',
        description: null,
        modifiedAtToken: nextVersion,
      ),
    );
    harness.owner.requestLoad(activation: harness.owner.activation);
    await tester.pumpAndSettle();
    final observation = harness.owner.recoveryObservation!;
    harness.owner.requestReconcile(
      observation,
      acceptRemote: true,
      activation: harness.owner.activation,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
    await tester.pumpAndSettle();
    expect(harness.repository.rejectIds, isEmpty);
    expect(harness.owner.name, 'Remote changed');
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

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
