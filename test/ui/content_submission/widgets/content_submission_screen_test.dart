import 'dart:async' show Completer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_description_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_external_url_service.dart';
import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  ContentSubmissionViewModel buildViewModel({
    required ControllableSubmissionRepository submissionRepository,
    ContentSubmissionDraftRepository? draftRepository,
    FakeImagePicker? imagePicker,
  }) {
    return ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: submissionRepository,
      draftRepository:
          draftRepository ?? FakeContentSubmissionDraftRepository(),
      stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    );
  }

  // The screen hosts several nested Scrollables (the main CustomScrollView
  // plus the horizontal asset ListView). Picking the first one in widget
  // order is brittle: it depends on traversal order staying stable across
  // Flutter versions and on no other Scrollable being inserted ahead of the
  // main scroll view. Anchor the finder to the explicitly-keyed
  // CustomScrollView, then resolve the Scrollable it builds internally via
  // `find.descendant`. The key keeps the lookup stable even if the widget
  // subtree is restructured.
  final mainScrollable = find
      .descendant(
        of: find.byKey(const ValueKey('content_submission_scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  /// Scrolls the main scrollable until the [TextFormField] labelled with
  /// [labelText] is visible, then enters [value] into it.
  Future<void> enterLabeledField(
    WidgetTester tester,
    String labelText,
    String value,
  ) async {
    final field = find.widgetWithText(TextFormField, labelText);
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: mainScrollable,
    );
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: mainScrollable);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> tapLegalLink(WidgetTester tester, String label) =>
      scrollToAndTap(tester, find.text(label));

  Finder formBoundaryAbsorber() => find
      .ancestor(
        of: find.byKey(const ValueKey('content_submission_scroll')),
        matching: find.byType(AbsorbPointer),
      )
      .first;

  Widget buildApp(
    ContentSubmissionViewModel viewModel, {
    UrlLaunchService? urlLaunchService,
    Object? Function()? acquireTransition,
    void Function(Object token)? releaseTransition,
    String initialLocation = '/submission',
    void Function(GoRouter router)? onRouterCreated,
  }) {
    Object? transitionOwner;
    Object? defaultAcquireTransition() {
      if (transitionOwner != null) return null;
      return transitionOwner = Object();
    }

    void defaultReleaseTransition(Object token) {
      if (identical(transitionOwner, token)) transitionOwner = null;
    }

    final resolvedAcquireTransition =
        acquireTransition ?? defaultAcquireTransition;
    final resolvedReleaseTransition =
        releaseTransition ?? defaultReleaseTransition;

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
        ),
        GoRoute(
          path: '/submission',
          name: RouteNames.contentSubmission,
          builder: (_, _) => ContentSubmissionScreen(
            viewModel: viewModel,
            acquireTransition: resolvedAcquireTransition,
            releaseTransition: resolvedReleaseTransition,
          ),
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
    onRouterCreated?.call(router);
    return Provider<UrlLaunchService>.value(
      value: urlLaunchService ?? UrlLaunchService(logger: MockLogger()),
      child: MaterialApp.router(
        scaffoldMessengerKey: $scaffoldMessengerKey,
        routerConfig: router,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          FlutterQuillLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('it')],
      ),
    );
  }

  /// Enters text into all required form fields and accepts the terms checkbox
  /// so both forms validate.
  Future<void> fillValidForm(WidgetTester tester) async {
    await enterLabeledField(tester, 'Città', 'Campobasso');
    await enterLabeledField(tester, 'Luogo o evento', 'Test Event');
    await enterLabeledField(tester, 'E-mail', 'test@example.com');
    await enterLabeledField(tester, 'Autore', 'Test User');

    final termsCheckbox = find.descendant(
      of: find.byType(CheckboxFormField),
      matching: find.byType(Checkbox),
    );
    await scrollToAndTap(tester, termsCheckbox);
  }

  group('ContentSubmissionScreen Invia button', () {
    testWidgets('with invalid form does not navigate and does not submit', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));

      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );

      expect(repo.submitCallCount, 0);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);
      expect(vm.submit.running, isFalse);
      expect(vm.submit.result, isNull);
    });

    testWidgets('with valid form fires submit and navigates to progress', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await fillValidForm(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );
      await tester.pump();

      expect(
        vm.submit.running,
        isTrue,
        reason: 'submit.execute() must run before navigation',
      );
      expect(repo.submitCallCount, 1);
      expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
      expect(find.text('Invio in corso...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      addTearDown(() => repo.completeSubmission(const Result.success(null)));
    });

    testWidgets(
      'with an incomplete event shows the date issue and does not navigate',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = ControllableSubmissionRepository();
        final vm = buildViewModel(submissionRepository: repo);
        addTearDown(vm.dispose);
        await vm.initialize();

        await tester.pumpWidget(buildApp(vm));
        await fillValidForm(tester);
        vm.setEventEnabled(true);
        await tester.pump();

        final submitButton = find.widgetWithText(FilledButton, 'Invia');
        await tester.scrollUntilVisible(
          submitButton,
          200,
          scrollable: mainScrollable,
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Seleziona una data di inizio.'),
          -200,
          scrollable: mainScrollable,
        );

        expect(find.text('Seleziona una data di inizio.'), findsOneWidget);
        expect(vm.eventTimeIssue, EventTimeIssue.missingStartDate);
        expect(repo.submitCallCount, 0);
        expect(vm.submit.result, isNull);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      },
    );

    testWidgets('completes the upload pipeline on success', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await fillValidForm(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );
      await tester.pump();

      expect(repo.submitCallCount, 1);
      repo.completeSubmission(const Result.success(null));
      await tester.pumpAndSettle();

      expect(vm.submit.completed, isTrue);
      expect(find.text('Nuovo suggerimento'), findsOneWidget);
    });

    testWidgets('renders the error path on upload failure', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await fillValidForm(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );
      await tester.pump();

      repo.completeSubmission(Result.error(Exception('boom')));
      await tester.pumpAndSettle();

      expect(vm.submit.error, isTrue);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsNothing);
    });

    testWidgets(
      'unmounting during a submit checkpoint releases without continuing',
      (tester) async {
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final repository = ControllableSubmissionRepository();
        final viewModel = buildViewModel(
          submissionRepository: repository,
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        final token = Object();
        final released = <Object>[];

        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => token,
            releaseTransition: released.add,
          ),
        );
        await fillValidForm(tester);
        await scrollToAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Invia'),
        );
        expect(draftRepository.saveDraftCallCount, 1);

        await tester.pumpWidget(const SizedBox());
        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(released, [token]);
        expect(repository.submitCallCount, 0);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('invalid first form acquires no submit transition work', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository();
      final repository = ControllableSubmissionRepository();
      final viewModel = buildViewModel(
        submissionRepository: repository,
        draftRepository: draftRepository,
      );
      await viewModel.initialize();
      var acquisitions = 0;

      await tester.pumpWidget(
        buildApp(
          viewModel,
          acquireTransition: () {
            acquisitions++;
            return Object();
          },
        ),
      );
      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );

      expect(acquisitions, 0);
      expect(draftRepository.saveDraftCallCount, 0);
      expect(repository.submitCallCount, 0);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
    });

    testWidgets('invalid second form acquires no submit transition work', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository();
      final repository = ControllableSubmissionRepository();
      final viewModel = buildViewModel(
        submissionRepository: repository,
        draftRepository: draftRepository,
      );
      await viewModel.initialize();
      var acquisitions = 0;

      await tester.pumpWidget(
        buildApp(
          viewModel,
          acquireTransition: () {
            acquisitions++;
            return Object();
          },
        ),
      );
      await fillValidForm(tester);
      final termsCheckbox = find.descendant(
        of: find.byType(CheckboxFormField),
        matching: find.byType(Checkbox),
      );
      await scrollToAndTap(tester, termsCheckbox);
      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );

      expect(acquisitions, 0);
      expect(draftRepository.saveDraftCallCount, 0);
      expect(repository.submitCallCount, 0);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
    });

    testWidgets('invalid event time acquires no submit transition work', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository();
      final repository = ControllableSubmissionRepository();
      final viewModel = buildViewModel(
        submissionRepository: repository,
        draftRepository: draftRepository,
      );
      await viewModel.initialize();
      var acquisitions = 0;

      await tester.pumpWidget(
        buildApp(
          viewModel,
          acquireTransition: () {
            acquisitions++;
            return Object();
          },
        ),
      );
      await fillValidForm(tester);
      viewModel.setEventEnabled(true);
      await tester.pump();
      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );

      expect(acquisitions, 0);
      expect(draftRepository.saveDraftCallCount, 0);
      expect(repository.submitCallCount, 0);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
    });

    testWidgets('denied submit ownership starts no lifecycle work', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository();
      final repository = ControllableSubmissionRepository();
      final viewModel = buildViewModel(
        submissionRepository: repository,
        draftRepository: draftRepository,
      );
      await viewModel.initialize();

      await tester.pumpWidget(
        buildApp(viewModel, acquireTransition: () => null),
      );
      await fillValidForm(tester);
      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );

      expect(draftRepository.saveDraftCallCount, 0);
      expect(repository.submitCallCount, 0);
      expect(viewModel.submit.result, isNull);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
    });

    testWidgets(
      'submit checkpoint is single-flight through the synchronous push handoff',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final repository = ControllableSubmissionRepository();
        addTearDown(
          () => repository.completeSubmission(Result.error(Exception())),
        );
        final viewModel = buildViewModel(
          submissionRepository: repository,
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        var acquisitions = 0;
        final token = Object();
        final released = <Object>[];
        bool? absorbedWhenReleased;

        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => ++acquisitions == 1 ? token : null,
            releaseTransition: (releasedToken) {
              absorbedWhenReleased = tester
                  .widget<AbsorbPointer>(formBoundaryAbsorber())
                  .absorbing;
              released.add(releasedToken);
            },
          ),
        );
        await fillValidForm(tester);
        final submit = find.widgetWithText(FilledButton, 'Invia');
        await tester.tap(submit);
        await tester.pump();

        expect(acquisitions, 1);
        expect(draftRepository.saveDraftCallCount, 1);
        expect(repository.submitCallCount, 0);
        expect(
          tester.widget<AbsorbPointer>(formBoundaryAbsorber()).absorbing,
          isTrue,
        );

        final city = find.widgetWithText(TextFormField, 'Campobasso');
        await tester.tap(city, warnIfMissed: false);
        tester.testTextInput.enterText('Isernia');
        await tester.tap(submit, warnIfMissed: false);
        await tester.pump();

        expect(viewModel.state.city, 'Campobasso');
        expect(acquisitions, 1);
        expect(draftRepository.saveDraftCallCount, 1);

        checkpoint.complete(const Result.success(null));
        await tester.pump();
        await tester.pump();

        expect(repository.submitCallCount, 1);
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        expect(released, [token]);
        expect(absorbedWhenReleased, isTrue);
        expect(
          tester.widget<AbsorbPointer>(formBoundaryAbsorber()).absorbing,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('submit checkpoint failure preserves editable work', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository(
        saveDraftResult: Result.error(Exception('checkpoint failed')),
      );
      final repository = ControllableSubmissionRepository();
      final viewModel = buildViewModel(
        submissionRepository: repository,
        draftRepository: draftRepository,
      );
      await viewModel.initialize();
      final token = Object();
      final released = <Object>[];

      await tester.pumpWidget(
        buildApp(
          viewModel,
          acquireTransition: () => token,
          releaseTransition: released.add,
        ),
      );
      await fillValidForm(tester);
      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );
      await tester.pump();

      expect(draftRepository.saveDraftCallCount, 1);
      expect(repository.submitCallCount, 0);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      expect(released, [token]);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );

      await enterLabeledField(tester, 'Città', 'Isernia');
      expect(viewModel.state.city, 'Isernia');
      expect(
        tester.widget<AbsorbPointer>(formBoundaryAbsorber()).absorbing,
        isFalse,
      );
    });
  });

  group('ContentSubmissionScreen dirty iOS gesture guard', () {
    testWidgets('derives the status and pop disposition from dirty state', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final vm = buildViewModel(
        submissionRepository: ControllableSubmissionRepository(),
      );
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await tester.pump();
      await tester.pump();
      final cleanExtent = tester
          .renderObject<RenderSliver>(
            find.byType(SliverAppBar, skipOffstage: false),
          )
          .geometry!
          .scrollExtent;
      expect(find.text('Modifiche non salvate'), findsNothing);
      expect(
        tester
            .widget<PopScope<dynamic>>(
              find.byWidgetPredicate(
                (widget) => widget is PopScope,
                skipOffstage: false,
              ),
            )
            .canPop,
        isTrue,
      );

      vm.setCity('Campobasso');
      await tester.pump();

      expect(find.text('Modifiche non salvate'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Modifiche non salvate',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '●',
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<PopScope<dynamic>>(
              find.byWidgetPredicate(
                (widget) => widget is PopScope,
                skipOffstage: false,
              ),
            )
            .canPop,
        isFalse,
      );
      expect(
        tester
            .renderObject<RenderSliver>(
              find.byType(SliverAppBar, skipOffstage: false),
            )
            .geometry!
            .scrollExtent,
        cleanExtent,
      );

      await vm.checkpointDraft();
      await tester.pump();

      expect(find.text('Modifiche non salvate'), findsNothing);
      expect(
        tester
            .widget<PopScope<dynamic>>(
              find.byWidgetPredicate(
                (widget) => widget is PopScope,
                skipOffstage: false,
              ),
            )
            .canPop,
        isTrue,
      );
      expect(
        tester
            .renderObject<RenderSliver>(
              find.byType(SliverAppBar, skipOffstage: false),
            )
            .geometry!
            .scrollExtent,
        cleanExtent,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'blocks native pop while a checkpointed external boundary is pending',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final draftRepository = FakeContentSubmissionDraftRepository();
        final launchGate = Completer<Result<void>>();
        final externalUrlService = FakeExternalUrlService(logger: MockLogger())
          ..pendingLaunch = launchGate;
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');

        await tester.pumpWidget(
          buildApp(
            viewModel,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Termini di Servizio'),
          200,
          scrollable: mainScrollable,
        );
        final terms = find.text('Termini di Servizio');
        await tester.ensureVisible(terms);
        await tester.tap(terms);
        await tester.pump();

        expect(viewModel.hasUnsavedChanges, isFalse);
        expect(externalUrlService.launchedUrls, hasLength(1));
        expect(
          tester
              .widget<PopScope<dynamic>>(
                find.byWidgetPredicate(
                  (widget) => widget is PopScope,
                  skipOffstage: false,
                ),
              )
              .canPop,
          isFalse,
        );

        launchGate.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<PopScope<dynamic>>(
                find.byWidgetPredicate(
                  (widget) => widget is PopScope,
                  skipOffstage: false,
                ),
              )
              .canPop,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  group('ContentSubmissionScreen external boundaries', () {
    const legalLinks = <String>[
      'Termini di Servizio',
      'Informativa sulla privacy',
    ];

    for (final label in legalLinks) {
      testWidgets(
        '$label checkpoints dirty work before launching and releases ownership',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final checkpoint = Completer<Result<void>>();
          final draftRepository = FakeContentSubmissionDraftRepository()
            ..pendingSaveDraft = checkpoint;
          final externalUrlService = FakeExternalUrlService(
            logger: MockLogger(),
          );
          final viewModel = buildViewModel(
            submissionRepository: ControllableSubmissionRepository(),
            draftRepository: draftRepository,
          );
          await viewModel.initialize();
          viewModel.setCity('Campobasso');
          Object? owner;
          final released = <Object>[];

          await tester.pumpWidget(
            buildApp(
              viewModel,
              acquireTransition: () {
                if (owner != null) return null;
                return owner = Object();
              },
              releaseTransition: (token) {
                released.add(token);
                if (identical(owner, token)) owner = null;
              },
              urlLaunchService: UrlLaunchService(
                logger: MockLogger(),
                externalUrlService: externalUrlService,
              ),
            ),
          );

          await tapLegalLink(tester, label);

          expect(draftRepository.saveDraftCallCount, 1);
          expect(externalUrlService.launchedUrls, isEmpty);
          expect(owner, isNotNull);

          checkpoint.complete(const Result.success(null));
          await tester.pumpAndSettle();

          expect(externalUrlService.launchedUrls, hasLength(1));
          expect(viewModel.hasUnsavedChanges, isFalse);
          expect(released, hasLength(1));
          expect(owner, isNull);
        },
      );

      testWidgets(
        '$label checkpoint failure preserves work and blocks launch',
        (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(800, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final draftRepository = FakeContentSubmissionDraftRepository(
            saveDraftResult: Result.error(Exception('checkpoint failed')),
          );
          final externalUrlService = FakeExternalUrlService(
            logger: MockLogger(),
          );
          final viewModel = buildViewModel(
            submissionRepository: ControllableSubmissionRepository(),
            draftRepository: draftRepository,
          );
          await viewModel.initialize();
          viewModel.setCity('Campobasso');
          Object? owner;
          final released = <Object>[];

          await tester.pumpWidget(
            buildApp(
              viewModel,
              acquireTransition: () {
                if (owner != null) return null;
                return owner = Object();
              },
              releaseTransition: (token) {
                released.add(token);
                if (identical(owner, token)) owner = null;
              },
              urlLaunchService: UrlLaunchService(
                logger: MockLogger(),
                externalUrlService: externalUrlService,
              ),
            ),
          );

          await tapLegalLink(tester, label);
          await tester.pump();

          expect(draftRepository.saveDraftCallCount, 1);
          expect(externalUrlService.launchedUrls, isEmpty);
          expect(viewModel.hasUnsavedChanges, isTrue);
          expect(released, hasLength(1));
          expect(owner, isNull);
          expect(
            find.text('Si è verificato un errore, riprova più tardi'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '$label launcher failure releases ownership and shows feedback',
        (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(800, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final draftRepository = FakeContentSubmissionDraftRepository();
          final externalUrlService = FakeExternalUrlService(
            logger: MockLogger(),
          )..result = Result.error(Exception('launcher failed'));
          final viewModel = buildViewModel(
            submissionRepository: ControllableSubmissionRepository(),
            draftRepository: draftRepository,
          );
          await viewModel.initialize();
          viewModel.setCity('Campobasso');
          Object? owner;
          final released = <Object>[];

          await tester.pumpWidget(
            buildApp(
              viewModel,
              acquireTransition: () {
                if (owner != null) return null;
                return owner = Object();
              },
              releaseTransition: (token) {
                released.add(token);
                if (identical(owner, token)) owner = null;
              },
              urlLaunchService: UrlLaunchService(
                logger: MockLogger(),
                externalUrlService: externalUrlService,
              ),
            ),
          );

          await tapLegalLink(tester, label);
          await tester.pump();

          expect(draftRepository.saveDraftCallCount, 1);
          expect(externalUrlService.launchedUrls, hasLength(1));
          expect(released, hasLength(1));
          expect(owner, isNull);
          expect(
            find.text('Si è verificato un errore, riprova più tardi'),
            findsOneWidget,
          );
        },
      );
    }

    for (final label in legalLinks) {
      testWidgets('$label clean launch avoids an empty draft checkpoint', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final draftRepository = FakeContentSubmissionDraftRepository();
        final externalUrlService = FakeExternalUrlService(logger: MockLogger());
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        await tester.pumpWidget(
          buildApp(
            viewModel,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );

        await tapLegalLink(tester, label);
        await tester.pumpAndSettle();

        expect(draftRepository.saveDraftCallCount, 0);
        expect(externalUrlService.launchedUrls, hasLength(1));
      });

      testWidgets('$label denied ownership starts no checkpoint or launch', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final draftRepository = FakeContentSubmissionDraftRepository();
        final externalUrlService = FakeExternalUrlService(logger: MockLogger());
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');
        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => null,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );

        await tapLegalLink(tester, label);

        expect(draftRepository.saveDraftCallCount, 0);
        expect(externalUrlService.launchedUrls, isEmpty);
        expect(viewModel.hasUnsavedChanges, isTrue);
      });
    }

    testWidgets(
      'rapid repeated legal-link taps are single-flight while gated',
      (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final externalUrlService = FakeExternalUrlService(logger: MockLogger());
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');
        var acquireCount = 0;
        final token = Object();

        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => ++acquireCount == 1 ? token : null,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );

        await tapLegalLink(tester, 'Termini di Servizio');
        await tester.tap(
          find.text('Termini di Servizio'),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(acquireCount, 1);
        expect(draftRepository.saveDraftCallCount, 1);
        expect(externalUrlService.launchedUrls, isEmpty);

        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(externalUrlService.launchedUrls, hasLength(1));
      },
    );

    testWidgets(
      'gated boundary absorbs form, asset, and AppBar pointer input',
      (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final imagePicker = FakeImagePicker();
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
          imagePicker: imagePicker,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');

        GoRouter? router;
        await tester.pumpWidget(
          buildApp(
            viewModel,
            initialLocation: '/home',
            onRouterCreated: (value) => router = value,
          ),
        );
        unawaited(router!.pushNamed<void>(RouteNames.contentSubmission));
        await tester.pumpAndSettle();
        await tapLegalLink(tester, 'Termini di Servizio');

        final cityField = find.widgetWithText(TextFormField, 'Campobasso');
        await tester.scrollUntilVisible(
          cityField,
          200,
          scrollable: mainScrollable,
        );
        await tester.tap(cityField, warnIfMissed: false);
        tester.testTextInput.enterText('Isernia');
        await tester.pump();
        expect(viewModel.state.city, 'Campobasso');

        final addAsset = find.byKey(
          const ValueKey('content-submission-asset-list-add-button'),
        );
        await tester.scrollUntilVisible(
          addAsset,
          200,
          scrollable: mainScrollable,
        );
        await tester.tap(addAsset, warnIfMissed: false);
        await tester.pump();
        expect(imagePicker.pickMultipleMediaLimits, isEmpty);

        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton), warnIfMissed: false);
        await tester.pump();
        expect(draftRepository.saveDraftCallCount, 1);
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);

        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'rapid repeated Privacy taps are single-flight while gated',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final externalUrlService = FakeExternalUrlService(logger: MockLogger());
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');
        var acquireCount = 0;
        final token = Object();

        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => ++acquireCount == 1 ? token : null,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );

        await tapLegalLink(tester, 'Informativa sulla privacy');
        await tester.tap(
          find.text('Informativa sulla privacy'),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(acquireCount, 1);
        expect(draftRepository.saveDraftCallCount, 1);
        expect(externalUrlService.launchedUrls, isEmpty);

        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(externalUrlService.launchedUrls, hasLength(1));
      },
    );

    testWidgets(
      'unmounting during a checkpoint releases without a late launch',
      (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final externalUrlService = FakeExternalUrlService(logger: MockLogger());
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');
        final token = Object();
        final released = <Object>[];

        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => token,
            releaseTransition: released.add,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );
        await tapLegalLink(tester, 'Termini di Servizio');

        await tester.pumpWidget(const SizedBox());
        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(released, [token]);
        expect(externalUrlService.launchedUrls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'unmounting during a Privacy checkpoint releases without a late launch',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final externalUrlService = FakeExternalUrlService(logger: MockLogger());
        final viewModel = buildViewModel(
          submissionRepository: ControllableSubmissionRepository(),
          draftRepository: draftRepository,
        );
        await viewModel.initialize();
        viewModel.setCity('Campobasso');
        final token = Object();
        final released = <Object>[];

        await tester.pumpWidget(
          buildApp(
            viewModel,
            acquireTransition: () => token,
            releaseTransition: released.add,
            urlLaunchService: UrlLaunchService(
              logger: MockLogger(),
              externalUrlService: externalUrlService,
            ),
          ),
        );
        await tapLegalLink(tester, 'Informativa sulla privacy');

        await tester.pumpWidget(const SizedBox());
        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(released, [token]);
        expect(externalUrlService.launchedUrls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ContentSubmissionScreen asset picker boundary', () {
    testWidgets('actual add-asset action uses only the ViewModel checkpoint', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final checkpoint = Completer<Result<void>>();
      final draftRepository = FakeContentSubmissionDraftRepository()
        ..pendingSaveDraft = checkpoint;
      final imagePicker = FakeImagePicker();
      final viewModel = buildViewModel(
        submissionRepository: ControllableSubmissionRepository(),
        draftRepository: draftRepository,
        imagePicker: imagePicker,
      );
      await viewModel.initialize();
      viewModel.setCity('Campobasso');
      var routeTokenAcquisitions = 0;

      await tester.pumpWidget(
        buildApp(
          viewModel,
          acquireTransition: () {
            routeTokenAcquisitions++;
            return Object();
          },
        ),
      );

      final addAsset = find.byKey(
        const ValueKey('content-submission-asset-list-add-button'),
      );
      await tester.scrollUntilVisible(
        addAsset,
        200,
        scrollable: mainScrollable,
      );
      await tester.tap(addAsset);
      await tester.pump();

      expect(
        draftRepository.saveDraftCallCount,
        1,
        reason: 'the existing ViewModel flow owns the pre-picker checkpoint',
      );
      expect(imagePicker.pickMultipleMediaLimits, isEmpty);
      expect(routeTokenAcquisitions, 0);

      checkpoint.complete(const Result.success(null));
      await tester.pumpAndSettle();

      expect(imagePicker.pickMultipleMediaLimits, hasLength(1));
      expect(viewModel.assets, isEmpty);
      expect(routeTokenAcquisitions, 0);
    });
  });

  testWidgets('restored incomplete event draft controls the checkbox', (
    tester,
  ) async {
    final repo = ControllableSubmissionRepository();
    final vm = buildViewModel(
      submissionRepository: repo,
      draftRepository: FakeContentSubmissionDraftRepository(
        loadDraftResult: Result.success(
          ContentSubmissionDraft(
            eventDates: EventDateDraft.unresolvedStart(
              EventCalendarDate(2026, 8, 20),
            ),
          ),
        ),
      ),
    );
    addTearDown(vm.dispose);

    await tester.pumpWidget(buildApp(vm));
    await vm.initialize();
    await tester.pump();

    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(find.textContaining('Inizia il'), findsOneWidget);
  });

  group('ContentSubmissionScreen back navigation', () {
    testWidgets(
      'completed back pops once and leaves a clean form',
      (tester) async {
        final repo = ControllableSubmissionRepository();
        final vm = buildViewModel(submissionRepository: repo);
        await vm.initialize();

        await tester.pumpWidget(buildApp(vm));
        await fillValidForm(tester);

        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, 'Invia'),
          200,
          scrollable: mainScrollable,
        );
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Invia'),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
        await tester.pump();

        repo.completeSubmission(const Result.success(null));
        await tester.pumpAndSettle();
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);

        // The completed pop cleared the in-memory state and reset the form.
        expect(vm.state.city, isEmpty);
        expect(vm.state.name, isEmpty);
        expect(find.widgetWithText(TextFormField, 'Campobasso'), findsNothing);
        expect(find.widgetWithText(TextFormField, 'Test Event'), findsNothing);

        // The controlled event state remains disabled after the clear.
        final eventCheckbox = find.descendant(
          of: find
              .ancestor(
                of: find.text('È un evento?'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byType(Checkbox),
        );
        await tester.scrollUntilVisible(
          find.text('È un evento?'),
          -200,
          scrollable: mainScrollable,
        );
        expect(tester.widget<Checkbox>(eventCheckbox).value, isFalse);

        await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, 'E-mail'),
          200,
          scrollable: mainScrollable,
        );
        expect(
          find.widgetWithText(TextFormField, 'test@example.com'),
          findsNothing,
        );

        await tester.scrollUntilVisible(
          find.byType(CheckboxFormField),
          200,
          scrollable: mainScrollable,
        );
        final termsCheckbox = tester.widget<Checkbox>(
          find.descendant(
            of: find.byType(CheckboxFormField),
            matching: find.byType(Checkbox),
          ),
        );
        expect(termsCheckbox.value, isFalse);
      },
    );

    testWidgets(
      'completed submission blocks progress exit while local clear is pending',
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
        final clearGate = Completer<Result<void>>();
        final asset = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final draftRepo = FakeContentSubmissionDraftRepository()
          ..pendingClearDraft = clearGate;
        final vm = buildViewModel(
          submissionRepository: repo,
          draftRepository: draftRepo,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [asset],
          ),
        );
        await vm.initialize();
        await vm.addAsset.execute();

        await tester.pumpWidget(buildApp(vm));
        await fillValidForm(tester);
        await scrollToAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Invia'),
        );
        await tester.pump();

        repo.completeSubmission(const Result.success(null));
        while (draftRepo.clearDraftCallCount == 0) {
          await tester.pump();
        }
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        final previousState = vm.state;
        final previousIdentity = vm.state.clientSubmissionId;
        final previousAsset = vm.assets.single;
        expect(vm.hasUnsavedChanges, isFalse);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pump();

        expect(vm.submit.running, isTrue);
        expect(vm.clear.idle, isTrue);
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        expect(vm.state, previousState);
        expect(vm.state.clientSubmissionId, previousIdentity);
        expect(vm.assets, [previousAsset]);
        expect(vm.hasUnsavedChanges, isFalse);

        clearGate.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(vm.submit.completed, isTrue);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);
        expect(vm.state.city, isEmpty);
        expect(vm.assets, isEmpty);
        expect(find.text('Campobasso'), findsNothing);
      },
    );

    testWidgets('error back pops once and preserves the form data', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await fillValidForm(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(FilledButton, 'Invia'),
      );
      await tester.pump();

      repo.completeSubmission(Result.error(Exception('boom')));
      await tester.pumpAndSettle();
      expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);

      // No clear ran, so the editable draft retains the submitted values.
      expect(vm.state.city, 'Campobasso');
      expect(vm.state.name, 'Test Event');
      expect(vm.state.userEmail, 'test@example.com');
      expect(vm.state.userName, 'Test User');

      // The preserved form still shows the entered text on screen.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Città'),
        -200,
        scrollable: mainScrollable,
      );
      expect(find.widgetWithText(TextFormField, 'Campobasso'), findsOneWidget);
    });
  });

  group('ContentSubmissionScreen persisted draft binding', () {
    testWidgets(
      'binds the loaded draft values to the form fields on first build',
      (tester) async {
        final draftRepo = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.success(
            ContentSubmissionDraft(
              city: 'Isernia',
              name: 'Test',
              description: 'Descrizione di test',
              userName: 'Mario',
              userEmail: 'm@e.com',
              acceptedTerms: true,
            ),
          ),
        );
        final repo = ControllableSubmissionRepository();
        final vm = ContentSubmissionViewModel(
          logger: MockLogger(),
          contentSubmissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
          imagePicker: FakeImagePicker(),
        );
        // The screen gates its body on
        // `loadState == ContentSubmissionDraftLoadState.ready`, so the draft
        // must be loaded before pumping or the form fields are never built.
        await vm.initialize();

        await tester.pumpWidget(buildApp(vm));

        // The standard form fields retain their initial values while the
        // description field reconstructs its owned Quill document from the
        // loaded legacy draft text.
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Città'),
              )
              .initialValue,
          'Isernia',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Luogo o evento'),
              )
              .initialValue,
          'Test',
        );
        final descriptionEditor = find.descendant(
          of: find.byType(ContentSubmissionDescriptionFormField),
          matching: find.byType(QuillEditor),
        );
        expect(
          tester
              .widget<QuillEditor>(descriptionEditor)
              .controller
              .document
              .toPlainText(),
          'Descrizione di test\n',
        );
        // E-mail, Autore, and the terms checkbox live in the second
        // SliverList — scroll them into view so sliver children are built.
        await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, 'E-mail'),
          200,
          scrollable: mainScrollable,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'E-mail'),
              )
              .initialValue,
          'm@e.com',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Autore'),
              )
              .initialValue,
          'Mario',
        );

        // The terms checkbox is checked from the persisted draft.
        await tester.scrollUntilVisible(
          find.byType(CheckboxFormField),
          200,
          scrollable: mainScrollable,
        );
        final termsCheckbox = tester.widget<Checkbox>(
          find.descendant(
            of: find.byType(CheckboxFormField),
            matching: find.byType(Checkbox),
          ),
        );
        expect(termsCheckbox.value, isTrue);
      },
    );

    testWidgets(
      'tapping the terms checkbox propagates the new value to the draft',
      (tester) async {
        final draftRepo = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.success(
            ContentSubmissionDraft(acceptedTerms: true),
          ),
        );
        final repo = ControllableSubmissionRepository();
        final vm = ContentSubmissionViewModel(
          logger: MockLogger(),
          contentSubmissionRepository: repo,
          draftRepository: draftRepo,
          stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
          imagePicker: FakeImagePicker(),
        );
        await vm.initialize();

        await tester.pumpWidget(buildApp(vm));
        // Drain the loading frame before scrolling/tapping.
        await tester.pumpAndSettle();

        final termsCheckbox = find.descendant(
          of: find.byType(CheckboxFormField),
          matching: find.byType(Checkbox),
        );
        // scrollUntilVisible stops as soon as the checkbox enters the sliver's
        // cache extent (built but still outside the viewport), so we need an
        // explicit ensureVisible for tap() to actually hit the widget.
        await tester.scrollUntilVisible(
          termsCheckbox,
          200,
          scrollable: mainScrollable,
        );
        await tester.ensureVisible(termsCheckbox);
        await tester.pump();
        await tester.tap(termsCheckbox);
        await tester.pump();

        expect(vm.state.acceptedTerms, isFalse);
        expect(draftRepo.lastSavedState, isNull);
      },
    );
  });

  group('ContentSubmissionScreen event dates', () {
    testWidgets('unchecking the event flag clears the draft dates', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();
      vm
        ..setStartCalendarDate(EventCalendarDate(2026, 8, 20))
        ..setStartClockTime(EventClockTime(10, 0))
        ..setEndCalendarDate(EventCalendarDate(2026, 8, 20));

      await tester.pumpWidget(buildApp(vm));

      final eventCheckbox = find.descendant(
        of: find
            .ancestor(
              of: find.text('È un evento?'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Checkbox),
      );
      expect(tester.widget<Checkbox>(eventCheckbox).value, isTrue);

      await tester.ensureVisible(eventCheckbox);
      await tester.pump();
      await tester.tap(eventCheckbox);
      await tester.pump();

      expect(vm.state.eventDates.startInstantUtc, isNull);
      expect(vm.state.eventDates.endInstantUtc, isNull);
    });
  });
}
