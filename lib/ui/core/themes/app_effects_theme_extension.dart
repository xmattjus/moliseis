import 'dart:ui';

import 'package:flutter/material.dart';

class AppEffectsThemeExtension
    extends ThemeExtension<AppEffectsThemeExtension> {
  final ImageFilter modalBlurEffect;

  const AppEffectsThemeExtension._internal({required this.modalBlurEffect});

  factory AppEffectsThemeExtension.defaultEffects() {
    return AppEffectsThemeExtension._internal(
      modalBlurEffect: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
    );
  }

  @override
  ThemeExtension<AppEffectsThemeExtension> copyWith({
    ImageFilter? modalBlurEffect,
  }) {
    return AppEffectsThemeExtension._internal(
      modalBlurEffect: modalBlurEffect ?? this.modalBlurEffect,
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
