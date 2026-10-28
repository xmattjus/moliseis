import 'dart:async';

import 'package:command_it/command_it.dart' as commands;
import 'package:flutter/foundation.dart';
import 'package:moliseis/data/services/supabase_anonymous_session.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
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
  AdminAuthViewModel({required GoTrueClient authClient, required Logger logger})
    : _authClient = authClient,
      _logger = logger {
    _loginCommand = createResultCommandNoParam<void>(
      () => _execute(_login),
      debugName: 'admin_login',
    );
    _logoutCommand = createResultCommandNoParam<void>(
      () => _execute(_logout),
      debugName: 'admin_logout',
    );
    _loginSnapshot = _loginCommand.results.value;
    _logoutSnapshot = _logoutCommand.results.value;
    for (final command in _commands) {
      void observe() => _scheduleSettlement();
      void forward() => _forward(command);
      _publicObservers[command] = forward;
      _observers[command] = observe;
      command.results.addListener(observe);
      command.isRunningSync.addListener(observe);
      command.results.addListener(forward);
      command.isRunningSync.addListener(forward);
    }
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

  late final ResultCommand<void, void> _loginCommand;
  late final ResultCommand<void, void> _logoutCommand;
  late commands.CommandResult<void, Result<void>?> _loginSnapshot;
  late commands.CommandResult<void, Result<void>?> _logoutSnapshot;
  final _publicObservers = <ResultCommand<void, void>, VoidCallback>{};
  final _observers = <ResultCommand<void, void>, VoidCallback>{};
  ResultCommand<void, void>? _active;
  AdminLoginCredentials? _credentials;
  bool _actionSettled = false;
  bool _barrierQueued = false;
  bool _released = false;

  Iterable<ResultCommand<void, void>> get _commands => [
    _loginCommand,
    _logoutCommand,
  ];

  /// Cached credential-free state, frozen when this owner is revoked.
  commands.CommandResult<void, Result<void>?> get loginSnapshot =>
      _loginSnapshot;

  /// Cached logout state, frozen when this owner is revoked.
  commands.CommandResult<void, Result<void>?> get logoutSnapshot =>
      _logoutSnapshot;

  /// Whether an admitted authentication operation is still settling.
  bool get isAuthenticating => _active != null;

  /// Whether either intent can reserve the shared authentication gate.
  bool get canLogin => !_disposed && _active == null;

  /// Uses exactly the same admission predicate as [requestLogout].
  bool get canLogout => canLogin;

  /// Whether this application owner has revoked its publication authority.
  bool get isDisposed => _disposed;

  /// Reserves login synchronously; true denotes admission, never success.
  /// Credentials never enter Command parameters, results or diagnostics.
  bool requestLogin(AdminLoginCredentials credentials) {
    if (!canLogin) return false;
    _active = _loginCommand;
    _actionSettled = false;
    _credentials = credentials;
    _loginCommand.run();
    return true;
  }

  /// Reserves logout without queuing or interrupting another auth operation.
  bool requestLogout() {
    if (!canLogout) return false;
    _active = _logoutCommand;
    _actionSettled = false;
    _logoutCommand.run();
    return true;
  }

  Future<Result<void>> _execute(Future<Result<void>> Function() action) async {
    try {
      if (_disposed) return _unavailable();
      return await action();
    } finally {
      // A witness for assertion-abort too; never completes/reports the action.
      _actionSettled = true;
      _scheduleSettlement();
    }
  }

  void _forward(ResultCommand<void, void> command) {
    if (!_disposed) {
      if (identical(command, _loginCommand)) {
        _loginSnapshot = command.results.value;
      } else {
        _logoutSnapshot = command.results.value;
      }
      notifyListeners();
    }
    _scheduleSettlement();
  }

  void _scheduleSettlement() {
    if (_barrierQueued || _released) return;
    _barrierQueued = true;
    scheduleMicrotask(() {
      unawaited(
        Future<void>(() {
          _barrierQueued = false;
          final active = _active;
          if (active != null &&
              (!_actionSettled || active.isRunningSync.value)) {
            return;
          }
          // Outside upstream terminal dispatch/finally. Reentrant intent
          // admission can no longer have its running flag reset by the old run.
          if (active != null) {
            _active = null;
            if (!_disposed) notifyListeners();
          }
          if (_disposed && _active == null && !_released) {
            _released = true;
            for (final command in _commands) {
              final observer = _observers.remove(command)!;
              command.results.removeListener(observer);
              command.isRunningSync.removeListener(observer);
              command.dispose();
            }
          }
        }),
      );
    });
  }

  Result<void> _unavailable() =>
      Result.error(Exception('Sessione non disponibile.'));

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

  Future<Result<void>> _login() async {
    final credentials = _credentials!;
    _credentials = null;
    late final AuthResponse response;
    try {
      response = await _authClient.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );
    } on Exception catch (error, stackTrace) {
      if (_disposed) return Result.error(error);
      _logger.log(
        const AdminAuthLoginFailed(),
        error: error,
        stackTrace: stackTrace,
      );
      _syncUser();
      return Result.error(error);
    }
    if (_disposed) return _unavailable();
    _syncUser();
    if (!_correlated(response)) {
      _syncUser();
      return _unavailable();
    }
    if (isAdmin) return const Result.success(null);

    _logger.log(const AdminAuthLoginRejected());
    // Logging and session notifications may reenter. This invocation-time
    // identity guard is intentionally adjacent to signOut: SDK has no CAS.
    if (!_correlated(response)) {
      _syncUser();
      return _unavailable();
    }
    if (_isAdmin(_authClient.currentUser)) return const Result.success(null);
    try {
      await _authClient.signOut();
    } on Exception catch (error, stackTrace) {
      if (_disposed) return Result.error(error);
      _logger.log(
        const AdminAuthLogoutFailed(),
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_disposed) return _unavailable();
    if (_authClient.currentUser == null) {
      await ensureAnonymousSupabaseSession(
        authClient: _authClient,
        logger: _logger,
      );
    }
    if (_disposed) return _unavailable();
    _syncUser();
    return Result.error(
      Exception("Questo account non ha accesso all'area redazione."),
    );
  }

  bool _correlated(AuthResponse response) {
    final user = response.user;
    final session = response.session;
    final current = _authClient.currentUser;
    return !_disposed &&
        identical(_active, _loginCommand) &&
        user != null &&
        user.id.isNotEmpty &&
        session != null &&
        session.user.id == user.id &&
        identical(session, _authClient.currentSession) &&
        current != null &&
        current.id == user.id &&
        !current.isAnonymous;
  }

  static bool _isAdmin(User? user) =>
      user != null && !user.isAnonymous && user.appMetadata['admin'] == true;

  Future<Result<void>> _logout() async {
    try {
      await _authClient.signOut();
    } on Exception catch (error, stackTrace) {
      if (_disposed) return Result.error(error);
      _logger.log(
        const AdminAuthLogoutFailed(),
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_disposed) return _unavailable();
    if (_authClient.currentUser == null) {
      await ensureAnonymousSupabaseSession(
        authClient: _authClient,
        logger: _logger,
      );
    }
    if (_disposed) return _unavailable();
    _syncUser();
    if (_authClient.currentUser?.isAnonymous ?? false) {
      return const Result.success(null);
    }
    return Result.error(
      Exception('La sessione anonima non è stata ripristinata.'),
    );
  }

  void _syncUser() {
    if (_disposed) return;
    final user = _authClient.currentUser;
    final previous = _currentUser;
    final changed =
        user?.id != previous?.id ||
        user?.email != previous?.email ||
        user?.isAnonymous != previous?.isAnonymous ||
        user?.appMetadata['admin'] != previous?.appMetadata['admin'] ||
        user?.userMetadata?['name'] != previous?.userMetadata?['name'];
    _currentUser = user;
    if (changed) notifyListeners();
  }

  void _handleAuthStateChange(AuthState _) {
    _syncUser();
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    // A failed authority stream cannot keep publishing private editor state.
    _currentUser = null;
    notifyListeners();
    _logger.log(
      const AdminAuthStateError(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _credentials = null;
    for (final command in _commands) {
      final forward = _publicObservers.remove(command)!;
      command.results.removeListener(forward);
      command.isRunningSync.removeListener(forward);
    }
    unawaited(_subscription.cancel());
    _scheduleSettlement();
    // A listener may revoke us while ChangeNotifier is dispatching.
    scheduleMicrotask(super.dispose);
  }
}
