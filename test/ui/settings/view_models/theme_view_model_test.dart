import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/fake_repositories.dart';

void main() {
  group('ThemeViewModel', () {
    test(
      'defers entry and preserves optimistic notify before repository write',
      () async {
        final repository = FakeSettingsRepository();
        final pending = Completer<Result<void>>();
        final events = <String>[];
        final vm = ThemeViewModel(settingsRepository: repository);
        addTearDown(vm.dispose);
        vm.addListener(() => events.add('notify:${vm.themeBrightness.name}'));
        repository.onSetThemeBrightness = (value) {
          events.add('write:${value.name}');
          return pending.future;
        };
        final execution = vm.setThemeBrightness.runAsync(ThemeBrightness.dark);
        expect(vm.themeBrightness, ThemeBrightness.system);
        expect(events, isEmpty);
        await Future<void>.delayed(Duration.zero);
        expect(vm.themeBrightness, ThemeBrightness.dark);
        expect(events, ['notify:dark', 'write:dark']);
        pending.complete(const Result.success(null));
        await execution;
      },
    );
    for (final brightnessFirst in [true, false]) {
      for (final failBrightness in [true, false]) {
        for (final failType in [true, false]) {
          test('independent lanes brightnessFirst=$brightnessFirst '
              'brightnessError=$failBrightness typeError=$failType', () async {
            final repository = FakeSettingsRepository();
            final vm = ThemeViewModel(settingsRepository: repository);
            addTearDown(vm.dispose);
            final brightness = Completer<Result<void>>();
            final type = Completer<Result<void>>();
            final events = <String>[];
            void onOptimisticChange() {
              events.add(
                'notify:${vm.themeBrightness.name}:${vm.themeType.name}',
              );
              // A reentrant duplicate must remain in its own admitted lane.
              vm.setThemeBrightness.run(ThemeBrightness.light);
              vm.setThemeType.run(ThemeType.system);
            }

            vm.addListener(onOptimisticChange);
            repository
              ..onSetThemeBrightness = (value) {
                events.add('brightness:${value.name}');
                return brightness.future;
              }
              ..onSetThemeType = (value) {
                events.add('type:${value.name}');
                return type.future;
              };
            final brightnessRun = vm.setThemeBrightness.runAsync(
              ThemeBrightness.dark,
            );
            final typeRun = vm.setThemeType.runAsync(ThemeType.app);
            vm.setThemeBrightness.run(ThemeBrightness.light);
            vm.setThemeType.run(ThemeType.system);
            expect(events, isEmpty);
            await Future<void>.delayed(Duration.zero);
            expect(events, [
              'notify:dark:system',
              'brightness:dark',
              'notify:dark:app',
              'type:app',
            ]);
            final brightnessResult = failBrightness
                ? Result<void>.error(TestException('brightness failed'))
                : const Result<void>.success(null);
            final typeResult = failType
                ? Result<void>.error(TestException('type failed'))
                : const Result<void>.success(null);
            // Remove the duplicate-attempt observer before terminal rollback;
            // already settled independent lanes admit new intents.
            vm.removeListener(onOptimisticChange);
            if (brightnessFirst) {
              brightness.complete(brightnessResult);
              expect(await brightnessRun, same(brightnessResult));
              expect(vm.themeType, ThemeType.app);
              type.complete(typeResult);
              expect(await typeRun, same(typeResult));
            } else {
              type.complete(typeResult);
              expect(await typeRun, same(typeResult));
              expect(vm.themeBrightness, ThemeBrightness.dark);
              brightness.complete(brightnessResult);
              expect(await brightnessRun, same(brightnessResult));
            }
            expect(
              vm.themeBrightness,
              failBrightness ? ThemeBrightness.system : ThemeBrightness.dark,
            );
            expect(vm.themeType, failType ? ThemeType.system : ThemeType.app);
            expect(
              events.where((e) => e.startsWith('brightness:')),
              hasLength(1),
            );
            expect(events.where((e) => e.startsWith('type:')), hasLength(1));
          });
        }
      }
    }

    group('setThemeType', () {
      test('updates themeType on success', () async {
        final vm = buildViewModel();

        await vm.setThemeType.runAsync(ThemeType.app);

        expect(vm.setThemeType.results.value.completed, isTrue);
        expect(vm.themeType, ThemeType.app);
      });

      test(
        'reverts themeType to previous value when repository write fails',
        () async {
          final vm = buildViewModel(
            setThemeTypeResult: Result.error(TestException('write failed')),
          );

          await vm.setThemeType.runAsync(ThemeType.app);

          expect(vm.setThemeType.results.value.hasFailure, isTrue);
          expect(vm.themeType, ThemeType.system);
        },
      );
    });

    group('setThemeBrightness', () {
      test('updates themeBrightness on success', () async {
        final vm = buildViewModel();

        await vm.setThemeBrightness.runAsync(ThemeBrightness.dark);

        expect(vm.setThemeBrightness.results.value.completed, isTrue);
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

          await vm.setThemeBrightness.runAsync(ThemeBrightness.dark);

          expect(vm.setThemeBrightness.results.value.hasFailure, isTrue);
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
  final vm = ThemeViewModel(
    settingsRepository: FakeSettingsRepository(
      themeType: themeType,
      themeBrightness: themeBrightness,
      setThemeTypeResult: setThemeTypeResult ?? const Result.success(null),
      setThemeBrightnessResult:
          setThemeBrightnessResult ?? const Result.success(null),
    ),
  );
  addTearDown(vm.dispose);
  return vm;
}
