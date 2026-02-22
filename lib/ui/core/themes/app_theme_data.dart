import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/base_theme_data.dart';
import 'package:moliseis/ui/core/themes/text_theme.dart';
import 'package:moliseis/ui/core/themes/theme_extensions.dart';

class AppThemeData {
  const AppThemeData._();

  static ThemeData light({
    required BuildContext context,
    ColorScheme? dynamicColorScheme,
  }) {
    final appColorSchemes = AppColorSchemesThemeExtension.fromSeed(
      Brightness.light,
    );

    final appColors = AppColorsThemeExtension.light(appColorSchemes.main);

    return BaseThemeData.get(
      extensions: <ThemeExtension<dynamic>>[appColorSchemes, appColors],
      colorScheme: appColorSchemes.main,
    );
  }

  static ThemeData dark({
    required BuildContext context,
    ColorScheme? dynamicColorScheme,
  }) {
    final appColorSchemes = AppColorSchemesThemeExtension.fromSeed(
      Brightness.dark,
    );

    final appColors = AppColorsThemeExtension.dark(appColorSchemes.main);

    return BaseThemeData.get(
      extensions: <ThemeExtension<dynamic>>[appColorSchemes, appColors],
      colorScheme: appColorSchemes.main,
    );
  }

  static ThemeData get photoViewer {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.lightBlue,
        brightness: Brightness.dark,
        surface: Colors.black,
      ),
      textTheme: appTextTheme,
    );
  }
}
