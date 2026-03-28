import 'package:flutter/material.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  final SentryLoggingFlag _sentryLoggingFlag;

  late Command1<void, bool> setCrashReporting;

  SettingsViewModel({
    required SettingsRepository settingsRepository,
    required SentryLoggingFlag sentryLoggingFlag,
  }) : _settingsRepository = settingsRepository,
       _sentryLoggingFlag = sentryLoggingFlag {
    setCrashReporting = Command1(_setCrashReporting);
    _crashReporting = _settingsRepository.crashReporting;
  }

  late bool _crashReporting;

  bool get crashReporting => _crashReporting;

  Future<Result<void>> _setCrashReporting(bool enable) async {
    _crashReporting = enable;

    notifyListeners();

    final result = await _settingsRepository.setCrashReporting(enable);

    if (result is Error) {
      _crashReporting = !_crashReporting; // Revert the change on error.

      notifyListeners();
    }

    _sentryLoggingFlag.enabled = _crashReporting;

    return result;
  }
}
