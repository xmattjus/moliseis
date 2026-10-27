import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result_command.dart';
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
        initialUser: makeAuthUser(isAdmin: true, displayName: 'Nome dashboard'),
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
        return AuthResponse(
          user: auth.client.currentUser,
          session: auth.client.currentSession,
        );
      });

      expect(auth.viewModel.requestLogin(credentials), isTrue);
      await pumpEventQueue();

      expect(auth.viewModel.loginSnapshot.completed, isTrue);
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
        return AuthResponse(
          user: auth.client.currentUser,
          session: auth.client.currentSession,
        );
      });

      expect(auth.viewModel.requestLogin(credentials), isTrue);
      await pumpEventQueue();

      final user = auth.viewModel.currentUser;
      expect(auth.viewModel.loginSnapshot.hasFailure, isTrue);
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

      expect(auth.viewModel.requestLogout(), isTrue);
      await pumpEventQueue();

      final user = auth.viewModel.currentUser;
      expect(auth.viewModel.logoutSnapshot.completed, isTrue);
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

    test('revokes private authority and logs auth stream errors', () async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      auth
        ..setUser(makeAuthUser(isAdmin: true))
        ..emit(AuthChangeEvent.signedIn);
      await pumpEventQueue();
      expect(auth.viewModel.isAdmin, isTrue);
      const error = AuthException('Synthetic auth-state failure');

      auth.events.addError(error, StackTrace.current);
      await pumpEventQueue();

      expect(auth.viewModel.currentUser, isNull);
      expect(auth.viewModel.isAdmin, isFalse);
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

        expect(auth.viewModel.requestLogout(), isTrue);
        await pumpEventQueue();

        expect(auth.viewModel.logoutSnapshot.hasFailure, isTrue);
        expect(auth.viewModel.currentUser, isNull);
      },
    );

    test('A2 wrong credentials remain expected and release the gate', () async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      auth.onPassword = () async => throw const AuthException('invalid');
      expect(
        auth.viewModel.requestLogin((email: 'a', password: 'secret')),
        isTrue,
      );
      await pumpEventQueue();
      expect(auth.viewModel.loginSnapshot.domainError, isA<AuthException>());
      expect(auth.logger.eventsOfType<AdminAuthLoginFailed>(), hasLength(1));
      expect(auth.viewModel.canLogin, isTrue);
    });

    test(
      'A5 gate reserves before entry and preserves admitted credentials',
      () async {
        final auth = ControllableAdminAuth();
        addTearDown(auth.dispose);
        final gate = Completer<AuthResponse>();
        auth.onPassword = () => gate.future;
        expect(
          auth.viewModel.requestLogin((email: 'first', password: 'sentinel')),
          isTrue,
        );
        expect(auth.viewModel.canLogout, isFalse);
        expect(
          auth.viewModel.requestLogin((email: 'second', password: 'other')),
          isFalse,
        );
        expect(auth.viewModel.requestLogout(), isFalse);
        await pumpEventQueue();
        expect(auth.passwordCalls, 1);
        expect(auth.capturedEmail, 'first');
        expect(auth.capturedPassword, 'sentinel');
        expect((auth.viewModel.loginSnapshot as dynamic).paramData, isNull);
        auth
          ..setUser(makeAuthUser(isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await pumpEventQueue();
        expect(auth.viewModel.isAdmin, isTrue);
        expect(auth.viewModel.canLogout, isFalse);
        gate.complete(
          AuthResponse(
            user: auth.client.currentUser,
            session: auth.client.currentSession,
          ),
        );
        await pumpEventQueue();
        expect(auth.viewModel.canLogout, isTrue);
        expect(auth.signOutCalls, 0);
      },
    );

    for (final adminB in [false, true]) {
      test(
        'A6 response A never cleans different current B admin=$adminB',
        () async {
          final auth = ControllableAdminAuth();
          addTearDown(auth.dispose);
          final a = makeAuthUser();
          final b = makeAuthUser(isAdmin: adminB);
          final gate = Completer<AuthResponse>();
          auth.onPassword = () => gate.future;
          auth.viewModel.requestLogin((email: 'a', password: 'secret'));
          await pumpEventQueue();
          auth
            ..setUser(b)
            ..emit(AuthChangeEvent.signedIn);
          gate.complete(AuthResponse(user: a, session: makeAuthSession(a)));
          await pumpEventQueue();
          expect(auth.viewModel.loginSnapshot.hasFailure, isTrue);
          expect(auth.viewModel.currentUser, same(b));
          expect(auth.signOutCalls, 0);
          expect(auth.anonymousCalls, 0);
        },
      );
    }

    for (final variant in [
      'missing',
      'inconsistent',
      'replaced',
      'missing-user',
      'missing-session',
      'null-current',
      'anonymous-current',
    ]) {
      test(
        'A3 rejects uncorrelated $variant session without cleanup',
        () async {
          final auth = ControllableAdminAuth();
          addTearDown(auth.dispose);
          final user = makeAuthUser(isAdmin: true);
          final session = makeAuthSession(user);
          auth.onPassword = () async {
            auth.setSession(switch (variant) {
              'replaced' => makeAuthSession(user),
              'null-current' => null,
              'anonymous-current' => makeAuthSession(
                makeAuthUser(isAnonymous: true),
              ),
              _ => session,
            });
            if (variant == 'missing-user') {
              final response = MockAuthResponse();
              when(() => response.user).thenReturn(null);
              when(() => response.session).thenReturn(session);
              return response;
            }
            if (variant == 'missing-session') return AuthResponse(user: user);
            return variant == 'missing'
                ? AuthResponse()
                : AuthResponse(
                    user: variant == 'inconsistent' ? makeAuthUser() : user,
                    session: session,
                  );
          };
          auth.viewModel.requestLogin((email: 'a', password: 'secret'));
          await pumpEventQueue();
          expect(auth.viewModel.loginSnapshot.hasFailure, isTrue);
          expect(auth.signOutCalls, 0);
          expect(auth.anonymousCalls, 0);
        },
      );
    }

    test(
      'A6 reentrant session replacement before cleanup is protected',
      () async {
        final auth = ControllableAdminAuth();
        addTearDown(auth.dispose);
        final a = makeAuthUser();
        final b = makeAuthUser();
        auth.onPassword = () async {
          auth.setUser(a);
          return AuthResponse(user: a, session: auth.client.currentSession);
        };
        auth.viewModel.addListener(() {
          if (identical(auth.viewModel.currentUser, a)) auth.setUser(b);
        });
        auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        await pumpEventQueue();
        expect(auth.signOutCalls, 0);
        expect(auth.client.currentUser, same(b));
      },
    );

    test(
      'A6 external identity after cleanup entry prevents anonymous restore',
      () async {
        final auth = ControllableAdminAuth();
        addTearDown(auth.dispose);
        final a = makeAuthUser();
        final b = makeAuthUser();
        final signOut = Completer<void>();
        auth.onPassword = () async {
          auth.setUser(a);
          return AuthResponse(user: a, session: auth.client.currentSession);
        };
        auth.onSignOut = () => signOut.future;
        auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        await pumpEventQueue();
        expect(auth.signOutCalls, 1);
        auth.setUser(b);
        signOut.complete();
        await pumpEventQueue();
        expect(auth.anonymousCalls, 0);
        expect(auth.viewModel.currentUser, same(b));
      },
    );

    for (final clear in [false, true]) {
      test(
        'A4 signOut failure after clear=$clear uses actual session',
        () async {
          final auth = ControllableAdminAuth(
            initialUser: makeAuthUser(isAdmin: true),
          );
          addTearDown(auth.dispose);
          auth.onSignOut = () async {
            if (clear) auth.setUser(null);
            throw const AuthException('signout failed');
          };
          auth.viewModel.requestLogout();
          await pumpEventQueue();
          expect(auth.viewModel.logoutSnapshot.completed, clear);
          expect(auth.anonymousCalls, clear ? 1 : 0);
        },
      );
    }

    test('A8 dispose before entry makes no SDK call', () async {
      final auth = ControllableAdminAuth();
      auth.viewModel.requestLogin((email: 'a', password: 'secret'));
      auth.dispose();
      await pumpEventQueue();
      expect(auth.passwordCalls, 0);
      expect(auth.viewModel.requestLogout(), isFalse);
    });

    test(
      'A8 pending login disposal prevents cleanup and notifications',
      () async {
        final auth = ControllableAdminAuth();
        final gate = Completer<AuthResponse>();
        auth.onPassword = () => gate.future;
        auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        await pumpEventQueue();
        final frozen = auth.viewModel.loginSnapshot;
        var notifications = 0;
        auth.viewModel.addListener(() => notifications++);
        auth
          ..dispose()
          ..setUser(makeAuthUser());
        gate.complete(
          AuthResponse(
            user: auth.client.currentUser,
            session: auth.client.currentSession,
          ),
        );
        await pumpEventQueue();
        expect(auth.signOutCalls, 0);
        expect(auth.anonymousCalls, 0);
        expect(notifications, 0);
        expect(auth.viewModel.loginSnapshot, same(frozen));
      },
    );

    test(
      'E3 terminal admission waits until old upstream finally has exited',
      () async {
        final auth = ControllableAdminAuth();
        addTearDown(auth.dispose);
        final second = Completer<AuthResponse>();
        var admitted = false;
        auth.viewModel.addListener(() {
          if (!admitted &&
              auth.viewModel.loginSnapshot.completed &&
              auth.viewModel.canLogin) {
            admitted = true;
            auth.onPassword = () => second.future;
            expect(
              auth.viewModel.requestLogin((
                email: 'second',
                password: 'secret',
              )),
              isTrue,
            );
          }
        });
        auth.viewModel.requestLogin((email: 'first', password: 'secret'));
        await pumpEventQueue();
        expect(admitted, isTrue);
        expect(auth.viewModel.isAuthenticating, isTrue);
        expect(auth.viewModel.requestLogout(), isFalse);
        second.complete(
          AuthResponse(
            user: auth.client.currentUser,
            session: auth.client.currentSession,
          ),
        );
        await pumpEventQueue();
        expect(auth.passwordCalls, 2);
      },
    );

    for (final logout in [false, true]) {
      test(
        'A8 dispose during anonymous restore logout=$logout freezes state',
        () async {
          final auth = ControllableAdminAuth();
          final gate = Completer<AuthResponse>();
          auth.onAnonymous = () => gate.future;
          auth.onPassword = () async {
            auth.setUser(makeAuthUser());
            return AuthResponse(
              user: auth.client.currentUser,
              session: auth.client.currentSession,
            );
          };
          if (logout) {
            auth.viewModel.requestLogout();
          } else {
            auth.viewModel.requestLogin((email: 'a', password: 'secret'));
          }
          await pumpEventQueue();
          expect(auth.anonymousCalls, 1);
          final frozen = auth.viewModel.currentUser;
          var notifications = 0;
          auth.viewModel.addListener(() => notifications++);
          auth.dispose();
          final anonymous = makeAuthUser(isAnonymous: true);
          auth.setUser(anonymous);
          gate.complete(
            AuthResponse(user: anonymous, session: auth.client.currentSession),
          );
          await pumpEventQueue();
          expect(auth.viewModel.currentUser, same(frozen));
          expect(notifications, 0);
        },
      );
    }

    test(
      'A8 dispose during rejected-account signOut starts no restore',
      () async {
        final auth = ControllableAdminAuth();
        final gate = Completer<void>();
        auth.onSignOut = () => gate.future;
        auth.onPassword = () async {
          auth.setUser(makeAuthUser());
          return AuthResponse(
            user: auth.client.currentUser,
            session: auth.client.currentSession,
          );
        };
        auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        await pumpEventQueue();
        expect(auth.signOutCalls, 1);
        final frozen = auth.viewModel.currentUser;
        var notifications = 0;
        auth.viewModel.addListener(() => notifications++);
        auth
          ..dispose()
          ..setUser(null);
        gate.complete();
        await pumpEventQueue();
        expect(auth.anonymousCalls, 0);
        expect(auth.viewModel.currentUser, same(frozen));
        expect(notifications, 0);
      },
    );

    test(
      'A5 logout reservation rejects login before and during SDK entry',
      () async {
        final auth = ControllableAdminAuth();
        addTearDown(auth.dispose);
        final gate = Completer<void>();
        auth.onSignOut = () => gate.future;
        expect(auth.viewModel.requestLogout(), isTrue);
        expect(
          auth.viewModel.requestLogin((email: 'a', password: 'discarded')),
          isFalse,
        );
        expect(auth.viewModel.requestLogout(), isFalse);
        await pumpEventQueue();
        expect(
          auth.viewModel.requestLogin((email: 'b', password: 'discarded')),
          isFalse,
        );
        gate.complete();
        await pumpEventQueue();
        expect(auth.passwordCalls, 0);
        expect(auth.viewModel.canLogin, isTrue);
      },
    );

    for (final clear in [false, true]) {
      test(
        'A3 rejected login cleanup failure clear=$clear remains denied',
        () async {
          final auth = ControllableAdminAuth();
          addTearDown(auth.dispose);
          auth.onPassword = () async {
            auth.setUser(makeAuthUser());
            return AuthResponse(
              user: auth.client.currentUser,
              session: auth.client.currentSession,
            );
          };
          auth.onSignOut = () async {
            if (clear) auth.setUser(null);
            throw const AuthException('cleanup failed');
          };
          auth.viewModel.requestLogin((email: 'a', password: 'secret'));
          await pumpEventQueue();
          expect(auth.viewModel.loginSnapshot.hasFailure, isTrue);
          expect(auth.signOutCalls, 1);
          expect(auth.anonymousCalls, clear ? 1 : 0);
          expect(
            auth.logger.eventsOfType<AdminAuthLogoutFailed>(),
            hasLength(1),
          );
        },
      );
    }

    test('A3 rejected login restore failure remains access denied', () async {
      final auth = ControllableAdminAuth();
      addTearDown(auth.dispose);
      auth.signInAnonymouslyError = const AuthException('restore failed');
      auth.onPassword = () async {
        auth.setUser(makeAuthUser());
        return AuthResponse(
          user: auth.client.currentUser,
          session: auth.client.currentSession,
        );
      };
      auth.viewModel.requestLogin((email: 'a', password: 'secret'));
      await pumpEventQueue();
      expect(auth.viewModel.loginSnapshot.hasFailure, isTrue);
      expect(auth.viewModel.currentUser, isNull);
      expect(auth.anonymousCalls, 1);
    });

    test(
      'A8 old pending login cannot publish or clean replacement owner session',
      () async {
        final auth = ControllableAdminAuth();
        final gate = Completer<AuthResponse>();
        auth.onPassword = () => gate.future;
        auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        await pumpEventQueue();
        final a = makeAuthUser();
        final response = AuthResponse(user: a, session: makeAuthSession(a));
        auth.viewModel.dispose();
        final replacement = AdminAuthViewModel(
          authClient: auth.client,
          logger: auth.logger,
        );
        final b = makeAuthUser(isAdmin: true);
        auth
          ..setUser(b)
          ..emit(AuthChangeEvent.signedIn);
        await pumpEventQueue();
        var notifications = 0;
        replacement.addListener(() => notifications++);
        gate.complete(response);
        await pumpEventQueue();
        expect(replacement.currentUser, same(b));
        expect(replacement.canLogin, isTrue);
        expect(notifications, 0);
        expect(auth.signOutCalls, 0);
        expect(auth.anonymousCalls, 0);
        replacement.dispose();
        auth.dispose();
      },
    );

    test(
      'A6 final guard rechecks correlation after rejected-login log hook',
      () async {
        final logger = AdminAuthRecordingLogger();
        final auth = ControllableAdminAuth(logger: logger);
        addTearDown(auth.dispose);
        final a = makeAuthUser();
        final b = makeAuthUser();
        auth.onPassword = () async {
          auth.setUser(a);
          return AuthResponse(user: a, session: auth.client.currentSession);
        };
        logger.onLog = (event) {
          if (event is AdminAuthLoginRejected) auth.setUser(b);
        };
        auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        await pumpEventQueue();
        expect(logger.eventsOfType<AdminAuthLoginRejected>(), hasLength(1));
        expect(auth.viewModel.loginSnapshot.hasFailure, isTrue);
        expect(auth.signOutCalls, 0);
        expect(auth.anonymousCalls, 0);
        expect(auth.client.currentUser, same(b));
      },
    );
  });
}
