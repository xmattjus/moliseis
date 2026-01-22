import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';

extension ThemeTypeExtensions on ThemeType {
  String get readableName {
    switch (this) {
      case ThemeType.system:
        return 'Sistema';
      case ThemeType.app:
        return 'App';
    }
  }
}

extension ThemeBrightnessExtensions on ThemeBrightness {
  String get readableName {
    switch (this) {
      case ThemeBrightness.system:
        return 'Auto';
      case ThemeBrightness.light:
        return 'Chiaro';
      case ThemeBrightness.dark:
        return 'Scuro';
    }
  }
}
