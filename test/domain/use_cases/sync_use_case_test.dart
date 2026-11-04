import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/dtos/place_dto.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry/sentry.dart';

import '../../support/fake_repositories.dart';
import '../../support/mock_logger.dart';
import '../../support/recording_sentry_transport.dart';
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

  group('truthful local lifecycle', () {
    for (final input in [
      -1,
      0,
      9007199254740990,
      9007199254740991,
      9007199254740992,
    ]) {
      test('numeric diagnostics clamp $input without aggregate arithmetic', () {
        final event = SyncFinished(
          mode: SyncMode.bootstrap,
          phase: SyncPhase.settings,
          succeeded: true,
          elapsedMs: input,
          cityFetched: input,
          placeFetched: input,
          eventFetched: input,
          mediaFetched: input,
        );
        final expected = input.clamp(0, 9007199254740991);
        for (final key in [
          'elapsed_ms',
          'city_fetched',
          'place_fetched',
          'event_fetched',
          'media_fetched',
        ]) {
          expect(event.data[key], expected);
          expect(event.data[key], isA<int>());
        }
      });
    }
    for (final bootstrap in [true, false]) {
      for (final empty in [true, false]) {
        test(
          'mode from entry cursor, bootstrap=$bootstrap empty=$empty',
          () async {
            final logger = MockLogger();
            final settings = FakeSettingsRepository(
              contentSyncCursorAt: bootstrap ? null : DateTime.utc(2026),
            );
            final deps = buildSyncUseCase(
              settings: settings,
              logger: logger,
              cityResult: Result.success(empty ? [] : [syncCityDto(1)]),
              placeResult: Result.success(
                empty ? [] : [syncPlaceDto(2), syncPlaceDto(3)],
              ),
              eventResult: Result.success(empty ? [] : [syncEventDto(4)]),
              mediaResult: Result.success(empty ? [] : [syncMediaDto(5)]),
            );
            expect(await deps.useCase.sync(), isA<Success<void>>());
            expect(logger.eventsOfType<SyncStarted>(), hasLength(1));
            final terminal = logger.eventsOfType<SyncFinished>();
            expect(terminal, hasLength(1));
            expect(
              terminal.single.data,
              containsPair('mode', bootstrap ? 'bootstrap' : 'delta'),
            );
            expect(terminal.single.succeeded, isTrue);
            expect(terminal.single.data['elapsed_ms'], greaterThanOrEqualTo(0));
            expect(terminal.single.data['city_fetched'], empty ? 0 : 1);
            expect(terminal.single.data['place_fetched'], empty ? 0 : 2);
            expect(terminal.single.data['event_fetched'], empty ? 0 : 1);
            expect(terminal.single.data['media_fetched'], empty ? 0 : 1);
            expect(terminal.single.data.keys, isNot(contains('total')));
            expect(
              logger.eventsOfType<SyncContentCommitSucceeded>(),
              hasLength(1),
            );
            expect(logger.calls.last.event, same(terminal.single));
            expect(settings.setSyncStateCalled, isTrue);
          },
        );
      }
    }

    test('terminal success waits for sync-state persistence', () async {
      final logger = MockLogger();
      final saveStarted = Completer<void>();
      final saved = Completer<Result<void>>();
      final settings = FakeSettingsRepository()
        ..onSetSyncState = () {
          saveStarted.complete();
          return saved.future;
        };
      final deps = buildSyncUseCase(settings: settings, logger: logger);
      final running = deps.useCase.sync();
      await saveStarted.future;
      expect(logger.eventsOfType<SyncContentCommitSucceeded>(), hasLength(1));
      expect(logger.eventsOfType<SyncFinished>(), isEmpty);
      saved.complete(const Result.success(null));
      expect(await running, isA<Success<void>>());
      expect(logger.eventsOfType<SyncFinished>().single.succeeded, isTrue);
    });

    test(
      'cursor error has one phase-only terminal and unavailable counts omitted',
      () async {
        final logger = MockLogger();
        const error = FormatException('cursor');
        final deps = buildSyncUseCase(
          settings: FakeSettingsRepository(),
          logger: logger,
          cursorSource: FakeSyncCursorSource(result: const Result.error(error)),
        );
        final result = await deps.useCase.sync();
        expect((result as Error<void>).error, same(error));
        expect(logger.eventsOfType<SyncStarted>(), hasLength(1));
        final terminal = logger.eventsOfType<SyncFinished>().single;
        expect(terminal.data['phase'], 'cursor');
        expect(terminal.succeeded, isFalse);
        expect(
          terminal.data.keys.where((key) => key.endsWith('_fetched')),
          isEmpty,
        );
        expect(logger.firstCallOfType<SyncFinished>()!.error, isNull);
        expect(logger.eventsOfType<SyncContentCommitSucceeded>(), isEmpty);
      },
    );

    for (final phase in [0, 1, 2, 3]) {
      test(
        'returned preparation failure preserves identity at phase $phase',
        () async {
          final logger = MockLogger();
          final error = TestException('prepare-$phase');
          final deps = buildSyncUseCase(
            settings: FakeSettingsRepository(),
            logger: logger,
            cityResult: phase == 0
                ? Result.error(error)
                : Result.success([syncCityDto(1)]),
            placeResult: phase == 1
                ? Result.error(error)
                : Result.success([syncPlaceDto(1)]),
            eventResult: phase == 2
                ? Result.error(error)
                : Result.success([syncEventDto(1)]),
            mediaResult: phase == 3
                ? Result.error(error)
                : Result.success([syncMediaDto(1)]),
          );
          final result = await deps.useCase.sync();
          expect((result as Error<void>).error, same(error));
          expect(deps.settings.setSyncStateCalled, isFalse);
          expect([
            deps.cityRepo.commitCalled,
            deps.placeRepo.commitCalled,
            deps.eventRepo.commitCalled,
            deps.mediaRepo.commitCalled,
          ], everyElement(isFalse));
          expect([
            deps.cityRepo.committedDtos,
            deps.placeRepo.committedDtos,
            deps.eventRepo.committedDtos,
            deps.mediaRepo.committedDtos,
          ], everyElement(isNull));
          final terminal = logger.eventsOfType<SyncFinished>().single;
          expect(
            terminal.data['phase'],
            [
              'prepare_city',
              'prepare_place',
              'prepare_event',
              'prepare_media',
            ][phase],
          );
          expect(terminal.succeeded, isFalse);
          final counts = [
            'city_fetched',
            'place_fetched',
            'event_fetched',
            'media_fetched',
          ];
          expect(terminal.data.containsKey(counts[phase]), isFalse);
          for (final key in counts.where((key) => key != counts[phase])) {
            expect(terminal.data[key], 1);
          }
          expect(logger.calls.where((call) => call.error != null), isEmpty);
          expect(logger.eventsOfType<SyncContentCommitSucceeded>(), isEmpty);
        },
      );
    }

    for (final reversed in [false, true]) {
      for (final scenario in [
        for (var phase = 0; phase < 4; phase++)
          (throwsAt: [phase], returnsAt: <int>[]),
        (throwsAt: [0, 1, 2, 3], returnsAt: <int>[]),
        (throwsAt: [3], returnsAt: [0, 1, 2]),
        (throwsAt: <int>[], returnsAt: [0, 1, 2, 3]),
      ]) {
        test(
          'parallel failure priority $scenario reversed=$reversed',
          () async {
            final logger = MockLogger();
            final deps = buildSyncUseCase(
              settings: FakeSettingsRepository(),
              logger: logger,
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
            final errors = <Object>[
              StateError('city'),
              Object(),
              'event thrown object',
              TestException('media'),
            ];
            final stacks = List.generate(
              4,
              (i) => StackTrace.fromString('original-prepare-$i'),
            );
            final returned = List.generate(
              4,
              (i) => TestException('returned-$i'),
            );
            final succeed = <void Function()>[
              () => city.complete(
                scenario.returnsAt.contains(0)
                    ? Result.error(returned[0])
                    : Result.success([syncCityDto(1)]),
              ),
              () => place.complete(
                scenario.returnsAt.contains(1)
                    ? Result.error(returned[1])
                    : Result.success([syncPlaceDto(1)]),
              ),
              () => event.complete(
                scenario.returnsAt.contains(2)
                    ? Result.error(returned[2])
                    : Result.success([syncEventDto(1)]),
              ),
              () => media.complete(
                scenario.returnsAt.contains(3)
                    ? Result.error(returned[3])
                    : Result.success([syncMediaDto(1)]),
              ),
            ];
            final fail = <void Function(Object, StackTrace)>[
              city.completeError,
              place.completeError,
              event.completeError,
              media.completeError,
            ];
            Object? caught;
            StackTrace? caughtStack;
            final running = deps.useCase.sync().then<Result<void>?>(
              (value) => value,
              onError: (Object error, StackTrace stack) {
                caught = error;
                caughtStack = stack;
                return null;
              },
            );
            await Future.wait(started.map((signal) => signal.future));
            final order = reversed ? [3, 2, 1, 0] : [0, 1, 2, 3];
            for (final index in order) {
              if (scenario.throwsAt.contains(index)) {
                fail[index](errors[index], stacks[index]);
              } else {
                succeed[index]();
              }
              await Future<void>.value();
            }
            final result = await running;
            final primary = scenario.throwsAt.isNotEmpty
                ? scenario.throwsAt.first
                : scenario.returnsAt.first;
            if (scenario.throwsAt.isNotEmpty) {
              expect(caught, same(errors[primary]));
              expect(caughtStack, same(stacks[primary]));
              expect(result, isNull);
            } else {
              expect(caught, isNull);
              expect((result! as Error<void>).error, same(returned[primary]));
            }
            expect(logger.eventsOfType<SyncStarted>(), hasLength(1));
            final terminal = logger.eventsOfType<SyncFinished>();
            expect(terminal, hasLength(1));
            expect(
              terminal.single.data['phase'],
              [
                'prepare_city',
                'prepare_place',
                'prepare_event',
                'prepare_media',
              ][primary],
            );
            expect(terminal.single.succeeded, isFalse);
            for (final (index, key) in [
              'city_fetched',
              'place_fetched',
              'event_fetched',
              'media_fetched',
            ].indexed) {
              if (scenario.throwsAt.contains(index) ||
                  scenario.returnsAt.contains(index)) {
                expect(terminal.single.data.containsKey(key), isFalse);
              } else {
                expect(terminal.single.data[key], 1);
              }
            }
            expect(logger.eventsOfType<SyncContentCommitSucceeded>(), isEmpty);
            expect(logger.calls.where((call) => call.error != null), isEmpty);
            expect(deps.cityRepo.commitCalled, isFalse);
            expect(deps.settings.setSyncStateCalled, isFalse);
          },
        );
      }
    }
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
      final transport = RecordingSentryTransport();
      await Sentry.init((options) {
        options
          ..dsn = 'https://test@localhost/1'
          ..tracesSampleRate = 1
          ..traceLifecycle = SentryTraceLifecycle.stream
          ..transport = transport
          ..beforeSendSpan = transport.recordSpan;
      });
      await Sentry.configureScope(
        (scope) => scope.addEventProcessor(transport),
      );
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
      await transport.settleSpans(5);
      expect(transport.spans.map((span) => span.name), everyElement('sync'));
      expect(transport.spans.map((span) => span.status), [
        SentrySpanStatusV2.error,
        SentrySpanStatusV2.error,
        SentrySpanStatusV2.error,
        SentrySpanStatusV2.error,
        SentrySpanStatusV2.ok,
      ]);
      await transport.settleCaptures();
      expect(transport.events, isEmpty);
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
