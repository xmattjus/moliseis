import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../support/fake_image_picker.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';

void main() {
  _ContentSubmissionRouteHarness createHarness({
    FakeContentSubmissionDraftRepository? draftRepository,
  }) => _ContentSubmissionRouteHarness(
    draftRepository: draftRepository ?? FakeContentSubmissionDraftRepository(),
  );

  group('Content Submission production route exit', () {
    testWidgets('clean replacement exits without a dialog or draft write', (
      tester,
    ) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      await harness.pumpForm(tester);

      harness.router.go(RoutePaths.gallery);
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.gallery,
      );
      expect(find.text('Salva ed esci'), findsNothing);
      expect(harness.draftRepository.saveDraftCallCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dirty replacement shows cancelable three-choice policy', (
      tester,
    ) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      await harness.pumpForm(tester);
      harness.viewModel.setCity('Campobasso');
      await tester.pump();

      harness.router.go(RoutePaths.gallery);
      await tester.pump();

      expect(find.text('Salva ed esci'), findsOneWidget);
      expect(find.text('Esci senza salvare'), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.text('Suggerimento'), findsOneWidget);
      expect(harness.viewModel.hasUnsavedChanges, isTrue);
      expect(harness.draftRepository.saveDraftCallCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gated dirty checkpoint permits only its owner to exit', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository();
      final harness = createHarness(draftRepository: draftRepository);
      addTearDown(harness.dispose);
      await harness.pumpForm(tester);
      harness.viewModel.setCity('Campobasso');
      await tester.pump();

      final checkpoint = Completer<Result<void>>();
      draftRepository.pendingSaveDraft = checkpoint;
      harness.router.go(RoutePaths.gallery);
      await tester.pump();
      await tester.tap(find.text('Salva ed esci'));
      await tester.pump();
      expect(find.text('Salva ed esci'), findsNothing);
      expect(draftRepository.saveDraftCallCount, 1);
      checkpoint.complete(const Result.success(null));
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.gallery,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

final class _ContentSubmissionRouteHarness {
  _ContentSubmissionRouteHarness({required this.draftRepository}) {
    final syncUseCase = SyncUseCase(
      cityRepository: FakeCityRepository(),
      eventRepository: FakeEventRepository(),
      mediaRepository: FakeMediaRepository(),
      placeRepository: FakePlaceRepository(),
      settingsRepository: FakeSettingsRepository(lastSyncedAt: DateTime.now()),
      transactionCoordinator: FakeTransactionCoordinator(),
    );
    syncViewModel = SyncViewModel(syncUseCase: syncUseCase);
    auth = ControllableAdminAuth();
    viewModel = ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: ControllableSubmissionRepository(),
      draftRepository: draftRepository,
      stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
      imagePicker: FakeImagePicker(),
    );
    router = buildAppRouter(
      syncViewModel: syncViewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  final FakeContentSubmissionDraftRepository draftRepository;
  late final ControllableAdminAuth auth;
  late final GoRouter router;
  late final SyncViewModel syncViewModel;
  late final ContentSubmissionViewModel viewModel;

  Future<void> pumpForm(WidgetTester tester) async {
    router.go(RoutePaths.contentSubmission);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ContentSubmissionViewModel>.value(
            value: viewModel,
          ),
          Provider<UrlLaunchService>(
            create: (_) => UrlLaunchService(logger: MockLogger()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('it')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    router.dispose();
    auth.dispose();
    syncViewModel.dispose();
    viewModel.dispose();
  }
}
