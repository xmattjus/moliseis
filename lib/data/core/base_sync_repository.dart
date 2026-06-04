import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
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

  /// Fetches remote DTOs without writing to the local database.
  ///
  /// This is the first phase of a two-phase sync. It performs network I/O
  /// and returns the fetched DTOs wrapped in a [Result]. Call [commitSync]
  /// with the returned DTOs to write them to the local database.
  ///
  /// The returned list elements are always instances of [TDto] at runtime,
  /// even though the static return type is `List<SyncDto>`.
  @override
  Future<Result<List<SyncDto>>> prepareSync() async {
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
  /// All elements of [dtos] must be instances of [TDto] at runtime —
  /// see [Synchronizable] for the full type contract.  If any element has
  /// an unexpected type the method returns `Result.error` immediately.
  ///
  /// This is the second phase of a two-phase sync. It performs merge + write
  /// logic and must run inside a write transaction provided by the caller.
  @override
  Result<void> commitSync(List<SyncDto> dtos) {
    if (!dtos.every((dto) => dto is TDto)) {
      return Result.error(
        Exception(
          'commitSync: received DTOs of wrong type. '
          'Expected $TDto but found '
          '${dtos.where((dto) => dto is! TDto).map((dto) => dto.runtimeType)}',
        ),
      );
    }

    try {
      final pendingPuts = <TEntity>[];
      final pendingById = <int, TEntity>{};

      final typedDtos = List<TDto>.from(dtos);
      for (final dto in typedDtos) {
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
