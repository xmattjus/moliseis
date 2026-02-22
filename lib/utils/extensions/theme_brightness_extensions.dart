import 'package:moliseis/domain/models/theme_brightness.dart';

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
