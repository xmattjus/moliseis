import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../support/fake_image_picker.dart';
import '../support/fake_repositories.dart';
import '../support/mock_logger.dart';

void main() {
  group('content submission restoration', () {
    testWidgets(
      'restored idle progress returns to the form without retrying or clearing',
      (tester) async {
        final holder = _FixtureHolder();

        await tester.pumpWidget(_RestorableHarness(holder: holder));
        await tester.pumpAndSettle();
        final before = holder.fixture!;

        unawaited(before.router.pushNamed(RouteNames.contentSubmission));
        await tester.pumpAndSettle();

        // Mirror production: submit begins before the progress route is pushed.
        unawaited(before.viewModel.submit.execute());
        unawaited(
          before.router.pushNamed(RouteNames.contentSubmissionUploadProgress),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(before.viewModel.submit.running, isTrue);
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

        // Keep the old request pending through process death. The new fixture
        // receives a fresh view model, exactly as production does.
        addTearDown(
          () => before.submissionRepository.completeUpload(
            const Result.success(null),
          ),
        );

        await tester.restartAndRestore();
        await tester.pumpAndSettle();

        final after = holder.fixture!;
        expect(after, isNot(same(before)));
        expect(after.viewModel, isNot(same(before.viewModel)));
        expect(after.viewModel.submit.idle, isTrue);
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        expect(find.byIcon(Symbols.upload), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Torna al modulo'), findsOneWidget);
        expect(after.submissionRepository.uploadCallCount, 0);

        await tester.tap(find.text('Torna al modulo'));
        await tester.pumpAndSettle();

        expect(holder.draftRepository.clearDraftCalled, isFalse);
        expect(after.submissionRepository.uploadCallCount, 0);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(_FormMarker), findsOneWidget);

        // The recovery exit performs one pop only; no duplicate form is left.
        after.router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(_FormMarker), findsNothing);
        expect(find.byType(_HomeMarker), findsOneWidget);
      },
    );
  });
}

final class _FixtureHolder {
  _FixtureHolder()
    : draftRepository = FakeContentSubmissionDraftRepository(
        loadDraftResult: Result.success(
          ContentSubmissionDraft(
            city: 'Campobasso',
            name: 'Test event',
            userEmail: 'test@example.com',
            userName: 'Test User',
          ),
        ),
      );

  final FakeContentSubmissionDraftRepository draftRepository;
  _RestorationFixture? fixture;
}

final class _RestorationFixture {
  _RestorationFixture({required this.draftRepository}) {
    submissionRepository = ControllableSubmissionRepository();
    viewModel = ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: submissionRepository,
      draftRepository: draftRepository,
      stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
      imagePicker: FakeImagePicker(),
    );
    unawaited(viewModel.initialize());
    router = GoRouter(
      initialLocation: RoutePaths.home,
      restorationScopeId: 'router',
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (_, _) => const _HomeMarker(),
        ),
        GoRoute(
          path: RoutePaths.contentSubmission,
          name: RouteNames.contentSubmission,
          builder: (_, _) => const _FormMarker(),
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.contentSubmissionUploadProgress,
              name: RouteNames.contentSubmissionUploadProgress,
              builder: (_, _) =>
                  ContentSubmissionProgressScreen(viewModel: viewModel),
            ),
          ],
        ),
      ],
    );
  }

  final FakeContentSubmissionDraftRepository draftRepository;
  late final ControllableSubmissionRepository submissionRepository;
  late final ContentSubmissionViewModel viewModel;
  late final GoRouter router;

  Widget get app => MaterialApp.router(
    restorationScopeId: 'app',
    routerConfig: router,
  );

  void dispose() {
    router.dispose();
    viewModel.dispose();
  }
}

class _RestorableHarness extends StatefulWidget {
  const _RestorableHarness({required this.holder});

  final _FixtureHolder holder;

  @override
  State<_RestorableHarness> createState() => _RestorableHarnessState();
}

class _RestorableHarnessState extends State<_RestorableHarness> {
  late final _RestorationFixture fixture = _RestorationFixture(
    draftRepository: widget.holder.draftRepository,
  );

  @override
  void initState() {
    super.initState();
    widget.holder.fixture = fixture;
  }

  @override
  void dispose() {
    fixture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => fixture.app;
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
