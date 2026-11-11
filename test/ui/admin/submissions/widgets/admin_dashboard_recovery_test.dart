import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_list_item.dart';
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

  for (final pull in [false, true]) {
    testOwnerUI(
      'dismissing manual wait preserves unrelated recovery pull=$pull',
      (tester) async {
        harness = AdminSaveRouteHarness()
          ..seedNavigationRecovery(requestNonce: nonce);
        final candidate = harness.local.drafts.drafts.values.single;
        final assets = List.of(harness.local.staged.assets[candidate.owner]!);
        harness.repository.listResult = Result.success([
          sampleAdminSubmission(),
        ]);
        harness.router.goNamed(RouteNames.adminDashboard);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        final pending = Completer<Result<List<AdminSubmission>>>();
        harness.repository.pendingList = pending;
        if (pull) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 300),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
        } else {
          await tester.tap(find.byTooltip('Aggiorna i contenuti'));
        }
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await pumpCommandTurns(tester);
        expect(find.text('Annulla').hitTestable(), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        final recovery = tester.element(find.text(message));
        await tester.tap(find.text('Annulla'));
        await tester.pump();
        expect(tester.element(find.text(message)), same(recovery));
        expect(find.text('Riprendi').hitTestable(), findsOneWidget);
        expect(find.text('Tutti'), findsOneWidget);
        expect(pending.isCompleted, isFalse);
        expect(harness.repository.listCallCount, 2);
        pending.complete(Result.error(TestException('dismissed failure')));
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(tester.element(find.text(message)), same(recovery));
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          harness.local.drafts.drafts[candidate.owner.lookupKey],
          same(candidate),
        );
        expect(harness.local.staged.assets[candidate.owner], assets);
        expect(harness.local.drafts.saves, isEmpty);
        expect(harness.local.staged.removals, isEmpty);
        expect(harness.repository.updateInputs, isEmpty);
        expect(harness.repository.createInputs, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  for (final recovery in [true, false]) {
    testOwnerUI('declarative editor return restores recovery and refreshes; '
        'recovery=$recovery', (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final candidate = harness.local.drafts.drafts.values.single;
      final assets = List.of(harness.local.staged.assets[candidate.owner]!);
      harness.repository
        ..listResult = Result.success([sampleAdminSubmission(id: 7)])
        ..getByIdResults[7] = Result.error(TestException('detail unavailable'));
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final dashboard = tester.state(find.byType(AdminDashboardScreen));
      final route = ModalRoute.of(
        tester.element(find.byType(AdminDashboardScreen)),
      )!;
      if (recovery) {
        await tester.tap(find.text('Riprendi'));
      } else {
        await tester.ensureVisible(find.byType(AdminSubmissionListItem));
        await tester.tap(find.byType(AdminSubmissionListItem));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(
        harness.owner.isActivationCurrent(harness.owner.activation),
        isTrue,
      );
      final reads = harness.repository.listCallCount;
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin_recovery_return')),
      );
      await tester.tap(find.byKey(const ValueKey('admin_recovery_return')));
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(tester.state(find.byType(AdminDashboardScreen)), same(dashboard));
      expect(
        ModalRoute.of(tester.element(find.byType(AdminDashboardScreen))),
        same(route),
      );
      if (recovery) expect(find.text(message), findsNothing);

      const replacement = '33333333-3333-4333-8333-333333333333';
      expect(
        await harness.local.drafts.saveNavigationIntent(
          owner: candidate.owner,
          requestNonce: replacement,
        ),
        isA<Success<AdminSubmissionDraft>>(),
      );
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await refresh;
      expect(
        find.text(message),
        findsOneWidget,
        reason: 'Declarative return must release recovery for a newer nonce',
      );
      expect(
        harness.repository.listCallCount,
        reads + 2,
        reason: 'One editor-return read and one explicit manual refresh',
      );
      expect(
        harness
            .local
            .drafts
            .drafts[candidate.owner.lookupKey]!
            .navigationIntent!
            .requestNonce,
        replacement,
      );
      expect(harness.local.staged.assets[candidate.owner], assets);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
    }, disposeOwners: () => harness.dispose());
  }

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
    expect(
      find.text('Si è verificato un errore, riprova più tardi'),
      findsOneWidget,
    );
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
        findsNothing,
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

  for (final replace in [false, true]) {
    testOwnerUI('editor return refresh is independent and stale recheck '
        'cannot release newer=$replace', (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      final candidate = harness.local.drafts.drafts.values.single;
      final reads = harness.repository.listCallCount;
      final gate = Completer<Result<AdminSubmissionDraft?>>();
      harness.local.drafts.onLoadNavigation = (_) => gate.future;
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.repository.listCallCount, reads + 1);
      expect(find.byType(SnackBar), findsNothing);
      if (replace) {
        final cover = harness.router.pushNamed<Object?>(
          RouteNames.adminSubmissionNew,
        );
        await tester.pumpAndSettle();
        const replacement = '33333333-3333-4333-8333-333333333333';
        final updated = await harness.local.drafts.saveNavigationIntent(
          owner: candidate.owner,
          requestNonce: replacement,
        );
        final fresh = (updated as Success<AdminSubmissionDraft>).value;
        harness.local.drafts.onLoadNavigation = null;
        harness.router.pop();
        await tester.pumpAndSettle();
        await cover;
        expect(find.text(message), findsOneWidget);
        final newer = Completer<Result<AdminSubmissionDraft?>>();
        harness.local.drafts.onLoadNavigation = (_) => newer.future;
        await tester.tap(find.text('Riprendi'));
        await tester.pumpAndSettle();
        final lookups = harness.local.drafts.navigationLoadCalls;
        gate.complete(Result.success(candidate));
        await tester.pumpAndSettle();
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        await refresh;
        expect(harness.local.drafts.navigationLoadCalls, lookups);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
        harness.local.drafts.onLoadNavigation = null;
        newer.complete(Result.success(fresh));
        await tester.pumpAndSettle();
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(harness.owner.activation!.owner, candidate.owner);
        expect(
          harness
              .local
              .drafts
              .drafts[candidate.owner.lookupKey]!
              .navigationIntent!
              .requestNonce,
          replacement,
        );
      } else {
        gate.complete(Result.error(TestException('recheck unavailable')));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      }
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
    }, disposeOwners: () => harness.dispose());
  }

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
