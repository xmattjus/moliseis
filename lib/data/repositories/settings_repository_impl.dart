import 'dart:async' show Future;

import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dataSource);

  final ISettingsLocalDataSource _dataSource;
  AppSettings? _settings;

  void _requireInitialized() {
    if (_settings == null) {
      throw StateError(
        'SettingsRepositoryImpl has not been initialized. '
        'Call initialize() and await completion before accessing app settings.',
      );
    }
  }

  AppSettings get _cache {
    _requireInitialized();
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

  Future<Result<void>> _persistNewSettings(
    AppSettings Function(AppSettings) transform,
  ) async {
    _requireInitialized();
    final result = await _dataSource.update(transform);

    if (result is Success<void>) {
      // Other setting lanes may have committed while this write was pending.
      _settings = transform(_cache);
    }

    return result;
  }

  @override
  ContentSort get contentSort => _cache.contentSort;

  @override
  bool get crashReporting => _cache.crashReporting;

  @override
  DateTime? get lastSyncedAt => _cache.lastSyncedAt;

  @override
  DateTime? get contentSyncCursorAt => _cache.contentSyncCursorAt;

  @override
  ThemeBrightness get themeBrightness => _cache.brightness;

  @override
  ThemeType get themeType => _cache.type;

  @override
  Future<Result<void>> setContentSort(ContentSort sort) {
    return _persistNewSettings(
      (settings) => settings.copyWith(contentSort: sort),
    );
  }

  @override
  Future<Result<void>> setCrashReporting({required bool enable}) {
    return _persistNewSettings(
      (settings) => settings.copyWith(crashReporting: enable),
    );
  }

  @override
  Future<Result<void>> setSyncState({
    required DateTime lastSyncedAt,
    required DateTime contentSyncCursorAt,
  }) {
    return _persistNewSettings(
      (settings) => settings.copyWith(
        lastSyncedAt: lastSyncedAt,
        contentSyncCursorAt: contentSyncCursorAt,
      ),
    );
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) {
    return _persistNewSettings(
      (settings) => settings.copyWith(brightness: brightness),
    );
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) {
    return _persistNewSettings((settings) => settings.copyWith(type: type));
  }
}
