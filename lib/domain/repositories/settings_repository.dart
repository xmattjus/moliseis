import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/utils/result.dart';

abstract class SettingsRepository {
  /// Whether the user has given his consent to log app Exceptions to Sentry
  /// or not.
  Result<bool> get crashReporting;

  /// Returns the user selected content sort order.
  Result<ContentSort> get contentSort;

  /// Returns the last time the repositories have been successfully synchronized
  /// with the backend.
  Result<DateTime?> get modifiedAt;

  /// Returns the user selected theme brightness (system, light, dark).
  Result<ThemeBrightness> get themeBrightness;

  /// Returns the user selected theme type (system, app).
  Result<ThemeType> get themeType;

  Future<Result<void>> setCrashReporting(bool enable);
  Future<Result<void>> setContentSort(ContentSort sort);
  Future<Result<void>> setModifiedAt(DateTime dateTime);
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness);
  Future<Result<void>> setThemeType(ThemeType type);
}
