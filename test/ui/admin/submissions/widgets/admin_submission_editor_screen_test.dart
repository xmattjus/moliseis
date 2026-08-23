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
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
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
                find.widgetWithText(FilledButton, 'Accetta'),
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

    testWidgets('disables status actions after edits and saves separately', (
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
        find.widgetWithText(FilledButton, 'Accetta'),
        200,
        scrollable: scrollable,
      );
      final acceptButton = find.widgetWithText(FilledButton, 'Accetta');
      final rejectButton = find.widgetWithText(FilledButton, 'Rifiuta');
      expect(tester.widget<FilledButton>(acceptButton).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNotNull);

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
        find.widgetWithText(FilledButton, 'Accetta'),
        200,
        scrollable: scrollable,
      );
      expect(tester.widget<FilledButton>(acceptButton).onPressed, isNull);
      expect(tester.widget<FilledButton>(rejectButton).onPressed, isNull);
      expect(
        find.text('Salva le modifiche prima di cambiare lo stato.'),
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
              find.widgetWithText(FilledButton, 'Accetta'),
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
      'does not auto-confirm moderation when save completes '
      'during confirmation',
      (
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
        final accept = find.widgetWithText(FilledButton, 'Accetta');
        await tester.scrollUntilVisible(accept, 200, scrollable: scrollable);

        await tester.tap(accept);
        await tester.pump();
        expect(
          find.text('Confermi di accettare questo contributo?'),
          findsOneWidget,
        );

        unawaited(viewModel.save.execute());
        await tester.pump();
        expect(viewModel.save.running, isTrue);
        pendingUpdate.complete(Result.success(sampleAdminSubmission()));
        await tester.pumpAndSettle();

        expect(
          find.text('Confermi di accettare questo contributo?'),
          findsOneWidget,
        );
        expect(repository.changeStatusCalls, isEmpty);

        await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
        await tester.pumpAndSettle();

        expect(repository.changeStatusCalls, isEmpty);
        expect(find.text('SHELL_MARKER'), findsOneWidget);
      },
    );

    testWidgets('rechecks busy state before confirming moderation', (
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
      final accept = find.widgetWithText(FilledButton, 'Accetta');
      await tester.scrollUntilVisible(accept, 200, scrollable: scrollable);
      await tester.tap(accept);
      await tester.pumpAndSettle();

      unawaited(viewModel.addAsset.execute());
      await tester.pump();
      expect(viewModel.addAsset.running, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pump();

      expect(repository.changeStatusCalls, isEmpty);
      pendingPick.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('disables save while a moderation request is pending', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pendingChangeStatus = Completer<Result<void>>();
      repository
        ..getByIdResults[1] = Result.success(sampleAdminSubmission())
        ..pendingChangeStatus = pendingChangeStatus;
      viewModel = AdminSubmissionEditorViewModel(
        repository: repository,
        contentSubmissionRepository: contentSubmissionRepository,
        submissionId: 1,
      );
      await viewModel.load.execute();
      await tester.pumpWidget(app);
      unawaited(router.push('/editor'));
      await tester.pumpAndSettle();

      unawaited(viewModel.changeStatus.execute(AdminSubmissionStatus.accepted));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salva modifiche'),
            )
            .onPressed,
        isNull,
      );
      pendingChangeStatus.complete(const Result.success(null));
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

      expect(repository.changeStatusCalls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Rifiuta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(
        repository.changeStatusCalls,
        <(int, AdminSubmissionStatus)>[
          (1, AdminSubmissionStatus.rejected),
        ],
      );
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });

    testWidgets('accepts a clean submission after confirmation', (
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
        find.widgetWithText(FilledButton, 'Accetta'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Accetta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Confermi di accettare questo contributo?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await tester.pumpAndSettle();

      expect(
        repository.changeStatusCalls,
        <(int, AdminSubmissionStatus)>[
          (1, AdminSubmissionStatus.accepted),
        ],
      );
      expect(find.text('SHELL_MARKER'), findsOneWidget);
    });

    testWidgets('shows only the accepted label while keeping save enabled', (
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
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salva modifiche'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('shows only the rejected label while keeping save enabled', (
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
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salva modifiche'),
            )
            .onPressed,
        isNotNull,
      );
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
  });
}
