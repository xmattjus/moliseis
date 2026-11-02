import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_dashboard_screen.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/admin_draft_repositories.dart';
import '../support/command_test_support.dart';
import '../support/crash_reporting_support.dart';
import '../support/fake_cache_manager.dart';
import '../support/fake_repositories.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';
import '../support/recording_tile_http_client.dart';

void main() {
  group('buildAppRouter admin auth guard', () {
    late _AdminRouteHarness harness;
    testOwnerUI(
      'NAV-03 direct anonymous login Back cannot expose dashboard',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.adminLoginLocation);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(harness.repository.listCallCount, 0);

        expect(await tester.binding.handlePopRoute(), isFalse);
        await tester.pumpAndSettle();
        expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.byType(AdminDashboardScreen), findsNothing);
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects an anonymous user from /admin to the login',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects an anonymous user from an admin child to login',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go('/admin/submissions/12');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects a permanent non-admin user from /admin to login',
      (tester) async {
        harness = _AdminRouteHarness(initialUser: makeAuthUser());

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
        expect(harness.repository.listCallCount, 0);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'keeps an admin user on the dashboard',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.admin);
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'redirects an admin user from the login to the dashboard',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );

        harness.router.go(RoutePaths.adminLoginLocation);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.admin);
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'keeps an anonymous user on settings',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.settings);
        await tester.pumpWidget(harness.app(withSettingsProviders: true));
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.settings);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'keeps an admin user on settings',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );

        harness.router.go(RoutePaths.settings);
        await tester.pumpWidget(harness.app(withSettingsProviders: true));
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.settings);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'refreshes from login to dashboard after an auth event',
      (tester) async {
        harness = _AdminRouteHarness();

        harness.router.go(RoutePaths.adminLoginLocation);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 0);

        harness.auth
          ..setUser(
            makeAuthUser(isAdmin: true, id: AdminDraftSessionHarness.accountA),
          )
          ..emit(AuthChangeEvent.signedIn);
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.admin);
        expect(find.byType(AdminLoginScreen), findsNothing);
        expect(harness.repository.listCallCount, 1);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'refreshes from dashboard to login after a sign-out event',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );

        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(find.byType(AdminDashboardScreen), findsOneWidget);

        harness.auth
          ..setUser(null)
          ..emit(AuthChangeEvent.signedOut);
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, RoutePaths.adminLoginLocation);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'settings entry preserves back navigation after login',
      (tester) async {
        harness = _AdminRouteHarness();
        when(
          () => harness.auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).thenAnswer((_) async {
          harness.auth
            ..setUser(
              makeAuthUser(
                isAdmin: true,
                id: AdminDraftSessionHarness.accountA,
              ),
            )
            ..emit(AuthChangeEvent.signedIn);
          return AuthResponse(
            user: harness.auth.client.currentUser,
            session: harness.auth.client.currentSession,
          );
        });

        harness.router.go(RoutePaths.settings);
        await tester.pumpWidget(harness.app(withSettingsProviders: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Area redazione'));
        await tester.pumpAndSettle();

        expect(
          harness.router.routerDelegate.state.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 0);

        await tester.enterText(
          find.byType(TextFormField).first,
          'redazione@example.com',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'password-sicura',
        );
        await tester.tap(find.text('Accedi'));
        await tester.pumpAndSettle();

        verify(
          () => harness.auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).called(1);
        expect(harness.router.routerDelegate.state.uri.path, RoutePaths.admin);
        expect(harness.repository.listCallCount, 1);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          harness.router.routerDelegate.state.uri.path,
          RoutePaths.settings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    for (final fromSettings in [false, true]) {
      testOwnerUI(
        'R2/R3 event plus pending login completion navigates once settings=$fromSettings',
        (tester) async {
          harness = _AdminRouteHarness();
          final gate = Completer<AuthResponse>();
          harness.auth.onPassword = () => gate.future;
          harness.router.go(
            fromSettings ? RoutePaths.settings : RoutePaths.adminLoginLocation,
          );
          await tester.pumpWidget(
            harness.app(withSettingsProviders: fromSettings),
          );
          await tester.pumpAndSettle();
          if (fromSettings) {
            await tester.tap(find.text('Area redazione'));
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byType(TextFormField).first,
            'staff@example.com',
          );
          await tester.enterText(find.byType(TextFormField).last, 'secret');
          await tester.tap(find.text('Accedi'));
          await pumpCommandTurns(tester);
          expect(harness.auth.passwordCalls, 1);
          harness.auth
            ..setUser(
              makeAuthUser(
                isAdmin: true,
                id: AdminDraftSessionHarness.accountA,
              ),
            )
            ..emit(AuthChangeEvent.signedIn);
          final response = AuthResponse(
            user: harness.auth.client.currentUser,
            session: harness.auth.client.currentSession,
          );
          await tester.pumpAndSettle();
          expect(find.byType(AdminDashboardScreen), findsOneWidget);
          expect(harness.auth.viewModel.canLogout, isFalse);
          expect(harness.repository.listCallCount, 1);
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton &&
                        widget.tooltip == 'Esegui il logout',
                  ),
                )
                .onPressed,
            isNull,
          );
          harness.auth.emit(AuthChangeEvent.signedIn);
          gate.complete(response);
          await tester.pumpAndSettle();
          expect(
            harness.router.routerDelegate.state.uri.path,
            RoutePaths.admin,
          );
          expect(harness.repository.listCallCount, 1);
          expect(harness.auth.viewModel.canLogout, isTrue);
          if (fromSettings) {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(
              harness.router.routerDelegate.state.uri.path,
              RoutePaths.settings,
            );
            expect(find.byType(SettingsScreen), findsOneWidget);
          } else {
            expect(await tester.binding.handlePopRoute(), isFalse);
            expect(find.byType(AdminDashboardScreen), findsOneWidget);
          }
        },
        disposeOwners: () {
          harness.editor.dispose();
          harness.auth.dispose();
          harness.syncViewModel.dispose();
          harness.router.dispose();
        },
      );
    }

    testOwnerUI(
      'R2 logout auth event and completion leave a single protected redirect',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );
        final gate = Completer<void>();
        harness.auth.onSignOut = () async {
          harness.auth
            ..setUser(null)
            ..emit(AuthChangeEvent.signedOut);
          await gate.future;
        };
        harness.router.go(RoutePaths.admin);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        expect(harness.repository.listCallCount, 1);
        expect(harness.auth.viewModel.requestLogout(), isTrue);
        await pumpCommandTurns(tester);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.auth.viewModel.canLogin, isFalse);
        gate.complete();
        await tester.pumpAndSettle();
        harness.auth.emit(AuthChangeEvent.signedOut);
        await tester.pumpAndSettle();
        expect(
          harness.router.routerDelegate.state.uri.path,
          RoutePaths.adminLoginLocation,
        );
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(harness.repository.listCallCount, 1);
        expect(harness.auth.signOutCalls, 1);
        expect(harness.auth.anonymousCalls, 1);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'builds the real create editor route for an admin',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );

        harness.router.go('/admin/submissions/new');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(harness.router.state.uri.path, '/admin/submissions/new');
        expect(find.text('Nuovo contributo'), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    testOwnerUI(
      'W4 owner blocks target replacement during hydration and permits retry',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );
        final oldLoad = Completer<Result<AdminSubmission>>();
        harness.repository.onGetById = (id) => id == 1
            ? oldLoad.future
            : Future.value(
                Result.success(
                  sampleAdminSubmission(
                    id: id,
                    modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                  ),
                ),
              );
        harness.router.go('/admin/submissions/1');
        await tester.pumpWidget(harness.app());
        await pumpCommandTurns(tester);
        final owner = harness.editor;
        final activation = owner.activation;
        expect(harness.repository.getByIdIds, [1]);
        expect(owner.requestLoad(activation: activation), isFalse);
        harness.router.go('/admin/submissions/2');
        // Refusal now happens before replacing the still-loading source page.
        await pumpCommandTurns(tester);
        expect(
          harness.router.routerDelegate.state.uri.path,
          '/admin/submissions/1',
        );
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(owner.submissionId, 1);
        expect(owner.isDisposed, isFalse);
        expect(harness.repository.getByIdIds, [1]);
        oldLoad.complete(
          Result.success(
            sampleAdminSubmission(
              modifiedAtToken: '2026-08-20T00:00:00.000000Z',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(harness.repository.getByIdIds, [1]);
        harness.router.go('/admin/submissions/2');
        await tester.pumpAndSettle();
        expect(harness.editor, same(owner));
        expect(owner.submissionId, 2);
        expect(owner.isActivationCurrent(activation), isFalse);
        expect(harness.repository.getByIdIds, [1, 2]);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    for (final destination in ['replacement', 'auth redirect']) {
      for (final operation in ['save', 'reject', 'delete asset']) {
        for (final outcome in ['success', 'expected error', 'raw failure']) {
          testOwnerUI(
            'W4 RF3.2 $operation $outcome after $destination stays isolated',
            (tester) async {
              harness = _AdminRouteHarness(
                initialUser: makeAuthUser(
                  isAdmin: true,
                  id: AdminDraftSessionHarness.accountA,
                ),
              );
              final logger = MockLogger();
              addTearDown(installCommandTestReporting(logger));
              final saveGate = Completer<Result<AdminSubmission>>();
              final mutationGate = Completer<Result<void>>();
              harness.repository.getByIdResults.addAll({
                1: Result.success(
                  sampleAdminSubmission(
                    modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                    assets: const [
                      AdminSubmissionAsset(
                        id: 7,
                        url: 'https://example.com/asset.jpg',
                        width: 1,
                        height: 1,
                      ),
                    ],
                  ),
                ),
                2: Result.success(
                  sampleAdminSubmission(
                    modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                    id: 2,
                  ),
                ),
              });
              harness.router.go('/admin/submissions/1');
              await tester.pumpWidget(harness.app());
              await tester.pumpAndSettle();
              final oldOwner = tester
                  .widget<AdminSubmissionEditorScreen>(
                    find.byType(AdminSubmissionEditorScreen),
                  )
                  .viewModel;
              switch (operation) {
                case 'save':
                  harness.repository.pendingUpdate = saveGate;
                  oldOwner.setName(
                    'Saved revision',
                    activation: oldOwner.activation,
                  );
                  expect(
                    oldOwner.requestSave(activation: oldOwner.activation),
                    isTrue,
                  );
                case 'reject':
                  harness.repository.pendingReject = mutationGate;
                  expect(
                    oldOwner.requestReject(activation: oldOwner.activation),
                    isTrue,
                  );
                case 'delete asset':
                  harness.repository.pendingDeleteAsset = mutationGate;
                  expect(
                    oldOwner.requestDeleteAsset(
                      7,
                      activation: oldOwner.activation,
                    ),
                    isTrue,
                  );
              }
              await pumpCommandTurns(tester);
              expect(
                switch (operation) {
                  'save' => harness.repository.updateIds,
                  'reject' => harness.repository.rejectIds,
                  _ =>
                    harness.repository.deleteAssetCalls
                        .map((call) => call.$1)
                        .toList(),
                },
                [1],
              );
              if (destination == 'replacement') {
                harness.router.go('/admin/submissions/2');
                await pumpCommandTurns(tester);
                expect(
                  harness.router.routerDelegate.state.uri.path,
                  '/admin/submissions/1',
                );
                Navigator.of(
                  tester.element(find.byType(AdminSubmissionEditorScreen)),
                ).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Text('Covering refused replacement'),
                    ),
                  ),
                );
              } else {
                harness.auth
                  ..setUser(null)
                  ..emit(AuthChangeEvent.signedOut);
              }
              await tester.pumpAndSettle();
              expect(oldOwner.isDisposed, isFalse);
              expect(
                oldOwner.requestSave(activation: oldOwner.activation),
                isFalse,
              );
              final expectedPath = destination == 'replacement'
                  ? '/admin/submissions/1'
                  : RoutePaths.adminLoginLocation;
              expect(
                harness.router.routerDelegate.state.uri.path,
                expectedPath,
              );
              if (destination == 'replacement') {
                expect(
                  find.text('Covering refused replacement'),
                  findsOneWidget,
                );
                expect(oldOwner.submissionId, 1);
              }
              final replacementLoad = oldOwner.loadSnapshot;
              // Exceed the documented upstream notifier teardown window while
              // the revoked owner's physical command must remain retained.
              await tester.pump(const Duration(milliseconds: 50));
              final runtimeError = StateError('late $operation');
              final expectedError = TestException('late expected $operation');
              if (operation == 'save') {
                switch (outcome) {
                  case 'success':
                    harness.repository.getByIdResults[1] = Result.success(
                      sampleAdminSubmission(
                        name: 'Saved revision',
                        modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                      ),
                    );
                    saveGate.complete(
                      Result.success(
                        sampleAdminSubmission(
                          name: 'Saved revision',
                          modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                        ),
                      ),
                    );
                  case 'expected error':
                    saveGate.complete(Result.error(expectedError));
                  case 'raw failure':
                    saveGate.completeError(runtimeError, StackTrace.current);
                }
              } else {
                switch (outcome) {
                  case 'success':
                    mutationGate.complete(const Result.success(null));
                  case 'expected error':
                    mutationGate.complete(Result.error(expectedError));
                  case 'raw failure':
                    mutationGate.completeError(
                      runtimeError,
                      StackTrace.current,
                    );
                }
              }
              await tester.pumpAndSettle();
              await pumpCommandTurns(tester);
              expect(
                harness.router.routerDelegate.state.uri.path,
                expectedPath,
              );
              expect(find.byType(SnackBar), findsNothing);
              expect(
                harness.repository.getByIdIds,
                destination == 'replacement' &&
                        operation == 'save' &&
                        outcome == 'success'
                    ? [1, 1]
                    : [1],
              );
              expect(identical(oldOwner.loadSnapshot, replacementLoad), isTrue);
              expect(
                logger.calls.where(
                  (call) => identical(call.error, runtimeError),
                ),
                hasLength(outcome == 'raw failure' ? 1 : 0),
              );
              expect(tester.takeException(), isNull);
            },
            disposeOwners: () {
              harness.editor.dispose();
              harness.auth.dispose();
              harness.syncViewModel.dispose();
              harness.router.dispose();
            },
          );
        }
      }
    }

    testOwnerUI(
      'unavailable pushed editor pop never authorizes dirty source removal',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );
        harness.repository.getByIdResults[1] = Result.success(
          sampleAdminSubmission(modifiedAtToken: '2026-08-20T00:00:00.000000Z'),
        );
        harness.router.go('/admin/submissions/1');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        final owner = harness.editor;
        final sourceState = tester.state(
          find.byType(AdminSubmissionEditorScreen),
        );
        owner.setName('Captured remote A', activation: owner.activation);
        final gate = Completer<Result<AdminSubmission>>();
        harness.repository.pendingUpdate = gate;
        expect(owner.requestSave(activation: owner.activation), isTrue);
        await pumpCommandTurns(tester);
        owner.setName('Newer source B', activation: owner.activation);
        unawaited(harness.router.push('/admin/submissions/2'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Impossibile aprire'), findsOneWidget);
        expect(owner.isSaveRunning, isTrue);
        expect(owner.submissionId, 1);
        await tester.binding.handlePopRoute();
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          harness.router.routerDelegate.state.uri.path,
          '/admin/submissions/1',
        );
        expect(
          tester.state(find.byType(AdminSubmissionEditorScreen)),
          same(sourceState),
        );
        expect(find.byType(UnsavedChangesDialog), findsNothing);
        expect(owner.name, 'Newer source B');
        expect(owner.isSaveRunning, isTrue);
        gate.complete(
          Result.success(
            sampleAdminSubmission(
              name: 'Captured remote A',
              modifiedAtToken: '2026-08-20T00:00:01.000000Z',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(owner.hasUncheckpointedChanges, isTrue);
        expect(owner.name, 'Newer source B');
        expect(find.byType(AdminSubmissionEditorScreen), findsOneWidget);
        expect(harness.repository.updateIds, [1]);
        expect(tester.takeException(), isNull);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );

    for (final operation in ['save', 'reject']) {
      for (final outcome in ['success', 'expected error', 'raw failure']) {
        testOwnerUI(
          'CR1.${operation == 'save' ? '1' : '2'} $operation $outcome '
          'behind covering route is consumed without effects',
          (tester) async {
            harness = _AdminRouteHarness(
              initialUser: makeAuthUser(
                isAdmin: true,
                id: AdminDraftSessionHarness.accountA,
              ),
            );
            final logger = MockLogger();
            addTearDown(installCommandTestReporting(logger));
            final saveGate = Completer<Result<AdminSubmission>>();
            final rejectGate = Completer<Result<void>>();
            harness.repository.getByIdResults.addAll({
              1: Result.success(
                sampleAdminSubmission(
                  modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                ),
              ),
              2: Result.success(
                sampleAdminSubmission(
                  modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                  id: 2,
                ),
              ),
            });
            harness.router.go('/admin/submissions/1');
            await tester.pumpWidget(harness.app());
            await tester.pumpAndSettle();
            final editorA = tester.state(
              find.byType(AdminSubmissionEditorScreen),
            );
            final ownerA = tester
                .widget<AdminSubmissionEditorScreen>(
                  find.byType(AdminSubmissionEditorScreen),
                )
                .viewModel;
            if (operation == 'save') {
              harness.repository.pendingUpdate = saveGate;
              ownerA.setName('Saved revision', activation: ownerA.activation);
              expect(ownerA.requestSave(activation: ownerA.activation), isTrue);
            } else {
              harness.repository.pendingReject = rejectGate;
              expect(
                ownerA.requestReject(activation: ownerA.activation),
                isTrue,
              );
            }
            await pumpCommandTurns(tester);
            var bPopped = false;
            final coveringNavigator = Navigator.of(
              tester.element(find.byType(AdminSubmissionEditorScreen)),
            );
            final pushed = coveringNavigator.push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => const Scaffold(body: Text('Covering editor')),
              ),
            );
            unawaited(pushed.then((_) => bPopped = true));
            await tester.pumpAndSettle();
            expect(editorA.mounted, isTrue);
            expect(ownerA.isDisposed, isFalse);
            expect(find.text('Covering editor'), findsOneWidget);
            expect(ownerA.submissionId, 1);
            final bSnapshot = ownerA.loadSnapshot;
            final runtimeError = StateError('covered $operation');
            final expectedError = TestException('covered expected $operation');
            if (operation == 'save') {
              switch (outcome) {
                case 'success':
                  harness.repository.getByIdResults[1] = Result.success(
                    sampleAdminSubmission(
                      name: 'Saved revision',
                      modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                    ),
                  );
                  saveGate.complete(
                    Result.success(
                      sampleAdminSubmission(
                        name: 'Saved revision',
                        modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                      ),
                    ),
                  );
                case 'expected error':
                  saveGate.complete(Result.error(expectedError));
                case 'raw failure':
                  saveGate.completeError(runtimeError, StackTrace.current);
              }
            } else {
              switch (outcome) {
                case 'success':
                  rejectGate.complete(const Result.success(null));
                case 'expected error':
                  rejectGate.complete(Result.error(expectedError));
                case 'raw failure':
                  rejectGate.completeError(runtimeError, StackTrace.current);
              }
            }
            await tester.pumpAndSettle();
            await pumpCommandTurns(tester);
            expect(bPopped, isFalse);
            expect(
              harness.router.routerDelegate.state.uri.path,
              '/admin/submissions/1',
            );
            expect(find.byType(SnackBar), findsNothing);
            expect(identical(ownerA.loadSnapshot, bSnapshot), isTrue);
            final snapshot = operation == 'save'
                ? ownerA.saveSnapshot
                : ownerA.rejectSnapshot;
            expect(
              snapshot.completed,
              outcome == 'success',
              reason: '${snapshot.data} / ${ownerA.savePhase}',
            );
            expect(snapshot.hasFailure, outcome != 'success');
            expect(ownerA.isDisposed, isFalse);
            expect(
              logger.calls.where((call) => identical(call.error, runtimeError)),
              hasLength(outcome == 'raw failure' ? 1 : 0),
            );
            coveringNavigator.pop();
            await tester.pumpAndSettle();
            await pumpCommandTurns(tester);
            expect(bPopped, isTrue);
            expect(
              harness.router.routerDelegate.state.uri.path,
              '/admin/submissions/1',
            );
            expect(
              tester.state(find.byType(AdminSubmissionEditorScreen)),
              same(editorA),
            );
            expect(find.byType(SnackBar), findsNothing);
            expect(tester.takeException(), isNull);
          },
          disposeOwners: () {
            harness.editor.dispose();
            harness.auth.dispose();
            harness.syncViewModel.dispose();
            harness.router.dispose();
          },
        );
      }
    }

    for (final dialog in ['Publish', 'Reject']) {
      for (final confirm in [true, false]) {
        testOwnerUI(
          'CR1.3 $dialog dialog Save success keeps the editor open '
          'on ${confirm ? 'confirm' : 'cancel'}',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(800, 1600));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            harness = _AdminRouteHarness(
              initialUser: makeAuthUser(
                isAdmin: true,
                id: AdminDraftSessionHarness.accountA,
              ),
            );
            harness.repository.getByIdResults[1] = Result.success(
              sampleAdminSubmission(
                modifiedAtToken: '2026-08-20T00:00:00.000000Z',
              ),
            );
            harness.router.go(RoutePaths.admin);
            await tester.pumpWidget(harness.app());
            await tester.pumpAndSettle();
            var pops = 0;
            bool? routeResult;
            unawaited(
              harness.router.push<bool>('/admin/submissions/1').then((result) {
                pops++;
                routeResult = result;
              }),
            );
            await tester.pumpAndSettle();
            final owner = tester
                .widget<AdminSubmissionEditorScreen>(
                  find.byType(AdminSubmissionEditorScreen),
                )
                .viewModel;
            final action = find.widgetWithText(
              FilledButton,
              dialog == 'Publish' ? 'Pubblica come luogo' : 'Rifiuta',
            );
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            final gate = Completer<Result<AdminSubmission>>();
            harness.repository.pendingUpdate = gate;
            owner.setName('Saved revision', activation: owner.activation);
            expect(owner.requestSave(activation: owner.activation), isTrue);
            await pumpCommandTurns(tester);
            harness.repository.getByIdResults[1] = Result.success(
              sampleAdminSubmission(
                name: 'Saved revision',
                modifiedAtToken: '2026-08-20T00:00:01.000000Z',
              ),
            );
            gate.complete(
              Result.success(
                sampleAdminSubmission(
                  name: 'Saved revision',
                  modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                ),
              ),
            );
            await tester.pumpAndSettle();
            await pumpCommandTurns(tester);
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(pops, 0);
            expect(
              owner.saveSnapshot.completed,
              isTrue,
              reason: '${owner.saveSnapshot.data} / ${owner.savePhase}',
            );
            await tester.tap(
              confirm
                  ? find.widgetWithText(FilledButton, 'Conferma')
                  : find.widgetWithText(TextButton, 'Annulla'),
            );
            await tester.pumpAndSettle();
            await pumpCommandTurns(tester);
            expect(pops, 0);
            expect(routeResult, isNull);
            expect(
              harness.router.routerDelegate.state.uri.path,
              '/admin/submissions/1',
            );
            expect(harness.repository.rejectIds, isEmpty);
            expect(harness.repository.promoteCalls, isEmpty);
            expect(find.byType(SnackBar), findsNothing);
            expect(tester.takeException(), isNull);
          },
          disposeOwners: () {
            harness.editor.dispose();
            harness.auth.dispose();
            harness.syncViewModel.dispose();
            harness.router.dispose();
          },
        );
        for (final completeBeforeCover in [false, true]) {
          testOwnerUI(
            'CR1.4 $dialog ${confirm ? 'confirm' : 'cancel'} covered dialog '
            '${completeBeforeCover ? 'prior latch' : 'late Save'} '
            'never replays effects',
            (tester) async {
              await tester.binding.setSurfaceSize(const Size(800, 1600));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              harness = _AdminRouteHarness(
                initialUser: makeAuthUser(
                  isAdmin: true,
                  id: AdminDraftSessionHarness.accountA,
                ),
              );
              harness.repository.getByIdResults.addAll({
                1: Result.success(
                  sampleAdminSubmission(
                    modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                  ),
                ),
                2: Result.success(
                  sampleAdminSubmission(
                    modifiedAtToken: '2026-08-20T00:00:00.000000Z',
                    id: 2,
                  ),
                ),
              });
              harness.router.go('/admin/submissions/1');
              await tester.pumpWidget(harness.app());
              await tester.pumpAndSettle();
              final stateA = tester.state(
                find.byType(AdminSubmissionEditorScreen),
              );
              final ownerA = tester
                  .widget<AdminSubmissionEditorScreen>(
                    find.byType(AdminSubmissionEditorScreen),
                  )
                  .viewModel;
              final action = find.widgetWithText(
                FilledButton,
                dialog == 'Publish' ? 'Pubblica come luogo' : 'Rifiuta',
              );
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              await tester.tap(action);
              await tester.pumpAndSettle();
              final dialogContext = tester.element(find.byType(AlertDialog));
              final dialogRoute = ModalRoute.of(dialogContext)!;
              expect(dialogRoute.isCurrent, isTrue);
              final gate = Completer<Result<AdminSubmission>>();
              harness.repository.pendingUpdate = gate;
              ownerA.setName('Saved revision', activation: ownerA.activation);
              expect(ownerA.requestSave(activation: ownerA.activation), isTrue);
              await pumpCommandTurns(tester);
              if (completeBeforeCover) {
                harness.repository.getByIdResults[1] = Result.success(
                  sampleAdminSubmission(
                    name: 'Saved revision',
                    modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                  ),
                );
                gate.complete(
                  Result.success(
                    sampleAdminSubmission(
                      name: 'Saved revision',
                      modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                await pumpCommandTurns(tester);
                expect(find.byType(AlertDialog), findsOneWidget);
              }
              var bPopped = false;
              final coveringNavigator = Navigator.of(dialogContext);
              unawaited(
                coveringNavigator
                    .push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) =>
                            const Scaffold(body: Text('Covering confirmation')),
                      ),
                    )
                    .then((_) => bPopped = true),
              );
              await tester.pumpAndSettle();
              expect(stateA.mounted, isTrue);
              expect(ownerA.isDisposed, isFalse);
              expect(dialogRoute.isCurrent, isFalse);
              expect(find.text('Covering confirmation'), findsOneWidget);
              expect(ownerA.submissionId, 1);
              if (!completeBeforeCover) {
                harness.repository.getByIdResults[1] = Result.success(
                  sampleAdminSubmission(
                    name: 'Saved revision',
                    modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                  ),
                );
                gate.complete(
                  Result.success(
                    sampleAdminSubmission(
                      name: 'Saved revision',
                      modifiedAtToken: '2026-08-20T00:00:01.000000Z',
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                await pumpCommandTurns(tester);
              }
              expect(bPopped, isFalse);
              expect(
                harness.router.routerDelegate.state.uri.path,
                '/admin/submissions/1',
              );
              expect(find.byType(SnackBar), findsNothing);
              coveringNavigator.pop();
              await tester.pump(const Duration(milliseconds: 400));
              await pumpCommandTurns(tester);
              expect(bPopped, isTrue);
              // Coverage permanently revokes this modal even after return,
              // whether Save completed before or after the covering page.
              expect(find.byType(AlertDialog), findsOneWidget);
              await tester.tap(
                confirm
                    ? find.widgetWithText(FilledButton, 'Conferma')
                    : find.widgetWithText(TextButton, 'Annulla'),
              );
              await tester.pumpAndSettle();
              await pumpCommandTurns(tester);
              expect(
                harness.router.routerDelegate.state.uri.path,
                '/admin/submissions/1',
              );
              expect(
                tester
                    .widget<AdminSubmissionEditorScreen>(
                      find.byType(AdminSubmissionEditorScreen),
                    )
                    .viewModel,
                same(ownerA),
              );
              expect(ownerA.submissionId, 1);
              expect(harness.repository.rejectIds, isEmpty);
              expect(harness.repository.promoteCalls, isEmpty);
              expect(find.byType(SnackBar), findsNothing);
              // Session cleanup permits a new explicit interaction without
              // reviving the prior Save receipt or stale moderation intent.
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              await tester.tap(action);
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
              await tester.pumpAndSettle();
              expect(
                harness.router.routerDelegate.state.uri.path,
                '/admin/submissions/1',
              );
              expect(harness.repository.rejectIds, isEmpty);
              expect(harness.repository.promoteCalls, isEmpty);
              expect(tester.takeException(), isNull);
            },
            disposeOwners: () {
              harness.editor.dispose();
              harness.auth.dispose();
              harness.syncViewModel.dispose();
              harness.router.dispose();
            },
          );
        }
      }
    }

    testOwnerUI(
      'shows the route error screen for an invalid submission id',
      (tester) async {
        harness = _AdminRouteHarness(
          initialUser: makeAuthUser(
            isAdmin: true,
            id: AdminDraftSessionHarness.accountA,
          ),
        );

        harness.router.go('/admin/submissions/abc');
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      },
      disposeOwners: () {
        harness.editor.dispose();
        harness.auth.dispose();
        harness.syncViewModel.dispose();
        harness.router.dispose();
      },
    );
  });
}

