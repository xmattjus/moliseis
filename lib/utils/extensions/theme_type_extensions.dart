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
