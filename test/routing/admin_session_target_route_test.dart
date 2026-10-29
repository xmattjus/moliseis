import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';

import '../support/admin_draft_repositories.dart';
import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';

void main() {
  late AdminSaveRouteHarness harness;

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
