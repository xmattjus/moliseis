import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/mock_logger.dart';

import '../../support/sync_repository_test_support.dart';

void main() {
  group('BaseSyncRepository.prepareSync', () {
    late MockLogger mockLogger;
    late StubSyncRepository repository;

    setUp(() {
      mockLogger = MockLogger();
      repository = StubSyncRepository(mockLogger);
    });

    test('returns Result.success with DTOs from fetchRemote', () async {
      repository.remoteDtos.add(FakeSyncDto(id: 1, modifiedAt: DateTime(2026)));

      final result = await repository.prepareSync();

      expect(result, isA<Success<List<FakeSyncDto>>>());
      final dtos = (result as Success<List<FakeSyncDto>>).value;
      expect(dtos, hasLength(1));
      expect(dtos[0].id, equals(1));
    });

    test('forwards the supplied inclusive lower bound unchanged', () async {
      final lowerBound = DateTime.utc(2026, 2);
      await repository.prepareSync(modifiedAtOrAfter: lowerBound);
      expect(repository.receivedLowerBound, lowerBound);
    });

    test('returns Result.error when fetchRemote throws', () async {
      final throwingRepository = StubSyncRepository(mockLogger)
        ..fetchError = Exception('Supabase unavailable');

      final result = await throwingRepository.prepareSync();

      expect(result, isA<Error<List<FakeSyncDto>>>());
      expect(mockLogger.eventsOfType<RepositorySyncFailed>(), hasLength(1));
      final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
      expect(failedCall, isNotNull);
      expect(failedCall!.error, isNotNull);
      expect(failedCall.stackTrace, isNotNull);
    });
  });

  group('BaseSyncRepository.commitSync', () {
    late MockLogger mockLogger;
    late StubSyncRepository repository;

    setUp(() {
      mockLogger = MockLogger();
      repository = StubSyncRepository(mockLogger);
    });

    test('inserts a new entity absent from the local store', () {
      repository.commitSync([FakeSyncDto(id: 1, modifiedAt: DateTime(2026))]);

      expect(repository.createdEntities, hasLength(1));
      expect(repository.storedEntities[1]?.remoteId, equals(1));
      expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
    });

    test('does not call putMany when remote returns empty', () {
      repository.commitSync([]);

      expect(repository.putManyCallCount, equals(0));
    });

    test('updates an existing entity when remote modifiedAt is newer', () {
      repository.storedEntities[1] = FakeSyncEntity(
        remoteId: 1,
        modifiedAt: DateTime(2025),
      );

      repository.commitSync([FakeSyncDto(id: 1, modifiedAt: DateTime(2026))]);

      expect(repository.mergedEntities, hasLength(1));
      expect(repository.storedEntities[1]?.modifiedAt, equals(DateTime(2026)));
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    test('skips an existing entity when remote modifiedAt is not newer', () {
      repository.storedEntities[1] = FakeSyncEntity(
        remoteId: 1,
        modifiedAt: DateTime(2025),
      );

      repository.commitSync([FakeSyncDto(id: 1, modifiedAt: DateTime(2025))]);

      expect(repository.mergedEntities, isEmpty);
      expect(repository.putManyCallCount, equals(0));
      expect(mockLogger.containsEvent<EntityInsertSuccess>(), isFalse);
      expect(mockLogger.containsEvent<EntityUpdateSuccess>(), isFalse);
    });

    test(
      'soft-deletes an existing entity when remote deletedAt is non-null',
      () {
        repository.storedEntities[1] = FakeSyncEntity(
          remoteId: 1,
          modifiedAt: DateTime(2025),
        );

        repository.commitSync([
          FakeSyncDto(
            id: 1,
            modifiedAt: DateTime(2026),
            deletedAt: DateTime(2026, 2),
          ),
        ]);

        expect(repository.mergedEntities, hasLength(1));
        expect(repository.storedEntities[1]?.isDeleted, isTrue);
        expect(mockLogger.eventsOfType<EntityDeleteSuccess>(), hasLength(1));
      },
    );

    test('skips soft-delete when deleted entity has no local counterpart', () {
      repository.commitSync([
        FakeSyncDto(
          id: 1,
          modifiedAt: DateTime(2026),
          deletedAt: DateTime(2026, 2),
        ),
      ]);

      expect(repository.createdEntities, isEmpty);
      expect(repository.putManyCallCount, equals(0));
    });

    test(
      'processes insert + update + skip + soft-delete in a single batch',
      () {
        repository.storedEntities[2] = FakeSyncEntity(
          remoteId: 2,
          modifiedAt: DateTime(2025),
        );
        repository.storedEntities[3] = FakeSyncEntity(
          remoteId: 3,
          modifiedAt: DateTime(2025),
        );
        repository.storedEntities[4] = FakeSyncEntity(
          remoteId: 4,
          modifiedAt: DateTime(2025),
        );

        repository.commitSync([
          FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
          FakeSyncDto(id: 2, modifiedAt: DateTime(2026)),
          FakeSyncDto(id: 3, modifiedAt: DateTime(2025)),
          FakeSyncDto(
            id: 4,
            modifiedAt: DateTime(2026),
            deletedAt: DateTime(2026, 2),
          ),
        ]);

        expect(repository.putManyCallCount, equals(1));
        expect(repository.putManyCalls[0], hasLength(3));
        expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
        expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
        expect(mockLogger.eventsOfType<EntityDeleteSuccess>(), hasLength(1));
      },
    );

    test('batches all pending puts into a single putMany call', () {
      for (var i = 1; i <= 5; i++) {
        repository.remoteDtos.add(
          FakeSyncDto(id: i, modifiedAt: DateTime(2026, 1, i)),
        );
      }

      repository.commitSync(repository.remoteDtos);

      expect(repository.putManyCallCount, equals(1));
      expect(repository.putManyCalls[0], hasLength(5));
    });

    test('re-activates a previously soft-deleted entity when remote no longer '
        'has deletedAt', () {
      repository.storedEntities[1] = FakeSyncEntity(
        remoteId: 1,
        modifiedAt: DateTime(2025),
        isDeleted: true,
      );

      repository.commitSync([FakeSyncDto(id: 1, modifiedAt: DateTime(2026))]);

      expect(repository.mergedEntities, hasLength(1));
      expect(repository.storedEntities[1]?.isDeleted, isFalse);
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    test('handles duplicate remote IDs — second DTO updates the entity '
        'created by the first within the same batch', () {
      repository.commitSync([
        FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
        FakeSyncDto(id: 1, modifiedAt: DateTime(2026, 6)),
      ]);

      expect(repository.createdEntities, hasLength(1));
      expect(repository.mergedEntities, hasLength(1));
      expect(repository.putManyCalls[0], hasLength(2));
      expect(
        repository.storedEntities[1]?.modifiedAt,
        equals(DateTime(2026, 6)),
      );
      expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
      expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
    });

    for (final deleted in [false, true]) {
      for (final remoteDeleted in [false, true]) {
        for (final year in [2024, 2025]) {
          test(
            'ignores year $year replay from deleted=$deleted to $remoteDeleted',
            () {
              final local = FakeSyncEntity(
                remoteId: 1,
                modifiedAt: DateTime(2025),
                isDeleted: deleted,
              );
              repository.storedEntities[1] = local;
              repository.commitSync([
                FakeSyncDto(
                  id: 1,
                  modifiedAt: DateTime(year),
                  deletedAt: remoteDeleted ? DateTime(2026) : null,
                ),
              ]);
              expect(repository.storedEntities[1], same(local));
              expect(repository.putManyCallCount, 0);
            },
          );
        }
      }
    }

    test('merges newer deleted state and replay is idempotent', () {
      repository.storedEntities[1] = FakeSyncEntity(
        remoteId: 1,
        modifiedAt: DateTime(2025),
        isDeleted: true,
      );
      final dto = FakeSyncDto(
        id: 1,
        modifiedAt: DateTime(2026),
        deletedAt: DateTime(2026, 2),
      );
      repository
        ..commitSync([dto])
        ..commitSync([dto]);
      expect(repository.storedEntities[1]!.modifiedAt, dto.modifiedAt);
      expect(repository.storedEntities[1]!.isDeleted, isTrue);
      expect(repository.putManyCallCount, 1);
    });

    test(
      'duplicate older tombstone cannot overwrite freshly created active',
      () {
        repository.commitSync([
          FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
          FakeSyncDto(
            id: 1,
            modifiedAt: DateTime(2025),
            deletedAt: DateTime(2025),
          ),
        ]);
        expect(repository.storedEntities[1]!.isDeleted, isFalse);
        expect(repository.putManyCalls.single, hasLength(1));
      },
    );

    test(
      'returns Result.error and logs RepositorySyncFailed when putMany throws',
      () {
        final throwingRepo = StubSyncRepository(mockLogger)
          ..commitError = Exception('Local write failed');

        final result = throwingRepo.commitSync([
          FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
        ]);

        expect(result.isError, isTrue);
        expect(mockLogger.eventsOfType<RepositorySyncFailed>(), hasLength(1));
        final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
        expect(failedCall, isNotNull);
        expect(failedCall!.error, isNotNull);
        expect(failedCall.stackTrace, isNotNull);
      },
    );
  });
}
