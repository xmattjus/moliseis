import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_progress_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_screen.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../support/fake_external_url_service.dart';
import '../support/fake_image_picker.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';
import '../support/predictive_back.dart';

void main() {
  _ContentSubmissionRouteHarness createHarness({
    FakeContentSubmissionDraftRepository? draftRepository,
    FakeContentSubmissionStagedAssetRepository? stagedAssetRepository,
    FakeImagePicker? imagePicker,
    ControllableSubmissionRepository? submissionRepository,
    FakeExternalUrlService? externalUrlService,
  }) => _ContentSubmissionRouteHarness(
    draftRepository: draftRepository ?? FakeContentSubmissionDraftRepository(),
    stagedAssetRepository:
        stagedAssetRepository ?? FakeContentSubmissionStagedAssetRepository(),
    imagePicker: imagePicker ?? FakeImagePicker(),
    submissionRepository:
        submissionRepository ?? ControllableSubmissionRepository(),
    externalUrlService:
        externalUrlService ?? FakeExternalUrlService(logger: MockLogger()),
  );

  final mainScrollable = find
      .descendant(
        of: find.byKey(const ValueKey('content_submission_scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  bool contentSubmissionCanPop(WidgetTester tester) => tester
      .widget<PopScope<dynamic>>(
        find.ancestor(
          of: find.byKey(const ValueKey('content_submission_scroll')),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopScope<dynamic>,
          ),
        ),
      )
      .canPop;

  Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: mainScrollable);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> enterLabeledField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.scrollUntilVisible(field, 200, scrollable: mainScrollable);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, value);
    await tester.pump();
  }

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

  group('Content Submission session presentation', () {
    for (final populated in [false, true]) {
      testWidgets(
        populated
            ? 'mixed late recovery preserves exact draft and clean Back'
            : 'RED 2 empty late recovery preserves exact draft and clean Back',
        (tester) async {
          final restored = ContentSubmissionDraft(
            clientSubmissionId: '12345678-1234-4234-8234-123456789abc',
            city: populated ? 'Isernia' : null,
            userEmail: populated ? 'recovered@example.com' : null,
          );
          final loadGate = Completer<Result<ContentSubmissionDraft?>>();
          final repository = FakeContentSubmissionDraftRepository()
            ..pendingLoadDraft = loadGate;
          final harness = createHarness(draftRepository: repository);
          addTearDown(harness.dispose);
          final constructorIdentity =
              harness.viewModel.state.clientSubmissionId;
          unawaited(harness.viewModel.initialize());
          await harness.pumpForm(
            tester,
            withGallerySentinel: true,
            settleAfterPush: false,
          );
          expect(repository.loadDraftCallCount, 1);
          expect(constructorIdentity, isNot(restored.clientSubmissionId));
          expect(
            harness.viewModel.state.clientSubmissionId,
            constructorIdentity,
          );
          expect(find.byType(ContentSubmissionScreen), findsOneWidget);
          expect(find.text('Caricamento in corso...'), findsOneWidget);
          expect(find.byType(TextFormField), findsNothing);
          final adopted =
              <
                ({ContentSubmissionDraft draft, bool dirty, StackTrace caller})
              >[];
          harness.viewModel.addListener(() {
            adopted.add((
              draft: harness.viewModel.state,
              dirty: harness.viewModel.hasUnsavedChanges,
              caller: StackTrace.current,
            ));
          });

          loadGate.complete(Result.success(restored));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(adopted.first.draft, restored);
          expect(adopted.first.dirty, isFalse);
          expect(
            harness.viewModel.state,
            restored,
            reason: adopted
                .where((snapshot) => snapshot.dirty)
                .map((snapshot) => snapshot.caller)
                .join('\n'),
          );
          expect(harness.viewModel.hasUnsavedChanges, isFalse);
          expect(find.text('Modifiche non salvate'), findsNothing);
          expect(repository.saveDraftCallCount, 0);
          expect(repository.clearDraftCallCount, 0);
          final email = find.widgetWithText(TextFormField, 'E-mail');
          await tester.scrollUntilVisible(
            email,
            200,
            scrollable: mainScrollable,
          );
          expect(
            tester
                .widget<TextField>(
                  find.descendant(of: email, matching: find.byType(TextField)),
                )
                .controller!
                .text,
            restored.userEmail ?? '',
          );
          expect(harness.viewModel.state, restored);
          await tester.scrollUntilVisible(
            find.byType(BackButton),
            -200,
            scrollable: mainScrollable,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Salvare le modifiche?'), findsNothing);
          expect(
            harness.router.routeInformationProvider.value.uri.path,
            RoutePaths.gallery,
          );
          expect(harness.viewModel.checkpointCallCount, 0);
          expect(harness.viewModel.restoreCallCount, 0);
          expect(repository.saveDraftCallCount, 0);
          expect(repository.clearDraftCallCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final action in ['Torna alla home', 'Back', 'Nuovo suggerimento']) {
      testWidgets(
        action == 'Torna alla home'
            ? 'successful Home performs no additional lifecycle work'
            : 'RED 3 recovered contacts stay retired through $action',
        (tester) async {
          final recovered = ContentSubmissionDraft(
            clientSubmissionId: '12345678-1234-4234-8234-123456789abc',
            city: 'Campobasso',
            name: 'Recovered place',
            userEmail: 'original@example.com',
            userName: 'Original Author',
            description: 'Original description',
            descriptionDelta: const [
              {'insert': 'Original description\n'},
            ],
            acceptedTerms: true,
          );
          final clearGate = Completer<Result<void>>();
          final repository = FakeContentSubmissionDraftRepository(
            loadDraftResult: Result.success(recovered),
          )..pendingClearDraft = clearGate;
          final harness = createHarness(draftRepository: repository);
          addTearDown(harness.dispose);
          await harness.viewModel.initialize();
          await harness.pumpForm(tester, withGallerySentinel: true);
          expect(harness.viewModel.state, recovered);
          final oldForms = tester
              .stateList<FormState>(find.byType(Form))
              .toList();
          for (final label in ['E-mail', 'Autore']) {
            final field = find.widgetWithText(TextFormField, label);
            await tester.scrollUntilVisible(
              field,
              200,
              scrollable: mainScrollable,
            );
            expect(
              tester
                  .widget<TextField>(
                    find.descendant(
                      of: field,
                      matching: find.byType(TextField),
                    ),
                  )
                  .controller!
                  .text,
              label == 'E-mail' ? recovered.userEmail : recovered.userName,
            );
          }
          for (final form in tester.stateList<FormState>(find.byType(Form))) {
            if (!oldForms.contains(form)) oldForms.add(form);
          }
          expect(oldForms, hasLength(2));
          final nextIdentities = <String>{};
          harness.viewModel.addListener(() {
            final id = harness.viewModel.state.clientSubmissionId;
            if (id != recovered.clientSubmissionId) nextIdentities.add(id);
          });
          await scrollToAndTap(
            tester,
            find.widgetWithText(FilledButton, 'Invia'),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(harness.submissionRepository.submitCallCount, 1);
          harness.submissionRepository.completeSubmission(
            const Result.success(null),
          );
          for (var frame = 0; frame < 20; frame++) {
            if (repository.clearDraftCallCount == 1) break;
            await tester.pump();
          }
          expect(repository.clearDraftCallCount, 1);
          expect(harness.viewModel.submit.running, isTrue);
          clearGate.complete(const Result.success(null));
          await tester.pumpAndSettle();
          expect(harness.viewModel.submit.completed, isTrue);
          expect(tester.takeException(), isNull);
          final freshId = harness.viewModel.state.clientSubmissionId;
          final checkpointCalls = harness.viewModel.checkpointCallCount;
          final restoreCalls = harness.viewModel.restoreCallCount;
          final saveCalls = repository.saveDraftCallCount;
          final stagedCalls =
              harness.stagedAssetRepository.clearedSessions.length;
          expect(nextIdentities, {freshId});
          expect(freshId, isNot(recovered.clientSubmissionId));
          if (action != 'Torna alla home') {
            expect(
              harness.viewModel.state,
              ContentSubmissionDraft(clientSubmissionId: freshId),
            );
            expect(harness.viewModel.hasUnsavedChanges, isFalse);
          }
          await tester.tap(
            action == 'Back' ? find.byType(BackButton) : find.text(action),
          );
          await tester.pumpAndSettle();

          expect(find.text('Salvare le modifiche?'), findsNothing);
          if (action == 'Torna alla home') {
            expect(
              harness.router.routeInformationProvider.value.uri.path,
              RoutePaths.home,
            );
            expect(find.byType(ExploreScreen), findsOneWidget);
          } else {
            expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
            expect(find.byType(ContentSubmissionScreen), findsOneWidget);
            for (final label in [
              'E-mail',
              'Autore',
              'Città',
              'Luogo o evento',
            ]) {
              final field = find.widgetWithText(TextFormField, label);
              await tester.scrollUntilVisible(
                field,
                label == 'Città' || label == 'Luogo o evento' ? -200 : 200,
                scrollable: mainScrollable,
              );
              expect(
                tester
                    .widget<TextField>(
                      find.descendant(
                        of: field,
                        matching: find.byType(TextField),
                      ),
                    )
                    .controller!
                    .text,
                isEmpty,
              );
            }
            final editor = find.byType(QuillEditor);
            await tester.scrollUntilVisible(
              editor,
              200,
              scrollable: mainScrollable,
            );
            expect(
              tester
                  .widget<QuillEditor>(editor)
                  .controller
                  .document
                  .toPlainText()
                  .trim(),
              isEmpty,
            );
            final terms = find.byType(CheckboxFormField);
            await tester.scrollUntilVisible(
              terms,
              200,
              scrollable: mainScrollable,
            );
            expect(
              tester
                  .widget<Checkbox>(
                    find.descendant(of: terms, matching: find.byType(Checkbox)),
                  )
                  .value,
              isFalse,
            );
            final newForms = tester.stateList<FormState>(find.byType(Form));
            expect(newForms.every((form) => !oldForms.contains(form)), isTrue);
            expect(find.text('Modifiche non salvate'), findsNothing);
          }
          expect(
            harness.viewModel.state,
            ContentSubmissionDraft(clientSubmissionId: freshId),
          );
          expect(harness.viewModel.hasUnsavedChanges, isFalse);
          expect(harness.viewModel.assets, isEmpty);
          expect(nextIdentities, {freshId});
          expect(harness.viewModel.checkpointCallCount, checkpointCalls);
          expect(harness.viewModel.restoreCallCount, restoreCalls);
          expect(harness.viewModel.clear.idle, isTrue);
          expect(repository.saveDraftCallCount, saveCalls);
          expect(repository.clearDraftCallCount, 1);
          expect(
            harness.stagedAssetRepository.clearedSessions.length,
            stagedCalls,
          );
          expect(harness.submissionRepository.submitCallCount, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'same-session text input updates draft and structural dirtiness',
      (tester) async {
        final harness = createHarness();
        addTearDown(harness.dispose);
        await harness.viewModel.initialize();
        await harness.pumpForm(tester);
        final identity = harness.viewModel.state.clientSubmissionId;
        final form = tester.state<FormState>(find.byType(Form).first);
        await enterLabeledField(tester, 'Città', 'Isernia');
        await tester.pumpAndSettle();
        expect(harness.viewModel.state.clientSubmissionId, identity);
        expect(harness.viewModel.state.city, 'Isernia');
        expect(harness.viewModel.hasUnsavedChanges, isTrue);
        expect(tester.state<FormState>(find.byType(Form).first), same(form));
        expect(harness.draftRepository.saveDraftCallCount, 0);
        await tester.scrollUntilVisible(
          find.text('Suggerimento'),
          -200,
          scrollable: mainScrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text('Modifiche non salvate'), findsOneWidget);
        await harness.viewModel.checkpointDraft();
        await tester.pump();
        expect(harness.viewModel.hasUnsavedChanges, isFalse);
        expect(find.text('Modifiche non salvate'), findsNothing);
        expect(tester.state<FormState>(find.byType(Form).first), same(form));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('RED 1 retirement stays canonical beneath real progress', (
      tester,
    ) async {
      final clearGate = Completer<Result<void>>();
      final draftRepository = FakeContentSubmissionDraftRepository()
        ..pendingClearDraft = clearGate;
      final harness = createHarness(draftRepository: draftRepository);
      addTearDown(harness.dispose);
      await harness.viewModel.initialize();
      await harness.pumpForm(tester, withGallerySentinel: true);
      await fillValidForm(tester);
      final submittedIdentity = harness.viewModel.state.clientSubmissionId;
      final retiredSnapshots =
          <({ContentSubmissionDraft draft, bool dirty, StackTrace caller})>[];
      harness.viewModel.addListener(() {
        if (harness.viewModel.state.clientSubmissionId != submittedIdentity) {
          retiredSnapshots.add((
            draft: harness.viewModel.state,
            dirty: harness.viewModel.hasUnsavedChanges,
            caller: StackTrace.current,
          ));
        }
      });

      await scrollToAndTap(tester, find.widgetWithText(FilledButton, 'Invia'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(harness.submissionRepository.submitCallCount, 1);
      expect(harness.submissionRepository.submittedClientSubmissionIds, [
        submittedIdentity,
      ]);
      expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
      expect(
        find.byType(ContentSubmissionScreen, skipOffstage: false),
        findsOneWidget,
      );
      harness.submissionRepository.completeSubmission(
        const Result.success(null),
      );
      for (var frame = 0; frame < 20; frame++) {
        if (draftRepository.clearDraftCallCount == 1) break;
        await tester.pump();
      }
      expect(draftRepository.clearDraftCallCount, 1);
      expect(harness.viewModel.submit.running, isTrue);
      expect(harness.viewModel.clear.idle, isTrue);
      expect(find.text('Nuovo suggerimento'), findsNothing);
      expect(harness.viewModel.state.clientSubmissionId, submittedIdentity);

      clearGate.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(harness.viewModel.submit.completed, isTrue);
      expect(find.text('Nuovo suggerimento'), findsOneWidget);
      final freshIdentity = harness.viewModel.state.clientSubmissionId;
      final canonical = ContentSubmissionDraft(
        clientSubmissionId: freshIdentity,
      );
      expect(freshIdentity, isNot(submittedIdentity));
      expect(retiredSnapshots, isNotEmpty);
      expect(retiredSnapshots.first.draft, canonical);
      expect(retiredSnapshots.first.dirty, isFalse);
      expect(
        retiredSnapshots
            .map((snapshot) => snapshot.draft.clientSubmissionId)
            .toSet(),
        {freshIdentity},
      );
      final syntheticCalls = retiredSnapshots
          .where((snapshot) => snapshot.dirty)
          .map((snapshot) => snapshot.caller)
          .join('\n');
      expect(
        harness.viewModel.state,
        canonical,
        reason:
            'Retirement first emitted canonical clean state. '
            'Subsequent dirty notifications came from:\n$syntheticCalls',
      );
      expect(harness.viewModel.state.city, isNull);
      expect(harness.viewModel.state.name, isNull);
      expect(harness.viewModel.state.description, isNull);
      expect(harness.viewModel.state.descriptionDelta, isNull);
      expect(harness.viewModel.state.userEmail, isNull);
      expect(harness.viewModel.state.userName, isNull);
      expect(harness.viewModel.state.acceptedTerms, isNull);
      expect(
        harness.viewModel.state.eventDates,
        const EventDateDraft.disabled(),
      );
      expect(harness.viewModel.assets, isEmpty);
      expect(harness.viewModel.hasUnsavedChanges, isFalse);
      expect(harness.stagedAssetRepository.clearedSessions, [
        submittedIdentity,
      ]);
    });
  });

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
      debugDefaultTargetPlatformOverride = null;
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
      debugDefaultTargetPlatformOverride = null;
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

    testWidgets('checkpoint failure denies exit and a later attempt succeeds', (
      tester,
    ) async {
      final draftRepository = FakeContentSubmissionDraftRepository(
        saveDraftResult: Result.error(Exception('checkpoint failed')),
      );
      final harness = createHarness(draftRepository: draftRepository);
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      harness.viewModel.setCity('Campobasso');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Salva ed esci'));
      await tester.pump();

      expect(find.text('Suggerimento'), findsOneWidget);
      expect(harness.viewModel.hasUnsavedChanges, isTrue);
      expect(draftRepository.saveDraftCallCount, 1);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      expect(contentSubmissionCanPop(tester), isFalse);

      draftRepository.saveDraftResult = const Result.success(null);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Salva ed esci'));
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.gallery,
      );
      expect(draftRepository.saveDraftCallCount, 2);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('dirty AppBar and system Back use the same cancelable policy', (
      tester,
    ) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);
      harness.viewModel.setCity('Campobasso');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.text('Salva ed esci'), findsOneWidget);
      expect(find.text('Esci senza salvare'), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      final systemBack = tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.text('Salva ed esci'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      expect(await systemBack, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Suggerimento'), findsOneWidget);
      expect(harness.viewModel.hasUnsavedChanges, isTrue);
      expect(harness.draftRepository.saveDraftCallCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'iOS AppBar Back revokes its one-shot allowance after each cancellation',
      (tester) async {
        final harness = createHarness();
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        harness.viewModel.setCity('Campobasso');
        await tester.pump();

        expect(contentSubmissionCanPop(tester), isFalse);
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump();
        expect(find.text('Salva ed esci'), findsOneWidget);
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(harness.viewModel.hasUnsavedChanges, isTrue);
        expect(find.text('Modifiche non salvate'), findsOneWidget);
        expect(contentSubmissionCanPop(tester), isFalse);

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump();
        expect(find.text('Salva ed esci'), findsOneWidget);
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(contentSubmissionCanPop(tester), isFalse);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'overlapping removals have one owner and preserve the sentinel',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final harness = createHarness(draftRepository: draftRepository);
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        harness.viewModel.setCity('Campobasso');
        final checkpoint = Completer<Result<void>>();
        draftRepository.pendingSaveDraft = checkpoint;
        await tester.pump();

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        harness.router.go(RoutePaths.logging);
        await tester.pump();
        expect(find.text('Salva ed esci'), findsOneWidget);
        await tester.tap(find.text('Salva ed esci'));
        await tester.pump();
        expect(draftRepository.saveDraftCallCount, 1);
        expect(find.text('Salva ed esci'), findsNothing);

        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );
        expect(find.text('Suggerimento'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'overlap releases after cancel and failure, then permits a reopened exit',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final harness = createHarness(draftRepository: draftRepository);
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        harness.viewModel.setCity('Campobasso');
        await tester.pump();

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        harness.router.go(RoutePaths.logging);
        await tester.pump();
        expect(find.text('Salva ed esci'), findsOneWidget);
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(find.text('Suggerimento'), findsOneWidget);
        expect(draftRepository.saveDraftCallCount, 0);

        draftRepository.saveDraftResult = Result.error(Exception('failed'));
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        harness.router.go(RoutePaths.logging);
        await tester.pump();
        await tester.tap(find.text('Salva ed esci'));
        await tester.pump();
        expect(draftRepository.saveDraftCallCount, 1);
        expect(find.text('Suggerimento'), findsOneWidget);

        draftRepository.saveDraftResult = const Result.success(null);
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.tap(find.text('Salva ed esci'));
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );

        unawaited(harness.router.push(RoutePaths.contentSubmission));
        await tester.pumpAndSettle();
        harness.viewModel.setCity('Isernia');
        await tester.pump();
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.tap(find.text('Salva ed esci'));
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );
        expect(draftRepository.saveDraftCallCount, 3);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'durable staged-asset mutations do not make a clean form dirty',
      (tester) async {
        final harness = createHarness(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'asset.jpg'),
            ],
          ),
        );
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);

        await harness.viewModel.addAsset.execute();
        await tester.pump();
        expect(harness.viewModel.hasUnsavedChanges, isFalse);
        expect(find.text('Modifiche non salvate'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );
        expect(find.text('Salva ed esci'), findsNothing);

        unawaited(harness.router.push(RoutePaths.contentSubmission));
        await tester.pumpAndSettle();
        await harness.viewModel.removeAssetAt.execute(0);
        await tester.pump();
        expect(harness.viewModel.assets, isEmpty);
        expect(harness.viewModel.hasUnsavedChanges, isFalse);
        expect(find.text('Modifiche non salvate'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );
        expect(find.text('Salva ed esci'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'discard restores the durable draft without retiring its assets',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final stagedRepository = FakeContentSubmissionStagedAssetRepository();
        final harness = createHarness(
          draftRepository: draftRepository,
          stagedAssetRepository: stagedRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'asset.jpg'),
            ],
          ),
        );
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        harness.viewModel.setCity('Campobasso');
        await harness.viewModel.checkpointDraft();
        final identity = harness.viewModel.state.clientSubmissionId;
        await harness.viewModel.addAsset.execute();
        expect(harness.viewModel.assets, hasLength(1));
        expect(harness.viewModel.hasUnsavedChanges, isFalse);
        harness.viewModel.setCity('Isernia');
        await tester.pump();

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text('Esci senza salvare'));
        await tester.pumpAndSettle();

        expect(harness.viewModel.state.city, 'Campobasso');
        expect(harness.viewModel.state.clientSubmissionId, identity);
        expect(harness.viewModel.assets, hasLength(1));
        expect(draftRepository.lastSavedState?.city, 'Campobasso');
        expect(draftRepository.clearDraftCallCount, 0);
        expect(stagedRepository.clearedSessions, isEmpty);
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );

        unawaited(harness.router.push(RoutePaths.contentSubmission));
        await tester.pumpAndSettle();
        expect(find.text('Suggerimento'), findsOneWidget);
        expect(harness.viewModel.state.city, 'Campobasso');
        expect(harness.viewModel.state.clientSubmissionId, identity);
        expect(harness.viewModel.assets, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'unknown persisted ownership blocks discard and keeps the form',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository(
          loadDraftResult: Result.error(Exception('unknown draft ownership')),
        );
        final harness = createHarness(draftRepository: draftRepository);
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        harness.viewModel.setCity('Campobasso');
        await tester.pump();
        expect(contentSubmissionCanPop(tester), isFalse);

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text('Esci senza salvare'));
        await tester.pump();

        expect(find.text('Suggerimento'), findsOneWidget);
        expect(harness.viewModel.state.city, 'Campobasso');
        expect(harness.viewModel.hasUnsavedChanges, isTrue);
        expect(draftRepository.clearDraftCallCount, 0);
        expect(
          find.text('Si è verificato un errore, riprova più tardi'),
          findsOneWidget,
        );
        expect(contentSubmissionCanPop(tester), isFalse);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('clean Android predictive Back removes the form directly', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = createHarness();
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);

      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        RoutePaths.gallery,
      );
      expect(find.text('Salva ed esci'), findsNothing);
      expect(harness.draftRepository.saveDraftCallCount, 0);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('dirty Android predictive Back shares cancellation policy', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = createHarness();
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);
      harness.viewModel.setCity('Campobasso');
      await tester.pump();

      await startPredictiveBack(tester);
      await cancelPredictiveBack(tester);
      expect(find.text('Suggerimento'), findsOneWidget);

      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);
      expect(find.text('Salva ed esci'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.text('Suggerimento'), findsOneWidget);
      expect(harness.viewModel.hasUnsavedChanges, isTrue);
      expect(harness.draftRepository.saveDraftCallCount, 0);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'concurrent programmatic removals retain only the owner destination',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final harness = createHarness(draftRepository: draftRepository);
        addTearDown(harness.dispose);
        await harness.pumpForm(tester);
        harness.viewModel.setCity('Campobasso');
        final checkpoint = Completer<Result<void>>();
        draftRepository.pendingSaveDraft = checkpoint;
        await tester.pump();

        harness.router.go(RoutePaths.gallery);
        await tester.pump();
        harness.router.go(RoutePaths.logging);
        await tester.pump();
        await tester.tap(find.text('Salva ed esci'));
        await tester.pump();
        expect(draftRepository.saveDraftCallCount, 1);
        checkpoint.complete(const Result.success(null));
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );

        harness.router.go(RoutePaths.contentSubmission);
        await tester.pumpAndSettle();
        harness.router.go(RoutePaths.logging);
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.logging,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'popping progress does not invoke the dirty parent exit policy',
      (tester) async {
        final harness = createHarness();
        addTearDown(harness.dispose);
        await harness.pumpForm(tester);
        harness.viewModel.setCity('Campobasso');
        unawaited(
          harness.router.pushNamed(RouteNames.contentSubmissionUploadProgress),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.text('Suggerimento'), findsOneWidget);
        expect(find.text('Salva ed esci'), findsNothing);
        expect(harness.viewModel.hasUnsavedChanges, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ordinary-error Back and return-to-form each pop one progress route',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final stagedRepository = FakeContentSubmissionStagedAssetRepository();
        final submissionRepository = ControllableSubmissionRepository(
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
        final harness = createHarness(
          draftRepository: draftRepository,
          stagedAssetRepository: stagedRepository,
          submissionRepository: submissionRepository,
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => <XFile>[
              XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]), name: 'a.jpg'),
            ],
          ),
        );
        addTearDown(harness.dispose);
        await harness.pumpForm(tester);
        await fillValidForm(tester);
        await harness.viewModel.addAsset.execute();
        await tester.pump();

        await scrollToAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Invia'),
        );
        await tester.pump();
        expect(submissionRepository.submitCallCount, 1);
        submissionRepository.completeSubmission(
          Result.error(Exception('ordinary failure')),
        );
        await tester.pumpAndSettle();

        final failedState = harness.viewModel.state;
        final failedIdentity = failedState.clientSubmissionId;
        final saveCount = draftRepository.saveDraftCallCount;
        expect(harness.viewModel.assets, hasLength(1));
        expect(find.text('Riprova'), findsNothing);
        expect(find.text('Torna al modulo'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);
        expect(harness.viewModel.state, failedState);
        expect(harness.viewModel.state.clientSubmissionId, failedIdentity);
        expect(harness.viewModel.assets, hasLength(1));
        expect(submissionRepository.submitCallCount, 1);
        expect(draftRepository.saveDraftCallCount, saveCount);
        expect(draftRepository.clearDraftCallCount, 0);
        expect(stagedRepository.clearedSessions, isEmpty);

        unawaited(
          harness.router.pushNamed(RouteNames.contentSubmissionUploadProgress),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        expect(
          find.byType(ContentSubmissionScreen, skipOffstage: false),
          findsOneWidget,
        );

        await tester.tap(find.text('Torna al modulo'));
        await tester.pumpAndSettle();

        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);
        expect(harness.viewModel.state, failedState);
        expect(harness.viewModel.state.clientSubmissionId, failedIdentity);
        expect(harness.viewModel.assets, hasLength(1));
        expect(submissionRepository.submitCallCount, 1);
        expect(draftRepository.saveDraftCallCount, saveCount);
        expect(draftRepository.clearDraftCallCount, 0);
        expect(stagedRepository.clearedSessions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Content Submission production router boundary ownership', () {
    testWidgets(
      'pre-submit ownership rejects system and predictive exit until handoff',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final repository = ControllableSubmissionRepository();
        addTearDown(
          () => repository.completeSubmission(Result.error(Exception())),
        );
        final harness = createHarness(
          draftRepository: draftRepository,
          submissionRepository: repository,
        );
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        await fillValidForm(tester);
        await scrollToAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Invia'),
        );

        expect(draftRepository.saveDraftCallCount, 1);
        expect(repository.submitCallCount, 0);
        final systemBack = tester.binding.handlePopRoute();
        await tester.pump();
        await systemBack;
        await startPredictiveBack(tester);
        await commitPredictiveBack(tester);
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(find.text('Salva ed esci'), findsNothing);
        expect(draftRepository.saveDraftCallCount, 1);
        expect(draftRepository.clearDraftCallCount, 0);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);

        checkpoint.complete(const Result.success(null));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(repository.submitCallCount, 1);
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        repository.completeSubmission(
          Result.error(Exception('remote failure')),
        );
        await tester.pump();
        await tester.pump();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pump();
        await tester.pump();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pump();
        await tester.pump();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final legalLink in <String>[
      'Termini di Servizio',
      'Informativa sulla privacy',
    ]) {
      testWidgets(
        '$legalLink ownership rejects system and predictive exit until launch',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final checkpoint = Completer<Result<void>>();
          final draftRepository = FakeContentSubmissionDraftRepository()
            ..pendingSaveDraft = checkpoint;
          final harness = createHarness(draftRepository: draftRepository);
          addTearDown(harness.dispose);
          await harness.pumpForm(tester, withGallerySentinel: true);
          harness.viewModel.setCity('Campobasso');
          await tester.pump();
          await scrollToAndTap(tester, find.text(legalLink));

          expect(draftRepository.saveDraftCallCount, 1);
          expect(harness.externalUrlService.launchedUrls, isEmpty);
          final systemBack = tester.binding.handlePopRoute();
          await tester.pump();
          await systemBack;
          await startPredictiveBack(tester);
          await commitPredictiveBack(tester);
          await tester.pump();
          debugDefaultTargetPlatformOverride = null;

          expect(find.text('Salva ed esci'), findsNothing);
          expect(draftRepository.saveDraftCallCount, 1);
          expect(draftRepository.clearDraftCallCount, 0);
          expect(find.byType(ContentSubmissionScreen), findsOneWidget);

          checkpoint.complete(const Result.success(null));
          await tester.pumpAndSettle();

          expect(harness.externalUrlService.launchedUrls, hasLength(1));
          expect(await tester.binding.handlePopRoute(), isTrue);
          await tester.pumpAndSettle();
          expect(
            harness.router.routeInformationProvider.value.uri.path,
            RoutePaths.gallery,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('failed Terms boundary releases ownership for normal Back', (
      tester,
    ) async {
      final checkpoint = Completer<Result<void>>();
      final draftRepository = FakeContentSubmissionDraftRepository()
        ..pendingSaveDraft = checkpoint;
      final harness = createHarness(draftRepository: draftRepository);
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);
      harness.viewModel.setCity('Campobasso');
      await tester.pump();
      await scrollToAndTap(tester, find.text('Termini di Servizio'));

      checkpoint.complete(Result.error(Exception('checkpoint failed')));
      await tester.pumpAndSettle();

      expect(harness.externalUrlService.launchedUrls, isEmpty);
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);
      final systemBack = tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.text('Salva ed esci'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      expect(await systemBack, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'owning exit denies every form boundary before it removes the form',
      (tester) async {
        final checkpoint = Completer<Result<void>>();
        final draftRepository = FakeContentSubmissionDraftRepository()
          ..pendingSaveDraft = checkpoint;
        final repository = ControllableSubmissionRepository();
        final harness = createHarness(
          draftRepository: draftRepository,
          submissionRepository: repository,
        );
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        await fillValidForm(tester);

        final terms = tester.widget<InkWell>(
          find.ancestor(
            of: find.text('Termini di Servizio'),
            matching: find.byType(InkWell),
          ),
        );
        final privacy = tester.widget<InkWell>(
          find.ancestor(
            of: find.text('Informativa sulla privacy'),
            matching: find.byType(InkWell),
          ),
        );
        final submitFinder = find.widgetWithText(FilledButton, 'Invia');
        await tester.scrollUntilVisible(
          submitFinder,
          200,
          scrollable: mainScrollable,
        );
        await tester.ensureVisible(submitFinder);
        final submit = tester.widget<FilledButton>(submitFinder);

        final exitAttempt = tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Salva ed esci'), findsOneWidget);

        submit.onPressed!();
        terms.onTap!();
        privacy.onTap!();
        await tester.pump();

        expect(draftRepository.saveDraftCallCount, 0);
        expect(repository.submitCallCount, 0);
        expect(harness.externalUrlService.launchedUrls, isEmpty);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);

        await tester.tap(find.text('Salva ed esci'));
        await tester.pump();
        expect(draftRepository.saveDraftCallCount, 1);
        submit.onPressed!();
        terms.onTap!();
        privacy.onTap!();
        await tester.pump();

        expect(draftRepository.saveDraftCallCount, 1);
        expect(repository.submitCallCount, 0);
        expect(harness.externalUrlService.launchedUrls, isEmpty);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);

        checkpoint.complete(const Result.success(null));
        expect(await exitAttempt, isTrue);
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.gallery,
        );
        expect(repository.submitCallCount, 0);
        expect(harness.externalUrlService.launchedUrls, isEmpty);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cancelled exit releases Terms and Privacy boundaries', (
      tester,
    ) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);
      await fillValidForm(tester);

      final exitAttempt = tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('Annulla'));
      expect(await exitAttempt, isTrue);
      await tester.pumpAndSettle();

      await scrollToAndTap(tester, find.text('Termini di Servizio'));
      await tester.pumpAndSettle();
      expect(harness.externalUrlService.launchedUrls, hasLength(1));
      harness.viewModel.setCity('Isernia');
      await tester.pump();
      await scrollToAndTap(tester, find.text('Informativa sulla privacy'));
      await tester.pumpAndSettle();
      expect(harness.externalUrlService.launchedUrls, hasLength(2));

      harness.viewModel.setCity('Termoli');
      await tester.pump();
      final laterBack = tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.text('Salva ed esci'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      expect(await laterBack, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed exit releases a later submit boundary', (tester) async {
      final draftRepository = FakeContentSubmissionDraftRepository(
        saveDraftResult: Result.error(Exception('exit checkpoint failed')),
      );
      final repository = ControllableSubmissionRepository();
      addTearDown(
        () => repository.completeSubmission(Result.error(Exception())),
      );
      final harness = createHarness(
        draftRepository: draftRepository,
        submissionRepository: repository,
      );
      addTearDown(harness.dispose);
      await harness.pumpForm(tester, withGallerySentinel: true);
      await fillValidForm(tester);

      final exitAttempt = tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('Salva ed esci'));
      expect(await exitAttempt, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ContentSubmissionScreen), findsOneWidget);

      draftRepository.saveDraftResult = const Result.success(null);
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Invia'))
          .onPressed!();
      await tester.pump();
      await tester.pump();

      expect(draftRepository.saveDraftCallCount, 2);
      expect(repository.submitCallCount, 1);
      expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'failed progress Home uses the parent exit policy and releases the '
      'form handoff',
      (tester) async {
        final draftRepository = FakeContentSubmissionDraftRepository();
        final repository = ControllableSubmissionRepository();
        final harness = createHarness(
          draftRepository: draftRepository,
          submissionRepository: repository,
        );
        addTearDown(harness.dispose);
        await harness.pumpForm(tester, withGallerySentinel: true);
        await fillValidForm(tester);

        await scrollToAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Invia'),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(ContentSubmissionProgressScreen), findsOneWidget);
        repository.completeSubmission(
          Result.error(Exception('remote failure')),
        );
        await tester.pump();
        await tester.pump();

        final submittedIdentity = harness.viewModel.state.clientSubmissionId;
        harness.viewModel.setCity('Isernia');
        await tester.pump();
        await tester.tap(find.text('Torna alla home'));
        await tester.pump();

        expect(find.text('Salva ed esci'), findsOneWidget);
        expect(draftRepository.clearDraftCallCount, 0);
        expect(repository.submitCallCount, 1);

        await tester.tap(find.text('Esci senza salvare'));
        await tester.pumpAndSettle();

        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.home,
        );
        expect(draftRepository.clearDraftCallCount, 0);
        expect(harness.viewModel.state.clientSubmissionId, submittedIdentity);
        expect(find.byType(ContentSubmissionProgressScreen), findsNothing);

        unawaited(harness.router.pushNamed(RouteNames.contentSubmission));
        await tester.pumpAndSettle();
        expect(find.byType(ContentSubmissionScreen), findsOneWidget);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          RoutePaths.home,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

final class _ContentSubmissionRouteHarness {
  _ContentSubmissionRouteHarness({
    required this.draftRepository,
    required this.stagedAssetRepository,
    required this.imagePicker,
    required this.submissionRepository,
    required this.externalUrlService,
  }) {
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
    viewModel = _RecordingContentSubmissionViewModel(
      logger: MockLogger(),
      contentSubmissionRepository: submissionRepository,
      draftRepository: draftRepository,
      stagedAssetRepository: stagedAssetRepository,
      imagePicker: imagePicker,
    );
    urlLaunchService = UrlLaunchService(
      logger: MockLogger(),
      externalUrlService: externalUrlService,
    );
    router = buildAppRouter(
      syncViewModel: syncViewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  final FakeContentSubmissionDraftRepository draftRepository;
  final FakeContentSubmissionStagedAssetRepository stagedAssetRepository;
  final FakeImagePicker imagePicker;
  final ControllableSubmissionRepository submissionRepository;
  final FakeExternalUrlService externalUrlService;
  late final ControllableAdminAuth auth;
  late final GoRouter router;
  late final SyncViewModel syncViewModel;
  late final _RecordingContentSubmissionViewModel viewModel;
  late final UrlLaunchService urlLaunchService;

  Future<void> pumpForm(
    WidgetTester tester, {
    bool withGallerySentinel = false,
    bool settleAfterPush = true,
  }) async {
    router.go(
      withGallerySentinel ? RoutePaths.gallery : RoutePaths.contentSubmission,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: FakeEventRepository()),
          Provider<PlaceRepository>.value(value: FakePlaceRepository()),
          Provider<SearchRepository>.value(value: FakeSearchRepository()),
          ChangeNotifierProvider<ContentSubmissionViewModel>.value(
            value: viewModel,
          ),
          ChangeNotifierProvider<SyncViewModel>.value(value: syncViewModel),
          Provider<UrlLaunchService>.value(value: urlLaunchService),
        ],
        child: MaterialApp.router(
          scaffoldMessengerKey: $scaffoldMessengerKey,
          routerConfig: router,
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('it')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    if (withGallerySentinel) {
      unawaited(router.push(RoutePaths.contentSubmission));
      if (settleAfterPush) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump();
      }
    }
  }

  void dispose() {
    router.dispose();
    auth.dispose();
    syncViewModel.dispose();
    viewModel.dispose();
  }
}

/// Counts public lifecycle calls while executing the real ViewModel behavior.
final class _RecordingContentSubmissionViewModel
    extends ContentSubmissionViewModel {
  _RecordingContentSubmissionViewModel({
    required super.logger,
    required super.contentSubmissionRepository,
    required super.draftRepository,
    required super.stagedAssetRepository,
    super.imagePicker,
  });

  int checkpointCallCount = 0;
  int restoreCallCount = 0;

  @override
  Future<Result<void>> checkpointDraft() {
    checkpointCallCount++;
    return super.checkpointDraft();
  }

  @override
  Future<Result<void>> restoreCheckpointDraft() {
    restoreCallCount++;
    return super.restoreCheckpointDraft();
  }
}