/// Local harness for the admin auth guard.
///
/// Sync is idle by construction, so it declines every redirect and leaves the
/// admin guard as the only active redirect for these route tests.
final class _AdminRouteHarness {
  _AdminRouteHarness({User? initialUser}) {
    auth = ControllableAdminAuth(initialUser: initialUser);
    repository = FakeAdminContentSubmissionRepository();
    editor = AdminSubmissionEditorViewModel(
      repository: repository,
      contentSubmissionRepository: FakeContentSubmissionRepository(),
      draftSession: local.session,
    )..bindAuth(auth.viewModel);
    settingsRepository = FakeSettingsRepository(
      lastSyncedAt: DateTime.now(),
      contentSyncCursorAt: DateTime.utc(2026, 10, 12),
    );
    syncViewModel = SyncViewModel(
      syncUseCase: SyncUseCase(
        cityRepository: FakeCityRepository(),
        eventRepository: FakeEventRepository(),
        mediaRepository: FakeMediaRepository(),
        placeRepository: FakePlaceRepository(),
        settingsRepository: settingsRepository,
        cursorSource: FakeSyncCursorSource(),
        transactionCoordinator: FakeTransactionCoordinator(),
      ),
    );
    router = buildAppRouter(
      syncViewModel: syncViewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  final local = AdminDraftSessionHarness();
  late final AdminSubmissionEditorViewModel editor;
  late final ControllableAdminAuth auth;
  late final FakeAdminContentSubmissionRepository repository;
  late final FakeSettingsRepository settingsRepository;
  late final SyncViewModel syncViewModel;
  late final GoRouter router;

  /// Builds the minimal provider tree required by each tested route.
  Widget app({bool withSettingsProviders = false}) {
    final logger = MockLogger();

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AdminAuthViewModel>.value(value: auth.viewModel),
        ChangeNotifierProvider<AdminSubmissionEditorViewModel>.value(
          value: editor,
        ),
        Provider<AdminSubmissionDraftRepository>.value(value: local.drafts),
        Provider<AdminContentSubmissionRepository>.value(value: repository),
        Provider<ContentSubmissionRepository>.value(
          value: FakeContentSubmissionRepository(),
        ),
        Provider<CacheManager>.value(value: FakeCacheManager()),
        Provider<http.Client>.value(value: RecordingTileHttpClient()),
        if (withSettingsProviders) ...<SingleChildWidget>[
          Provider<SettingsRepository>.value(value: settingsRepository),
          Provider<Logger>.value(value: logger),
          Provider<UrlLaunchService>(
            create: (_) => UrlLaunchService(logger: logger),
          ),
          ChangeNotifierProvider<ThemeViewModel>(
            create: (_) =>
                ThemeViewModel(settingsRepository: settingsRepository),
          ),
          ChangeNotifierProvider<SettingsViewModel>(
            create: (_) => SettingsViewModel(
              crashReporting: testCrashReporting(
                repository: settingsRepository,
                flag: SentryLoggingFlag(initialValue: false),
              ),
            ),
          ),
        ],
      ],
      child: MaterialApp.router(
        routerConfig: router,
        scaffoldMessengerKey: $scaffoldMessengerKey,
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('en'), Locale('it')],
      ),
    );
  }
}
