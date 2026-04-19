import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/result.dart';

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
            setThemeTypeResult: Result.error(_TestException('write failed')),
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
            initialBrightness: ThemeBrightness.light,
            setThemeBrightnessResult: Result.error(
              _TestException('write failed'),
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
        final vm = buildViewModel(initialBrightness: ThemeBrightness.light);
        expect(vm.themeMode, ThemeMode.light);
      });

      test('maps dark brightness to ThemeMode.dark', () {
        final vm = buildViewModel(initialBrightness: ThemeBrightness.dark);
        expect(vm.themeMode, ThemeMode.dark);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

ThemeViewModel buildViewModel({
  ThemeType initialType = ThemeType.system,
  ThemeBrightness initialBrightness = ThemeBrightness.system,
  Result<void>? setThemeTypeResult,
  Result<void>? setThemeBrightnessResult,
}) {
  return ThemeViewModel(
    settingsRepository: _FakeSettingsRepository(
      initialType: initialType,
      initialBrightness: initialBrightness,
      setThemeTypeResult: setThemeTypeResult ?? const Result.success(null),
      setThemeBrightnessResult:
          setThemeBrightnessResult ?? const Result.success(null),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

final class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    required ThemeType initialType,
    required ThemeBrightness initialBrightness,
    required Result<void> setThemeTypeResult,
    required Result<void> setThemeBrightnessResult,
  }) : _themeType = initialType,
       _themeBrightness = initialBrightness,
       _setThemeTypeResult = setThemeTypeResult,
       _setThemeBrightnessResult = setThemeBrightnessResult;

  ThemeType _themeType;
  ThemeBrightness _themeBrightness;
  final Result<void> _setThemeTypeResult;
  final Result<void> _setThemeBrightnessResult;

  @override
  ThemeType get themeType => _themeType;

  @override
  ThemeBrightness get themeBrightness => _themeBrightness;

  @override
  bool get crashReporting => false;

  @override
  ContentSort get contentSort => ContentSort.byName;

  @override
  DateTime? get modifiedAt => null;

  @override
  Future<Result<void>> initialize() async => const Result.success(null);

  @override
  Future<Result<void>> setThemeType(ThemeType type) async {
    if (_setThemeTypeResult.isSuccess) _themeType = type;
    return _setThemeTypeResult;
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async {
    if (_setThemeBrightnessResult.isSuccess) _themeBrightness = brightness;
    return _setThemeBrightnessResult;
  }

  @override
  Future<Result<void>> setCrashReporting(bool enable) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async =>
      const Result.success(null);

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async =>
      const Result.success(null);
}

// ---------------------------------------------------------------------------
// Test exception
// ---------------------------------------------------------------------------

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
