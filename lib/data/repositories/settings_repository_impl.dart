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
  ThemeType get themeType => _appSettings.type;

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

  @override
  ThemeBrightness get themeBrightness => _appSettings.brightness;

  @override
  Future<void> setThemeBrightness(ThemeBrightness brightness) =>
      _settingsBox.putAsync(_appSettings.copyWith(brightness: brightness));

  @override
  ContentSort get contentSort => _appSettings.contentSort;

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
  DateTime? get modifiedAt => _appSettings.modifiedAt;

  @override
  void setModifiedAt(DateTime dateTime) =>
      _settingsBox.put(_appSettings.copyWith(modifiedAt: dateTime));

  @override
  bool get crashReporting => _appSettings.crashReporting;

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
}
