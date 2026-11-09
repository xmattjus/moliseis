import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/admin_draft_repositories.dart';
import '../../../../support/admin_save_route_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_gotrue_client.dart';

void main() {
  late AdminSaveRouteHarness harness;
  const message = 'Hai una modifica interrotta da recuperare.';
  const nonce = '22222222-2222-4222-8222-222222222222';

  testOwnerUI(
    'recovery is persistent; explicit close suppresses only this visit',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);

      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.byTooltip('Riprendi editor'), findsNothing);
      final count = harness.local.drafts.navigationLoadCalls;
      await tester.pump(const Duration(seconds: 10));
      expect(find.text(message), findsOneWidget);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(harness.local.drafts.navigationLoadCalls, count);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      final context = tester.element(find.byType(AdminDashboardScreen));
      showSnackBar(context: context, textContent: 'Ordinary feedback');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      final cover = harness.router.pushNamed<Object?>(
        RouteNames.adminSubmissionNew,
      );
      await tester.pumpAndSettle();
      harness.router.pop();
      await tester.pumpAndSettle();
      await cover;
      expect(find.text(message), findsNothing);
      expect(
        harness
            .local
            .drafts
            .drafts[harness.local.owner.lookupKey]!
            .navigationIntent!
            .requestNonce,
        nonce,
      );
      expect(harness.local.staged.removals, isEmpty);
      expect(harness.local.drafts.saves, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  for (final kind in ['absent', 'ordinary', 'foreign', 'error']) {
    testOwnerUI('automatic $kind lookup is silent and never deletes state', (
      tester,
    ) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final retained = harness.local.drafts.drafts.values.single;
      harness.local.drafts.onLoadNavigation = (_) async => switch (kind) {
        'absent' => const Result.success(null),
        'ordinary' => Result.success(
          AdminSubmissionDraft(
            owner: retained.owner,
            snapshot: retained.snapshot,
          ),
        ),
        'foreign' => Result.success(
          AdminSubmissionDraft(
            owner: AdminDraftOwner(
              accountId: AdminDraftSessionHarness.accountB,
            ),
            snapshot: retained.snapshot,
            navigationIntent: AdminNavigationIntent(requestNonce: nonce),
          ),
        ),
        _ => Result.error(TestException('lookup unavailable')),
      };
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(harness.local.drafts.drafts.values.single, same(retained));
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI('ordinary replacement suspends recovery; '
      'explicit clear requires a new trigger', (tester) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);

    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AdminDashboardScreen));
    final reads = harness.local.drafts.navigationLoadCalls;
    showSnackBar(context: context, textContent: 'First ordinary');
    showSnackBar(
      context: context,
      textContent: 'Replacement',
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.text(message), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(harness.local.drafts.navigationLoadCalls, greaterThan(reads));
    clearAppSnackBars();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text(message), findsNothing);
    // A covering-route return is an established fresh eligibility trigger.
    final cover = harness.router.pushNamed<Object?>(
      RouteNames.adminSubmissionNew,
    );
    await tester.pumpAndSettle();
    harness.router.pop();
    await tester.pumpAndSettle();
    await cover;
    expect(find.text(message), findsOneWidget);
    expect(
      harness
          .local
          .drafts
          .drafts[harness.local.owner.lookupKey]!
          .navigationIntent!
          .requestNonce,
      nonce,
    );
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('explicit lookup error reports once, latches double activation, '
      'and can retry later', (tester) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);

    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final gate = Completer<Result<AdminSubmissionDraft?>>();
    harness.local.drafts.onLoadNavigation = (_) => gate.future;
    final action = tester
        .widget<SnackBarAction>(find.byType(SnackBarAction))
        .onPressed;
    action();
    action();
    await tester.pumpAndSettle();
    final count = harness.local.drafts.navigationLoadCalls;
    gate.complete(Result.error(TestException('explicit failure')));
    await tester.pumpAndSettle();
    expect(harness.local.drafts.navigationLoadCalls, count);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(harness.local.drafts.saves, isEmpty);
    harness.local.drafts.onLoadNavigation = null;
    final cover = harness.router.pushNamed<Object?>(
      RouteNames.adminSubmissionNew,
    );
    await tester.pumpAndSettle();
    harness.router.pop();
    await tester.pumpAndSettle();
    await cover;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
  }, disposeOwners: () => harness.dispose());

  for (final retry in [false, true]) {
    testOwnerUI(
      'failed editor activation then return; successful retry=$retry',
      (tester) async {
        harness = AdminSaveRouteHarness()
          ..seedNavigationRecovery(requestNonce: nonce);

        harness.local.staged.onReconcile = (_) async =>
            Result.error(TestException('staging unavailable'));
        harness.router.goNamed(RouteNames.adminDashboard);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Riprendi'));
        await tester.pumpAndSettle();

        expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
        expect(find.text('Riprova'), findsOneWidget);
        if (retry) {
          harness.local.staged.onReconcile = null;
          await tester.tap(find.text('Riprova'));
          await tester.pumpAndSettle();
          expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
          expect(harness.owner.sessionId, harness.local.owner.sessionId);
        }
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(find.text(message), retry ? findsNothing : findsOneWidget);
        final retained =
            harness.local.drafts.drafts[harness.local.owner.lookupKey]!;
        expect(retained.navigationIntent!.requestNonce, nonce);
        expect(retained.snapshot.latitudeText, '41,');
        expect(harness.local.staged.removals, isEmpty);
        expect(harness.local.drafts.saves, isEmpty);
        expect(harness.repository.createInputs, isEmpty);
        expect(harness.repository.updateInputs, isEmpty);
        expect(harness.content.uploadedImages, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI(
    'successful activation retains nonce but suppresses repeat recovery',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);

      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(harness.owner.activation!.owner, harness.local.owner);
      expect(
        harness.owner.isActivationCurrent(harness.owner.activation),
        isTrue,
      );
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      expect(
        harness
            .local
            .drafts
            .drafts[harness.local.owner.lookupKey]!
            .navigationIntent!
            .requestNonce,
        nonce,
      );
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'late lookup cannot publish after A to B to A or route departure',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);

      final stale = Completer<Result<AdminSubmissionDraft?>>();
      final candidate = harness.local.drafts.drafts.values.single;
      harness.local.drafts.onLoadNavigation = (_) => stale.future;
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final accountA = harness.auth.viewModel.currentUser!;
      harness.auth.setUser(
        makeAuthUser(isAdmin: true, id: AdminDraftSessionHarness.accountB),
      );
      harness.auth.emit(AuthChangeEvent.userUpdated);
      await tester.pumpAndSettle();
      harness.local.drafts.onLoadNavigation = (_) async =>
          const Result.success(null);
      harness.auth.setUser(accountA);
      harness.auth.emit(AuthChangeEvent.userUpdated);
      await tester.pumpAndSettle();
      stale.complete(Result.success(candidate));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      harness.router.go('/');
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      expect(harness.local.drafts.drafts.values.single, same(candidate));
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('cover during explicit lookup releases only that stale attempt', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);
    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final candidate = harness.local.drafts.drafts.values.single;
    final gate = Completer<Result<AdminSubmissionDraft?>>();
    harness.local.drafts.onLoadNavigation = (_) => gate.future;
    final action = tester
        .widget<SnackBarAction>(find.byType(SnackBarAction))
        .onPressed;
    action();
    await tester.pumpAndSettle();
    final cover = harness.router.pushNamed<Object?>(
      RouteNames.adminSubmissionNew,
    );
    await tester.pumpAndSettle();
    harness.local.drafts.onLoadNavigation = null;
    harness.router.pop();
    await tester.pumpAndSettle();
    await cover;
    expect(find.text(message), findsOneWidget);
    gate.complete(Result.success(candidate));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(find.text(message), findsOneWidget);
    expect(harness.local.drafts.drafts.values.single, same(candidate));
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  for (final changed in ['absent', 'nonce', 'target']) {
    testOwnerUI('explicit activation never retargets $changed candidate', (
      tester,
    ) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final candidate = harness.local.drafts.drafts.values.single;
      final replacement = changed == 'absent'
          ? null
          : AdminSubmissionDraft(
              owner: changed == 'target'
                  ? AdminDraftOwner(
                      accountId: candidate.owner.accountId,
                      sessionId: candidate.owner.sessionId,
                      submissionId: 8,
                    )
                  : candidate.owner,
              snapshot: candidate.snapshot,
              navigationIntent: AdminNavigationIntent(
                requestNonce: changed == 'nonce'
                    ? '33333333-3333-4333-8333-333333333333'
                    : nonce,
              ),
            );
      harness.local.drafts.onLoadNavigation = (_) async =>
          Result.success(replacement);
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      expect(harness.local.drafts.drafts.values.single, same(candidate));
      expect(harness.local.drafts.saves, isEmpty);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(
        find.text(message),
        changed == 'absent' ? findsNothing : findsOneWidget,
      );
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI('new nonce is eligible after dismissal; '
      'late earlier lookup cannot retire it', (tester) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);
    final stale = Completer<Result<AdminSubmissionDraft?>>();
    harness.local.drafts.onLoadNavigation = (_) => stale.future;
    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    harness.local.drafts.onLoadNavigation = null;
    await tester.tap(find.byTooltip('Aggiorna i contenuti'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    stale.complete(Result.error(TestException('old lookup')));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.drag(find.byType(SnackBar), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    await tester.tap(find.byTooltip('Aggiorna i contenuti'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    harness.seedNavigationRecovery(
      requestNonce: '33333333-3333-4333-8333-333333333333',
    );
    await tester.tap(find.byTooltip('Aggiorna i contenuti'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('editor-return list refresh does not wait for recovery recheck', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);
    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riprendi'));
    await tester.pumpAndSettle();
    final reads = harness.repository.listCallCount;
    final gate = Completer<Result<AdminSubmissionDraft?>>();
    harness.local.drafts.onLoadNavigation = (_) => gate.future;
    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.repository.listCallCount, reads + 1);
    expect(find.byType(SnackBar), findsNothing);
    gate.complete(Result.error(TestException('recheck unavailable')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('global clear revokes an eligibility lookup not yet registered', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);
    final candidate = harness.local.drafts.drafts.values.single;
    final gate = Completer<Result<AdminSubmissionDraft?>>();
    harness.local.drafts.onLoadNavigation = (_) => gate.future;
    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(harness.local.drafts.navigationLoadCalls, 1);
    clearAppSnackBars();
    gate.complete(Result.success(candidate));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.local.drafts.drafts.values.single, same(candidate));
    harness.local.drafts.onLoadNavigation = null;
    final lookups = harness.local.drafts.navigationLoadCalls;
    await tester.tap(find.byTooltip('Aggiorna i contenuti'));
    clearAppSnackBars();
    await tester.pumpAndSettle();
    expect(harness.local.drafts.navigationLoadCalls, lookups);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.byTooltip('Aggiorna i contenuti'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.local.staged.removals, isEmpty);
  }, disposeOwners: () => harness.dispose());
}
