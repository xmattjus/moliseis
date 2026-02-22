import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/theme_extensions.dart';

import 'package:moliseis/utils/enums.dart';

extension BuildContextExtensions on BuildContext {
  /// Whether the [MediaQueryData.orientation] reported for the nearest
  /// [MediaQuery] ancestor equals [Orientation.landscape] or false, if no such
  /// ancestor exists.
  bool get isLandscape {
    final inherited = InheritedModel.inheritFrom<MediaQuery>(this)?.data;
    return inherited?.orientation == Orientation.landscape;
  }

  bool get isDarkTheme {
    return Theme.of(this).brightness == Brightness.dark;
  }

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => theme.textTheme;

  ColorScheme get colorScheme => theme.colorScheme;

  DefaultTextStyle get defaultTextStyle => DefaultTextStyle.of(this);

  AppColorSchemesThemeExtension get appColorSchemes =>
      theme.extension<AppColorSchemesThemeExtension>() ??
      AppColorSchemesThemeExtension.fromSeed(theme.brightness);

  AppColorsThemeExtension get appColors =>
      theme.extension<AppColorsThemeExtension>() ?? newAppColorsThemeExt;

  AppEffectsThemeExtension get appEffects =>
      theme.extension<AppEffectsThemeExtension>() ?? AppEffectsThemeExtension();

  AppSizesThemeExtension get appSizes =>
      theme.extension<AppSizesThemeExtension>() ?? AppSizesThemeExtension();

  AppShapesThemeExtension get appShapes =>
      theme.extension<AppShapesThemeExtension>() ?? AppShapesThemeExtension();

  AppColorsThemeExtension get newAppColorsThemeExt => isDarkTheme
      ? AppColorsThemeExtension.dark(colorScheme)
      : AppColorsThemeExtension.light(colorScheme);
}

// Material 3 Expressive window size classes widths.
const double _compactWidthLimit = 600;
const double _mediumWidthLimit = 840;
const double _expandedWidthLimit = 1200;
const double _largeWidthLimit = 1600;

extension MediaQueryOnBuildContextExtensions on BuildContext {
  WindowSizeClass get windowSizeClass {
    final width = MediaQuery.maybeSizeOf(this)?.width;

    if (width == null) {
      // If MediaQuery data is not available, default to compact.
      return WindowSizeClass.compact;
    }

    if (width < _compactWidthLimit) {
      return WindowSizeClass.compact;
    }
    if (width < _mediumWidthLimit) {
      return WindowSizeClass.medium;
    }
    if (width < _expandedWidthLimit) {
      return WindowSizeClass.expanded;
    }
    if (width < _largeWidthLimit) {
      return WindowSizeClass.large;
    }
    return WindowSizeClass.extraLarge;
  }

  double get bottomPadding {
    final bottomPadding = MediaQuery.maybePaddingOf(this)?.bottom ?? 0.0;
    return bottomPadding + 16.0;
  }
}
