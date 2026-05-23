part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when ObjectBox fails to initialize at startup.
class LocalPersistenceInitFailed extends LogEvent {
  const LocalPersistenceInitFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.critical;

  @override
  String get name => 'local_persistence_init_failed';
}

/// Fired when the settings store fails to initialise from ObjectBox.
class LocalPersistenceSettingsInitFailed extends LogEvent {
  const LocalPersistenceSettingsInitFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'local_persistence_settings_init_failed';
}
