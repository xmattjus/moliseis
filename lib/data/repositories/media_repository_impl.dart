import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/media_supabase_table.dart';
import 'package:moliseis/data/dtos/media_dto.dart';
import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaRepositoryImpl extends BaseSyncRepository<MediaDto, MediaEntity>
    implements MediaRepository {
  MediaRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required MediaSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _table = supabaseTable,
       _objectBox = objectBoxI,
       _box = objectBoxI.store.box<MediaEntity>(),
       super(logger);

  final Supabase _supabase;
  final MediaSupabaseTable _table;
  final ObjectBox _objectBox;
  final Box<MediaEntity> _box;

  @override
  String get entityName => 'media';

  @override
  void runInWriteTransaction(void Function() fn) =>
      _objectBox.store.runInTransaction(TxMode.write, fn);

  @override
  Future<List<MediaDto>> fetchRemote() async {
    final response = await _supabase.client.from(_table.tableName).select();

    return response.map<MediaDto>(MediaDtoMapper.fromMap).toList();
  }

  @override
  MediaEntity? getLocalById(int id) => _box.get(id);

  @override
  void put(MediaEntity entity) => _box.put(entity);

  @override
  void putMany(List<MediaEntity> entities) => _box.putMany(entities);

  @override
  MediaEntity createEntity(MediaDto dto) => dto.toEntity();

  @override
  MediaEntity mergeEntity(MediaDto dto, MediaEntity existing) =>
      dto.mergeInto(existing);

  @override
  MediaEntity markEntityDeleted(MediaEntity existing) {
    return existing.copyWith(
      isDeleted: true,
    );
  }

  Condition<MediaEntity> get _isNotDeleted =>
      MediaEntity_.isDeleted.equals(false);

  @override
  Future<Result<List<Media>>> getByEventId(int id) async {
    Query<MediaEntity>? query;

    try {
      final builder = _box.query(_isNotDeleted)
        ..link(MediaEntity_.event, EventEntity_.remoteId.equals(id));

      query = builder.build();

      final results = await query.findAsync();

      final mappedResults = results
          .map<Media>((entity) => entity.toModel())
          .toList();

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('media', method: 'getByEventId'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Media>>> getByPlaceId(int id) async {
    Query<MediaEntity>? query;

    try {
      final builder = _box.query(_isNotDeleted)
        ..link(MediaEntity_.place, PlaceEntity_.remoteId.equals(id));

      query = builder.build();

      final results = await query.findAsync();

      final mappedResults = results
          .map<Media>((entity) => entity.toModel())
          .toList();

      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      logger.log(
        const EntityLoadFailed('media', method: 'getByPlaceId'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    } finally {
      query?.close();
    }
  }
}
