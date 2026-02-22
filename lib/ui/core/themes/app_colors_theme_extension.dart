import 'package:flutter/material.dart';

class AppColorsThemeExtension extends ThemeExtension<AppColorsThemeExtension> {
  final Color blurredBoxBackgroundColor;
  final Color modalBorderColor;
  final Color paneColor;

  const AppColorsThemeExtension._({
    required this.blurredBoxBackgroundColor,
    required this.modalBorderColor,
    required this.paneColor,
  });

  factory AppColorsThemeExtension.light(ColorScheme colorScheme) {
    return AppColorsThemeExtension._(
      blurredBoxBackgroundColor: Color.alphaBlend(
        colorScheme.primary.withAlpha(17),
        colorScheme.surfaceContainer.withAlpha(64),
      ),
      modalBorderColor: const Color.fromRGBO(255, 255, 255, 0.4),
      paneColor: colorScheme.surfaceContainerLowest.withAlpha(
        192,
      ), // 75% opacity
    );
  }

  factory AppColorsThemeExtension.dark(ColorScheme colorScheme) {
    return AppColorsThemeExtension._(
      blurredBoxBackgroundColor: Color.alphaBlend(
        colorScheme.primary.withAlpha(17),
        colorScheme.surface.withAlpha(102),
      ),
      modalBorderColor: const Color.fromRGBO(255, 255, 255, 0.15),
      paneColor: colorScheme.surfaceContainerLowest,
    );
  }

  @override
  ThemeExtension<AppColorsThemeExtension> copyWith({
    ColorScheme? colorScheme,
    Color? blurredBoxBackgroundColor,
    Color? modalBorderColor,
    Color? paneColor,
  }) {
    return AppColorsThemeExtension._(
      blurredBoxBackgroundColor:
          blurredBoxBackgroundColor ?? this.blurredBoxBackgroundColor,
      modalBorderColor: modalBorderColor ?? this.modalBorderColor,
      paneColor: paneColor ?? this.paneColor,
    );
  }

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
    );
  }
}
