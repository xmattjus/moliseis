import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  late Command1<void, bool> setCrashReporting;

  SettingsViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository {
    setCrashReporting = Command1(_setCrashReporting);
  }

  bool? _crashReporting;

  bool get crashReporting =>
      _crashReporting ??= _settingsRepository.crashReporting;

  Future<Result<void>> _setCrashReporting(bool enable) async {
    _crashReporting = enable;

    notifyListeners();

    final result = await _settingsRepository.setCrashReporting(enable);

    if (result is Error) {
      _crashReporting = !_crashReporting!; // Revert the change on error.

      notifyListeners();
    }

    return result;
  }
}
