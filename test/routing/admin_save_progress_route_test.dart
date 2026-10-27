import 'dart:async';
import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_save_progress_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/admin_draft_repositories.dart';
import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/predictive_back.dart';

void main() {
  late AdminSaveRouteHarness harness;

  testOwnerUI('cold progress reconstruction never admits a mutation', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.router.go('/admin/submissions/save-progress');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
    expect(find.textContaining('Nessun salvataggio'), findsOneWidget);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(harness.repository.createInputs, isEmpty);
    expect(harness.repository.updateIds, isEmpty);
    expect(harness.repository.addAssetCalls, isEmpty);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'progress observes admitted Save across rebuild and blocks Back',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.router.goNamed(RouteNames.adminSubmissionNew);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = tester
          .widget<AdminSubmissionEditorScreen>(
            find.byType(AdminSubmissionEditorScreen),
          )
          .viewModel;
      expect(owner, same(harness.owner));
      final activation = owner.activation;
      owner
        ..setCategory(ContentCategory.history, activation: activation)
        ..setCity('Campobasso', activation: activation)
        ..setName('Contributo di prova', activation: activation);
      final gate = Completer<Result<AdminSubmission>>();
      harness.repository.pendingCreate = gate;
      expect(owner.requestSave(activation: activation), isTrue);
      expect(owner.saveSnapshot.isRunning, isTrue);
      expect(owner.requestSave(activation: activation), isFalse);
      final attempt = owner.saveExecutionId;
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {'session': owner.sessionId, 'attempt': '$attempt'},
        ),
      );
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<AdminSubmissionSaveProgressScreen>(
              find.byType(AdminSubmissionSaveProgressScreen),
            )
            .viewModel,
        same(owner),
      );
      expect(harness.repository.createInputs, hasLength(1));
      await tester.binding.handlePopRoute();
      await pumpCommandTurns(tester);
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      await startPredictiveBack(tester);
      await updatePredictiveBack(tester, 0.6);
      await commitPredictiveBack(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      await tester.pumpWidget(harness.app());
      await pumpCommandTurns(tester);
      expect(harness.repository.createInputs, hasLength(1));
      gate.complete(
        Result.success(
          sampleAdminSubmission(
            description: null,
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.repository.createInputs, hasLength(1));
      expect(owner.savePhase.name, 'completed');
      expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
      await tester.tap(find.text('Torna all’editor'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AdminSubmissionEditorScreen>(
              find.byType(AdminSubmissionEditorScreen),
            )
            .viewModel,
        same(owner),
      );
      expect(owner.sessionId, activation!.owner.sessionId);
      expect(owner.submissionId, 1);
    },
    disposeOwners: () => harness.dispose(),
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testOwnerUI('Save button reserves before navigating to progress', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.router.goNamed(RouteNames.adminSubmissionNew);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final owner = harness.owner;
    final activation = owner.activation;
    owner.setCategory(ContentCategory.history, activation: activation);
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Città',
      ),
      'Campobasso',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Luogo o evento',
      ),
      'Contributo di prova',
    );
    final gate = Completer<Result<AdminSubmission>>();
    harness.repository.pendingCreate = gate;
    var observedAdmitted = false;
    harness.router.routerDelegate.addListener(() {
      if (harness.router.state.uri.path.endsWith('save-progress')) {
        observedAdmitted =
            owner.saveSnapshot.isRunning && owner.saveExecutionId != null;
      }
    });
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Crea contributo'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(AdminSubmissionEditorScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Crea contributo'));
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(observedAdmitted, isTrue);
    expect(find.byType(AdminSubmissionSaveProgressScreen), findsOneWidget);
    expect(harness.repository.createInputs, hasLength(1));
    gate.complete(
      Result.success(
        sampleAdminSubmission(
          description: null,
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(owner.savePhase.name, 'completed');
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'terminal progress without its editor below returns to exact session',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.router.goNamed(RouteNames.adminSubmissionNew);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = harness.owner;
      final activation = owner.activation;
      owner
        ..setCategory(ContentCategory.history, activation: activation)
        ..setCity('Campobasso', activation: activation)
        ..setName('Contributo di prova', activation: activation);
      expect(owner.requestSave(activation: activation), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      final session = owner.sessionId;
      final attempt = owner.saveExecutionId;
      harness.router.goNamed(RouteNames.adminDashboard);
      await tester.pumpAndSettle();
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {'session': session, 'attempt': '$attempt'},
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.repository.createInputs, hasLength(1));
      await tester.tap(find.text('Torna all’editor'));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/admin/submissions/1');
      expect(harness.router.state.uri.queryParameters['session'], session);
      expect(harness.owner.sessionId, session);
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(harness.repository.createInputs, hasLength(1));
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'retained editor A reactivates after B pops without reviving A1',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.repository.getByIdResults.addAll({
        1: Result.success(
          sampleAdminSubmission(
            name: 'Editor A',
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          ),
        ),
        2: Result.success(
          sampleAdminSubmission(
            id: 2,
            name: 'Editor B',
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          ),
        ),
      });
      harness.router.goNamed(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '1'},
      );
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = harness.owner;
      expect(await owner.checkpointLocal(), isA<Success<void>>());
      await tester.pump();
      final activationA1 = owner.activation;
      final sessionA = owner.sessionId;
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionEditor,
          pathParameters: {'id': '2'},
        ),
      );
      await tester.pumpAndSettle();
      expect(owner.submissionId, 2);
      expect(owner.name, 'Editor B');
      expect(owner.isActivationCurrent(activationA1), isFalse);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/admin/submissions/1');
      expect(owner.submissionId, 1);
      expect(owner.sessionId, sessionA);
      expect(owner.name, 'Editor A');
      expect(owner.isActivationCurrent(activationA1), isFalse);
      owner.setName('obsolete A1 callback', activation: activationA1);
      expect(owner.name, 'Editor A');
      expect(
        tester
            .widget<AdminSubmissionEditorScreen>(
              find.byType(AdminSubmissionEditorScreen),
            )
            .viewModel,
        same(owner),
      );
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('failed local checkpoint preserves fields and shows an error', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.router.goNamed(RouteNames.adminSubmissionNew);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final owner = harness.owner;
    final activation = owner.activation;
    owner.setName('Unfinished local value', activation: activation);
    harness.local.drafts.onSave = (_) async =>
        Result.error(TestException('private filesystem unavailable'));
    expect(owner.hasDurableDraft, isFalse);
    await tester.pump();
    await tester.tap(find.text('Salva bozza locale'));
    await tester.pumpAndSettle();
    expect(owner.name, 'Unfinished local value');
    expect(owner.hasDurableDraft, isFalse);
    expect(harness.local.drafts.saves, hasLength(1));
    expect(harness.local.drafts.drafts, isEmpty);
    expect(harness.repository.createInputs, isEmpty);
    expect(harness.repository.updateIds, isEmpty);
    expect(find.textContaining('private filesystem'), findsNothing);
    expect(
      find.text('Si è verificato un errore, riprova più tardi'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI('framework restoration resumes adopted new-route session', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness();
    harness.router.goNamed(RouteNames.adminSubmissionNew);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final owner = harness.owner;
    final initial = owner.activation;
    owner
      ..setCategory(ContentCategory.history, activation: initial)
      ..setCity('Campobasso', activation: initial)
      ..setName('Contributo di prova', activation: initial);
    expect(owner.requestSave(activation: initial), isTrue);
    await pumpCommandTurns(tester);
    await tester.pumpAndSettle();
    expect(owner.savePhase.name, 'completed');
    final sessionId = owner.sessionId;
    expect(owner.submissionId, 1);
    expect(harness.router.state.uri.path, '/admin/submissions/new');
    expect(harness.router.state.uri.queryParameters['session'], isNull);
    // This fake proves repository-boundary restoration of committed metadata.
    // Real private-file reopen durability is verified by the persistence suite.
    harness.local.staged.onResolve = (_) async =>
        Result.error(TestException('No filesystem in this routing fixture'));
    final acquired = await harness.local.session.acquire(
      File('fixture-source-never-read-by-fake'),
      capacity: harness.local.session.capacityContext,
    );
    expect(acquired.getOrNull(), isNotNull);
    final staged = acquired.getOrNull()!;
    owner.setLatitudeText('41,', activation: owner.activation);
    expect(await owner.checkpointLocal(), isA<Success<void>>());
    await tester.pumpAndSettle();
    final data = await tester.getRestorationData();
    final creates = harness.repository.createInputs.length;
    final updates = harness.repository.updateInputs.length;
    final uploads = harness.content.uploadedImages.length;
    for (var restart = 0; restart < 2; restart++) {
      await tester.pumpWidget(const SizedBox.shrink());
      owner.revoke();
      expect(owner.sessionId, isNull);
      await tester.pumpWidget(harness.app());
      await tester.restoreFrom(data);
      await tester.pumpAndSettle();
      expect(owner.sessionId, sessionId);
      expect(owner.submissionId, 1);
      expect(owner.latitudeText, '41,');
      expect(owner.stagedAssets.single, staged);
      expect(owner.hasDurableDraft, isTrue);
      expect(harness.repository.createInputs, hasLength(creates));
      expect(harness.repository.updateInputs, hasLength(updates));
      expect(harness.content.uploadedImages, hasLength(uploads));
      expect(harness.repository.addAssetCalls, isEmpty);
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
    }
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'obsolete progress Retry cannot admit a later same-session Save',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.router.goNamed(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '1'},
      );
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = harness.owner;
      final activation = owner.activation;
      harness.local.drafts.onSave = (_) async =>
          Result.error(TestException('checkpoint failed'));
      expect(owner.requestSave(activation: activation), isTrue);
      await pumpCommandTurns(tester);
      final attemptA = owner.saveExecutionId;
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {'session': owner.sessionId, 'attempt': '$attemptA'},
        ),
      );
      await tester.pumpAndSettle();
      final obsoleteRetry = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Riprova'))
          .onPressed!;
      harness.local.drafts.onSave = null;
      owner.setName('Confirmed B', activation: activation);
      final confirmedB = sampleAdminSubmission(
        name: 'Confirmed B',
        description: null,
        modifiedAtToken: '2026-08-20T00:00:01.123456Z',
      );
      harness.repository
        ..updateResult = Result.success(confirmedB)
        ..getByIdResults[1] = Result.success(confirmedB);
      expect(owner.requestSave(activation: activation), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      expect(owner.savePhase.name, 'completed');
      expect(owner.isActivationCurrent(activation), isTrue);
      owner.setName('Uncaptured C', activation: activation);
      expect(owner.canRequestSave, isTrue);
      final attemptB = owner.saveExecutionId;
      final location = harness.router.state.uri;
      final updates = harness.repository.updateInputs.length;
      obsoleteRetry();
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      expect(owner.saveExecutionId, attemptB);
      expect(harness.repository.updateInputs, hasLength(updates));
      expect(harness.router.state.uri, location);
      expect(owner.name, 'Uncaptured C');
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'obsolete progress read-back cannot consume a newer Update intent',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.router.goNamed(
        RouteNames.adminSubmissionEditor,
        pathParameters: {'id': '1'},
      );
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = harness.owner;
      final activation = owner.activation;
      owner.setName('Update A', activation: activation);
      harness.repository.updateResult = Result.error(
        TestException('response lost'),
      );
      expect(owner.requestSave(activation: activation), isTrue);
      await pumpCommandTurns(tester);
      final attemptA = owner.saveExecutionId;
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {'session': owner.sessionId, 'attempt': '$attemptA'},
        ),
      );
      await tester.pumpAndSettle();
      final obsoleteReadBack = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Verifica esito remoto'),
          )
          .onPressed!;
      harness.repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          name: 'Update A',
          description: null,
          modifiedAtToken: '2026-08-20T00:00:01.123456Z',
        ),
      );
      expect(owner.requestSaveReadBack(activation: activation), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      expect(owner.savePhase.name, 'completed');
      owner.setName('Update B', activation: activation);
      expect(owner.requestSave(activation: activation), isTrue);
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      expect(owner.savePhase.name, 'unknownOutcome');
      expect(owner.isActivationCurrent(activation), isTrue);
      expect(owner.canRequestSaveReadBack, isTrue);
      final attemptB = owner.saveExecutionId;
      final loadExecution = owner.loadExecutionId;
      final reads = harness.repository.getByIdIds.length;
      final location = harness.router.state.uri;
      obsoleteReadBack();
      await pumpCommandTurns(tester);
      await tester.pumpAndSettle();
      expect(owner.saveExecutionId, attemptB);
      expect(owner.loadExecutionId, loadExecution);
      expect(owner.savePhase.name, 'unknownOutcome');
      expect(owner.canRequestSaveReadBack, isTrue);
      expect(harness.repository.getByIdIds, hasLength(reads));
      expect(harness.router.state.uri, location);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'dashboard resume protects A draft through B and reauthorizes A',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.router.goNamed(RouteNames.adminSubmissionNew);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = harness.owner;
      final accountA = harness.auth.viewModel.currentUser!;
      final activationA = owner.activation!;
      owner
        ..setName('Private unfinished A', activation: activationA)
        ..setLatitudeText('41,', activation: activationA);
      expect(await owner.checkpointLocal(), isA<Success<void>>());
      const nonce = '22222222-2222-4222-8222-222222222222';
      expect(
        await harness.local.session.setNavigationIntent(
          activation: activationA,
          requestNonce: nonce,
        ),
        isA<Success<void>>(),
      );
      await tester.pumpAndSettle();
      expect(harness.auth.viewModel.requestLogout(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      final accountB = makeAuthUser(
        isAdmin: true,
        id: AdminDraftSessionHarness.accountB,
      );
      harness.auth.onPassword = () async {
        harness.auth.setUser(accountB);
        return AuthResponse(
          user: accountB,
          session: harness.auth.client.currentSession,
        );
      };
      expect(
        harness.auth.viewModel.requestLogin((
          email: 'b@example.com',
          password: 'fixture-password',
        )),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(harness.auth.viewModel.currentUser?.id, accountB.id);
      expect(harness.router.state.uri.path, RoutePaths.admin);
      await tester.tap(find.byTooltip('Riprendi editor'));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, RoutePaths.admin);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.text('Private unfinished A'), findsNothing);
      expect(owner.sessionId, isNull);
      final retainedA =
          harness.local.drafts.drafts[activationA.owner.lookupKey]!;
      expect(retainedA.owner.sessionId, activationA.owner.sessionId);
      expect(retainedA.snapshot.name, 'Private unfinished A');
      expect(retainedA.navigationIntent?.requestNonce, nonce);
      expect(harness.auth.viewModel.requestLogout(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      harness.auth.onPassword = () async {
        harness.auth.setUser(accountA);
        return AuthResponse(
          user: accountA,
          session: harness.auth.client.currentSession,
        );
      };
      expect(
        harness.auth.viewModel.requestLogin((
          email: 'a@example.com',
          password: 'fixture-password',
        )),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, RoutePaths.admin);
      await tester.tap(find.byTooltip('Riprendi editor'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
      expect(owner.accountId, accountA.id);
      expect(owner.sessionId, activationA.owner.sessionId);
      expect(owner.name, 'Private unfinished A');
      expect(owner.latitudeText, '41,');
      expect(owner.hasDurableDraft, isTrue);
      expect(harness.repository.createInputs, isEmpty);
      expect(harness.repository.updateInputs, isEmpty);
      expect(harness.content.uploadedImages, isEmpty);
      expect(harness.repository.addAssetCalls, isEmpty);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'auth revocation can leave running progress before HTTP settles',
    (tester) async {
      harness = AdminSaveRouteHarness();
      harness.router.goNamed(RouteNames.adminSubmissionNew);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final owner = harness.owner;
      final activation = owner.activation;
      owner
        ..setCategory(ContentCategory.history, activation: activation)
        ..setCity('Campobasso', activation: activation)
        ..setName('Contributo di prova', activation: activation);
      final gate = Completer<Result<AdminSubmission>>();
      harness.repository.pendingCreate = gate;
      expect(owner.requestSave(activation: activation), isTrue);
      unawaited(
        harness.router.pushNamed(
          RouteNames.adminSubmissionSaveProgress,
          queryParameters: {
            'session': owner.sessionId,
            'attempt': '${owner.saveExecutionId}',
          },
        ),
      );
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 400));
      harness.auth.setUser(null);
      harness.auth.emit(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
      gate.complete(
        Result.success(
          sampleAdminSubmission(
            description: null,
            modifiedAtToken: '2026-08-20T00:00:00.123456Z',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(owner.sessionId, isNull);
    },
    disposeOwners: () => harness.dispose(),
  );
}
