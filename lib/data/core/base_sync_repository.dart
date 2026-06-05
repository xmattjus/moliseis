import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/synchronizable.dart';

abstract class BaseSyncRepository<
  TDto extends SyncDto,
  TEntity extends SyncEntity
>
    with Synchronizable<TDto> {
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

  /// Fetches remote DTOs without writing to the local database.
  ///
  /// This is the first phase of a two-phase sync. It performs network I/O
  /// and returns the fetched DTOs wrapped in a [Result]. Call [commitSync]
  /// with the returned DTOs to write them to the local database.
  @override
  Future<Result<List<TDto>>> prepareSync() async {
    logger.log(RepositorySyncStarted(entityName));

    try {
      final dtos = await fetchRemote();
      return Result.success(dtos);
    } on Exception catch (e, stackTrace) {
      logger.log(
        RepositorySyncFailed(entityName),
        error: e,
        stackTrace: stackTrace,
      );

      return Result.error(e);
    }
  }

  /// Writes the given remote [dtos] to the local database.
  ///
  /// This is the second phase of a two-phase sync. It performs merge + write
  /// logic and must run inside a write transaction provided by the caller.
  @override
  Result<void> commitSync(List<TDto> dtos) {
    try {
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

      logger.log(RepositorySyncFinished(entityName));

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
