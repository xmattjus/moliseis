import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/app_snack_bar_colors.dart';

class AppColorsThemeExtension extends ThemeExtension<AppColorsThemeExtension> {
  const AppColorsThemeExtension._({
    required this.blurredBoxBackgroundColor,
    required this.modalBorderColor,
    required this.paneColor,
    required this.infoSnackBar,
    required this.warningSnackBar,
    required this.errorSnackBar,
  });

  factory AppColorsThemeExtension.light(ColorScheme colorScheme) {
    final info = _MaterialColorTest.light(colorScheme.primary);
    final warning = _MaterialColorTest.light(Colors.orange);
    return AppColorsThemeExtension._(
      blurredBoxBackgroundColor: Color.alphaBlend(
        colorScheme.primary.withAlpha(17),
        colorScheme.surfaceContainer.withAlpha(64),
      ),
      modalBorderColor: const Color.fromRGBO(255, 255, 255, 0.4),
      paneColor: colorScheme.surfaceContainerLowest.withAlpha(
        192,
      ), // 75% opacity
      infoSnackBar: AppSnackBarColors(
        background: info.colorContainer,
        foreground: info.onColorContainer,
        actionForeground: info.color,
      ),
      warningSnackBar: AppSnackBarColors(
        background: warning.colorContainer,
        foreground: warning.onColorContainer,
        actionForeground: warning.color,
      ),
      errorSnackBar: AppSnackBarColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        actionForeground: colorScheme.error,
      ),
    );
  }

  factory AppColorsThemeExtension.dark(ColorScheme colorScheme) {
    final info = _MaterialColorTest.dark(colorScheme.primary);
    final warning = _MaterialColorTest.dark(Colors.orange);
    return AppColorsThemeExtension._(
      blurredBoxBackgroundColor: Color.alphaBlend(
        colorScheme.primary.withAlpha(17),
        colorScheme.surface.withAlpha(102),
      ),
      modalBorderColor: const Color.fromRGBO(255, 255, 255, 0.15),
      paneColor: colorScheme.surfaceContainerLowest,
      infoSnackBar: AppSnackBarColors(
        background: info.colorContainer,
        foreground: info.onColorContainer,
        actionForeground: info.color,
      ),
      warningSnackBar: AppSnackBarColors(
        background: warning.colorContainer,
        foreground: warning.onColorContainer,
        actionForeground: warning.color,
      ),
      errorSnackBar: AppSnackBarColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        actionForeground: colorScheme.error,
      ),
    );
  }

  final Color blurredBoxBackgroundColor;
  final Color modalBorderColor;
  final Color paneColor;
  final AppSnackBarColors infoSnackBar;
  final AppSnackBarColors warningSnackBar;
  final AppSnackBarColors errorSnackBar;

  @override
  ThemeExtension<AppColorsThemeExtension> copyWith({
    Color? blurredBoxBackgroundColor,
    Color? modalBorderColor,
    Color? paneColor,
    AppSnackBarColors? infoSnackBar,
    AppSnackBarColors? warningSnackBar,
    AppSnackBarColors? errorSnackBar,
  }) => AppColorsThemeExtension._(
    blurredBoxBackgroundColor:
        blurredBoxBackgroundColor ?? this.blurredBoxBackgroundColor,
    modalBorderColor: modalBorderColor ?? this.modalBorderColor,
    paneColor: paneColor ?? this.paneColor,
    infoSnackBar: infoSnackBar ?? this.infoSnackBar,
    warningSnackBar: warningSnackBar ?? this.warningSnackBar,
    errorSnackBar: errorSnackBar ?? this.errorSnackBar,
  );

  @override
  ThemeExtension<AppColorsThemeExtension> lerp(
    ThemeExtension<AppColorsThemeExtension>? other,
    double t,
  ) {
    if (other is! AppColorsThemeExtension) {
      return this;
    }
    return AppColorsThemeExtension._(
      blurredBoxBackgroundColor: Color.lerp(
        blurredBoxBackgroundColor,
        other.blurredBoxBackgroundColor,
        t,
      )!,
      modalBorderColor: Color.lerp(
        modalBorderColor,
        other.modalBorderColor,
        t,
      )!,
      paneColor: Color.lerp(paneColor, other.paneColor, t)!,
      infoSnackBar: AppSnackBarColors.lerp(
        infoSnackBar,
        other.infoSnackBar,
        t,
      ),
      warningSnackBar: AppSnackBarColors.lerp(
        warningSnackBar,
        other.warningSnackBar,
        t,
      ),
      errorSnackBar: AppSnackBarColors.lerp(
        errorSnackBar,
        other.errorSnackBar,
        t,
      ),
    );
  }
}

class _MaterialColorTest {
  _MaterialColorTest({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  factory _MaterialColorTest.light(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return _MaterialColorTest(
      color: hsl.withLightness(0.4).toColor(),
      onColor: Colors.white,
      colorContainer: hsl.withLightness(0.9).toColor(),
      onColorContainer: hsl.withLightness(0.1).toColor(),
    );
  }

  factory _MaterialColorTest.dark(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return _MaterialColorTest(
      color: hsl.withLightness(0.8).toColor(),
      onColor: hsl.withLightness(0.2).toColor(),
      colorContainer: hsl.withLightness(0.3).toColor(),
      onColorContainer: hsl.withLightness(0.9).toColor(),
    );
  }

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
