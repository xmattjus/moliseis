import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/utils/initializable.dart';
import 'package:moliseis/utils/result.dart';

/// Provides access to the app settings used by the presentation layer.
///
/// Read getters return plain values because callers consume the latest
/// in-memory settings snapshot as part of normal UI flow.
///
/// Consumers must call [initialize] and await completion before accessing
/// getters or invoking write methods. Implementations may throw a
/// [StateError] when this contract is violated.
///
/// Write methods return [Result] because persistence can fail and the caller
/// may need to react, for example by reverting optimistic UI updates.
abstract class SettingsRepository implements Initializable {
  /// Whether the user has given his consent to log app Exceptions to Sentry
  /// or not.
  bool get crashReporting;

  /// Returns the user selected content sort order.
  ContentSort get contentSort;

  /// Returns the last time the repositories have been successfully synchronized
  /// with the backend.
  DateTime? get modifiedAt;

  /// Returns the user selected theme brightness (system, light, dark).
  ThemeBrightness get themeBrightness;

  /// Returns the user selected theme type (system, app).
  ThemeType get themeType;

  /// Initializes the in-memory settings cache from persistence.
  ///
  /// The app can continue with fallback defaults even if this returns an
  /// error, but callers should still handle and report failures.
  @override
  Future<Result<void>> initialize();

  Future<Result<void>> setCrashReporting(bool enable);
  Future<Result<void>> setContentSort(ContentSort sort);
  Future<Result<void>> setModifiedAt(DateTime dateTime);
  Future<Result<void>> setThemeBrightness(ThemeBrightness brightness);
  Future<Result<void>> setThemeType(ThemeType type);
}
