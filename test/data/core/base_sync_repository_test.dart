import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
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
  group('BaseSyncRepository.prepareSync', () {
    late MockLogger mockLogger;
    late StubSyncRepository repository;

    setUp(() {
      mockLogger = MockLogger();
      repository = StubSyncRepository(mockLogger);
    });

    test('returns Result.success with DTOs from fetchRemote', () async {
      repository.remoteDtos.add(
        FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
      );

      final result = await repository.prepareSync();

      expect(result, isA<Success<List<FakeSyncDto>>>());
      final dtos = (result as Success<List<FakeSyncDto>>).value;
      expect(dtos, hasLength(1));
      expect(dtos[0].id, equals(1));
    });

    test(
      'returns Result.error when fetchRemote throws',
      () async {
        final throwingRepository = _ThrowingStubSyncRepository(mockLogger);

        final result = await throwingRepository.prepareSync();

        expect(result, isA<Error<List<FakeSyncDto>>>());
        expect(mockLogger.eventsOfType<RepositorySyncFailed>(), hasLength(1));
        final failedCall = mockLogger.firstCallOfType<RepositorySyncFailed>();
        expect(failedCall, isNotNull);
        expect(failedCall!.error, isNotNull);
        expect(failedCall.stackTrace, isNotNull);
      },
    );
  });

  group('BaseSyncRepository.commitSync', () {
    late MockLogger mockLogger;
    late StubSyncRepository repository;

    setUp(() {
      mockLogger = MockLogger();
      repository = StubSyncRepository(mockLogger);
    });

    test('inserts a new entity absent from the local store', () {
      repository.commitSync([
        FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
      ]);

      expect(repository.createdEntities, hasLength(1));
      expect(repository.storedEntities[1]?.remoteId, equals(1));
      expect(mockLogger.eventsOfType<EntityInsertSuccess>(), hasLength(1));
    });

    test('does not call putMany when remote returns empty', () {
      repository.commitSync([]);

      expect(repository.putManyCallCount, equals(0));
    });

    test(
      'updates an existing entity when remote modifiedAt is newer',
      () {
        repository.storedEntities[1] = FakeSyncEntity(
          remoteId: 1,
          modifiedAt: DateTime(2025),
        );

        repository.commitSync([
          FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
        ]);

        expect(repository.mergedEntities, hasLength(1));
        expect(
          repository.storedEntities[1]?.modifiedAt,
          equals(DateTime(2026)),
        );
        expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
      },
    );

    test(
      'skips an existing entity when remote modifiedAt is not newer',
      () {
        repository.storedEntities[1] = FakeSyncEntity(
          remoteId: 1,
          modifiedAt: DateTime(2025),
        );

        repository.commitSync([
          FakeSyncDto(id: 1, modifiedAt: DateTime(2025)),
        ]);

        expect(repository.mergedEntities, isEmpty);
        expect(repository.putManyCallCount, equals(0));
        expect(mockLogger.containsEvent<EntityInsertSuccess>(), isFalse);
        expect(mockLogger.containsEvent<EntityUpdateSuccess>(), isFalse);
      },
    );

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

        expect(repository.deletedEntities, hasLength(1));
        expect(repository.storedEntities[1]?.isDeleted, isTrue);
        expect(mockLogger.eventsOfType<EntityDeleteSuccess>(), hasLength(1));
      },
    );

    test(
      'skips soft-delete when deleted entity has no local counterpart',
      () {
        repository.commitSync([
          FakeSyncDto(
            id: 1,
            modifiedAt: DateTime(2026),
            deletedAt: DateTime(2026, 2),
          ),
        ]);

        expect(repository.deletedEntities, isEmpty);
        expect(repository.createdEntities, isEmpty);
        expect(repository.putManyCallCount, equals(0));
      },
    );

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

    test(
      're-activates a previously soft-deleted entity when remote no longer '
      'has deletedAt',
      () {
        repository.storedEntities[1] = FakeSyncEntity(
          remoteId: 1,
          modifiedAt: DateTime(2025),
          isDeleted: true,
        );

        repository.commitSync([
          FakeSyncDto(id: 1, modifiedAt: DateTime(2026)),
        ]);

        expect(repository.mergedEntities, hasLength(1));
        expect(repository.deletedEntities, isEmpty);
        expect(repository.storedEntities[1]?.isDeleted, isFalse);
        expect(mockLogger.eventsOfType<EntityUpdateSuccess>(), hasLength(1));
      },
    );

    test(
      'handles duplicate remote IDs — second DTO updates the entity '
      'created by the first within the same batch',
      () {
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
      },
    );

    test(
      'ignores deletedAt when supportsSoftDelete is false',
      () {
        final noSoftDeleteRepo = StubSyncRepository(
          mockLogger,
          supportsSoftDelete: false,
        );

        // Test readability benefits from separate statements over cascades.
        // ignore: cascade_invocations
        noSoftDeleteRepo.commitSync([
          FakeSyncDto(
            id: 1,
            modifiedAt: DateTime(2026),
            deletedAt: DateTime(2026, 2),
          ),
        ]);

        expect(noSoftDeleteRepo.deletedEntities, isEmpty);
        expect(noSoftDeleteRepo.createdEntities, hasLength(1));
      },
    );

    test(
      'returns Result.error and logs RepositorySyncFailed when putMany throws',
      () {
        final throwingRepo = _CommitThrowingStubSyncRepository(mockLogger);

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

class _CommitThrowingStubSyncRepository extends StubSyncRepository {
  _CommitThrowingStubSyncRepository(super.logger);

  @override
  void putMany(List<FakeSyncEntity> entities) {
    throw Exception('Local write failed');
  }
}
