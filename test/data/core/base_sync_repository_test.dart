import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/data/core/sync_dto.dart';
import 'package:moliseis/data/core/sync_entity.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/mock_logger.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class FakeSyncDto implements SyncDto {
  const FakeSyncDto({
    required this.id,
    required this.modifiedAt,
    this.deletedAt,
  });

  @override
  final int id;
  @override
  final DateTime modifiedAt;
  @override
  final DateTime? deletedAt;
}

class FakeSyncEntity implements SyncEntity {
  FakeSyncEntity({
    required this.remoteId,
    required this.modifiedAt,
    this.isDeleted = false,
  });

  @override
  final int remoteId;
  @override
  final DateTime modifiedAt;
  @override
  final bool isDeleted;
}

class StubSyncRepository
    extends BaseSyncRepository<FakeSyncDto, FakeSyncEntity> {
  StubSyncRepository(
    super.logger, {
    this.supportsSoftDelete = true,
  });

  @override
  final bool supportsSoftDelete;

  @override
  void runInWriteTransaction(void Function() fn) => fn();

  final storedEntities = <int, FakeSyncEntity>{};
  final remoteDtos = <FakeSyncDto>[];

  int putManyCallCount = 0;
  final putManyCalls = <List<FakeSyncEntity>>[];
  final createdEntities = <FakeSyncEntity>[];
  final mergedEntities = <FakeSyncEntity>[];
  final deletedEntities = <FakeSyncEntity>[];

  @override
  String get entityName => 'fake';

  @override
  Future<List<FakeSyncDto>> fetchRemote() async => remoteDtos;

  @override
  FakeSyncEntity? getLocalById(int id) => storedEntities[id];

  @override
  void put(FakeSyncEntity entity) {
    storedEntities[entity.remoteId] = entity;
  }

  @override
  void putMany(List<FakeSyncEntity> entities) {
    putManyCallCount++;
    putManyCalls.add(List.of(entities));
    for (final entity in entities) {
      storedEntities[entity.remoteId] = entity;
    }
  }

  @override
  FakeSyncEntity createEntity(FakeSyncDto dto) {
    final entity = FakeSyncEntity(
      remoteId: dto.id,
      modifiedAt: dto.modifiedAt,
      isDeleted: dto.deletedAt != null,
    );
    createdEntities.add(entity);
    return entity;
  }

  @override
  FakeSyncEntity mergeEntity(FakeSyncDto dto, FakeSyncEntity existing) {
    final entity = FakeSyncEntity(
      remoteId: dto.id,
      modifiedAt: dto.modifiedAt,
      isDeleted: dto.deletedAt != null,
    );
    mergedEntities.add(entity);
    return entity;
  }

  @override
  FakeSyncEntity markEntityDeleted(FakeSyncEntity existing) {
    final entity = FakeSyncEntity(
      remoteId: existing.remoteId,
      modifiedAt: existing.modifiedAt,
      isDeleted: true,
    );
    deletedEntities.add(entity);
    return entity;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(setUpMockLogger);

  group('BaseSyncRepository.synchronize', () {
    late MockLogger mockLogger;
    late StubSyncRepository repository;

    setUp(() {
      mockLogger = MockLogger();
      repository = StubSyncRepository(mockLogger);
    });

    // -----------------------------------------------------------------------
    // Insert path
    // -----------------------------------------------------------------------

    group('insert', () {
      test('inserts a new entity absent from the local store', () async {
        repository.remoteDtos.add(
          FakeSyncDto(
            id: 1,
            modifiedAt: DateTime(2026, 1, 1),
          ),
        );

        final result = await repository.synchronize();

        expect(result, isA<Success<void>>());
        expect(repository.createdEntities, hasLength(1));
        expect(repository.storedEntities[1]?.remoteId, equals(1));
        verify(
          () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
        ).called(1);
      });

      test('does not call putMany when remote returns empty', () async {
        final result = await repository.synchronize();

        expect(result, isA<Success<void>>());
        expect(repository.putManyCallCount, equals(0));
      });
    });

    // -----------------------------------------------------------------------
    // Update / skip path
    // -----------------------------------------------------------------------

    group('update / skip', () {
      test(
        'updates an existing entity when remote modifiedAt is newer',
        () async {
          repository.storedEntities[1] = FakeSyncEntity(
            remoteId: 1,
            modifiedAt: DateTime(2025, 1, 1),
          );

          repository.remoteDtos.add(
            FakeSyncDto(
              id: 1,
              modifiedAt: DateTime(2026, 1, 1),
            ),
          );

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          expect(repository.mergedEntities, hasLength(1));
          expect(
            repository.storedEntities[1]?.modifiedAt,
            equals(DateTime(2026, 1, 1)),
          );
          verify(
            () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
          ).called(1);
        },
      );

      test(
        'skips an existing entity when remote modifiedAt is not newer',
        () async {
          repository.storedEntities[1] = FakeSyncEntity(
            remoteId: 1,
            modifiedAt: DateTime(2025, 1, 1),
          );

          repository.remoteDtos.add(
            FakeSyncDto(
              id: 1,
              modifiedAt: DateTime(2025, 1, 1),
            ),
          );

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          expect(repository.mergedEntities, isEmpty);
          expect(repository.putManyCallCount, equals(0));
          verifyNever(
            () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
          );
          verifyNever(
            () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // Soft-delete path
    // -----------------------------------------------------------------------

    group('soft-delete', () {
      test(
        'soft-deletes an existing entity when remote deletedAt is non-null',
        () async {
          repository.storedEntities[1] = FakeSyncEntity(
            remoteId: 1,
            modifiedAt: DateTime(2025, 1, 1),
          );

          repository.remoteDtos.add(
            FakeSyncDto(
              id: 1,
              modifiedAt: DateTime(2026, 1, 1),
              deletedAt: DateTime(2026, 2, 1),
            ),
          );

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          expect(repository.deletedEntities, hasLength(1));
          expect(repository.storedEntities[1]?.isDeleted, isTrue);
          verify(
            () => mockLogger.log(any(that: isA<EntityDeleteSuccess>())),
          ).called(1);
        },
      );

      test(
        'skips soft-delete when deleted entity has no local counterpart',
        () async {
          repository.remoteDtos.add(
            FakeSyncDto(
              id: 1,
              modifiedAt: DateTime(2026, 1, 1),
              deletedAt: DateTime(2026, 2, 1),
            ),
          );

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          expect(repository.deletedEntities, isEmpty);
          expect(repository.createdEntities, isEmpty);
          expect(repository.putManyCallCount, equals(0));
        },
      );
    });

    // -----------------------------------------------------------------------
    // Mixed batch
    // -----------------------------------------------------------------------

    group('mixed batch', () {
      test(
        'processes insert + update + skip + soft-delete in a single sync',
        () async {
          // id=1: insert (absent locally)
          // id=2: update (local is older)
          repository.storedEntities[2] = FakeSyncEntity(
            remoteId: 2,
            modifiedAt: DateTime(2025, 1, 1),
          );
          // id=3: skip (local is same age)
          repository.storedEntities[3] = FakeSyncEntity(
            remoteId: 3,
            modifiedAt: DateTime(2025, 1, 1),
          );
          // id=4: soft-delete
          repository.storedEntities[4] = FakeSyncEntity(
            remoteId: 4,
            modifiedAt: DateTime(2025, 1, 1),
          );

          repository.remoteDtos.addAll([
            FakeSyncDto(id: 1, modifiedAt: DateTime(2026, 1, 1)),
            FakeSyncDto(id: 2, modifiedAt: DateTime(2026, 1, 1)),
            FakeSyncDto(
              id: 3,
              modifiedAt: DateTime(2025, 1, 1),
            ),
            FakeSyncDto(
              id: 4,
              modifiedAt: DateTime(2026, 1, 1),
              deletedAt: DateTime(2026, 2, 1),
            ),
          ]);

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          expect(repository.putManyCallCount, equals(1));
          expect(repository.putManyCalls[0], hasLength(3));
          verify(
            () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
          ).called(1);
          verify(
            () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
          ).called(1);
          verify(
            () => mockLogger.log(any(that: isA<EntityDeleteSuccess>())),
          ).called(1);
        },
      );

      test('batches all pending puts into a single putMany call', () async {
        for (var i = 1; i <= 5; i++) {
          repository.remoteDtos.add(
            FakeSyncDto(id: i, modifiedAt: DateTime(2026, 1, i)),
          );
        }

        final result = await repository.synchronize();

        expect(result, isA<Success<void>>());
        expect(repository.putManyCallCount, equals(1));
        expect(repository.putManyCalls[0], hasLength(5));
      });
    });

    // -----------------------------------------------------------------------
    // Error path
    // -----------------------------------------------------------------------

    group('error handling', () {
      test(
        'returns Result.error and logs RepositorySyncFailed when '
        'fetchRemote throws',
        () async {
          final throwingRepository = _ThrowingStubSyncRepository(
            mockLogger,
          );

          final result = await throwingRepository.synchronize();

          expect(result, isA<Error<void>>());
          verify(
            () => mockLogger.log(
              any(that: isA<RepositorySyncFailed>()),
              error: any(named: 'error'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).called(1);
        },
      );

      test('logs RepositorySyncStarted before any work', () async {
        repository.remoteDtos.add(
          FakeSyncDto(id: 1, modifiedAt: DateTime(2026, 1, 1)),
        );

        await repository.synchronize();

        verify(
          () => mockLogger.log(any(that: isA<RepositorySyncStarted>())),
        ).called(1);
      });

      test(
        'rolls back the transaction when putMany throws, '
        'leaving local store untouched',
        () async {
          repository.storedEntities[1] = FakeSyncEntity(
            remoteId: 1,
            modifiedAt: DateTime(2025, 1, 1),
          );

          repository.storedEntities[2] = FakeSyncEntity(
            remoteId: 2,
            modifiedAt: DateTime(2025, 1, 1),
          );

          repository.remoteDtos.addAll([
            FakeSyncDto(id: 1, modifiedAt: DateTime(2026, 1, 1)),
            FakeSyncDto(id: 2, modifiedAt: DateTime(2026, 1, 1)),
          ]);

          final failingRepo = _PutManyThrowingStubSyncRepository(
            mockLogger,
            storedEntities: repository.storedEntities,
            remoteDtos: repository.remoteDtos,
          );

          final result = await failingRepo.synchronize();

          expect(result, isA<Error<void>>());
          expect(
            failingRepo.storedEntities[1]?.modifiedAt,
            equals(DateTime(2025, 1, 1)),
          );
          expect(
            failingRepo.storedEntities[2]?.modifiedAt,
            equals(DateTime(2025, 1, 1)),
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    group('edge cases', () {
      test(
        're-activates a previously soft-deleted entity when remote no longer '
        'has deletedAt',
        () async {
          repository.storedEntities[1] = FakeSyncEntity(
            remoteId: 1,
            modifiedAt: DateTime(2025, 1, 1),
            isDeleted: true,
          );

          repository.remoteDtos.add(
            FakeSyncDto(
              id: 1,
              modifiedAt: DateTime(2026, 1, 1),
              deletedAt: null,
            ),
          );

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          expect(repository.mergedEntities, hasLength(1));
          expect(repository.deletedEntities, isEmpty);
          expect(repository.storedEntities[1]?.isDeleted, isFalse);
          verify(
            () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
          ).called(1);
        },
      );

      test(
        'handles duplicate remote IDs — second DTO updates the entity '
        'created by the first within the same batch',
        () async {
          repository.remoteDtos.addAll([
            FakeSyncDto(id: 1, modifiedAt: DateTime(2026, 1, 1)),
            FakeSyncDto(id: 1, modifiedAt: DateTime(2026, 6, 1)),
          ]);

          final result = await repository.synchronize();

          expect(result, isA<Success<void>>());
          // First DTO creates; second DTO finds the first in pendingById
          // and merges rather than creating again.
          expect(repository.createdEntities, hasLength(1));
          expect(repository.mergedEntities, hasLength(1));
          // Both the created and merged entities are in the batch.
          expect(repository.putManyCalls[0], hasLength(2));
          // The final stored entity reflects the second (newer) DTO.
          expect(
            repository.storedEntities[1]?.modifiedAt,
            equals(DateTime(2026, 6, 1)),
          );
          verify(
            () => mockLogger.log(any(that: isA<EntityInsertSuccess>())),
          ).called(1);
          verify(
            () => mockLogger.log(any(that: isA<EntityUpdateSuccess>())),
          ).called(1);
        },
      );

      test(
        'ignores deletedAt when supportsSoftDelete is false',
        () async {
          final noSoftDeleteRepo = StubSyncRepository(
            mockLogger,
            supportsSoftDelete: false,
          );

          noSoftDeleteRepo.remoteDtos.add(
            FakeSyncDto(
              id: 1,
              modifiedAt: DateTime(2026, 1, 1),
              deletedAt: DateTime(2026, 2, 1),
            ),
          );

          final result = await noSoftDeleteRepo.synchronize();

          expect(result, isA<Success<void>>());
          expect(noSoftDeleteRepo.deletedEntities, isEmpty);
          expect(noSoftDeleteRepo.createdEntities, hasLength(1));
        },
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Throwing variant for error-path tests
// ---------------------------------------------------------------------------

class _ThrowingStubSyncRepository extends StubSyncRepository {
  _ThrowingStubSyncRepository(super.logger);

  @override
  Future<List<FakeSyncDto>> fetchRemote() async {
    throw Exception('Supabase unavailable');
  }
}

class _PutManyThrowingStubSyncRepository extends StubSyncRepository {
  _PutManyThrowingStubSyncRepository(
    super.logger, {
    Map<int, FakeSyncEntity> storedEntities = const {},
    List<FakeSyncDto> remoteDtos = const [],
  }) {
    this.storedEntities.addAll(storedEntities);
    this.remoteDtos.addAll(remoteDtos);
  }

  @override
  void putMany(List<FakeSyncEntity> entities) {
    throw Exception('Disk full — write transaction failed');
  }
}
