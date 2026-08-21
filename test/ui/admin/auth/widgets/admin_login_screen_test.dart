import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/ui/admin/auth/widgets/admin_login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/mock_gotrue_client.dart';

void main() {
  group('AdminLoginScreen', () {
    testWidgets('renders the editorial login form', (tester) async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        MaterialApp(home: AdminLoginScreen(viewModel: auth.viewModel)),
      );

      expect(find.text('Area redazione'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Accedi'), findsOneWidget);
    });

    testWidgets('validates empty credentials without executing login', (
      tester,
    ) async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);

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
    });

    testWidgets('executes login with a trimmed e-mail address', (tester) async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      when(
        () => auth.client.signInWithPassword(
          email: 'redazione@example.com',
          password: 'password-sicura',
        ),
      ).thenAnswer((_) async {
        auth.setUser(makeAuthUser(isAdmin: true));
        return MockAuthResponse();
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
    });

    testWidgets('shows a generic error after a failed login', (tester) async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
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
        find.text(
          'Accesso non riuscito. Verifica le credenziali e riprova.',
        ),
        findsOneWidget,
      );
    });
  });
}
