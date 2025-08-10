import 'dart:math' show pow;

import 'package:flutter/material.dart';

class AppColorUtils {
  AppColorUtils._();

  /// Source: https://stackoverflow.com/a/21682946.
  static Color stringToColor(
    String string, [
    double saturation = 1.0,
    double lightness = 0.0,
  ]) {
    int hash = 0;

    for (int i = 0; i < string.length; i++) {
      hash = string.codeUnitAt(i) + ((hash << 5) - hash);
      hash = hash & hash;
    }

    final hslColor = HSLColor.fromAHSL(1.0, hash % 360, saturation, lightness);

    return hslColor.toColor();
  }

  ///
  /// Sources:
  /// https://stackoverflow.com/a/77124714,
  /// https://github.com/Myndex/max-contrast.
  static Brightness maxContrast([List<double> rgb = const [0xa4, 0xa4, 0xa4]]) {
    assert(rgb.length == 3);

    // Based on APCA™ 0.98G middle contrast background color.
    const double flipYs = 0.342;

    const double trc = 2.4;

    const List<double> rgbCo = [0.2126729, 0.7151522, 0.0721750];

    var ys = 0.0;

    for (var i = 0; i < rgb.length; i++) {
      ys += pow(rgb[i] / 255.0, trc) * rgbCo[i];
    }

    return ys < flipYs ? Brightness.dark : Brightness.light;
  }
}
