part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when staff sign-in with a password fails.
class AdminAuthLoginFailed extends LogEvent {
  const AdminAuthLoginFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'admin_auth_login_failed';
}

/// Fired when an authenticated user does not have staff access.
class AdminAuthLoginRejected extends LogEvent {
  const AdminAuthLoginRejected();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'admin_auth_login_rejected';
}

/// Fired when signing out the staff session fails.
class AdminAuthLogoutFailed extends LogEvent {
  const AdminAuthLogoutFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'admin_auth_logout_failed';
}

/// Fired when the Supabase authentication-state stream emits an error.
class AdminAuthStateError extends LogEvent {
  const AdminAuthStateError();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'admin_auth_state_error';
}

/// Fired when an admin repository is invoked before its backend exists.
class AdminBackendUnavailable extends LogEvent {
  const AdminBackendUnavailable();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'admin_backend_unavailable';
}
