import 'package:collection/collection.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/media_supabase_table.dart';
import 'package:moliseis/data/mappers/media_entity_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required MediaSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _logger = logger,
       _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _mediaBox = objectBoxI.store.box<MediaEntity>();

  final Logger _logger;

  final Supabase _supabase;
  final MediaSupabaseTable _supabaseTable;
  final Box<MediaEntity> _mediaBox;

  @override
  Future<Result<void>> synchronize() async {
    _logger.log(const RepositorySyncStarted('media'));

    try {
      final media = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<MediaEntity>.unmodifiable(
        media.map<MediaEntity>(MediaEntity.fromJson),
      );

      final local = Set<MediaEntity>.unmodifiable(_mediaBox.getAll());

      final mediaToPut = remote.difference(local);

      for (final media in mediaToPut) {
        final existingMedia = local.firstWhereOrNull(
          (test) => test.remoteId == media.remoteId,
        );

        if (existingMedia == null) {
          media.place.targetId = media.placeToOneId;
          media.event.targetId = media.eventToOneId;

          _mediaBox.put(media);

          _logger.log(EntityInsertSuccess('media', media.remoteId));
        } else {
          if (existingMedia != media) {
            final copy = existingMedia.copyWith(
              title: media.title,
              author: media.author,
              license: media.license,
              licenseUrl: media.licenseUrl,
              url: media.url,
              width: media.width,
              height: media.height,
              placeToOneId: () => media.placeToOneId,
              eventToOneId: () => media.eventToOneId,
              createdAt: media.createdAt,
              modifiedAt: media.modifiedAt,
            );

            _mediaBox.put(copy);

            _logger.log(
              EntityUpdateSuccess('media', media.remoteId),
            );
          }
        }
      }

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const RepositorySyncFailed('media'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  @override
  Future<Result<List<Media>>> getByEventId(int id) async {
    Query<MediaEntity>? query;

    try {
      final builder = _mediaBox.query()
        ..link(MediaEntity_.event, EventEntity_.remoteId.equals(id));
      query = builder.build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Media>((entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
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
      final builder = _mediaBox.query()
        ..link(MediaEntity_.place, PlaceEntity_.remoteId.equals(id));
      query = builder.build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Media>((entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
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
