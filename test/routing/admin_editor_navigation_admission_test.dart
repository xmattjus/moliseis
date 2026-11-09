import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/routing/admin_submission_exit_policy.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/utils/result.dart';

import '../support/admin_draft_repositories.dart';
import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';

void main() {
  late AdminSaveRouteHarness harness;

  testOwnerUI('only the exact destination consumes a rejection once', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1]);
    await harness.openEditor(tester, target: 1);
    final original = harness.owner.activation!;
    final query = {'session': original.owner.sessionId};
    var rejected = 0;
    final admission = AdminEditorNavigationAdmission(
      location: Uri.parse(
        harness.router.namedLocation(
          RouteNames.adminSubmissionEditor,
          pathParameters: {'id': '2'},
          queryParameters: query,
        ),
      ),
      onRejected: () => rejected++,
    );

    unawaited(
      harness.router.pushNamed<Object?>(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '3'},
        queryParameters: query,
        extra: admission,
      ),
    );
    await tester.pumpAndSettle();
    expect(rejected, 0);
    expect(harness.owner.isActivationCurrent(original), isTrue);

    for (var attempt = 0; attempt < 2; attempt++) {
      unawaited(
        harness.router.pushNamed<Object?>(
          RouteNames.adminSubmissionEditor,
          pathParameters: {'id': '2'},
          queryParameters: query,
          extra: admission,
        ),
      );
      await tester.pumpAndSettle();
      expect(rejected, 1);
      expect(harness.owner.isActivationCurrent(original), isTrue);
      expect(harness.router.state.uri.path, '/admin/submissions/1');
    }
    expect(harness.repository.getByIdIds, [1]);
    expect(harness.local.drafts.saves, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('admitted request cannot become rejected on a later reparse', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
    await harness.openEditor(tester, target: 1);
    final target =
        harness.local.drafts.drafts['${AdminDraftSessionHarness.accountA}/2']!;
    final query = {'session': target.owner.sessionId};
    var rejected = 0;
    final admission = AdminEditorNavigationAdmission(
      location: Uri.parse(
        harness.router.namedLocation(
          RouteNames.adminSubmissionEditor,
          pathParameters: {'id': '2'},
          queryParameters: query,
        ),
      ),
      onRejected: () => rejected++,
    );
    final visit = harness.router.pushNamed<Object?>(
      RouteNames.adminSubmissionEditor,
      pathParameters: {'id': '2'},
      queryParameters: query,
      extra: admission,
    );
    await tester.pumpAndSettle();
    expect(harness.owner.activation!.owner, target.owner);
    expect(rejected, 0);

    harness.owner.setName(
      'Retained private edit',
      activation: harness.owner.activation,
    );
    harness.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    unawaited(
      harness.router.pushNamed<Object?>(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '2'},
        queryParameters: query,
        extra: admission,
      ),
    );
    await tester.pumpAndSettle();
    expect(rejected, 0);
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    expect(harness.owner.name, 'Retained private edit');
    expect(harness.owner.activation!.owner, target.owner);
    await tester.tap(find.text('Esci senza salvare'));
    await tester.pumpAndSettle();
    await visit;
    expect(rejected, 0);
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.repository.updateInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('deferred admission denial releases policy for a fresh retry', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
    await harness.openEditor(tester, target: 1);
    final original = harness.owner.activation!;
    final target =
        harness.local.drafts.drafts['${AdminDraftSessionHarness.accountA}/2']!;
    final query = {'session': target.owner.sessionId};
    final gate = Completer<Result<AdminSubmissionDraft?>>();
    var lookups = 0;
    harness.local.drafts.onLoadBySession = (account, session) {
      expect(account, target.owner.accountId);
      expect(session, target.owner.sessionId);
      lookups++;
      return gate.future;
    };
    var rejected = 0;
    final location = Uri.parse(
      harness.router.namedLocation(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '2'},
        queryParameters: query,
      ),
    );
    unawaited(
      harness.router.pushNamed<Object?>(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '2'},
        queryParameters: query,
        extra: AdminEditorNavigationAdmission(
          location: location,
          onRejected: () => rejected++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(lookups, 1);
    expect(rejected, 0);
    expect(harness.owner.isActivationCurrent(original), isTrue);
    gate.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(rejected, 1);
    expect(harness.owner.isActivationCurrent(original), isTrue);
    expect(harness.router.state.uri.path, '/admin/submissions/1');

    harness.local.drafts.onLoadBySession = null;
    final visit = harness.router.pushNamed<Object?>(
      RouteNames.adminSubmissionEditor,
      pathParameters: {'id': '2'},
      queryParameters: query,
      extra: AdminEditorNavigationAdmission(
        location: location,
        onRejected: () => rejected++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    expect(harness.owner.activation!.owner, target.owner);
    expect(rejected, 1);
    harness.router.pop();
    await tester.pumpAndSettle();
    await visit;
    expect(harness.local.drafts.saves, isEmpty);
    expect(harness.repository.updateInputs, isEmpty);
  }, disposeOwners: () => harness.dispose());
}
