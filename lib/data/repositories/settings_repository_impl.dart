import 'dart:async' show Future;

import 'package:logging/logging.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/app_settings.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final Box<AppSettings> _settingsBox;

  SettingsRepositoryImpl({required ObjectBox objectBoxI})
    : _settingsBox = objectBoxI.store.box<AppSettings>();

  final _log = Logger('SettingsRepositoryImpl');

  /// Loads from the database (or creates) the [AppSettings] object.
  ///
  /// ObjectBox does not support the creation of a box with only one object
  /// inside. As such, the [AppSettings.id] is not managed by ObjectBox and
  /// is always set to constant [settingsId] during object instantiation.
  AppSettings get _appSettings => _settingsBox.get(settingsId) ?? AppSettings();

  @override
  Result<ContentSort> get contentSort {
    return Result.success(_appSettings.contentSort);
  }

  @override
  Result<bool> get crashReporting {
    return Result.success(_appSettings.crashReporting);
  }

  @override
  Result<DateTime?> get modifiedAt {
    return Result.success(_appSettings.modifiedAt);
  }

  @override
  Result<ThemeBrightness> get themeBrightness {
    return Result.success(_appSettings.brightness);
  }

  @override
  Result<ThemeType> get themeType {
    return Result.success(_appSettings.type);
  }

  @override
  Future<Result<void>> setContentSort(ContentSort sort) async {
    try {
      await _settingsBox.putAsync(_appSettings.copyWith(contentSort: sort));
      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while setting content sort to $sort.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> setCrashReporting(bool enable) async {
    try {
      await _settingsBox.putAsync(
        _appSettings.copyWith(crashReporting: enable),
      );
      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while setting crash reporting to $enable.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> setModifiedAt(DateTime dateTime) async {
    try {
      await _settingsBox.putAsync(_appSettings.copyWith(modifiedAt: dateTime));
      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while setting modified at to $dateTime.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness) async {
    try {
      await _settingsBox.putAsync(
        _appSettings.copyWith(brightness: brightness),
      );
      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while setting theme brightness to $brightness.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> setThemeType(ThemeType type) async {
    try {
      await _settingsBox.putAsync(_appSettings.copyWith(type: type));
      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while setting theme type to $type.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }
}
