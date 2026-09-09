import 'dart:async' show Completer, TimeoutException, unawaited;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
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
    required ContentSubmissionRepository submissionRepository,
    ContentSubmissionDraftRepository? draftRepository,
    FakeContentSubmissionStagedAssetRepository? stagedAssetRepository,
    ImagePicker? imagePicker,
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
        imagePicker: imagePicker ?? FakeImagePicker(),
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
      final draftRepository = FakeContentSubmissionDraftRepository();
      final vm = buildViewModel(
        submissionRepository: repo,
        draftRepository: draftRepository,
      );

      await tester.pumpWidget(buildProgressFirstApp(vm));

      unawaited(vm.submit.execute());
      unawaited(vm.submit.execute());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Invio in corso...'), findsOneWidget);
      expect(find.text('Torna alla home'), findsNothing);
      expect(find.text('Nuovo suggerimento'), findsNothing);
      expect(find.text('Riprova'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(vm.submit.running, isTrue);
      expect(repo.submitCallCount, 1);
      expect(draftRepository.clearDraftCallCount, 0);

      addTearDown(() => repo.completeSubmission(const Result.success(null)));
    });

    testWidgets('completed: shows success text and Nuovo suggerimento', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);

      await tester.pumpWidget(buildProgressFirstApp(vm));

      unawaited(vm.submit.execute());
      await tester.pump();

      repo.completeSubmission(const Result.success(null));
      await tester.pumpAndSettle();

      expect(find.byIcon(Symbols.check_circle), findsOneWidget);
      expect(find.textContaining('inviato con successo'), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsOneWidget);
      expect(find.text('Riprova'), findsNothing);
      expect(find.text('Torna alla home'), findsOneWidget);
      expect(vm.submit.completed, isTrue);
    });

    testWidgets('success UI waits for ViewModel-owned local finalization', (
      tester,
    ) async {
      final clearGate = Completer<Result<void>>();
      final repository = ControllableSubmissionRepository();
      final draftRepository = FakeContentSubmissionDraftRepository()
        ..pendingClearDraft = clearGate;
      final vm = buildViewModel(
        submissionRepository: repository,
        draftRepository: draftRepository,
      );
      final submittedIdentity = vm.state.clientSubmissionId;

      await tester.pumpWidget(buildProgressFirstApp(vm));
      unawaited(vm.submit.execute());
      await tester.pump();
      repository.completeSubmission(const Result.success(null));
      await tester.pump();
      await tester.pump();

      expect(vm.submit.running, isTrue);
      expect(vm.submissionFinalizationPending, isTrue);
      expect(draftRepository.clearDraftCallCount, 1);
      expect(vm.state.clientSubmissionId, submittedIdentity);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsNothing);

      clearGate.complete(const Result.success(null));
      await tester.pumpAndSettle();

      expect(vm.submit.completed, isTrue);
      expect(vm.submissionFinalizationPending, isFalse);
      expect(vm.state.clientSubmissionId, isNot(submittedIdentity));
      expect(find.text('Nuovo suggerimento'), findsOneWidget);
    });

    for (final failure in <({String name, Exception error})>[
      (name: 'validation', error: TestException('VALIDATION_ERROR')),
      (name: 'authentication', error: TestException('UNAUTHORIZED')),
      (name: 'method', error: TestException('METHOD_NOT_ALLOWED')),
      (name: 'rate limit', error: TestException('RATE_LIMIT_EXCEEDED')),
      (name: 'internal 500', error: TestException('INTERNAL_ERROR')),
      (
        name: 'final-submit transport',
        error: TimeoutException('submit-content timed out'),
      ),
      (
        name: 'malformed acknowledgement',
        error: const FormatException('invalid acknowledgement'),
      ),
      (name: 'unknown final-submit', error: TestException('UNKNOWN_CODE')),
      (
        name: 'preparation 502',
        error: TestException('CLOUDINARY_PREPARATION_ERROR'),
      ),
      (
        name: 'direct-upload terminal',
        error: TestException('direct upload exhausted'),
      ),
      (name: 'local', error: TestException('checkpoint failed')),
      (name: 'unknown', error: TestException('unknown failure')),
    ]) {
      testWidgets('${failure.name} error has safe recovery and no retry', (
        tester,
      ) async {
        final repository = FakeContentSubmissionRepository(
          submitResult: Result.error(failure.error),
        );
        final viewModel = buildViewModel(
          submissionRepository: repository,
        );

        await tester.pumpWidget(buildProgressFirstApp(viewModel));
        await viewModel.submit.execute();
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Symbols.error_circle_rounded_rounded),
          findsOneWidget,
        );
        expect(find.textContaining('problema durante'), findsOneWidget);
        expect(find.text('Riprova'), findsNothing);
        expect(find.text('Nuovo suggerimento'), findsNothing);
        expect(find.text('Torna alla home'), findsOneWidget);
        expect(find.text('Torna al modulo'), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(viewModel.submit.error, isTrue);
        expect(viewModel.canRetrySubmissionImmediately, isFalse);
        expect(repository.submitCallCount, 1);
      });
    }

    testWidgets(
      'finalization failure retries local retirement until it succeeds',
      (tester) async {
        final imagePicker = FakeImagePicker(
          onPickMultipleMedia: () async => <XFile>[
            XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]), name: 'a.jpg'),
          ],
        );
        final repository = FakeContentSubmissionRepository(
          uploadImageTaskResult: FakeImageUploadTask.completed(
            const Result.success(
              SubmissionAsset(
                secureUrl: 'https://assets.example/a.jpg',
                width: 1,
                height: 1,
              ),
            ),
          ),
        );
        final draftRepository = FakeContentSubmissionDraftRepository(
          clearDraftResult: Result.error(Exception('local clear failed')),
        );
        final stagedRepository = FakeContentSubmissionStagedAssetRepository();
        final viewModel = buildViewModel(
          submissionRepository: repository,
          draftRepository: draftRepository,
          stagedAssetRepository: stagedRepository,
          imagePicker: imagePicker,
        );
        await viewModel.addAsset.execute();
        final pendingIdentity = viewModel.state.clientSubmissionId;
        final pendingState = viewModel.state;
        await tester.pumpWidget(buildProgressFirstApp(viewModel));

        unawaited(viewModel.submit.execute());
        await tester.pumpAndSettle();

        expect(viewModel.submissionFinalizationPending, isTrue);
        expect(viewModel.canRetrySubmissionImmediately, isTrue);
        expect(find.textContaining('senza inviare di nuovo'), findsOneWidget);
        expect(find.text('Riprova'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(BackButton), findsNothing);
        expect(find.text('Torna alla home'), findsNothing);
        expect(find.text('Nuovo suggerimento'), findsNothing);
        expect(repository.submitCallCount, 1);
        expect(repository.uploadedImages, hasLength(1));
        expect(draftRepository.clearDraftCallCount, 1);
        expect(viewModel.state, pendingState);
        expect(viewModel.assets, hasLength(1));
        expect(stagedRepository.clearedSessions, isEmpty);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pump();
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await startPredictiveBack(tester);
        await commitPredictiveBack(tester, settle: false);
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;

        draftRepository.clearDraftResult = Result.error(
          Exception('second local clear failed'),
        );
        final retryClear = Completer<Result<void>>();
        draftRepository.pendingClearDraft = retryClear;
        await tester.tap(find.text('Riprova'));
        await tester.pump();

        expect(viewModel.submit.running, isTrue);
        expect(viewModel.canRetrySubmissionImmediately, isFalse);
        expect(find.text('Riprova'), findsNothing);
        expect(find.text('Torna alla home'), findsNothing);
        expect(find.byType(BackButton), findsNothing);
        expect(viewModel.state, pendingState);
        expect(viewModel.state.clientSubmissionId, pendingIdentity);
        expect(viewModel.assets, hasLength(1));

        retryClear.complete(draftRepository.clearDraftResult);
        await tester.pumpAndSettle();

        expect(repository.submitCallCount, 1);
        expect(repository.uploadedImages, hasLength(1));
        expect(draftRepository.clearDraftCallCount, 2);
        expect(viewModel.submissionFinalizationPending, isTrue);
        expect(viewModel.canRetrySubmissionImmediately, isTrue);
        expect(viewModel.state, pendingState);
        expect(viewModel.state.clientSubmissionId, pendingIdentity);
        expect(viewModel.assets, hasLength(1));
        expect(find.text('Riprova'), findsOneWidget);
        expect(stagedRepository.clearedSessions, isEmpty);

        draftRepository.clearDraftResult = const Result.success(null);
        await tester.tap(find.text('Riprova'));
        await tester.pumpAndSettle();

        expect(repository.submitCallCount, 1);
        expect(repository.uploadedImages, hasLength(1));
        expect(draftRepository.clearDraftCallCount, 3);
        expect(viewModel.submit.completed, isTrue);
        expect(viewModel.submissionFinalizationPending, isFalse);
        expect(viewModel.canRetrySubmissionImmediately, isFalse);
        expect(viewModel.state.clientSubmissionId, isNot(pendingIdentity));
        expect(viewModel.assets, isEmpty);
        expect(stagedRepository.clearedSessions, <String>[pendingIdentity]);
        expect(find.text('Nuovo suggerimento'), findsOneWidget);
      },
    );
  });

  group('ContentSubmissionProgressScreen navigation-only actions', () {
    testWidgets(
      'BackButton when completed reveals the already-finalized fresh form',
      (tester) async {
        final repo = ControllableSubmissionRepository(
          uploadImageTaskResult: FakeImageUploadTask.completed(
            const Result.success(
              SubmissionAsset(
                secureUrl: 'https://assets.example/a.jpg',
                width: 1,
                height: 1,
              ),
            ),
          ),
        );
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => <XFile>[
              XFile.fromData(
                Uint8List.fromList(<int>[1, 2, 3]),
                name: 'a.jpg',
              ),
            ],
          ),
        );
        await vm.addAsset.execute();
        final completedIdentity = vm.state.clientSubmissionId;
        expect(vm.assets, hasLength(1));

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
        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();

        final finalizedIdentity = vm.state.clientSubmissionId;
        expect(draftRepo.clearDraftCallCount, 1);
        expect(stagedRepo.clearedSessions, [completedIdentity]);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCallCount, 1);
        expect(stagedRepo.clearedSessions, [completedIdentity]);
        expect(vm.state.clientSubmissionId, finalizedIdentity);
        expect(vm.state.clientSubmissionId, isNot(completedIdentity));
        expect(vm.state.city, isNull);
        expect(vm.assets, isEmpty);
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
      'BackButton after remote failure preserves the same draft and staged '
      'session',
      (tester) async {
        final repo = ControllableSubmissionRepository(
          uploadImageTaskResult: FakeImageUploadTask.completed(
            const Result.success(
              SubmissionAsset(
                secureUrl: 'https://assets.example/a.jpg',
                width: 1,
                height: 1,
              ),
            ),
          ),
        );
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => <XFile>[
              XFile.fromData(
                Uint8List.fromList(<int>[1, 2, 3]),
                name: 'a.jpg',
              ),
            ],
          ),
        );
        await vm.addAsset.execute();
        final failedState = vm.state;
        final failedIdentity = vm.state.clientSubmissionId;

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        unawaited(vm.submit.execute());
        await tester.pump();
        repo.completeSubmission(Result.error(Exception('boom')));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // P2 intent: the error-path back returns to the previous screen
        // (the form) WITHOUT clearing state, so the user can edit and
        // retry. With the production-shaped harness the previous screen is
        // `_FormMarker`, not home.
        expect(draftRepo.clearDraftCalled, isFalse);
        expect(stagedRepo.clearedSessions, isEmpty);
        expect(vm.state, failedState);
        expect(vm.state.clientSubmissionId, failedIdentity);
        expect(vm.assets, hasLength(1));
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets(
      'Nuovo suggerimento reveals the already-finalized fresh form',
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
        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();

        final finalizedIdentity = vm.state.clientSubmissionId;
        expect(draftRepo.clearDraftCallCount, 1);
        expect(stagedRepo.clearedSessions, [completedIdentity]);

        await tester.tap(find.text('Nuovo suggerimento'));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCallCount, 1);
        expect(stagedRepo.clearedSessions, [completedIdentity]);
        expect(vm.state.clientSubmissionId, finalizedIdentity);
        expect(vm.state.clientSubmissionId, isNot(completedIdentity));
        expect(vm.state.city, isNull);
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
      'OS back when completed reveals the already-finalized fresh form',
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
        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();

        final finalizedIdentity = vm.state.clientSubmissionId;
        expect(draftRepo.clearDraftCallCount, 1);

        // Simulate the OS back gesture by dispatching it at the binding level,
        // which routes through `PopScope.onPopInvokedWithResult` rather than
        // the explicit AppBar chevron tap path.
        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(draftRepo.clearDraftCallCount, 1);
        expect(vm.state.clientSubmissionId, finalizedIdentity);
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
      repo.completeSubmission(Result.error(Exception('boom')));
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
        expect(repo.submitCallCount, 0);
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
        expect(repo.submitCallCount, 0);
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
        expect(repo.submitCallCount, 0);
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

      addTearDown(() => repo.completeSubmission(const Result.success(null)));
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
          expect(repo.submitCallCount, 0);
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

          addTearDown(
            () => repo.completeSubmission(const Result.success(null)),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'Torna al modulo after error pops once and performs no lifecycle work',
      (tester) async {
        final repo = FakeContentSubmissionRepository(
          submitResult: Result.error(TestException('ordinary failure')),
          uploadImageTaskResult: FakeImageUploadTask.completed(
            const Result.success(
              SubmissionAsset(
                secureUrl: 'https://assets.example/a.jpg',
                width: 1,
                height: 1,
              ),
            ),
          ),
        );
        final draftRepo = FakeContentSubmissionDraftRepository();
        final stagedRepo = FakeContentSubmissionStagedAssetRepository();
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: stagedRepo,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => <XFile>[
              XFile.fromData(
                Uint8List.fromList(<int>[1, 2, 3]),
                name: 'a.jpg',
              ),
            ],
          ),
        );
        await vm.addAsset.execute();

        final (router, app) = buildHomeFirstApp(vm);
        await tester.pumpWidget(app);
        await pushProgress(tester, router);
        await vm.submit.execute();
        await tester.pumpAndSettle();

        expect(repo.submitCallCount, 1);
        expect(repo.uploadedImages, hasLength(1));
        final failedIdentity = vm.state.clientSubmissionId;
        final failedState = vm.state;
        final saveCount = draftRepo.saveDraftCallCount;
        expect(vm.assets, hasLength(1));
        expect(find.text('Riprova'), findsNothing);
        expect(find.text('Torna al modulo'), findsOneWidget);

        await tester.tap(find.text('Torna al modulo'));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCalled, isFalse);
        expect(draftRepo.saveDraftCallCount, saveCount);
        expect(stagedRepo.clearedSessions, isEmpty);
        expect(repo.submitCallCount, 1);
        expect(repo.uploadedImages, hasLength(1));
        expect(vm.state, failedState);
        expect(vm.state.clientSubmissionId, failedIdentity);
        expect(vm.assets, hasLength(1));
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(_FormMarker), findsOneWidget);
        expect(find.byType(_HomeMarker), findsNothing);
      },
    );

    testWidgets('Torna alla home navigates without another finalization', (
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
      repo.completeSubmission(const Result.success(null));
      await tester.pumpAndSettle();

      final finalizedIdentity = vm.state.clientSubmissionId;
      expect(draftRepo.clearDraftCallCount, 1);
      expect(stagedRepo.clearedSessions, [completedIdentity]);

      await tester.tap(find.text('Torna alla home'));
      await tester.pumpAndSettle();

      expect(draftRepo.clearDraftCallCount, 1);
      expect(stagedRepo.clearedSessions, [completedIdentity]);
      expect(vm.state.clientSubmissionId, finalizedIdentity);
      expect(vm.state.clientSubmissionId, isNot(completedIdentity));
      expect(find.byType(_HomeMarker), findsOneWidget);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'repeated completed Home actions cannot retire the fresh session',
      (
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
        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();

        final finalizedIdentity = vm.state.clientSubmissionId;
        expect(draftRepo.clearDraftCallCount, 1);
        final home = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Torna alla home'),
        );
        home.onPressed!();
        home.onPressed!();
        await tester.pumpAndSettle();

        expect(find.byType(_HomeMarker), findsOneWidget);
        expect(draftRepo.clearDraftCallCount, 1);
        expect(vm.state.clientSubmissionId, finalizedIdentity);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'completed navigation does not rotate or clear the fresh session twice',
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
        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();

        final firstFinalizedIdentity = vm.state.clientSubmissionId;
        expect(draftRepo.clearDraftCallCount, 1);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCallCount, 1);
        expect(vm.state.clientSubmissionId, firstFinalizedIdentity);
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
        expect(repo.submitCallCount, 2);

        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();

        final secondFinalizedIdentity = vm.state.clientSubmissionId;
        expect(draftRepo.clearDraftCallCount, 2);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(draftRepo.clearDraftCallCount, 2);
        expect(vm.state.clientSubmissionId, secondFinalizedIdentity);
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
