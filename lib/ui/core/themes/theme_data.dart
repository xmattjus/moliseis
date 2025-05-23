import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/color.dart';
import 'package:moliseis/ui/core/themes/text_theme.dart';
import 'package:moliseis/utils/constants.dart';

class _BaseThemeData {
  const _BaseThemeData._();

  static ThemeData get({
    ColorScheme? colorScheme,
    Iterable<ThemeExtension<dynamic>>? extensions,
  }) {
    return ThemeData(
      // useMaterial3: true,
      extensions: extensions,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: colorScheme,
      textTheme: appTextTheme,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardCornerRadius),
        ),
      ),
      searchBarTheme: const SearchBarThemeData(
        constraints: BoxConstraints(minHeight: 56.0),
        elevation: WidgetStatePropertyAll<double>(0),
      ),
      tabBarTheme: const TabBarTheme(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        strokeWidth: 3.0,
        year2023: false,
      ),
    );
  }
}

class AppThemeData {
  const AppThemeData._();

  /// If not null, generate a new color scheme from the primary color token
  /// detected by the dynamic_color library. This is necessary since the
  /// dynamic_color library hasn't been updated to support the latest
  /// Material3 color tokens yet.
  ///
  /// See:
  /// https://github.com/material-foundation/flutter-packages/issues/574
  /// https://github.com/material-foundation/flutter-packages/issues/582
  static ColorScheme _colorScheme(Color? primary, Brightness brightness) =>
      CustomColorSchemes.main(
        primary ?? CustomColorSchemes.appSeed,
        brightness,
      );

  static ThemeData light({ColorScheme? dynamicColorScheme}) {
    final colorScheme = _colorScheme(
      dynamicColorScheme?.primary,
      Brightness.light,
    );

    return _BaseThemeData.get(colorScheme: colorScheme);
  }

  static ThemeData dark({ColorScheme? dynamicColorScheme}) {
    final colorScheme = _colorScheme(
      dynamicColorScheme?.primary,
      Brightness.dark,
    );

    return _BaseThemeData.get(colorScheme: colorScheme);
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
