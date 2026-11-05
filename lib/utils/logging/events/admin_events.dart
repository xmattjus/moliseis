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

/// Fired when an admin backend request fails.
final class AdminBackendRequestFailed extends LogEvent {
  const AdminBackendRequestFailed({
    required this.operation,
    this.outcome,
    this.statusCode,
  });

  final String operation;
  final AssociationOutcome? outcome;
  final int? statusCode;

  @override
  Map<String, Object?> get data => {
    'operation': operation,
    if (operation == 'associateStagedAsset') ...{
      'outcome': (outcome ?? AssociationOutcome.unconfirmed).name,
      if (statusCode case final int status when status >= 100 && status <= 599)
        'status_code': status,
    },
  };

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'admin_backend_request_failed';
}

/// Fired only after the server confirms an exact staged-asset receipt.
final class AdminStagedAssetAssociated extends LogEvent {
  const AdminStagedAssetAssociated({required this.replayed});

  final bool replayed;

  @override
  Map<String, Object?> get data => {
    'outcome': replayed ? 'replayed' : 'confirmed',
  };

  @override
  AppLogLevel get level => AppLogLevel.info;

  @override
  String get name => 'admin_staged_asset_associated';
}

/// A local Admin persistence stage failed without disclosing private paths.
final class AdminLocalStorageFailed extends LogEvent {
  /// Identifies the stable operation name rather than a file or owner path.
  const AdminLocalStorageFailed({required this.operation});

  /// Local persistence stage, without user content or filesystem locations.
  final String operation;

  @override
  Map<String, Object?> get data => {'operation': operation};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'admin_local_storage_failed';
}
