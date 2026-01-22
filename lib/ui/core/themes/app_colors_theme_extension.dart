import 'package:flutter/material.dart';

class AppColorsThemeExtension extends ThemeExtension<AppColorsThemeExtension> {
  final Color modalBackgroundColor;
  final Color modalBorderColor;

  const AppColorsThemeExtension._internal({
    required this.modalBackgroundColor,
    required this.modalBorderColor,
  });

  factory AppColorsThemeExtension.light() {
    return AppColorsThemeExtension._internal(
      modalBackgroundColor: Colors.white.withValues(alpha: 0.15),
      modalBorderColor: Colors.white.withValues(alpha: 0.2),
    );
  }

  factory AppColorsThemeExtension.dark() {
    return AppColorsThemeExtension._internal(
      modalBackgroundColor: Colors.black87.withValues(alpha: 0.45),
      modalBorderColor: Colors.white.withValues(alpha: 0.15),
    );
  }

  @override
  ThemeExtension<AppColorsThemeExtension> copyWith({
    Color? modalBackgroundColor,
    Color? modalBorderColor,
  }) {
    return AppColorsThemeExtension._internal(
      modalBackgroundColor: modalBackgroundColor ?? this.modalBackgroundColor,
      modalBorderColor: modalBorderColor ?? this.modalBorderColor,
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
    return AppColorsThemeExtension._internal(
      modalBackgroundColor: Color.lerp(
        modalBackgroundColor,
        other.modalBackgroundColor,
        t,
      )!,
      modalBorderColor: Color.lerp(
        modalBorderColor,
        other.modalBorderColor,
        t,
      )!,
    );
  }
}
