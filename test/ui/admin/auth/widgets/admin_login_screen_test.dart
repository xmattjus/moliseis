import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/command_test_support.dart';
import '../../../../support/mock_gotrue_client.dart';

void main() {
  group('AdminLoginScreen', () {
    late ControllableAdminAuth auth;
    testOwnerUI(
      'renders the editorial login form',
      (tester) async {
        auth = ControllableAdminAuth();

        await tester.pumpWidget(
          MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
        );

        expect(find.text('Area redazione'), findsOneWidget);
        expect(find.text('E-mail'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Accedi'), findsOneWidget);
      },
      disposeOwners: () {
        auth.dispose();
      },
    );

    testOwnerUI(
      'validates empty credentials without executing login',
      (tester) async {
        auth = ControllableAdminAuth();

        await tester.pumpWidget(
          MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
        );

        await tester.tap(find.text('Accedi'));
        await tester.pump();

        expect(
          find.text('Inserisci un indirizzo e-mail valido'),
          findsOneWidget,
        );
        expect(find.text('Inserisci la password'), findsOneWidget);
        verifyNever(
          () => auth.client.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
      disposeOwners: () {
        auth.dispose();
      },
    );

    testOwnerUI(
      'executes login with a trimmed e-mail address',
      (tester) async {
        auth = ControllableAdminAuth();
        when(
          () => auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).thenAnswer((_) async {
          auth.setUser(makeAuthUser(isAdmin: true));
          return AuthResponse(
            user: auth.client.currentUser,
            session: auth.client.currentSession,
          );
        });

        await tester.pumpWidget(
          MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          '  redazione@example.com  ',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'password-sicura',
        );
        await tester.tap(find.text('Accedi'));
        await tester.pumpAndSettle();

        verify(
          () => auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).called(1);
      },
      disposeOwners: () {
        auth.dispose();
      },
    );

    testOwnerUI(
      'shows a generic error after a failed login',
      (tester) async {
        auth = ControllableAdminAuth();
        when(
          () => auth.client.signInWithPassword(
            email: 'redazione@example.com',
            password: 'password-sicura',
          ),
        ).thenThrow(const AuthException('invalid credentials'));

        await tester.pumpWidget(
          MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
        );
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

        expect(
          find.text('Accesso non riuscito. Verifica le credenziali e riprova.'),
          findsOneWidget,
        );
      },
      disposeOwners: () {
        auth.dispose();
      },
    );

    testOwnerUI(
      'A5 pending login disables submission and hides password errors',
      (tester) async {
        auth = ControllableAdminAuth();
        final gate = Completer<AuthResponse>();
        auth.onPassword = () => gate.future;
        await tester.pumpWidget(
          MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'staff@example.com',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'PRIVATE-PASSWORD',
        );
        await tester.tap(find.text('Accedi'));
        await pumpCommandTurns(tester);
        expect(auth.passwordCalls, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.last.obscureText, isTrue);
        gate.completeError(const AuthException('PRIVATE-PASSWORD'));
        await pumpCommandTurns(tester);
        expect(
          find.text('Accesso non riuscito. Verifica le credenziali e riprova.'),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .join(),
          isNot(contains('PRIVATE-PASSWORD')),
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
      disposeOwners: () => auth.dispose(),
    );

    testOwnerUI('A5 pending logout also disables the login form', (
      tester,
    ) async {
      auth = ControllableAdminAuth();
      final gate = Completer<void>();
      auth.onSignOut = () => gate.future;
      auth.viewModel.requestLogout();
      await tester.pumpWidget(
        MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
      );
      await pumpCommandTurns(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
      expect(auth.passwordCalls, 0);
      gate.complete();
      await pumpCommandTurns(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    }, disposeOwners: () => auth.dispose());

    testOwnerUI(
      'R4 listener rebinding isolates replacement from old pending login',
      (tester) async {
        auth = ControllableAdminAuth();
        final replacement = ControllableAdminAuth();
        final owner = ValueNotifier<AdminAuthViewModel>(auth.viewModel);
        final gate = Completer<AuthResponse>();
        auth.onPassword = () => gate.future;
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<AdminAuthViewModel>(
              valueListenable: owner,
              builder: (_, current, _) => AdminLoginScreen(viewModel: current),
            ),
          ),
        );
        auth.viewModel.requestLogin((email: 'old', password: 'old'));
        await pumpCommandTurns(tester);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        owner.value = replacement.viewModel;
        await tester.pump();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        auth.setUser(makeAuthUser(isAdmin: true));
        gate.complete(
          AuthResponse(
            user: auth.client.currentUser,
            session: auth.client.currentSession,
          ),
        );
        await pumpCommandTurns(tester);
        expect(replacement.passwordCalls, 0);
        expect(find.text('Accedi'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField).first,
          'new@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'new');
        await tester.tap(find.text('Accedi'));
        await pumpCommandTurns(tester);
        expect(replacement.passwordCalls, 1);
        expect(auth.passwordCalls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        replacement.dispose();
        owner.dispose();
      },
      disposeOwners: () => auth.dispose(),
    );

    testOwnerUI('R4 unmounted login ignores late owner notifications', (
      tester,
    ) async {
      auth = ControllableAdminAuth();
      final gate = Completer<AuthResponse>();
      auth.onPassword = () => gate.future;
      await tester.pumpWidget(
        MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
      );
      auth.viewModel.requestLogin((email: 'old', password: 'old'));
      await pumpCommandTurns(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.setUser(makeAuthUser(isAdmin: true));
      gate.complete(
        AuthResponse(
          user: auth.client.currentUser,
          session: auth.client.currentSession,
        ),
      );
      await pumpCommandTurns(tester);
      expect(tester.takeException(), isNull);
    }, disposeOwners: () => auth.dispose());

    for (final replaceOwner in [false, true]) {
      testOwnerUI(
        'R3/R4 pushed login binds initial/update owner replace=$replaceOwner',
        (tester) async {
          auth = ControllableAdminAuth(
            initialUser: replaceOwner ? null : makeAuthUser(isAdmin: true),
          );
          final replacement = ControllableAdminAuth();
          final owners = ValueNotifier<AdminAuthViewModel>(auth.viewModel);
          final router = GoRouter(
            initialLocation: RoutePaths.settings,
            routes: [
              GoRoute(
                path: RoutePaths.settings,
                builder: (_, _) => const Scaffold(body: Text('Settings base')),
              ),
              GoRoute(
                path: RoutePaths.adminLoginLocation,
                builder: (_, _) => ValueListenableBuilder<AdminAuthViewModel>(
                  valueListenable: owners,
                  builder: (_, owner, _) => AdminLoginScreen(viewModel: owner),
                ),
              ),
              GoRoute(
                path: RoutePaths.admin,
                builder: (_, _) =>
                    const Scaffold(body: Text('Dashboard target')),
              ),
            ],
          );
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();
          unawaited(router.push(RoutePaths.adminLoginLocation));
          await tester.pumpAndSettle();
          if (replaceOwner) {
            expect(find.byType(AdminLoginScreen), findsOneWidget);
            owners.value = replacement.viewModel;
            await tester.pump();
            auth
              ..setUser(makeAuthUser(isAdmin: true))
              ..emit(AuthChangeEvent.signedIn);
            await tester.pumpAndSettle();
            expect(find.byType(AdminLoginScreen), findsOneWidget);
            replacement
              ..setUser(makeAuthUser(isAdmin: true))
              ..emit(AuthChangeEvent.signedIn);
            await tester.pumpAndSettle();
          }
          expect(find.text('Dashboard target'), findsOneWidget);
          expect(find.byType(AdminLoginScreen), findsNothing);
          replacement.emit(AuthChangeEvent.signedIn);
          auth.emit(AuthChangeEvent.signedIn);
          await tester.pumpAndSettle();
          router.pop();
          await tester.pumpAndSettle();
          expect(find.text('Settings base'), findsOneWidget);
          expect(router.canPop(), isFalse);
          await tester.pumpWidget(const SizedBox.shrink());
          replacement.dispose();
          owners.dispose();
          router.dispose();
        },
        disposeOwners: () => auth.dispose(),
      );
    }
  });
}
