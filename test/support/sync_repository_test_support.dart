import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/core/sync_entity.dart';

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
  StubSyncRepository(super.logger);

  final storedEntities = <int, FakeSyncEntity>{};
  final remoteDtos = <FakeSyncDto>[];

  int putManyCallCount = 0;
  final putManyCalls = <List<FakeSyncEntity>>[];
  final createdEntities = <FakeSyncEntity>[];
  final mergedEntities = <FakeSyncEntity>[];
  DateTime? receivedLowerBound;
  Exception? fetchError;
  Exception? commitError;

  @override
  String get tableName => 'fakes';

  @override
  String get entityName => 'fake';

  @override
  Future<List<FakeSyncDto>> fetchRemote({DateTime? modifiedAtOrAfter}) async {
    receivedLowerBound = modifiedAtOrAfter;
    if (fetchError != null) throw fetchError!;
    return remoteDtos;
  }

  @override
  FakeSyncEntity? getLocalById(int id) => storedEntities[id];

  @override
  void put(FakeSyncEntity entity) {
    storedEntities[entity.remoteId] = entity;
  }

  @override
  void putMany(List<FakeSyncEntity> entities) {
    if (commitError != null) throw commitError!;
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
}
