import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/admin_draft_repositories.dart';
import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/predictive_back.dart';
import '../support/test_image_files.dart';

void main() {
  late AdminSaveRouteHarness harness;

  testOwnerUI('pristine New exits without a field dialog or local write', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    await harness.openEditor(tester);
    expect(harness.owner.isDirty, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsNothing);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.repository.createInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('remote unsaved checkpoint-clean fields exit without a prompt', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName(
      'Checkpointed remote work',
      activation: harness.owner.activation,
    );
    await harness.owner.checkpointLocal();
    final saves = harness.local.drafts.saves.length;
    expect(harness.owner.isDirty, isTrue);
    expect(harness.owner.hasUncheckpointedChanges, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsNothing);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(harness.local.drafts.saves.length, saves);
    expect(harness.repository.updateIds, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('durable staged receipt alone does not prompt or mutate work', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    final draft = harness.local.drafts.drafts.values.single;
    final images = TestImageFiles.create();
    addTearDown(images.dispose);
    final image = images.createPng();
    const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final asset = AdminSubmissionStagedAsset(
      owner: draft.owner,
      digest: digest,
      relativePath: '${draft.owner.accountId}/${draft.owner.sessionId}/$digest',
      progress: AdminStagedAssetProgress(
        upload: const SubmissionAsset(
          secureUrl: 'https://example.com/upload.png',
          width: 1,
          height: 1,
        ),
      ),
    );
    harness.local.staged.assets[draft.owner] = [asset];
    harness.local.staged.onResolve = (_) async =>
        Result.success(File(image.path));
    await harness.openEditor(tester, target: 1);
    expect(harness.owner.isDirty, isTrue);
    expect(harness.owner.hasUncheckpointedChanges, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsNothing);
    expect(harness.local.staged.assets[draft.owner], [asset]);
    expect(harness.repository.addAssetCalls, isEmpty);
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  for (final choice in ['Annulla', 'Salva ed esci', 'Esci senza salvare']) {
    testOwnerUI('dirty AppBar Back uses one three-choice decision: $choice', (
      tester,
    ) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      final original = harness.local.session.state!.effective;
      harness.owner.setName(
        'Uncheckpointed A',
        activation: harness.owner.activation,
      );
      await tester.tap(find.byType(CustomBackButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);
      expect(find.text('Salva ed esci'), findsOneWidget);
      expect(find.text('Esci senza salvare'), findsOneWidget);
      expect(
        find.textContaining('non salva il contributo sul server.'),
        findsOneWidget,
      );
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      if (choice == 'Annulla') {
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(harness.owner.name, 'Uncheckpointed A');
        expect(harness.local.drafts.saves, isEmpty);
      } else {
        expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
        if (choice == 'Salva ed esci') {
          expect(
            harness.local.session.state!.physicalCheckpoint!.snapshot.name,
            'Uncheckpointed A',
          );
        } else {
          expect(harness.local.session.state!.current, original);
          expect(harness.local.drafts.saves, isEmpty);
        }
      }
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateIds, isEmpty);
      expect(harness.repository.addAssetCalls, isEmpty);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI('failed Exit checkpoint retains fields and route for retry', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName(
      'Keep after failure',
      activation: harness.owner.activation,
    );
    harness.local.drafts.onSave = (_) async =>
        Result.error(Exception('disk failed'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva ed esci'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.name, 'Keep after failure');
    expect(harness.owner.hasUncheckpointedChanges, isTrue);
    expect(harness.owner.exitDecisionPending, isFalse);
    expect(harness.repository.updateIds, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('discard returns to E after hydration leaves P different', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    final physical = harness.local.drafts.drafts.values.single;
    await harness.openEditor(tester, target: 1);
    final remote = AdminRemoteBaseline(
      snapshot: physical.snapshot.copyWith(name: 'Hydrated B'),
      status: AdminSubmissionStatus.pending,
      modifiedAt: DateTime.utc(2026, 10, 29),
      modifiedAtToken: '2026-10-29T00:00:00.123456Z',
    );
    final token = harness.local.session.admitHydration()!;
    await harness.local.session.acceptHydration(
      token,
      remote,
      associatedCount: 0,
    );
    harness.owner.setName('Typing C', activation: harness.owner.activation);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esci senza salvare'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(harness.local.session.state!.current.name, 'Hydrated B');
    expect(harness.local.session.state!.physicalCheckpoint, physical);
    expect(harness.local.session.state!.remoteBaseline, remote);
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('newer fields supersede discard review without being discarded', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName('Reviewed A', activation: harness.owner.activation);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    harness.owner.setName('New B', activation: harness.owner.activation);
    await tester.tap(find.text('Esci senza salvare'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.name, 'New B');
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'Exit checkpoint queued behind local work never captures unreviewed B',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Reviewed A', activation: harness.owner.activation);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      harness.local.drafts.onSave = (_) {
        entered.complete();
        return release.future;
      };
      final ordinary = harness.local.session.checkpoint();
      await tester.pump();
      expect(entered.isCompleted, isTrue);
      await tester.tap(find.text('Salva ed esci'));
      await tester.pump();
      harness.owner.setName(
        'Unreviewed B',
        activation: harness.owner.activation,
      );
      release.complete(const Result.success(null));
      await tester.pumpAndSettle();
      await ordinary;
      expect(harness.local.drafts.saves, hasLength(1));
      expect(harness.local.drafts.saves.single.snapshot.name, 'Reviewed A');
      expect(harness.owner.name, 'Unreviewed B');
      expect(harness.owner.hasUncheckpointedChanges, isTrue);
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('started Exit write settles A while newer B retains the editor', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName('Reviewed A', activation: harness.owner.activation);
    final entered = Completer<void>();
    final release = Completer<Result<void>>();
    harness.local.drafts.onSave = (_) {
      entered.complete();
      return release.future;
    };
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva ed esci'));
    await tester.pump();
    expect(entered.isCompleted, isTrue);
    harness.owner.setName('New B', activation: harness.owner.activation);
    release.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(
      harness.local.session.state!.physicalCheckpoint!.snapshot.name,
      'Reviewed A',
    );
    expect(harness.local.session.state!.effective.name, 'Reviewed A');
    expect(harness.owner.name, 'New B');
    expect(harness.owner.hasUncheckpointedChanges, isTrue);
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'Back owns its decision and competing programmatic target is refused',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Retained A', activation: harness.owner.activation);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      harness.router.go('/admin/submissions/2');
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      expect(harness.owner.submissionId, 1);
      await tester.tap(find.text('Salva ed esci'));
      await tester.pumpAndSettle();
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin',
      );
      expect(harness.owner.submissionId, 1);
      expect(harness.local.drafts.saves, hasLength(1));
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('two parser removals cannot reuse affirmative permission', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2, 3]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName('Reviewed A', activation: harness.owner.activation);
    harness.router.go('/admin/submissions/2');
    harness.router.go('/admin/submissions/3');
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(harness.owner.submissionId, 1);
    expect(
      harness.router.routerDelegate.currentConfiguration.uri.path,
      '/admin/submissions/1',
    );
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('different ID on same route pattern requires an exit decision', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName(
      'Uncheckpointed A',
      activation: harness.owner.activation,
    );
    harness.router.go('/admin/submissions/2');
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    expect(harness.owner.submissionId, 1);
    await tester.tap(find.text('Esci senza salvare'));
    await tester.pumpAndSettle();
    expect(harness.owner.submissionId, 2);
    expect(harness.owner.name, 'Target 2');
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'query-only session change cannot abandon uncheckpointed fields',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Private A', activation: harness.owner.activation);
      harness.router.go(
        '/admin/submissions/1?session=99999999-9999-4999-8999-999999999999',
      );
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(harness.owner.name, 'Private A');
      expect(
        harness
            .router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['session'],
        isNull,
      );
      expect(harness.local.drafts.saves, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('covered exit dialog permanently loses authority', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName('Private A', activation: harness.owner.activation);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final navigator =
        Navigator.of(tester.element(find.byType(UnsavedChangesDialog)))..push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Cover')),
          ),
        );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva ed esci'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.name, 'Private A');
    expect(harness.local.drafts.saves, isEmpty);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'auth revocation retires pending modal without waiting for a choice',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Private A', activation: harness.owner.activation);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      harness.auth.setUser(null);
      harness.auth.emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.owner.sessionId, isNull);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'desktop Escape enters policy and modal Escape cancels only modal',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Private A', activation: harness.owner.activation);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(harness.owner.name, 'Private A');
    },
    disposeOwners: () => harness.dispose(),
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testOwnerUI(
    'iOS clean native swipe available while dirty swipe is disabled',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      final route =
          ModalRoute.of(
                tester.element(find.byType(AdminSubmissionEditorScreen)),
              )!
              as PageRoute<dynamic>;
      expect(route.popGestureEnabled, isTrue);
      harness.owner.setName('Dirty A', activation: harness.owner.activation);
      await tester.pump();
      expect(route.popGestureEnabled, isFalse);
      await tester.dragFrom(const Offset(1, 200), const Offset(350, 0));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      await tester.tap(find.byType(CustomBackButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(route.popGestureEnabled, isFalse);
    },
    disposeOwners: () => harness.dispose(),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testOwnerUI(
    'Android predictive Back reaches the same dirty decision',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Dirty A', activation: harness.owner.activation);
      await startPredictiveBack(tester);
      await updatePredictiveBack(tester, 0.7);
      await commitPredictiveBack(tester);
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    },
    disposeOwners: () => harness.dispose(),
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testOwnerUI(
    'unresolved durable field intent alone does not trigger field discard',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      final draft = harness.local.drafts.drafts.values.single;
      harness.local.drafts.drafts[draft.owner.lookupKey] = AdminSubmissionDraft(
        owner: draft.owner,
        snapshot: draft.snapshot,
        remoteBaseline: draft.remoteBaseline,
        fieldWriteIntent: AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: '11111111-1111-4111-8111-111111111111',
          snapshot: draft.snapshot,
          expectedModifiedAt: draft.remoteBaseline!.modifiedAtToken,
        ),
      );
      await harness.openEditor(tester, target: 1);
      expect(harness.owner.isDirty, isTrue);
      expect(harness.owner.hasUncheckpointedChanges, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(
        harness.local.session.state!.physicalCheckpoint!.fieldWriteIntent,
        isNotNull,
      );
      expect(harness.repository.updateIds, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'terminal progress pop retains dirty editor without its exit dialog',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName(
        'Dirty underneath',
        activation: harness.owner.activation,
      );
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {'session': harness.owner.sessionId, 'editor': '1'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsNothing);
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(harness.owner.name, 'Dirty underneath');
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.repository.updateIds, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  for (final dirty in [false, true]) {
    testOwnerUI('pending recovery survives page removal and blocks switching '
        'dirty=$dirty', (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
      await harness.openEditor(tester, target: 1);
      final original = harness.local.session.state!.physicalCheckpoint!;
      final remote = AdminRemoteBaseline(
        snapshot: original.snapshot.copyWith(name: 'Accepted B'),
        status: AdminSubmissionStatus.pending,
        modifiedAt: DateTime.utc(2026, 10, 29),
        modifiedAtToken: '2026-10-29T00:00:00.654321Z',
      );
      final token = harness.local.session.admitHydration()!;
      await harness.local.session.acceptHydration(
        token,
        remote,
        associatedCount: 0,
        requireReconciliation: true,
      );
      final observation = harness.local.session.captureRecoveryObservation(
        token,
        remote,
        associatedCount: 0,
      )!;
      await harness.local.session.reconcile(observation, acceptRemote: true);
      harness.owner.setName(
        dirty ? 'New C' : 'Accepted B',
        activation: harness.owner.activation,
      );
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
      final session = harness.owner.sessionId;
      harness.router.go('/admin/submissions/2');
      await tester.pumpAndSettle();
      expect(harness.owner.submissionId, 1);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(
        find.text(
          'Salva nella bozza locale i campi remoti accettati '
          'prima di aprire un altro contributo.',
        ),
        findsOneWidget,
      );
      harness.router.go('/admin');
      await tester.pumpAndSettle();
      if (dirty) {
        expect(find.byType(UnsavedChangesDialog), findsOneWidget);
        await tester.tap(find.text('Esci senza salvare'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
      expect(harness.local.session.state!.current.name, 'Accepted B');
      expect(harness.local.session.state!.physicalCheckpoint, original);
      harness.router.go('/admin/submissions/1?session=$session');
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
      expect(harness.owner.name, 'Accepted B');
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.repository.updateIds, isEmpty);
    }, disposeOwners: () => harness.dispose());
  }
  testOwnerUI(
    'revocation during started Exit checkpoint navigates before write settles',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      final owner = harness.local.session.state!.owner;
      harness.owner.setName(
        'Private reviewed A',
        activation: harness.owner.activation,
      );
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      harness.local.drafts.onSave = (_) {
        entered.complete();
        return release.future;
      };
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva ed esci'));
      await tester.pump();
      expect(entered.isCompleted, isTrue);
      harness.auth.setUser(null);
      harness.auth.emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(harness.owner.sessionId, isNull);
      release.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(
        harness.local.drafts.drafts[owner.lookupKey]!.snapshot.name,
        'Private reviewed A',
      );
      expect(harness.owner.sessionId, isNull);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('admitted remote Save refuses ordinary exit without a dialog', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName(
      'Remote save A',
      activation: harness.owner.activation,
    );
    final gate = Completer<Result<AdminSubmission>>();
    harness.repository.pendingUpdate = gate;
    expect(
      harness.owner.requestSave(activation: harness.owner.activation),
      isTrue,
    );
    await pumpCommandTurns(tester);
    await tester.binding.handlePopRoute();
    await pumpCommandTurns(tester);
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(find.byType(UnsavedChangesDialog), findsNothing);
    expect(harness.owner.isSaveRunning, isTrue);
    gate.complete(
      Result.success(
        sampleAdminSubmission(
          name: 'Remote save A',
          description: null,
          modifiedAtToken: '2026-10-29T00:00:00.123456Z',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.repository.updateIds, [1]);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'clean iOS native edge swipe removes only the editor',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      await tester.dragFrom(const Offset(1, 200), const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin',
      );
      expect(harness.local.drafts.saves, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testOwnerUI(
    'current successful moderation closes its editor without dirty dialog',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      expect(
        harness.owner.requestReject(activation: harness.owner.activation),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(harness.repository.rejectIds, [1]);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin',
      );
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'moderation terminal under covering page cannot close editor on return',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      final navigator =
          Navigator.of(tester.element(find.byType(AdminSubmissionEditorScreen)))
            ..push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            );
      await tester.pumpAndSettle();
      expect(
        harness.owner.requestReject(activation: harness.owner.activation),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cover'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin/submissions/1',
      );
      expect(find.byType(UnsavedChangesDialog), findsNothing);
    },
    disposeOwners: () => harness.dispose(),
  );
  testOwnerUI('covered modal action cannot pop a different top route', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName('Reviewed A', activation: harness.owner.activation);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final action = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Salva ed esci'),
        )
        .onPressed!;
    final navigator =
        Navigator.of(tester.element(find.byType(UnsavedChangesDialog)))..push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Cover protects current route')),
          ),
        );
    await tester.pumpAndSettle();
    action();
    await tester.pumpAndSettle();
    expect(find.text('Cover protects current route'), findsOneWidget);
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.owner.name, 'Reviewed A');
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'retired pushed visit cannot unregister the restored source visit',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
      await harness.openEditor(tester, target: 1);
      unawaited(harness.router.push('/admin/submissions/2'));
      await tester.pumpAndSettle();
      expect(harness.owner.submissionId, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(harness.owner.submissionId, 1);
      harness.owner.setName(
        'Restored visit edit',
        activation: harness.owner.activation,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Restored visit edit');
      expect(harness.local.drafts.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
  for (final dirty in [false, true]) {
    testOwnerUI(
      'terminal Progress full-stack replacement protects editor dirty=$dirty',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [1]);
        await harness.openEditor(tester, target: 1);
        if (dirty) {
          harness.owner.setName(
            'Retained editor A',
            activation: harness.owner.activation,
          );
        }
        unawaited(
          harness.router.pushNamed(
            RouteNames.adminSubmissionSaveProgress,
            queryParameters: {
              'session': harness.owner.sessionId,
              'editor': '1',
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
        harness.router.go('/admin');
        await tester.pumpAndSettle();
        if (dirty) {
          expect(find.byType(UnsavedChangesDialog), findsOneWidget);
          await tester.tap(find.text('Annulla'));
          await tester.pumpAndSettle();
          expect(
            find.byType(AdminSubmissionSaveProgressScreen),
            findsOneWidget,
          );
          expect(harness.owner.name, 'Retained editor A');
          harness.router.go('/admin');
          await tester.pumpAndSettle();
          expect(find.byType(UnsavedChangesDialog), findsOneWidget);
          await tester.tap(find.text('Salva ed esci'));
          await tester.pumpAndSettle();
          expect(
            harness.local.session.state!.physicalCheckpoint!.snapshot.name,
            'Retained editor A',
          );
        } else {
          expect(find.byType(UnsavedChangesDialog), findsNothing);
          expect(harness.local.drafts.saves, isEmpty);
        }
        expect(
          harness.router.routerDelegate.currentConfiguration.uri.path,
          '/admin',
        );
        expect(find.byType(AdminSubmissionSaveProgressScreen), findsNothing);
        expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
        expect(harness.repository.updateIds, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI(
    'running Progress Save refuses full-stack replacement without dialog',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName(
        'Captured remote A',
        activation: harness.owner.activation,
      );
      final gate = Completer<Result<AdminSubmission>>();
      harness.repository.pendingUpdate = gate;
      expect(
        harness.owner.requestSave(activation: harness.owner.activation),
        isTrue,
      );
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {
            'session': harness.owner.sessionId,
            'attempt': '${harness.owner.saveExecutionId}',
            'editor': '1',
          },
        ),
      );
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 400));
      harness.owner.setName(
        'New B while Save runs',
        activation: harness.owner.activation,
      );
      harness.router.go('/admin');
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(harness.owner.isSaveRunning, isTrue);
      expect(harness.owner.name, 'New B while Save runs');
      gate.complete(
        Result.success(
          sampleAdminSubmission(
            name: 'Captured remote A',
            description: null,
            modifiedAtToken: '2026-10-29T00:00:00.123456Z',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(harness.owner.name, 'New B while Save runs');
      expect(harness.owner.hasUncheckpointedChanges, isTrue);
      expect(harness.repository.updateIds, [1]);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'covered discard rehydrates retained name and city before further typing',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      final nameField = find.widgetWithText(TextFormField, 'Luogo o evento');
      final cityField = find.widgetWithText(TextFormField, 'Città');
      await tester.enterText(nameField, 'Discarded name');
      await tester.enterText(cityField, 'Discarded city');
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Discarded name');
      expect(harness.owner.city, 'Discarded city');
      final owner = harness.owner;
      final navigator = Navigator.of(
        tester.element(find.byType(AdminSubmissionEditorScreen)),
      );
      var covered = false;
      void coverOnDiscard() {
        if (covered ||
            !owner.exitDecisionPending ||
            owner.hasUncheckpointedChanges) {
          return;
        }
        covered = true;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Cover after discard')),
          ),
        );
      }

      owner.addListener(coverOnDiscard);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esci senza salvare'));
      await tester.pumpAndSettle();
      owner.removeListener(coverOnDiscard);
      expect(covered, isTrue);
      expect(find.text('Cover after discard'), findsOneWidget);
      expect(owner.name, 'Target 1');
      expect(owner.city, 'Campobasso');
      expect(owner.exitDecisionPending, isFalse);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin/submissions/1',
      );
      final nameInput = find.descendant(
        of: nameField,
        matching: find.byType(EditableText),
      );
      final cityInput = find.descendant(
        of: cityField,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(nameInput).controller.text,
        'Target 1',
      );
      expect(
        tester.widget<EditableText>(cityInput).controller.text,
        'Campobasso',
      );
      await tester.enterText(
        nameField,
        '${tester.widget<EditableText>(nameInput).controller.text}X',
      );
      await tester.enterText(
        cityField,
        '${tester.widget<EditableText>(cityInput).controller.text}X',
      );
      expect(owner.name, 'Target 1X');
      expect(owner.city, 'CampobassoX');
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateIds, isEmpty);
      expect(harness.repository.addAssetCalls, isEmpty);
      expect(harness.repository.deleteAssetCalls, isEmpty);
      expect(harness.repository.rejectIds, isEmpty);
      expect(harness.repository.promoteCalls, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'covering editor during pending checkpoint permanently revokes exit',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1]);
      await harness.openEditor(tester, target: 1);
      harness.owner.setName('Reviewed A', activation: harness.owner.activation);
      final entered = Completer<void>();
      final release = Completer<Result<void>>();
      harness.local.drafts.onSave = (_) {
        entered.complete();
        return release.future;
      };
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva ed esci'));
      await tester.pump();
      expect(entered.isCompleted, isTrue);
      final navigator =
          Navigator.of(
            tester.element(find.byType(AdminSubmissionEditorScreen)),
          )..push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Text('Cover while checkpoint persists')),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Cover while checkpoint persists'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      release.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(
        harness.local.session.state!.physicalCheckpoint!.snapshot.name,
        'Reviewed A',
      );
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin/submissions/1',
      );
      expect(harness.repository.updateIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
  for (final target in [1, 2]) {
    for (final hintKind in ['missing', 'foreign', 'mismatched']) {
      testOwnerUI(
        'invalid $hintKind hint for target $target cannot authorize fields',
        (tester) async {
          harness = AdminSaveRouteHarness(persistedTargets: [1, 2, 3]);
          final foreign = AdminDraftOwner(
            accountId: AdminDraftSessionHarness.accountB,
            submissionId: target,
          );
          harness.local.drafts.drafts[foreign.lookupKey] = AdminSubmissionDraft(
            owner: foreign,
            snapshot: AdminDraftSnapshot(name: 'Foreign fields'),
          );
          final mismatched = harness.local.drafts.drafts.values.firstWhere(
            (draft) => draft.owner.submissionId == 3,
          );
          final hint = switch (hintKind) {
            'missing' => '99999999-9999-4999-8999-999999999999',
            'foreign' => foreign.sessionId,
            _ => mismatched.owner.sessionId,
          };
          await harness.openEditor(tester, target: 1);
          harness.owner.setName(
            'Private unreviewed A',
            activation: harness.owner.activation,
          );
          final before = harness.local.session.state;
          final activation = harness.owner.activation;
          harness.router.go('/admin/submissions/$target?session=$hint');
          await tester.pumpAndSettle();
          expect(find.byType(UnsavedChangesDialog), findsNothing);
          expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
          expect(
            harness.router.routerDelegate.currentConfiguration.uri.toString(),
            '/admin/submissions/1',
          );
          expect(harness.local.session.state, same(before));
          expect(harness.owner.isActivationCurrent(activation), isTrue);
          expect(harness.owner.name, 'Private unreviewed A');
          expect(harness.owner.hasUncheckpointedChanges, isTrue);
          expect(harness.owner.exitDecisionPending, isFalse);
          expect(harness.local.drafts.saves, isEmpty);
          expect(harness.repository.updateIds, isEmpty);
          // A rejected hint must release validation ownership for a real Back.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(UnsavedChangesDialog), findsOneWidget);
          await tester.tap(find.text('Annulla'));
          await tester.pumpAndSettle();
          expect(harness.local.session.state, same(before));
        },
        disposeOwners: () => harness.dispose(),
      );
    }
  }

  for (final choice in ['Salva ed esci', 'Esci senza salvare']) {
    testOwnerUI(
      'valid other-ID session hint still requires owning decision $choice',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
        final targetDraft = harness.local.drafts.drafts.values.firstWhere(
          (draft) => draft.owner.submissionId == 2,
        );
        await harness.openEditor(tester, target: 1);
        harness.owner.setName(
          'Reviewed original A',
          activation: harness.owner.activation,
        );
        final originalOwner = harness.local.session.state!.owner;
        harness.router.go(
          '/admin/submissions/2?session=${targetDraft.owner.sessionId}',
        );
        await tester.pumpAndSettle();
        expect(find.byType(UnsavedChangesDialog), findsOneWidget);
        expect(harness.owner.submissionId, 1);
        expect(harness.local.drafts.saves, isEmpty);
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        expect(harness.owner.submissionId, 2);
        expect(harness.owner.sessionId, targetDraft.owner.sessionId);
        expect(harness.owner.name, 'Target 2');
        expect(find.byType(UnsavedChangesDialog), findsNothing);
        expect(
          harness.local.drafts.drafts[targetDraft.owner.lookupKey],
          targetDraft,
        );
        if (choice == 'Salva ed esci') {
          expect(
            harness.local.drafts.drafts[originalOwner.lookupKey]!.snapshot.name,
            'Reviewed original A',
          );
        } else {
          expect(harness.local.drafts.saves, isEmpty);
        }
        expect(harness.repository.updateIds, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }
  testOwnerUI('overlapping delegate removals never share affirmative exit', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2, 3]);
    await harness.openEditor(tester, target: 1);
    harness.owner.setName(
      'Reviewed delegate A',
      activation: harness.owner.activation,
    );
    var firstFinished = false;
    var secondFinished = false;
    // Admit both outgoing onExit invocations before pumping the dialog frame.
    // Calling only router.go twice here could coalesce at the parser boundary.
    final first = harness.router.routerDelegate
        .setNewRoutePath(
          harness.router.configuration.findMatch(
            Uri.parse('/admin/submissions/2'),
          ),
        )
        .then((_) => firstFinished = true);
    final second = harness.router.routerDelegate
        .setNewRoutePath(
          harness.router.configuration.findMatch(
            Uri.parse('/admin/submissions/3'),
          ),
        )
        .then((_) => secondFinished = true);
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    expect(firstFinished, isFalse);
    expect(secondFinished, isTrue);
    expect(harness.owner.submissionId, 1);
    expect(harness.local.drafts.saves, isEmpty);
    await tester.tap(find.text('Salva ed esci'));
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    await tester.pumpAndSettle();
    expect(harness.local.drafts.saves, hasLength(1));
    expect(
      harness.local.drafts.saves.single.snapshot.name,
      'Reviewed delegate A',
    );
    expect(
      harness.router.routerDelegate.currentConfiguration.uri.path,
      '/admin/submissions/2',
    );
    expect(
      harness.router.routerDelegate.currentConfiguration.matches,
      hasLength(2),
    );
    expect(harness.owner.submissionId, 2);
    expect(harness.repository.getByIdIds, [1, 2]);
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(find.byType(UnsavedChangesDialog), findsNothing);
    expect(tester.takeException(), isNull);
  }, disposeOwners: () => harness.dispose());
  testOwnerUI(
    'old AppBar Back callback cannot borrow a reused editor binding',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
      await harness.openEditor(tester, target: 1);
      final oldBack = tester
          .widget<CustomBackButton>(find.byType(CustomBackButton).first)
          .onPressed!;
      harness.router.go('/admin/submissions/2');
      await tester.pumpAndSettle();
      expect(harness.owner.submissionId, 2);
      harness.owner.setName(
        'Private dirty B',
        activation: harness.owner.activation,
      );
      await tester.pump();
      oldBack();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin/submissions/2',
      );
      expect(harness.owner.name, 'Private dirty B');
      expect(harness.local.drafts.saves, isEmpty);
      // Current B still owns its normal explicit Back initiation.
      tester
          .widget<CustomBackButton>(find.byType(CustomBackButton).first)
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Private dirty B');
      expect(harness.owner.submissionId, 2);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
  testOwnerUI(
    'old onExit state cannot borrow same-pattern replacement authority',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
      await harness.openEditor(tester, target: 1);
      final oldState = harness.router.routerDelegate.state;
      final oldExit = harness.router.configuration
          .findMatch(Uri.parse('/admin/submissions/1'))
          .last
          .route
          .onExit!;
      final rootContext = tester.element(find.byType(MaterialApp));
      harness.router.go('/admin/submissions/2');
      await tester.pumpAndSettle();
      expect(rootContext.mounted, isTrue);
      harness.owner.setName(
        'Private dirty replacement B',
        activation: harness.owner.activation,
      );
      await tester.pump();
      final before = harness.local.session.state;
      final obsoleteResult = Future<bool>.value(oldExit(rootContext, oldState));
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(await obsoleteResult, isFalse);
      expect(harness.local.session.state, same(before));
      expect(harness.owner.name, 'Private dirty replacement B');
      expect(harness.owner.submissionId, 2);
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/admin/submissions/2',
      );
      expect(harness.local.drafts.saves, isEmpty);
      // Rejecting A's old callback leaves B's live invocation usable.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(harness.owner.name, 'Private dirty replacement B');
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
}
