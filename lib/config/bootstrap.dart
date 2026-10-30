import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Resolves local consent before SDK initialization or normal startup work.
///
/// A missing row uses repository defaults; a failed read keeps those defaults
/// for the app while failing closed only for telemetry. Local creation failures
/// retain the existing setup-error presentation without initializing telemetry.
Future<void> bootstrapApplication({
  required Future<SettingsRepository> Function() createSettings,
  required void Function(Object, StackTrace) onLocalFailure,
  required void Function(Result<void>) onSettingsInitialized,
  required Future<void> Function(Future<void> Function()) initializeTelemetry,
  required Future<void> Function(
    SettingsRepository, {
    required bool reportingEnabled,
  })
  runApplication,
}) async {
  final SettingsRepository settings;
  try {
    settings = await createSettings();
  } on Object catch (error, stack) {
    onLocalFailure(error, stack);
    return;
  }
  final result = await settings.initialize();
  onSettingsInitialized(result);
  final enabled = result is Success<void> && settings.crashReporting;
  Future<void> run() => runApplication(settings, reportingEnabled: enabled);
  if (enabled) {
    await initializeTelemetry(run);
  } else {
    await run();
  }
}
