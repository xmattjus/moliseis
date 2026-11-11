import 'dart:async' show Completer, unawaited;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/extensions/date_time_extensions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_gotrue_client.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  testWidgets('private row masks wrap at narrow large text size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final submission = sampleAdminSubmission(
      userName: 'Synthetic contributor with a long display name',
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: AdminSubmissionListItem(summary: submission, onTap: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(
        of: find.text(submission.userName),
        matching: find.byType(SentryMask),
      ),
      findsOneWidget,
    );
    final locale = Localizations.localeOf(
      tester.element(find.byType(AdminSubmissionListItem)),
    );
    final date = find.text(' · ${submission.createdAt.formatDate(locale)}');
    expect(date, findsOneWidget);
    expect(
      find.ancestor(of: date, matching: find.byType(SentryMask)),
      findsNothing,
    );
  });

  for (final status in AdminSubmissionStatus.values) {
    testWidgets('original row title and city remain private for $status', (
      tester,
    ) async {
      final submission = sampleAdminSubmission(
        status: status,
        name: 'PRIVATE_ORIGINAL_TITLE',
        city: 'PRIVATE_ORIGINAL_CITY',
      );
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSubmissionListItem(
              summary: submission,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final value in [
        submission.name,
        submission.city,
        submission.userName,
      ]) {
        expect(find.text(value), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text(value),
            matching: find.byType(SentryMask),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.ancestor(
          of: find.text('Luogo · ${status.label}'),
          matching: find.byType(SentryMask),
        ),
        findsNothing,
      );
      await tester.tap(find.text(submission.name));
      expect(taps, 1);
    });
  }

  group('AdminDashboardScreen', () {
    late ControllableAdminAuth auth;
    late FakeAdminContentSubmissionRepository repository;
    late AdminSubmissionsViewModel viewModel;
    late GoRouter router;
    late ValueNotifier<AdminSubmissionsViewModel> owner;
    bool? editorChanged;

    setUp(() {
      editorChanged = true;
      auth = ControllableAdminAuth(initialUser: makeAuthUser(isAdmin: true));
      repository = FakeAdminContentSubmissionRepository();
      viewModel = AdminSubmissionsViewModel(repository: repository);
      owner = ValueNotifier(viewModel);
      router = GoRouter(
        initialLocation: '/dashboard',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard',
            name: RouteNames.adminDashboard,
            builder: (_, _) => ValueListenableBuilder(
              valueListenable: owner,
              builder: (_, currentOwner, _) => AdminDashboardScreen(
                key: ValueKey(currentOwner),
                viewModel: currentOwner,
                authViewModel: auth.viewModel,
              ),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
          ),
          GoRoute(
            path: '/new',
            name: RouteNames.adminSubmissionNew,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(editorChanged),
                child: const Text('CREATE_EDITOR_MARKER'),
              ),
            ),
          ),
          GoRoute(
            path: '/editor/:id',
            name: RouteNames.adminSubmissionEditor,
            builder: (context, state) => Scaffold(
              key: ValueKey('editor_${state.pathParameters['id']}'),
              body: TextButton(
                onPressed: () => context.pop(editorChanged),
                child: const Text('EDIT_EDITOR_MARKER'),
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      clearAppSnackBars();
      owner.dispose();
      router.dispose();
      viewModel.dispose();
      auth.dispose();
    });

    testOwnerUI(
      'ignored source without pending can be reactivated and returned '
      'proposal opened',
      (tester) async {
        repository
          ..ignoredSourcesResult = const Result.success([
            AdminIgnoredSource(
              id: 12,
              provider: 'eventimolise',
              externalId: 'a',
              name: 'Ignored source',
              ignoredAt: '2026-10-02T10:00:00Z',
            ),
          ])
          ..unIgnoreResult = const Result.success(
            AdminEventResolution(outcome: 'unignored', pendingId: 8),
          );
        final initialRead = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initialRead;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Fonti ignorate'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fonti ignorate'));
        await tester.pumpAndSettle();
        expect(find.text('Ignored source'), findsOneWidget);
        expect(viewModel.items, isEmpty);
        repository
          ..ignoredSourcesResult = const Result.success([])
          ..listResult = Result.success([sampleAdminSubmission(id: 8)]);
        await tester.tap(find.text('Riattiva fonte'));
        await tester.pumpAndSettle();
        expect(repository.unIgnoreCalls, [12]);
        expect(find.text('Fonte riattivata'), findsOneWidget);
        expect(find.text('Nessuna fonte ignorata'), findsOneWidget);
        expect(viewModel.items.single.id, 8);
        await tester.tap(find.text('Apri revisione in attesa'));
        await tester.pumpAndSettle();
        expect(find.text('EDIT_EDITOR_MARKER'), findsOneWidget);
        expect(find.byKey(const ValueKey('editor_8')), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'un-ignore failure keeps ignored row reachable with feedback',
      (tester) async {
        repository
          ..ignoredSourcesResult = const Result.success([
            AdminIgnoredSource(
              id: 12,
              provider: 'eventimolise',
              externalId: 'a',
              name: 'Ignored source',
              ignoredAt: '2026-10-02T10:00:00Z',
            ),
          ])
          ..unIgnoreResult = Result.error(TestException('Failed'));
        final initialRead = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initialRead;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Fonti ignorate'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fonti ignorate'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Riattiva fonte'));
        await tester.pumpAndSettle();
        expect(find.text('Ignored source'), findsOneWidget);
        expect(
          find.text('Impossibile riattivare la fonte. Riprova.'),
          findsOneWidget,
        );
        expect(find.text('Apri revisione in attesa'), findsNothing);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'shows loading while the initial list request is pending',
      (tester) async {
        final pending = Completer<Result<List<AdminSubmission>>>();
        repository.pendingList = pending;
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pump();

        expect(find.text('Caricamento in corso...'), findsOneWidget);

        pending.complete(const Result.success(<AdminSubmission>[]));
        await tester.pumpAndSettle();

        expect(find.text('Nessun contributo da mostrare'), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'retries after a list error',
      (tester) async {
        repository.listResult = Result.error(TestException('list failed'));
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Impossibile caricare i contributi'), findsOneWidget);
        expect(find.text('Riprova'), findsOneWidget);

        repository.listResult = const Result.success(<AdminSubmission>[]);
        await tester.tap(find.text('Riprova'));
        await tester.pumpAndSettle();

        expect(repository.listCallCount, 2);
        expect(find.text('Nessun contributo da mostrare'), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'shows the empty state after loading an empty list',
      (tester) async {
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nessun contributo da mostrare'), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'renders loaded submission details',
      (tester) async {
        final submission = sampleAdminSubmission();
        repository.listResult = Result.success(<AdminSubmission>[submission]);
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(submission.name), findsOneWidget);
        expect(find.text(submission.city), findsOneWidget);
        expect(find.text('Luogo · Da revisionare'), findsOneWidget);
        expect(find.text(submission.userName), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text(submission.userName),
            matching: find.byType(SentryMask),
          ),
          findsOneWidget,
        );
        final locale = Localizations.localeOf(
          tester.element(find.byType(AdminSubmissionListItem)),
        );
        for (final privateText in [submission.name, submission.city]) {
          expect(
            find.ancestor(
              of: find.text(privateText),
              matching: find.byType(SentryMask),
            ),
            findsOneWidget,
          );
        }
        for (final publicText in [
          'Luogo · Da revisionare',
          ' · ${submission.createdAt.formatDate(locale)}',
        ]) {
          expect(find.text(publicText), findsOneWidget);
          expect(
            find.ancestor(
              of: find.text(publicText),
              matching: find.byType(SentryMask),
            ),
            findsNothing,
          );
        }
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'filters loaded submissions through a status control',
      (tester) async {
        final pending = sampleAdminSubmission(
          name: 'Contributo da revisionare',
        );
        final accepted = sampleAdminSubmission(
          id: 2,
          name: 'Contributo accettato',
          status: AdminSubmissionStatus.accepted,
        );
        repository.listResult = Result.success(<AdminSubmission>[
          pending,
          accepted,
        ]);
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(pending.name), findsOneWidget);
        expect(find.text(accepted.name), findsOneWidget);

        await tester.tap(find.text('Accettati'));
        await tester.pump();

        expect(find.text(pending.name), findsNothing);
        expect(find.text(accepted.name), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'reflects a filter already selected by the view model',
      (tester) async {
        viewModel.setFilter(AdminSubmissionStatus.accepted);

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );

        expect(
          tester.widget<ToggleButtons>(find.byType(ToggleButtons)).isSelected,
          <bool>[false, false, true, false, false],
        );
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'shows an empty state when a filter has no matches',
      (tester) async {
        final pending = sampleAdminSubmission();
        repository.listResult = Result.success(<AdminSubmission>[pending]);
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Accettati'));
        await tester.pump();

        expect(find.text(pending.name), findsNothing);
        expect(
          find.text('Nessun contributo corrisponde al filtro selezionato'),
          findsOneWidget,
        );
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'opens the editor for a tapped submission',
      (tester) async {
        final submission = sampleAdminSubmission();
        repository.listResult = Result.success(<AdminSubmission>[submission]);
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CustomInkWell));
        await tester.pumpAndSettle();

        expect(router.routerDelegate.state.uri.path, '/editor/1');
        expect(find.text('EDIT_EDITOR_MARKER'), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'opens the create editor from the header action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.tap(find.text('Nuovo contributo'));
        await tester.pumpAndSettle();

        expect(router.routerDelegate.state.uri.path, '/new');
        expect(find.text('CREATE_EDITOR_MARKER'), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'executes refresh from the compact overflow menu',
      (tester) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Symbols.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aggiorna'));
        await tester.pumpAndSettle();

        expect(repository.listCallCount, 1);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'keeps status filters usable on a narrow screen',
      (tester) async {
        tester.view
          ..physicalSize = const Size(320, 640)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tutti'), findsOneWidget);
        expect(find.text('Rifiutati'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'pull-to-refresh reloads a short submission list',
      (tester) async {
        repository.listResult = Result.success(<AdminSubmission>[
          sampleAdminSubmission(),
        ]);
        final initialRead = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initialRead;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
        await tester.pumpAndSettle();

        expect(repository.listCallCount, 2);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'navigates home before executing logout',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        expect(find.widgetWithIcon(IconButton, Symbols.logout), findsOneWidget);

        await tester.tap(find.byIcon(Symbols.logout));
        await tester.pump();

        expect(router.routeInformationProvider.value.uri.path, '/home');
        await pumpCommandTurns(tester);
        expect(auth.signOutCalls, 1);

        await tester.pumpAndSettle();

        expect(find.text('HOME_MARKER'), findsOneWidget);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'reloads after an editor reports a change',
      (tester) async {
        final submission = sampleAdminSubmission();
        repository.listResult = Result.success(<AdminSubmission>[submission]);
        unawaited(viewModel.refreshSubmissions());

        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CustomInkWell));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT_EDITOR_MARKER'));
        await tester.pumpAndSettle();

        expect(repository.listCallCount, 2);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );
    for (final (failure, compact) in [
      ('none', false),
      ('ignored', false),
      ('submissions', false),
      ('both', false),
      ('none', true),
    ]) {
      testOwnerUI(
        'D5/D7 pending link waits for both refreshes: $failure compact=$compact',
        (tester) async {
          if (compact) {
            tester.view
              ..physicalSize = const Size(390, 900)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
          }
          repository.ignoredSourcesResult = const Result.success([
            AdminIgnoredSource(
              id: 12,
              provider: 'eventimolise',
              externalId: 'a',
              name: 'Ignored source',
              ignoredAt: '2026-10-02',
            ),
          ]);
          final initial = viewModel.refreshIgnoredSources();
          await pumpCommandTurns(tester);
          await initial;
          viewModel.setIgnoredFilter();
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          final mutation = Completer<Result<AdminEventResolution>>();
          final ignored = Completer<Result<List<AdminIgnoredSource>>>();
          final submissions = Completer<Result<List<AdminSubmission>>>();
          repository
            ..pendingUnIgnore = mutation
            ..pendingIgnoredList = ignored
            ..pendingList = submissions;
          await tester.tap(find.text('Riattiva fonte'));
          await pumpCommandTurns(tester);
          expect(viewModel.unignoredPendingId, isNull);
          expect(find.text('Apri revisione in attesa'), findsNothing);
          mutation.complete(
            const Result.success(
              AdminEventResolution(outcome: 'unignored', pendingId: 8),
            ),
          );
          await pumpCommandTurns(tester);
          expect(repository.unIgnoreCalls, [12]);
          expect(repository.ignoredListCalls, 2);
          expect(repository.listCallCount, 0);
          expect(viewModel.isUnIgnoring, isTrue);
          expect(viewModel.canOpenPendingSubmission, isFalse);
          expect(find.text('Apri revisione in attesa'), findsNothing);
          ignored.complete(
            failure == 'ignored' || failure == 'both'
                ? Result.error(TestException('ignored refresh'))
                : const Result.success([]),
          );
          await pumpCommandTurns(tester);
          expect(repository.listCallCount, 1);
          expect(viewModel.canOpenPendingSubmission, isFalse);
          expect(find.text('Apri revisione in attesa'), findsNothing);
          submissions.complete(
            failure == 'submissions' || failure == 'both'
                ? Result.error(TestException('submission refresh'))
                : Result.success([sampleAdminSubmission(id: 8)]),
          );
          await pumpCommandTurns(tester);
          await tester.pumpAndSettle();
          expect(viewModel.unIgnoreSnapshot.completed, isTrue);
          expect(viewModel.canOpenPendingSubmission, isTrue);
          expect(viewModel.unignoredPendingId, 8);
          expect(find.text('Fonte riattivata'), findsOneWidget);
          expect(find.text('Apri revisione in attesa'), findsOneWidget);
          await tester.tap(find.text('Apri revisione in attesa'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('editor_8')), findsOneWidget);
          expect(repository.unIgnoreCalls, [12]);
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    for (final compact in [false, true]) {
      testOwnerUI(
        'F4 Logout disabled during external Admin/local pending login compact=$compact',
        (tester) async {
          tester.view
            ..physicalSize = Size(compact ? 390 : 1200, 900)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final login = Completer<AuthResponse>();
          auth.onPassword = () => login.future;
          auth.viewModel.requestLogin((
            email: 'a@example.com',
            password: 'sentinel',
          ));
          await pumpCommandTurns(tester);
          auth
            ..setUser(makeAuthUser(isAdmin: true))
            ..emit(AuthChangeEvent.signedIn);
          await pumpCommandTurns(tester);
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          expect(auth.viewModel.canLogout, isFalse);
          if (compact) {
            await tester.tap(find.byIcon(Symbols.more_vert));
            await tester.pumpAndSettle();
            final logout = tester.widget<MenuItemButton>(
              find.widgetWithText(MenuItemButton, 'Logout'),
            );
            expect(logout.onPressed, isNull);
            await tester.tap(find.text('Logout'));
          } else {
            final logout = tester.widget<IconButton>(
              find.widgetWithIcon(IconButton, Symbols.logout),
            );
            expect(logout.onPressed, isNull);
            await tester.tap(find.byIcon(Symbols.logout));
          }
          await pumpCommandTurns(tester);
          expect(router.state.uri.path, '/dashboard');
          expect(auth.signOutCalls, 0);
          login.complete(
            AuthResponse(
              user: auth.client.currentUser,
              session: auth.client.currentSession,
            ),
          );
          await pumpCommandTurns(tester);
          await tester.pumpAndSettle();
          expect(auth.viewModel.canLogout, isTrue);
          if (compact) {
            expect(
              tester
                  .widget<MenuItemButton>(
                    find.widgetWithText(MenuItemButton, 'Logout'),
                  )
                  .onPressed,
              isNotNull,
            );
          } else {
            expect(
              tester
                  .widget<IconButton>(
                    find.widgetWithIcon(IconButton, Symbols.logout),
                  )
                  .onPressed,
              isNotNull,
            );
          }
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    testOwnerUI(
      'F4 stale enabled Logout callback is rejected without navigation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        final callback = tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Symbols.logout))
            .onPressed!;
        final login = Completer<AuthResponse>();
        auth.onPassword = () => login.future;
        auth.viewModel.requestLogin((email: 'a', password: 'sentinel'));
        callback();
        expect(router.state.uri.path, '/dashboard');
        expect(auth.signOutCalls, 0);
        login.complete(AuthResponse());
        await pumpCommandTurns(tester);
        expect(auth.signOutCalls, 0);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'R4 admitted Logout reentrant navigation causes no local Home go',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        var moved = false;
        final locations = <String>[];
        router.routeInformationProvider.addListener(() {
          locations.add(router.routeInformationProvider.value.uri.path);
        });
        auth.viewModel.addListener(() {
          if (!moved && auth.viewModel.isAuthenticating) {
            moved = true;
            router.go('/new');
          }
        });
        await tester.tap(find.byIcon(Symbols.logout));
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(auth.signOutCalls, 1);
        expect(router.state.uri.path, '/new');
        expect(locations, isNot(contains('/home')));
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'R4 replaced Dashboard owner receives no old editor refresh',
      (tester) async {
        repository.listResult = Result.success([sampleAdminSubmission()]);
        final initial = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initial;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CustomInkWell));
        await tester.pumpAndSettle();
        final replacementRepository = FakeAdminContentSubmissionRepository();
        final replacement = AdminSubmissionsViewModel(
          repository: replacementRepository,
        );
        owner.value = replacement;
        await tester.pump();
        await tester.tap(find.text('EDIT_EDITOR_MARKER'));
        await tester.pumpAndSettle();
        expect(repository.listCallCount, 1);
        expect(replacementRepository.listCallCount, 0);
        expect(tester.takeException(), isNull);
        replacement.dispose();
        await pumpPhysicalCommandDisposal(tester);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'F2 stale pending callback cannot navigate during new mutation',
      (tester) async {
        repository.unIgnoreResult = const Result.success(
          AdminEventResolution(outcome: 'unignored', pendingId: 8),
        );
        viewModel.requestUnIgnore(12);
        for (var phase = 0; phase < 4; phase++) {
          await pumpCommandTurns(tester);
        }
        viewModel.setIgnoredFilter();
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        final callback = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Apri revisione in attesa'),
            )
            .onPressed!;
        final mutation = Completer<Result<AdminEventResolution>>();
        repository.pendingUnIgnore = mutation;
        expect(viewModel.requestUnIgnore(12), isTrue);
        callback();
        expect(router.state.uri.path, '/dashboard');
        mutation.complete(Result.error(TestException('second mutation')));
        await pumpCommandTurns(tester);
        expect(viewModel.canOpenPendingSubmission, isFalse);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );
    for (final ignored in [false, true]) {
      testOwnerUI(
        'R4 replaced owner rejects captured retry ignored=$ignored',
        (tester) async {
          if (ignored) {
            viewModel.setIgnoredFilter();
            repository.ignoredSourcesResult = Result.error(
              TestException('read'),
            );
            final read = viewModel.refreshIgnoredSources();
            await pumpCommandTurns(tester);
            await read;
          } else {
            repository.listResult = Result.error(TestException('read'));
            final read = viewModel.refreshSubmissions();
            await pumpCommandTurns(tester);
            await read;
          }
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          final VoidCallback callback;
          if (ignored) {
            callback = tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Riprova'))
                .onPressed!;
          } else {
            callback = tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Riprova'),
                )
                .onPressed!;
          }
          final oldCalls = [...repository.dashboardCalls];
          final replacementRepository = FakeAdminContentSubmissionRepository();
          final replacement = AdminSubmissionsViewModel(
            repository: replacementRepository,
          );
          owner.value = replacement;
          await tester.pumpAndSettle();
          callback();
          await pumpCommandTurns(tester);
          expect(repository.dashboardCalls, oldCalls);
          expect(replacementRepository.dashboardCalls, isEmpty);
          expect(tester.takeException(), isNull);
          replacement.dispose();
          await pumpPhysicalCommandDisposal(tester);
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    testOwnerUI(
      'R4 unmounted Dashboard rejects captured editor callback',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        final callback = tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed!;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        callback();
        await pumpCommandTurns(tester);
        expect(tester.takeException(), isNull);
        expect(repository.listCallCount, 0);
        expect(router.state.uri.path, '/dashboard');
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    for (final changed in [true, false, null]) {
      testOwnerUI(
        'D1 editor return $changed while stale read is active',
        (tester) async {
          editorChanged = changed;
          repository.listResult = Result.success([sampleAdminSubmission()]);
          final initial = viewModel.refreshSubmissions();
          await pumpCommandTurns(tester);
          await initial;
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(CustomInkWell));
          await tester.pumpAndSettle();
          final stale = Completer<Result<List<AdminSubmission>>>();
          repository.pendingList = stale;
          final oldRead = viewModel.refreshSubmissions();
          await pumpCommandTurns(tester);
          expect(repository.listCallCount, 2);
          await tester.tap(find.text('EDIT_EDITOR_MARKER'));
          await pumpCommandTurns(tester);
          expect(repository.listCallCount, 2);
          stale.complete(
            Result.success([sampleAdminSubmission(name: 'Stale')]),
          );
          await pumpCommandTurns(tester);
          await oldRead;
          expect(repository.listCallCount, 2);
          await tester.pumpAndSettle();
          expect(repository.dashboardCalls, ['list', 'list']);
          expect(viewModel.items.single.name, 'Stale');
          if (changed == true) {
            repository
              ..pendingList = null
              ..listResult = Result.success([
                sampleAdminSubmission(name: 'Updated after manual refresh'),
              ]);
            await tester.tap(find.byIcon(Symbols.sync));
            await tester.pumpAndSettle();
            expect(repository.listCallCount, 3);
            expect(viewModel.items.single.name, 'Updated after manual refresh');
          }
          expect(tester.takeException(), isNull);
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    testOwnerUI(
      'F5.8 widget unmounted before editor return registers nothing',
      (tester) async {
        repository.listResult = Result.success([sampleAdminSubmission()]);
        final initial = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initial;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CustomInkWell));
        await tester.pumpAndSettle();
        final replacementRepository = FakeAdminContentSubmissionRepository();
        final replacement = AdminSubmissionsViewModel(
          repository: replacementRepository,
        );
        owner.value = replacement;
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT_EDITOR_MARKER'));
        await tester.pumpAndSettle();
        expect(repository.listCallCount, 1);
        expect(replacementRepository.listCallCount, 0);
        expect(tester.takeException(), isNull);
        replacement.dispose();
        await pumpPhysicalCommandDisposal(tester);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'D1 busy editor refresh has no obligation after widget unmount',
      (tester) async {
        repository.listResult = Result.success([sampleAdminSubmission()]);
        final initial = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initial;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CustomInkWell));
        await tester.pumpAndSettle();
        final stale = Completer<Result<List<AdminSubmission>>>();
        repository.pendingList = stale;
        final oldRead = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await tester.tap(find.text('EDIT_EDITOR_MARKER'));
        await pumpCommandTurns(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        stale.complete(const Result.success([]));
        await pumpCommandTurns(tester);
        await oldRead;
        expect(repository.listCallCount, 2);
        expect(viewModel.items, isEmpty);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    for (final changed in [null, false, true]) {
      testOwnerUI(
        'D3 editor result $changed refreshes both lists '
        'independently of pop value',
        (tester) async {
          editorChanged = changed;
          repository.listResult = Result.success([sampleAdminSubmission()]);
          final initial = viewModel.refreshSubmissions();
          await pumpCommandTurns(tester);
          await initial;
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(CustomInkWell));
          await tester.pumpAndSettle();
          viewModel.setIgnoredFilter();
          await tester.tap(find.text('EDIT_EDITOR_MARKER'));
          await tester.pumpAndSettle();
          expect(repository.listCallCount, 2);
          expect(repository.ignoredListCalls, 1);
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    testOwnerUI(
      'D3 menu and pull refresh the selected ignored list',
      (tester) async {
        viewModel.setIgnoredFilter();
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Symbols.sync));
        await tester.pumpAndSettle();
        expect(repository.ignoredListCalls, 1);
        expect(repository.listCallCount, 0);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(repository.ignoredListCalls, 2);
        expect(repository.listCallCount, 0);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    testOwnerUI(
      'D1 failed main refresh retains rendered rows without initial-error view',
      (tester) async {
        repository.listResult = Result.success([
          sampleAdminSubmission(name: 'Retained row'),
        ]);
        final initial = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initial;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        repository.listResult = Result.error(TestException('refresh failure'));
        await tester.tap(find.byIcon(Symbols.sync));
        await tester.pumpAndSettle();
        expect(viewModel.error, isTrue);
        expect(find.text('Retained row'), findsOneWidget);
        expect(find.text('Impossibile caricare i contributi'), findsNothing);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );
    testOwnerUI(
      'REF ignored failure restores retained sources and authorized feedback',
      (tester) async {
        repository.ignoredSourcesResult = const Result.success([
          AdminIgnoredSource(
            id: 12,
            provider: 'p',
            externalId: 'e',
            name: 'Retained ignored',
            ignoredAt: 'today',
          ),
        ]);
        final initial = viewModel.refreshIgnoredSources();
        await pumpCommandTurns(tester);
        await initial;
        viewModel.setIgnoredFilter();
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        final pending = Completer<Result<List<AdminIgnoredSource>>>();
        repository.pendingIgnoredList = pending;
        await tester.tap(find.byTooltip('Aggiorna i contenuti'));
        await pumpCommandTurns(tester);
        expect(find.text('Retained ignored'), findsNothing);
        pending.complete(
          Result.error(TestException('ignored refresh failure')),
        );
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(find.text('Retained ignored'), findsOneWidget);
        expect(find.text('Tutti'), findsOneWidget);
        expect(
          find.text('Impossibile caricare le fonti ignorate'),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        expect(viewModel.showIgnored, isTrue);
        expect(repository.listCallCount, 0);
        expect(repository.ignoredListCalls, 2);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );

    for (final compact in [false, true]) {
      for (final ignored in [false, true]) {
        testOwnerUI(
          'REF toolbar retains scroll subtree and admits only selected lane '
          'compact=$compact ignored=$ignored',
          (tester) async {
            tester.view
              ..physicalSize = Size(compact ? 400 : 1000, 900)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            repository
              ..listResult = Result.success([
                sampleAdminSubmission(name: 'Retained row'),
              ])
              ..ignoredSourcesResult = const Result.success([
                AdminIgnoredSource(
                  id: 12,
                  provider: 'p',
                  externalId: 'e',
                  name: 'Retained ignored',
                  ignoredAt: 'today',
                ),
              ]);
            final initial = ignored
                ? viewModel.refreshIgnoredSources()
                : viewModel.refreshSubmissions();
            await pumpCommandTurns(tester);
            await initial;
            if (ignored) viewModel.setIgnoredFilter();
            await tester.pumpWidget(
              MaterialApp.router(
                scaffoldMessengerKey: $scaffoldMessengerKey,
                routerConfig: router,
              ),
            );
            await tester.pumpAndSettle();
            final scroll = tester.element(find.byType(NestedScrollView));
            final row = tester.element(
              find.text(ignored ? 'Retained ignored' : 'Retained row'),
            );
            final main = Completer<Result<List<AdminSubmission>>>();
            final sources = Completer<Result<List<AdminIgnoredSource>>>();
            repository
              ..pendingList = main
              ..pendingIgnoredList = sources;
            if (compact) {
              await tester.tap(find.byTooltip('Altro'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Aggiorna'));
            } else {
              await tester.tap(find.byTooltip('Aggiorna i contenuti'));
            }
            await pumpCommandTurns(tester);
            expect(find.text('Caricamento in corso'), findsOneWidget);
            expect(find.text('Annulla').hitTestable(), findsOneWidget);
            expect(find.text('Tutti'), findsNothing);
            expect(
              find.text(ignored ? 'Retained ignored' : 'Retained row'),
              findsNothing,
            );
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            expect(find.byType(RefreshProgressIndicator), findsNothing);
            expect(find.text('Area redazione').hitTestable(), findsOneWidget);
            expect(
              tester.element(
                find.byType(NestedScrollView, skipOffstage: false),
              ),
              same(scroll),
            );
            expect(
              tester.element(
                find.text(
                  ignored ? 'Retained ignored' : 'Retained row',
                  skipOffstage: false,
                ),
              ),
              same(row),
            );
            final pull = tester.widget<RefreshIndicator>(
              find.byType(RefreshIndicator),
            );
            await pull
                .onRefresh(); // Busy refusal must not join the physical read.
            expect(repository.listCallCount, ignored ? 0 : 2);
            expect(repository.ignoredListCalls, ignored ? 2 : 0);
            if (ignored) {
              sources.complete(repository.ignoredSourcesResult);
            } else {
              main.complete(repository.listResult);
            }
            await pumpCommandTurns(tester);
            await tester.pumpAndSettle();
            expect(find.text('Caricamento in corso'), findsNothing);
            expect(find.text('Tutti'), findsOneWidget);
            expect(
              find.text(ignored ? 'Retained ignored' : 'Retained row'),
              findsOneWidget,
            );
            expect(find.byType(SnackBar), findsNothing);
            expect(router.state.uri.path, '/dashboard');
          },
          disposeOwners: () {
            viewModel.dispose();
            auth.dispose();
          },
        );
      }
    }

    for (final compact in [false, true]) {
      for (final ignored in [false, true]) {
        testOwnerUI(
          'REF scrolled loading is centered and excludes retained controls '
          'compact=$compact ignored=$ignored',
          (tester) async {
            tester.view
              ..physicalSize = Size(compact ? 400 : 1000, 900)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              repository
                ..listResult = Result.success([
                  for (var i = 0; i < 30; i++)
                    sampleAdminSubmission(id: i + 1, name: 'Retained row $i'),
                ])
                ..ignoredSourcesResult = Result.success([
                  for (var i = 0; i < 30; i++)
                    AdminIgnoredSource(
                      id: i + 1,
                      provider: 'p',
                      externalId: '$i',
                      name: 'Retained ignored $i',
                      ignoredAt: 'today',
                    ),
                ]);
              final initial = ignored
                  ? viewModel.refreshIgnoredSources()
                  : viewModel.refreshSubmissions();
              await pumpCommandTurns(tester);
              await initial;
              if (ignored) {
                viewModel.setIgnoredFilter();
              } else {
                viewModel.setFilter(AdminSubmissionStatus.pending);
              }
              await tester.pumpWidget(
                MaterialApp.router(
                  scaffoldMessengerKey: $scaffoldMessengerKey,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      // shortcut: test ignored 2x after row fix.
                      textScaler: TextScaler.linear(
                        compact && ignored ? 1.3 : 2,
                      ),
                      padding: const EdgeInsets.only(top: 24),
                    ),
                    child: child!,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -650),
              );
              await tester.pumpAndSettle();
              final scroll = tester.state<NestedScrollViewState>(
                find.byType(NestedScrollView),
              );
              expect(scroll.innerController.position.pixels, greaterThan(0));
              // Expose the toolbar while retaining the inner scroll offset.
              scroll.outerController.jumpTo(0);
              await tester.pumpAndSettle();
              final offset = scroll.innerController.position.pixels;
              final filterFocus = Focus.of(tester.element(find.text('Tutti')));
              expect(filterFocus.canRequestFocus, isTrue);
              final main = Completer<Result<List<AdminSubmission>>>();
              final sources = Completer<Result<List<AdminIgnoredSource>>>();
              repository
                ..pendingList = main
                ..pendingIgnoredList = sources;
              if (compact) {
                await tester.tap(find.byTooltip('Altro'));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Aggiorna'));
              } else {
                await tester.tap(find.byTooltip('Aggiorna i contenuti'));
              }
              await pumpCommandTurns(tester);
              expect(find.text('Area redazione').hitTestable(), findsOneWidget);
              expect(find.byType(ToggleButtons), findsNothing);
              expect(find.byType(AdminSubmissionListItem), findsNothing);
              expect(find.textContaining('Retained ignored'), findsNothing);
              expect(find.bySemanticsLabel('Tutti'), findsNothing);
              expect(
                find.bySemanticsLabel(RegExp('Retained (row|ignored)')),
                findsNothing,
              );
              expect(filterFocus.canRequestFocus, isFalse);
              filterFocus.requestFocus();
              await tester.pump();
              expect(filterFocus.hasFocus, isFalse);
              final cancel = find.text('Annulla');
              expect(cancel.hitTestable(), findsOneWidget);
              final cancelSemantics = tester.getSemantics(cancel);
              expect(
                cancelSemantics.getSemanticsData().hasAction(
                  SemanticsAction.tap,
                ),
                isTrue,
              );
              expect(
                cancelSemantics.getSemanticsData().hint,
                contains('aggiornamento può continuare'),
              );
              expect(find.byType(CircularProgressIndicator), findsOneWidget);
              expect(find.byType(RefreshProgressIndicator), findsNothing);
              final group = find
                  .ancestor(of: cancel, matching: find.byType(Column))
                  .first;
              final appBar = tester.getRect(find.byType(AppBar));
              expect(
                tester.getCenter(group),
                offsetMoreOrLessEquals(
                  Offset((compact ? 400 : 1000) / 2, (appBar.bottom + 900) / 2),
                ),
              );
              await tester.tap(cancel);
              await tester.pump();
              expect(find.text('Caricamento in corso'), findsNothing);
              expect(find.byType(ToggleButtons), findsOneWidget);
              expect(find.bySemanticsLabel('Tutti'), findsOneWidget);
              expect(filterFocus.canRequestFocus, isTrue);
              filterFocus.requestFocus();
              await tester.pump();
              expect(filterFocus.hasFocus, isTrue);
              expect(scroll.innerController.position.pixels, offset);
              expect(viewModel.showIgnored, ignored);
              expect(
                viewModel.filter,
                ignored ? null : AdminSubmissionStatus.pending,
              );
              expect(
                ignored
                    ? viewModel.loadIgnoredSnapshot.isRunning
                    : viewModel.loadSnapshot.isRunning,
                isTrue,
              );
              expect(repository.listCallCount, ignored ? 0 : 2);
              expect(repository.ignoredListCalls, ignored ? 2 : 0);
              if (ignored) {
                sources.complete(repository.ignoredSourcesResult);
              } else {
                main.complete(repository.listResult);
              }
              await pumpCommandTurns(tester);
              await tester.pumpAndSettle();
              expect(scroll.innerController.position.pixels, offset);
              expect(find.byType(SnackBar), findsNothing);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
          disposeOwners: () {
            viewModel.dispose();
            auth.dispose();
          },
        );
      }
    }

    for (final pull in [false, true]) {
      for (final failure in [false, true]) {
        testOwnerUI(
          'REF dismiss pending wait preserves execution and pull settlement '
          'pull=$pull failure=$failure',
          (tester) async {
            repository.listResult = Result.success([
              sampleAdminSubmission(name: 'Retained row'),
            ]);
            final initial = viewModel.refreshSubmissions();
            await pumpCommandTurns(tester);
            await initial;
            await tester.pumpWidget(
              MaterialApp.router(
                scaffoldMessengerKey: $scaffoldMessengerKey,
                routerConfig: router,
              ),
            );
            await tester.pumpAndSettle();
            final pending = Completer<Result<List<AdminSubmission>>>();
            repository.pendingList = pending;
            if (pull) {
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, 300),
              );
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 300));
            } else {
              await tester.tap(find.byTooltip('Aggiorna i contenuti'));
            }
            await pumpCommandTurns(tester);
            var pullSettled = false;
            Future<void>? pullFuture;
            if (pull) {
              // show() returns the already armed gesture's pending Future.
              pullFuture = tester
                  .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
                  .show();
              unawaited(pullFuture.then((_) => pullSettled = true));
            }
            expect(find.text('Caricamento in corso'), findsOneWidget);
            expect(find.text('Annulla').hitTestable(), findsOneWidget);
            await tester.pump(const Duration(seconds: 30));
            expect(pending.isCompleted, isFalse);
            expect(find.text('Annulla').hitTestable(), findsOneWidget);
            await tester.tap(find.text('Annulla'));
            await tester.pump();
            expect(find.text('Retained row'), findsOneWidget);
            expect(find.text('Tutti').hitTestable(), findsOneWidget);
            expect(viewModel.loadSnapshot.isRunning, isTrue);
            expect(viewModel.canRefreshSelectedLane, isFalse);
            expect(pending.isCompleted, isFalse);
            expect(pullSettled, isFalse);
            // Both admission routes must refuse a second read of the busy lane.
            expect(viewModel.startSelectedLaneRefresh(), isNull);
            await tester
                .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                .onRefresh();
            expect(repository.listCallCount, 2);
            expect(find.text('Caricamento in corso'), findsNothing);
            if (failure) {
              pending.complete(
                Result.error(TestException('dismissed failure')),
              );
            } else {
              pending.complete(
                Result.success([
                  sampleAdminSubmission(name: 'Late updated row'),
                ]),
              );
            }
            await pumpCommandTurns(tester);
            if (pullFuture != null) await pullFuture;
            await tester.pumpAndSettle();
            expect(pullSettled, pull);
            expect(viewModel.loadSnapshot.isRunning, isFalse);
            expect(
              find.text(failure ? 'Retained row' : 'Late updated row'),
              findsOneWidget,
            );
            expect(find.text('Caricamento in corso'), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(repository.listCallCount, 2);
          },
          disposeOwners: () {
            viewModel.dispose();
            auth.dispose();
          },
        );
      }
    }

    for (final revoke in [
      'none',
      'selection',
      'cover',
      'owner',
      'auth',
      'back',
      'dispose',
      'logout',
    ]) {
      testOwnerUI(
        'REF delayed failure feedback authority=$revoke',
        (tester) async {
          repository.listResult = Result.success([
            sampleAdminSubmission(name: 'Retained row'),
          ]);
          final initial = viewModel.refreshSubmissions();
          await pumpCommandTurns(tester);
          await initial;
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          final pending = Completer<Result<List<AdminSubmission>>>();
          repository.pendingList = pending;
          await tester.tap(find.byTooltip('Aggiorna i contenuti'));
          await pumpCommandTurns(tester);
          expect(find.text('Caricamento in corso'), findsOneWidget);
          if (revoke == 'back') {
            await tester.tap(find.byType(IconButton).first);
          } else if (revoke == 'dispose') {
            await tester.pumpWidget(const SizedBox.shrink());
          } else if (revoke == 'logout') {
            await tester.tap(find.byTooltip('Esegui il logout'));
          } else if (revoke == 'selection') {
            viewModel
              ..setFilter(AdminSubmissionStatus.accepted)
              ..setFilter(null);
          } else if (revoke == 'cover') {
            unawaited(router.pushNamed<Object?>(RouteNames.adminSubmissionNew));
            await tester.pumpAndSettle();
            router.pop();
          } else if (revoke == 'owner') {
            final replacement = AdminSubmissionsViewModel(
              repository: repository,
            );
            addTearDown(replacement.dispose);
            owner.value = replacement;
          } else if (revoke == 'auth') {
            final old = auth.viewModel.currentUser!;
            auth
              ..setUser(
                makeAuthUser(
                  isAdmin: true,
                  id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
                ),
              )
              ..emit(AuthChangeEvent.userUpdated);
            await pumpCommandTurns(tester);
            auth
              ..setUser(old)
              ..emit(AuthChangeEvent.userUpdated);
          }
          await pumpCommandTurns(tester);
          expect(pending.isCompleted, isFalse);
          expect(repository.listCallCount, 2);
          pending.complete(Result.error(TestException('manual failure')));
          await pumpCommandTurns(tester);
          await tester.pumpAndSettle();
          expect(find.text('Caricamento in corso'), findsNothing);
          expect(
            find.byType(SnackBar),
            revoke == 'none' ? findsOneWidget : findsNothing,
          );
          if (revoke == 'none') {
            expect(
              find.text(
                'Si è verificato un errore durante '
                "l'aggiornamento dei contenuti",
              ),
              findsOneWidget,
            );
            expect(find.text('Retained row'), findsOneWidget);
          }
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    testOwnerUI(
      'REF pull uses unified progress and awaits only its admitted execution',
      (tester) async {
        repository.listResult = Result.success([
          sampleAdminSubmission(name: 'Retained row'),
        ]);
        final initial = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initial;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        final pending = Completer<Result<List<AdminSubmission>>>();
        repository.pendingList = pending;
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpCommandTurns(tester);
        expect(repository.listCallCount, 2);
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Caricamento in corso'), findsOneWidget);
        expect(find.text('Annulla').hitTestable(), findsOneWidget);
        expect(find.text('Tutti'), findsNothing);
        expect(find.text('Retained row'), findsNothing);
        pending.complete(repository.listResult);
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );
    for (final pull in [false, true]) {
      testOwnerUI(
        'REF old lane completion cannot remove newer progress pull=$pull',
        (tester) async {
          final main = Completer<Result<List<AdminSubmission>>>();
          final ignored = Completer<Result<List<AdminIgnoredSource>>>();
          repository
            ..pendingList = main
            ..pendingIgnoredList = ignored;
          await tester.pumpWidget(
            MaterialApp.router(
              scaffoldMessengerKey: $scaffoldMessengerKey,
              routerConfig: router,
            ),
          );
          await tester.pumpAndSettle();
          if (pull) {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, 300),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));
          } else {
            await tester.tap(find.byTooltip('Aggiorna i contenuti'));
          }
          await pumpCommandTurns(tester);
          expect(find.text('Caricamento in corso'), findsOneWidget);
          final staleDismiss = tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Annulla'))
              .onPressed!;
          await tester.tap(find.text('Annulla'));
          await tester.pump();
          await tester.ensureVisible(find.text('Fonti ignorate'));
          await tester.tap(find.text('Fonti ignorate'));
          await pumpCommandTurns(tester);
          expect(viewModel.loadSnapshot.isRunning, isTrue);
          expect(viewModel.loadIgnoredSnapshot.isRunning, isTrue);
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          expect(find.text('Caricamento in corso'), findsNothing);
          ignored.complete(const Result.success([]));
          await pumpCommandTurns(tester);
          repository.pendingIgnoredList =
              Completer<Result<List<AdminIgnoredSource>>>();
          tester
              .state<NestedScrollViewState>(find.byType(NestedScrollView))
              .outerController
              .jumpTo(0);
          await tester.pump();
          await tester.tap(find.byTooltip('Aggiorna i contenuti'));
          await pumpCommandTurns(tester);
          expect(repository.listCallCount, 1);
          expect(repository.ignoredListCalls, 2);
          staleDismiss();
          await tester.pump();
          expect(find.text('Caricamento in corso'), findsOneWidget);
          main.complete(Result.error(TestException('obsolete lane')));
          await pumpCommandTurns(tester);
          expect(find.text('Caricamento in corso'), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          repository.pendingIgnoredList!.complete(const Result.success([]));
          await pumpCommandTurns(tester);
          await tester.pumpAndSettle();
          expect(find.text('Caricamento in corso'), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
        },
        disposeOwners: () {
          viewModel.dispose();
          auth.dispose();
        },
      );
    }

    testOwnerUI(
      'REF handled unexpected failure shows one message and reports once',
      (tester) async {
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final gate = Completer<Result<List<AdminSubmission>>>();
        repository.pendingList = gate;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Aggiorna i contenuti'));
        await pumpCommandTurns(tester);
        final failure = StateError('manual unexpected');
        gate.completeError(failure, StackTrace.current);
        await pumpCommandTurns(tester);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          logger.calls.where((call) => identical(call.error, failure)),
          hasLength(1),
        );
        expect(find.text('Caricamento in corso'), findsNothing);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );
    testOwnerUI(
      'editor-return refresh cannot borrow restored A authority',
      (tester) async {
        repository.listResult = Result.success([sampleAdminSubmission()]);
        final initial = viewModel.refreshSubmissions();
        await pumpCommandTurns(tester);
        await initial;
        await tester.pumpWidget(
          MaterialApp.router(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CustomInkWell));
        await tester.pumpAndSettle();
        final accountA = auth.viewModel.currentUser!;
        auth
          ..setUser(
            makeAuthUser(
              isAdmin: true,
              id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            ),
          )
          ..emit(AuthChangeEvent.userUpdated);
        await pumpCommandTurns(tester);
        auth
          ..setUser(accountA)
          ..emit(AuthChangeEvent.userUpdated);
        await pumpCommandTurns(tester);
        await tester.tap(find.text('EDIT_EDITOR_MARKER'));
        await tester.pumpAndSettle();
        expect(repository.listCallCount, 1);
      },
      disposeOwners: () {
        viewModel.dispose();
        auth.dispose();
      },
    );
    for (final failedInitial in [false, true]) {
      for (final ignored in [false, true]) {
        testOwnerUI(
          'REF empty/error lane pull hides placeholders '
          'ignored=$ignored failedInitial=$failedInitial',
          (tester) async {
            tester.view
              ..physicalSize = const Size(400, 800)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            if (ignored) viewModel.setIgnoredFilter();
            if (failedInitial) {
              repository
                ..listResult = Result.error(TestException('initial failure'))
                ..ignoredSourcesResult = Result.error(
                  TestException('initial failure'),
                );
              final initial = ignored
                  ? viewModel.refreshIgnoredSources()
                  : viewModel.refreshSubmissions();
              await pumpCommandTurns(tester);
              await initial;
            }
            final main = Completer<Result<List<AdminSubmission>>>();
            final sources = Completer<Result<List<AdminIgnoredSource>>>();
            repository
              ..pendingList = main
              ..pendingIgnoredList = sources;
            await tester.pumpWidget(
              MaterialApp.router(
                scaffoldMessengerKey: $scaffoldMessengerKey,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, 300),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));
            await pumpCommandTurns(tester);
            expect(find.byType(RefreshProgressIndicator), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            expect(find.text('Annulla').hitTestable(), findsOneWidget);
            expect(find.text('Tutti'), findsNothing);
            expect(find.text('Nessun contributo da mostrare'), findsNothing);
            expect(find.text('Nessuna fonte ignorata'), findsNothing);
            expect(
              find.text('Impossibile caricare le fonti ignorate'),
              findsNothing,
            );
            expect(
              find.text('Impossibile caricare i contributi'),
              findsNothing,
            );
            expect(find.text('Riprova'), findsNothing);
            expect(find.text('Caricamento in corso...'), findsNothing);
            expect(find.text('Caricamento fonti ignorate...'), findsNothing);
            expect(find.text('Caricamento in corso'), findsOneWidget);
            expect(
              repository.listCallCount,
              ignored ? 0 : (failedInitial ? 2 : 1),
            );
            expect(
              repository.ignoredListCalls,
              ignored ? (failedInitial ? 2 : 1) : 0,
            );
            if (ignored) {
              sources.complete(const Result.success([]));
            } else {
              main.complete(const Result.success([]));
            }
            await pumpCommandTurns(tester);
            await tester.pumpAndSettle();
            expect(find.byType(RefreshProgressIndicator), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
          },
          disposeOwners: () {
            viewModel.dispose();
            auth.dispose();
          },
        );
      }
    }
  });
}
