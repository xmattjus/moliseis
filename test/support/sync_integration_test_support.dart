import 'dart:core' as core;
import 'dart:core';

import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/utils/result.dart';

/// Production media repository that can fail after staging its real writes.
final class FailingWriteMediaRepository extends MediaRepositoryImpl {
  FailingWriteMediaRepository({
    required super.logger,
    required super.supabaseI,
    required super.objectBoxI,
  });

  /// Whether [putMany] fails after the production write has completed.
  bool failAfterWrite = false;

  /// Observes staged values inside the encompassing ObjectBox transaction.
  void Function()? afterWrite;

  @override
  void putMany(List<MediaEntity> entities) {
    super.putMany(entities);
    afterWrite?.call();
    if (failAfterWrite) throw Exception('Late media commit failure');
  }
}

/// Real settings persistence with one controllable recoverable save failure.
final class FailNextSettingsSave implements ISettingsLocalDataSource {
  FailNextSettingsSave(this.delegate);

  /// Real local datasource whose reads and successful writes are preserved.
  final ISettingsLocalDataSource delegate;

  /// The next attempted save returns an error without changing disk state.
  bool failNextSave = false;

  /// Original recoverable failure injected inside production update's catch.
  final Exception failure = Exception('Settings save failure');
  final StackTrace failureStack = StackTrace.fromString(
    'settings-update-source',
  );

  /// Number of settings save attempts, including failures.
  int saves = 0;

  @override
  Future<Result<AppSettings>> load() => delegate.load();

  @override
  Future<Result<void>> update(
    AppSettings Function(AppSettings) transform, {
    bool reportSyncFailure = false,
  }) {
    saves++;
    if (failNextSave) {
      failNextSave = false;
      return delegate.update((current) {
        core.Error.throwWithStackTrace(failure, failureStack);
      }, reportSyncFailure: reportSyncFailure);
    }
    return delegate.update(transform, reportSyncFailure: reportSyncFailure);
  }

  @override
  Future<Result<void>> save(AppSettings settings) {
    saves++;
    if (failNextSave) {
      failNextSave = false;
      return Future.value(Result.error(Exception('Settings save failure')));
    }
    return delegate.save(settings);
  }
}
