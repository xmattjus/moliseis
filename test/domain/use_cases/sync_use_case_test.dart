import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry/sentry.dart';

import '../../support/fake_repositories.dart';
import '../../support/sync_use_case_test_support.dart';

void main() {
  group('server cursor and concurrent retrieval protocol', () {
    test(
      'cursor failure short circuits every preparation and commit',
      () async {
        final source = FakeSyncCursorSource(
          result: Result.error(TestException('cursor')),
        );
        final coordinator = FakeTransactionCoordinator();
        final deps = buildSyncUseCase(
          settings: FakeSettingsRepository(),
          cursorSource: source,
          transactionCoordinator: coordinator,
        );
        expect(await deps.useCase.sync(), isA<Error<void>>());
        expect(source.calls, 1);
        expect(deps.cityRepo.prepareCalls, isEmpty);
        expect(deps.placeRepo.prepareCalls, isEmpty);
        expect(deps.eventRepo.prepareCalls, isEmpty);
        expect(deps.mediaRepo.prepareCalls, isEmpty);
        expect(coordinator.calls, 0);
        expect(deps.settings.setSyncStateCalled, isFalse);
      },
    );

    test('all four preparations start before completion or commit', () async {
      final coordinator = FakeTransactionCoordinator();
      final deps = buildSyncUseCase(
        settings: FakeSettingsRepository(),
        transactionCoordinator: coordinator,
      );
      final city = Completer<Result<List<CityDto>>>();
      final place = Completer<Result<List<PlaceDto>>>();
      final event = Completer<Result<List<EventDto>>>();
      final media = Completer<Result<List<MediaDto>>>();
      final started = List.generate(4, (_) => Completer<void>());
      deps.cityRepo
        ..pendingPrepare = city
        ..prepareStarted = started[0];
      deps.placeRepo
        ..pendingPrepare = place
        ..prepareStarted = started[1];
      deps.eventRepo
        ..pendingPrepare = event
        ..prepareStarted = started[2];
      deps.mediaRepo
        ..pendingPrepare = media
        ..prepareStarted = started[3];
      final running = deps.useCase.sync();
      await Future.wait(started.map((signal) => signal.future));
      expect(coordinator.calls, 0);
      expect(deps.settings.setSyncStateCalled, isFalse);
      city.complete(const Result.success([]));
      place.complete(const Result.success([]));
      event.complete(const Result.success([]));
      await Future<void>.value();
      expect(coordinator.calls, 0);
      media.complete(const Result.success([]));
      expect(await running, isA<Success<void>>());
      expect(coordinator.calls, 1);
    });

    for (final bootstrap in [true, false]) {
      test(
        'shared lower bound and exact UTC U, bootstrap=$bootstrap',
        () async {
          final previous = DateTime.utc(2026, 10, 10, 12);
          final server = DateTime.parse('2026-10-12T14:00:00+02:00');
          final completion = DateTime.utc(2026, 10, 12, 13);
          final settings = FakeSettingsRepository(
            lastSyncedAt: previous,
            contentSyncCursorAt: bootstrap ? null : previous,
          );
          final deps = buildSyncUseCase(
            settings: settings,
            cursorSource: FakeSyncCursorSource(result: Result.success(server)),
            now: () => completion,
            cityResult: Result.success([
              CityDto(
                id: 1,
                name: 'Future marker',
                createdAt: previous,
                modifiedAt: server.add(const Duration(days: 2)),
              ),
            ]),
          );
          expect(await deps.useCase.sync(), isA<Success<void>>());
          final bound = bootstrap
              ? null
              : previous.subtract(const Duration(hours: 24));
          expect(deps.cityRepo.prepareCalls, [bound]);
          expect(deps.placeRepo.prepareCalls, [bound]);
          expect(deps.eventRepo.prepareCalls, [bound]);
          expect(deps.mediaRepo.prepareCalls, [bound]);
          expect(settings.contentSyncCursorAt, server.toUtc());
          expect(settings.contentSyncCursorAt!.isUtc, isTrue);
          expect(settings.lastSyncedAt, completion);
        },
      );
    }

    test('U equal to C still fetches the overlap range', () async {
      final cursor = DateTime.utc(2026, 10, 12, 12);
      final deps = buildSyncUseCase(
        settings: FakeSettingsRepository(contentSyncCursorAt: cursor),
        cursorSource: FakeSyncCursorSource(result: Result.success(cursor)),
      );
      expect(await deps.useCase.sync(), isA<Success<void>>());
      final bound = cursor.subtract(syncOverlap);
      expect(deps.cityRepo.prepareCalls, [bound]);
      expect(deps.placeRepo.prepareCalls, [bound]);
      expect(deps.eventRepo.prepareCalls, [bound]);
      expect(deps.mediaRepo.prepareCalls, [bound]);
    });

    test(
      'settings failure after commit returns error and retains old state',
      () async {
        final old = DateTime.utc(2026, 10, 9);
        final settings = FakeSettingsRepository(
          lastSyncedAt: old,
          contentSyncCursorAt: old,
          setSyncStateResult: Result.error(TestException('disk')),
        );
        final deps = buildSyncUseCase(
          settings: settings,
          now: () => DateTime.utc(2026, 10, 12, 12),
        );
        expect(await deps.useCase.sync(), isA<Error<void>>());
        expect(deps.cityRepo.commitCalled, isTrue);
        expect(deps.placeRepo.commitCalled, isTrue);
        expect(deps.eventRepo.commitCalled, isTrue);
        expect(deps.mediaRepo.commitCalled, isTrue);
        expect(settings.lastSyncedAt, old);
        expect(settings.contentSyncCursorAt, old);
      },
    );
  });

  group('deterministic scheduling', () {
    final now = DateTime.utc(2026, 10, 12, 12);
    test('null cursor forces bootstrap with recent completion', () {
      final deps = buildSyncUseCase(
        settings: FakeSettingsRepository(lastSyncedAt: now),
        now: () => now,
      );
      expect(deps.useCase.isSyncRequired, isTrue);
    });
    for (final elapsed in [
      const Duration(days: 3) - const Duration(microseconds: 1),
      const Duration(days: 3),
      const Duration(days: 3, microseconds: 1),
    ]) {
      test('three-day inclusive boundary $elapsed', () {
        final deps = buildSyncUseCase(
          settings: FakeSettingsRepository(
            lastSyncedAt: now.subtract(elapsed),
            contentSyncCursorAt: now,
          ),
          now: () => now,
        );
        expect(deps.useCase.isSyncRequired, elapsed >= const Duration(days: 3));
      });
    }
    test('cursor without completion is due', () {
      final deps = buildSyncUseCase(
        settings: FakeSettingsRepository(contentSyncCursorAt: now),
        now: () => now,
      );
      expect(deps.useCase.isSyncRequired, isTrue);
    });
  });

  test(
    'Sentry status is failed for every error boundary and OK after settings',
    () async {
      final statuses = <SpanStatus?>[];
      await Sentry.init((options) {
        options
          ..dsn = 'https://test@localhost/1'
          ..tracesSampleRate = 1
          ..traceLifecycle = SentryTraceLifecycle.static
          ..beforeSendTransaction = (transaction, hint) {
            statuses.add(transaction.contexts.trace?.status);
            return null;
          };
      });
      addTearDown(Sentry.close);
      final failed = Result<void>.error(TestException('failure'));
      final cases = [
        buildSyncUseCase(
          settings: FakeSettingsRepository(),
          cursorSource: FakeSyncCursorSource(
            result: Result.error(TestException('cursor')),
          ),
        ),
        buildSyncUseCase(
          settings: FakeSettingsRepository(),
          cityResult: Result.error(TestException('prepare')),
        ),
        buildSyncUseCase(
          settings: FakeSettingsRepository(),
          transactionCoordinator: FakeTransactionCoordinator()..result = failed,
        ),
        buildSyncUseCase(
          settings: FakeSettingsRepository(setSyncStateResult: failed),
        ),
        buildSyncUseCase(settings: FakeSettingsRepository()),
      ];
      for (final deps in cases) {
        await deps.useCase.sync();
      }
      expect(statuses, [
        const SpanStatus.internalError(),
        const SpanStatus.internalError(),
        const SpanStatus.internalError(),
        const SpanStatus.internalError(),
        const SpanStatus.ok(),
      ]);
    },
  );

  group('SyncUseCase.sync', () {
    test(
      'calls commitSync on all repos when all prepareSync calls succeed',
      () async {
        final cityDtos = [syncCityDto(1)];
        final placeDtos = [syncPlaceDto(2)];
        final eventDtos = [syncEventDto(3)];
        final mediaDtos = [syncMediaDto(4)];

        final settings = FakeSettingsRepository();
        final deps = buildSyncUseCase(
          settings: settings,
          cityResult: Result.success(cityDtos),
          placeResult: Result.success(placeDtos),
          eventResult: Result.success(eventDtos),
          mediaResult: Result.success(mediaDtos),
        );

        final result = await deps.useCase.sync();

        expect(result.isSuccess, isTrue);
        expect(deps.settings.setSyncStateCalled, isTrue);
        expect(deps.cityRepo.commitCalled, isTrue);
        expect(deps.cityRepo.committedDtos, equals(cityDtos));
        expect(deps.placeRepo.commitCalled, isTrue);
        expect(deps.placeRepo.committedDtos, equals(placeDtos));
        expect(deps.eventRepo.commitCalled, isTrue);
        expect(deps.eventRepo.committedDtos, equals(eventDtos));
        expect(deps.mediaRepo.commitCalled, isTrue);
        expect(deps.mediaRepo.committedDtos, equals(mediaDtos));
      },
    );

    test(
      'does not call commitSync on any repo when city prepareSync fails',
      () async {
        final error = TestException('city sync failed');
        final settings = FakeSettingsRepository();
        final deps = buildSyncUseCase(
          cityResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setSyncStateCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'does not call commitSync on any repo when place prepareSync fails',
      () async {
        final error = TestException('place sync failed');
        final settings = FakeSettingsRepository();
        final deps = buildSyncUseCase(
          placeResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setSyncStateCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'does not call commitSync on any repo when event prepareSync fails',
      () async {
        final error = TestException('event sync failed');
        final settings = FakeSettingsRepository();
        final deps = buildSyncUseCase(
          eventResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setSyncStateCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test(
      'does not call commitSync on any repo when media prepareSync fails',
      () async {
        final error = TestException('media sync failed');
        final settings = FakeSettingsRepository();
        final deps = buildSyncUseCase(
          mediaResult: Result.error(error),
          settings: settings,
        );

        final result = await deps.useCase.sync();

        expect(result.isError, isTrue);
        expect((result as Error<void>).error, same(error));
        expect(deps.settings.setSyncStateCalled, isFalse);
        expect(deps.cityRepo.commitCalled, isFalse);
        expect(deps.cityRepo.committedDtos, isNull);
        expect(deps.placeRepo.commitCalled, isFalse);
        expect(deps.placeRepo.committedDtos, isNull);
        expect(deps.eventRepo.commitCalled, isFalse);
        expect(deps.eventRepo.committedDtos, isNull);
        expect(deps.mediaRepo.commitCalled, isFalse);
        expect(deps.mediaRepo.committedDtos, isNull);
      },
    );

    test('wraps all commitSync calls inside runInWriteTransaction', () async {
      final cityDtos = [syncCityDto(1)];
      final placeDtos = [syncPlaceDto(2)];
      final eventDtos = [syncEventDto(3)];
      final mediaDtos = [syncMediaDto(4)];

      final settings = FakeSettingsRepository();
      final wrappedCalls = <VoidCall>[];
      final coordinator = RecordingSyncTransactionCoordinator(wrappedCalls);

      final deps = buildSyncUseCase(
        settings: settings,
        cityResult: Result.success(cityDtos),
        placeResult: Result.success(placeDtos),
        eventResult: Result.success(eventDtos),
        mediaResult: Result.success(mediaDtos),
        cursorSource: FakeSyncCursorSource(),
        transactionCoordinator: coordinator,
      );

      await deps.useCase.sync();

      expect(wrappedCalls, hasLength(1));
      expect(deps.settings.setSyncStateCalled, isTrue);
      expect(deps.cityRepo.commitCalled, isTrue);
      expect(deps.cityRepo.committedDtos, equals(cityDtos));
      expect(deps.placeRepo.commitCalled, isTrue);
      expect(deps.placeRepo.committedDtos, equals(placeDtos));
      expect(deps.eventRepo.commitCalled, isTrue);
      expect(deps.eventRepo.committedDtos, equals(eventDtos));
      expect(deps.mediaRepo.commitCalled, isTrue);
      expect(deps.mediaRepo.committedDtos, equals(mediaDtos));
    });

    test('does not call setSyncState when any prepareSync fails', () async {
      final error = TestException('sync failed');
      final settings = FakeSettingsRepository();
      final deps = buildSyncUseCase(
        cityResult: Result.error(error),
        settings: settings,
      );

      await deps.useCase.sync();

      expect(deps.settings.setSyncStateCalled, isFalse);
    });

    test('does not call setSyncState when commitSync returns error', () async {
      final settings = FakeSettingsRepository();
      final deps = buildSyncUseCase(
        settings: settings,
        cursorSource: FakeSyncCursorSource(),
        transactionCoordinator: FailingSyncTransactionCoordinator(),
      );

      final result = await deps.useCase.sync();

      expect(result.isError, isTrue);
      expect(deps.settings.setSyncStateCalled, isFalse);
    });
  });

  group('SyncUseCase.isSyncRequired', () {
    test('returns true when modifiedAt is null (never synced)', () {
      final settings = FakeSettingsRepository();
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => DateTime.utc(2026, 10, 12, 12),
      );

      expect(deps.useCase.isSyncRequired, isTrue);
    });

    test('returns false when last sync was less than 3 days ago', () {
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.utc(2026, 10, 11, 12),
        contentSyncCursorAt: DateTime.utc(2026, 10, 12),
      );
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => DateTime.utc(2026, 10, 12, 12),
      );

      expect(deps.useCase.isSyncRequired, isFalse);
    });

    test('returns true when last sync was more than 3 days ago', () {
      final settings = FakeSettingsRepository(
        lastSyncedAt: DateTime.utc(2026, 10, 8, 12),
      );
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => DateTime.utc(2026, 10, 12, 12),
      );

      expect(deps.useCase.isSyncRequired, isTrue);
    });
  });

  group('SyncUseCase.lastSyncedAt', () {
    test('returns null when settings has no modifiedAt', () {
      final settings = FakeSettingsRepository();
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => DateTime.utc(2026, 10, 12, 12),
      );

      expect(deps.useCase.lastSyncedAt, isNull);
    });

    test('returns the modifiedAt value from settings repository', () {
      final date = DateTime.utc(2026, 10, 11, 12);
      final settings = FakeSettingsRepository(lastSyncedAt: date);
      final deps = buildSyncUseCase(
        settings: settings,
        now: () => DateTime.utc(2026, 10, 12, 12),
      );

      expect(deps.useCase.lastSyncedAt, equals(date));
    });
  });
}
