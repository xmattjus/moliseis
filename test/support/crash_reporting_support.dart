import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

/// Creates a process owner without any external SDK or telemetry destination.
SetCrashReportingUseCase testCrashReporting({
  required SettingsRepository repository,
  SentryLoggingFlag? flag,
  bool? initiallyEnabled,
  Future<void> Function()? closeSentry,
}) {
  final gate = flag ?? SentryLoggingFlag(initialValue: false);
  return SetCrashReportingUseCase(
    settingsRepository: repository,
    sentryLoggingFlag: gate,
    initiallyEnabled: initiallyEnabled ?? gate.enabled,
    closeSentry: closeSentry ?? () async {},
  );
}
