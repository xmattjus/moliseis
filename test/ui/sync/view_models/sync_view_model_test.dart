import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/sync_use_case_test_support.dart';

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
      cursorSource: FakeSyncCursorSource(),
      transactionCoordinator: FakeTransactionCoordinator(),
    );
  }

  test(
    'upgraded recent cache bootstraps immediately and failure is nonfatal',
    () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      final settings = FakeSettingsRepository(lastSyncedAt: now);
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => now,
        cityResult: Result.error(TestException('offline')),
      );
      final viewModel = SyncViewModel(syncUseCase: deps.useCase);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      expect(deps.cityRepo.prepareCalls, [null]);
      expect(viewModel.sync.results.value.hasFailure, isTrue);
      expect(viewModel.fatalError, isFalse);
      expect(settings.contentSyncCursorAt, isNull);
      expect(settings.lastSyncedAt, now);
    },
  );

  for (final bootstrap in [true, false]) {
    test(
      'forced sync chooses bootstrap/delta from the cursor: $bootstrap',
      () async {
        final now = DateTime.utc(2026, 10, 12, 12);
        final settings = FakeSettingsRepository(
          lastSyncedAt: now,
          contentSyncCursorAt: now,
        );
        final deps = buildSyncUseCase(settings: settings, now: () => now);
        final viewModel = SyncViewModel(syncUseCase: deps.useCase);
        addTearDown(viewModel.dispose);
        expect(viewModel.sync.results.value.idle, isTrue);
        if (bootstrap) settings.contentSyncCursorAt = null;
        await viewModel.sync.runAsync(true);
        expect(deps.cityRepo.prepareCalls, [
          if (bootstrap) null else now.subtract(const Duration(hours: 24)),
        ]);
        expect(viewModel.sync.results.value.completed, isTrue);
      },
    );
  }

  group('SyncViewModel constructor', () {
    test('does not auto-execute when isSyncRequired is false', () {
      // modifiedAt 1 day ago → isSyncRequired = false
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
        contentSyncCursorAt: DateTime.utc(2026, 10, 12),
      );
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(settings: settings),
      );

      expect(viewModel.sync.isRunningSync.value, isFalse);
      expect(viewModel.sync.results.value.completed, isFalse);
      expect(viewModel.sync.results.value.hasFailure, isFalse);
    });

    test('auto-executes and completes when isSyncRequired is true', () async {
      // modifiedAt null → isSyncRequired = true → constructor triggers execute
      final settings = FakeSettingsRepository();
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(settings: settings),
      );

      await pumpEventQueue();

      expect(viewModel.sync.results.value.completed, isTrue);
      expect(settings.setSyncStateCalled, isTrue);
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

        expect(viewModel.sync.results.value.completed, isTrue);
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

        expect(viewModel.sync.results.value.hasFailure, isTrue);
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
          contentSyncCursorAt: DateTime.utc(2026, 10, 12),
        );
        final viewModel = SyncViewModel(
          syncUseCase: buildUseCase(
            cityResult: Result.error(error),
            settings: settings,
          ),
        );

        await viewModel.sync.runAsync(true);

        expect(viewModel.sync.results.value.hasFailure, isTrue);
        expect(viewModel.fatalError, isFalse);
      },
    );
  });

  group('SyncViewModel.sync force flag', () {
    test('force=true syncs even when isSyncRequired is false', () async {
      // modifiedAt 1 day ago → isSyncRequired = false → no auto-execute
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
        contentSyncCursorAt: DateTime.utc(2026, 10, 12),
      );
      final viewModel = SyncViewModel(
        syncUseCase: buildUseCase(settings: settings),
      );

      await viewModel.sync.runAsync(true);

      expect(viewModel.sync.results.value.completed, isTrue);
      // setSyncState is only called when the underlying sync() actually runs
      expect(settings.setSyncStateCalled, isTrue);
    });

    test(
      'force=false skips sync and returns success when isSyncRequired is false',
      () async {
        // modifiedAt 1 day ago → isSyncRequired = false → no auto-execute
        final settings = FakeSettingsRepository(
          lastSyncedAt: DateTime.now().subtract(const Duration(days: 1)),
          contentSyncCursorAt: DateTime.utc(2026, 10, 12),
        );
        final viewModel = SyncViewModel(
          syncUseCase: buildUseCase(settings: settings),
        );

        await viewModel.sync.runAsync(false);

        expect(viewModel.sync.results.value.completed, isTrue);
        // No actual network sync occurred
        expect(settings.setSyncStateCalled, isFalse);
      },
    );
  });
  for (final cached in [false, true]) {
    testWidgets('S1 inline admission and busy drop cached=$cached', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 12, 12);
      final settings = FakeSettingsRepository(
        lastSyncedAt: cached ? now.subtract(const Duration(days: 8)) : null,
      );
      final gate = Completer<Result<DateTime>>();
      final cursor = FakeSyncCursorSource()..pendingCursor = gate;
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => now,
        cursorSource: cursor,
      );
      final vm = SyncViewModel(syncUseCase: deps.useCase);
      expect(vm.sync.isRunningSync.value, isTrue);
      expect(vm.sync.results.value.isRunning, isTrue);
      expect(cursor.calls, 0);
      vm.sync.run(true);
      await pumpCommandTurns(tester);
      expect(cursor.calls, 1);
      vm.sync.run(false);
      gate.complete(Result.success(now));
      await pumpCommandTurns(tester);
      expect(vm.sync.results.value.completed, isTrue);
      expect(cursor.calls, 1);
      expect(deps.cityRepo.prepareCalls, hasLength(1));
      vm.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
      'S3 raw cursor runtime stays unexpected and original cached=$cached',
      (tester) async {
        final now = DateTime.utc(2026, 10, 12, 12);
        final settings = FakeSettingsRepository(
          lastSyncedAt: cached ? now : null,
          contentSyncCursorAt: cached ? now : null,
        );
        final gate = Completer<Result<DateTime>>();
        final cursor = FakeSyncCursorSource()..pendingCursor = gate;
        final deps = buildSyncUseCase(
          settings: settings,
          now: () => now,
          cursorSource: cursor,
        );
        final logger = MockLogger();
        addTearDown(installCommandTestReporting(logger));
        final vm = SyncViewModel(syncUseCase: deps.useCase);
        if (cached) vm.sync.run(true);
        await pumpCommandTurns(tester);
        final failure = StateError('original runtime');
        final stack = StackTrace.fromString(
          '#0 syncOriginal (package:moliseis/sync_original.dart:21:7)',
        );
        gate.completeError(failure, stack);
        await pumpCommandTurns(tester);
        expect(vm.sync.results.value.unexpectedError, same(failure));
        expect(vm.sync.results.value.domainError, isNull);
        expect(vm.fatalError, !cached);
        expect(logger.calls, hasLength(1));
        expect(logger.calls.single.error, same(failure));
        expect(
          logger.calls.single.stackTrace.toString(),
          contains('sync_original.dart 21:7'),
        );
        expect(deps.cityRepo.prepareCalls, isEmpty);
        vm.dispose();
        await pumpCommandTurns(tester);
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  }

  testWidgets('S2 schedule is checked at deferred entry, force overrides it', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 12, 12);
    final settings = FakeSettingsRepository(
      lastSyncedAt: now,
      contentSyncCursorAt: now,
    );
    final cursor = FakeSyncCursorSource();
    final deps = buildSyncUseCase(
      settings: settings,
      now: () => now,
      cursorSource: cursor,
    );
    final vm = SyncViewModel(syncUseCase: deps.useCase);
    expect(vm.sync.results.value.idle, isTrue);
    settings.lastSyncedAt = null;
    vm.sync.run(false);
    settings.lastSyncedAt = now;
    await pumpCommandTurns(tester);
    expect(vm.sync.results.value.completed, isTrue);
    expect(cursor.calls, 0);
    vm.sync.run(true);
    await pumpCommandTurns(tester);
    expect(cursor.calls, 1);
    expect(vm.sync.results.value.completed, isTrue);
    vm.dispose();
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('S3 fatal retry resets current outcome and recovers', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 12, 12);
    final settings = FakeSettingsRepository();
    final failure = TestException('offline');
    final cursor = FakeSyncCursorSource(result: Result.error(failure));
    final deps = buildSyncUseCase(
      settings: settings,
      now: () => now,
      cursorSource: cursor,
    );
    final vm = SyncViewModel(syncUseCase: deps.useCase);
    await pumpCommandTurns(tester);
    expect(vm.fatalError, isTrue);
    expect(vm.sync.results.value.domainError, same(failure));
    cursor.result = Result.success(now);
    vm.sync.run(true);
    expect(vm.fatalError, isFalse);
    expect(vm.sync.isRunningSync.value, isTrue);
    await pumpCommandTurns(tester);
    expect(vm.sync.results.value.completed, isTrue);
    expect(vm.fatalError, isFalse);
    expect(settings.lastSyncedAt, now);
    vm.dispose();
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
    'S3 Settings failure after commit keeps timestamp-based fatal proxy',
    (tester) async {
      final failure = TestException('settings failed');
      final settings = FakeSettingsRepository(
        setSyncStateResult: Result.error(failure),
      );
      final deps = buildSyncUseCase(settings: settings);
      final vm = SyncViewModel(syncUseCase: deps.useCase);
      await pumpCommandTurns(tester);
      expect(deps.cityRepo.committedDtos, isNotNull);
      expect(vm.sync.results.value.domainError, same(failure));
      expect(settings.lastSyncedAt, isNull);
      expect(vm.fatalError, isTrue);
      vm.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'S3 existing prepare wait wrapper remains unexpected and reports once',
    (tester) async {
      final deps = buildSyncUseCase(settings: FakeSettingsRepository());
      final pending = Completer<Result<List<CityDto>>>();
      deps.cityRepo.pendingPrepare = pending;
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final vm = SyncViewModel(syncUseCase: deps.useCase);
      await pumpCommandTurns(tester);
      final original = StateError('prepare failure');
      pending.completeError(original, StackTrace.current);
      await pumpCommandTurns(tester);
      final wrapper = vm.sync.results.value.unexpectedError;
      expect(wrapper, isA<ParallelWaitError<Object?, Object?>>());
      if (wrapper
          is ParallelWaitError<
            Object?,
            (AsyncError?, AsyncError?, AsyncError?, AsyncError?)
          >) {
        expect(wrapper.errors.$1?.error, same(original));
      } else {
        fail('Expected the existing four-prepare error record');
      }
      expect(vm.sync.results.value.domainError, isNull);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(wrapper));
      vm.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  for (final outcome in ['success', 'domain', 'runtime']) {
    testWidgets('S4 terminal precedes settlement wake: $outcome', (
      tester,
    ) async {
      final pending = Completer<Result<DateTime>>();
      final cursor = FakeSyncCursorSource()..pendingCursor = pending;
      final deps = buildSyncUseCase(
        settings: FakeSettingsRepository(),
        cursorSource: cursor,
      );
      final logger = MockLogger();
      addTearDown(installCommandTestReporting(logger));
      final vm = SyncViewModel(syncUseCase: deps.useCase);
      final terminalAdmission = <bool>[];
      final settlementWake = <bool>[];
      vm.sync.results.addListener(() {
        final snapshot = vm.sync.results.value;
        if (snapshot.completed || snapshot.hasFailure) {
          terminalAdmission.add(vm.sync.isRunningSync.value);
        }
      });
      vm.sync.isRunning.addListener(() {
        if (!vm.sync.isRunning.value) {
          settlementWake.add(vm.sync.isRunningSync.value);
          expectSync(vm.sync.results.value.isRunning, isFalse);
        }
      });
      await pumpCommandTurns(tester);
      expect(cursor.calls, 1);
      if (outcome == 'runtime') {
        pending.completeError(StateError('terminal order'), StackTrace.current);
      } else if (outcome == 'domain') {
        pending.complete(Result.error(TestException('terminal order')));
      } else {
        pending.complete(Result.success(DateTime.utc(2026, 10, 23)));
      }
      await pumpCommandTurns(tester);
      expect(terminalAdmission, [true]);
      expect(settlementWake, [false]);
      expect(logger.calls, outcome == 'runtime' ? hasLength(1) : isEmpty);
      vm.dispose();
      await pumpCommandTurns(tester);
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
