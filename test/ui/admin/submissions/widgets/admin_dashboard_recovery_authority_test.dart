import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
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
  AdminSubmissionEditorViewModel? replacementOwner;
  const message = 'Hai una modifica interrotta da recuperare.';
  const nonce = '22222222-2222-4222-8222-222222222222';
  const nextNonce = '33333333-3333-4333-8333-333333333333';

  testOwnerUI(
    'editor owner replacement during explicit revalidation revokes old action',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final candidate = harness.local.drafts.drafts.values.single;
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      final gate = Completer<Result<AdminSubmissionDraft?>>();
      var loads = 0;
      harness.local.drafts.onLoadNavigation = (_) {
        loads++;
        return gate.future;
      };
      final action = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      action();
      await tester.pumpAndSettle();
      expect(loads, 1);

      replacementOwner = AdminSubmissionEditorViewModel(
        repository: harness.repository,
        contentSubmissionRepository: harness.content,
      );
      await tester.pumpWidget(harness.app(editorOwner: replacementOwner));
      await tester.pumpAndSettle();
      gate.complete(Result.success(candidate));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      harness.local.drafts.onLoadNavigation = null;
      await tester.tap(find.byTooltip('Aggiorna i contenuti'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
    },
    disposeOwners: () {
      replacementOwner?.dispose();
      replacementOwner = null;
      harness.dispose();
    },
  );

  testOwnerUI(
    'stale recovery action cannot navigate after explicit global clearing',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final action = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      final reads = harness.local.drafts.navigationLoadCalls;

      clearAppSnackBars();
      action();
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(harness.local.drafts.navigationLoadCalls, reads);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
      expect(
        harness
            .local
            .drafts
            .drafts[harness.local.owner.lookupKey]!
            .navigationIntent!
            .requestNonce,
        nonce,
      );
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'stale action for replaced candidate cannot navigate or consume its nonce',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final oldAction = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      harness.seedNavigationRecovery(requestNonce: nextNonce);
      await tester.tap(find.byTooltip('Aggiorna i contenuti'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      final reads = harness.local.drafts.navigationLoadCalls;

      oldAction();
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(harness.local.drafts.navigationLoadCalls, reads);
      expect(
        harness
            .local
            .drafts
            .drafts[harness.local.owner.lookupKey]!
            .navigationIntent!
            .requestNonce,
        nextNonce,
      );
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('route departure during explicit lookup revokes its completion', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness()
      ..seedNavigationRecovery(requestNonce: nonce);
    final candidate = harness.local.drafts.drafts.values.single;
    harness.router.goNamed(RouteNames.adminDashboard);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final gate = Completer<Result<AdminSubmissionDraft?>>();
    harness.local.drafts.onLoadNavigation = (_) => gate.future;
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();

    harness.router.go('/');
    await tester.pumpAndSettle();
    gate.complete(Result.success(candidate));
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboardScreen), findsNothing);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.local.drafts.drafts.values.single, same(candidate));
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.local.staged.removals, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'explicit revalidation from A cannot navigate after A to B to A',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final candidate = harness.local.drafts.drafts.values.single;
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      final gate = Completer<Result<AdminSubmissionDraft?>>();
      var authLookups = 0;
      harness.local.drafts.onLoadNavigation = (_) {
        authLookups++;
        return authLookups == 1
            ? gate.future
            : Future.value(const Result.success(null));
      };
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pumpAndSettle();
      expect(authLookups, 1);

      final accountB = makeAuthUser(
        isAdmin: true,
        id: AdminDraftSessionHarness.accountB,
      );
      harness.auth.setUser(accountB);
      harness.auth.emit(AuthChangeEvent.userUpdated);
      await tester.pumpAndSettle();
      harness.auth.setUser(makeAuthUser(isAdmin: true));
      harness.auth.emit(AuthChangeEvent.userUpdated);
      await tester.pumpAndSettle();
      gate.complete(Result.success(candidate));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.text(message), findsNothing);
      expect(harness.local.drafts.drafts.values.single, same(candidate));
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'unrelated initialized editor session cannot qualify failed recovery',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final candidate = harness.local.drafts.drafts.values.single;
      final unrelated = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
        sessionId: '44444444-4444-4444-8444-444444444444',
        submissionId: 8,
      );
      harness.local.drafts.drafts[unrelated.lookupKey] = AdminSubmissionDraft(
        owner: unrelated,
        snapshot: AdminDraftSnapshot(name: 'Unrelated initialized session'),
      );
      expect(
        await harness.owner.activate(
          accountId: unrelated.accountId,
          submissionId: unrelated.submissionId,
          sessionId: unrelated.sessionId,
        ),
        isA<Success<void>>(),
      );
      expect(harness.owner.activation?.owner, unrelated);
      harness.local.drafts.onLoadBySession = (accountId, sessionId) async {
        if (sessionId == candidate.owner.sessionId) {
          return Result.error(
            TestException('candidate activation unavailable'),
          );
        }
        return Result.success(harness.local.drafts.drafts[unrelated.lookupKey]);
      };
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.text('Riprova'), findsOneWidget);
      expect(harness.owner.activation?.owner, unrelated);

      harness.router.pop();
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(harness.owner.activation?.owner, unrelated);
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
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'editor owner replacement during target activation cannot suppress '
    'recovery',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final candidate = harness.local.drafts.drafts.values.single;
      final entered = Completer<void>();
      final activationGate = Completer<Result<AdminSubmissionDraft?>>();
      harness.local.drafts.onLoadBySession = (accountId, sessionId) {
        if (sessionId == candidate.owner.sessionId) {
          if (!entered.isCompleted) entered.complete();
          return activationGate.future;
        }
        return Future.value(const Result.success(null));
      };
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprendi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(entered.isCompleted, isTrue);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);

      replacementOwner = AdminSubmissionEditorViewModel(
        repository: harness.repository,
        contentSubmissionRepository: harness.content,
      );
      await tester.pumpWidget(harness.app(editorOwner: replacementOwner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      activationGate.complete(Result.success(candidate));
      await tester.pumpAndSettle();
      harness.router.pop();
      await tester.pumpAndSettle();

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
      expect(harness.local.staged.removals, isEmpty);
      expect(harness.local.drafts.saves, isEmpty);
    },
    disposeOwners: () {
      replacementOwner?.dispose();
      replacementOwner = null;
      harness.dispose();
    },
  );
}
