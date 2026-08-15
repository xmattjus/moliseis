import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/themes/app_snack_bar_colors.dart';

void main() {
  group('AppSnackBarColors.lerp', () {
    const x = AppSnackBarColors(
      background: Colors.red,
      foreground: Colors.green,
      actionForeground: Colors.blue,
    );
    const y = AppSnackBarColors(
      background: Colors.white,
      foreground: Colors.black,
      actionForeground: Colors.yellow,
    );

    test('returns x channels at t = 0', () {
      final result = AppSnackBarColors.lerp(x, y, 0);

      expect(
        result.background,
        equals(Color.lerp(x.background, y.background, 0)),
      );
      expect(
        result.foreground,
        equals(Color.lerp(x.foreground, y.foreground, 0)),
      );
      expect(
        result.actionForeground,
        equals(Color.lerp(x.actionForeground, y.actionForeground, 0)),
      );
    });

    test('returns y channels at t = 1', () {
      final result = AppSnackBarColors.lerp(x, y, 1);

      expect(
        result.background,
        equals(Color.lerp(x.background, y.background, 1)),
      );
      expect(
        result.foreground,
        equals(Color.lerp(x.foreground, y.foreground, 1)),
      );
      expect(
        result.actionForeground,
        equals(Color.lerp(x.actionForeground, y.actionForeground, 1)),
      );
    });

    test('interpolates each channel at t = 0.5', () {
      final result = AppSnackBarColors.lerp(x, y, 0.5);

      expect(
        result.background,
        equals(Color.lerp(x.background, y.background, 0.5)),
      );
      expect(
        result.foreground,
        equals(Color.lerp(x.foreground, y.foreground, 0.5)),
      );
      expect(
        result.actionForeground,
        equals(Color.lerp(x.actionForeground, y.actionForeground, 0.5)),
      );
    });
  });
}
