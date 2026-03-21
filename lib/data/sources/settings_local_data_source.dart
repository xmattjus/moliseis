import 'package:moliseis/data/sources/app_settings.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

/// Local persistence contract for app settings.
abstract interface class ISettingsLocalDataSource {
  /// Loads the singleton settings entity from local storage.
  Future<Result<AppSettings>> load();

  /// Persists the singleton settings entity to local storage.
  Future<Result<void>> save(AppSettings settings);
}

/// ObjectBox-backed implementation for app settings persistence.
class SettingsLocalDataSource implements ISettingsLocalDataSource {
  final ISettingsBox _settingsBox;

  SettingsLocalDataSource(Store store)
    : _settingsBox = _ObjectBoxSettingsBox(store.box<AppSettings>());

  SettingsLocalDataSource.fromBox(ISettingsBox settingsBox)
    : _settingsBox = settingsBox;

  @override
  Future<Result<AppSettings>> load() async {
    try {
      final entity = _settingsBox.get(AppSettings.singletonId);
      if (entity == null) return Result.success(AppSettings());
      return Result.success(entity);
    } on Exception catch (exception, stackTrace) {
      return Result.error(
        Exception('Failed to load app settings, $exception, $stackTrace'),
      );
    }
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    try {
      _settingsBox.put(settings);
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      return Result.error(
        Exception('Failed to save app settings, $exception, $stackTrace'),
      );
    }
  }
}

/// Minimal storage API used by [SettingsLocalDataSource].
abstract interface class ISettingsBox {
  /// Returns settings entity by id.
  AppSettings? get(int id);

  /// Stores the provided settings entity.
  void put(AppSettings settings);
}

final class _ObjectBoxSettingsBox implements ISettingsBox {
  final Box<AppSettings> _box;

  _ObjectBoxSettingsBox(this._box);

  @override
  AppSettings? get(int id) => _box.get(id);

  @override
  void put(AppSettings settings) => _box.put(settings);
}
