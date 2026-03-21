import 'dart:async' show Future;

import 'package:moliseis/data/sources/app_settings.dart';
import 'package:moliseis/data/sources/settings_local_data_source.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final ISettingsLocalDataSource _dataSource;
  AppSettings? _settings;

  SettingsRepositoryImpl(this._dataSource);

  AppSettings get _cache {
    if (_settings == null) {
      throw StateError(
        'SettingsRepositoryImpl has not been initialized. '
        'Call initialize() and await completion before accessing app settings.',
      );
    }

    return _settings!;
  }

  @override
  Future<Result<void>> initialize() async {
    final result = await _dataSource.load();

    switch (result) {
      case Success<AppSettings>():
        _settings = result.value;
      case Error<AppSettings>():
        // I/O failed but we have safe defaults — app can still run.
        _settings = AppSettings();
    }

    return result;
  }

  Future<Result<void>> _persistNewSettings(AppSettings newSettings) async {
    final result = await _dataSource.save(newSettings);

    if (result is Success<void>) {
      _settings = newSettings;
    }

    return result;
  }

  @override
  ContentSort get contentSort => _cache.contentSort;

  @override
  bool get crashReporting => _cache.crashReporting;

  @override
  DateTime? get modifiedAt => _cache.modifiedAt;

  @override
  ThemeBrightness get themeBrightness => _cache.brightness;

  @override
  ThemeType get themeType => _cache.type;

  @override
  Future<Result<void>> setContentSort(ContentSort sort) {
    final newSettings = _cache.copyWith(contentSort: sort);
    return _persistNewSettings(newSettings);
  }

  @override
  Future<Result<void>> setCrashReporting(bool enable) {
    final newSettings = _cache.copyWith(crashReporting: enable);
    return _persistNewSettings(newSettings);
  }

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) {
    final newSettings = _cache.copyWith(modifiedAt: dateTime);
    return _persistNewSettings(newSettings);
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) {
    final newSettings = _cache.copyWith(brightness: brightness);
    return _persistNewSettings(newSettings);
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) {
    final newSettings = _cache.copyWith(type: type);
    return _persistNewSettings(newSettings);
  }
}
