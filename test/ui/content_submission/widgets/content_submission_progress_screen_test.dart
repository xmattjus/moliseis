import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/predictive_back.dart';

void main() {
  ContentSubmissionViewModel buildViewModel({
    required ControllableSubmissionRepository submissionRepository,
    ContentSubmissionDraftRepository? draftRepository,
    FakeContentSubmissionStagedAssetRepository? stagedAssetRepository,
  }) {
    // _submit null-checks these fields; populate them so the Command can run.
    return ContentSubmissionViewModel(
        logger: MockLogger(),
        contentSubmissionRepository: submissionRepository,
        draftRepository:
            draftRepository ?? FakeContentSubmissionDraftRepository(),
        stagedAssetRepository:
            stagedAssetRepository ??
            FakeContentSubmissionStagedAssetRepository(),
        imagePicker: FakeImagePicker(),
      )
      ..setCity('Campobasso')
      ..setName('Test event')
      ..setUserEmail('test@example.com')
      ..setUserName('Test User');
  }

  /// Harness mounting the progress screen as the initial route. Use for tests
  /// that never need to pop to a previous page.
  Widget buildProgressFirstApp(ContentSubmissionViewModel viewModel) {
    final router = GoRouter(
      initialLocation: '/progress',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (_, _) => const _HomeMarker(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, _) => ContentSubmissionProgressScreen(
            viewModel: context.read<ContentSubmissionViewModel>(),
          ),
        ),
      ],
    );
    return ChangeNotifierProvider<ContentSubmissionViewModel>.value(
      value: viewModel,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// Harness mounting the home route as the initial route and mirroring the
  /// production route tree (`/contentSubmission` form → `uploadProgress`
  /// child). The caller pushes the form and progress pages on top via
  /// [pushProgress] so pop returns to the form, then home. Use for tests that
  /// exercise pop/back, including the pop-twice-then-push completed exits.
  (GoRouter, Widget) buildHomeFirstApp(ContentSubmissionViewModel viewModel) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (_, _) => const _HomeMarker(),
        ),
        GoRoute(
          path: '/contentSubmission',
          name: RouteNames.contentSubmission,
          builder: (_, _) => const _FormMarker(),
          routes: <RouteBase>[
            GoRoute(
              path: 'uploadProgress',
              name: RouteNames.contentSubmissionUploadProgress,
              builder: (context, _) => ContentSubmissionProgressScreen(
                viewModel: context.read<ContentSubmissionViewModel>(),
              ),
            ),
          ],
        ),
      ],
    );
    return (
      router,
      ChangeNotifierProvider<ContentSubmissionViewModel>.value(
        value: viewModel,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  /// Pushes the form route (`/contentSubmission`) and then the progress
  /// route on top of it, mirroring the production stack
  /// `[explore → contentSubmission → contentSubmission/uploadProgress]`,
  /// waiting for the form route to mount before pushing its child.
  ///
  /// Returns synchronously without awaiting `pushNamed`: its returned
  /// `Future<String?>` only completes when the pushed route is *popped*
  /// (carrying a result), so awaiting it would hang the test forever.
  ///
  /// This harness deliberately leaves `submit` idle so tests can exercise the
  /// process-restoration recovery state. Callers that need an in-flight upload
  /// start `submit` after this helper returns.
  Future<void> pushProgress(WidgetTester tester, GoRouter router) async {
    unawaited(router.pushNamed(RouteNames.contentSubmission));
    await tester.pumpAndSettle();
    unawaited(router.pushNamed(RouteNames.contentSubmissionUploadProgress));
    await tester.pumpAndSettle();
  }

  group('ContentSubmissionProgressScreen state rendering', () {
    testWidgets('idle: shows recovery UI and no retry action', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));

      expect(find.byIcon(Symbols.upload), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining("L'invio è stato interrotto"), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('Torna al modulo'), findsOneWidget);
      expect(find.text('Torna alla home'), findsNothing);
      expect(find.text('Nuovo suggerimento'), findsNothing);
      expect(find.text('Riprova'), findsNothing);
      expect(vm.submit.idle, isTrue);
    });

    testWidgets('running: shows spinner and no action buttons', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));

      unawaited(vm.submit.execute());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Invio in corso...'), findsOneWidget);
      expect(find.text('Torna alla home'), findsNothing);
      expect(find.text('Nuovo suggerimento'), findsNothing);
      expect(find.text('Riprova'), findsNothing);
      expect(vm.submit.running, isTrue);

      addTearDown(() => repo.completeUpload(const Result.success(null)));
    });

    testWidgets('completed: shows success text and Nuovo suggerimento', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));

      unawaited(vm.submit.execute());
      await tester.pump();

      repo.completeUpload(const Result.success(null));
      await tester.pumpAndSettle();

      expect(find.byIcon(Symbols.check_circle), findsOneWidget);
      expect(find.textContaining('inviato con successo'), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);
      expect(find.text('Torna alla home'), findsOneWidget);
      expect(vm.submit.completed, isTrue);
    });

    testWidgets('error: shows error text and Riprova', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));

      unawaited(vm.submit.execute());
      await tester.pump();

      repo.completeUpload(Result.error(Exception('upload failed')));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Symbols.error_circle_rounded_rounded),
        findsOneWidget,
      );
      expect(find.textContaining('problema durante'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsNothing);
      expect(find.text('Torna alla home'), findsOneWidget);
      expect(vm.submit.error, isTrue);
    });
  });

  group('ContentSubmissionProgressScreen clear command call sites', () {
    testWidgets(
      'BackButton when completed pops once, clears, and reveals the form',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
        );
        final completedIdentity = vm.state.clientSubmissionId;

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        expect(
          // This is the explicit invariant that verifies Provider installed
          // its ChangeNotifier listener for the regression harness.
          // ignore: invalid_use_of_protected_member
          vm.hasListeners,
          isTrue,
          reason: 'Provider must subscribe to the view model.',
        );
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isTrue);
        expect(draftRepo.clearDraftCallCount, 1);
        expect(stagedRepo.clearedSessions, [completedIdentity]);
        // The completed exit pops the progress route once and lands on the
        // form route below; the form screen owns the reset of its fields when
        // `viewModel.clear` completes.
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
        expect(
          find.byType(ContentSubmissionProgressScreen),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'BackButton when error does not call clear and pops to the form',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(Result.error(Exception('boom')));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // P2 intent: the error-path back returns to the previous screen
        // (the form) WITHOUT clearing state, so the user can edit and
        // retry. With the production-shaped harness the previous screen is
        // `_FormMarker`, not home.
        expect(draftRepo.clearDraftCalled, isFalse);
        expect(stagedRepo.clearedSessions, isEmpty);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets(
      'Nuovo suggerimento when completed clears then pops to the form',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
        );
        final completedIdentity = vm.state.clientSubmissionId;

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Nuovo suggerimento'));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isTrue);
        expect(draftRepo.clearDraftCallCount, 1);
        expect(stagedRepo.clearedSessions, [completedIdentity]);
        // The completed exit pops the progress route once and lands on the
        // form route below, which resets its own fields on clear.
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
        expect(
          find.byType(ContentSubmissionProgressScreen),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'OS back when completed pops once, clears, and reveals the form',
      (
        tester,
      ) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        // Simulate the OS back gesture by dispatching it at the binding level,
        // which routes through `PopScope.onPopInvokedWithResult` rather than
        // the explicit AppBar chevron tap path.
        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(draftRepo.clearDraftCalled, isTrue);
        expect(draftRepo.clearDraftCallCount, 1);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
        expect(
          find.byType(ContentSubmissionProgressScreen),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('OS back when error does not clear and pops to the form', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final draftRepo = FakeContentSubmissionDraftRepository();
      final stagedRepo = FakeContentSubmissionStagedAssetRepository();
      final vm = buildViewModel(
        submissionRepository: repo,
        draftRepository: draftRepo,
        stagedAssetRepository: stagedRepo,
      );

      final (router, app) = buildHomeFirstApp(vm);
      await tester.pumpWidget(app);
      await pushProgress(tester, router);
      unawaited(vm.submit.execute());
      await tester.pump();
      repo.completeUpload(Result.error(Exception('boom')));
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(draftRepo.clearDraftCalled, isFalse);
      expect(stagedRepo.clearedSessions, isEmpty);
      expect(find.byType(_FormMarker), findsOneWidget);
      expect(find.byType(_HomeMarker), findsNothing);
    });

    testWidgets(
      'BackButton while idle pops to form without clearing or retrying',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isFalse);
        expect(stagedRepo.clearedSessions, isEmpty);
        expect(repo.uploadCallCount, 0);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets(
      'Torna al modulo while idle pops to form without clearing or retrying',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);

        await tester.tap(find.text('Torna al modulo'));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isFalse);
        expect(repo.uploadCallCount, 0);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets(
      'OS back while idle pops to form without clearing or retrying',
      (
        tester,
      ) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);

        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(draftRepo.clearDraftCalled, isFalse);
        expect(repo.uploadCallCount, 0);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets('OS back while running is blocked and does not pop', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      final (router, app) = buildHomeFirstApp(vm);
      await tester.pumpWidget(app);
      await pushProgress(tester, router);
      unawaited(vm.submit.execute());
      await tester.pump();

      final handled = await tester.binding.handlePopRoute();
      // The spinner keeps animating, so a single pump is enough here.
      await tester.pump();

      expect(handled, isTrue);
      expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
      expect(find.byType(_FormMarker), findsNothing);
      expect(vm.submit.running, isTrue);

      addTearDown(() => repo.completeUpload(const Result.success(null)));
    });

    testWidgets(
      'predictive back while idle pops to form without clearing or retrying',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final repo = ControllableSubmissionRepository();
          final draftRepo = FakeContentSubmissionDraftRepository();
          final vm = buildViewModel(
            submissionRepository: repo,
            draftRepository: draftRepo,
          );

          final (router, app) = buildHomeFirstApp(vm);
          await tester.pumpWidget(app);
          await pushProgress(tester, router);

          await startPredictiveBack(tester);
          expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

          await commitPredictiveBack(tester);

          expect(draftRepo.clearDraftCalled, isFalse);
          expect(repo.uploadCallCount, 0);
          expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
          expect(find.byType(_FormMarker), findsOneWidget);
          expect(find.byType(_HomeMarker), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'predictive back while running does not pop the progress route',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final repo = ControllableSubmissionRepository();
          final vm = buildViewModel(submissionRepository: repo);

          final (router, app) = buildHomeFirstApp(vm);
          await tester.pumpWidget(app);
          await pushProgress(tester, router);
          unawaited(vm.submit.execute());
          await tester.pump();

          await startPredictiveBack(tester);
          expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

          // Commit the gesture without settling: the running spinner is an
          // infinite animation, so `pumpAndSettle` would never settle.
          await commitPredictiveBack(tester, settle: false);

          expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
          expect(find.byType(_FormMarker), findsNothing);
          expect(vm.submit.running, isTrue);

          addTearDown(() => repo.completeUpload(const Result.success(null)));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets('Riprova when error does not call clear and retries submit', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final draftRepo = FakeContentSubmissionDraftRepository();
      final vm = buildViewModel(
        submissionRepository: repo,
        draftRepository: draftRepo,
      );

      await tester.pumpWidget(buildProgressFirstApp(vm));
      unawaited(vm.submit.execute());
      await tester.pump();
      repo.completeUpload(Result.error(Exception('first')));
      await tester.pumpAndSettle();
      expect(repo.uploadCallCount, 1);

      await tester.tap(find.text('Riprova'));
      await tester.pump();

      expect(draftRepo.clearDraftCalled, isFalse);
      expect(vm.submit.running, isTrue);
      expect(repo.uploadCallCount, 2);

      addTearDown(() => repo.completeUpload(const Result.success(null)));
    });

    testWidgets('Torna alla home clears once and navigates home', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final draftRepo = FakeContentSubmissionDraftRepository();
      final stagedRepo = FakeContentSubmissionStagedAssetRepository();
      final vm = buildViewModel(
        submissionRepository: repo,
        draftRepository: draftRepo,
        stagedAssetRepository: stagedRepo,
      );
      final completedIdentity = vm.state.clientSubmissionId;

      await tester.pumpWidget(buildProgressFirstApp(vm));
      unawaited(vm.submit.execute());
      await tester.pump();
      repo.completeUpload(const Result.success(null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Torna alla home'));
      await tester.pumpAndSettle();

      expect(draftRepo.clearDraftCalled, isTrue);
      expect(draftRepo.clearDraftCallCount, 1);
      expect(stagedRepo.clearedSessions, [completedIdentity]);
      expect(find.byType(_HomeMarker), findsOneWidget);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'completed exits on separate progress routes each clear once',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCallCount, 1);
        expect(find.byType(_FormMarker), findsOneWidget);

        vm
          ..setCity('Campobasso')
          ..setName('Second test event')
          ..setUserEmail('second@example.com')
          ..setUserName('Second Test User');

        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();

        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        expect(repo.uploadCallCount, 2);

        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCallCount, 2);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('HOME_MARKER')));
}

class _FormMarker extends StatelessWidget {
  const _FormMarker();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('FORM_MARKER')));
}
