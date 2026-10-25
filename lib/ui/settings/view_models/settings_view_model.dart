import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsRepository settingsRepository,
    required SentryLoggingFlag sentryLoggingFlag,
  }) : _settingsRepository = settingsRepository,
       _sentryLoggingFlag = sentryLoggingFlag {
    setCrashReporting = createResultCommand(
      _setCrashReporting,
      debugName: 'SettingsViewModel.setCrashReporting',
    );
    _crashReporting = _settingsRepository.crashReporting;
  }

  final SettingsRepository _settingsRepository;

  final SentryLoggingFlag _sentryLoggingFlag;

  late final ResultCommand<bool, void> setCrashReporting;

  bool _disposed = false;

  late bool _crashReporting;

  /// Whether this owner has revoked its publication authority.
  bool get isDisposed => _disposed;

  bool get crashReporting => _crashReporting;

  Future<Result<void>> _setCrashReporting(bool enable) async {
    if (_disposed) return Result.error(Exception('Settings unavailable'));
    _crashReporting = enable;

    notifyListeners();

    if (_disposed) return Result.error(Exception('Settings unavailable'));
    final result = await _settingsRepository.setCrashReporting(enable: enable);

    // Shared consent follows the repository's committed cache, even after this
    // presentation owner is revoked or another owner's write has completed.
    _sentryLoggingFlag.enabled = _settingsRepository.crashReporting;
    if (_disposed) return result;

    if (result.isError) {
      _crashReporting = !_crashReporting; // Revert the change on error.

      notifyListeners();
    }

    return result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    scheduleMicrotask(super.dispose);

    for (final command in [setCrashReporting]) {
      var queued = false;
      var invalidated = false;
      var released = false;
      late VoidCallback onRunningChanged;
      void requestCleanup() {
        if (queued || released) return;
        queued = true;
        invalidated = false;
        // Leave the current dispatch, then upstream's queued terminal work.
        scheduleMicrotask(() {
          unawaited(
            Future<void>(() {
              queued = false;
              if (released || command.isRunningSync.value) return;
              if (invalidated) {
                requestCleanup();
                return;
              }
              command.isRunningSync.removeListener(onRunningChanged);
              released = true;
              command.dispose();
            }),
          );
        });
      }

      onRunningChanged = () {
        invalidated = true;
        if (!command.isRunningSync.value) requestCleanup();
      };
      command.isRunningSync.addListener(onRunningChanged);
      if (!command.isRunningSync.value) requestCleanup();
    }
  }
}
