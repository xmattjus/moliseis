import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';

import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/admin_draft_repositories.dart';
import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';
import '../support/mock_gotrue_client.dart';

void main() {
  late AdminSaveRouteHarness harness;

  for (final bAlreadyOpening in [false, true]) {
    testOwnerUI(
      'E1 pending A lookup retires before B opens: $bAlreadyOpening',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [1]);
        final router = harness.router;
        final local = harness.local;
        const a = AdminDraftSessionHarness.accountA;
        const b = AdminDraftSessionHarness.accountB;
        final draft = local.drafts.drafts['$a/1']!;
        final digest = 'a' * 40;
        final staged = AdminSubmissionStagedAsset(
          owner: draft.owner,
          digest: digest,
          relativePath: '$a/${draft.owner.sessionId}/$digest',
        );
        local.staged.assets[draft.owner] = [staged];
        local.staged.onResolve = (_) async =>
            Result.error(Exception('Fixture preview unavailable.'));
        final lookup = Completer<Result<AdminSubmissionDraft?>>();
        final loadB = Completer<Result<AdminSubmissionDraft?>>();
        final lookups = <(String, String)>[];
        final reconciled = <AdminDraftOwner>[];
        local.drafts.onLoadBySession = (account, session) {
          lookups.add((account, session));
          return lookups.length == 1
              ? lookup.future
              : Future.value(Result.success(draft));
        };
        local.drafts.onLoad = (account, _) =>
            account == b ? loadB.future : Future.value(Result.success(draft));
        local.staged.onReconcile = (owner) async {
          reconciled.add(owner);
          return Result.success(local.staged.assets[owner] ?? []);
        };
        final aUri = '/admin/submissions/1?session=${draft.owner.sessionId}';
        router.go(aUri);
        await tester.pumpWidget(harness.app());
        await tester.pump();
        await tester.idle();
        await tester.pump();
        expect(lookups, [(a, draft.owner.sessionId)]);
        expect(local.session.state, isNull);
        expect(harness.repository.getByIdIds, isEmpty);

        harness.auth
          ..setUser(makeAuthUser(id: b, isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await tester.idle();
        if (bAlreadyOpening) {
          await tester.pumpAndSettle();
          expect(router.state.uri.path, RoutePaths.admin);
          router.go('/admin/submissions/1');
          await tester.pump();
          await tester.idle();
          await tester.pump();
          expect(local.session.state?.owner.accountId, b);
        }
        final stateBeforeA = local.session.state;
        lookup.complete(Result.success(draft));
        await tester.idle();
        expect(local.session.state, same(stateBeforeA));
        expect(harness.repository.getByIdIds, isEmpty);
        expect(reconciled, isEmpty);
        expect(lookups, [(a, draft.owner.sessionId)]);
        expect(local.drafts.drafts[draft.owner.lookupKey], same(draft));
        expect(local.staged.assets[draft.owner], [staged]);

        loadB.complete(const Result.success(null));
        await tester.pumpAndSettle();
        expect(harness.owner.accountId, bAlreadyOpening ? b : null);
        harness.auth
          ..setUser(makeAuthUser(id: a, isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await tester.pumpAndSettle();
        router.go(aUri);
        await tester.pumpAndSettle();
        expect(lookups, [
          (a, draft.owner.sessionId),
          (a, draft.owner.sessionId),
        ]);
        expect(reconciled, [draft.owner]);
        expect(harness.owner.accountId, a);
        expect(harness.owner.sessionId, draft.owner.sessionId);
        expect(local.staged.assets[draft.owner], [staged]);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI('matching explicit remote route and session are accepted', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
    final draft = harness
        .local
        .drafts
        .drafts['${AdminDraftSessionHarness.accountA}/123']!;
    harness.router.goNamed(
      RouteNames.adminSubmissionEditor,
      pathParameters: {'id': '123'},
      queryParameters: {'session': draft.owner.sessionId},
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.sessionId, draft.owner.sessionId);
    expect(harness.owner.submissionId, 123);
    expect(harness.owner.name, 'Target 123');
    expect(harness.repository.getByIdIds, [123]);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('explicit remote route rejects another same-account session', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
    final unrelated = harness
        .local
        .drafts
        .drafts['${AdminDraftSessionHarness.accountA}/456']!;
    harness.router.goNamed(
      RouteNames.adminSubmissionEditor,
      pathParameters: {'id': '123'},
      queryParameters: {'session': unrelated.owner.sessionId},
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Impossibile aprire'), findsOneWidget);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(harness.owner.sessionId, isNull);
    expect(harness.repository.getByIdIds, isEmpty);
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.local.drafts.drafts[unrelated.owner.lookupKey], unrelated);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('mismatch in same-session fast path preserves active work', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
    final active = harness
        .local
        .drafts
        .drafts['${AdminDraftSessionHarness.accountA}/456']!;
    harness.router.goNamed(
      RouteNames.adminSubmissionEditor,
      pathParameters: {'id': '456'},
      queryParameters: {'session': active.owner.sessionId},
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final activation = harness.owner.activation;
    harness.owner.setName('Private uncheckpointed B', activation: activation);
    final before = harness.local.session.state;

    harness.router.goNamed(
      RouteNames.adminSubmissionEditor,
      pathParameters: {'id': '123'},
      queryParameters: {'session': active.owner.sessionId},
    );
    await tester.pumpAndSettle();

    // The known active-session/other-ID mismatch is refused before rebinding.
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(
      harness.router.routerDelegate.currentConfiguration.uri.path,
      '/admin/submissions/456',
    );
    expect(harness.local.session.state, same(before));
    expect(harness.owner.isActivationCurrent(activation), isTrue);
    expect(harness.owner.name, 'Private uncheckpointed B');
    expect(harness.owner.submissionId, 456);
    expect(harness.repository.getByIdIds, [456]);
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  for (final missing in [true, false]) {
    testOwnerUI(
      '${missing ? 'missing' : 'foreign'} route session fails closed',
      (tester) async {
        harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
        final foreign = AdminDraftOwner(
          accountId: AdminDraftSessionHarness.accountB,
          submissionId: 123,
        );
        harness.local.drafts.drafts[foreign.lookupKey] = AdminSubmissionDraft(
          owner: foreign,
          snapshot: AdminDraftSnapshot(name: 'Private foreign draft'),
        );
        harness.router.goNamed(
          RouteNames.adminSubmissionEditor,
          pathParameters: {'id': '123'},
          queryParameters: {
            'session': missing
                ? '99999999-9999-4999-8999-999999999999'
                : foreign.sessionId,
          },
        );
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(find.textContaining('Impossibile aprire'), findsOneWidget);
        expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
        expect(harness.owner.sessionId, isNull);
        expect(harness.repository.getByIdIds, isEmpty);
        expect(harness.local.drafts.saves, isEmpty);
      },
      disposeOwners: () => harness.dispose(),
    );
  }

  testOwnerUI('new route with adopted hint restores its remote identity', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
    final adopted = harness
        .local
        .drafts
        .drafts['${AdminDraftSessionHarness.accountA}/456']!;
    harness.router.goNamed(
      RouteNames.adminSubmissionNew,
      queryParameters: {'session': adopted.owner.sessionId},
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.submissionId, 456);
    expect(harness.owner.sessionId, adopted.owner.sessionId);
    expect(harness.repository.createInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('new route without hint activates the new target', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
    harness.router.goNamed(RouteNames.adminSubmissionNew);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.submissionId, isNull);
    expect(harness.owner.name, isNull);
    expect(harness.repository.getByIdIds, isEmpty);
    expect(harness.repository.createInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('targetless progress restores its session without Save', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [123, 456]);
    final adopted = harness
        .local
        .drafts
        .drafts['${AdminDraftSessionHarness.accountA}/456']!;
    harness.router.goNamed(
      RouteNames.adminSubmissionSaveProgress,
      queryParameters: {'session': adopted.owner.sessionId},
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
    expect(harness.owner.submissionId, 456);
    expect(harness.owner.sessionId, adopted.owner.sessionId);
    expect(harness.repository.createInputs, isEmpty);
    expect(harness.repository.updateIds, isEmpty);
    expect(harness.repository.addAssetCalls, isEmpty);
  }, disposeOwners: () => harness.dispose());
}
