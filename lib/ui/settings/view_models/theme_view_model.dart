import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository {
    setThemeBrightness = createResultCommand(
      _setThemeBrightness,
      debugName: 'ThemeViewModel.setThemeBrightness',
    );
    setThemeType = createResultCommand(
      _setThemeType,
      debugName: 'ThemeViewModel.setThemeType',
    );
    _themeBrightness = _settingsRepository.themeBrightness;
    _themeType = _settingsRepository.themeType;
  }

  final SettingsRepository _settingsRepository;
  bool _disposed = false;
  late ThemeType _themeType;
  late ThemeBrightness _themeBrightness;

  ThemeType get themeType => _themeType;

  ThemeBrightness get themeBrightness => _themeBrightness;

  late final ResultCommand<ThemeBrightness, void> setThemeBrightness;

  late final ResultCommand<ThemeType, void> setThemeType;

  /// Sets the app theme 'type', e.g. color scheme, to the required value.
  Future<Result<void>> _setThemeType(ThemeType type) async {
    if (_disposed) return Result.error(Exception('Theme unavailable'));
    final oldType = _themeType;

    _themeType = type;
    notifyListeners();

    if (_disposed) return Result.error(Exception('Theme unavailable'));
    final result = await _settingsRepository.setThemeType(type);

    if (_disposed) return result;

    if (result.isError) {
      _themeType = oldType; // Revert the change on error.
      notifyListeners();
    }

    return result;
  }

  /// Sets the app theme mode to the required value.
  Future<Result<void>> _setThemeBrightness(ThemeBrightness brightness) async {
    if (_disposed) return Result.error(Exception('Theme unavailable'));
    final oldBrightness = _themeBrightness;

    _themeBrightness = brightness;
    notifyListeners();

    if (_disposed) return Result.error(Exception('Theme unavailable'));
    final result = await _settingsRepository.setThemeBrightness(brightness);

    if (_disposed) return result;

    if (result.isError) {
      _themeBrightness = oldBrightness; // Revert the change on error.
      notifyListeners();
    }

    return result;
  }

  /// Maps the app [ThemeBrightness] to the Flutter [ThemeMode] enum.
  ThemeMode get themeMode => switch (themeBrightness) {
    ThemeBrightness.system => ThemeMode.system,
    ThemeBrightness.light => ThemeMode.light,
    ThemeBrightness.dark => ThemeMode.dark,
  };

  /// Maps the app [ThemeBrightness] to the Flutter [Brightness] enum.
  Brightness get brightness => switch (themeBrightness) {
    ThemeBrightness.system => Brightness.light,
    ThemeBrightness.light => Brightness.light,
    ThemeBrightness.dark => Brightness.dark,
  };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    scheduleMicrotask(super.dispose);

    for (final command in [setThemeBrightness, setThemeType]) {
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
