import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required SetCrashReportingUseCase crashReporting})
    : _consent = crashReporting {
    setCrashReporting = createResultCommand(
      _setCrashReporting,
      debugName: 'SettingsViewModel.setCrashReporting',
    );
    _crashReporting = _consent.preference;
  }

  final SetCrashReportingUseCase _consent;

  late final ResultCommand<bool, CrashReportingUpdate> setCrashReporting;

  bool _disposed = false;

  late bool _crashReporting;

  /// Whether this owner has revoked its publication authority.
  bool get isDisposed => _disposed;

  bool get crashReporting => _crashReporting;

  /// Saved consent, independent of the switch's pending optimistic value.
  bool get committedCrashReporting => _consent.preference;

  /// Effective process state, independent of the optimistic switch.
  CrashReportingState get reportingState => _consent.state;

  /// Feedback must still describe this application's current committed intent.
  bool isCurrent(CrashReportingUpdate update) => _consent.isCurrent(update);

  Future<Result<CrashReportingUpdate>> _setCrashReporting(bool enable) async {
    if (_disposed) return Result.error(Exception('Settings unavailable'));
    _crashReporting = enable;
    notifyListeners();
    if (_disposed) return Result.error(Exception('Settings unavailable'));
    try {
      return await _consent(enable: enable);
    } finally {
      if (!_disposed) {
        _crashReporting = _consent.preference;
        notifyListeners();
      }
    }
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
