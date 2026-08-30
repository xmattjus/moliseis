import 'dart:async' show Completer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_gotrue_client.dart';

void main() {
  group('AdminDashboardScreen', () {
    late ControllableAdminAuth auth;
    late FakeAdminContentSubmissionRepository repository;
    late AdminSubmissionsViewModel viewModel;
    late GoRouter router;

    setUp(() {
      auth = ControllableAdminAuth();
      repository = FakeAdminContentSubmissionRepository();
      viewModel = AdminSubmissionsViewModel(repository: repository);
      router = GoRouter(
        initialLocation: '/dashboard',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => AdminDashboardScreen(
              viewModel: viewModel,
              authViewModel: auth.viewModel,
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
              body: Column(
                children: <Widget>[
                  TextButton(
                    onPressed: () => context.pop(true),
                    child: const Text('CREATE_EDITOR_MARKER'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('CREATE_EDITOR_NO_RESULT'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/editor/:id',
            name: RouteNames.adminSubmissionEditor,
            builder: (context, _) => Scaffold(
              body: Column(
                children: <Widget>[
                  TextButton(
                    onPressed: () => context.pop(true),
                    child: const Text('EDIT_EDITOR_MARKER'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('EDIT_EDITOR_NO_RESULT'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      router.dispose();
      viewModel.dispose();
      auth.dispose();
    });

    testWidgets('shows loading while the initial list request is pending', (
      tester,
    ) async {
      final pending = Completer<Result<List<AdminSubmission>>>();
      repository.pendingList = pending;
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(find.text('Caricamento in corso...'), findsOneWidget);

      pending.complete(const Result.success(<AdminSubmission>[]));
      await tester.pumpAndSettle();

      expect(find.text('Nessun contributo da mostrare'), findsOneWidget);
    });

    testWidgets('retries after a list error', (tester) async {
      repository.listResult = Result.error(TestException('list failed'));
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Impossibile caricare i contributi'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);

      repository.listResult = const Result.success(<AdminSubmission>[]);
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repository.listCallCount, 2);
      expect(find.text('Nessun contributo da mostrare'), findsOneWidget);
    });

    testWidgets('shows the empty state after loading an empty list', (
      tester,
    ) async {
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Nessun contributo da mostrare'), findsOneWidget);
    });

    testWidgets('renders loaded submission details', (tester) async {
      final submission = sampleAdminSubmission();
      repository.listResult = Result.success(<AdminSubmission>[submission]);
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text(submission.name), findsOneWidget);
      expect(find.text(submission.city), findsOneWidget);
      expect(find.text('Luogo · Da revisionare'), findsOneWidget);
      expect(find.textContaining('${submission.userName} ·'), findsOneWidget);
    });

    testWidgets('filters loaded submissions through a status chip', (
      tester,
    ) async {
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
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text(pending.name), findsOneWidget);
      expect(find.text(accepted.name), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Accettati'));
      await tester.pump();

      expect(find.text(pending.name), findsNothing);
      expect(find.text(accepted.name), findsOneWidget);
    });

    testWidgets('shows an empty state when a filter has no matches', (
      tester,
    ) async {
      final pending = sampleAdminSubmission();
      repository.listResult = Result.success(<AdminSubmission>[pending]);
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Accettati'));
      await tester.pump();

      expect(find.text(pending.name), findsNothing);
      expect(
        find.text('Nessun contributo corrisponde al filtro selezionato'),
        findsOneWidget,
      );
    });

    testWidgets('opens the editor for a tapped submission', (tester) async {
      final submission = sampleAdminSubmission();
      repository.listResult = Result.success(<AdminSubmission>[submission]);
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CustomInkWell));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.uri.path, '/editor/1');
      expect(find.text('EDIT_EDITOR_MARKER'), findsOneWidget);
    });

    testWidgets('opens the create editor from the header action', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Nuovo contributo'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.uri.path, '/new');
      expect(find.text('CREATE_EDITOR_MARKER'), findsOneWidget);
    });

    testWidgets('navigates home before executing logout', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.byTooltip('Esci'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.logout));
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/home');
      verify(() => auth.client.signOut()).called(1);

      await tester.pumpAndSettle();

      expect(find.text('HOME_MARKER'), findsOneWidget);
    });

    testWidgets('reloads after an editor reports a change', (tester) async {
      final submission = sampleAdminSubmission();
      repository.listResult = Result.success(<AdminSubmission>[submission]);
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CustomInkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT_EDITOR_MARKER'));
      await tester.pumpAndSettle();

      expect(repository.listCallCount, 2);
    });

    testWidgets('reloads after either editor route returns without a result', (
      tester,
    ) async {
      final submission = sampleAdminSubmission();
      repository.listResult = Result.success(<AdminSubmission>[submission]);
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuovo contributo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREATE_EDITOR_NO_RESULT'));
      await tester.pumpAndSettle();
      expect(repository.listCallCount, 2);

      await tester.tap(find.byType(CustomInkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT_EDITOR_NO_RESULT'));
      await tester.pumpAndSettle();
      expect(repository.listCallCount, 3);
    });

    testWidgets('serializes a fresh reload when an older list is active on '
        'editor return', (tester) async {
      final oldSubmission = sampleAdminSubmission(name: 'Old submission');
      final refreshedSubmission = sampleAdminSubmission(
        name: 'Refreshed submission',
      );
      final initialList = Completer<Result<List<AdminSubmission>>>();
      final refreshedList = Completer<Result<List<AdminSubmission>>>();
      repository.pendingList = initialList;
      unawaited(viewModel.load.execute());

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.tap(find.text('Nuovo contributo'));
      await tester.pumpAndSettle();

      repository.pendingList = refreshedList;
      await tester.tap(find.text('CREATE_EDITOR_NO_RESULT'));
      await tester.pump();
      initialList.complete(Result.success(<AdminSubmission>[oldSubmission]));
      await tester.pump();
      await tester.pump();

      expect(repository.listCallCount, 2);
      expect(find.text(oldSubmission.name), findsNothing);

      refreshedList.complete(
        Result.success(<AdminSubmission>[refreshedSubmission]),
      );
      await tester.pumpAndSettle();

      expect(find.text(refreshedSubmission.name), findsOneWidget);
      expect(find.text(oldSubmission.name), findsNothing);
    });
  });
}
