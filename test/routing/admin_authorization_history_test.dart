import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/routing/admin_route_history.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/admin_draft_repositories.dart';
import '../support/admin_save_route_harness.dart';
import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/sync_harness.dart';

void main() {
  late AdminSaveRouteHarness harness;

  for (final diagnostic in [false, true]) {
    final source = diagnostic ? 'H3 diagnostic' : 'H1 Dashboard';
    testOwnerUI('$source retires under an uninstalled Admin cover', (
      tester,
    ) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      if (diagnostic) {
        unawaited(router.push<void>('/admin/submissions/not-a-number'));
        await tester.pumpAndSettle();
      }
      final protected = find.byType(
        diagnostic ? RouteErrorScreen : AdminDashboardScreen,
      );
      final oldRoute = ModalRoute.of(tester.element(protected))!;
      final navigator = router.routerDelegate.navigatorKey.currentState!;
      final oldPage = navigator.widget.pages.last;
      expect(oldRoute.isCurrent, isTrue);

      unawaited(router.push<void>(RoutePaths.admin));
      await tester.idle();
      final covered = router.routerDelegate.currentConfiguration;
      final cover = covered.last as ImperativeRouteMatch;
      expect(cover.route.name, RouteNames.adminDashboard);
      expect(oldRoute.isCurrent, isTrue);
      expect(navigator.widget.pages.last, same(oldPage));

      harness.auth
        ..setUser(null)
        ..emit(AuthChangeEvent.signedOut);
      await tester.idle();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(oldRoute.isActive, isFalse);
      expect(
        navigator.widget.pages.map((page) => page.name),
        isNot(contains(RouteNames.adminDashboard)),
      );
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(protected, findsNothing);
      expect(tester.takeException(), isNull);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI(
    'H1 sign-out keeps Login current when the Admin cover is installed',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      unawaited(router.push<void>(RoutePaths.admin));
      await tester.pumpAndSettle();
      final dashboards = find.byType(AdminDashboardScreen);
      final cover = ModalRoute.of(tester.element(dashboards.last))!;
      expect(cover.isCurrent, isTrue);

      harness.auth
        ..setUser(null)
        ..emit(AuthChangeEvent.signedOut);
      await tester.idle();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminLoginScreen).hitTestable(), findsOneWidget);
      expect(cover.isActive, isFalse);
      expect(await tester.binding.handlePopRoute(), isFalse);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'H2 direct Admin replacement installs a fresh Dashboard owner and Page',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final dashboard = find.byType(AdminDashboardScreen);
      final oldWidget = tester.widget<AdminDashboardScreen>(dashboard);
      final oldRoute = ModalRoute.of(tester.element(dashboard))!;
      final oldPage =
          router.routerDelegate.navigatorKey.currentState!.widget.pages.single;

      harness.auth
        ..setUser(
          makeAuthUser(id: AdminDraftSessionHarness.accountB, isAdmin: true),
        )
        ..emit(AuthChangeEvent.signedIn);
      await tester.idle();
      await tester.pumpAndSettle();

      final replacement = find.byType(AdminDashboardScreen);
      final newWidget = tester.widget<AdminDashboardScreen>(replacement);
      final newRoute = ModalRoute.of(tester.element(replacement))!;
      final newPage =
          router.routerDelegate.navigatorKey.currentState!.widget.pages.single;
      expect(router.state.uri.path, RoutePaths.admin);
      expect(newRoute, isNot(same(oldRoute)));
      expect(newPage, isNot(same(oldPage)));
      expect(newWidget.viewModel, isNot(same(oldWidget.viewModel)));
      expect(newWidget.viewModel.items, isEmpty);
      expect(harness.repository.listCallCount, 2);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  for (final (accountId, publicAncestry, restore) in [
    (AdminDraftSessionHarness.accountA, false, false),
    (AdminDraftSessionHarness.accountB, false, false),
    (AdminDraftSessionHarness.accountA, true, false),
    (AdminDraftSessionHarness.accountB, true, false),
    (AdminDraftSessionHarness.accountA, false, true),
  ]) {
    final ancestry = publicAncestry ? 'above Home' : 'at the root';
    final request = restore ? ' with an intervening stale restore' : '';
    testOwnerUI('Dashboard renders after rapid authority churn to $accountId '
        '$ancestry$request', (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router as AdminRouteHistoryRouter;
      final cached = Completer<Result<List<AdminSubmission>>>()
        ..complete(Result.success([sampleAdminSubmission(id: 98)]));
      harness.repository.pendingList = cached;
      router.go(publicAncestry ? RoutePaths.home : RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      if (publicAncestry) {
        unawaited(router.push<void>(RoutePaths.admin));
        await tester.pumpAndSettle();
      }

      final dashboard = find.byType(AdminDashboardScreen);
      final oldOwner = tester.widget<AdminDashboardScreen>(dashboard).viewModel;
      final oldRoute = ModalRoute.of(tester.element(dashboard))!;
      expect(oldOwner.items.map((item) => item.id), [98]);
      final oldAuthority = router.admittedAuthority!;
      final oldConfiguration = router.routerDelegate.currentConfiguration;
      final navigator = router.routerDelegate.navigatorKey.currentState!;
      final oldPage = navigator.widget.pages.last;
      final homePage = publicAncestry ? navigator.widget.pages.first : null;

      final pending = Completer<Result<List<AdminSubmission>>>();
      harness.repository.pendingList = pending;
      final oldRead = oldOwner.refreshSubmissions();
      await tester.idle();
      expect(harness.repository.listCallCount, 2);
      harness.repository.pendingList = null;

      harness.auth
        ..setUser(makeAuthUser(id: AdminDraftSessionHarness.accountA))
        ..emit(AuthChangeEvent.userUpdated);
      await tester.idle();
      expect(router.admittedAuthority, isNull);
      harness.auth
        ..setUser(makeAuthUser(isAnonymous: true))
        ..emit(AuthChangeEvent.signedIn);
      await tester.idle();
      expect(harness.auth.viewModel.authority, isNull);
      void restoreOldConfiguration() => router.restore(oldConfiguration);
      // Supersede the pending Login-to-Dashboard request during notification.
      if (restore) harness.auth.viewModel.addListener(restoreOldConfiguration);
      harness.auth
        ..setUser(makeAuthUser(id: accountId, isAdmin: true))
        ..emit(AuthChangeEvent.signedIn);
      await tester.idle();
      if (restore) {
        harness.auth.viewModel.removeListener(restoreOldConfiguration);
      }

      expect(router.state.uri.path, RoutePaths.admin);
      expect(router.admittedAuthority, same(harness.auth.viewModel.authority));
      expect(router.admittedAuthority?.accountId, accountId);
      expect(router.admittedAuthority, isNot(same(oldAuthority)));
      // The original Page is still installed: no frame ran during churn.
      expect(navigator.widget.pages.last, same(oldPage));
      expect(oldOwner.items, isEmpty);
      await oldOwner.refreshSubmissions();
      expect(harness.repository.listCallCount, 2);

      await tester.pumpAndSettle();
      expect(dashboard.hitTestable(), findsOneWidget);
      final newOwner = tester.widget<AdminDashboardScreen>(dashboard).viewModel;
      expect(newOwner, isNot(same(oldOwner)));
      expect(navigator.widget.pages.last, isNot(same(oldPage)));
      expect(oldRoute.isActive, isFalse);
      expect(harness.repository.listCallCount, 3);

      pending.complete(Result.success([sampleAdminSubmission(id: 99)]));
      await pumpCommandTurns(tester);
      await oldRead;
      await tester.pumpAndSettle();
      expect(oldOwner.items, isEmpty);
      expect(newOwner.items, isEmpty);
      expect(harness.repository.listCallCount, 3);

      if (publicAncestry) {
        expect(navigator.widget.pages.first.key, homePage!.key);
      }
      expect(await tester.binding.handlePopRoute(), publicAncestry);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        publicAncestry ? RoutePaths.home : RoutePaths.admin,
      );
      expect(dashboard, publicAncestry ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }, disposeOwners: () => harness.dispose());
  }

  testOwnerUI(
    'authorized Admin push and Back retain the original Dashboard route',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final dashboard = find.byType(AdminDashboardScreen);
      final originalRoute = ModalRoute.of(tester.element(dashboard.first))!;
      final originalPage =
          router.routerDelegate.navigatorKey.currentState!.widget.pages.single;

      final pushed = router.push<void>(RoutePaths.admin);
      await tester.pumpAndSettle();
      expect(
        find.byType(AdminDashboardScreen, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(originalRoute.isCurrent, isFalse);
      expect(originalRoute.isActive, isTrue);
      router.pop();
      await tester.pumpAndSettle();

      await pushed;
      expect(originalRoute.isCurrent, isTrue);
      final restoredPage =
          router.routerDelegate.navigatorKey.currentState!.widget.pages.single;
      expect(restoredPage.key, originalPage.key);
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'H3 public Home remains the Back destination below revoked Admin',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.home);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);

      unawaited(router.push<void>(RoutePaths.admin));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      final staleConfiguration = router.routerDelegate.currentConfiguration;

      harness.auth
        ..setUser(makeAuthUser(id: AdminDraftSessionHarness.accountA))
        ..emit(AuthChangeEvent.userUpdated);
      await tester.idle();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      router.restore(staleConfiguration);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(router.state.uri.path, RoutePaths.home);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'H3 authority loss removes dirty editor and its pageless decision route',
    (tester) async {
      harness = AdminSaveRouteHarness();
      await harness.openEditor(tester);
      harness.owner.setName(
        'Uncheckpointed private value',
        activation: harness.owner.activation,
      );
      await tester.tap(find.byType(CustomBackButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);

      final dialogRoute = ModalRoute.of(
        tester.element(find.byType(UnsavedChangesDialog)),
      )!;
      final editorRoute = ModalRoute.of(
        tester.element(find.byType(AdminSubmissionEditorScreen)),
      )!;
      expect(dialogRoute.isCurrent, isTrue);

      harness.auth
        ..setUser(makeAuthUser(id: AdminDraftSessionHarness.accountA))
        ..emit(AuthChangeEvent.userUpdated);
      await tester.idle();
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminLoginScreen).hitTestable(), findsOneWidget);
      expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(dialogRoute.isActive, isFalse);
      expect(editorRoute.isActive, isFalse);
      expect(harness.local.drafts.saves, isEmpty);
      expect(harness.repository.createInputs, isEmpty);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI('H3 old clean exit cannot admit its parsed target under B', (
    tester,
  ) async {
    harness = AdminSaveRouteHarness(persistedTargets: [1, 2]);
    await harness.openEditor(tester, target: 1);
    final router = harness.router as AdminRouteHistoryRouter;
    final original = harness.auth.viewModel.authority;
    var queued = false;
    harness.owner.addListener(() {
      if (queued || !harness.owner.exitDecisionPending) return;
      queued = true;
      harness.auth
        ..setUser(
          makeAuthUser(id: AdminDraftSessionHarness.accountB, isAdmin: true),
        )
        ..emit(AuthChangeEvent.signedIn);
    });
    final lateAdmissions = <AdminAuthority?>[];
    router.routerDelegate.addListener(() {
      if (router.state.uri.path == '/admin/submissions/2' &&
          !identical(harness.auth.viewModel.authority, original)) {
        lateAdmissions.add(router.admittedAuthority);
      }
    });

    router.go('/admin/submissions/2');
    await tester.idle();
    await tester.pumpAndSettle();

    expect(queued, isTrue);
    expect(lateAdmissions, [null]);
    expect(router.state.uri.path, RoutePaths.admin);
    expect(
      harness.auth.viewModel.authority?.accountId,
      AdminDraftSessionHarness.accountB,
    );
    expect(router.admittedAuthority, same(harness.auth.viewModel.authority));
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.byType(AdminSubmissionEditorScreen), findsNothing);
    expect(harness.repository.getByIdIds, [1]);
  }, disposeOwners: () => harness.dispose());

  testOwnerUI(
    'H4 stale restored Admin state cannot restore old owner after A returns',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.admin);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final dashboard = find.byType(AdminDashboardScreen);
      final oldWidget = tester.widget<AdminDashboardScreen>(dashboard);
      final oldRoute = ModalRoute.of(tester.element(dashboard))!;
      final oldPage =
          router.routerDelegate.navigatorKey.currentState!.widget.pages.single;
      final staleConfiguration = router.routerDelegate.currentConfiguration;

      harness.auth
        ..setUser(null)
        ..emit(AuthChangeEvent.signedOut);
      await tester.idle();
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);

      harness.auth
        ..setUser(
          makeAuthUser(id: AdminDraftSessionHarness.accountA, isAdmin: true),
        )
        ..emit(AuthChangeEvent.signedIn);
      await tester.idle();
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      router.restore(staleConfiguration);
      await tester.pumpAndSettle();

      final restored = find.byType(AdminDashboardScreen);
      final restoredWidget = tester.widget<AdminDashboardScreen>(restored);
      final restoredRoute = ModalRoute.of(tester.element(restored))!;
      final restoredPage =
          router.routerDelegate.navigatorKey.currentState!.widget.pages.single;
      expect(router.state.uri.path, RoutePaths.admin);
      expect(restoredRoute, isNot(same(oldRoute)));
      expect(restoredPage, isNot(same(oldPage)));
      expect(restoredWidget.viewModel, isNot(same(oldWidget.viewModel)));
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'H4 encoded mixed restoration keeps public cover without old Admin',
    (tester) async {
      harness = AdminSaveRouteHarness();
      final router = harness.router..go(RoutePaths.home);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      unawaited(router.push<void>(RoutePaths.admin));
      await tester.pumpAndSettle();
      final oldAdmin = ModalRoute.of(
        tester.element(find.byType(AdminDashboardScreen)),
      )!;
      unawaited(router.push<void>(RoutePaths.settings));
      await tester.pumpAndSettle();
      final settings = find.byType(SettingsScreen);
      final originalCover = ModalRoute.of(tester.element(settings))!;
      final stale = await tester.getRestorationData();

      harness.auth
        ..setUser(
          makeAuthUser(id: AdminDraftSessionHarness.accountB, isAdmin: true),
        )
        ..emit(AuthChangeEvent.signedIn);
      await tester.idle();
      await tester.pumpAndSettle();
      expect(ModalRoute.of(tester.element(settings)), same(originalCover));
      expect(oldAdmin.isActive, isFalse);

      await tester.restoreFrom(stale);
      await tester.pumpAndSettle();
      expect(settings.hitTestable(), findsOneWidget);
      final pages =
          router.routerDelegate.navigatorKey.currentState!.widget.pages;
      expect(pages, hasLength(2));
      expect(
        pages.any((page) => page.name == RouteNames.adminDashboard),
        isFalse,
      );
      expect(
        find.byType(AdminDashboardScreen, skipOffstage: false),
        findsNothing,
      );
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(harness.repository.listCallCount, 1);
      expect(tester.takeException(), isNull);
    },
    disposeOwners: () => harness.dispose(),
  );

  testOwnerUI(
    'H4 running Sync keeps precedence and cannot return to revoked Admin',
    (tester) async {
      final sync = SyncHarness();
      final auth = ControllableAdminAuth(
        initialUser: makeAuthUser(
          id: AdminDraftSessionHarness.accountA,
          isAdmin: true,
        ),
      );
      final app = buildSyncRouterApp(sync, auth: auth);
      final router = app.router..go(RoutePaths.admin);
      await tester.pumpWidget(app.app);
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      sync.viewModel.sync.run(true);
      await pumpSyncRedirects(tester);
      expect(router.state.uri.path, RoutePaths.sync);
      expect(find.byType(SyncScreen), findsOneWidget);

      auth
        ..setUser(null)
        ..emit(AuthChangeEvent.signedOut);
      await tester.idle();
      await pumpSyncRedirects(tester);
      expect(router.state.uri.path, RoutePaths.sync);
      expect(find.byType(AdminLoginScreen), findsNothing);

      sync.release();
      await pumpSyncRedirects(tester);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, RoutePaths.adminLoginLocation);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
