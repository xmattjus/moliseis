import 'dart:async' show Future;

import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/settings/app_settings.dart';
import 'package:moliseis/domain/models/settings/theme_brightness.dart';
import 'package:moliseis/domain/models/settings/theme_type.dart';
import 'package:moliseis/generated/objectbox.g.dart';

class SettingsRepositoryLocal implements SettingsRepository {
  SettingsRepositoryLocal({required ObjectBox objectBoxI})
    : _settingsBox = objectBoxI.store.box<AppSettings>();

  final Box<AppSettings> _settingsBox;

  /// Loads from the database (or creates) the [AppSettings] object.
  ///
  /// ObjectBox does not support the creation of a box with only one object
  /// inside. As such, the [AppSettings.id] is not managed by ObjectBox and
  /// is always set to constant [settingsId] during object instantiation.
  AppSettings get _appSettings =>
      _settingsBox.get(settingsId) ??
      AppSettings(modifiedAt: DateTime.parse('1970-01-01T00:00:00Z'));

  @override
  ThemeType get themeType => _appSettings.type;

  @override
  Future<void> setThemeType(ThemeType type) =>
      _settingsBox.putAsync(_appSettings.copyWith(type: type));

  @override
  ThemeBrightness get themeBrightness => _appSettings.brightness;

  @override
  Future<void> setThemeBrightness(ThemeBrightness brightness) =>
      _settingsBox.putAsync(_appSettings.copyWith(brightness: brightness));

  @override
  AttractionSort get attractionSort => _appSettings.attractionSort;

  @override
  Future<void> setAttractionSort(AttractionSort sort) =>
      _settingsBox.putAsync(_appSettings.copyWith(attractionSort: sort));

  @override
  DateTime get modifiedAt => _appSettings.modifiedAt;

  @override
  void setModifiedAt(DateTime dateTime) =>
      _settingsBox.put(_appSettings.copyWith(modifiedAt: dateTime));

  @override
  bool get crashReporting => _appSettings.crashReporting;

  @override
  Future<void> setCrashReporting(bool enable) =>
      _settingsBox.putAsync(_appSettings.copyWith(crashReporting: enable));
}
