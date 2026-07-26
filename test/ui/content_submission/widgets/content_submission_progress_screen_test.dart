import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  ContentSubmissionViewModel buildViewModel({
    required ControllableSubmissionRepository submissionRepository,
    ContentSubmissionDraftRepository? draftRepository,
  }) {
    final vm = ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: submissionRepository,
      draftRepository:
          draftRepository ?? FakeContentSubmissionDraftRepository(),
      imagePicker: FakeImagePicker(),
    );
    // _submit null-checks these fields; populate them so the Command can run.
    vm
      ..setCity('Campobasso')
      ..setName('Test event')
      ..setUserEmail('test@example.com')
      ..setUserName('Test User');
    return vm;
  }

  /// Flushes the 3s debounce timer scheduled by the setters in
  /// [buildViewModel] so the test binding does not fail its "no pending
  /// timers" invariant.
  Future<void> flushDebounce(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3, milliseconds: 100));

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
          builder: (_, _) =>
              ContentSubmissionProgressScreen(viewModel: viewModel),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
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
              builder: (_, _) =>
                  ContentSubmissionProgressScreen(viewModel: viewModel),
            ),
          ],
        ),
      ],
    );
    return (router, MaterialApp.router(routerConfig: router));
  }

  /// Pushes the form route (`/contentSubmission`) and then the progress
  /// route on top of it, mirroring the production stack
  /// `[explore → contentSubmission → contentSubmission/uploadProgress]`,
  /// and pumps a single frame so the progress screen is mounted.
  ///
  /// Returns synchronously without awaiting `pushNamed`: its returned
  /// `Future<String?>` only completes when the pushed route is *popped*
  /// (carrying a result), so awaiting it would hang the test forever.
  ///
  /// Pumps once (not `pumpAndSettle`) because at push time `submit` is
  /// `idle` and the progress screen renders an indefinite
  /// `CircularProgressIndicator` — `pumpAndSettle` would never settle on
  /// that infinite animation. Callers that need a settled tree should drive
  /// `submit` to `completed`/`error` (which swaps the spinner for a static
  /// icon) and then `pumpAndSettle`.
  Future<void> pushProgress(WidgetTester tester, GoRouter router) async {
    unawaited(router.pushNamed(RouteNames.contentSubmission));
    unawaited(router.pushNamed(RouteNames.contentSubmissionUploadProgress));
    await tester.pump();
  }

  group('ContentSubmissionProgressScreen state rendering', () {
    testWidgets('idle: shows spinner and no action buttons', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));
      await flushDebounce(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Invio in corso...'), findsOneWidget);
      expect(find.text('Torna alla home'), findsNothing);
      expect(find.text('Nuovo suggerimento'), findsNothing);
      expect(find.text('Riprova'), findsNothing);
      expect(vm.submit.idle, isTrue);
    });

    testWidgets('running: shows spinner and no action buttons', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));
      await flushDebounce(tester);

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
      await flushDebounce(tester);

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
      await flushDebounce(tester);

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
      'BackButton when completed calls clear then recreates the form fresh',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await flushDebounce(tester);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isTrue);
        // P1 fix: completed exits recreate the form (pop-twice-then-push),
        // so they land on a fresh `/contentSubmission` route, not home.
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
        expect(
          find.byType(ContentSubmissionProgressScreen),
          findsNothing,
        );
      },
    );

    testWidgets(
      'BackButton when error does not call clear and pops to the form',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await flushDebounce(tester);
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
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets(
      'Nuovo suggerimento when completed calls clear then recreates the form',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final draftRepo = FakeContentSubmissionDraftRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
        );

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await flushDebounce(tester);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Nuovo suggerimento'));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isTrue);
        // P4 fix: same pop-twice-then-push as the AppBar chevron on success.
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
        expect(
          find.byType(ContentSubmissionProgressScreen),
          findsNothing,
        );
      },
    );

    testWidgets('OS back when completed clears and recreates the form', (
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
      await flushDebounce(tester);
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
      expect(find.byType(_FormMarker), findsOneWidget);
      expect(find.byType(_HomeMarker), findsNothing);
      expect(
        find.byType(ContentSubmissionProgressScreen),
        findsNothing,
      );
    });

    testWidgets('OS back when error does not clear and pops to the form', (
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
      await flushDebounce(tester);
      await pushProgress(tester, router);
      unawaited(vm.submit.execute());
      await tester.pump();
      repo.completeUpload(Result.error(Exception('boom')));
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(draftRepo.clearDraftCalled, isFalse);
      expect(find.byType(_FormMarker), findsOneWidget);
      expect(find.byType(_HomeMarker), findsNothing);
    });

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
      await flushDebounce(tester);
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

    testWidgets('Torna alla home calls clear and navigates home', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final draftRepo = FakeContentSubmissionDraftRepository();
      final vm = buildViewModel(
        submissionRepository: repo,
        draftRepository: draftRepo,
      );

      await tester.pumpWidget(buildProgressFirstApp(vm));
      await flushDebounce(tester);
      unawaited(vm.submit.execute());
      await tester.pump();
      repo.completeUpload(const Result.success(null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Torna alla home'));
      await tester.pumpAndSettle();

      expect(draftRepo.clearDraftCalled, isTrue);
      expect(find.byType(_HomeMarker), findsOneWidget);
    });
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
