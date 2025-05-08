import 'dart:async' show Future;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/core/repository_sync_result.dart';
import 'package:moliseis/data/repositories/core/repository_sync_state.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/domain/use-cases/sync/sync_start_use_case.dart';
import 'package:moliseis/utils/result.dart';

class SyncViewModel extends ChangeNotifier {
  SyncViewModel({
    required SyncStartUseCase syncStartUseCase,
    required SettingsRepository settingsRepository,
  }) : _repositorySyncUseCase = syncStartUseCase,
       _settingsRepository = settingsRepository {
    synchronize(force: false);
  }

  final SyncStartUseCase _repositorySyncUseCase;
  final SettingsRepository _settingsRepository;

  RepositorySyncResult result = RepositorySyncResult.none;
  RepositorySyncState state = RepositorySyncState.none;

  /// Synchronizes the local app repositories with the backend.
  Future<void> synchronize({required bool force}) async {
    if (state != RepositorySyncState.loading) {
      state = RepositorySyncState.loading;

      notifyListeners();

      final lastUpdate = _settingsRepository.modifiedAt;

      final nextScheduledUpdate = lastUpdate.add(const Duration(days: 3));

      if (force || DateTime.now().isAfter(nextScheduledUpdate)) {
        final syncResult = await _repositorySyncUseCase.start();

        state = RepositorySyncState.done;

        switch (syncResult) {
          case Success<void>():
            result = RepositorySyncResult.success;
          case Error<void>():
            if (lastUpdate.isAtSameMomentAs(
              DateTime.parse('1970-01-01T00:00:00Z'),
            )) {
              result = RepositorySyncResult.majorError;
            } else {
              result = RepositorySyncResult.error;
            }
        }
      } else {
        result = RepositorySyncResult.success;
        state = RepositorySyncState.done;
      }

      notifyListeners();
    }
  }
}
