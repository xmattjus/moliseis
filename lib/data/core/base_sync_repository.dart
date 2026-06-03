import 'package:moliseis/data/core/sync_dto.dart';
import 'package:moliseis/data/core/sync_entity.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

abstract class BaseSyncRepository<
  TDto extends SyncDto,
  TEntity extends SyncEntity
>
    with Synchronizable {
  BaseSyncRepository(this.logger);

  final Logger logger;

  String get entityName;

  Future<List<TDto>> fetchRemote();

  TEntity? getLocalById(int id);

  void put(TEntity entity);

  void putMany(List<TEntity> entities);

  TEntity createEntity(TDto dto);

  TEntity mergeEntity(TDto dto, TEntity existing);

  TEntity markEntityDeleted(TEntity existing);

  bool get supportsSoftDelete => true;

  void runInWriteTransaction(void Function() fn);

  @override
  Future<Result<void>> synchronize() async {
    logger.log(RepositorySyncStarted(entityName));

    try {
      final dtos = await fetchRemote();

      runInWriteTransaction(() {
        final pendingPuts = <TEntity>[];
        final pendingById = <int, TEntity>{};

        for (final dto in dtos) {
          final existing = pendingById[dto.id] ?? getLocalById(dto.id);

          if (supportsSoftDelete && dto.deletedAt != null) {
            if (existing != null) {
              final deleted = markEntityDeleted(existing);
              pendingPuts.add(deleted);
              pendingById[dto.id] = deleted;

              logger.log(
                EntityDeleteSuccess(entityName, dto.id),
              );
            }
            continue;
          }

          if (existing == null) {
            final created = createEntity(dto);
            pendingPuts.add(created);
            pendingById[dto.id] = created;

            logger.log(
              EntityInsertSuccess(entityName, dto.id),
            );
            continue;
          }

          if (dto.modifiedAt.isAfter(existing.modifiedAt)) {
            final merged = mergeEntity(dto, existing);
            pendingPuts.add(merged);
            pendingById[dto.id] = merged;

            logger.log(
              EntityUpdateSuccess(entityName, dto.id),
            );
          }
        }

        if (pendingPuts.isNotEmpty) {
          putMany(pendingPuts);
        }
      });

      return const Result.success(null);
    } on Exception catch (e, stackTrace) {
      logger.log(
        RepositorySyncFailed(entityName),
        error: e,
        stackTrace: stackTrace,
      );

      return Result.error(e);
    }
  }
}
