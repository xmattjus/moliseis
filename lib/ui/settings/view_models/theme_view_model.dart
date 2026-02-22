import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';

// TODO (xmattjus): Implement Command & Result patterns.
class ThemeViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  ThemeType? _themeType;
  ThemeBrightness? _themeBrightness;

  ThemeViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  ThemeType get themeType => _themeType ??= _settingsRepository.themeType;

  ThemeBrightness get themeBrightness =>
      _themeBrightness ??= _settingsRepository.themeBrightness;

  /// Sets the app theme 'type', e.g. color scheme, to the required value.
  void setThemeType(ThemeType type) {
    _themeType = type;
    notifyListeners();

    /// Saves the user theme type selection to the app database.
    _settingsRepository.setThemeType(type);
  }

  /// Sets the app theme mode to the required value.
  void setThemeBrightness(ThemeBrightness brightness) {
    _themeBrightness = brightness;
    notifyListeners();

    /// Saves the user theme brightness selection to the app database.
    _settingsRepository.setThemeBrightness(brightness);
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
