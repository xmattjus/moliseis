// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/sources/app_settings.dart';
import 'package:moliseis/data/sources/settings_local_data_source.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('SettingsLocalDataSource', () {
    late _FakeSettingsBox fakeSettingsBox;
    late SettingsLocalDataSource dataSource;

    setUp(() {
      fakeSettingsBox = _FakeSettingsBox();
      dataSource = SettingsLocalDataSource.fromBox(fakeSettingsBox);
    });

    test('load returns default settings when no entity is stored', () async {
      final result = await dataSource.load();

      expect(result, isA<Success<AppSettings>>());
      final settings = (result as Success<AppSettings>).value;
      expect(settings.id, AppSettings.singletonId);
      expect(settings.type, ThemeType.system);
      expect(settings.brightness, ThemeBrightness.system);
      expect(settings.contentSort, ContentSort.byName);
      expect(settings.crashReporting, isTrue);
    });

    test('load always reads the singleton id record', () async {
      final nonSingletonSettings = AppSettings(
        type: ThemeType.app,
        brightness: ThemeBrightness.dark,
        contentSort: ContentSort.byDate,
        crashReporting: false,
      )..id = 999;

      final singletonSettings = AppSettings(
        type: ThemeType.system,
        brightness: ThemeBrightness.light,
        contentSort: ContentSort.byName,
        crashReporting: true,
      );

      fakeSettingsBox.put(nonSingletonSettings);
      fakeSettingsBox.put(singletonSettings);

      final result = await dataSource.load();

      expect(result, isA<Success<AppSettings>>());
      final loadedSettings = (result as Success<AppSettings>).value;
      expect(loadedSettings.id, AppSettings.singletonId);
      expect(loadedSettings.type, ThemeType.system);
      expect(loadedSettings.brightness, ThemeBrightness.light);
      expect(loadedSettings.contentSort, ContentSort.byName);
      expect(loadedSettings.crashReporting, isTrue);
    });

    test('load returns error when box access throws', () async {
      fakeSettingsBox.throwOnGet = true;

      final result = await dataSource.load();

      expect(result, isA<Error<AppSettings>>());
    });

    test('save persists settings in the singleton slot', () async {
      final updatedSettings = AppSettings(
        type: ThemeType.app,
        brightness: ThemeBrightness.dark,
        contentSort: ContentSort.byDate,
        crashReporting: false,
      );

      final saveResult = await dataSource.save(updatedSettings);
      final loadResult = await dataSource.load();

      expect(saveResult, isA<Success<void>>());
      expect(loadResult, isA<Success<AppSettings>>());

      final loadedSettings = (loadResult as Success<AppSettings>).value;
      expect(loadedSettings.id, AppSettings.singletonId);
      expect(loadedSettings.type, ThemeType.app);
      expect(loadedSettings.brightness, ThemeBrightness.dark);
      expect(loadedSettings.contentSort, ContentSort.byDate);
      expect(loadedSettings.crashReporting, isFalse);
    });

    test('save returns error when box write throws', () async {
      fakeSettingsBox.throwOnPut = true;

      final result = await dataSource.save(AppSettings());

      expect(result, isA<Error<void>>());
    });
  });
}

final class _FakeSettingsBox implements ISettingsBox {
  final Map<int, AppSettings> _store = <int, AppSettings>{};

  bool throwOnGet = false;
  bool throwOnPut = false;

  @override
  AppSettings? get(int id) {
    if (throwOnGet) throw _TestException('get failed');
    return _store[id];
  }

  @override
  void put(AppSettings settings) {
    if (throwOnPut) throw _TestException('put failed');
    _store[settings.id] = settings;
  }
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
