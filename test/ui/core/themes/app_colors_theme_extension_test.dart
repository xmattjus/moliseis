import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_snack_bar_colors.dart';

void main() {
  AppColorsThemeExtension buildLight() => AppColorsThemeExtension.light(
    ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  );

  AppColorsThemeExtension buildDark() => AppColorsThemeExtension.dark(
    ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );

  group('AppColorsThemeExtension.copyWith', () {
    test('keeps all fields when no arguments are provided', () {
      final original = buildLight();
      final copy = original.copyWith() as AppColorsThemeExtension;

      expect(
        copy.blurredBoxBackgroundColor,
        equals(original.blurredBoxBackgroundColor),
      );
      expect(copy.modalBorderColor, equals(original.modalBorderColor));
      expect(copy.paneColor, equals(original.paneColor));
      expect(
        copy.infoSnackBar.background,
        equals(original.infoSnackBar.background),
      );
      expect(
        copy.infoSnackBar.foreground,
        equals(original.infoSnackBar.foreground),
      );
      expect(
        copy.infoSnackBar.actionForeground,
        equals(original.infoSnackBar.actionForeground),
      );
      expect(
        copy.warningSnackBar.background,
        equals(original.warningSnackBar.background),
      );
      expect(
        copy.warningSnackBar.foreground,
        equals(original.warningSnackBar.foreground),
      );
      expect(
        copy.warningSnackBar.actionForeground,
        equals(original.warningSnackBar.actionForeground),
      );
      expect(
        copy.errorSnackBar.background,
        equals(original.errorSnackBar.background),
      );
      expect(
        copy.errorSnackBar.foreground,
        equals(original.errorSnackBar.foreground),
      );
      expect(
        copy.errorSnackBar.actionForeground,
        equals(original.errorSnackBar.actionForeground),
      );
    });

    test('replaces only the given Color fields', () {
      final original = buildLight();
      final copy =
          original.copyWith(
                paneColor: Colors.red,
                modalBorderColor: Colors.green,
              )
              as AppColorsThemeExtension;

      expect(copy.paneColor, equals(Colors.red));
      expect(copy.modalBorderColor, equals(Colors.green));
      expect(
        copy.blurredBoxBackgroundColor,
        equals(original.blurredBoxBackgroundColor),
      );
      expect(
        copy.infoSnackBar.background,
        equals(original.infoSnackBar.background),
      );
      expect(
        copy.infoSnackBar.foreground,
        equals(original.infoSnackBar.foreground),
      );
      expect(
        copy.infoSnackBar.actionForeground,
        equals(original.infoSnackBar.actionForeground),
      );
      expect(
        copy.warningSnackBar.background,
        equals(original.warningSnackBar.background),
      );
      expect(
        copy.warningSnackBar.foreground,
        equals(original.warningSnackBar.foreground),
      );
      expect(
        copy.warningSnackBar.actionForeground,
        equals(original.warningSnackBar.actionForeground),
      );
      expect(
        copy.errorSnackBar.background,
        equals(original.errorSnackBar.background),
      );
      expect(
        copy.errorSnackBar.foreground,
        equals(original.errorSnackBar.foreground),
      );
      expect(
        copy.errorSnackBar.actionForeground,
        equals(original.errorSnackBar.actionForeground),
      );
    });

    test('swaps an AppSnackBarColors triplet as a unit', () {
      final original = buildLight();
      const replacement = AppSnackBarColors(
        background: Colors.pink,
        foreground: Colors.teal,
        actionForeground: Colors.amber,
      );
      final copy =
          original.copyWith(
                infoSnackBar: replacement,
              )
              as AppColorsThemeExtension;

      expect(copy.infoSnackBar.background, equals(Colors.pink));
      expect(copy.infoSnackBar.foreground, equals(Colors.teal));
      expect(copy.infoSnackBar.actionForeground, equals(Colors.amber));
      expect(
        copy.warningSnackBar.background,
        equals(original.warningSnackBar.background),
      );
      expect(
        copy.warningSnackBar.foreground,
        equals(original.warningSnackBar.foreground),
      );
      expect(
        copy.warningSnackBar.actionForeground,
        equals(original.warningSnackBar.actionForeground),
      );
      expect(
        copy.errorSnackBar.background,
        equals(original.errorSnackBar.background),
      );
      expect(
        copy.errorSnackBar.foreground,
        equals(original.errorSnackBar.foreground),
      );
      expect(
        copy.errorSnackBar.actionForeground,
        equals(original.errorSnackBar.actionForeground),
      );
    });
  });

  group('AppColorsThemeExtension.lerp', () {
    test('returns this when other is null (non-matching branch)', () {
      final original = buildLight();
      // Null exercises the `other is! AppColorsThemeExtension` branch.
      final result = original.lerp(null, 0.5) as AppColorsThemeExtension;

      expect(
        result.blurredBoxBackgroundColor,
        equals(original.blurredBoxBackgroundColor),
      );
      expect(result.modalBorderColor, equals(original.modalBorderColor));
      expect(result.paneColor, equals(original.paneColor));
      expect(
        result.infoSnackBar.background,
        equals(original.infoSnackBar.background),
      );
      expect(
        result.infoSnackBar.foreground,
        equals(original.infoSnackBar.foreground),
      );
      expect(
        result.infoSnackBar.actionForeground,
        equals(original.infoSnackBar.actionForeground),
      );
      expect(
        result.warningSnackBar.background,
        equals(original.warningSnackBar.background),
      );
      expect(
        result.warningSnackBar.foreground,
        equals(original.warningSnackBar.foreground),
      );
      expect(
        result.warningSnackBar.actionForeground,
        equals(original.warningSnackBar.actionForeground),
      );
      expect(
        result.errorSnackBar.background,
        equals(original.errorSnackBar.background),
      );
      expect(
        result.errorSnackBar.foreground,
        equals(original.errorSnackBar.foreground),
      );
      expect(
        result.errorSnackBar.actionForeground,
        equals(original.errorSnackBar.actionForeground),
      );
    });

    test('interp from light at t = 0 returns light channels', () {
      final light = buildLight();
      final dark = buildDark();
      final result = light.lerp(dark, 0) as AppColorsThemeExtension;

      expect(
        result.blurredBoxBackgroundColor,
        equals(light.blurredBoxBackgroundColor),
      );
      expect(result.modalBorderColor, equals(light.modalBorderColor));
      expect(result.paneColor, equals(light.paneColor));
      expect(
        result.infoSnackBar.background,
        equals(light.infoSnackBar.background),
      );
      expect(
        result.infoSnackBar.foreground,
        equals(light.infoSnackBar.foreground),
      );
      expect(
        result.infoSnackBar.actionForeground,
        equals(light.infoSnackBar.actionForeground),
      );
      expect(
        result.warningSnackBar.background,
        equals(light.warningSnackBar.background),
      );
      expect(
        result.warningSnackBar.foreground,
        equals(light.warningSnackBar.foreground),
      );
      expect(
        result.warningSnackBar.actionForeground,
        equals(light.warningSnackBar.actionForeground),
      );
      expect(
        result.errorSnackBar.background,
        equals(light.errorSnackBar.background),
      );
      expect(
        result.errorSnackBar.foreground,
        equals(light.errorSnackBar.foreground),
      );
      expect(
        result.errorSnackBar.actionForeground,
        equals(light.errorSnackBar.actionForeground),
      );
    });

    test('interp from light to dark at t = 1 returns dark channels', () {
      final light = buildLight();
      final dark = buildDark();
      final result = light.lerp(dark, 1) as AppColorsThemeExtension;

      expect(
        result.blurredBoxBackgroundColor,
        equals(dark.blurredBoxBackgroundColor),
      );
      expect(result.modalBorderColor, equals(dark.modalBorderColor));
      expect(result.paneColor, equals(dark.paneColor));
      expect(
        result.infoSnackBar.background,
        equals(dark.infoSnackBar.background),
      );
      expect(
        result.infoSnackBar.foreground,
        equals(dark.infoSnackBar.foreground),
      );
      expect(
        result.infoSnackBar.actionForeground,
        equals(dark.infoSnackBar.actionForeground),
      );
      expect(
        result.warningSnackBar.background,
        equals(dark.warningSnackBar.background),
      );
      expect(
        result.warningSnackBar.foreground,
        equals(dark.warningSnackBar.foreground),
      );
      expect(
        result.warningSnackBar.actionForeground,
        equals(dark.warningSnackBar.actionForeground),
      );
      expect(
        result.errorSnackBar.background,
        equals(dark.errorSnackBar.background),
      );
      expect(
        result.errorSnackBar.foreground,
        equals(dark.errorSnackBar.foreground),
      );
      expect(
        result.errorSnackBar.actionForeground,
        equals(dark.errorSnackBar.actionForeground),
      );
    });

    test('interp at t = 0.5 matches Color.lerp per channel at t = 0.5', () {
      final light = buildLight();
      final dark = buildDark();
      final result = light.lerp(dark, 0.5) as AppColorsThemeExtension;

      expect(
        result.blurredBoxBackgroundColor,
        equals(
          Color.lerp(
            light.blurredBoxBackgroundColor,
            dark.blurredBoxBackgroundColor,
            0.5,
          ),
        ),
      );
      expect(
        result.modalBorderColor,
        equals(Color.lerp(light.modalBorderColor, dark.modalBorderColor, 0.5)),
      );
      expect(
        result.paneColor,
        equals(Color.lerp(light.paneColor, dark.paneColor, 0.5)),
      );
      expect(
        result.infoSnackBar.background,
        equals(
          Color.lerp(
            light.infoSnackBar.background,
            dark.infoSnackBar.background,
            0.5,
          ),
        ),
      );
      expect(
        result.infoSnackBar.foreground,
        equals(
          Color.lerp(
            light.infoSnackBar.foreground,
            dark.infoSnackBar.foreground,
            0.5,
          ),
        ),
      );
      expect(
        result.infoSnackBar.actionForeground,
        equals(
          Color.lerp(
            light.infoSnackBar.actionForeground,
            dark.infoSnackBar.actionForeground,
            0.5,
          ),
        ),
      );
      expect(
        result.warningSnackBar.background,
        equals(
          Color.lerp(
            light.warningSnackBar.background,
            dark.warningSnackBar.background,
            0.5,
          ),
        ),
      );
      expect(
        result.warningSnackBar.foreground,
        equals(
          Color.lerp(
            light.warningSnackBar.foreground,
            dark.warningSnackBar.foreground,
            0.5,
          ),
        ),
      );
      expect(
        result.warningSnackBar.actionForeground,
        equals(
          Color.lerp(
            light.warningSnackBar.actionForeground,
            dark.warningSnackBar.actionForeground,
            0.5,
          ),
        ),
      );
      expect(
        result.errorSnackBar.background,
        equals(
          Color.lerp(
            light.errorSnackBar.background,
            dark.errorSnackBar.background,
            0.5,
          ),
        ),
      );
      expect(
        result.errorSnackBar.foreground,
        equals(
          Color.lerp(
            light.errorSnackBar.foreground,
            dark.errorSnackBar.foreground,
            0.5,
          ),
        ),
      );
      expect(
        result.errorSnackBar.actionForeground,
        equals(
          Color.lerp(
            light.errorSnackBar.actionForeground,
            dark.errorSnackBar.actionForeground,
            0.5,
          ),
        ),
      );
    });
  });
}
