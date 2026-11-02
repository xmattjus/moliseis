import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/result.dart';

/// Local persistence contract for app settings.
abstract interface class ISettingsLocalDataSource {
  /// Loads the singleton settings entity from local storage.
  Future<Result<AppSettings>> load();

  /// Persists the singleton settings entity to local storage.
  Future<Result<void>> save(AppSettings settings);

  /// Applies a field-only change to the latest singleton in one transaction.
  ///
  /// The transform must be synchronous and must not mutate its argument.
  Future<Result<void>> update(AppSettings Function(AppSettings) transform);
}

/// ObjectBox-backed implementation for app settings persistence.
class SettingsLocalDataSource implements ISettingsLocalDataSource {
  SettingsLocalDataSource(Store store)
    : _store = store,
      _box = store.box<AppSettings>();

  final Store _store;

  final Box<AppSettings> _box;

  @override
  Future<Result<AppSettings>> load() async {
    try {
      final entity = _box.get(AppSettings.singletonId);
      if (entity == null) return Result.success(AppSettings());
      return Result.success(entity);
    } on Exception catch (exception, stackTrace) {
      return Result.error(
        Exception('Failed to load app settings, $exception, $stackTrace'),
      );
    }
  }

  @override
  Future<Result<void>> update(
    AppSettings Function(AppSettings) transform,
  ) async {
    try {
      _store.runInTransaction(TxMode.write, () {
        final current = _box.get(AppSettings.singletonId) ?? AppSettings();
        _box.put(transform(current));
      });
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      return Result.error(
        Exception('Failed to update app settings, $exception, $stackTrace'),
      );
    }
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    try {
      _box.put(settings);
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      return Result.error(
        Exception('Failed to save app settings, $exception, $stackTrace'),
      );
    }
  }
}
