import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/mock_gotrue_client.dart';

void main() {
  group('AdminAuthViewModel', () {
    test('treats an anonymous user as non-admin', () {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);

      expect(auth.viewModel.isAdmin, isFalse);
      expect(auth.viewModel.isAnonymous, isTrue);
    });

    test('exposes staff user metadata for an admin user', () {
      final user = makeAuthUser(
        isAdmin: true,
        email: 'redazione@example.com',
        name: 'Redazione Molise Is',
      );
      final auth = ControllableAdminAuth(initialUser: user);
      addTearDown(auth.dispose);

      expect(auth.viewModel.isAdmin, isTrue);
      expect(auth.viewModel.isAnonymous, isFalse);
      expect(auth.viewModel.email, user.email);
      expect(auth.viewModel.displayName, 'Redazione Molise Is');
    });

    test('ignores display_name metadata without name', () {
      final auth = ControllableAdminAuth(
        initialUser: makeAuthUser(
          isAdmin: true,
          displayName: 'Nome dashboard',
        ),
      );
      addTearDown(auth.dispose);

      expect(auth.viewModel.displayName, isNull);
    });

    test('treats a permanent non-admin user as non-admin', () {
      final auth = ControllableAdminAuth(initialUser: makeAuthUser());
      addTearDown(auth.dispose);

      expect(auth.viewModel.isAdmin, isFalse);
      expect(auth.viewModel.isAnonymous, isFalse);
    });

    test('completes login for an admin account', () async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      final user = makeAuthUser(isAdmin: true);
      const credentials = (
        email: 'redazione@example.com',
        password: 'password-sicura',
      );
      when(
        () => auth.client.signInWithPassword(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async {
        auth.setUser(user);
        return MockAuthResponse();
      });

      await auth.viewModel.login.execute(credentials);

      expect(auth.viewModel.login.completed, isTrue);
      expect(auth.viewModel.isAdmin, isTrue);
    });

    test('rejects a non-admin login and restores an anonymous user', () async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      const credentials = (
        email: 'utente@example.com',
        password: 'password-sicura',
      );
      when(
        () => auth.client.signInWithPassword(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async {
        auth.setUser(makeAuthUser());
        return MockAuthResponse();
      });

      await auth.viewModel.login.execute(credentials);

      final user = auth.viewModel.currentUser;
      expect(auth.viewModel.login.error, isTrue);
      verify(() => auth.client.signOut()).called(1);
      expect(user, isNotNull);
      expect(user!.isAnonymous, isTrue);
      expect(user.id, isNotEmpty);
    });

    test('restores a real anonymous user when logging out', () async {
      final auth = ControllableAdminAuth(
        initialUser: makeAuthUser(isAdmin: true),
      );
      addTearDown(auth.dispose);

      await auth.viewModel.logout.execute();

      final user = auth.viewModel.currentUser;
      expect(auth.viewModel.logout.completed, isTrue);
      expect(user, isNotNull);
      expect(user!.isAnonymous, isTrue);
      expect(user.id, isNotEmpty);
    });

    test(
      'refreshes state and notifies listeners after an auth event',
      () async {
        final auth = ControllableAdminAuth();
        addTearDown(auth.dispose);
        var notificationCount = 0;
        auth.viewModel.addListener(() => notificationCount++);

        auth
          ..setUser(makeAuthUser(isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await pumpEventQueue();

        expect(auth.viewModel.isAdmin, isTrue);
        expect(notificationCount, 1);
      },
    );

    test('logs auth stream errors without changing state', () async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      final user = auth.viewModel.currentUser;
      const error = AuthException('Synthetic auth-state failure');

      auth.events.addError(error, StackTrace.current);
      await pumpEventQueue();

      expect(auth.viewModel.currentUser, same(user));
      expect(auth.logger.eventsOfType<AdminAuthStateError>(), hasLength(1));
      expect(
        auth.logger.firstCallOfType<AdminAuthStateError>()!.error,
        same(error),
      );
    });

    test(
      'reports an error when anonymous restoration fails on logout',
      () async {
        final auth = ControllableAdminAuth(
          initialUser: makeAuthUser(isAdmin: true),
        );
        addTearDown(auth.dispose);
        auth.signInAnonymouslyError = const AuthException('restore failed');

        await auth.viewModel.logout.execute();

        expect(auth.viewModel.logout.error, isTrue);
        expect(auth.viewModel.currentUser, isNull);
      },
    );
  });
}
