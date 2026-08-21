import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moliseis/data/services/supabase_anonymous_session.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Credentials for the staff login form.
typedef AdminLoginCredentials = ({String email, String password});

/// Staff authentication state for the admin area.
///
/// Not user management: it only observes the Supabase Auth session,
/// authenticates pre-existing editor accounts, and restores the anonymous
/// session on logout.
class AdminAuthViewModel extends ChangeNotifier {
  /// Creates the auth state that protects staff-only application routes.
  AdminAuthViewModel({
    required GoTrueClient authClient,
    required Logger logger,
  }) : _authClient = authClient,
       _logger = logger {
    login = Command1<void, AdminLoginCredentials>(_login);
    logout = Command0<void>(_logout);
    _currentUser = _authClient.currentUser;
    _subscription = _authClient.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: _handleAuthStreamError,
    );
  }

  final GoTrueClient _authClient;
  final Logger _logger;
  late final StreamSubscription<AuthState> _subscription;
  User? _currentUser;
  bool _disposed = false;

  /// Signs in staff using e-mail and password credentials.
  late Command1<void, AdminLoginCredentials> login;

  /// Signs out staff and restores the anonymous application session.
  late Command0<void> logout;

  /// The cached Supabase user, refreshed whenever authentication changes.
  User? get currentUser => _currentUser;

  /// Whether the current session is anonymous or absent.
  bool get isAnonymous => _currentUser?.isAnonymous ?? true;

  /// Whether the current session belongs to an authenticated staff account.
  bool get isAdmin {
    final currentUser = _currentUser;
    return currentUser != null &&
        !currentUser.isAnonymous &&
        currentUser.appMetadata['admin'] == true;
  }

  /// The current user's e-mail address, when Supabase provides one.
  String? get email => _currentUser?.email;

  /// The current user's display name when the metadata has a string value.
  String? get displayName {
    final name = _currentUser?.userMetadata?['name'];
    return name is String ? name : null;
  }

  Future<Result<void>> _login(AdminLoginCredentials credentials) async {
    try {
      await _authClient.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );
    } on Exception catch (error, stackTrace) {
      _logger.log(
        const AdminAuthLoginFailed(),
        error: error,
        stackTrace: stackTrace,
      );
      return Result.error(error);
    }

    _currentUser = _authClient.currentUser;
    _notifyListeners();

    if (!isAdmin) {
      _logger.log(const AdminAuthLoginRejected());
      try {
        await _authClient.signOut();
      } on Exception catch (error, stackTrace) {
        _logger.log(
          const AdminAuthLogoutFailed(),
          error: error,
          stackTrace: stackTrace,
        );
      }

      await ensureAnonymousSupabaseSession(
        authClient: _authClient,
        logger: _logger,
      );
      _currentUser = _authClient.currentUser;
      _notifyListeners();

      return Result.error(
        Exception("Questo account non ha accesso all'area redazione."),
      );
    }

    return const Result.success(null);
  }

  Future<Result<void>> _logout() async {
    try {
      await _authClient.signOut();
    } on Exception catch (error, stackTrace) {
      _logger.log(
        const AdminAuthLogoutFailed(),
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      await ensureAnonymousSupabaseSession(
        authClient: _authClient,
        logger: _logger,
      );
      _currentUser = _authClient.currentUser;
      _notifyListeners();
    }

    final currentUser = _currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      return const Result.success(null);
    }

    return Result.error(
      Exception('La sessione anonima non è stata ripristinata.'),
    );
  }

  void _handleAuthStateChange(AuthState _) {
    _currentUser = _authClient.currentUser;
    _notifyListeners();
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    _logger.log(
      const AdminAuthStateError(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
