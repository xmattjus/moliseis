import 'package:flutter/material.dart';

extension ColorExtensions on Color? {
  /// Darkens the color by the specified [amount].
  ///
  /// The [amount] parameter should be between 0.0 and 1.0, where:
  /// - 0.0 means no change
  /// - 1.0 means maximum darkening (towards black)
  ///
  /// Returns null if the original color is null.
  ///
  /// Example:
  /// ```dart
  /// Color red = Colors.red;
  /// Color darkerRed = red.darken(0.2); // 20% darker
  /// ```
  Color? darken(double amount) => _changeLightness(-amount);

  /// Lightens the color by the specified [amount].
  ///
  /// The [amount] parameter should be between 0.0 and 1.0, where:
  /// - 0.0 means no change
  /// - 1.0 means maximum lightening (towards white)
  ///
  /// Returns null if the original color is null.
  ///
  /// Example:
  /// ```dart
  /// Color blue = Colors.blue;
  /// Color lighterBlue = blue.lighten(0.3); // 30% lighter
  /// ```
  Color? lighten(double amount) => _changeLightness(amount);

  /// Internal method that changes the lightness of the color by the specified [amount].
  ///
  /// The [amount] can be positive (to lighten) or negative (to darken).
  /// The absolute value of [amount] must not exceed 1.0.
  ///
  /// The method converts the color to HSL, adjusts the lightness value,
  /// clamps it between 0.0 and 1.0, and converts back to RGB.
  ///
  /// Returns null if the original color is null.
  ///
  /// Throws an [AssertionError] if the absolute value of [amount] exceeds 1.0.
  Color? _changeLightness(double amount) {
    if (this == null) return null;

    assert(amount.abs() <= 1);

    final hsl = HSLColor.fromColor(this!);
    final hslNew = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslNew.toColor();
  }
}
