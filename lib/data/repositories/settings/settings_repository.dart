import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/settings/theme_brightness.dart';
import 'package:moliseis/domain/models/settings/theme_type.dart';

abstract class SettingsRepository {
  /// Returns the user selected theme type (system, app).
  ThemeType get themeType;

  void setThemeType(ThemeType type);

  /// Returns the user selected theme brightness (system, light, dark).
  ThemeBrightness get themeBrightness;

  void setThemeBrightness(ThemeBrightness brightness);

  /// Returns the user selected attractions sort order (by name or by
  /// creation date).
  AttractionSort get attractionSort;

  void setAttractionSort(AttractionSort sort);

  /// Returns the last time the repositories have been successfully synchronized
  /// with the backend.
  DateTime get modifiedAt;

  void setModifiedAt(DateTime dateTime);

  /// Whether the user has given his consent to log app Exceptions to the
  /// Sentry service or not.
  bool get crashReporting;

  void setCrashReporting(bool enable);
}
