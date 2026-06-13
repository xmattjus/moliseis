import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';

void main() {
  group('ThemeViewModel', () {
    group('setThemeType', () {
      test('updates themeType on success', () async {
        final vm = buildViewModel();

        await vm.setThemeType.execute(ThemeType.app);

        expect(vm.setThemeType.completed, isTrue);
        expect(vm.themeType, ThemeType.app);
      });

      test(
        'reverts themeType to previous value when repository write fails',
        () async {
          final vm = buildViewModel(
            setThemeTypeResult: Result.error(TestException('write failed')),
          );

          await vm.setThemeType.execute(ThemeType.app);

          expect(vm.setThemeType.error, isTrue);
          expect(vm.themeType, ThemeType.system);
        },
      );
    });

    group('setThemeBrightness', () {
      test('updates themeBrightness on success', () async {
        final vm = buildViewModel();

        await vm.setThemeBrightness.execute(ThemeBrightness.dark);

        expect(vm.setThemeBrightness.completed, isTrue);
        expect(vm.themeBrightness, ThemeBrightness.dark);
      });

      test(
        'reverts themeBrightness to previous value when repository write fails',
        () async {
          final vm = buildViewModel(
            themeBrightness: ThemeBrightness.light,
            setThemeBrightnessResult: Result.error(
              TestException('write failed'),
            ),
          );

          await vm.setThemeBrightness.execute(ThemeBrightness.dark);

          expect(vm.setThemeBrightness.error, isTrue);
          expect(vm.themeBrightness, ThemeBrightness.light);
        },
      );
    });

    group('themeMode', () {
      test('maps system brightness to ThemeMode.system', () {
        final vm = buildViewModel();
        expect(vm.themeMode, ThemeMode.system);
      });

      test('maps light brightness to ThemeMode.light', () {
        final vm = buildViewModel(themeBrightness: ThemeBrightness.light);
        expect(vm.themeMode, ThemeMode.light);
      });

      test('maps dark brightness to ThemeMode.dark', () {
        final vm = buildViewModel(themeBrightness: ThemeBrightness.dark);
        expect(vm.themeMode, ThemeMode.dark);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

ThemeViewModel buildViewModel({
  ThemeType themeType = ThemeType.system,
  ThemeBrightness themeBrightness = ThemeBrightness.system,
  Result<void>? setThemeTypeResult,
  Result<void>? setThemeBrightnessResult,
}) {
  return ThemeViewModel(
    settingsRepository: FakeSettingsRepository(
      themeType: themeType,
      themeBrightness: themeBrightness,
      setThemeTypeResult: setThemeTypeResult ?? const Result.success(null),
      setThemeBrightnessResult:
          setThemeBrightnessResult ?? const Result.success(null),
    ),
  );
}
