import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/utils/result.dart';

/// Configurable settings persistence boundary with recorded save attempts.
final class FakeSettingsLocalDataSource implements ISettingsLocalDataSource {
  FakeSettingsLocalDataSource({
    Result<AppSettings>? loadResult,
    Result<void>? saveResult,
  }) : loadResult = loadResult ?? Result.success(AppSettings()),
       saveResult = saveResult ?? const Result.success(null);

  /// Settings returned by [load].
  Result<AppSettings> loadResult;

  /// Result returned by [save], including when testing failure then retry.
  Result<void> saveResult;

  /// Complete settings snapshots passed to [save].
  final savedSettings = <AppSettings>[];

  @override
  Future<Result<AppSettings>> load() async => loadResult;

  @override
  Future<Result<void>> save(AppSettings settings) async {
    savedSettings.add(settings);
    return saveResult;
  }
}
