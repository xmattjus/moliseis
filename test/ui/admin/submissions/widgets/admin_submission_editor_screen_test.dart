import 'dart:async' show Completer, unawaited;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../../support/fake_cache_manager.dart';
import '../../../../support/fake_image_picker.dart';
import '../../../../support/fake_repositories.dart';

void main() {
  group('AdminSubmissionEditorScreen', () {
    late FakeAdminContentSubmissionRepository repository;
    late FakeContentSubmissionRepository contentSubmissionRepository;
    late FakeContentSubmissionDraftRepository draftRepository;
    late AdminSubmissionEditorViewModel viewModel;
    late GoRouter router;
    late Widget app;

    setUp(() {
      repository = FakeAdminContentSubmissionRepository();
      contentSubmissionRepository = FakeContentSubmissionRepository();
      draftRepository = FakeContentSubmissionDraftRepository();
      router = GoRouter(
        initialLocation: '/shell',
        routes: <RouteBase>[
          GoRoute(
            path: '/shell',
            builder: (_, _) => const Scaffold(body: Text('SHELL_MARKER')),
          ),
          GoRoute(
            path: '/editor',
            builder: (_, _) => AdminSubmissionEditorScreen(
              viewModel: viewModel,
            ),
          ),
        ],
      );
      app = MultiProvider(
        providers: <SingleChildWidget>[
          Provider<CacheManager>.value(value: FakeCacheManager()),
          Provider<ContentSubmissionDraftRepository>.value(
            value: draftRepository,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          scaffoldMessengerKey: $scaffoldMessengerKey,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            FlutterQuillLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('en'), Locale('it')],
        ),
      );
    });

    tearDown(() {
      router.dispose();
      viewModel.dispose();
    });

    testWidgets('renders the shared create fields without an asset section', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        creatorName: 'Redattore',
        creatorEmail: 'redattore@example.com',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Nuovo contributo'), findsOneWidget);
      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Dettagli'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Città'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        findsOneWidget,
      );
      expect(find.text('È un evento?'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Crea contributo'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.widgetWithText(FilledButton, 'Crea contributo'),
        findsOneWidget,
      );
      expect(find.text('Foto'), findsNothing);
    });

    testWidgets('shows creator identity read-only without public fields', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        creatorName: 'Redattore',
        creatorEmail: 'redattore@example.com',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Creato come Redattore · redattore@example.com'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.text('Creato come Redattore · redattore@example.com'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Autore'), findsNothing);
      expect(find.byType(CheckboxFormField), findsNothing);
    });

    testWidgets('shows loaded edit details, assets, count, and add control', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          userName: 'Anna Bianchi',
          userEmail: 'anna@example.com',
          assets: <AdminSubmissionAsset>[asset],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Modifica contributo'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Foto'),
        200,
        scrollable: scrollable,
      );
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('admin_submission_delete_asset_2'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('anna@example.com'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Proposto da'), findsOneWidget);
      expect(find.text('Anna Bianchi'), findsOneWidget);
      expect(find.text('anna@example.com'), findsOneWidget);
    });

    testWidgets('unfocuses the editor before opening the asset picker', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingPicker = Completer<XFile?>();
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        imagePicker: FakeImagePicker(
          onPickImage: () => pendingPicker.future,
        ),
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final cityField = find.widgetWithText(TextFormField, 'Città');
      await tester.tap(cityField);
      await tester.pump();
      final cityEditable = find.descendant(
        of: cityField,
        matching: find.byType(EditableText),
      );
      final cityFocusNode = tester.widget<EditableText>(cityEditable).focusNode;
      expect(FocusManager.instance.primaryFocus, same(cityFocusNode));

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final addAsset = find.byKey(
        const ValueKey<String>('admin_submission_add_asset'),
      );
      await tester.scrollUntilVisible(addAsset, 200, scrollable: scrollable);
      expect(FocusManager.instance.primaryFocus, same(cityFocusNode));

      await tester.tap(addAsset);
      await tester.pump();

      expect(viewModel.addAsset.running, isTrue);
      expect(FocusManager.instance.primaryFocus, isNot(same(cityFocusNode)));
      // A keyboard event arriving after the picker starts cannot mutate the
      // draft while the editor's focus barrier is active.
      await tester.enterText(cityField, 'Changed while picking');
      expect(viewModel.city, 'Campobasso');

      pendingPicker.complete(null);
      await tester.pumpAndSettle();
      expect(viewModel.addAsset.completed, isTrue);

      final restoredFocusNode =
          tester.widget<EditableText>(cityEditable).focusNode..requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(restoredFocusNode));
    });

    testWidgets('never loads or saves the public draft after field edits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        'Museo del Tartufo',
      );
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));

      expect(draftRepository.loadDraftCallCount, 0);
      expect(draftRepository.saveDraftCallCount, 0);
    });

    testWidgets('shows an empty pending photo section with an add control', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsOneWidget,
      );
    });

    testWidgets('hides add control at the pending asset limit', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          assets: List<AdminSubmissionAsset>.generate(
            5,
            (index) => AdminSubmissionAsset(
              id: index + 1,
              url: 'https://example.com/photo-$index.jpg',
              width: 640,
              height: 480,
            ),
          ),
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNWidgets(5));
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
    });

    testWidgets('confirms deletion before removing an asset association', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final deleteAsset = find.byKey(
        const ValueKey<String>('admin_submission_delete_asset_2'),
      );
      await tester.tap(deleteAsset);
      await tester.pumpAndSettle();
      expect(
        find.text('Rimuovere questa foto dal suggerimento?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();
      expect(repository.deleteAssetCalls, isEmpty);

      await tester.tap(deleteAsset);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.deleteAssetCalls, <(int, int)>[(1, 2)]);
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsNothing);
    });

    testWidgets('shows a generic error snackbar for add and delete failures', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.accepted,
          assets: const <AdminSubmissionAsset>[asset],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      await viewModel.addAsset.execute();
      await tester.pump();
      expect(viewModel.addAsset.error, isTrue);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();

      await viewModel.deleteAsset.execute(2);
      await tester.pump();
      expect(viewModel.deleteAsset.error, isTrue);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    });

    testWidgets(
      'disables asset, save, and moderation controls while deleting',
      (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pendingDelete = Completer<Result<void>>();
        const asset = AdminSubmissionAsset(
          id: 2,
          url: 'https://example.com/photo.jpg',
          width: 640,
          height: 480,
        );
        repository
          ..getByIdResults[1] = Result.success(
            sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
          )
          ..pendingDeleteAsset = pendingDelete;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();

        unawaited(viewModel.deleteAsset.execute(2));
        await tester.pump();

        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(
                  const ValueKey<String>('admin_submission_add_asset'),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byKey(
                  const ValueKey<String>('admin_submission_delete_asset_2'),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Salva modifiche'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pubblica come luogo'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Rifiuta'),
              )
              .onPressed,
          isNull,
        );

        pendingDelete.complete(const Result.success(null));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('keeps entered text after an asset mutation rebuild', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );

      await viewModel.deleteAsset.execute(2);
      await tester.pumpAndSettle();

      expect(find.text('Isernia'), findsOneWidget);
      expect(viewModel.city, 'Isernia');
      expect(viewModel.isDirty, isTrue);
    });

    testWidgets('disables publish and reject after edits and saves '
        'separately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        200,
        scrollable: scrollable,
      );
      final publishButton = find.widgetWithText(
        FilledButton,
        'Pubblica come luogo',
      );
      final rejectButton = find.widgetWithText(FilledButton, 'Rifiuta');
      expect(tester.widget<FilledButton>(publishButton).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNotNull);
      expect(find.text('Accetta'), findsNothing);

      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Città'),
        200,
        scrollable: scrollable,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        publishButton,
        200,
        scrollable: scrollable,
      );
      expect(tester.widget<FilledButton>(publishButton).onPressed, isNull);
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNull);
      expect(
        find.text('Salva le modifiche prima di pubblicare o rifiutare.'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pumpAndSettle();

      expect(repository.updateIds, <int>[1]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });

    testWidgets('disables moderation while a save request is pending', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingUpdate = Completer<Result<AdminSubmission>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingUpdate = pendingUpdate;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Pubblica come luogo'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Rifiuta'),
            )
            .onPressed,
        isNull,
      );
      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'does not auto-confirm publication when save completes '
      'during confirmation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pendingUpdate = Completer<Result<AdminSubmission>>();
        repository
          ..getByIdResults[1] = Result.success(sampleAdminSubmission())
          ..pendingUpdate = pendingUpdate;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        final publish = find.widgetWithText(
          FilledButton,
          'Pubblica come luogo',
        );
        await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);

        await tester.tap(publish);
        await tester.pump();
        expect(
          find.text(
            'Confermi di voler pubblicare questo contributo come luogo?',
          ),
          findsOneWidget,
        );

        unawaited(viewModel.save.execute());
        await tester.pump();
        expect(viewModel.save.running, isTrue);
        pendingUpdate.complete(Result.success(sampleAdminSubmission()));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Confermi di voler pubblicare questo contributo come luogo?',
          ),
          findsOneWidget,
        );
        expect(repository.promoteCalls, isEmpty);

        await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
        await tester.pumpAndSettle();

        // The save completed while the dialog was open: closing the editor
        // refreshes the dashboard instead of running a stale moderation.
        expect(repository.promoteCalls, isEmpty);
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      },
    );

    testWidgets(
      'does not run a stale rejection when save completes '
      'during its confirmation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pendingUpdate = Completer<Result<AdminSubmission>>();
        repository
          ..getByIdResults[1] = Result.success(sampleAdminSubmission())
          ..pendingUpdate = pendingUpdate;
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        final reject = find.widgetWithText(FilledButton, 'Rifiuta');
        await tester.scrollUntilVisible(reject, 200, scrollable: scrollable);

        await tester.tap(reject);
        await tester.pump();
        expect(
          find.text('Confermi di voler rifiutare questo contributo?'),
          findsOneWidget,
        );

        unawaited(viewModel.save.execute());
        await tester.pump();
        expect(viewModel.save.running, isTrue);
        pendingUpdate.complete(Result.success(sampleAdminSubmission()));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
        await tester.pumpAndSettle();

        expect(repository.rejectIds, isEmpty);
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      },
    );

    testWidgets('rechecks busy state before confirming publication', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingPick = Completer<XFile?>();
      repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        imagePicker: FakeImagePicker(
          onPickImage: () => pendingPick.future,
        ),
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final publish = find.widgetWithText(FilledButton, 'Pubblica come luogo');
      await tester.scrollUntilVisible(publish, 200, scrollable: scrollable);
      await tester.tap(publish);
      await tester.pumpAndSettle();

      unawaited(viewModel.addAsset.execute());
      await tester.pump();
      expect(viewModel.addAsset.running, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pump();

      expect(repository.promoteCalls, isEmpty);
      pendingPick.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('disables save while a rejection request is pending', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingReject = Completer<Result<void>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingReject = pendingReject;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      unawaited(viewModel.reject.execute());
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salva modifiche'),
            )
            .onPressed,
        isNull,
      );
      pendingReject.complete(const Result.success(null));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'keeps edited data on save failure and shows an error snackbar',
      (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository
          ..getByIdResults[1] = Result.success(sampleAdminSubmission())
          ..updateResult = Result.error(TestException('update failed'));
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Città'),
          'Isernia',
        );
        await tester.pump();

        final scrollable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('admin_submission_editor_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, 'Salva modifiche'),
          200,
          scrollable: scrollable,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
        await tester.pumpAndSettle();

        expect(
          find.text('Si è verificato un errore, riprova più tardi'),
          findsOneWidget,
        );
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(viewModel.city, 'Isernia');
        $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
      },
    );

    testWidgets('rejects a clean submission only after confirmation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Rifiuta'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Rifiuta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Confermi di voler rifiutare questo contributo?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();

      expect(repository.rejectIds, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Rifiuta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.rejectIds, <int>[1]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });

    testWidgets('publishes a place draft after explicit confirmation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        200,
        scrollable: scrollable,
      );
      // A place draft offers exactly one publication CTA.
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        findsNothing,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Confermi di voler pubblicare questo contributo come luogo?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
        (1, AdminPromotionTarget.place),
      ]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });

    testWidgets('publishes an event draft as an event', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          startDate: DateTime.utc(2026, 9, 20, 10),
          endDate: DateTime.utc(2026, 9, 20, 12),
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        findsNothing,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Confermi di voler pubblicare questo contributo come evento?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(repository.promoteCalls, <(int, AdminPromotionTarget)>[
        (1, AdminPromotionTarget.event),
      ]);
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });

    testWidgets('keeps event publication CTA and renders a temporal issue', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(startDate: DateTime.utc(2026, 3, 29, 0, 30)),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      viewModel.setStartClockTime(EventClockTime(2, 30));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.textContaining('non esiste in Italia'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        200,
        scrollable: scrollable,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        findsNothing,
      );
    });

    group('promotion error messages', () {
      Future<void> pumpPendingEditor(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
      }

      testWidgets('maps readiness codes to actionable Italian copy', (
        tester,
      ) async {
        for (final entry in <(String?, String)>[
          (
            'PROMOTION_COORDINATES_REQUIRED',
            'Imposta coordinate valide e salva prima di pubblicare.',
          ),
          (
            'PROMOTION_CITY_NOT_FOUND',
            'La città non corrisponde a una località disponibile. '
                'Correggila e salva.',
          ),
          (
            'PROMOTION_START_DATE_REQUIRED',
            "Imposta una data di inizio e salva prima di pubblicare l'evento.",
          ),
          (
            'PROMOTION_TARGET_CONFLICT',
            'Il contributo è già stato pubblicato con un tipo diverso.',
          ),
        ]) {
          await pumpPendingEditor(tester);
          repository.promoteResults
            ..clear()
            ..add(
              Result.error(
                AdminContentSubmissionApiException(
                  statusCode: entry.$1 == 'PROMOTION_TARGET_CONFLICT'
                      ? 409
                      : 422,
                  code: entry.$1,
                  message: 'API failure',
                ),
              ),
            );

          await viewModel.promote.execute(AdminPromotionTarget.place);
          await tester.pump();

          expect(find.text(entry.$2), findsOneWidget);
          $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
          router.go('/shell');
          await tester.pumpAndSettle();
        }
      });
    });

    testWidgets('renders promoted accepted rows read-only with linkage', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.accepted,
          promotion: const AdminSubmissionPromotion(
            target: AdminPromotionTarget.event,
            entityId: 123,
          ),
          assets: const <AdminSubmissionAsset>[
            AdminSubmissionAsset(
              id: 2,
              url: 'https://example.com/photo.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Accettato'), findsOneWidget);
      expect(find.text('Pubblicato come evento · ID 123'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('admin_submission_delete_asset_2'),
        ),
        findsNothing,
      );
      // No moderation or Save controls remain.
      expect(find.widgetWithText(FilledButton, 'Accetta'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, 'Pubblica come evento'),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Rifiuta'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        findsNothing,
      );

      // Attempted interaction leaves the ViewModel untouched: the tap is
      // suppressed by the pointer barrier, so no state can change.
      final cityField = find.widgetWithText(TextFormField, 'Città');
      expect(cityField, findsOneWidget);
      await tester.tap(cityField, warnIfMissed: false);
      await tester.pump();

      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');
      // Requesting focus on the locked field cannot make it primary.
      final lockedNode = _requestFocusOn(tester, cityField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(equals(lockedNode)));
    });

    testWidgets('excludes keyboard focus from locked fields while busy', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingDelete = Completer<Result<void>>();
      const asset = AdminSubmissionAsset(
        id: 2,
        url: 'https://example.com/photo.jpg',
        width: 640,
        height: 480,
      );
      repository
        ..getByIdResults[1] = Result.success(
          sampleAdminSubmission(assets: const <AdminSubmissionAsset>[asset]),
        )
        ..pendingDeleteAsset = pendingDelete;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      unawaited(viewModel.deleteAsset.execute(2));
      await tester.pump();
      expect(viewModel.deleteAsset.running, isTrue);

      final cityField = find.widgetWithText(TextFormField, 'Città');
      // While locked, requesting focus on an inner field never makes it the
      // primary focus.
      final lockedNode = _requestFocusOn(tester, cityField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(equals(lockedNode)));
      expect(viewModel.isDirty, isFalse);

      pendingDelete.complete(const Result.success(null));
      await tester.pumpAndSettle();

      // Unlocked again, the same request focuses the field normally.
      final unlockedNode = _requestFocusOn(tester, cityField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, equals(unlockedNode));
    });

    testWidgets('keeps drafts locked while a save is running and restores '
        'interaction afterwards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingUpdate = Completer<Result<AdminSubmission>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingUpdate = pendingUpdate;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Salva modifiche'),
        200,
        scrollable: scrollable,
      );

      unawaited(viewModel.save.execute());
      await tester.pump();

      // Tapping the city field while saving cannot dirty the editor.
      await tester.tap(
        find.widgetWithText(TextFormField, 'Città'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');

      pendingUpdate.complete(Result.success(sampleAdminSubmission()));
      await tester.pumpAndSettle();
      // The save success pops the editor back to the shell.
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });
    testWidgets('renders historical accepted rows read-only without Save', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.accepted,
          assets: const <AdminSubmissionAsset>[
            AdminSubmissionAsset(
              id: 2,
              url: 'https://example.com/photo.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Accettato'), findsOneWidget);
      // Historical accepted rows carry no durable link and none is invented.
      expect(find.text('Pubblicato come evento · ID 123'), findsNothing);
      expect(
        find.textContaining('Pubblicato come'),
        findsNothing,
      );
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('admin_submission_delete_asset_2'),
        ),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Accetta'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Rifiuta'), findsNothing);
      // The Save control is hidden entirely for read-only rows.
      expect(find.text('Salva modifiche'), findsNothing);

      // Attempted interaction leaves the ViewModel untouched.
      await tester.tap(
        find.widgetWithText(TextFormField, 'Città'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');
    });

    testWidgets('renders rejected rows read-only without Save', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.getByIdResults[1] = Result.success(
        sampleAdminSubmission(
          status: AdminSubmissionStatus.rejected,
          assets: const <AdminSubmissionAsset>[
            AdminSubmissionAsset(
              id: 2,
              url: 'https://example.com/photo.jpg',
              width: 640,
              height: 480,
            ),
          ],
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      expect(find.text('Rifiutato'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('admin_submission_add_asset')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('admin_submission_delete_asset_2'),
        ),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Accetta'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Rifiuta'), findsNothing);
      expect(find.text('Salva modifiche'), findsNothing);

      // Attempted interaction leaves the ViewModel untouched.
      await tester.tap(
        find.widgetWithText(TextFormField, 'Città'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(viewModel.isDirty, isFalse);
      expect(viewModel.city, 'Campobasso');
    });

    testWidgets('shows the profile-specific create failure message', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      repository.createResult = const Result.error(
        AdminContentSubmissionApiException(
          statusCode: 422,
          code: 'ADMIN_PROFILE_INCOMPLETE',
          message: 'Profile is incomplete.',
        ),
      );
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
      );
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Isernia',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        'Palazzo',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crea contributo'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Il profilo amministratore richiede un nome e un'email validi.",
        ),
        findsOneWidget,
      );
      $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    });

    testWidgets('blocks an incomplete event save with a date-section issue', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel =
          AdminSubmissionEditorViewModel(
              repository: repository,
              contentSubmissionRepository: contentSubmissionRepository,
            )
            ..setCity('Isernia')
            ..setName('Sagra del Tartufo')
            ..setEventEnabled(true);
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Crea contributo'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crea contributo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Seleziona una data di inizio.'),
        -200,
        scrollable: scrollable,
      );

      expect(find.text('Seleziona una data di inizio.'), findsOneWidget);
      expect(viewModel.eventTimeIssue, EventTimeIssue.missingStartDate);
      expect(repository.createInputs, isEmpty);
      expect(viewModel.save.result, isNull);
    });

    testWidgets(
      'cancelling an inverted end-date picker preserves the invalid draft',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final originalStart = DateTime.utc(2027, 1, 1, 10);
        final originalEnd = DateTime.utc(2026, 12, 31, 22, 59, 59, 999, 999);
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(startDate: originalStart, endDate: originalEnd),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await tester.pumpWidget(app);
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();

        final endDateChip = find.textContaining('Finisce il');
        await tester.tap(endDateChip);
        await tester.pump();
        expect(find.byType(DatePickerDialog), findsOneWidget);

        var pickerActions = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextButton),
        );
        expect(pickerActions, findsNWidgets(2));
        await tester.tap(pickerActions.first);
        await tester.pumpAndSettle();

        expect(viewModel.startDate, originalStart);
        expect(viewModel.endDate, originalEnd);
        expect(viewModel.isDirty, isFalse);
        expect(repository.updateInputs, isEmpty);
        expect(viewModel.validateEventTimeForSave(), isFalse);
        expect(viewModel.eventTimeIssue, EventTimeIssue.invalidRange);
        await viewModel.save.execute();
        expect(repository.updateInputs, isEmpty);

        await tester.tap(endDateChip);
        await tester.pump();
        pickerActions = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextButton),
        );
        await tester.tap(pickerActions.last);
        await tester.pumpAndSettle();

        expect(viewModel.endCalendarDate, EventCalendarDate(2027, 1, 1));
        expect(viewModel.endDate!.isBefore(viewModel.startDate!), isFalse);
        expect(viewModel.eventTimeIssue, isNull);
        expect(viewModel.isDirty, isTrue);
      },
    );

    group('location section', () {
      Finder scrollableOf(WidgetTester tester) => find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('admin_submission_editor_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;

      Future<void> pushEditor(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        unawaited(router.push('/editor'));
        await tester.pumpAndSettle();
      }

      Future<void> scrollTo(WidgetTester tester, Finder finder) => tester
          .scrollUntilVisible(finder, 200, scrollable: scrollableOf(tester));

      testWidgets('create screen exposes the Posizione section', (
        tester,
      ) async {
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          creatorName: 'Redattore',
          creatorEmail: 'redattore@example.com',
        );
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        expect(find.text('Posizione'), findsOneWidget);
        expect(find.text('Mappa'), findsOneWidget);
        expect(find.text('Coordinate'), findsOneWidget);
        expect(find.byType(GeoMap), findsOneWidget);
      });

      testWidgets('edit screen exposes the Posizione section after load', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        expect(find.text('Posizione'), findsOneWidget);
      });

      testWidgets('loaded coordinates reach the location editor fields', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(latitude: 41.5575078, longitude: 14.6485406),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await pushEditor(tester);

        final latitudeField = find.widgetWithText(
          TextFormField,
          '41.5575078',
          skipOffstage: false,
        );
        final longitudeField = find.widgetWithText(
          TextFormField,
          '14.6485406',
          skipOffstage: false,
        );
        expect(latitudeField, findsOneWidget);
        expect(longitudeField, findsOneWidget);
      });

      testWidgets('mode switching alone does not dirty the editor', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mappa'));
        await tester.pumpAndSettle();

        expect(viewModel.isDirty, isFalse);
      });

      testWidgets('a coordinate edit makes the editor dirty and disables '
          'moderation', (tester) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitudine'),
          '41.55',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitudine'),
          '14.64',
        );
        await tester.pump();
        expect(viewModel.isDirty, isTrue);

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Pubblica come luogo'),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pubblica come luogo'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Rifiuta'),
              )
              .onPressed,
          isNull,
        );
      });

      testWidgets('an invalid location prevents Save', (tester) async {
        repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(latitude: 12.5, longitude: -3),
        );
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await pushEditor(tester);

        // Break the loaded pair into a half-location.
        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitudine'),
          '',
        );
        await tester.pump();

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Salva modifiche'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
        await tester.pumpAndSettle();

        expect(repository.updateIds, isEmpty);
        expect(viewModel.isDirty, isTrue);
      });

      testWidgets('valid blank drafts permit Save directly from Map mode', (
        tester,
      ) async {
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          creatorName: 'Redattore',
          creatorEmail: 'redattore@example.com',
        );
        await pushEditor(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Città'),
          'Isernia',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Luogo o evento'),
          'Museo',
        );
        await tester.pump();

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Crea contributo'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Crea contributo'));
        await tester.pumpAndSettle();

        expect(repository.createInputs, isNotEmpty);
        expect(repository.createInputs.single.latitude, isNull);
        expect(repository.createInputs.single.longitude, isNull);
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      });

      testWidgets('successful Save persists the updated coordinate pair', (
        tester,
      ) async {
        repository.getByIdResults[1] = Result.success(sampleAdminSubmission());
        viewModel = AdminSubmissionEditorViewModel(
          repository: repository,
          contentSubmissionRepository: contentSubmissionRepository,
          submissionId: 1,
        );
        await viewModel.load.execute();
        await pushEditor(tester);

        await scrollTo(tester, find.text('Posizione'));
        await tester.tap(find.text('Coordinate'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitudine'),
          '41.55',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitudine'),
          '14,64',
        );
        await tester.pump();

        await scrollTo(
          tester,
          find.widgetWithText(FilledButton, 'Salva modifiche'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Salva modifiche'));
        await tester.pumpAndSettle();

        expect(repository.updateIds, <int>[1]);
        expect(repository.updateInputs.single.latitude, 41.55);
        expect(repository.updateInputs.single.longitude, 14.64);
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      });
    });
  });
}

/// Requests keyboard focus on the editable text inside [fieldFinder].
///
/// Returns the field's own [FocusNode] so callers can assert whether the
/// request made it the manager's primary focus.
FocusNode _requestFocusOn(WidgetTester tester, Finder fieldFinder) {
  final fieldNode = Focus.of(
    tester.element(
      find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
    ),
  )..requestFocus();
  return fieldNode;
}
