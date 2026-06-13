import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';

void main() {
  // Builds a SyncUseCase with configurable prepareSync() results and settings.
  SyncUseCase buildUseCase({
    required FakeSettingsRepository settings,
    Result<List<CityDto>> cityResult = const Result.success([]),
    Result<List<EventDto>> eventResult = const Result.success([]),
    Result<List<MediaDto>> mediaResult = const Result.success([]),
    Result<List<PlaceDto>> placeResult = const Result.success([]),
  }) {
    return SyncUseCase(
      cityRepository: FakeCityRepository(prepareResult: cityResult),
      eventRepository: FakeEventRepository(prepareResult: eventResult),
      mediaRepository: FakeMediaRepository(prepareResult: mediaResult),
      placeRepository: FakePlaceRepository(prepareResult: placeResult),
      settingsRepository: settings,
      transactionCoordinator: FakeTransactionCoordinator(),
    );
  }

  group('SyncViewModel constructor', () {
    test('does not auto-execute when isSyncRequired is false', () {
      // modifiedAt 1 day ago → isSyncRequired = false
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(settings: settings),
      );

      expect(viewModel.sync.running, isFalse);
      expect(viewModel.sync.completed, isFalse);
      expect(viewModel.sync.error, isFalse);
    });

    test('auto-executes and completes when isSyncRequired is true', () async {
      // modifiedAt null → isSyncRequired = true → constructor triggers execute
      final settings = FakeSettingsRepository();
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(settings: settings),
      );

      await pumpEventQueue();

      expect(viewModel.sync.completed, isTrue);
      expect(settings.setModifiedAtCalled, isTrue);
    });
  });

  group('SyncViewModel.sync success', () {
    test(
      'completed is true and fatalError is false after successful sync',
      () async {
        final settings = FakeSettingsRepository();
        final viewModel = SyncViewModel(
          syncUseCase: buildUseCase(settings: settings),
        );

        await pumpEventQueue();

        expect(viewModel.sync.completed, isTrue);
        expect(viewModel.fatalError, isFalse);
      },
    );
  });

  group('SyncViewModel.sync error', () {
    test(
      'sets fatalError when error occurs with no prior successful sync',
      () async {
        // modifiedAt null → isSyncRequired = true and no prior sync data
        final error = TestException('sync failed');
        final settings = FakeSettingsRepository();
        final viewModel = SyncViewModel(
          syncUseCase: buildUseCase(
            cityResult: Result.error(error),
            settings: settings,
          ),
        );

        await pumpEventQueue();

        expect(viewModel.sync.error, isTrue);
        expect(viewModel.fatalError, isTrue);
      },
    );

    test(
      'does not set fatalError when error occurs with a prior successful sync',
      () async {
        // modifiedAt 1 day ago → isSyncRequired = false, so force=true
        // is needed
        final error = TestException('sync failed');
        final settings = FakeSettingsRepository(
          lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        final viewModel = SyncViewModel(
          syncUseCase: buildUseCase(
            cityResult: Result.error(error),
            settings: settings,
          ),
        );

        await viewModel.sync.execute(true);

        expect(viewModel.sync.error, isTrue);
        expect(viewModel.fatalError, isFalse);
      },
    );
  });

  group('SyncViewModel.sync force flag', () {
    test('force=true syncs even when isSyncRequired is false', () async {
      // modifiedAt 1 day ago → isSyncRequired = false → no auto-execute
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(settings: settings),
      );

      await viewModel.sync.execute(true);

      expect(viewModel.sync.completed, isTrue);
      // setModifiedAt is only called when the underlying sync() actually runs
      expect(settings.setModifiedAtCalled, isTrue);
    });

    test(
      'force=false skips sync and returns success when isSyncRequired is false',
      () async {
        // modifiedAt 1 day ago → isSyncRequired = false → no auto-execute
        final settings = FakeSettingsRepository(
          lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        final viewModel = SyncViewModel(
          syncUseCase: buildUseCase(settings: settings),
        );

        await viewModel.sync.execute(false);

        expect(viewModel.sync.completed, isTrue);
        // No actual network sync occurred
        expect(settings.setModifiedAtCalled, isFalse);
      },
    );
  });
}
