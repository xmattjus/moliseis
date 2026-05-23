import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository {
    setThemeBrightness = Command1(_setThemeBrightness);
    setThemeType = Command1(_setThemeType);
    _themeBrightness = _settingsRepository.themeBrightness;
    _themeType = _settingsRepository.themeType;
  }

  final SettingsRepository _settingsRepository;
  late ThemeType _themeType;
  late ThemeBrightness _themeBrightness;

  ThemeType get themeType => _themeType;

  ThemeBrightness get themeBrightness => _themeBrightness;

  late Command1<void, ThemeBrightness> setThemeBrightness;

  late Command1<void, ThemeType> setThemeType;

  /// Sets the app theme 'type', e.g. color scheme, to the required value.
  Future<Result<void>> _setThemeType(ThemeType type) async {
    final oldType = _themeType;

    _themeType = type;
    notifyListeners();

    final result = await _settingsRepository.setThemeType(type);

    if (result.isError) {
      _themeType = oldType; // Revert the change on error.
      notifyListeners();
    }

    return result;
  }

  /// Sets the app theme mode to the required value.
  Future<Result<void>> _setThemeBrightness(ThemeBrightness brightness) async {
    final oldBrightness = _themeBrightness;

    _themeBrightness = brightness;
    notifyListeners();

    final result = await _settingsRepository.setThemeBrightness(brightness);

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
}
