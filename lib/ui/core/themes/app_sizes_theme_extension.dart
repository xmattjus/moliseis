import 'dart:ui';

import 'package:flutter/material.dart';

class AppSizesThemeExtension extends ThemeExtension<AppSizesThemeExtension> {
  /// The minimum snap size all modals should have.
  final double modalMinSnapSize;

  /// The snap sizes, e.g. the screen percentages at which all modals should
  /// "snap" in place.
  final List<double> modalSnapSizes;

  final double borderSize;

  const AppSizesThemeExtension._internal({
    required this.modalMinSnapSize,
    required this.modalSnapSizes,
    required this.borderSize,
  });

  factory AppSizesThemeExtension.defaultSizes() {
    return const AppSizesThemeExtension._internal(
      modalMinSnapSize: 0.20,
      modalSnapSizes: [0.20, 0.35, 0.50],
      borderSize: 1.20,
    );
  }

  @override
  ThemeExtension<AppSizesThemeExtension> copyWith({
    double? modalMinSnapSize,
    List<double>? modalSnapSizes,
    double? borderSize,
  }) {
    return AppSizesThemeExtension._internal(
      modalMinSnapSize: modalMinSnapSize ?? this.modalMinSnapSize,
      modalSnapSizes: modalSnapSizes ?? this.modalSnapSizes,
      borderSize: borderSize ?? this.borderSize,
    );
  }

  @override
  AppSizesThemeExtension lerp(
    ThemeExtension<AppSizesThemeExtension>? other,
    double t,
  ) {
    if (other is! AppSizesThemeExtension) {
      return this;
    }
    return AppSizesThemeExtension._internal(
      modalMinSnapSize: lerpDouble(
        modalMinSnapSize,
        other.modalMinSnapSize,
        t,
      )!,
      modalSnapSizes: List<double>.generate(
        modalSnapSizes.length,
        (index) =>
            lerpDouble(modalSnapSizes[index], other.modalSnapSizes[index], t)!,
      ),
      borderSize: lerpDouble(borderSize, other.borderSize, t)!,
    );
  }
}
