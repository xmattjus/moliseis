import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/routing/admin_submission_exit_policy.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/admin_draft_repositories.dart';
import '../../../../support/admin_editor_interactions.dart';
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
    'rejected recovery releases admission and retries after local checkpoint',
    (tester) async {
      harness = AdminSaveRouteHarness(persistedTargets: [1])
        ..seedNavigationRecovery(requestNonce: nonce);
      final persisted = harness.local.drafts.drafts.values.firstWhere(
        (draft) => draft.owner.submissionId == 1,
      );
      final original = AdminSubmissionDraft(
        owner: persisted.owner,
        snapshot: persisted.snapshot.copyWith(name: 'Local fields'),
        remoteBaseline: persisted.remoteBaseline,
      );
      harness.local.drafts.drafts[original.owner.lookupKey] = original;
      final interrupted =
          harness.local.drafts.drafts[harness.local.owner.lookupKey]!;
      final candidate = AdminSubmissionDraft(
        owner: interrupted.owner,
        snapshot: interrupted.snapshot,
        navigationIntent: interrupted.navigationIntent,
        fieldWriteIntent: AdminFieldWriteIntent(
          kind: AdminFieldWriteKind.update,
          attemptId: nextNonce,
          snapshot: original.snapshot,
          expectedModifiedAt: original.remoteBaseline!.modifiedAtToken,
        ),
      );
      harness.local.drafts.drafts[candidate.owner.lookupKey] = candidate;
      final assets = List.of(harness.local.staged.assets[candidate.owner]!);
      harness.repository.getByIdResults[7] = Result.success(
        sampleAdminSubmission(id: 7, description: null),
      );
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Accepted remote fields',
          description: null,
          modifiedAtToken: '2026-08-21T00:00:00.654321Z',
        ),
      );
      await harness.openEditor(tester, target: 1);
      await revealAdminEditorWidget(
        tester,
        find.byKey(const ValueKey('admin_accept_remote')),
      );
      await tester.tap(find.byKey(const ValueKey('admin_accept_remote')));
      await tester.pumpAndSettle();
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
      expect(harness.owner.name, 'Accepted remote fields');
      harness.router.pop();
      await tester.pumpAndSettle();
      final dashboardRoute = ModalRoute.of(
        tester.element(find.byType(AdminDashboardScreen)),
      );
      expect(find.text(message), findsOneWidget);

      AdminEditorNavigationAdmission? rejectedRequest;
      void captureRequest() {
        final state = harness.router.routeInformationProvider.value.state;
        if (state is RouteInformationState &&
            state.extra is AdminEditorNavigationAdmission) {
          rejectedRequest = state.extra! as AdminEditorNavigationAdmission;
        }
      }

      harness.router.routeInformationProvider.addListener(captureRequest);
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      harness.router.routeInformationProvider.removeListener(captureRequest);
      expect(rejectedRequest, isNotNull);
      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(
        find.text(
          'Salva nella bozza locale i campi remoti accettati '
          'prima di aprire un altro contributo.',
        ),
        findsOneWidget,
      );
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);
      expect(harness.owner.submissionId, 1);
      expect(harness.local.session.state!.physicalCheckpoint, original);
      expect(
        harness.local.drafts.drafts[candidate.owner.lookupKey],
        same(candidate),
      );
      expect(harness.local.staged.assets[candidate.owner], assets);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
      final deniedReads = harness.local.drafts.navigationLoadCalls;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(harness.local.drafts.navigationLoadCalls, deniedReads);
      expect(find.text(message), findsNothing);

      await tester.tap(find.byTooltip('Aggiorna i contenuti'));
      await tester.pumpAndSettle();
      expect(
        find.text(message),
        findsOneWidget,
        reason: 'Denied Riprendi must release its attempt for a later trigger',
      );
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);

      final gate = Completer<Result<AdminSubmissionDraft?>>();
      harness.local.drafts.onLoadNavigation = (_) => gate.future;
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      final pendingReads = harness.local.drafts.navigationLoadCalls;
      // Replaying an old rejected request must not release the newer lookup.
      unawaited(
        harness.router.pushNamed<Object?>(
          RouteNames.adminSubmissionEditor,
          pathParameters: {'id': '7'},
          queryParameters: {'session': candidate.owner.sessionId},
          extra: rejectedRequest,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aggiorna i contenuti'));
      await tester.pumpAndSettle();
      expect(harness.local.drafts.navigationLoadCalls, pendingReads);
      expect(find.text(message), findsNothing);
      harness.local.drafts.onLoadNavigation = null;
      gate.complete(Result.success(candidate));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(harness.owner.pendingRecoveryCheckpoint, isTrue);

      final repair = harness.router.pushNamed<Object?>(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '1'},
        queryParameters: {'session': original.owner.sessionId},
      );
      await tester.pumpAndSettle();
      await revealAdminEditorWidget(tester, find.text('Salva bozza locale'));
      await tester.tap(find.text('Salva bozza locale'));
      await tester.pumpAndSettle();
      expect(harness.owner.pendingRecoveryCheckpoint, isFalse);
      harness.router.pop();
      await tester.pumpAndSettle();
      await repair;
      // Both deliberate denied pushes retain their ordinary feedback lifetime.
      for (var message = 0; message < 2; message++) {
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      }
      expect(
        ModalRoute.of(tester.element(find.byType(AdminDashboardScreen))),
        same(dashboardRoute),
      );
      expect(find.text(message), findsOneWidget);
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(harness.owner.activation!.owner, candidate.owner);
      expect(
        harness.owner.isActivationCurrent(harness.owner.activation),
        isTrue,
      );
      expect(
        harness.local.drafts.drafts[candidate.owner.lookupKey],
        same(candidate),
      );
      expect(harness.local.staged.assets[candidate.owner], assets);
      expect(harness.local.drafts.saves, hasLength(1));
      expect(harness.local.drafts.saves.single.owner, original.owner);
      expect(harness.local.staged.removals, isEmpty);
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.repository.addAssetCalls, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'ready exact session admits recovery without a replacement activation',
    (tester) async {
      harness = AdminSaveRouteHarness()
        ..seedNavigationRecovery(requestNonce: nonce);
      final candidate = harness.local.drafts.drafts.values.single;
      final assets = List.of(harness.local.staged.assets[candidate.owner]!);
      expect(
        await harness.owner.activate(
          accountId: candidate.owner.accountId,
          submissionId: candidate.owner.submissionId,
          sessionId: candidate.owner.sessionId,
        ),
        isA<Success<void>>(),
      );
      final original = harness.owner.activation!;
      expect(original.owner, candidate.owner);
      expect(harness.owner.isActivationCurrent(original), isTrue);

      var sessionReads = 0;
      var targetReads = 0;
      var reconciliations = 0;
      harness.local.drafts
        ..onLoadBySession = (_, _) async {
          sessionReads++;
          return Result.error(TestException('session read unavailable'));
        }
        ..onLoad = (_, _) async {
          targetReads++;
          return Result.error(TestException('target read unavailable'));
        };
      harness.local.staged.onReconcile = (_) async {
        reconciliations++;
        return Result.error(TestException('staging unavailable'));
      };
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      final dashboardRoute = ModalRoute.of(
        tester.element(find.byType(AdminDashboardScreen)),
      );

      // The real admission guard rejects a conflicting target, not this owner.
      var deniedPushReturned = false;
      unawaited(
        harness.router
            .pushNamed<Object?>(
              RouteNames.adminSubmissionEditor,
              pathParameters: {'id': '${candidate.owner.submissionId! + 1}'},
              queryParameters: {'session': candidate.owner.sessionId},
            )
            .then((_) => deniedPushReturned = true),
      );
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(deniedPushReturned, isFalse);
      expect(find.text(message), findsOneWidget);
      expect(harness.owner.isActivationCurrent(original), isTrue);

      harness.local.drafts.onLoadNavigation = (_) async =>
          Result.error(TestException('navigation validation unavailable'));
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      expect(harness.owner.isActivationCurrent(original), isTrue);
      harness.local.drafts.onLoadNavigation = null;
      await tester.tap(find.byTooltip('Aggiorna i contenuti'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);

      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(
        find.textContaining('Impossibile aprire il contributo'),
        findsNothing,
      );
      expect(harness.owner.activation!.owner, candidate.owner);
      expect(harness.owner.activation!.generation, original.generation);
      expect(harness.owner.isActivationCurrent(original), isTrue);
      expect(sessionReads, 0);
      expect(targetReads, 0);
      expect(reconciliations, 0);
      final navigationReads = harness.local.drafts.navigationLoadCalls;

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(find.byType(AdminDashboardScreen))),
        same(dashboardRoute),
      );
      expect(
        harness.local.drafts.navigationLoadCalls,
        greaterThan(navigationReads),
      );
      expect(find.text(message), findsNothing);
      expect(deniedPushReturned, isFalse);
      expect(harness.local.drafts.drafts.values.single, same(candidate));
      expect(candidate.navigationIntent!.requestNonce, nonce);
      expect(harness.local.staged.assets[candidate.owner], assets);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.local.staged.removals, isEmpty);
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.repository.addAssetCalls, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

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

  for (final declarativeReturn in [false, true]) {
    testOwnerUI('unrelated initialized editor cannot qualify recovery; '
        'declarative=$declarativeReturn', (tester) async {
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
      harness.repository.getByIdResults[8] = Result.error(
        TestException('active detail unavailable'),
      );
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final dashboardRoute = ModalRoute.of(
        tester.element(find.byType(AdminDashboardScreen)),
      )!;
      await tester.tap(find.text('Riprendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.text('Riprova'), findsOneWidget);
      expect(harness.owner.activation?.owner, unrelated);

      if (declarativeReturn) {
        final lookups = harness.local.drafts.navigationLoadCalls;
        final reads = harness.repository.listCallCount;
        await tester.tap(
          find.byKey(const ValueKey('admin_return_active_editor')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(dashboardRoute.isCurrent, isFalse);
        expect(find.text(message), findsNothing);
        expect(harness.local.drafts.navigationLoadCalls, lookups);
        expect(harness.repository.listCallCount, reads);
        await revealAdminEditorWidget(
          tester,
          find.byKey(const ValueKey('admin_recovery_return')),
        );
        await tester.tap(find.byKey(const ValueKey('admin_recovery_return')));
      } else {
        harness.router.pop();
      }
      await tester.pumpAndSettle();

      expect(dashboardRoute.isCurrent, isTrue);
      expect(
        ModalRoute.of(tester.element(find.byType(AdminDashboardScreen))),
        same(dashboardRoute),
      );
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
    }, disposeOwners: () => harness.dispose());
  }

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
