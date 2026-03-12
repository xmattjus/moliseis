import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class ThemeViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  late ThemeType _themeType;
  late ThemeBrightness _themeBrightness;

  ThemeViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository {
    setThemeBrightness = Command1(_setThemeBrightness);
    setThemeType = Command1(_setThemeType);

    final themeBrightnessResult = _settingsRepository.themeBrightness;

    switch (themeBrightnessResult) {
      case Success<ThemeBrightness>():
        _themeBrightness = themeBrightnessResult.value;
      case Error<ThemeBrightness>():
        _themeBrightness =
            ThemeBrightness.system; // Default value in case of error.
    }

    final themeTypeResult = _settingsRepository.themeType;

    switch (themeTypeResult) {
      case Success<ThemeType>():
        _themeType = themeTypeResult.value;
      case Error<ThemeType>():
        _themeType = ThemeType.app; // Default value in case of error.
    }
  }

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

    switch (result) {
      case Error<void>():
        _themeType = oldType; // Revert the change on error.
        notifyListeners();
      case Success<void>():
    }

    return const Result.success(null);
  }

  /// Sets the app theme mode to the required value.
  Future<Result<void>> _setThemeBrightness(ThemeBrightness brightness) async {
    final oldBrightness = _themeBrightness;

    _themeBrightness = brightness;
    notifyListeners();

    final result = await _settingsRepository.setThemeBrightness(brightness);

    switch (result) {
      case Error<void>():
        _themeBrightness = oldBrightness; // Revert the change on error.
        notifyListeners();
      case Success<void>():
    }

    return const Result.success(null);
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
