import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
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
}) {
  final now = DateTime.utc(2026).toIso8601String();
  return User(
    id: 'test-auth-user-${_nextAuthUserId++}',
    appMetadata: {'admin': isAdmin},
    userMetadata: name == null ? {} : {'name': name},
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
  ControllableAdminAuth({User? initialUser}) {
    _registerFallbackValues();
    client = MockGoTrueClient();
    events = StreamController<AuthState>.broadcast();
    _currentUser = initialUser ?? makeAuthUser(isAnonymous: true);

    when(() => client.currentUser).thenAnswer((_) => _currentUser);
    when(() => client.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => client.signInAnonymously()).thenAnswer((_) async {
      final error = signInAnonymouslyError;
      if (error != null) _throwConfiguredError(error);

      _currentUser = makeAuthUser(isAnonymous: true);
      return MockAuthResponse();
    });
    when(() => client.signOut()).thenAnswer((_) async {
      _currentUser = null;
      final error = signOutError;
      if (error != null) _throwConfiguredError(error);
    });

    viewModel = AdminAuthViewModel(authClient: client, logger: logger);
  }

  User? _currentUser;

  /// The mocked Supabase authentication client.
  late final MockGoTrueClient client;

  /// Broadcast source for Supabase authentication-state events.
  late final StreamController<AuthState> events;

  /// The logging double passed to [viewModel].
  late final MockLogger logger = MockLogger();

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
  // ignore: use_setters_to_change_properties
  void setUser(User? user) {
    _currentUser = user;
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
