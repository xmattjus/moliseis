import 'dart:async' show Completer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
    await tester.tap(finder);
    await tester.pump();
  }

  Widget buildApp(ContentSubmissionViewModel viewModel) {
    final router = GoRouter(
      initialLocation: '/submission',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
        ),
        GoRoute(
          path: '/submission',
          name: RouteNames.contentSubmission,
          builder: (_, _) => ContentSubmissionScreen(viewModel: viewModel),
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
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('it')],
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

      expect(repo.uploadCallCount, 0);
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
      expect(repo.uploadCallCount, 1);
      expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
      expect(find.text('Invio in corso...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      addTearDown(() => repo.completeUpload(const Result.success(null)));
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
        expect(repo.uploadCallCount, 0);
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

      expect(repo.uploadCallCount, 1);
      repo.completeUpload(const Result.success(null));
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

      repo.completeUpload(Result.error(Exception('boom')));
      await tester.pumpAndSettle();

      expect(vm.submit.error, isTrue);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsNothing);
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

        repo.completeUpload(const Result.success(null));
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
      'completed pop hides stale form while persisted clear is pending',
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

        repo.completeUpload(const Result.success(null));
        await tester.pumpAndSettle();
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        final previousState = vm.state;
        final previousIdentity = vm.state.clientSubmissionId;
        final previousAsset = vm.assets.single;
        expect(vm.hasUnsavedChanges, isTrue);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(vm.clear.running, isTrue);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.text('Caricamento in corso...'), findsOneWidget);
        expect(find.text('Campobasso'), findsNothing);
        expect(vm.state, previousState);
        expect(vm.state.clientSubmissionId, previousIdentity);
        expect(vm.assets, [previousAsset]);
        expect(vm.hasUnsavedChanges, isTrue);

        clearGate.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(vm.clear.completed, isTrue);
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

      repo.completeUpload(Result.error(Exception('boom')));
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
