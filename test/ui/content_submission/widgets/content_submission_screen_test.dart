import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  ContentSubmissionViewModel buildViewModel({
    required ControllableSubmissionRepository submissionRepository,
  }) {
    return ContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: submissionRepository,
      draftRepository: FakeContentSubmissionDraftRepository(),
      imagePicker: FakeImagePicker(),
    );
  }

  /// Flushes the 3s debounce timer scheduled by field onChanged callbacks.
  Future<void> flushDebounce(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3, milliseconds: 100));

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
    return MaterialApp.router(routerConfig: router);
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
      await flushDebounce(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(OutlinedButton, 'Invia'),
      );

      expect(repo.uploadCallCount, 0);
      expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);
      expect(vm.submit.idle, isTrue);
    });

    testWidgets('with valid form fires submit and navigates to progress', (
      tester,
    ) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await fillValidForm(tester);
      await flushDebounce(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(OutlinedButton, 'Invia'),
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

    testWidgets('completes the upload pipeline on success', (tester) async {
      final repo = ControllableSubmissionRepository();
      final vm = buildViewModel(submissionRepository: repo);
      await vm.initialize();

      await tester.pumpWidget(buildApp(vm));
      await fillValidForm(tester);
      await flushDebounce(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(OutlinedButton, 'Invia'),
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
      await flushDebounce(tester);

      await scrollToAndTap(
        tester,
        find.widgetWithText(OutlinedButton, 'Invia'),
      );
      await tester.pump();

      repo.completeUpload(Result.error(Exception('boom')));
      await tester.pumpAndSettle();

      expect(vm.submit.error, isTrue);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Nuovo suggerimento'), findsNothing);
    });
  });

  group('ContentSubmissionScreen persisted draft binding', () {
    testWidgets(
      'binds the loaded draft values to the form fields on first build',
      (tester) async {
        final draftRepo = FakeContentSubmissionDraftRepository(
          loadDraftResult: const Result.success(
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
        await flushDebounce(tester);

        // Each TextFormField now carries `initialValue` bound to the loaded
        // draft state — the belt-and-suspenders path that fixes the
        // resume-through-CTA visible-text drift.
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
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Descrizione'),
              )
              .initialValue,
          'Descrizione di test',
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
          loadDraftResult: const Result.success(
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
        await flushDebounce(tester);

        expect(vm.state.acceptedTerms, isFalse);
        expect(draftRepo.lastSavedState?.acceptedTerms, isFalse);
      },
    );
  });
}
