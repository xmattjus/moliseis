import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/app_effects_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_shapes_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_sizes_theme_extension.dart';
import 'package:moliseis/ui/core/themes/text_theme.dart';

class BaseThemeData {
  // Private constructor to prevent class instantiation.
  BaseThemeData._();

  static ThemeData get({
    Iterable<ThemeExtension<dynamic>>? extensions,
    ColorScheme? colorScheme,
    ChipThemeData? chipTheme,
    Color? scaffoldBackgroundColor,
    AppBarThemeData? appBarTheme,
    NavigationBarThemeData? navigationBarTheme,
    NavigationRailThemeData? navigationRailTheme,
  }) {
    // Get a reference to the M3 Expressive shape tokens to use in the theme
    // data below.
    final appShapes = AppShapesThemeExtension();

    return ThemeData(
      appBarTheme:
          appBarTheme ??
          AppBarTheme(
            backgroundColor: scaffoldBackgroundColor ?? colorScheme?.surface,
            elevation: 0,
          ),
      scaffoldBackgroundColor: scaffoldBackgroundColor ?? colorScheme?.surface,
      navigationBarTheme:
          navigationBarTheme ??
          NavigationBarThemeData(
            backgroundColor: colorScheme?.surfaceContainer,
            elevation: 3,
          ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme?.surfaceContainerLow,
        elevation: 1,
      ),
      navigationRailTheme:
          navigationRailTheme ??
          NavigationRailThemeData(
            backgroundColor: colorScheme?.surface,
            // indicatorColor: colorScheme?.primaryContainer,
            elevation: 0,
            groupAlignment: -0.85,
          ),
      extensions: [
        AppEffectsThemeExtension(),
        appShapes,
        AppSizesThemeExtension(),
        ...?extensions,
      ],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: colorScheme,
      textTheme: appTextTheme,
      chipTheme:
          chipTheme ??
          const ChipThemeData(
            padding: EdgeInsets.only(
              left: 12,
              top: 8,
              bottom: 8,
              right: 8,
            ),
          ),
      dividerTheme: DividerThemeData(
        color: colorScheme?.brightness == Brightness.light
            ? colorScheme?.surfaceDim
            : colorScheme?.surfaceBright,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: appShapes.circular.cornerExtraSmall,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(shape: _expressiveButtonShape),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(shape: _expressiveButtonShape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: colorScheme?.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: appShapes.circular.cornerExtraSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(shape: _expressiveButtonShape),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colorScheme?.secondaryContainer,
        linearMinHeight: 4,
        circularTrackColor: colorScheme?.secondaryContainer,
        stopIndicatorColor: colorScheme?.primary,
        strokeWidth: 4,
        strokeCap: StrokeCap.round,
        trackGap: 4,
      ),
      searchBarTheme: const SearchBarThemeData(
        constraints: BoxConstraints(minHeight: 56),
        elevation: WidgetStatePropertyAll<double>(0),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
      ),
    );
  }

  static WidgetStateProperty<OutlinedBorder?>? get _expressiveButtonShape =>
      WidgetStateProperty.resolveWith((states) {
        final appSizes = AppSizesThemeExtension();
        final appShapes = AppShapesThemeExtension();

        if (states.contains(WidgetState.pressed)) {
          return RoundedRectangleBorder(
            borderRadius: appShapes.circular.cornerMedium,
          );
        }

        if (states.contains(WidgetState.focused)) {
          return RoundedRectangleBorder(
            side: BorderSide(
              // color: Colors.black54,
              width: appSizes.borderSide.large,
            ),
            borderRadius: appShapes.circular.cornerFull,
          );
        }

        return RoundedRectangleBorder(
          borderRadius: appShapes.circular.cornerFull,
        );
      });
}
