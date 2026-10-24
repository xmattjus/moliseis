import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mock_logger.dart';

/// Mocktail double for [GoTrueClient].
final class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Mocktail double for [User].
final class MockUser extends Mock implements User {}

/// Mocktail double for [AuthResponse].
final class MockAuthResponse extends Mock implements AuthResponse {}

var _nextAuthUserId = 0;

/// Creates a concrete Supabase user for authentication tests.
///
/// Anonymous users have no e-mail by default so tests cannot accidentally
/// rely on an address that Supabase anonymous sessions do not provide.
User makeAuthUser({
  bool isAdmin = false,
  bool isAnonymous = false,
  String? email,
  String? name,
  String? displayName,
}) {
  final now = DateTime.utc(2026).toIso8601String();
  return User(
    id: 'test-auth-user-${_nextAuthUserId++}',
    appMetadata: {'admin': isAdmin},
    userMetadata: <String, dynamic>{
      if (name case final String name) 'name': name,
      if (displayName case final String displayName)
        'display_name': displayName,
    },
    aud: 'authenticated',
    createdAt: now,
    updatedAt: now,
    isAnonymous: isAnonymous,
    email: email ?? (isAnonymous ? null : 'editor@example.com'),
  );
}

/// A real [AdminAuthViewModel] driven by a controllable [MockGoTrueClient].
///
/// The current user is backed by one mutable variable. Harness behaviours
/// update that variable instead of layering mocktail getter stubs.
final class ControllableAdminAuth {
  /// Creates the harness, defaulting to a concrete anonymous user.
  ControllableAdminAuth({User? initialUser, MockLogger? logger})
    : logger = logger ?? MockLogger() {
    _registerFallbackValues();
    client = MockGoTrueClient();
    events = StreamController<AuthState>.broadcast();
    _currentUser = initialUser ?? makeAuthUser(isAnonymous: true);
    _currentSession = makeAuthSession(_currentUser!);

    when(() => client.currentUser).thenAnswer((_) => _currentUser);
    when(() => client.currentSession).thenAnswer((_) => _currentSession);
    when(
      () => client.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((invocation) async {
      passwordCalls++;
      capturedEmail = invocation.namedArguments[#email] as String;
      capturedPassword = invocation.namedArguments[#password] as String;
      final handler = onPassword;
      if (handler != null) return await handler();
      final user = makeAuthUser(isAdmin: true);
      setUser(user);
      return AuthResponse(user: user, session: _currentSession);
    });
    when(() => client.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => client.signInAnonymously()).thenAnswer((_) async {
      anonymousCalls++;
      final handler = onAnonymous;
      if (handler != null) return await handler();
      final error = signInAnonymouslyError;
      if (error != null) _throwConfiguredError(error);

      setUser(makeAuthUser(isAnonymous: true));
      return AuthResponse(user: _currentUser, session: _currentSession);
    });
    when(() => client.signOut()).thenAnswer((_) async {
      signOutCalls++;
      beforeSignOut?.call();
      final handler = onSignOut;
      if (handler != null) return await handler();
      setUser(null);
      afterSignOut?.call();
      final error = signOutError;
      if (error != null) _throwConfiguredError(error);
    });

    viewModel = AdminAuthViewModel(authClient: client, logger: this.logger);
  }

  User? _currentUser;
  Session? _currentSession;

  /// Independent SDK operation controls and invocation counters.
  Future<AuthResponse> Function()? onPassword;
  Future<AuthResponse> Function()? onAnonymous;
  Future<void> Function()? onSignOut;
  void Function()? beforeSignOut;
  void Function()? afterSignOut;
  int passwordCalls = 0;
  int anonymousCalls = 0;
  int signOutCalls = 0;
  String? capturedEmail;
  String? capturedPassword;

  /// The mocked Supabase authentication client.
  late final MockGoTrueClient client;

  /// Broadcast source for Supabase authentication-state events.
  late final StreamController<AuthState> events;

  /// The logging double passed to [viewModel].
  final MockLogger logger;

  /// The real view model controlled by this harness.
  late final AdminAuthViewModel viewModel;

  /// Error thrown by anonymous sign-in instead of installing an anonymous user.
  Object? signInAnonymouslyError;

  /// Error thrown after the sign-out stub removes the current user.
  Object? signOutError;

  /// Updates the backing user without emitting an auth-state event.
  ///
  /// This remains a method so tests can separately control state mutation and
  /// auth-event emission.
  void setUser(User? user) {
    _currentUser = user;
    _currentSession = user == null ? null : makeAuthSession(user);
  }

  /// Installs an exact Session independently of an SDK response.
  void setSession(Session? session) {
    _currentSession = session;
    _currentUser = session?.user;
  }

  /// Emits an authentication event for the current backing user.
  void emit(AuthChangeEvent change) {
    events.add(AuthState(change, null));
  }

  /// Closes the event stream and disposes the real view model.
  void dispose() {
    unawaited(events.close());
    viewModel.dispose();
  }
}

void _registerFallbackValues() {
  registerFallbackValue('');
  registerFallbackValue(AuthResponse());
  registerFallbackValue(const AuthState(AuthChangeEvent.initialSession, null));
}

Never _throwConfiguredError(Object error) {
  if (error is Error) throw error;
  if (error is Exception) throw error;
  throw Exception(error);
}

/// Creates a concrete session; identity, rather than token equality, matters.
Session makeAuthSession(User user) =>
    Session(accessToken: 'test-token', tokenType: 'bearer', user: user);

/// Records Auth logs before a test-controlled reentrant application callback.
final class AdminAuthRecordingLogger extends MockLogger {
  /// Optional hook invoked after the ordinary recording behavior.
  void Function(LogEvent event)? onLog;

  @override
  void log(
    LogEvent event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  }) {
    super.log(event, error: error, stackTrace: stackTrace, extra: extra);
    onLog?.call(event);
  }
}
