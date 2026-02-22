import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';

typedef ColorFunction = Color Function(Color primary, Color surface);

class AppEffectsThemeExtension
    extends ThemeExtension<AppEffectsThemeExtension> {
  final ui.ImageFilter modalBlurEffect;
  final ColorFunction containerColor;
  final ColorFunction containerColor2;

  factory AppEffectsThemeExtension() {
    return AppEffectsThemeExtension._(
      modalBlurEffect: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      containerColor: (Color primary, Color surface) {
        return Color.alphaBlend(primary.withAlpha(17), surface.withAlpha(51));
      },
      containerColor2: (Color primary, Color surface) {
        return Color.alphaBlend(primary.withAlpha(54), surface.withAlpha(51));
      },
    );
  }

  const AppEffectsThemeExtension._({
    required this.modalBlurEffect,
    required this.containerColor,
    required this.containerColor2,
  });

  @override
  ThemeExtension<AppEffectsThemeExtension> copyWith({
    ui.ImageFilter? modalBlurEffect,
    ColorFunction? containerColor,
    ColorFunction? containerColor2,
  }) {
    return AppEffectsThemeExtension._(
      modalBlurEffect: modalBlurEffect ?? this.modalBlurEffect,
      containerColor: containerColor ?? this.containerColor,
      containerColor2: containerColor2 ?? this.containerColor2,
    );
  }

  @override
  ThemeExtension<AppEffectsThemeExtension> lerp(
    covariant ThemeExtension<AppEffectsThemeExtension>? other,
    double t,
  ) {
    if (other is! AppEffectsThemeExtension) {
      return this;
    }
    return other;
  }
}
